#!/system/bin/sh

# BurpSuiteCert Module for KSU/ksu-next - Installs CA certificates
# This script runs after filesystem is mounted

MODDIR=${0%/*}
MODNAME="BurpSuiteCert"
CERT_FILE="$MODDIR/system/etc/security/cacerts/9a5ba575.0"

log_info() {
    echo "[BurpSuiteCert] $1"
}

log_error() {
    echo "[BurpSuiteCert ERROR] $1" >&2
}

log_info "Starting BurpSuiteCert installation..."

# Check if certificate file exists in module
if [ ! -f "$CERT_FILE" ]; then
    log_error "Certificate not found at: $CERT_FILE"
    exit 1
fi

log_info "Certificate found at: $CERT_FILE"

# Detect Android version
ANDROID_VERSION=$(getprop ro.build.version.sdk)
log_info "Android API Level: $ANDROID_VERSION"

# For Android 10 and above, we need to handle APEX certificates
if [ "$ANDROID_VERSION" -ge 30 ]; then
    log_info "Detected Android 11+, setting up APEX injection..."
    
    # Create system CA directory override
    SYSTEM_CA_DIR="/system/etc/security/cacerts"
    mkdir -p "$MODDIR/system/etc/security/cacerts"
    
    # Copy existing system certificates
    if [ -d "$SYSTEM_CA_DIR" ]; then
        log_info "Copying system certificates..."
        for cert in "$SYSTEM_CA_DIR"/*.0 "$SYSTEM_CA_DIR"/*.pem; do
            if [ -f "$cert" ]; then
                cp "$cert" "$MODDIR/system/etc/security/cacerts/" 2>/dev/null
            fi
        done
    fi
    
    # Ensure Burp certificate is in the directory
    if [ ! -f "$MODDIR/system/etc/security/cacerts/9a5ba575.0" ]; then
        cp "$CERT_FILE" "$MODDIR/system/etc/security/cacerts/"
    fi
    
    # Set proper permissions
    chmod 644 "$MODDIR/system/etc/security/cacerts"/*
    chown 0:0 "$MODDIR/system/etc/security/cacerts"/*
    
    log_info "APEX certificate override prepared"
else
    # For Android 10 and below
    log_info "Detected Android 10 or lower, using standard installation..."
    mkdir -p "$MODDIR/system/etc/security/cacerts"
    
    # Copy system certificates if they exist
    if [ -d "/system/etc/security/cacerts" ]; then
        cp "/system/etc/security/cacerts"/* "$MODDIR/system/etc/security/cacerts/" 2>/dev/null
    fi
    
    # Ensure Burp certificate is present
    if [ ! -f "$MODDIR/system/etc/security/cacerts/9a5ba575.0" ]; then
        cp "$CERT_FILE" "$MODDIR/system/etc/security/cacerts/"
    fi
    
    chmod 644 "$MODDIR/system/etc/security/cacerts"/*
    chown 0:0 "$MODDIR/system/etc/security/cacerts"/*
fi

log_info "Certificate installation complete!"
log_info "IMPORTANT: Configure Burp proxy in device settings:"
log_info "  1. Go to Settings → Network & Internet → WiFi"
log_info "  2. Long-press your WiFi → Modify"
log_info "  3. Set Burp Suite host IP and port (8080)"
log_info "  4. Restart the apps you want to intercept"

exit 0
