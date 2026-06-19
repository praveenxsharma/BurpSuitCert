#!/bin/bash

# BurpSuiteCert Module Generator
# Converts Burp Suite CA certificate to KSU/ksu-next/Magisk module

set -e

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info() {
    echo -e "${GREEN}[Generator]${NC} $1"
}

log_error() {
    echo -e "${RED}[Generator] ERROR:${NC} $1" >&2
}

log_warn() {
    echo -e "${YELLOW}[Generator] WARN:${NC} $1"
}

log_verbose() {
    echo -e "${BLUE}[Generator]${NC} $1"
}

show_help() {
    cat << EOF
BurpSuiteCert Module Generator

Usage: $0 [OPTIONS]

OPTIONS:
  -c, --cert FILE           Path to Burp Suite certificate (DER, PEM, or P12)
  -o, --output DIR          Output directory (default: current directory)
  -n, --name NAME           Module name (default: BurpSuiteCert)
  -a, --author NAME         Author name (default: Praveen Sharma)
  -h, --help                Show this help message

EXAMPLES:
  $0 --cert burp-cert.der
  $0 -c burp-cert.pem -o ./output
  $0 -c burp-cert.p12 -n MyBurpCert -a "Your Name"

EOF
    exit 0
}

# Default values
CERT_FILE=""
OUTPUT_DIR="."
MODULE_NAME="BurpSuiteCert"
AUTHOR="Praveen Sharma"
MODULE_ID="ksu.burpsuite"

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -c|--cert)
            CERT_FILE="$2"
            shift 2
            ;;
        -o|--output)
            OUTPUT_DIR="$2"
            shift 2
            ;;
        -n|--name)
            MODULE_NAME="$2"
            shift 2
            ;;
        -a|--author)
            AUTHOR="$2"
            shift 2
            ;;
        -h|--help)
            show_help
            ;;
        *)
            log_error "Unknown option: $1"
            echo "Use --help for usage information"
            exit 1
            ;;
    esac
done

# Interactive mode if no certificate provided
if [ -z "$CERT_FILE" ]; then
    log_info "No certificate specified. Starting interactive mode..."
    echo ""
    read -p "Enter path to your Burp certificate: " CERT_FILE
fi

# Validate certificate file
if [ ! -f "$CERT_FILE" ]; then
    log_error "Certificate file not found: $CERT_FILE"
    exit 1
fi

log_info "Certificate file: $CERT_FILE"

# Check if OpenSSL is available
if ! command -v openssl &> /dev/null; then
    log_error "OpenSSL not found. Please install it first."
    log_error "On Ubuntu/Debian: sudo apt-get install openssl"
    log_error "On macOS: brew install openssl"
    exit 1
fi

log_verbose "OpenSSL found"

# Create temporary directory
TEMP_DIR=$(mktemp -d)
trap "rm -rf $TEMP_DIR" EXIT

log_verbose "Created temporary directory: $TEMP_DIR"

# Detect certificate format and convert to DER
log_info "Detecting certificate format..."

CERT_FORMAT="unknown"
if file "$CERT_FILE" | grep -q "DER"; then
    CERT_FORMAT="der"
    log_verbose "Detected format: DER"
elif openssl x509 -in "$CERT_FILE" -text -noout &>/dev/null 2>&1; then
    CERT_FORMAT="pem"
    log_verbose "Detected format: PEM"
elif openssl pkcs12 -in "$CERT_FILE" -password pass: -passin pass: &>/dev/null 2>&1; then
    CERT_FORMAT="p12"
    log_verbose "Detected format: PKCS12"
else
    # Try reading as DER
    if openssl x509 -inform DER -in "$CERT_FILE" -text -noout &>/dev/null 2>&1; then
        CERT_FORMAT="der"
        log_verbose "Detected format: DER (after retry)"
    fi
fi

log_info "Certificate format: $CERT_FORMAT"

# Convert to DER if needed
DER_CERT="$TEMP_DIR/cert.der"

case $CERT_FORMAT in
    der)
        cp "$CERT_FILE" "$DER_CERT"
        log_verbose "Certificate already in DER format"
        ;;
    pem)
        log_info "Converting PEM to DER..."
        if ! openssl x509 -in "$CERT_FILE" -outform DER -out "$DER_CERT" 2>/dev/null; then
            log_error "Failed to convert PEM to DER"
            exit 1
        fi
        log_verbose "PEM conversion successful"
        ;;
    p12)
        log_info "Converting PKCS12 to DER..."
        if ! openssl pkcs12 -in "$CERT_FILE" -clcerts -nokeys -out "$TEMP_DIR/cert.pem" -password pass: -passin pass: 2>/dev/null; then
            log_error "Failed to extract certificate from PKCS12"
            exit 1
        fi
        if ! openssl x509 -in "$TEMP_DIR/cert.pem" -outform DER -out "$DER_CERT" 2>/dev/null; then
            log_error "Failed to convert PKCS12 to DER"
            exit 1
        fi
        log_verbose "PKCS12 conversion successful"
        ;;
    unknown)
        log_error "Could not determine certificate format"
        log_error "Supported formats: DER, PEM, PKCS12"
        exit 1
        ;;
