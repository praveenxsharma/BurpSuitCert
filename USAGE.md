# BurpSuiteCert - Usage Guide

## Overview

After successful installation, the Burp Suite CA certificate is available system-wide for MITM HTTPS interception.

## Certificate Selection

### In System Settings
1. Open `Settings`
2. Go to `Security` or `Privacy and Security`
3. Tap `Trusted credentials` or `App credentials`
4. Select `BurpSuiteCert` from the list

### In Apps with Custom Trust Management
Some apps allow you to select the CA certificate directly:
- Web browsers may have a certificate selection dialog
- Proxy apps may list available CAs
- Custom apps with SSL pinning bypass tools

### Using Burp Suite
1. In Burp Suite, go to "Proxy" > "Options"
2. Configure your listener port (default: 8080)
3. In the target app, enable proxy interception
4. Select the Burp Suite CA certificate when prompted for certificate trust

## Testing Installation

### Basic Test
```bash
# Test if certificate is available
cat /system/etc/security/cacerts/9a5ba575.0
# Check if file exists
ls -la /data/adb/ksu/modules/burpsuite-cert/
```

### Network Test
```bash
# Test HTTPS interception (replace with target host)
curl -k https://example.com
```

### Certificate Chain Test
```bash
# View certificate details
openssl x509 -in /system/etc/security/cacerts/9a5ba575.0 -text -noout
```

## Compatibility Notes

### Android Versions
- **Android 7-9**: Traditional system trust store
- **Android 10-13**: APEX integration supported
- **Android 14+**: APEX binding for `com.android.conscrypt`

### Device Types
- **Stock ROMs**: Installs to system partition
- **Custom ROMs**: Installs to module directory
- **Rooted without KSU**: Standard rooted installation

## Known Issues

### Certificate Not Showing
- Reboot device after installation
- Clear app data for apps that cache certificates
- Check if app uses hardware-backed keystore

### App Still Trusting System CAs
- Some apps have hardcoded certificate pins
- Consider using certificate pinning bypass tools
- May need to modify app code directly

### Network Connectivity Issues
- Ensure proxy configuration is correct
- Check firewall rules
- Verify certificate chain is complete

## Advanced Usage

### Custom Certificate Paths
```bash
# Location where certificate may be found
# KSU: /data/adb/ksu/modules/burpsuite-cert/9a5ba575.0
# Magisk: /data/adb/modules/burpsuite-cert/9a5ba575.0
# System: /system/etc/security/cacerts/9a5ba575.0
```

### Certificate Fingerprint
SHA256: `9a5ba575.0` (System hash format)

### API Access
```bash
# Check if module is active
if [ -f "/system/etc/security/cacerts/9a5ba575.0" ]; then
    echo "BurpSuiteCert: Certificate found"
else
    echo "BurpSuiteCert: Certificate not found"
fi
```

## Best Practices

1. **Test on non-production devices first**
2. **Keep device unlocked for development needs**
3. **Document successful configurations**
4. **Backup certificate files**
5. **Consider security implications of CA trust**

## Next Steps

After successful installation:
1. Configure your proxy tool (Burp Suite, Charles, etc.)
2. Set up proper port forwarding
3. Test with target applications
4. Document successful configurations for others

---

**Note**: This certificate should only be used for legitimate testing and debugging purposes.