#!/sbin/sh
# =============================================================================
# Treble Overlay — Post-Boot Initialization Script
# =============================================================================
# Runs at boot to enable overlays, set system properties, and start
# vendor HAL services. Sections for vendor HALs are conditional —
# they only run if the corresponding binary exists.
#
# Customize the properties below for YOUR device.
# Reference values are for Samsung Galaxy A90 5G (SM-A908 / r3q).
# =============================================================================

# ═══════════════════════════════════════════════════════════════════════════
# SECTION 1: Wait for boot
# ═══════════════════════════════════════════════════════════════════════════
while [ "$(getprop sys.boot_completed)" != "1" ]; do
    sleep 5
done

# ═══════════════════════════════════════════════════════════════════════════
# SECTION 2: Enable overlays
# ═══════════════════════════════════════════════════════════════════════════

# Enable the main framework-res overlay
# Note: @OVERLAY_PACKAGE@ is replaced by build.sh with your config.env value
cmd overlay enable @OVERLAY_PACKAGE@ 2>/dev/null || true

# Enable the SystemUI overlay (doze/AOD fix)
# Note: @OVERLAY_PACKAGE_SYSTEMUI@ is replaced by build.sh with your config.env value
cmd overlay enable @OVERLAY_PACKAGE_SYSTEMUI@ 2>/dev/null || true

# ═══════════════════════════════════════════════════════════════════════════
# SECTION 3: AOD / Doze configuration
# ═══════════════════════════════════════════════════════════════════════════

# Enable AOD overlay via Phh-Treble property
setprop persist.sys.overlay.aod true

# Prevent DOZE_SUSPEND — keeps AOD content updating (clock, notifications)
setprop persist.sys.phh.disable_display_doze_suspend true

# ═══════════════════════════════════════════════════════════════════════════
# SECTION 4: Vendor HAL services (optional)
# ═══════════════════════════════════════════════════════════════════════════
# Each service start is guarded by a file existence check.
# Add or remove sections based on your device's vendor HALs.

# --- Fingerprint HAL (AOSP v2.3 Wrapper) ---
# Only start if the binary exists in the module
if [ -f "/system/vendor/bin/hw/android.hardware.biometrics.fingerprint@2.3-service.samsung" ]; then
    start vendor.fps_hal_aosp 2>/dev/null || true
fi

# --- Vibrator HAL (Samsung sec-vibrator-2-2) ---
if [ -f "/system/vendor/bin/hw/vendor.samsung.hardware.vibrator@2.2-service" ]; then
    start sec-vibrator-2-2 2>/dev/null || true
fi

# --- UDFPS FOD Screen Lighting ---
# Enables FOD (Fingerprint on Display) mode on the TSP
if [ -f "/sys/class/sec/tsp/cmd" ]; then
    echo "fod_enable,1" > /sys/class/sec/tsp/cmd 2>/dev/null || true
fi

# ═══════════════════════════════════════════════════════════════════════════
# SECTION 5: UDFPS Fingerprint properties
# ═══════════════════════════════════════════════════════════════════════════
# Set these to match your sensor position (override in config.env).
# Reference (A90 5G): X=540, Y=2145, Size=114

setprop persist.sys.phh.samsung_fingerprint 1
setprop persist.sys.udfps.custom 1
setprop persist.sys.udfps.x 540
setprop persist.sys.udfps.y 2145
setprop persist.sys.udfps.size 114

# ═══════════════════════════════════════════════════════════════════════════
# SECTION 6: Brightness fix (Samsung AMOLED panels)
# ═══════════════════════════════════════════════════════════════════════════

# Samsung panels need full_brightness to avoid gamma curve inversion
setprop persist.sys.samsung.full_brightness true
setprop persist.sys.qcom-brightness -1

# Brightness watchdog: some GSIs override these properties after boot
# Runs for 10 iterations (100s), then one final check after 60s
for i in 1 2 3 4 5 6 7 8 9 10; do
    sleep 10
    if [ "$(getprop persist.sys.samsung.full_brightness)" != "true" ]; then
        setprop persist.sys.samsung.full_brightness true
    fi
    if [ "$(getprop persist.sys.qcom-brightness)" != "-1" ]; then
        setprop persist.sys.qcom-brightness -1
    fi
    if [ "$(getprop persist.sys.phh.disable_display_doze_suspend)" != "true" ]; then
        setprop persist.sys.phh.disable_display_doze_suspend true
    fi
done

# Final long-delay check to catch late overrides
sleep 60
if [ "$(getprop persist.sys.samsung.full_brightness)" != "true" ]; then
    setprop persist.sys.samsung.full_brightness true
fi
if [ "$(getprop persist.sys.qcom-brightness)" != "-1" ]; then
    setprop persist.sys.qcom-brightness -1
fi
if [ "$(getprop persist.sys.phh.disable_display_doze_suspend)" != "true" ]; then
    setprop persist.sys.phh.disable_display_doze_suspend true
fi

# ═══════════════════════════════════════════════════════════════════════════
# SECTION 7: 5G / VoLTE / IMS
# ═══════════════════════════════════════════════════════════════════════════
# Uncomment/comment based on your device's RIL type.
# Samsung devices with libsec-ril.so use ims.sec.
# Qualcomm devices use ims.caf (default).

# --- Samsung IMS ---
setprop persist.sys.phh.ims.sec true

# --- 5G display ---
setprop persist.sys.phh.force_display_5g 1
setprop persist.sys.phh.radio.nr 1
setprop persist.dbg.volte_avail_ovr 1
setprop persist.dbg.allow_ims_off 0
settings put global preferred_network_mode 26

# Restart RIL to pick up new IMS properties
stop ril-daemon 2>/dev/null || true
sleep 2
start ril-daemon 2>/dev/null || true

# --- IMS overlays ---
# Enable Samsung LSI IMS telephony overlay
cmd overlay enable me.phh.treble.overlay.slsiims_telephony 2>/dev/null || true
# Disable Qualcomm CAF IMS (to avoid conflict)
cmd overlay disable me.phh.treble.overlay.cafims_telephony 2>/dev/null || true

# IMS watchdog: ensures IMS properties persist
for i in 1 2 3 4 5; do
    sleep 10
    if [ "$(getprop persist.sys.phh.ims.sec)" != "true" ]; then
        setprop persist.sys.phh.ims.sec true
        if [ "$i" = "1" ]; then
            stop ril-daemon 2>/dev/null || true
            sleep 2
            start ril-daemon 2>/dev/null || true
        fi
    fi
done