esac

# Generate OpenSSL hash for certificate filename
log_info "Generating certificate hash..."
CERT_HASH=$(openssl x509 -inform DER -in "$DER_CERT" -subject_hash_old -noout 2>/dev/null)
if [ $? -ne 0 ]; then
    log_warn "Failed to generate hash with old algorithm, trying standard algorithm..."
    CERT_HASH=$(openssl x509 -inform DER -in "$DER_CERT" -subject_hash -noout 2>/dev/null)
fi

if [ -z "$CERT_HASH" ]; then
    log_error "Failed to generate certificate hash"
    exit 1
fi

CERT_FILENAME="${CERT_HASH}.0"
log_info "Certificate hash: $CERT_HASH"
log_info "Certificate filename: $CERT_FILENAME"

# Extract certificate subject
CERT_SUBJECT=$(openssl x509 -inform DER -in "$DER_CERT" -subject -noout | sed 's/^subject=//' || echo "Unknown")
log_verbose "Certificate subject: $CERT_SUBJECT"

# Create module directory structure
MODULE_DIR="$OUTPUT_DIR/$MODULE_NAME"
log_info "Creating module directory: $MODULE_DIR"

mkdir -p "$MODULE_DIR"
mkdir -p "$MODULE_DIR/system/etc/security/cacerts"
mkdir -p "$MODULE_DIR/META-INF/com/google/android"

log_verbose "Directory structure created"

# Copy certificate to module
log_info "Installing certificate to module..."
cp "$DER_CERT" "$MODULE_DIR/system/etc/security/cacerts/$CERT_FILENAME"
chmod 644 "$MODULE_DIR/system/etc/security/cacerts/$CERT_FILENAME"

log_verbose "Certificate installed: $MODULE_DIR/system/etc/security/cacerts/$CERT_FILENAME"

# Create post-fs-data.sh with correct hash
log_info "Generating post-fs-data.sh..."
cat > "$MODULE_DIR/post-fs-data.sh" << 'POSTFS_EOF'
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
POSTFS_EOF

chmod +x "$MODULE_DIR/post-fs-data.sh"
log_verbose "post-fs-data.sh created"

# Create install.sh
log_info "Generating install.sh..."
cat > "$MODULE_DIR/install.sh" << 'INSTALL_EOF'
#!/system/bin/sh

# BurpSuiteCert KSU/ksu-next Installation Script
# This script is called during module flashing

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log() {
    echo -e "${GREEN}[KSU-Install]${NC} $1"
}

error() {
    echo -e "${RED}[KSU-Install] ERROR:${NC} $1" >&2
}

log "Validating BurpSuiteCert module..."

if [ -z "$MODPATH" ]; then
    MODPATH="/data/adb/modules/burpsuite-cert"
fi

log "Module path: $MODPATH"

if [ ! -f "$MODPATH/post-fs-data.sh" ]; then
    error "post-fs-data.sh not found"
    exit 1
fi

if [ ! -f "$MODPATH/module.prop" ]; then
    error "module.prop not found"
    exit 1
fi

if [ ! -d "$MODPATH/system/etc/security/cacerts" ]; then
    error "Certificate directory not found"
    exit 1
fi

CERT_COUNT=$(find "$MODPATH/system/etc/security/cacerts" -type f | wc -l)
if [ "$CERT_COUNT" -eq 0 ]; then
    error "No certificates found in module"
    exit 1
fi

log "✓ Module structure validated"
log "✓ Found $CERT_COUNT certificate(s)"
log "Certificate will be installed on next boot"
log "Reboot your device to activate the module"

chmod +x "$MODPATH/post-fs-data.sh" 2>/dev/null || true

exit 0
INSTALL_EOF

chmod +x "$MODULE_DIR/install.sh"
log_verbose "install.sh created"

# Generate version code (YYYYMMDDHH format)
VERSION_CODE=$(date +%Y%m%d%H)
VERSION_NAME="1.0"

# Create module.prop
log_info "Generating module.prop..."
cat > "$MODULE_DIR/module.prop" << MODULE_PROP_EOF
id=$MODULE_ID
name=$MODULE_NAME
versionCode=$VERSION_CODE
versionName=$VERSION_NAME
description=Adds Burp Suite CA certificate for HTTPS interception. Supports KSU/ksu-next, Magisk, and rooted devices.
author=$AUTHOR
supports=arm64-v8a,armeabi-v7a,x86,x86_64
minKernel=4.4
propVersion=2
MODULE_PROP_EOF

