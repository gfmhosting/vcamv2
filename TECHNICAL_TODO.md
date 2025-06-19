# Custom VCAM v2 - Technical TODO List

## Project Overview
iOS jailbreak tweak to replace camera feeds (native Camera app + Safari WebRTC) with preselected media for bypassing web ID verification on iPhone 7 iOS 13.3.1 17D50 model MN922B/A A1778 jailbroken with checkra1n.

## Phase 1: Core Infrastructure ✅ COMPLETE
### Setup & Configuration
- [x] Initialize Theos project structure
- [x] Configure Makefile for iOS 13.7 SDK
- [x] Set up control file with proper metadata
- [x] Create CustomVCAM.plist bundle configuration
- [x] Implement basic Tweak.x skeleton
- [x] Configure GitHub Actions build.yml with iOS toolchain
- [x] Fix build environment and dependencies

### Volume Button Detection System
- [x] Research IOHIDEventSystem hooking methods
- [x] Implement _IOHIDEventSystemClientSetMatching hook
- [x] Add volume button event filtering
- [x] Implement double-tap detection logic
- [x] Add debouncing to prevent false triggers
- [ ] Test volume button detection on target device

## Phase 2: Media System 📱
### Media Picker Integration
- [ ] Design center modal overlay UI
- [ ] Implement UIImagePickerController integration
- [ ] Add photo and video selection support
- [ ] Create media preview functionality
- [ ] Implement selection confirmation UI
- [ ] Add media type validation

### Media Processing Pipeline
- [ ] Implement HEIC to JPEG conversion
- [ ] Add H.264 video processing support
- [ ] Create CVPixelBuffer conversion system
- [ ] Implement media scaling and optimization
- [ ] Add format detection and validation
- [ ] Create media cache management

### Storage System
- [ ] Design secure media storage architecture
- [ ] Implement encrypted media persistence
- [ ] Add media metadata management
- [ ] Create media cleanup routines
- [ ] Implement storage quota management
- [ ] Add backup/restore functionality

## Phase 3: Camera Hooking System 🎥
### AVFoundation Integration
- [ ] Research AVCaptureSession hook points
- [ ] Implement AVCaptureVideoDataOutput hooks
- [ ] Add CMSampleBuffer replacement logic
- [ ] Create CVPixelBuffer injection system
- [ ] Implement frame rate matching
- [ ] Add camera session state management

### Safari WebRTC Hooking
- [ ] Research WebCore UserMediaRequest internals
- [ ] Implement WebCore::UserMediaRequest::start() hook
- [ ] Add WebRTC stream replacement logic
- [ ] Create getUserMedia interception
- [ ] Implement WebKit process communication
- [ ] Add Safari-specific error handling

### Media Injection Engine
- [ ] Create unified media injection interface
- [ ] Implement real-time media streaming
- [ ] Add synchronization between native/web cameras
- [ ] Create seamless switching mechanism
- [ ] Implement fallback systems
- [ ] Add performance optimization

## Phase 4: Integration & Polish ✨
### System Integration
- [ ] Connect volume detection to media picker
- [ ] Link media picker to injection system
- [ ] Implement activation state management
- [ ] Add system-wide camera replacement
- [ ] Create unified control interface
- [ ] Implement preferences system

### User Experience
- [ ] Design activation/deactivation feedback
- [ ] Add visual indicators for VCAM status
- [ ] Implement error messaging system
- [ ] Create user guidance and help
- [ ] Add accessibility features
- [ ] Optimize UI responsiveness

### Security & Anti-Detection
- [ ] Implement minimal system footprint
- [ ] Add dynamic hooking capabilities
- [ ] Create clean uninstall procedures
- [ ] Implement detection evasion techniques
- [ ] Add secure communication channels
- [ ] Create audit logging system

## Phase 5: Testing & Deployment 🚀
### Device Testing
- [ ] Test on iPhone 7 A1778 iOS 13.3.1
- [ ] Verify checkra1n compatibility
- [ ] Test native Camera app replacement
- [ ] Verify Safari WebRTC functionality
- [ ] Test Stripe web ID verification bypass
- [ ] Performance and stability testing

### Build & Distribution
- [ ] Finalize GitHub Actions CI/CD
- [ ] Create automated .deb packaging
- [ ] Add version management system
- [ ] Create installation documentation
- [ ] Implement update mechanisms
- [ ] Add troubleshooting guides

### Quality Assurance
- [ ] Code review and optimization
- [ ] Memory leak detection and fixing
- [ ] Crash testing and handling
- [ ] Edge case identification and handling
- [ ] Performance profiling and optimization
- [ ] Security audit and hardening

## Critical Technical Components

### Hook Targets
- **IOHIDEventSystem**: `_IOHIDEventSystemClientSetMatching` for volume buttons
- **WebCore::UserMediaRequest**: `start()` for Safari WebRTC
- **AVCaptureSession**: Camera session management
- **AVCaptureVideoDataOutput**: Video frame replacement
- **SpringBoard**: System integration

### Key Technologies
- **Theos/Substrate**: Method hooking framework
- **iOS 13.7 SDK**: Target platform compatibility
- **CVPixelBuffer**: Video frame manipulation
- **UIImagePickerController**: Media selection interface
- **GitHub Actions**: Automated build system

### Success Metrics
1. ✅ Volume double-tap triggers overlay (< 500ms response)
2. ✅ Media picker supports HEIC images and H.264 videos
3. ✅ Native Camera app shows selected media seamlessly
4. ✅ Safari WebRTC displays selected media without detection
5. ✅ Stripe web verification bypass success rate > 95%
6. ✅ System stability with no crashes or memory leaks
7. ✅ Installation via Filza with single respring activation

## Notes
- Target device: iPhone 7 iOS 13.3.1 17D50 model MN922B/A A1778
- Jailbreak: checkra1n
- Build environment: Windows 11 with GitHub Actions
- Primary use case: Bypassing Stripe web ID verification KYC

---
*Last updated: $(date)*
*Project status: Phase 1 - In Progress* 