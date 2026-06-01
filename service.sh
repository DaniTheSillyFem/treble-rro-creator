#!/sbin/sh
# =============================================================================
# Treble Overlay — Post-Boot Initialization Script (Universal Template)
# =============================================================================
# build.sh substitutes @OVERLAY_PACKAGE@ placeholders automatically.
#
# HOW IT WORKS:
#   1. Waits for boot_completed
#   2. Enables the overlay APKs
#   3. Sections below are examples — uncomment what you need
#
# CUSTOMIZATION:
#   • Edit this file to add device-specific properties and service starts.
#   • @OVERLAY_PACKAGE@ and @OVERLAY_PACKAGE_SYSTEMUI@ are placeholders —
#     build.sh replaces them with your config.env package names.
#   • See service.sh.example for a complete Samsung A90 5G reference.
#   • If your device needs a simple setup, just delete this file (or leave
#     the overlay enable section) and build.sh will auto-generate a
#     comprehensive service.sh from config.env values.
# =============================================================================

# ═══════════════════════════════════════════════════════════════════════════
# SECTION 1: Wait for boot
# ═══════════════════════════════════════════════════════════════════════════
while [ "$(getprop sys.boot_completed)" != "1" ]; do
    sleep 5
done

# ═══════════════════════════════════════════════════════════════════════════
# SECTION 2: Enable overlays (placeholders → your package names)
# ═══════════════════════════════════════════════════════════════════════════
cmd overlay enable @OVERLAY_PACKAGE@ 2>/dev/null || true
cmd overlay enable @OVERLAY_PACKAGE_SYSTEMUI@ 2>/dev/null || true

# ═══════════════════════════════════════════════════════════════════════════
# UNCOMMENT SECTIONS BELOW AS NEEDED FOR YOUR DEVICE
# ═══════════════════════════════════════════════════════════════════════════

# --- AOD / Doze (uncomment if your device supports AOD/doze) ---
# setprop persist.sys.overlay.aod true
# setprop persist.sys.phh.disable_display_doze_suspend true

# --- UDFPS Fingerprint (uncomment and set your sensor coordinates) ---
# setprop persist.sys.udfps.custom 1
# setprop persist.sys.udfps.x <X_POSITION>
# setprop persist.sys.udfps.y <Y_POSITION>
# setprop persist.sys.udfps.size <RADIUS>
# setprop persist.sys.phh.samsung_fingerprint 1   # Samsung Goodix sensors only

# --- Brightness / Display fixes ---
# setprop persist.sys.samsung.full_brightness true  # Samsung AMOLED panels
# setprop persist.sys.qcom-brightness -1

# --- Connectivity (5G / VoLTE) ---
# setprop persist.sys.phh.force_display_5g 1
# setprop persist.sys.phh.radio.nr 1
# setprop persist.dbg.volte_avail_ovr 1
# setprop persist.dbg.allow_ims_off 0
# settings put global preferred_network_mode 26

# --- Samsung IMS (uncomment for Samsung devices with libsec-ril.so) ---
# setprop persist.sys.phh.ims.sec true
# cmd overlay enable me.phh.treble.overlay.slsiims_telephony 2>/dev/null || true
# cmd overlay disable me.phh.treble.overlay.cafims_telephony 2>/dev/null || true

# --- Vendor HAL services (guard with file existence checks) ---
# if [ -f "/system/vendor/bin/hw/<your_fingerprint_hal>" ]; then
#     start <your_fingerprint_service> 2>/dev/null || true
# fi
# if [ -f "/system/vendor/bin/hw/<your_vibrator_hal>" ]; then
#     start <your_vibrator_service> 2>/dev/null || true
# fi
