# StripeVCAM Bypass - Implementation Plan

## 🎯 Project Overview
**Target**: Stripe liveness detection bypass in Safari/WebView  
**Device**: iPhone 7 iOS 13.3.1 (checkra1n jailbreak)  
**Goal**: Replace camera feed with selected media during KYC verification  
**Approach**: Minimal code (~400 LoC), maximum effectiveness  

---

## 📋 Phase 1: Project Setup & Foundation
**Duration**: 1-2 hours  
**Status**: 🔄 In Progress

### 1.1 Repository Structure
```
StripeVCAMBypass/
├── .github/workflows/
│   └── build.yml                 # GitHub Actions workflow
├── Tweak.xm                      # Main hook implementation (~100 LoC)
├── VCAMOverlay.m                 # Simple overlay (~80 LoC)
├── MediaProcessor.m              # Basic media handling (~60 LoC)
├── VolumeHook.m                  # Volume detection (~40 LoC)
├── Makefile                      # Theos configuration
├── control                       # Debian package info
├── Preferences/
│   ├── StripeVCAMPrefs.m        # Settings (~50 LoC)
│   └── Resources/
│       └── Root.plist           # Settings UI
└── README.md                     # Installation guide
```

### 1.2 Dependencies Setup
- [ ] Initialize Theos project structure
- [ ] Configure MobileSubstrate dependencies
- [ ] Set up PreferenceLoader integration
- [ ] Create basic Makefile with iPhone 7 target

### 1.3 GitHub Actions Configuration
- [ ] Create workflow for artifact-only builds
- [ ] Configure iOS SDK and toolchain
- [ ] Set up .deb package generation
- [ ] Test build pipeline

---

## 🔧 Phase 2: Core Camera Hooks (Minimal Implementation)
**Duration**: 2-3 hours  
**Status**: ⏳ Pending

### 2.1 Primary Camera Hook (~50 LoC)
```objective-c
%hook AVCaptureVideoDataOutput
- (void)setSampleBufferDelegate:(id)delegate queue:(dispatch_queue_t)queue {
    // Intercept and replace with custom delegate
    %orig([VCAMProcessor sharedInstance], queue);
}
%end

%hook AVCaptureSession
- (void)startRunning {
    // Hook session start for WebView contexts only
    if ([self isWebViewContext]) {
        [VCAMProcessor enableReplacement];
    }
    %orig;
}
%end
```

### 2.2 Frame Replacement Engine (~40 LoC)
```objective-c
@interface VCAMProcessor : NSObject
+ (instancetype)sharedInstance;
- (void)replaceFrameWithMedia:(CVPixelBufferRef)pixelBuffer;
- (BOOL)isWebViewContext;
@end
```

### 2.3 WebView Detection (~30 LoC)
- [ ] Detect Safari/WKWebView contexts
- [ ] Identify Stripe domain patterns
- [ ] Minimal footprint detection logic

---

## 🎮 Phase 3: Volume Button Integration
**Duration**: 1 hour  
**Status**: ⏳ Pending

### 3.1 Hardware Event Hook (~40 LoC)
```objective-c
%hook SpringBoard
- (void)_handleVolumeButtonEvent:(IOHIDEventRef)event {
    if ([VCAMVolumeHandler shouldInterceptEvent:event]) {
        [VCAMOverlay toggleOverlay];
        return;
    }
    %orig;
}
%end
```

### 3.2 Double-Tap Detection (~20 LoC)
- [ ] Simple timing-based double-tap detection
- [ ] Configurable delay (default 300ms)
- [ ] Volume up/down differentiation

---

## 🖼️ Phase 4: Minimal UI Overlay
**Duration**: 2 hours  
**Status**: ⏳ Pending

### 4.1 Media Selection Overlay (~60 LoC)
```objective-c
@interface VCAMOverlay : UIWindow
- (void)showMediaPicker;
- (void)showDebugLogs;
- (void)selectImageFromGallery;
@end
```

### 4.2 Debug Log Overlay (~40 LoC)
```objective-c
@interface DebugOverlay : UIView
+ (void)log:(NSString *)message;
- (void)exportLogs;
- (void)clearLogs;
@end
```

### 4.3 UI Components
- [ ] Simple photo picker integration
- [ ] Basic debug log viewer with scroll
- [ ] Minimal styling for clarity
- [ ] Export functionality for logs

