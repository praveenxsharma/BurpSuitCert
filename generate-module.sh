#!/bin/bash

# BurpSuiteCert Module Generator
# Automatically converts your Burp certificate to a flashable KSU module
# Usage: bash generate-module.sh [--cert path/to/cert] [--name ModuleName] [--author "Your Name"]

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Configuration
CERT_FILE=""
MODULE_NAME="BurpSuiteCert"
AUTHOR_NAME="Praveen Sharma"
OUTPUT_ZIP="BurpSuiteCert.zip"
WORK_DIR=$(mktemp -d)
VERBOSE=0
DRY_RUN=0
CERT_HASH=""
CERT_FILENAME=""

# Functions
print_header() {
    echo -e "${BLUE}=== BurpSuiteCert Module Generator ===${NC}"
}

log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1" >&2
}

log_verbose() {
    if [ "$VERBOSE" -eq 1 ]; then
        echo -e "${BLUE}[DEBUG]${NC} $1"
    fi
}

cleanup() {
    if [ -d "$WORK_DIR" ]; then
        log_verbose "Cleaning up temporary directory: $WORK_DIR"
        rm -rf "$WORK_DIR"
    fi
}

trap cleanup EXIT

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --cert)
            CERT_FILE="$2"
            shift 2
            ;;
        --name)
            MODULE_NAME="$2"
            shift 2
            ;;
        --author)
            AUTHOR_NAME="$2"
            shift 2
            ;;
        --output)
            OUTPUT_ZIP="$2"
            shift 2
            ;;
        --verbose)
            VERBOSE=1
            shift
            ;;
        --dry-run)
            DRY_RUN=1
            shift
            ;;
        *)
            log_error "Unknown option: $1"
            exit 1
            ;;
    esac
done

print_header

# Interactive input if cert not provided
if [ -z "$CERT_FILE" ]; then
    echo ""
    echo "📜 Burp Suite Certificate Input"
    read -p "Enter path to your Burp certificate (DER/PEM/P12): " CERT_FILE
fi

# Validate certificate file
if [ ! -f "$CERT_FILE" ]; then
    log_error "Certificate file not found: $CERT_FILE"
    exit 1
fi

log_info "Using certificate: $CERT_FILE"

# Detect certificate format
detect_cert_format() {
    local file="$1"
    
    # Check file headers
    if file "$file" | grep -q "DER\|Certificate"; then
        echo "DER"
    elif file "$file" | grep -q "PEM\|ASCII"; then
        echo "PEM"
    elif file "$file" | grep -q "data"; then
        # Could be DER or binary
        if head -c 2 "$file" | od -An -tx1 | grep -q "30 82\|30 81"; then
            echo "DER"
        else
            echo "BINARY"
        fi
    else
        echo "UNKNOWN"
    fi
}

CERT_FORMAT=$(detect_cert_format "$CERT_FILE")
log_info "Detected certificate format: $CERT_FORMAT"

# Convert to DER if needed
CERT_DER="$WORK_DIR/burp-cert.der"

if [ "$CERT_FORMAT" = "PEM" ]; then
    log_info "Converting PEM to DER..."
    if ! openssl x509 -inform PEM -in "$CERT_FILE" -outform DER -out "$CERT_DER" 2>/dev/null; then
        log_error "Failed to convert PEM to DER. Check certificate format."
        exit 1
    fi
elif [ "$CERT_FORMAT" = "DER" ] || [ "$CERT_FORMAT" = "BINARY" ]; then
    cp "$CERT_FILE" "$CERT_DER"
else
    log_error "Unable to determine certificate format"
    exit 1
fi

# Verify certificate
log_info "Verifying certificate..."
if ! openssl x509 -in "$CERT_DER" -inform DER -noout >/dev/null 2>&1; then
    log_error "Certificate verification failed. Is it a valid X.509 certificate?"
    exit 1
fi

# Get certificate hash
log_verbose "Generating certificate hash..."
if ! CERT_HASH=$(openssl x509 -in "$CERT_DER" -inform DER -noout -subject_hash_old 2>/dev/null); then
    log_error "Failed to generate certificate hash"
    exit 1
fi

if [ -z "$CERT_HASH" ]; then
    log_error "Certificate hash is empty - invalid certificate"
    exit 1
fi

CERT_FILENAME="${CERT_HASH}.0"

log_info "Certificate hash: $CERT_HASH"
log_info "Certificate filename: $CERT_FILENAME"

