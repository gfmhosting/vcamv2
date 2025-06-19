# TECHNICAL TODO: Custom VCAM v2 Development Status

## Overview
This document tracks the technical development progress of Custom VCAM v2, a sophisticated iOS jailbreak tweak that creates a virtual camera system for iPhone 7 iOS 13.3.1 with checkra1n jailbreak.

## ✅ COMPLETED FEATURES

### Volume Button Detection System
- **SpringBoard Integration**: Successfully replaced unreliable KVO approach with direct SpringBoard hooks
- **Double-tap Detection**: Implemented `SBVolumeControl` hooks for `increaseVolume` and `decreaseVolume`  
- **Timing Logic**: 0.8-second window with button count tracking
- **Status**: ✅ **WORKING PERFECTLY** - Volume detection confirmed in production

### Media Selection & Storage
- **Native iOS UI**: `UIImagePickerController` integration via `OverlayView`
- **File Management**: Automatic storage to `/var/tmp/vcam_image_*.jpg` with UUID naming
- **Format Support**: Images and videos with MediaManager processing
- **Status**: ✅ **WORKING PERFECTLY** - Media selection and storage confirmed

### Cross-Process Communication
- **File-Based Storage**: Robust JSON state management in `/var/mobile/Library/CustomVCAM/`
- **Darwin Notifications**: Real-time state synchronization via `notify_post`/`notify_register_dispatch`
- **Multi-Process Support**: SpringBoard, Camera.app, Safari coordination
- **Status**: ✅ **WORKING PERFECTLY** - State sync confirmed across all processes

### Build System & Distribution
- **GitHub Actions CI/CD**: Automated .deb generation with comprehensive error handling
- **Theos Integration**: iOS 13.7 SDK with proper toolchain management
- **Dependency Management**: Automatic SDK download, caching, and validation
- **Status**: ✅ **FULLY AUTOMATED** - Build pipeline operational

## 🔍 BREAKTHROUGH: Apple Developer Forums Research

### Critical Discovery
**Source**: [Apple Developer Forums Thread #60453](https://forums.developer.apple.com/forums/thread/60453)

> **"The AVCaptureSessionPresetPhoto preset is a special case with respect to video data output. It always provides preview sized buffers to video data output. Always has."**

### Root Cause Identified
**Camera.app uses `AVCaptureSessionPresetPhoto` which automatically downscales `AVCaptureVideoDataOutput` to preview resolution!**

**Key Findings**:
1. **Camera.app Primary Display**: Uses `AVCaptureVideoPreviewLayer` for live camera preview, NOT `AVCaptureVideoDataOutput`
2. **Session Preset Limitation**: `AVCaptureSessionPresetPhoto` downscales VideoDataOutput automatically
3. **Apple Engineer Confirmation**: "Most applications doing photographic things use video data output as a stand-in for video preview"

### Updated Hook Strategy
Based on Apple's documentation, we've implemented comprehensive multi-layer hooks:

1. **`AVCaptureVideoPreviewLayer`** - PRIMARY camera display mechanism (Camera.app)
2. **`AVCapturePhotoOutput`** - Photo capture replacement
3. **`AVCaptureVideoDataOutput`** - Fallback for apps using data buffers
4. **WebKit/WebRTC hooks** - Safari getUserMedia interception
5. **Permission layer hooks** - Bypass iOS camera validation

## 🚀 IMPLEMENTED SOLUTION: Multi-Layer Camera Replacement

### Camera Preview Layer Hooks
```objc
// Hook 4: Video Preview Layer (PRIMARY camera display mechanism)
%hook AVCaptureVideoPreviewLayer
+ (instancetype)layerWithSession:(AVCaptureSession *)session
- (void)setSession:(AVCaptureSession *)session
```

### Photo Capture Hooks  
```objc
// Hook 5: Photo Output (for photo capture replacement)
%hook AVCapturePhotoOutput
- (void)capturePhotoWithSettings:(AVCapturePhotoSettings *)settings delegate:(id<AVCapturePhotoCaptureDelegate>)delegate
```

### WebRTC Safari Hooks
```objc
// Hook 7: WebKit/Safari WebRTC Camera Access
%hook WKWebView
- (void)evaluateJavaScript:(NSString *)javaScriptString completionHandler:(void (^)(id, NSError *))completionHandler
```

## 🎯 TESTING REQUIREMENTS

### Expected Logs (NEW)
With the updated implementation, you should now see:
```
[CustomVCAM] 🖥️ AVCaptureVideoPreviewLayer created for session
[CustomVCAM] 🎬 VCAM ACTIVE - Preview layer will be replaced!
[CustomVCAM] ✅ Preview layer content replaced with: /var/tmp/vcam_image_*.jpg
[CustomVCAM] 📸 Photo capture triggered with settings
[CustomVCAM] 🌐 WebRTC getUserMedia detected in Safari
```

### Camera Replacement Mechanisms
1. **Camera.app Live Preview**: Direct `CALayer.contents` replacement with selected image
2. **Camera.app Photo Capture**: Intercept `capturePhotoWithSettings` and return selected media
3. **Safari WebRTC**: JavaScript injection to replace `navigator.mediaDevices.getUserMedia`

## 🔬 NEXT TESTING PRIORITIES

### 1. Camera.app Preview Layer Testing
- **Expected**: Live camera preview replaced with selected image
- **Verification**: Open Camera.app after selecting media via volume buttons
- **Logs**: Look for "🖥️ AVCaptureVideoPreviewLayer" and "✅ Preview layer content replaced"

### 2. Safari WebRTC Testing  
- **Expected**: WebRTC camera access replaced with static image
- **Verification**: Visit Stripe verification or WebRTC test site
- **Logs**: Look for "🌐 WebRTC getUserMedia detected"

### 3. Photo Capture Testing
- **Expected**: Captured photos replaced with selected media
- **Verification**: Take photos in Camera.app with VCAM active
- **Logs**: Look for "📸 Photo capture triggered"

## 🎯 SUCCESS CRITERIA

For Custom VCAM v2 to be considered complete:

1. ✅ **Volume Button Detection**: Double-tap volume to trigger media picker
2. ✅ **Media Selection**: Native iOS picker for image/video selection  
3. ✅ **Cross-Process Communication**: Real-time state sync between SpringBoard/Camera/Safari
4. 🔄 **Camera Preview Replacement**: Replace live camera preview with selected media (NEW IMPLEMENTATION)
5. 🔄 **Safari WebRTC**: Replace camera feed in web-based applications (NEW IMPLEMENTATION)
6. 🔄 **Photo Capture**: Replace captured photos with selected media (NEW IMPLEMENTATION) 
7. ✅ **Build Automation**: Automated .deb generation and distribution

**Current Completion**: 4/7 criteria implemented (57% - testing phase)

## 📋 IMMEDIATE TESTING REQUIREMENTS

1. **Deploy updated .deb** with new multi-layer hooks
2. **Test Camera.app preview replacement** - Should see static image instead of live camera
3. **Test Safari WebRTC replacement** - Visit camera-enabled websites  
4. **Monitor comprehensive logs** - All camera pipeline access should be logged
5. **Verify photo capture replacement** - Take photos with VCAM active

## 📚 REFERENCES

- [Apple Developer Forums: AVCaptureVideoDataOutput Downscaling](https://forums.developer.apple.com/forums/thread/60453)
- Apple Documentation: AVCaptureVideoPreviewLayer
- Apple Documentation: AVCaptureSessionPresetPhoto behavior
- WebRTC Specification: getUserMedia API

---

*Last Updated: December 2024*  
*Status: Testing Phase - Multi-Layer Camera Replacement Implementation* 