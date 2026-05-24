# Vendor HAL Extraction Guide

Some devices need proprietary vendor HAL (Hardware Abstraction Layer) binaries to make features like **fingerprint sensors**, **vibrators**, or **display hardware** work on a GSI. These binaries live in the vendor partition and are replaced when you flash a GSI — so we ship them inside the KSU module.

> ⚠️ **⚠️ CRITICAL WARNING: BOOTLOOP RISK ⚠️**
>
> Shipping the **wrong** HAL binaries, **incompatible** VINTF manifest fragments, or **incorrect** SELinux policies can cause:
> - **Bootloop** — phone gets stuck at the boot animation
> - **Soft brick** — phone boots but touch/display doesn't work
> - **Silent failure** — phone boots but features silently don't work (no errors shown)
>
> **Always test on a device you can recover** (e.g., with a working recovery mode).
> Extract binaries from **your own device's vendor partition**, not from another device.

---

## 📋 Quick Checklist

Before extracting, determine what your device needs:

| Feature | Files to extract | Required? |
|---------|-----------------|-----------|
| **Fingerprint (UDFPS)** | HAL binary, .rc file, VINTF manifest, shared libs, sepolicy rules | Optional |
| **Vibrator** | HAL binary, .rc file, VINTF manifest, sepolicy rules | Optional |
| **Display/AOD** | .rc file for display sysfs permissions | Optional |
| **Other HALs** | Similar pattern | Usually not needed on GSI |

Most devices only **need the overlay APK** (corner radius, cutout, brightness, etc.). Vendor HALs are only needed for features that don't work on the GSI's default implementation.

---

## 🛠 Step 1: Identify Your Device's Vendor HALs

Connect your device over ADB and check what's running:

```bash
# Check running HAL services (e.g., fingerprint, vibrator)
adb shell dumpsys -l | grep -iE 'finger|vibrat|udfps|biometric'

# List HAL binary files in vendor
adb shell ls /vendor/bin/hw/ 2>/dev/null

# Look for specific HALs (replace "finger" with "vibrat", "display", etc.)
adb shell ls /vendor/bin/hw/*finger* /vendor/bin/hw/*biometric* 2>/dev/null
adb shell ls /vendor/bin/hw/*vibrat* 2>/dev/null

# List init scripts for these HALs
adb shell ls /vendor/etc/init/*finger* /vendor/etc/init/*vibrat* /vendor/etc/init/*udfps* 2>/dev/null

# List all VINTF manifest fragments
adb shell ls /vendor/etc/vintf/manifest/ 2>/dev/null

# List shared libraries for HALs
adb shell ls /vendor/lib64/*finger* /vendor/lib64/*biometric* 2>/dev/null
adb shell ls /vendor/lib64/*vibrat* 2>/dev/null
```

> 💡 **Note on GSIs:** If you're running a GSI or a Custom ROM, `/vendor/bin/hw/` may only contain basic AOSP HALs while your stock vendor's proprietary HALs are gone. In that case, you need to extract from a **stock firmware vendor.img** instead (see Method B).

### Reference Example: Samsung Galaxy A90 5G (r3q)

On a stock Samsung vendor, you'd find:

```
# Fingerprint (Goodix ET715 optical UDFPS)
/vendor/bin/hw/android.hardware.biometrics.fingerprint@2.3-service.samsung
/vendor/etc/init/android.hardware.biometrics.fingerprint@2.3-service.samsung.rc
/vendor/etc/init/init.udfps.rc
/vendor/etc/init/fingerprint_common.rc
/vendor/etc/vintf/manifest/android.hardware.biometrics.fingerprint@2.3-service.samsung.xml
/vendor/lib64/android.hardware.biometrics.fingerprint@2.1.so
/vendor/lib64/android.hardware.biometrics.fingerprint@2.2.so
/vendor/lib64/android.hardware.biometrics.fingerprint@2.3.so

# Vibrator (Samsung sec-vibrator-2-2)
/vendor/bin/hw/vendor.samsung.hardware.vibrator@2.2-service
/vendor/etc/init/vendor.samsung.hardware.vibrator@2.2-service.rc
/vendor/etc/vintf/manifest/vendor.samsung.hardware.vibrator@2.2-service.xml

# Display (AOD sysfs permissions)
/vendor/etc/init/init.samsung.display.rc
```

> Your device will likely have **different HAL names** — look for patterns in the filenames (e.g., `*fingerprint*`, `*vibrat*`, `*display*`) rather than exact names.

---

## 📦 Step 2: Extract the Files

You can either pull files from a running device (Method A) or extract from a vendor image dump (Method B).

### Method A: Pull from running device (requires root)

