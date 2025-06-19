# Custom VCAM v2

![Build Status](https://github.com/gfmhosting/vcamv2/workflows/Build%20Custom%20VCAM%20v2/badge.svg)
[![Latest Release](https://img.shields.io/github/v/release/gfmhosting/vcamv2)](https://github.com/gfmhosting/vcamv2/releases)

Advanced camera replacement system for bypassing web verification on jailbroken iOS devices.

## Overview

Custom VCAM v2 is a sophisticated jailbreak tweak that allows you to replace both native camera feeds and Safari WebRTC camera streams with preselected media (photos and videos). This tool is specifically designed for iPhone 7 iOS 13.3.1 devices jailbroken with checkra1n.

## Features

- **Double-tap volume activation**: Trigger media selection with volume button gestures
- **Universal camera replacement**: Works with native Camera app and Safari WebRTC
- **Native media picker**: Seamless iOS photo/video selection interface
- **Format support**: HEIC images and H.264 videos with automatic conversion
- **Real-time injection**: Live CVPixelBuffer replacement for smooth operation
- **Anti-detection**: Minimal system footprint and dynamic hooking
- **Automatic builds**: GitHub Actions CI/CD with automated .deb generation

## Target Device

- **Model**: iPhone 7 (A1778) model MN922B/A
- **iOS Version**: 13.3.1 (17D50)
- **Jailbreak**: checkra1n
- **Architecture**: arm64

## Installation

### Quick Install

1. **Download**: Get the latest `.deb` from [GitHub Releases](../../releases) or [Build Artifacts](../../actions)
2. **Install**: Use Filza File Manager or dpkg
3. **Respring**: Restart SpringBoard
4. **Activate**: Double-tap volume buttons

### Detailed Steps

1. Download the latest `.deb` file from [Releases](../../releases)
2. Transfer the file to your jailbroken device via:
   - **AirDrop** (easiest)
   - **Filza Web Server**
   - **SSH/SCP**
   - **iTunes File Sharing**

3. Install using **Filza File Manager**:
   - Navigate to the downloaded `.deb` file
   - Tap the file and select "Install"
   - Tap "Confirm" to proceed
   - Wait for installation to complete

4. **Respring** your device:
   - Use Filza's "Respring" option, or
   - Run `killall SpringBoard` via SSH

5. **Verify Installation**:
   - Double-tap volume buttons
   - Media picker should appear

### Alternative Installation Methods

#### SSH/Terminal (Advanced)
```bash
# Transfer file to device first, then:
dpkg -i com.customvcam.vcam_*.deb
killall SpringBoard
```

#### Package Manager (if available)
- Some package managers may support direct installation from GitHub releases

## Usage

### Basic Operation
1. **Activation**: Double-tap volume up or volume down buttons quickly
2. **Media Selection**: Choose photo or video from the native iOS picker
3. **Camera Replacement**: Selected media will replace all camera feeds
4. **Deactivation**: Select different media, restart device, or disable in settings

### Supported Applications

- ✅ **Camera.app**: Native iOS camera application
- ✅ **Safari**: WebRTC-based web applications (Stripe verification, video calls)
- ✅ **Any AVCaptureSession app**: Automatic compatibility with most camera apps
- ✅ **Web browsers**: Chrome, Firefox (through WebRTC hooks)

### Troubleshooting Activation

If double-tap doesn't work:
- Try different timing (faster/slower taps)
- Ensure no other tweaks interfere with volume buttons
- Check console logs for error messages
- Respring device and try again

## Development & Building

### Automated Builds (Recommended)

This project uses **GitHub Actions** for automated building:

- **Automatic builds** on every push to main branch
- **Modern Theos installer** with multiple fallback sources
- **Robust toolchain management** with cctools-port and alternative sources
- **Comprehensive validation** and error reporting
- **Artifact uploads** for easy download

**Build artifacts** are available in the [Actions tab](../../actions) for every commit.

### Local Development Setup

#### Prerequisites
- **macOS** (recommended) or **Linux**
- **Xcode** (macOS) or **build-essential** (Linux)
- **git** for cloning repositories

#### Quick Setup (Linux/macOS)
```bash
# Install Theos using the official installer (handles everything automatically)
bash -c "$(curl -fsSL https://raw.githubusercontent.com/theos/theos/master/bin/install-theos)"

# Clone and build
git clone https://github.com/gfmhosting/vcamv2.git
cd vcamv2
make clean && make package
```

#### Manual Setup (if automatic installer fails)
```bash
# Clone Theos
git clone --recursive https://github.com/theos/theos.git /opt/theos
export THEOS=/opt/theos

# Download iOS 13.7 SDK
curl -LO https://github.com/theos/sdks/archive/master.zip
unzip master.zip
cp -r sdks-master/iPhoneOS13.7.sdk $THEOS/sdks/

# Install toolchain (Linux only)
# The automated build system handles multiple sources:
# - GitHub kabiroberai toolchain
# - cctools-port releases  
# - angelxwind mirror
# - System toolchain fallback

# Build project
make clean
make package FINALPACKAGE=1
```

### Build System Architecture

- **Framework**: Theos/Substrate with modern installer
- **CI/CD**: GitHub Actions with robust error handling
- **SDK**: iOS 13.7 SDK with automatic fallbacks
- **Toolchain**: Multiple sources with validation
- **Target**: `iphone:13.7:13.0`
- **Architecture**: `arm64`
- **Package Format**: Debian (.deb)

## Technical Implementation

### Core Components

```
Custom VCAM v2/
├── Makefile                     # Theos build configuration
├── control                      # Package metadata and dependencies  
├── CustomVCAM.plist            # Bundle filter (Camera, Safari, SpringBoard)
├── Tweak.x                     # Main hooking implementation
├── Sources/
│   ├── MediaManager.h/m        # Media conversion (UIImage ↔ CVPixelBuffer)
│   ├── OverlayView.h/m         # Native iOS media picker UI
│   └── SimpleMediaManager.h/m  # Utility functions and type detection
├── .github/workflows/
│   └── build.yml               # CI/CD pipeline with modern Theos installer
└── README.md
```

### Hooking Architecture

1. **Volume Button Detection**:
   - `IOHIDEventSystem` hooks for hardware button events
   - Double-tap timing and debouncing
   - SpringBoard-level event interception

2. **Camera Feed Replacement**:
   - `AVCaptureVideoDataOutput` hooks for native apps
   - CVPixelBuffer manipulation and injection
   - Real-time format conversion (HEIC→JPEG, H.264 processing)

3. **WebRTC Interception**:
   - `WebCore::UserMediaRequest::start()` hooks for Safari
   - JavaScript-to-native bridge interception
   - Browser compatibility layer

### Media Processing Pipeline

1. **Selection**: Native iOS PHPickerViewController/UIImagePickerController
2. **Validation**: Format detection and compatibility checking
3. **Conversion**: HEIC→JPEG, video→H.264, resolution scaling
4. **Storage**: Secure temporary storage with cleanup
5. **Injection**: CVPixelBuffer replacement at capture session level

## Debugging & Logs

### Console Monitoring
```bash
# Real-time log monitoring
tail -f /var/log/syslog | grep "CustomVCAM"

# Or use device console tools
deviceconsole | grep "CustomVCAM"
```

### Log Prefixes
- `[CustomVCAM]`: General operations and lifecycle
- `[CustomVCAM MediaManager]`: Media processing and conversion
- `[CustomVCAM OverlayView]`: UI operations and user interaction
- `[CustomVCAM Volume]`: Volume button detection and handling

### Common Debug Scenarios

1. **Build failures**: Check GitHub Actions logs for detailed error information
2. **Volume detection issues**: Monitor IOHIDEventSystem hooks
3. **Media conversion problems**: Check MediaManager logs for format issues
4. **WebRTC compatibility**: Verify Safari hooks and JavaScript bridge

## Troubleshooting

### Installation Issues

1. **"Cannot install package"**:
   - Verify device compatibility (iPhone 7 iOS 13.3.1)
   - Check if Substrate/Cydia Substrate is installed
   - Ensure sufficient storage space

2. **"Tweak not working after install"**:
   - Perform a proper respring (not just lock/unlock)
   - Check if conflicting tweaks are installed
   - Verify installation in Settings → General → About

### Functionality Issues

1. **Volume buttons not responding**:
   ```bash
   # Check if events are being detected
   grep -i "volume" /var/log/syslog
   
   # Verify no conflicting volume tweaks
   dpkg -l | grep -i volume
   ```

2. **Camera feed not replaced**:
   - Ensure media was selected successfully
   - Check media format compatibility
   - Try different source media
   - Monitor logs during camera app usage

3. **Safari WebRTC issues**:
   - Clear Safari cache and website data
   - Ensure camera permissions are enabled
   - Test with different websites (meet.google.com, etc.)
   - Check if other browsers work

### Performance Issues

1. **System lag or crashes**:
   - Disable tweak temporarily to verify cause
   - Check memory usage during operation
   - Monitor crash logs in Settings → Privacy & Security

2. **Media picker slow to appear**:
   - Check available storage space
   - Verify photo library permissions
   - Monitor system resources

## Security & Privacy

### Security Features
- **Minimal system footprint**: Only active when triggered
- **Temporary storage**: Media cached in `/tmp` with automatic cleanup
- **Clean uninstall**: No persistent system modifications
- **Sandbox compliance**: Respects iOS security boundaries

### Privacy Considerations
- **Local processing**: All operations performed on-device
- **No data transmission**: No network communication
- **Temporary storage**: Selected media automatically cleaned up
- **Permission respect**: Uses standard iOS photo/camera permissions

### Detection Mitigation
- **Dynamic hooking**: Methods hooked only when active
- **Native UI**: Uses standard iOS components for selection
- **Format preservation**: Maintains original media characteristics
- **Minimal signatures**: Low detectability profile

## Compatibility Matrix

| Device | iOS Version | Jailbreak | Status |
|--------|-------------|-----------|---------|
| iPhone 7 (A1778) | 13.3.1 | checkra1n | ✅ **Fully Supported** |
| iPhone 7 Plus | 13.3.1 | checkra1n | ⚠️ *Likely Compatible* |
| iPhone 6s/6s+ | 13.3.1 | checkra1n | ⚠️ *Untested* |
| Other iPhones | 13.x | checkra1n | ❌ *Not Tested* |
| Any iPhone | 14.x+ | Any | ❌ *Incompatible* |
| Any iPhone | Any | Unc0ver | ❌ *Not Tested* |

### Substrate Compatibility
- ✅ **Cydia Substrate**: Full compatibility
- ✅ **Substitute**: Should work (untested)
- ❌ **libhooker**: Not compatible
- ❌ **Rootless**: Not supported

## Contributing

### Bug Reports
1. **Check existing issues** before creating new ones
2. **Include device information** (model, iOS version, jailbreak)
3. **Provide console logs** when possible
4. **Describe reproduction steps** clearly

### Development Contributions
1. **Fork the repository** and create a feature branch
2. **Follow existing code style** and conventions
3. **Test thoroughly** on target device (iPhone 7 iOS 13.3.1)
4. **Update documentation** for any changes
5. **Submit pull request** with detailed description

### Development Guidelines
- Use proper Objective-C memory management
- Follow Theos conventions and directory structure
- Add appropriate logging for debugging
- Document all public interfaces
- Test edge cases and error conditions

## Build Status & Releases

### Continuous Integration
- **Automatic builds** on every commit
- **Multiple toolchain sources** for reliability
- **Comprehensive validation** before packaging
- **Artifact retention** for 30 days

### Release Schedule
- **Development builds**: Available after every commit
- **Stable releases**: Tagged releases for major milestones
- **Pre-releases**: Beta versions for testing new features

Check the [Actions tab](../../actions) for the latest build status and download development builds.

## Legal & Disclaimer

### Educational Purpose
This software is provided for **educational and research purposes only**. It demonstrates:
- iOS jailbreak development techniques
- System-level hooking and interception
- Media processing and format conversion
- CI/CD automation for iOS projects

### User Responsibility
- **Compliance**: Users are responsible for complying with all applicable laws
- **Terms of Service**: Respect website and application terms of service
- **Ethical Use**: Use responsibly and ethically
- **Risk Acknowledgment**: Understand risks of jailbreaking and third-party modifications

### Disclaimer
The developers assume **no responsibility** for:
- Misuse of this software
- Device damage or data loss
- Violation of terms of service
- Legal consequences of usage

## License

This project is provided **as-is** for educational purposes under the following terms:
- **No warranty** express or implied
- **Use at your own risk**
- **Educational use only**
- **No redistribution** without permission

## Support & Community

### Getting Help
1. **Documentation**: Read this README thoroughly
2. **Issues**: Check [GitHub Issues](../../issues) for known problems
3. **Logs**: Always include console logs with support requests
4. **Device Info**: Specify your exact device model and iOS version

### Community Guidelines
- Be respectful and constructive
- Provide detailed information when reporting issues
- Search existing issues before creating new ones
- Follow responsible disclosure for security issues

---

**Built with ❤️ using modern Theos and GitHub Actions** 