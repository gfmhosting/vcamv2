# Custom VCAM v2

Advanced virtual camera solution for jailbroken iOS devices. Replace camera feeds with gallery media to bypass web ID verification systems like Stripe.

## 🎯 Features

- **Universal Camera Replacement**: Works with Safari, Instagram, Camera app, FaceTime, and more
- **Volume Button Activation**: Double-click volume up/down to access controls
- **Gallery Integration**: Select any photo or video from your gallery
- **Detection Avoidance**: Randomized metadata and realistic camera characteristics
- **Multi-App Support**: Hooks into all camera-using applications simultaneously
- **Lightweight**: Minimal battery and performance impact

## 📱 Compatibility

- **Device**: iPhone 7 (Model A1778, MN922B/A) - Optimized specifically for this model
- **iOS Version**: 13.3.1 (17D50)
- **Jailbreak**: checkra1n (recommended)
- **Architecture**: arm64

*Note: This build is specifically optimized for the target device. Other devices may require modifications.*

## 🚀 Installation

### Prerequisites
- iPhone 7 jailbroken with checkra1n
- Filza File Manager or similar file manager
- iTunes/3uTools for file transfer (optional)

### Installation Steps

1. **Download the .deb file**
   - Go to [GitHub Actions](../../actions)
   - Download the latest `CustomVCAM-deb` artifact
   - Extract the .deb file

2. **Transfer to iPhone**
   - Via iTunes: Add to Files app or any accessible folder
   - Via AirDrop: Send directly to iPhone
   - Via 3uTools: Drag and drop to device

3. **Install using Filza**
   - Open Filza File Manager
   - Navigate to the .deb file location
   - Tap the .deb file
   - Select "Install"
   - Wait for installation to complete

4. **Respring**
   - The device will automatically respring
   - Or manually respring using your preferred method

## 📖 Usage

### Activation
1. **Double-click** volume up or volume down button
2. The VCAM overlay will appear at the top of the screen
3. The overlay auto-hides after 5 seconds

### Configuration
1. **Enable VCAM**: Toggle the switch in the overlay
2. **Select Media**: Tap "Select Media" button
3. **Choose Content**: Pick an image or video from your gallery
4. **Grant Permissions**: Allow photo access if prompted

### Testing
1. Open any camera app (Safari, Instagram, Camera, etc.)
2. The selected media should replace the live camera feed
3. To disable, double-click volume again and toggle off

## 🛠 Technical Details

### How It Works
- **Camera Hooks**: Intercepts `AVCaptureVideoDataOutput` sample buffers
- **Volume Detection**: Hooks SpringBoard volume controls for activation
- **Media Processing**: Converts gallery media to camera-compatible formats
- **Metadata Spoofing**: Randomizes EXIF data and camera characteristics

### Supported Applications
- Safari (web cameras)
- Instagram
- Facebook
- Snapchat
- WhatsApp
- Skype
- FaceTime
- Native Camera app
- Most camera-using applications

### Security Features
- Randomized timestamps
- Spoofed camera metadata (focal length, ISO, aperture)
- Realistic device characteristics
- Maintained frame timing

## 🔧 Troubleshooting

### Common Issues

**Overlay not appearing:**
- Ensure you're double-clicking volume buttons quickly
- Try with different timing intervals
- Check if tweak is loaded: look for "[CustomVCAM]" in device logs

**Camera not replaced:**
- Verify VCAM is enabled in overlay
- Check that media is selected
- Restart the camera app
- Grant photo permissions if prompted

**Installation failed:**
- Ensure Filza has root access
- Try installing in safe mode
- Check available storage space
- Verify .deb file integrity

### Logs
View detailed logs in Console app or via SSH:
```bash
grep -i "CustomVCAM" /var/log/syslog
```

## 🚨 Legal Notice

This tool is for educational and research purposes only. Users are responsible for complying with all applicable laws and terms of service. The developers do not encourage or condone the use of this software for illegal activities or to violate terms of service of any platform.

## 🏗 Building from Source

### Requirements
- macOS with Xcode
- Theos development environment
- iOS 13 SDK

### Build Steps
```bash
git clone https://github.com/yourusername/Custom-VCAM-v2.git
cd Custom-VCAM-v2
make clean
make package FINALPACKAGE=1
```

### GitHub Actions
This project uses automated builds via GitHub Actions. Every push to main branch triggers a build that:
- Sets up Theos environment
- Compiles the project
- Generates .deb package
- Uploads artifacts for download

## 📋 Project Structure

```
Custom VCAM v2/
├── .github/workflows/build.yml    # GitHub Actions workflow
├── Sources/
│   ├── MediaManager.h/.m          # Gallery integration
│   └── OverlayView.h/.m          # Volume button UI
├── Tweak.x                       # Main hook implementation
├── Makefile                      # Build configuration
├── control                       # Package metadata
├── CustomVCAM.plist             # Process filtering
├── TECHNICAL_TODO.md            # Development roadmap
└── README.md                    # This file
```

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Test thoroughly
5. Submit a pull request

## 📄 License

This project is provided as-is for educational purposes. See LICENSE file for details.

## 🔗 Related Resources

- [Theos Documentation](https://theos.dev/)
- [iOS Jailbreak Development](https://iphonedev.wiki/)
- [Substrate Documentation](http://www.cydiasubstrate.com/)
- [checkra1n Jailbreak](https://checkra.in/)

## ⚠️ Disclaimer

This software modifies system behavior and camera functionality. Use at your own risk. Always maintain backups and be prepared to restore your device if issues occur. The developers are not responsible for any damage or consequences resulting from the use of this software.

---

**Version**: 1.0.0  
**Build**: GitHub Actions Automated  
**Target**: iPhone 7 iOS 13.3.1 17D50  
**Last Updated**: 2025 