---

## 📱 Phase 5: Media Processing (Lightweight)
**Duration**: 1 hour  
**Status**: ⏳ Pending

### 5.1 Image/Video Handler (~50 LoC)
```objective-c
@interface MediaProcessor : NSObject
- (CVPixelBufferRef)processSelectedMedia:(UIImage *)image;
- (void)cacheProcessedFrame:(CVPixelBufferRef)frame;
- (CVPixelBufferRef)getCurrentFrame;
@end
```

### 5.2 Format Support
- [ ] JPG/PNG image processing
- [ ] Basic MP4 video frame extraction
- [ ] CVPixelBuffer conversion
- [ ] Memory-efficient caching

---

## ⚙️ Phase 6: Settings & Preferences
**Duration**: 1 hour  
**Status**: ⏳ Pending

### 6.1 Settings Bundle (~50 LoC)
```
Settings Options:
- Enable/Disable tweak
- Default media selection
- Volume button sensitivity
- Debug logging level
- Auto-enable for Stripe domains
```

### 6.2 PreferenceLoader Integration
- [ ] System Settings integration
- [ ] Preference synchronization
- [ ] Runtime configuration updates

---

## 🔄 Phase 7: GitHub Actions & Packaging
**Duration**: 1 hour  
**Status**: ⏳ Pending

### 7.1 Build Workflow
```yaml
name: Build StripeVCAM
on: [push, pull_request]
jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      - uses: Randomblock1/theos-action@v1
      - name: Build Package
        run: make package FINALPACKAGE=1
      - uses: actions/upload-artifact@v3
        with:
          name: StripeVCAMBypass.deb
          path: packages/*.deb
```

### 7.2 Package Configuration
- [ ] Debian control file setup
- [ ] Dependency specifications
- [ ] Installation scripts
- [ ] Proper file permissions

---

## 🧪 Phase 8: Testing & Validation
**Duration**: 2 hours  
**Status**: ⏳ Pending

### 8.1 Functionality Testing
- [ ] Volume button double-tap response
- [ ] Media selection and replacement
- [ ] Stripe KYC bypass validation
- [ ] Debug log accuracy

### 8.2 Stability Testing
- [ ] Memory leak detection
- [ ] Safe mode compatibility
- [ ] App crash prevention
- [ ] System performance impact

---

## 📦 Phase 9: Documentation & Deployment
**Duration**: 1 hour  
**Status**: ⏳ Pending

### 9.1 Installation Guide
```markdown
# Installation Instructions
1. Download .deb from GitHub Actions artifacts
2. Transfer to iPhone: `scp StripeVCAMBypass.deb root@[device-ip]:`
3. Install: `dpkg -i StripeVCAMBypass.deb`
4. Respring device
5. Configure in Settings > StripeVCAM
```

### 9.2 Usage Documentation
- [ ] Volume button activation guide
- [ ] Media selection process
- [ ] Troubleshooting common issues
- [ ] Debug log interpretation

---

## 📊 Code Estimation Summary
| Component | Lines of Code |
|-----------|---------------|
| Tweak.xm (main hooks) | ~100 LoC |
| VCAMOverlay.m (UI overlay) | ~80 LoC |
| MediaProcessor.m (media handling) | ~60 LoC |
| VolumeHook.m (button detection) | ~40 LoC |
| StripeVCAMPrefs.m (settings) | ~50 LoC |
| Supporting files | ~70 LoC |
| **Total** | **~400 LoC** |

---

## 🎯 Success Criteria
- [ ] Successful .deb generation via GitHub Actions
- [ ] Functional volume button activation
- [ ] Effective Stripe KYC bypass
- [ ] Stable operation on iPhone 7 iOS 13.3.1
- [ ] Debug logging for troubleshooting
- [ ] Clean installation/uninstallation

---

## 🔧 Technical Stack
- **Framework**: Theos + MobileSubstrate
- **Target**: iPhone 7 iOS 13.3.1 (arm64)
- **Dependencies**: PreferenceLoader, UIKit, AVFoundation
- **Build**: GitHub Actions with artifact upload
- **Package**: Debian (.deb) format

---

## 📝 Notes
- Focus on Stripe website KYC specifically
- Minimal code footprint for stealth
- Real-time debug logging capability
- Volume button activation for ease of use
- Gallery media selection for flexibility

**Project Confidence**: 100% ✅ 