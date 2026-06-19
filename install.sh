#!/system/bin/sh

# BurpSuiteCert KSU/ksu-next Installation Script
# This script is called during module flashing

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

log() {
    echo -e "${GREEN}[KSU-Install]${NC} $1"
}

error() {
    echo -e "${RED}[KSU-Install] ERROR:${NC} $1" >&2
}

warn() {
    echo -e "${YELLOW}[KSU-Install] WARN:${NC} $1"
}

# The install.sh script doesn't actually install the certificate
# That's handled by post-fs-data.sh during module boot-up
# This script just validates the module structure

log "Validating BurpSuiteCert module..."

# MODPATH is set by KSU/Magisk installer
if [ -z "$MODPATH" ]; then
    MODPATH="/data/adb/modules/burpsuite-cert"
fi

log "Module path: $MODPATH"

# Verify module structure
if [ ! -f "$MODPATH/post-fs-data.sh" ]; then
    error "post-fs-data.sh not found in module"
    exit 1
fi

if [ ! -f "$MODPATH/module.prop" ]; then
    error "module.prop not found in module"
    exit 1
fi

if [ ! -d "$MODPATH/system/etc/security/cacerts" ]; then
    error "Certificate directory not found in module"
    exit 1
fi

CERT_COUNT=$(find "$MODPATH/system/etc/security/cacerts" -type f | wc -l)
if [ "$CERT_COUNT" -eq 0 ]; then
    error "No certificates found in module"
    exit 1
fi

log "✓ Module structure validated"
log "✓ Found $CERT_COUNT certificate(s)"
log "✓ post-fs-data.sh found"
log "✓ module.prop found"

# Make scripts executable
chmod +x "$MODPATH/post-fs-data.sh" 2>/dev/null || true
chmod +x "$MODPATH/service.sh" 2>/dev/null || true

log "BurpSuiteCert module validation complete"
log "Certificate will be installed on next boot"
log "Reboot your device to activate the module"

exit 0
