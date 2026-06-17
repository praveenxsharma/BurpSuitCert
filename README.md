# BurpSuiteCert - KSU/ksu-next Module

**Author**: [Praveen Sharma](https://github.com/praveensharma)  
**Version**: 1.0 (Version Code: 202506171)  
**Purpose**: Install the Burp Suite CA certificate into the Android system certificate store for full HTTPS interception.

---

## Description

`BurpSuiteCert` is a KSU/ksu-next module that injects the Burp Suite CA certificate directly into the Android system key store, including the APEX `com.android.conscrypt` location (required from Android 10+ and especially Android 14). This module also maintains backward compatibility with Magisk.

This enables **system-wide trusted HTTPS interception** with Burp Suite, including for apps that use custom trust managers.

---

## Module Files Required

The BurpSuiteCert module requires these 4 files:

| File | Purpose |
|------|---------|
| `module.xml` | KSU/ksu-next module manifest |
| `module.prop` | Module properties and metadata |
| `post-fs-data.sh` | Post-installation configuration script |
| `system/etc/security/cacerts/9a5ba575.0` | The Burp Suite CA certificate |

---

## Simple Installation Process

1. **Clone this repository**:
   ```bash
   git clone https://github.com/praveensharma/BurpSuiteCert.git
   cd BurpSuiteCert
   ```

2. **Replace the certificate** with your custom one:
   - Import your Burp certificate to Burp Suite
   - Export and convert it to DER format (.0)
   - Replace the existing certificate in this repository

3. **Create installation zip**:
   ```bash
   zip -r BurpSuiteCert.zip module.xml module.prop post-fs-data.sh system/etc/security/cacerts/9a5ba575.0
   ```

4. **Flash the module**:
   - Install KSU/ksu-next manager on your device
   - Open manager → Modules → Install from storage
   - Select `BurpSuiteCert.zip`
   - Enable module and reboot

---

## Installation Paths

The module automatically detects your environment:
- **KSU/ksu-next**: `/data/adb/ksu/modules/burpsuite-cert`
- **Magisk (fallback)**: `/data/adb/modules/burpsuite-cert`
- **Standard Root**: `/system/burp_cert`

---

## Module Information

- **Module ID**: ksu.00000001
- **Version Code**: 202506171
- **Target**: Systemless installation
- **License**: MIT

---

## Disclaimer

This module modifies system trust settings. Use only in **development** or **controlled environments**.