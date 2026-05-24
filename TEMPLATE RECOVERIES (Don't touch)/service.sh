#!/sbin/sh
# =============================================================================
# Treble Overlay — Post-Boot Initialization Script (Template)
# =============================================================================
# This is a template for TEMPLATE RECOVERIES. During the build process,
# build.sh auto-generates the actual service.sh based on config.env values.
#
# If you need custom service.sh behavior (Samsung IMS, custom HAL startups, etc.):
#   1. Place a service.sh at the project root with @OVERLAY_PACKAGE@ and
#      @OVERLAY_PACKAGE_SYSTEMUI@ as placeholders for the package names
#   2. build.sh will detect it and substitute the placeholders automatically
#   3. See service.sh.example for a reference (Samsung Galaxy A90 5G)
# =============================================================================

while [ "$(getprop sys.boot_completed)" != "1" ]; do
    sleep 5
done

# Enable overlays (placeholders substituted by build.sh)
cmd overlay enable @OVERLAY_PACKAGE@ 2>/dev/null || true
cmd overlay enable @OVERLAY_PACKAGE_SYSTEMUI@ 2>/dev/null || true

# Add your device-specific properties and service starts below.
# See service.sh.example for a comprehensive reference.
