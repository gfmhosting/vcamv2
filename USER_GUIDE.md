# Custom VCAM v2 - User Guide

![Custom VCAM v2 Banner](https://img.shields.io/badge/Custom%20VCAM-v2.0.0-blue) ![iOS](https://img.shields.io/badge/iOS-13.3.1-green) ![Device](https://img.shields.io/badge/iPhone-7-orange) ![Jailbreak](https://img.shields.io/badge/Jailbreak-checkra1n-red)

## 🎯 What is Custom VCAM v2?

Custom VCAM v2 is a **virtual camera system** for jailbroken iPhones that lets you replace your live camera feed with any photo or video from your library. When apps try to access your camera, they'll see your selected media instead of the real camera view.

Think of it as a **"green screen" for your entire iPhone** - but instead of replacing backgrounds, it replaces the entire camera input.

## 🤔 Why Would You Need This?

### Primary Use Cases

**🔐 Identity Verification Bypass**
- **Stripe ID verification** on websites
- **KYC (Know Your Customer)** processes 
- **Document verification** systems
- **Age verification** on platforms
- **WebRTC camera checks** in browsers

**🛡️ Privacy Protection**
- Avoid showing your real face during verification
- Protect your identity while using services
- Control what information you share
- Maintain anonymity on verification-required platforms

**🎭 Creative Applications**
- Use custom images for video calls
- Create content with consistent "camera" input
- Test applications that require camera access
- Demonstrate camera-based features

## 🎛️ How It Works

### The Magic Behind the Scenes

1. **📱 Volume Button Detection**
   - Double-tap your volume buttons (up or down)
   - Custom VCAM detects the gesture at the system level
   - No need to open any apps or settings

2. **🖼️ Media Selection**
   - Native iOS photo picker appears automatically
   - Choose any photo or video from your library
   - Supports all iOS formats (HEIC, JPEG, MP4, MOV)

3. **🔄 Real-Time Replacement**
   - Your selected media gets converted to camera format
   - All apps now see your chosen image/video instead of live camera
   - Works across the entire system - Camera app, Safari, any app with camera access

4. **🔗 Cross-App Communication**
   - Selection made in SpringBoard works in all apps
   - State persists across app launches
   - No need to reselect media for each app

## 📱 Compatible Devices

| Device | iOS Version | Jailbreak | Status |
|--------|------------|-----------|---------|
| **iPhone 7 (A1778)** | **13.3.1** | **checkra1n** | ✅ **Fully Supported** |
| iPhone 7 Plus | 13.3.1 | checkra1n | ⚠️ *Likely Compatible* |
| iPhone 6s/6s+ | 13.3.1 | checkra1n | ⚠️ *Untested* |
| Other Devices | Any | Any | ❌ *Not Tested* |

**Note:** This tweak is specifically engineered for iPhone 7 iOS 13.3.1 with checkra1n jailbreak.

## 🚀 Installation Guide

### Step 1: Download
1. Go to [GitHub Releases](https://github.com/gfmhosting/vcamv2/releases)
2. Download the latest `.deb` file
3. Transfer to your jailbroken iPhone via:
   - AirDrop (easiest)
   - Filza Web Server
   - SSH/SCP

### Step 2: Install
**Using Filza:**
1. Open Filza File Manager
2. Navigate to the downloaded `.deb` file
3. Tap the file → "Install"
4. Tap "Confirm"
5. Wait for installation to complete

**Using Terminal/SSH:**
```bash
dpkg -i com.customvcam.vcam_*.deb
killall SpringBoard
```

### Step 3: Respring
- Use Filza's "Respring" option
- Or run `killall SpringBoard` via SSH
- Your device will restart the SpringBoard

### Step 4: Verify
- Double-tap volume buttons
- If media picker appears, installation was successful!

## 🎮 How to Use

### Activation (First Time)
1. **Double-tap volume buttons** quickly (up or down, doesn't matter)
2. **Native iOS photo picker** will appear
3. **Select any photo or video** from your library
4. **Tap "Choose"** to confirm selection
5. **Custom VCAM is now active!**

### Using with Apps

**📷 Camera App:**
1. Open the native Camera app
2. Instead of live camera, you'll see your selected image/video
3. Take "photos" or record "videos" of your selected media

**🌐 Web Browsers (Safari, Chrome):**
1. Visit any website requiring camera access
2. Grant camera permission when prompted  
3. Website will receive your selected media instead of live camera
4. Perfect for Stripe verification, WebRTC calls, etc.

**📱 Any Camera App:**
- Instagram, Snapchat, Zoom, etc.
- All will receive your virtual camera feed
- No additional configuration needed

### Changing Media
1. **Double-tap volume buttons** again
2. **Select different media** from picker
3. **New selection** immediately replaces the old one

### Deactivation
- **Restart your device** to disable Custom VCAM
- **Or select different media** to change what's shown
- No permanent changes to your system

## 📋 What You'll See in Logs

When Custom VCAM is working correctly, you'll see logs like this:

```
[CustomVCAM] SpringBoard volume UP detected
[CustomVCAM] Volume button count: 2 (within 0.8s)
[CustomVCAM] DOUBLE-TAP DETECTED! Triggering media picker
[CustomVCAM] Media selected: /var/tmp/vcam_image_[ID].jpg
[CustomVCAM] Media injection activated for Stripe bypass
[CustomVCAM] Camera capture detected - replacing with: [your_image]
[CustomVCAM] Successfully created replacement sample buffer
```

## 🔧 Troubleshooting

### Volume Buttons Not Working
- **Try different timing** - tap faster or slower
- **Check other tweaks** - disable conflicting volume button tweaks
- **Respring device** and try again
- **Look for logs** in Console app or via SSH

### Media Not Replacing Camera
- **Check app permissions** - ensure apps have camera access
- **Try different media** - some formats may not work perfectly
- **Reselect media** - double-tap volume and choose again
- **Restart target app** after selecting media

### App Crashes
- **Compatible device check** - ensure you're on iPhone 7 iOS 13.3.1
- **Respring device** to reset tweak state
- **Reinstall tweak** if problems persist

## ⚠️ Important Considerations

### Legal & Ethical Use
- **Educational purposes only** - understand the technology
- **Respect terms of service** - don't violate platform policies
- **Use responsibly** - consider the ethics of bypassing verification
- **Legal compliance** - ensure your use is lawful in your jurisdiction

### Privacy & Security
- **No data transmission** - everything happens locally
- **Temporary storage** - selected media is cleaned up automatically
- **No network communication** - completely offline operation
- **Standard iOS permissions** - uses normal photo library access

### Technical Limitations
- **Single device support** - iPhone 7 iOS 13.3.1 only
- **Substrate dependency** - requires Cydia Substrate
- **Process-specific** - works in SpringBoard, Camera, Safari
- **Media format limits** - best with standard iOS formats

## 🎯 Real-World Applications

### Example Scenario: Stripe Verification
1. **Website requests ID verification** via camera
2. **Double-tap volume buttons** on your iPhone
3. **Select photo of your ID** from camera roll
4. **Continue with website verification** 
5. **Website receives your ID photo** instead of live camera
6. **Verification process completes** using your selected image

### Example Scenario: Privacy Protection
1. **Platform requires face verification**
2. **Double-tap volume buttons**
3. **Select neutral/stock photo** from library
4. **Continue with verification process**
5. **Your real face never transmitted** to the service

## 🔬 Technical Details (For Advanced Users)

### Architecture
- **SpringBoard hooks** for volume button detection
- **AVFoundation interception** for camera replacement
- **Cross-process communication** via NSUserDefaults
- **Real-time media conversion** using CoreVideo/CoreMedia

### File Structure
```
Custom VCAM v2/
├── Tweak.x                     # Main implementation
├── Sources/
│   ├── MediaManager.m          # Media processing engine
│   ├── OverlayView.m          # UI interface
│   └── SimpleMediaManager.m   # Utility functions
├── Makefile                   # Build configuration
└── control                    # Package metadata
```

### Build System
- **GitHub Actions CI/CD** with automated builds
- **Theos framework** for jailbreak development
- **Modern toolchain** with multiple fallback sources
- **Automatic .deb generation** on every commit

## 🆘 Support & Community

### Getting Help
1. **Check logs first** - most issues show up in console
2. **Review troubleshooting** section above
3. **Search existing issues** on GitHub
4. **Provide device info** when reporting problems

### Contributing
- **Bug reports** - include device model, iOS version, logs
- **Feature requests** - explain use case and benefits
- **Code contributions** - follow existing style and test thoroughly

### Community Guidelines
- **Be respectful** and constructive
- **Help others** when you can
- **Share knowledge** and experiences
- **Use responsibly** and ethically

---

## 📄 License & Disclaimer

**This software is provided for educational and research purposes only.**

- **No warranty** express or implied
- **Use at your own risk**
- **Educational use only**
- **Respect all applicable laws and terms of service**

**The developers assume no responsibility for:**
- Misuse of this software
- Device damage or data loss  
- Violation of terms of service
- Legal consequences of usage

---

**Built with ❤️ for the jailbreak community**

*Custom VCAM v2 - Bringing virtual camera technology to iOS 13.3.1* 