# Create module structure
log_info "Creating module structure..."
MODULE_DIR="$WORK_DIR/$MODULE_NAME"
mkdir -p "$MODULE_DIR/system/etc/security/cacerts"
mkdir -p "$MODULE_DIR/META-INF/com/google/android"

log_verbose "Module directory: $MODULE_DIR"

# Copy certificate
cp "$CERT_DER" "$MODULE_DIR/system/etc/security/cacerts/$CERT_FILENAME"
log_verbose "Certificate copied to module"

# Try to copy system certificates
log_info "Gathering system certificates..."
if command -v adb &> /dev/null; then
    log_verbose "ADB found, attempting to pull system certificates..."
    adb pull /system/etc/security/cacerts/ "$MODULE_DIR/system/etc/security/cacerts/" 2>/dev/null || true
fi

# Create module.prop
log_info "Generating module.prop..."
CURRENT_DATE=$(date +%Y%m%d)
cat > "$MODULE_DIR/module.prop" << EOF
id=burpsuite.cert
name=$MODULE_NAME
versionCode=$CURRENT_DATE
versionName=1.0
author=$AUTHOR_NAME
description=Installs Burp Suite CA certificate for HTTPS interception
minKernel=4.4
propVersion=2
EOF

log_verbose "module.prop created"

# Create module.xml
log_info "Generating module.xml..."
cat > "$MODULE_DIR/module.xml" << 'EOF'
<?xml version="1.0" encoding="utf-8"?>
<module>
    <id>burpsuite.cert</id>
    <versionCode>1</versionCode>
    <versionName>1.0</versionName>
    <name>BurpSuiteCert</name>
    <author>Praveen Sharma</author>
    <targetApi>31</targetApi>
    <minKernel>4.4</minKernel>
    
    <properties>
        <name>ksu</name>
        <version>minimum</version>
    </properties>
    
    <hooks>
        <hook>
            <name>post-fs-data</name>
            <path>post-fs-data.sh</path>
            <run_at>post-fs-data</run_at>
        </hook>
    </hooks>
</module>
EOF

log_verbose "module.xml created"

# Create post-fs-data.sh with DYNAMIC certificate hash
log_info "Generating post-fs-data.sh..."
cat > "$MODULE_DIR/post-fs-data.sh" << EOF
#!/system/bin/sh

# BurpSuiteCert Module for KSU/ksu-next - Installs CA certificates
# This script runs after filesystem is mounted
# WARNING: This file is auto-generated. Do not edit manually.

