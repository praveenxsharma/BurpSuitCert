#!/system/bin/sh

# BurpSuiteCert Module for KSU/ksu-next - Installs CA certificates
# This script runs after filesystem is mounted

# Detect KSU/ksu-next environment
KSU_PATH=""
if [ -d "/data/adb/ksu" ] || [ -d "/data/ksu" ]; then
    # KSU/ksu-next detected
    KSU_PATH="/data/adb/ksu"
elif [ -d "/data/adb/modules/ksu" ]; then
    KSU_PATH="/data/adb/modules/ksu"
elif [ -d "/data/adb/modules" ] && [ "$MAGISK" ]; then
    # Fallback to Magisk if KSU not found
    MODULE_PATH="/data/adb/modules/burpsuite-cert"
    echo "BurpSuiteCert: Magisk environment detected, installing to Magisk location"
fi

# For KSU modules, we'll use APEX integration for modern Android versions
if [ -n "$KSU_PATH" ]; then
    MODULE_PATH="$KSU_PATH/modules/burpsuite-cert"
    echo "BurpSuiteCert: KSU/ksu-next environment detected, installing to KSU location"
else
    # Standard rooted device or fallback
    MODULE_PATH="/system/burp_cert"
    echo "BurpSuiteCert: Installing to standard location"
fi

# Common installation logic
if [ -d "$MODULE_PATH" ] ; then
    # Certificates already installed
    echo "BurpSuiteCert: Module already installed"
else
    echo "BurpSuiteCert: Installing CA certificates..."

    # Create module directory
    mkdir -p "$MODULE_PATH"

    # Install the root CA certificate
    cp /system/etc/security/cacerts/9a5ba575.0 "$MODULE_PATH/"

    # Set permissions
    chmod 644 "$MODULE_PATH/9a5ba575.0"
    chown root:root "$MODULE_PATH/9a5ba575.0"

    echo "BurpSuiteCert: Installation complete"
fi

if [ -d "$APEX_CA_DIR" ]; then
    echo "[3/5] Preparing tmpfs for CA cert override..."
    rm -rf "$TMP_COPY"
    mkdir -p "$TMP_COPY"
    mount -t tmpfs tmpfs "$TMP_COPY"

    echo "[4/5] Copying system and Burp certs into tmpfs..."
    cp -f "$APEX_CA_DIR"/* "$TMP_COPY"/
    cp -f "$CUSTOM_CERTS"/* "$TMP_COPY"/
    chown -R 0:0 "$TMP_COPY"
    set_context "$APEX_CA_DIR" "$TMP_COPY"

    CERTS_NUM=$(ls -1 "$TMP_COPY" | wc -l)
    if [ "$CERTS_NUM" -gt 10 ]; then
        echo "[5/5] Binding modified certs to APEX..."
        mount --bind "$TMP_COPY" "$APEX_CA_DIR"
        for pid in 1 $(pgrep zygote) $(pgrep zygote64); do
            nsenter --mount="/proc/${pid}/ns/mnt" -- \
                mount --bind "$TMP_COPY" "$APEX_CA_DIR"
        done
        echo "✅ Burp Suite CA successfully installed and active."
    else
        echo "❌ Aborting: CA cert count too low ($CERTS_NUM)."
    fi

    umount "$TMP_COPY"
    rmdir "$TMP_COPY"
else
    echo "⚠️ APEX CA directory not found. Skipping injection."
fi
create a read me file for the above script. this module is used to install Burp Suite CA certificate on Android devices. and module name is BurpSuiteCert and give me the markdown fle as downloadable