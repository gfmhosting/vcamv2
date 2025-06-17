# StripeVCAM Bypass

A lightweight iOS tweak for bypassing Stripe's liveness detection in KYC verification by replacing camera feed with selected media from gallery.

## 🎯 Features

- **Camera Feed Replacement**: Replace live camera with images/videos from gallery
- **Volume Button Activation**: Double-tap volume buttons to activate overlay
- **Debug Logging**: Real-time logging with exportable debug information
- **Stripe KYC Focus**: Specifically designed for Stripe liveness detection bypass
- **Minimal Footprint**: ~400 lines of code for maximum stealth

## 📱 Compatibility

- **Device**: iPhone 7 (arm64)
- **iOS Version**: 13.3.1
- **Jailbreak**: checkra1n
- **Dependencies**: MobileSubstrate, PreferenceLoader

## 📦 Installation

### Method 1: Download from Releases
1. Download `StripeVCAMBypass.deb` from [GitHub Releases](../../releases)
2. Transfer to your iPhone: `scp StripeVCAMBypass.deb root@[device-ip]:`
3. SSH into device: `ssh root@[device-ip]`
4. Install package: `dpkg -i StripeVCAMBypass.deb`
5. Respring device: `killall -9 SpringBoard`

### Method 2: Build from Source
1. Clone repository: `git clone [repo-url]`
2. Install Theos and dependencies
3. Build: `make package FINALPACKAGE=1`
4. Install generated .deb file

## 🚀 Usage

### Activation
1. Open Safari or any app with camera access
2. Navigate to Stripe KYC verification page
3. **Double-tap volume up or down** to activate overlay
4. Select "📷 Select Media" to choose replacement image/video
5. Proceed with KYC verification

### Debug Logs
1. Activate overlay with volume double-tap
2. Select "🐛 Debug Logs" to view real-time logging
3. Use "Clear" to reset logs or "Close" to return
4. Logs show camera hooks, frame replacement, and system events

## ⚙️ Configuration

Currently no settings panel - operates automatically when:
- Camera session starts in web context (Safari/WebView)
- Stripe or similar KYC domain is detected
- Volume button double-tap is registered

## 🔧 Technical Details

### Components
- **Tweak.xm**: Main camera hooks and WebView detection
- **VCAMOverlay.m**: UI overlay for media selection and debug logs
- **MediaProcessor.m**: CVPixelBuffer manipulation and frame replacement
- **VolumeHook.m**: Double-tap detection with 300ms threshold

### Camera Hooks
- `AVCaptureSession` - Session management and WebView context detection
- `AVCaptureVideoDataOutput` - Sample buffer delegate interception
- Frame replacement via CVPixelBuffer manipulation

### Volume Button Detection
- SpringBoard hook for volume events
- Double-tap timing with configurable threshold
- Non-intrusive - single taps pass through normally

## 🐛 Troubleshooting

### Common Issues

**Overlay not appearing:**
- Ensure volume buttons are working normally
- Try double-tapping with shorter intervals
- Check debug logs for volume event detection

**Camera replacement not working:**
- Verify you've selected media from gallery
- Check if camera session is active in web context
- Review debug logs for frame replacement messages

**App crashes or safe mode:**
- Check device compatibility (iPhone 7, iOS 13.3.1)
- Ensure all dependencies are installed
- Try disabling other camera-related tweaks

### Debug Information
Access debug logs via overlay to see:
- Camera session status
- Frame replacement activity
- Volume button events
- WebView context detection
- Memory and processing information

### Log Export
Debug logs can be copied to clipboard for sharing or analysis.

## ⚠️ Disclaimer

This tweak is for educational and research purposes only. Users are responsible for complying with applicable laws and terms of service. The developers assume no liability for misuse.

## 🔒 Privacy & Security

- No network connections or data transmission
- All processing happens locally on device
- No persistent storage of sensitive information
- Minimal system footprint for stealth operation

## 📄 License

This project is provided as-is for educational purposes.

## 🤝 Contributing

1. Fork the repository
2. Create feature branch
3. Make changes with minimal code impact
4. Test on iPhone 7 iOS 13.3.1
5. Submit pull request

## 📞 Support

For issues or questions:
- Check debug logs first
- Review troubleshooting section
- Open GitHub issue with device info and logs
- Include steps to reproduce problem

---

**Built with ❤️ for the jailbreak community** 