This works if you're booted into **stock firmware** (not a GSI) or if the HALs survived the GSI flash.

```bash
# Create extraction directories (these already exist in this project)
mkdir -p system/vendor/bin/hw
mkdir -p system/vendor/etc/init
mkdir -p system/vendor/etc/vintf/manifest
mkdir -p system/vendor/lib64

# --- Option 1: Pull individual files ---
# Replace paths with YOUR device's actual paths from Step 1.
# Binary file (HAL executable):
adb shell su -c 'cat /vendor/bin/hw/<your_fingerprint_hal_binary>' > system/vendor/bin/hw/<your_fingerprint_hal_binary>

# Init script:
adb shell su -c 'cat /vendor/etc/init/<your_fingerprint_init.rc>' > system/vendor/etc/init/<your_fingerprint_init.rc>

# VINTF manifest:
adb shell su -c 'cat /vendor/etc/vintf/manifest/<your_fingerprint_manifest.xml>' > system/vendor/etc/vintf/manifest/<your_fingerprint_manifest.xml>

# Shared library:
adb shell su -c 'cat /vendor/lib64/<your_fingerprint_library.so>' > system/vendor/lib64/<your_fingerprint_library.so>

# Make binaries executable
chmod +x system/vendor/bin/hw/*

# --- Option 2: Pull via tar (faster for many files) ---
# This is much faster if you have many files to extract:
adb shell su -c 'tar -czf /data/local/tmp/vendor_hal.tar.gz -C / vendor/bin/hw/*finger* vendor/etc/init/*finger* vendor/etc/vintf/manifest/*finger* vendor/lib64/*finger*'
adb pull /data/local/tmp/vendor_hal.tar.gz /tmp/
cd system/vendor && tar -xzf /tmp/vendor_hal.tar.gz
```

### Method B: Extract from a vendor image dump

Use this if you have a `vendor.img` from your device's stock ROM or a properly working Custom ROM:

```bash
# 1. Mount the vendor image (Or just double click to mount if works):
sudo mount -o loop vendor.img /mnt/vendor

# 2. Copy files (adjust paths to match your device's HALs)
# Fingerprint:
sudo cp /mnt/vendor/bin/hw/*finger* system/vendor/bin/hw/
sudo cp /mnt/vendor/etc/init/*finger* system/vendor/etc/init/
sudo cp /mnt/vendor/etc/vintf/manifest/*finger*.xml system/vendor/etc/vintf/manifest/
sudo cp /mnt/vendor/lib64/*finger* system/vendor/lib64/

# Vibrator (if applicable):
sudo cp /mnt/vendor/bin/hw/*vibrat* system/vendor/bin/hw/
sudo cp /mnt/vendor/etc/init/*vibrat* system/vendor/etc/init/
sudo cp /mnt/vendor/etc/vintf/manifest/*vibrat*.xml system/vendor/etc/vintf/manifest/

# Display init scripts (if applicable):
sudo cp /mnt/vendor/etc/init/*display* system/vendor/etc/init/ 2>/dev/null

# 3. Fix ownership
sudo chown -R $USER:$USER system/vendor/

# 4. Make binaries executable
chmod +x system/vendor/bin/hw/*

# 5. Unmount
sudo umount /mnt/vendor
```

> 💡 **Tip:** You can copy **all** vendor init scripts and manifests at once and then remove what you don't need:
> ```bash
> sudo cp -r /mnt/vendor/etc/init/ system/vendor/etc/
> sudo cp -r /mnt/vendor/etc/vintf/ system/vendor/etc/
> # Then delete files you don't want or select all the necessary files
> ```

---

## 🔧 Step 3: Prepare the Init .rc File

The `.rc` file tells Android's init system how to start your HAL service. Extract this from your device (at `/vendor/etc/init/`) and place it in `system/vendor/etc/init/`.

### Generic .rc file format

The exact content varies by device, but the structure is always similar:

```rc
# Name the service (use a unique name to avoid conflicts with stock vendor)
service <your_service_name> /vendor/bin/hw/<your_hal_binary>
    class late_start          # or "hal" for some HALs
    user system
    group system <additional_groups>
    <capabilities>
    <device_node_permissions>
```

Find the `class`, `user`, `group`, and other directives by looking at the original `.rc` file from your device. Key things to note:

| Directive | Common values | Notes |
|-----------|--------------|-------|
| `class` | `late_start`, `hal`, `main` | Most HALs use `late_start` or `hal` |
| `user` | `system`, `root`, `bluetooth` | Usually `system` for HALs |
| `group` | `system`, `input`, `uhid` | Varies by HAL type |
| `capabilities` | `SYS_NICE`, `SYS_RESOURCE` | Only if the HAL needs elevated caps |
| `file` | `/dev/...` | Device node permissions |

