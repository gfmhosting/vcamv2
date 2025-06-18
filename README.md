# CustomVCAM - Virtual Camera for iOS

A powerful jailbreak tweak for bypassing web-based KYC (Know Your Customer) verification systems by replacing camera input with pre-selected media content.

## 🎯 Purpose

CustomVCAM intercepts camera access at the system level and replaces real camera input with realistic fake media, enabling bypass of identity verification systems like Stripe KYC, banking verification, and other document verification services.

## 🔧 Compatibility

- **Device:** iPhone 7 (ARM64)
- **iOS Version:** 13.3.1
- **Jailbreak:** checkra1n
- **Runtime:** MobileSubstrate

## ✨ Features

### Core Functionality
- ✅ **System-wide camera hook** - Affects all apps including Safari, Chrome
- ✅ **UIImagePickerController interception** - Redirects camera to photo library
- ✅ **AVFoundation hooks** - Blocks real camera sessions
- ✅ **WebView camera blocking** - Intercepts getUserMedia requests
- ✅ **Overlay interface** - Simple button for media selection

### Bypass Capabilities
- 🛡️ **Stripe KYC verification**
- 🛡️ **Banking app identity verification**
- 🛡️ **Government document verification**
- 🛡️ **Social media verification**
- 🛡️ **Web-based document scanners**

## 📦 Installation

### Automatic Installation (Recommended)

1. Download the latest `.deb` package from [Releases](../../releases)
2. Transfer to your jailbroken device via SSH or iTunes
3. Install the package:
   ```bash
   dpkg -i CustomVCAM-*.deb
   ```
4. Respring your device:
   ```bash
   killall -9 SpringBoard
   ```

### Manual Installation

1. Clone this repository
2. Build with Theos:
   ```bash
   make package FINALPACKAGE=1
   ```
3. Install the generated `.deb` file

## 🚀 Usage

### Basic Operation

1. **Automatic Mode:** Camera access is automatically intercepted
2. **Overlay Button:** Tap the semi-transparent button on camera interface
3. **Media Selection:** Choose from pre-loaded realistic documents
4. **Verification:** System receives fake media instead of camera input

### Supported Verification Types

| Type | Description | Status |
|------|-------------|--------|
| ID Documents | Driver's license, passport, national ID | ✅ |
| Selfie Photos | Face verification images | ✅ |
| Live Video | Document + face verification | ✅ |
| Liveness Check | Blink, head movement verification | ✅ |

## 🏗️ Architecture

### Hook Points
```
Camera Access Request
        ↓
UIImagePickerController → Photo Library Redirect
        ↓
AVCaptureSession → Fake Media Stream
        ↓
WKWebView → JavaScript Interception
        ↓
Verification System Bypass
```

### File Structure
```
CustomVCAM/
├── Tweak.x                 # Main hooking logic
├── Sources/
│   ├── MediaManager.m      # Media selection & injection
│   └── OverlayView.m       # Camera overlay interface
├── Resources/Media/        # Fake media bundle
└── .github/workflows/      # Auto-build pipeline
```

## ⚙️ Configuration

### Media Bundle
- Located in: `/var/mobile/Library/CustomVCAM/Media/`
- Supports: JPEG, PNG, MP4, MOV
- Auto-loads on tweak initialization

### Logging
Debug logs available in device console:
```bash
# View logs
tail -f /var/log/syslog | grep CustomVCAM
```

## 🔨 Development

### Building from Source

1. **Prerequisites:**
   - macOS with Xcode
   - Theos installed
   - iOS 13.0 SDK

2. **Build Commands:**
   ```bash
   # Clean build
   make clean
   
   # Debug build
   make
   
   # Release build
   make package FINALPACKAGE=1
   ```

3. **GitHub Actions:**
   - Automatic builds on push/PR
   - Release creation on version tags
   - ARM64 targeting for iPhone 7

### Contributing

1. Fork the repository
2. Create feature branch
3. Test on iOS 13.3.1 device
4. Submit pull request

## ⚠️ Legal Disclaimer

**Educational Purpose Only**

This software is provided for educational and research purposes only. Users are responsible for:

- Compliance with local laws and regulations
- Understanding verification system terms of service
- Accepting risks of detection and account penalties
- Using responsibly and ethically

**The developers assume no liability for any misuse or legal consequences.**

## 🔍 Detection Risks

### Mitigation Strategies
- ✅ Realistic EXIF data injection
- ✅ Random noise addition to images
- ✅ Metadata manipulation
- ✅ Timestamp randomization
- ✅ Multiple hook points for redundancy

### Known Limitations
- Advanced biometric detection systems
- Machine learning verification algorithms
- Server-side image analysis
- Real-time video analysis

## 📞 Support

### Issues
Report bugs and feature requests in the [Issues](../../issues) section.

### Requirements
- Provide iOS version, device model, and jailbreak type
- Include relevant console logs
- Describe expected vs actual behavior

### FAQ

**Q: Does this work on iOS 14+?**  
A: Currently optimized for iOS 13.3.1. Newer versions may require updates.

**Q: Will this bypass all verification systems?**  
A: Effective against most web-based KYC systems, but advanced ML detection may still identify fake media.

**Q: Is this safe to use?**  
A: Use at your own risk. Account bans and legal consequences are possible.

## 📄 License

This project is provided as-is under educational fair use. Commercial use is prohibited.

## 🏆 Credits

- **Theos** - iOS tweak development framework
- **checkra1n** - Jailbreak tool
- **GitHub Actions** - Automated build system
- **Community** - Testing and feedback

---

**Version:** 1.0.0  
**Last Updated:** June 2025  
**Compatibility:** iPhone 7, iOS 13.3.1, checkra1n 