#!/system/bin/sh

# BurpSuiteCert Module for KSU/ksu-next - Installs CA certificates
# This script is executed during module boot-up

MODDIR=${0%/*}
MODNAME="BurpSuiteCert"

log_info() {
    echo "[BurpSuiteCert] $1"
}

log_error() {
    echo "[BurpSuiteCert ERROR] $1" >&2
}

log_info "Starting BurpSuiteCert certificate injection..."

# Get Android API level
ANDROID_VERSION=$(getprop ro.build.version.sdk)
log_info "Detected Android API level: $ANDROID_VERSION"

# Define certificate directory
CERT_SOURCE_DIR="$MODDIR/system/etc/security/cacerts"
CERT_DEST_DIR="/system/etc/security/cacerts"

# Check if source certificate exists
if [ ! -d "$CERT_SOURCE_DIR" ]; then
    log_error "Certificate directory not found at $CERT_SOURCE_DIR"
    log_error "Module installation may be incomplete"
    exit 1
fi

# Count certificates in source
CERT_COUNT=$(find "$CERT_SOURCE_DIR" -type f | wc -l)
if [ "$CERT_COUNT" -eq 0 ]; then
    log_error "No certificates found in $CERT_SOURCE_DIR"
    exit 1
fi

log_info "Found $CERT_COUNT certificate(s) in module"

# Create destination directory
mkdir -p "$CERT_DEST_DIR" 2>/dev/null || log_error "Failed to create $CERT_DEST_DIR"

# Copy all certificates from module to system
log_info "Installing certificates..."
for cert in "$CERT_SOURCE_DIR"/*; do
    if [ -f "$cert" ]; then
        cert_name=$(basename "$cert")
        log_info "Installing certificate: $cert_name"
        
        # Copy certificate
        if cp "$cert" "$CERT_DEST_DIR/$cert_name" 2>/dev/null; then
            chmod 644 "$CERT_DEST_DIR/$cert_name" 2>/dev/null || true
            chown 0:0 "$CERT_DEST_DIR/$cert_name" 2>/dev/null || true
            log_info "✓ Successfully installed: $cert_name"
        else
            log_error "Failed to copy $cert_name"
        fi
    fi
done

# Set proper permissions on directory
chmod 755 "$CERT_DEST_DIR" 2>/dev/null || log_error "Failed to set directory permissions"

# Verify installation
log_info "Verifying certificate installation..."
INSTALLED_COUNT=$(find "$CERT_DEST_DIR" -type f | wc -l)
log_info "Total certificates in system store: $INSTALLED_COUNT"

# For Android 11+ (API 30+) - APEX handling note
if [ "$ANDROID_VERSION" -ge 30 ]; then
    log_info "Detected Android 11+ (API $ANDROID_VERSION): Using KSU systemless module"
else
    log_info "Detected Android 10 or lower (API $ANDROID_VERSION): Standard certificate installation"
fi

log_info "✅ Certificate injection complete!"
log_info "Device may need reboot for certificate to appear in Settings"

exit 0