> **⚠️ IMPORTANT:** If the stock vendor already has a service with the same name (e.g., `vendor.fps_hal`), you must use a **different service name** (e.g., `vendor.fps_hal_aosp`) to avoid conflict. Both binaries can coexist!

### Reference Example: Samsung Fingerprint

```rc
service vendor.fps_hal_aosp /vendor/bin/hw/android.hardware.biometrics.fingerprint@2.3-service.samsung
    class late_start
    user system
    group system input uhid
    capabilities SYS_NICE
    file /dev/goodix_fp 0660 system system
    file /dev/esfp0 0660 system system
```

### Reference Example: Samsung Vibrator

```rc
on early-boot
    chown system system /sys/class/timed_output/vibrator/intensity
    chmod 660 /sys/class/timed_output/vibrator/intensity
    # ... (all sysfs nodes the HAL needs)

service sec-vibrator-2-2 /vendor/bin/hw/vendor.samsung.hardware.vibrator@2.2-service
    class hal
    user system
    group system
```

---

## 📄 Step 4: Prepare the VINTF Manifest Fragment

The VINTF manifest tells the framework what HAL interfaces your service implements. Extract from your device at `/vendor/etc/vintf/manifest/`. Incorrect one will bootloop or freeze the device.

### Generic VINTF manifest format

```xml
<manifest version="1.0" type="device">
    <hal format="hidl">              <!-- or "aidl" for newer HALs -->
        <name><hal_interface_name></name>
        <transport>hwbinder</transport>
        <version><major.minor></version>
        <interface>
            <name><InterfaceName></name>
            <instance>default</instance>
        </interface>
        <fqname>@<major.minor>::<InterfaceName>/default</fqname>
    </hal>
</manifest>
```

> 💡 **Just extract it!** The VINTF manifest from your device already has the correct format — there's usually no need to write one from scratch.

### Reference Example: Fingerprint VINTF (Samsung)

```xml
<manifest version="1.0" type="device">
    <hal format="hidl">
        <name>android.hardware.biometrics.fingerprint</name>
        <transport>hwbinder</transport>
        <version>2.3</version>
        <interface>
            <name>IBiometricsFingerprint</name>
            <instance>default</instance>
        </interface>
        <fqname>@2.3::IBiometricsFingerprint/default</fqname>
    </hal>
</manifest>
```

### Reference Example: Vibrator VINTF (Samsung)

```xml
<manifest version="1.0" type="device">
    <hal format="hidl">
        <name>vendor.samsung.hardware.vibrator</name>
        <transport>hwbinder</transport>
        <version>2.2</version>
        <interface>
            <name>ISehVibrator</name>
            <instance>default</instance>
        </interface>
    </hal>
</manifest>
```

---

## 🔒 Step 5: Add SELinux Policy Rules

SELinux might block your HAL from accessing device nodes or sysfs files which might also cause bootloops or freezes. Add the necessary rules to `sepolicy.rule` in the project root. A reference example is in `sepolicy.rule.example` (Samsung Galaxy A90 5G).

### Generic SELinux rules pattern

The rules follow this pattern for any HAL type:

```
# Allow init to execute the HAL binary (domain transition)
allow init <hal_type>_exec:file { execute execute_no_trans };

# Allow HAL to load shared libraries
allow <hal_type> vendor_file:file { read execute getattr open map };

# Allow HAL to access its device node
allow <hal_type> <device_type>:chr_file rw_file_perms;

# Allow HAL to read sysfs attributes
allow <hal_type> <sysfs_type>:dir r_dir_perms;
allow <hal_type> <sysfs_type>:file r_file_perms;

# Allow HAL to create data files
allow <hal_type> <data_type>:dir create_dir_perms;
allow <hal_type> <data_type>:file create_file_perms;
```

Replace `<hal_type>`, `<device_type>`, `<sysfs_type>`, and `<data_type>` with your device's actual SELinux types. Determine the right types by checking the stock device's `sepolicy` or by examining logcat denials.

### Finding SELinux denials on your device

```bash
# Check for denials after flashing the module
adb logcat -b all -d | grep "avc: denied"

# Each line shows:
# avc: denied { <permission> } for pid=... scontext=u:r:<source_context>:s0
#   tcontext=u:object_r:<target_type>:s0 tclass=<class>
#
# Translate to sepolicy rule:
#   allow <source_context> <target_type>:<class> { <permission> };
```

### Reference Example: Fingerprint HAL sepolicy

