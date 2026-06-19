# BurpSuiteCert - Interactive Certificate Module Generator

This is an **intelligent module builder** that takes your Burp Suite certificate and automatically generates a complete, working KSU/ksu-next module with zero manual configuration.

## 🎯 What It Does

Simply provide your Burp certificate in **any format** (DER, PEM, CER) and the generator:
- ✅ Converts it to the correct format (DER with .0 extension)
- ✅ Copies all system certificates for compatibility
- ✅ Creates all required module files automatically
- ✅ Handles all Android versions (7-14+)
- ✅ Generates a ready-to-flash ZIP file

## 📋 Requirements

- Burp Suite Community or Professional
- KSU/ksu-next installed on your Android device
- A computer with Bash/Python (for the generator)

## 🚀 Quick Start

### Step 1: Export Your Burp Certificate

1. Open **Burp Suite**
2. Go to **Proxy → Settings → TLS Pass Through**
3. Click **Import / Export CA Certificate**
4. Export as **DER format** (or any format - we'll convert it)
5. Save as `burp-cert.der` or `burp-cert.pem`

### Step 2: Run the Generator

```bash
# Clone the repo
git clone https://github.com/praveenxsharma/BurpSuiteCert.git
cd BurpSuiteCert

# Run the generator (interactive)
bash generate-module.sh

# Or with Python (if available)
python3 generate-module.py --cert burp-cert.der

# The script will ask:
# Enter path to your Burp certificate: [burp-cert.der]
# Enter module name (optional): [BurpSuiteCert]
# Enter your name (optional): [Praveen Sharma]
```

### Step 3: Flash the Module

1. Copy the generated `BurpSuiteCert.zip` to your phone
2. Open **KSU Manager**
3. **Modules** → **Install from storage**
4. Select `BurpSuiteCert.zip`
5. **Reboot**

### Step 4: Configure WiFi Proxy

1. **Settings** → **Network & Internet** → **WiFi**
2. Long-press your WiFi network → **Edit**
3. Expand **Advanced options**
4. **Proxy**: Manual
5. **Proxy hostname**: Your PC's IP address
6. **Proxy port**: `8080`
7. Save and reconnect

### Step 5: Verify in Burp

Open any app (browser, social media, etc.) and check if traffic appears in **Burp Suite → HTTP history**.

## 📁 Generated Module Structure

```
BurpSuiteCert/
├── module.prop          # Module metadata
├── module.xml           # KSU module manifest
├── post-fs-data.sh      # Auto-runs certificate injection
├── service.sh           # Optional: app restart handler
└── system/
    └── etc/security/
        └── cacerts/
            ├── 9a5ba575.0    # Your Burp certificate
            └── [system certs]
```

## 🔄 Supported Certificate Formats

The generator automatically detects and converts:
- **DER** (.der, .0) ✓
- **PEM** (.pem, .crt) ✓
- **PKCS12** (.p12, .pfx) ✓
- **OpenSSL X509** ✓

## ⚙️ How It Works (Under the Hood)

1. **Certificate Detection**: Identifies format and validity
2. **Format Conversion**: Converts to standard DER if needed
3. **Hash Generation**: Creates OpenSSL hash (9a5ba575.0)
4. **System Cert Collection**: Extracts all system certificates
5. **Module Packaging**: Creates KSU-compliant module structure
6. **ZIP Generation**: Produces flashable module

## 🆘 Troubleshooting

### "No traffic in Burp"

**Check list:**
1. ✓ WiFi proxy is configured correctly
2. ✓ Burp listener is running on `0.0.0.0:8080`
3. ✓ Certificate is installed (Settings → Security → Certificate authorities)
4. ✓ App is restarted after proxy configuration
5. ✓ Device can ping your PC IP

### "Certificate not trusted"

The certificate might still be processing. Try:
```bash
# On device (via adb or terminal)
adb shell am dump-hprof --user 10 system_server
adb reboot
```

### "Module won't install"

Ensure:
- KSU/ksu-next is version 10.0 or higher
- You have admin permissions
- Zip file is not corrupted

## 📊 Generator Options

```bash
# Full customization
bash generate-module.sh \
  --cert burp-cert.der \
  --name "MyBurpModule" \
  --author "Your Name" \
  --output custom-module.zip

# Verbose mode (debugging)
bash generate-module.sh --verbose

# Dry run (show what would happen)
bash generate-module.sh --dry-run
```

## 🔐 Security Notes

- This module **only** installs your certificate
- Your traffic is only intercepted if you configure the WiFi proxy
- The certificate is added to **system trust store**, not keystore
- Works with **any app** that uses system certificates
- Apps with certificate pinning may still bypass interception

## 📝 Manual Certificate Hash (Advanced)

If you want to understand the naming:

```bash
# Generate the hash for any certificate
openssl x509 -in burp-cert.pem -noout -subject_hash_old
# Output: 9a5ba575
# Use as: 9a5ba575.0
```

## 🤝 Contributing

Found a bug? Want to add support for Magisk? See [CONTRIBUTING.md](CONTRIBUTING.md)

## 📄 License

MIT - See [LICENSE](LICENSE)

## 🙋 Support

- **Issues**: [GitHub Issues](https://github.com/praveenxsharma/BurpSuiteCert/issues)
- **Discussions**: [GitHub Discussions](https://github.com/praveenxsharma/BurpSuiteCert/discussions)

---

**Made with ❤️ for penetration testers and security researchers**