MODDIR=\${0%/*}
MODNAME="BurpSuiteCert"
CERT_HASH="$CERT_HASH"
CERT_FILENAME="\${CERT_HASH}.0"
CERT_FILE="\$MODDIR/system/etc/security/cacerts/\$CERT_FILENAME"

log_info() {
    echo "[BurpSuiteCert] \$1"
}

log_error() {
    echo "[BurpSuiteCert ERROR] \$1" >&2
}

log_info "Starting certificate injection..."
log_info "Looking for certificate: \$CERT_FILENAME"

# Check if certificate file exists in module
if [ ! -f "\$CERT_FILE" ]; then
    log_error "Certificate not found at: \$CERT_FILE"
    log_error "Available certificates:"
    ls -la "\$MODDIR/system/etc/security/cacerts/" 2>/dev/null || log_error "Directory not found"
    exit 1
fi

log_info "Certificate found: \$CERT_FILENAME"

# Detect Android version
ANDROID_VERSION=\$(getprop ro.build.version.sdk)
log_info "Android API Level: \$ANDROID_VERSION"

# Ensure certificate directory exists
CERT_DIR="\$MODDIR/system/etc/security/cacerts"
if [ ! -d "\$CERT_DIR" ]; then
    log_error "Certificate directory not found: \$CERT_DIR"
    exit 1
fi

# Set proper permissions on all certificates
log_info "Setting certificate permissions..."
chmod 755 "\$CERT_DIR" 2>/dev/null || log_error "Failed to set directory permissions"
for cert in "\$CERT_DIR"/*; do
    if [ -f "\$cert" ]; then
        chmod 644 "\$cert" 2>/dev/null || true
        chown 0:0 "\$cert" 2>/dev/null || true
    fi
done

log_info "Certificate permissions configured"

# For Android 11+ (API 30+) - APEX handling
if [ "\$ANDROID_VERSION" -ge 30 ]; then
    log_info "Detected Android 11+ (API \$ANDROID_VERSION): KSU systemless module will handle APEX"
else
    log_info "Detected Android 10 or lower (API \$ANDROID_VERSION): Standard certificate installation"
fi

log_info "✅ Certificate injection complete!"
log_info ""
log_info "NEXT: Configure WiFi proxy in device settings:"
log_info "  1. Settings → Network & Internet → WiFi"
log_info "  2. Long-press your WiFi network → Edit"
log_info "  3. Expand Advanced options"
log_info "  4. Proxy: Manual"
log_info "  5. Proxy hostname: Your PC IP (running Burp)"
log_info "  6. Proxy port: 8080"
log_info "  7. Save and reconnect"

exit 0
EOF

chmod +x "$MODULE_DIR/post-fs-data.sh"
log_verbose "post-fs-data.sh created and made executable"

# Create META-INF/com/google/android/update-binary (required for KSU)
cat > "$MODULE_DIR/META-INF/com/google/android/update-binary" << 'EOF'
#!/sbin/sh
OUTFD=$2
ZIPFILE=$3

ui_print() {
  echo "ui_print $1" >> /proc/self/fd/$OUTFD
  echo "ui_print" >> /proc/self/fd/$OUTFD
}

ui_print "Installing BurpSuiteCert..."
ui_print "Extracting files..."

unzip -o "$ZIPFILE" -d /tmp/burpsuite_install

if [ $? -eq 0 ]; then
  ui_print "Installation successful!"
else
  ui_print "Installation failed!"
  exit 1
fi

exit 0
EOF

chmod +x "$MODULE_DIR/META-INF/com/google/android/update-binary"

# Create INSTALL_GUIDE.txt
cat > "$MODULE_DIR/INSTALL_GUIDE.txt" << EOF
=== BurpSuiteCert Module ===

INSTALLATION:
1. Copy this ZIP to your phone
2. Open KSU Manager → Modules → Install from storage
3. Select this ZIP and tap Install
4. Reboot your device

CONFIGURATION:
1. Settings → Network & Internet → WiFi
2. Long-press your WiFi → Edit
3. Expand Advanced options
4. Set Proxy:
   - Host: Your PC IP (where Burp is running)
   - Port: 8080
5. Save and reconnect

VERIFICATION:
1. Go to Settings → Security → Certificate authorities
2. Look for "PortSwigger" or your certificate subject name
3. Open Burp Suite on your PC
4. Ensure Proxy → Settings → Proxy Listeners has 0.0.0.0:8080
5. Open any app on your device (browser, social media, etc.)
6. Check if traffic appears in Burp's HTTP history

If no traffic appears:
- Verify WiFi proxy is correctly configured in device settings
- Restart the app you want to intercept
- Check device system settings → Security → Certificate authorities (should show Burp cert)
- Reboot the device
- Verify Burp listener is running and accessible on 0.0.0.0:8080

Generated: $(date)
Certificate Hash: $CERT_HASH
Certificate Filename: $CERT_FILENAME
EOF

# If dry run, show what would be created
if [ "$DRY_RUN" -eq 1 ]; then
    log_warn "DRY RUN MODE - No files were created"
    echo ""
    echo "Would create the following structure:"
    find "$MODULE_DIR" -type f | sort
    exit 0
fi

# Create ZIP
log_info "Creating flashable ZIP module..."
cd "$MODULE_DIR" || exit 1
if ! zip -r -q "$WORK_DIR/$OUTPUT_ZIP" . -x "*.DS_Store" "*.git*" 2>/dev/null; then
    log_error "Failed to create ZIP file"
    exit 1
fi
cd - > /dev/null

# Move to current directory
if ! cp "$WORK_DIR/$OUTPUT_ZIP" "./$OUTPUT_ZIP"; then
    log_error "Failed to copy ZIP to current directory"
    exit 1
fi

log_info "✅ Module created successfully!"
echo ""
echo -e "${GREEN}Module Details:${NC}"
echo "  Name: $MODULE_NAME"
echo "  Certificate: $CERT_FILENAME"
echo "  Certificate Hash: $CERT_HASH"
echo "  Author: $AUTHOR_NAME"
echo "  Output: $OUTPUT_ZIP"
echo "  Size: $(du -h "$OUTPUT_ZIP" | cut -f1)"
echo ""
echo -e "${BLUE}Next Steps:${NC}"
echo "  1. Transfer '$OUTPUT_ZIP' to your Android device"
echo "  2. Open KSU Manager → Modules → Install from storage"
echo "  3. Select the ZIP and reboot"
echo "  4. Verify certificate in Settings → Security → Certificate authorities"
echo "  5. Configure WiFi proxy (see INSTALL_GUIDE.txt for details)"
echo ""

exit 0
