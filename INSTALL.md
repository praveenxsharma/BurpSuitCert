# BurpSuiteCert - KSU/ksu-next Module Installation Guide

## Quick Installation

### For KSU/ksu-next Users (Recommended)

1. **Download the module zip**
   ```bash
   # On computer
   adb push BurpSuiteCert.zip /sdcard/Download/
   ```

2. **Install using KSU/ksu-next manager**
   - Open your KSU/ksu-next manager app
   - Go to "Modules" > "Install from storage"
   - Select `BurpSuiteCert.zip`
   - Enable the module
   - Reboot device

### For Advanced Users (Command Line)

```bash
# Install using KSU/ksu-next
adb push BurpSuiteCert.zip /data/local/tmp/
adb shell "su -c 'ksu install-module /data/local/tmp/BurpSuiteCert.zip'"

# OR fallback to Magisk if KSU not available
adb push BurpSuiteCert.zip /data/local/tmp/
adb shell "magisk --install-module /data/local/tmp/BurpSuiteCert.zip"

reboot
```

## Installation Paths

The module automatically detects your environment:

| Environment | Installation Path |
|-------------|------------------|
| KSU/ksu-next | `/data/adb/ksu/modules/burpsuite-cert` |
| Magisk (fallback) | `/data/adb/modules/burpsuite-cert` |
| Standard Root | `/system/burp_cert` |

## Module Information

- **Module ID**: `ksu.00000001`
- **Version**: `1.0` (Version Code: `202506171`)
- **Target**: Systemless installation
- **Supported Architectures**: `arm64-v8a`, `armeabi-v7a`, `x86`, `x86_64`
- **Minimum Kernel**: `4.4`

## Files Included

- `module.prop` - Module properties (KSU/ksu-next compatible)
- `module.xml` - KSU/ksu-next module manifest
- `post-fs-data.sh` - Post-installation configuration script
- `install.sh` - Installation script
- `BurpSuiteCert.zip` - The actual module archive

## Troubleshooting

### Module not installing
```bash
# Check if module exists
ls -la /data/adb/ksu/modules/
ls -la /data/adb/modules/
```

### Certificate not appearing
- Reboot after enabling the module
- Check log: `cat /data/local/tmp/BurpSuiteCert.log`
- Verify device compatibility

### Installation errors
1. Ensure device is rooted
2. Check if KSU/ksu-next is installed
3. Use Magisk fallback if needed
4. Try standard rooted installation as last resort

## Uninstallation

```bash
# Method 1: Using KSU/ksu-next manager
- Disable the module in your KSU manager
- Reboot device

# Method 2: Manual removal
rm -rf /data/adb/ksu/modules/burpsuite-cert
rm -rf /data/adb/modules/burpsuite-cert
rm -rf /system/burp_cert
```

## Support

For issues, please check the README.md or contact the author.

---

**Note**: This module maintains backward compatibility with Magisk and standard rooted devices while being optimized for KSU/ksu-next.