```allow init hal_fingerprint_default_exec:file { execute execute_no_trans };
allow hal_fingerprint_default vendor_file:file { read execute getattr open map };
allow hal_fingerprint_default fingerprint_sensor_device:chr_file rw_file_perms;
allow hal_fingerprint_default sysfs_fingerprint:dir r_dir_perms;
allow hal_fingerprint_default sysfs_fingerprint:file r_file_perms;
allow hal_fingerprint_default tee_device:chr_file rw_file_perms;
allow hal_fingerprint_default vendor_biometrics_data_file:dir create_dir_perms;
allow hal_fingerprint_default vendor_biometrics_data_file:file create_file_perms;
```

### Reference Example: Vibrator HAL sepolicy

```allow init hal_vibrator_default_exec:file { execute execute_no_trans };
allow hal_vibrator_default sysfs:file rw_file_perms;
allow hal_vibrator_default sysfs:dir r_dir_perms;
allow hal_vibrator_default sysfs_leds:file rw_file_perms;
allow hal_vibrator_default sysfs_leds:dir r_dir_perms;
allow hal_vibrator_default timed_output_device:chr_file rw_file_perms;
```

---

## 🧪 Step 6: Test

1. Run `./build.sh` to build the module with your extracted files
2. Flash the module on your device
3. Check logcat for SELinux denials: `adb logcat -b all -d | grep "avc: denied"`
4. Check if the service started:
   ```bash
   adb shell dumpsys fingerprint        # For fingerprint
   adb shell dumpsys vibrator           # For vibrator
   adb shell dumpsys -l | grep <hal>    # For any other HAL
   ```

### Debugging checklist

| Symptom | Likely cause | Fix |
|---------|-------------|-----|
| Service not found | Missing VINTF manifest | Add .xml to `system/vendor/etc/vintf/manifest/` |
| Service won't start | SELinux denial | Check logcat, add rules to `sepolicy.rule` |
| Service starts but doesn't work | Wrong HAL binary version | Extract from your exact device model and firmware |
| "No such file" in logcat | Missing shared library | Check `system/vendor/lib64/` for missing .so files |
| Device bootloops | Incompatible sepolicy or VINTF | Remove the vendor files and re-test |

---

## 📁 File Layout Reference

The `system/vendor/` directory structure has been pre-created in this project. Place your extracted files here:

```
project_root/
├── system/
│   └── vendor/
│       ├── bin/
│       │   └── hw/          # ← Put HAL binaries here (e.g., fingerprint@2.3-service.*)
│       ├── etc/
│       │   ├── init/        # ← Put init .rc files here
│       │   └── vintf/
│       │       └── manifest/ # ← Put VINTF manifest .xml files here
│       └── lib64/           # ← Put shared libraries (.so) here
├── sepolicy.rule             # ← Add YOUR SELinux rules here (template)
├── sepolicy.rule.example     # ← Reference: Samsung A90 5G rules (copy as starting point)
├── customize.sh              # ← Sets SELinux contexts at install time (update if you add new HALs)
└── service.sh                # ← Starts services at boot (update if you add new HALs)
```

The empty directories are already created — just drop your files in the right folder and they'll be picked up automatically by `build.sh`.

This project has a well-structured file system for the vendor handling, PLEASE RE-STRUCTURE IF INCORRECT:
> - `system/vendor/bin/hw/` — fingerprint, vibrator, display HAL binaries
> - `system/vendor/etc/init/` — init scripts for those HALs
> - `system/vendor/etc/vintf/manifest/` — VINTF manifest fragment
> - `system/vendor/lib64/` — fingerprint shared libraries
> - `system/vendor/vendor_overlay_ref/` — stock vendor overlay APKs (useful for extracting config values like corner radius, UDFPS coords, brightness curve)
> - `system/vendor/build.prop` — vendor build properties (all device identifiers in one file)
>
> Place YOUR device's files before building for your device.

---

## ⚠️ Safety Notes

1. **Always keep a backup** of your working module before adding vendor HALs
2. **Test one HAL at a time** — add fingerprint first, get it working, then add vibrator
3. **If the device bootloops**, boot to recovery and remove the module, if you absolutely can't remove the module, just format data 🙂‍↕️:
   ```bash
   adb reboot recovery
   adb shell mount /data
   adb shell rm -rf /data/adb/modules/treble-overlay-<your_device>
   adb shell reboot
   ```
4. **VINTF manifest fragments from the wrong device can cause HAL manager crashes** — only use fragments from your exact device model and firmware version.
5. **Don't blindly copy ALL vendor files** — only copy the HALs you actually need. Each extra file is another potential source of conflicts.

---

*Reference examples in this guide use the Samsung Galaxy A90 5G (SM-A908N / r3q) — your device will have different file names and paths.*
