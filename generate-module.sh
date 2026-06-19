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
    if file "$file" | grep -q "DER"; then
        echo "DER"
    elif file "$file" | grep -q "PEM\|ASCII"; then
        echo "PEM"
    elif file "$file" | grep -q "data"; then
        # Could be DER or binary
        if head -c 2 "$file" | od -An -tx1 | grep -q "30 82"; then
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
    openssl x509 -inform PEM -in "$CERT_FILE" -outform DER -out "$CERT_DER"
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
CERT_HASH=$(openssl x509 -in "$CERT_DER" -inform DER -noout -subject_hash_old)
CERT_FILENAME="${CERT_HASH}.0"

log_info "Certificate hash: $CERT_HASH"
log_info "Certificate filename: $CERT_FILENAME"

# Create module structure
log_info "Creating module structure..."
MODULE_DIR="$WORK_DIR/$MODULE_NAME"
mkdir -p "$MODULE_DIR/system/etc/security/cacerts"
mkdir -p "$MODULE_DIR/META-INF"

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
cat > "$MODULE_DIR/module.prop" << EOF
id=burpsuite.cert
name=$MODULE_NAME
versionCode=20260619
versionName=1.0
author=$AUTHOR_NAME
description=Installs Burp Suite CA certificate for HTTPS interception. Simply add your certificate and flash!
minKernel=4.4
EOF

log_verbose "module.prop created"

# Create module.xml
log_info "Generating module.xml..."
cat > "$MODULE_DIR/module.xml" << 'EOF'
<?xml version="1.0" encoding="utf-8"?>
<module>
    <id>burpsuite.cert</id>
    <versionCode>20260619</versionCode>
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

# Create post-fs-data.sh
log_info "Generating post-fs-data.sh..."
cat > "$MODULE_DIR/post-fs-data.sh" << 'EOF'
#!/system/bin/sh

MODDIR=${0%/*}
MODNAME="BurpSuiteCert"

log_info() {
    echo "[BurpSuiteCert] $1"
}

log_error() {
    echo "[BurpSuiteCert ERROR] $1" >&2
}

log_info "Starting certificate injection..."

# Detect Android version
ANDROID_VERSION=$(getprop ro.build.version.sdk)
log_info "Android API Level: $ANDROID_VERSION"

# Ensure certificate directory exists
CERT_DIR="$MODDIR/system/etc/security/cacerts"
if [ ! -d "$CERT_DIR" ]; then
    log_error "Certificate directory not found: $CERT_DIR"
    exit 1
fi

# Set proper permissions
chmod 755 "$CERT_DIR"
chmod 644 "$CERT_DIR"/*
chown -R 0:0 "$CERT_DIR"

log_info "Certificate permissions set"

# For Android 11+ (APEX)
if [ "$ANDROID_VERSION" -ge 30 ]; then
    log_info "Android 11+: Using APEX injection method"
    
    # The systemless module handles APEX automatically via bind mount
    for pid in 1 $(pgrep zygote) $(pgrep zygote64) 2>/dev/null; do
        nsenter --mount="/proc/${pid}/ns/mnt" -- \
            mount --bind "$CERT_DIR" /system/etc/security/cacerts 2>/dev/null || true
    done
else
    log_info "Android 10 and below: Standard installation"
fi

log_info "Certificate injection complete!"
log_info "Configure WiFi proxy in device settings:"
log_info "  Settings → Network → WiFi → Edit → Advanced"
log_info "  Set Proxy Host and Port (8080)"

exit 0
EOF

chmod +x "$MODULE_DIR/post-fs-data.sh"
log_verbose "post-fs-data.sh created and made executable"

# Create META-INF/com/google/android/update-binary (required for KSU)
mkdir -p "$MODULE_DIR/META-INF/com/google/android"
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
1. Open Burp Suite on your PC
2. Ensure Proxy → Settings → Proxy Listeners has 0.0.0.0:8080
3. Open any app on your device (browser, social media, etc.)
4. Check if traffic appears in Burp's HTTP history

If no traffic appears:
- Verify WiFi proxy is correctly configured
- Restart the app
- Check device system settings → Security → Certificate authorities (should show Burp cert)
- Reboot the device

Author: $AUTHOR_NAME
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
cd "$MODULE_DIR"
zip -r -q "$WORK_DIR/$OUTPUT_ZIP" . -x "*.DS_Store" "*.git*"
cd - > /dev/null

# Move to current directory
cp "$WORK_DIR/$OUTPUT_ZIP" "./$OUTPUT_ZIP"

log_info "✅ Module created successfully!"
echo ""
echo -e "${GREEN}Module Details:${NC}"
echo "  Name: $MODULE_NAME"
echo "  Certificate: $CERT_FILENAME"
echo "  Author: $AUTHOR_NAME"
echo "  Output: $OUTPUT_ZIP"
echo "  Size: $(du -h "$OUTPUT_ZIP" | cut -f1)"
echo ""
echo -e "${BLUE}Next Steps:${NC}"
echo "  1. Transfer '$OUTPUT_ZIP' to your Android device"
echo "  2. Open KSU Manager → Modules → Install from storage"
echo "  3. Select the ZIP and reboot"
echo "  4. Configure WiFi proxy (see README for details)"
echo ""

exit 0
