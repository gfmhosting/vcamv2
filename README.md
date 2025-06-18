# CustomVCAM - Virtual Camera for iOS

A jailbreak tweak that allows injecting custom media into camera feeds, designed to bypass camera-based verification systems.

## Features

- 📱 **Virtual Camera**: Replace camera feed with selected images/videos
- 🎵 **Volume Button Control**: Double-tap volume buttons to access controls
- 🌐 **WebRTC Support**: Works with Safari web camera access
- 📷 **Native Camera Support**: Hooks into iOS Camera app and AVFoundation
- 🎬 **Media Support**: Both images and videos supported
- 📝 **Debug Logging**: Comprehensive NSLog debugging

## Target Environment

- **Device**: iPhone 13 (A1778) - iOS 13.3.1 (17D50)
- **Jailbreak**: checkra1n compatible
- **Architecture**: arm64

## Installation

### Automatic Installation (Recommended)

1. Download the latest `.deb` file from [Releases](../../releases)
2. Transfer to your jailbroken device
3. Install using Filza or terminal:
   ```bash
   dpkg -i com.customvcam.tweak_1.0.0_iphoneos-arm.deb
   ```
4. Respring your device

### Manual Build

1. Install Theos development environment
2. Clone this repository
3. Build the package:
   ```bash
   make package
   ```

## Usage

1. **Activate Control Panel**: Double-tap volume up or down buttons
2. **Select Media**: Tap "Select Media" to choose image/video from library
3. **Enable VCAM**: Tap "Enable VCAM" to start virtual camera
4. **Use Camera**: Open Camera app or Safari - your selected media will replace the camera feed
5. **Disable**: Double-tap volume buttons again and tap "Disable VCAM"

## How It Works

The tweak hooks into several iOS frameworks:

- **AVFoundation**: Intercepts `AVCaptureVideoDataOutput` and `AVCaptureDevice`
- **WebKit**: Hooks WebRTC camera access for Safari
- **SpringBoard**: Captures volume button events
- **Media Injection**: Creates custom `CMSampleBuffer` from selected media

## Target Applications

- Camera.app (Native iOS camera)
- Safari.app (WebRTC camera access)
- Any app using AVFoundation camera APIs

## Debug Logging

All debug information is logged to Console with the prefix `[CustomVCAM]`. Use Console.app or device logs to troubleshoot:

```bash
log stream --predicate 'process == "Camera" OR process == "MobileSafari"' --style compact
```

## File Structure

```
CustomVCAM/
├── Makefile                 # Theos build configuration
├── control                  # Debian package metadata
├── CustomVCAM.plist        # Process filtering
├── Tweak.x                 # Main hooking logic
└── Sources/
    ├── MediaManager.h/m    # Media handling
    ├── OverlayView.h/m     # UI overlay system
    └── SimpleMediaManager.h/m  # Utilities
```

## Development

### Prerequisites
- Theos
- iOS SDK 13.7
- Xcode command line tools

### Building
```bash
make clean
make package FINALPACKAGE=1
```

### Dependencies
- mobilesubstrate
- preferenceloader
- iOS 13.0+

## Troubleshooting

1. **Overlay not showing**: Check volume button permissions and SpringBoard hooks
2. **Media not loading**: Verify photo library permissions
3. **Camera still shows real feed**: Ensure VCAM is enabled and media is selected
4. **Crashes**: Check Console logs for detailed error messages

## Security Notice

This tweak is designed for educational and testing purposes. Use responsibly and in accordance with applicable laws and terms of service.

## License

This project is for educational purposes only. Use at your own risk.

## Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Test thoroughly
5. Submit a pull request

---

**⚠️ Important**: This tweak modifies system camera behavior. Always test in a controlled environment first. 