log_verbose "module.prop created"

# Create META-INF update-binary for KSU compatibility
log_info "Creating META-INF structure..."
cat > "$MODULE_DIR/META-INF/com/google/android/update-binary" << 'UPDATE_BINARY_EOF'
#!/sbin/sh
OUTFD=$2
ZIPFILE=$3

ui_print() {
  echo "ui_print $1" >> /proc/self/fd/$OUTFD
  echo "ui_print" >> /proc/self/fd/$OUTFD
}

ui_print "Installing BurpSuiteCert..."
ui_print "Certificate will be installed on next boot"
ui_print "Reboot your device to activate the module"

exit 0
UPDATE_BINARY_EOF

chmod +x "$MODULE_DIR/META-INF/com/google/android/update-binary"
log_verbose "META-INF structure created"

# Create updater-script (minimal, required by some systems)
log_info "Creating updater-script..."
cat > "$MODULE_DIR/META-INF/com/google/android/updater-script" << 'UPDATER_SCRIPT_EOF'
install_module();
UPDATER_SCRIPT_EOF

log_verbose "updater-script created"

# Create module.xml for KSU
log_info "Generating module.xml..."
cat > "$MODULE_DIR/module.xml" << MODULE_XML_EOF
<?xml version="1.0" encoding="utf-8"?>
<manifest>
    <properties>
        <id>$MODULE_ID</id>
        <name>$MODULE_NAME</name>
        <version>$VERSION_NAME</version>
        <versionCode>$VERSION_CODE</versionCode>
        <author>$AUTHOR</author>
        <description>Adds Burp Suite CA certificate for HTTPS interception</description>
    </properties>
    <compatible>
        <minApi>24</minApi>
        <maxApi>99</maxApi>
    </compatible>
</manifest>
MODULE_XML_EOF

log_verbose "module.xml created"

# Create README for reference
log_info "Creating README..."
cat > "$MODULE_DIR/README.md" << 'README_EOF'
# BurpSuiteCert Module

Automatically generated module for Burp Suite CA certificate installation.

## Installation

1. Copy this folder to your KSU modules directory: `/data/adb/ksu/modules/`
2. Or use KSU Manager → Modules → Install from storage
3. Reboot your device
4. Certificate will appear in Settings → Security → Certificate authorities

## Proxy Configuration

1. Settings → Network & Internet → WiFi
2. Long-press your WiFi network → Edit
3. Expand Advanced options
4. Proxy: Manual
5. Proxy hostname: Your PC's IP (running Burp Suite)
6. Proxy port: 8080
7. Save and reconnect

## Verification

- Open Burp Suite on your PC
- Configure listener on 0.0.0.0:8080
- Open any app on your device
- Check if traffic appears in Burp Suite HTTP history

README_EOF

log_verbose "README.md created"

# Create the final ZIP module
ZIP_NAME="${MODULE_NAME}.zip"
ZIP_PATH="$OUTPUT_DIR/$ZIP_NAME"

log_info "Creating flashable ZIP module: $ZIP_NAME"

cd "$MODULE_DIR"
if ! zip -r -q "$ZIP_PATH" .; then
    log_error "Failed to create ZIP file"
    exit 1
fi
cd - > /dev/null

if [ ! -f "$ZIP_PATH" ]; then
    log_error "ZIP file was not created"
    exit 1
fi

ZIP_SIZE=$(ls -lh "$ZIP_PATH" | awk '{print $5}')
log_verbose "ZIP file created: $ZIP_SIZE"

# Display summary
echo ""
echo "========================================"
echo -e "${GREEN}✅ Module Generation Complete!${NC}"
echo "========================================"
echo -e "Module Name:      ${BLUE}$MODULE_NAME${NC}"
echo -e "Certificate:      ${BLUE}$CERT_FILENAME${NC}"
echo -e "Certificate Hash: ${BLUE}$CERT_HASH${NC}"
echo -e "Output Location:  ${BLUE}$OUTPUT_DIR${NC}"
echo -e "ZIP File:         ${BLUE}$ZIP_PATH${NC}"
echo -e "ZIP Size:         ${BLUE}$ZIP_SIZE${NC}"
echo "========================================"
echo ""
echo "Next steps:"
echo "  1. Transfer $ZIP_NAME to your Android device"
echo "  2. Open KSU Manager → Modules → Install from storage"
echo "  3. Select $ZIP_NAME and tap Install"
echo "  4. Reboot your device"
echo "  5. Verify in Settings → Security → Certificate authorities"
echo ""
echo "Proxy Configuration:"
echo "  - WiFi → Advanced options"
echo "  - Set Proxy Host to your PC's IP"
echo "  - Set Proxy Port to 8080"
echo ""
