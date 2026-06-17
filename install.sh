#!/system/bin/sh

# BurpSuiteCert KSU/ksu-next Installation Script
# This script installs the module for KSU/ksu-next, Magisk, or standard rooted devices

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

# Detect installation environment
log "Detecting installation environment..."

# Check for KSU/ksu-next
if [ -d "/data/adb/ksu" ] || [ -d "/data/ksu" ]; then
    INSTALL_TYPE="ksu"
    MODULE_DIR="/data/adb/ksu/modules/burpsuite-cert"
elif [ -d "/data/adb/modules/ksu" ]; then
    INSTALL_TYPE="ksu"
    MODULE_DIR="/data/adb/modules/ksu/modules/burpsuite-cert"
elif [ -d "/data/adb/modules" ] && [ "$MAGISK" ]; then
    INSTALL_TYPE="magisk"
    MODULE_DIR="/data/adb/modules/burpsuite-cert"
    warn "KSU not found, falling back to Magisk installation"
else
    INSTALL_TYPE="standard"
    MODULE_DIR="/system/burp_cert"
    warn "KSU/Magisk not found, installing to standard rooted location"
fi

log "Detected installation type: $INSTALL_TYPE"
log "Module will be installed to: $MODULE_DIR"

# Check if module is already installed
if [ -d "$MODULE_DIR" ] && [ -f "$MODULE_DIR/9a5ba575.0" ]; then
    warn "Module already installed at $MODULE_DIR"
    log "Skipping installation..."
    exit 0
fi

# Create module directory
log "Creating module directory: $MODULE_DIR"
mkdir -p "$MODULE_DIR"

# Copy the certificate file
log "Copying Burp Suite CA certificate..."
if [ ! -f "/system/etc/security/cacerts/9a5ba575.0" ]; then
    error "CA certificate not found at /system/etc/security/cacerts/9a5ba575.0"
    exit 1
fi

cp "/system/etc/security/cacerts/9a5ba575.0" "$MODULE_DIR/"

# Set permissions and ownership
log "Setting permissions..."
chmod 644 "$MODULE_DIR/9a5ba575.0"
chown 0:0 "$MODULE_DIR/9a5ba575.0"

# For KSU/ksu-next modules, additional setup may be needed
if [ "$INSTALL_TYPE" = "ksu" ]; then
    log "KSU/ksu-next detected - additional setup complete"
    # KSU-specific setup can be added here
elif [ "$INSTALL_TYPE" = "magisk" ]; then
    log "Magisk detected - module ready for Magisk manager"
else
    log "Standard installation complete"
fi

log "BurpSuiteCert installation complete!"
log "Reboot your device to activate the module"
log "Module ID: ksu.00000001 (for reference)"

exit 0