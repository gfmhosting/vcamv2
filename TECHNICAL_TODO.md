# Technical Implementation Notes

## Current Implementation Status

### ✅ Completed Features
- [x] Basic Theos project structure
- [x] Volume button hook for overlay trigger
- [x] Media selection UI overlay
- [x] AVFoundation camera output interception
- [x] Image to CVPixelBuffer conversion
- [x] Video frame extraction and playback
- [x] CMSampleBuffer creation utilities
- [x] WebRTC camera hooks (RTCCameraVideoCapturer)
- [x] Debug logging system
- [x] GitHub Actions build pipeline

### 🔄 In Progress / Needs Testing
- [ ] WebKit camera permission hooks validation
- [ ] Stripe ID verification bypass testing
- [ ] Memory management optimization
- [ ] Error handling for edge cases

### 📋 Future Enhancements
- [ ] Custom video encoding options
- [ ] Multiple media preset slots
- [ ] Settings panel in Preferences app
- [ ] Real-time video effects
- [ ] Network stream injection
- [ ] Face detection alignment

## Technical Architecture

### Hook Points Analysis

#### 1. Volume Button Detection
```objective-c
// SpringBoard hook - SBVolumeHardwareButtonActions
- volumeIncreasePress: / volumeDecreasePress:
```
**Status**: ✅ Implemented
**Notes**: Double-tap detection with 0.5s interval threshold

#### 2. Camera Output Interception
```objective-c
// AVFoundation hook
AVCaptureVideoDataOutput captureOutput:didOutputSampleBuffer:fromConnection:
```
**Status**: ✅ Implemented
**Notes**: Replaces CMSampleBuffer with custom media data

#### 3. WebRTC Camera Hooks
```objective-c
// WebKit/WebRTC hooks
RTCCameraVideoCapturer startCaptureWithDevice:
WKWebView _requestUserMediaAuthorizationForDevices:
```
**Status**: ✅ Implemented
**Notes**: May need additional WebKit private API hooks

### Media Processing Pipeline

1. **Media Selection**: UIImagePickerController → MediaManager
2. **Format Conversion**: UIImage/Video → CVPixelBuffer
3. **Sample Buffer Creation**: CVPixelBuffer → CMSampleBuffer
4. **Injection**: Replace original camera output

### Memory Management Considerations

- CVPixelBuffer reference counting
- CMSampleBuffer lifecycle management
- Video player memory cleanup
- UI overlay view hierarchy management

## Known Issues & Solutions

### Issue 1: WebRTC Detection
**Problem**: WebRTC hooks may not cover all Safari camera access points
**Solution**: Add more WebKit private API hooks:
```objective-c
// Additional hooks needed:
- [WKWebView _evaluateJavaScript:...]
- [WebCore::MediaDevicesRequest...]
```

### Issue 2: Memory Leaks
**Problem**: CVPixelBuffer/CMSampleBuffer not properly released
**Solution**: Implement proper reference counting in MediaManager

### Issue 3: Video Synchronization
**Problem**: Video playback timing may not match camera frame rate
**Solution**: Implement frame interpolation and timing adjustment

## Testing Strategy

### Unit Testing
- MediaManager pixel buffer generation
- Sample buffer creation/destruction
- Volume button timing detection

### Integration Testing
- Camera app compatibility
- Safari WebRTC functionality
- Stripe verification bypass
- Memory usage under load

### Device Testing Matrix
| App | Test Case | Expected Result |
|-----|-----------|----------------|
| Camera.app | Photo capture with VCAM | Custom media in photo |
| Camera.app | Video recording | Custom media in video |
| Safari | WebRTC getUserMedia | Custom media in web stream |
| Third-party apps | Camera access | Custom media injection |

## Performance Optimization

### Memory Usage
- Lazy load video assets
- Implement frame caching strategy
- Use lower resolution for preview
- Clean up unused pixel buffers

### CPU Usage
- Optimize pixel buffer conversion
- Implement frame rate limiting
- Use hardware acceleration where possible

### Battery Impact
- Monitor background processing
- Implement sleep mode for unused features
- Optimize video decoding pipeline

## Security Considerations

### Detection Avoidance
- Randomize hook timing
- Implement natural camera behavior simulation
- Add jitter to frame timing
- Obfuscate debug strings in release builds

### API Stability
- Monitor iOS updates for hook compatibility
- Implement fallback mechanisms
- Version-specific hook implementations

## Build System Improvements

### Current GitHub Actions
- Ubuntu-based Theos build
- Automatic .deb generation
- Release management

### Planned Improvements
- macOS build support for better iOS SDK compatibility
- Code signing for distribution
- Automated testing pipeline
- Multi-architecture builds

## Code Quality

### Current Standards
- Objective-C ARC enabled
- Comprehensive logging
- Error handling in critical paths

### Improvements Needed
- Unit test coverage
- Static analysis integration
- Memory leak detection
- Performance profiling

## Distribution Strategy

### Current Method
- Manual .deb installation via Filza
- GitHub releases

### Future Options
- Cydia repository hosting
- Package manager integration
- Over-the-air updates
- Beta testing program

---

## Development Environment Setup

### Required Tools
```bash
# Theos installation
git clone --recursive https://github.com/theos/theos.git $THEOS
echo "export THEOS=~/theos" >> ~/.profile

# iOS SDK setup
cd $THEOS/sdks
# Download and extract iOS 13.7 SDK
```

### IDE Configuration
- Xcode for Objective-C syntax
- VS Code with Theos extension
- Logos syntax highlighting

### Debugging Setup
```bash
# Device console monitoring
ssh root@device.ip "tail -f /var/log/syslog | grep CustomVCAM"

# Real-time logging
log stream --predicate 'eventMessage contains "CustomVCAM"'
```

This technical documentation should be updated as development progresses and new challenges are discovered. 