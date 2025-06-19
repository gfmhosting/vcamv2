# Custom VCAM v2

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

## Target Device

- **Model**: iPhone 7 (A1778) model MN922B/A
- **iOS Version**: 13.3.1 (17D50)
- **Jailbreak**: checkra1n
- **Architecture**: arm64

## Installation

### Prerequisites

1. iPhone 7 jailbroken with checkra1n
2. Filza File Manager or SSH access
3. Substrate/Cydia Substrate installed

### Steps

1. Download the latest `.deb` file from [Releases](../../releases)
2. Transfer the file to your jailbroken device
3. Install using Filza:
   - Navigate to the `.deb` file
   - Tap and select "Install"
   - Tap "Confirm"
4. Respring your device
5. The tweak is now active

### Alternative Installation (SSH)

```bash
dpkg -i com.customvcam.vcam_2.0.0_iphoneos-arm.deb
killall SpringBoard
```

## Usage

1. **Activation**: Double-tap volume up or volume down buttons
2. **Media Selection**: Choose photo or video from the native picker
3. **Camera Replacement**: Selected media will replace camera feeds
4. **Deactivation**: Select different media or restart device

### Supported Apps

- **Camera.app**: Native iOS camera application
- **Safari**: WebRTC-based web applications (primary target: Stripe verification)
- **Any app using AVCaptureSession**: Automatic compatibility

## Technical Details

### Architecture

- **Framework**: Theos/Substrate
- **SDK**: iOS 13.7 SDK
- **Hooking Targets**:
  - `IOHIDEventSystem` for volume button detection
  - `AVCaptureVideoDataOutput` for native camera replacement
  - `WebCore::UserMediaRequest` for Safari WebRTC hooking

### Build System

- **CI/CD**: GitHub Actions
- **Build Tool**: Theos Make
- **Target**: `iphone:13.7:13.0`
- **Architecture**: `arm64`

### File Structure

```
Custom VCAM v2/
├── Makefile                 # Theos build configuration
├── control                  # Package metadata
├── CustomVCAM.plist        # Bundle filter configuration
├── Tweak.x                 # Main hooking implementation
├── Sources/
│   ├── MediaManager.h/m    # Media conversion and management
│   ├── OverlayView.h/m     # UI overlay and media picker
│   └── SimpleMediaManager.h/m # Utility functions
├── .github/workflows/
│   └── build.yml           # CI/CD pipeline
└── README.md
```

## Development

### Building from Source

1. **Setup Theos**:
   ```bash
   git clone --recursive https://github.com/theos/theos.git /opt/theos
   export THEOS=/opt/theos
   ```

2. **Install iOS 13.7 SDK**:
   ```bash
   curl -LO https://github.com/theos/sdks/archive/master.zip
   unzip master.zip
   cp -r sdks-master/iPhoneOS13.7.sdk $THEOS/sdks/
   ```

3. **Build Project**:
   ```bash
   make clean
   make package
   ```

### Debugging

Enable verbose logging by checking device console:
```bash
tail -f /var/log/syslog | grep "CustomVCAM"
```

## Troubleshooting

### Common Issues

1. **Volume buttons not responding**:
   - Ensure device is resprung after installation
   - Check if other tweaks conflict with volume button handling

2. **Camera not replaced**:
   - Verify media was selected successfully
   - Check console logs for error messages
   - Try selecting different media format

3. **Safari WebRTC not working**:
   - Ensure Safari has camera permissions
   - Clear Safari cache and data
   - Test with different websites

### Log Analysis

Check these log prefixes for debugging:
- `[CustomVCAM]`: General tweak operations
- `[CustomVCAM MediaManager]`: Media processing
- `[CustomVCAM OverlayView]`: UI operations

## Security Considerations

- **Minimal footprint**: Only hooks when activated
- **Temporary storage**: Media files stored in temp directory
- **Clean uninstall**: No persistent system modifications
- **Privacy**: No data transmitted externally

## Compatibility

### Supported
- iPhone 7 (A1778) iOS 13.3.1
- checkra1n jailbreak
- Substrate-based environment

### Unsupported
- Other iPhone models (not tested)
- Different iOS versions
- Unc0ver or other jailbreaks (not tested)
- Rootless jailbreaks

## Contributing

This project is designed specifically for the target device mentioned above. Contributions for bug fixes and improvements are welcome.

### Development Guidelines

1. Follow existing code style and conventions
2. Test thoroughly on target device
3. Document all changes in commit messages
4. Update technical documentation as needed

## Legal Notice

This tool is intended for educational and research purposes. Users are responsible for complying with all applicable laws and regulations. The developers assume no responsibility for misuse of this software.

## License

This project is provided as-is for educational purposes. Use at your own risk.

## Support

For technical issues and questions:
1. Check the [Issues](../../issues) section
2. Review console logs for error messages
3. Verify compatibility with your specific device

---

**Version**: 2.0.0  
**Last Updated**: 2025  
**Status**: Active Development 