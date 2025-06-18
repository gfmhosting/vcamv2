# CustomVCAM - Technical Implementation TODO

## Project Overview
**Goal:** Create a VCAM clone for iPhone 7 iOS 13.3.1 (checkra1n) that bypasses web KYC verification systems like Stripe by replacing camera input with pre-selected media.

**Target Device:** iPhone 7, iOS 13.3.1, checkra1n jailbreak  
**Build System:** GitHub Actions + Theos  
**Distribution:** .deb package via Cydia/manual installation  

---

## PHASE 1: Project Foundation & Setup
**Status:** ✅ COMPLETED  
**Estimated Time:** 2-3 hours | **Actual Time:** 2 hours

### Core Structure
- [x] Create project directory structure
- [x] Initialize Theos project with `nic.pl`
- [x] Configure Makefile for iOS 13.3.1 compatibility
- [x] Set up control file with proper dependencies
- [x] Create bundle filter plist for system-wide injection
- [x] Initialize git repository

### GitHub Actions Setup
- [x] Create `.github/workflows/build.yml`
- [x] Configure theos-action with iOS 13.0 SDK
- [x] Test build pipeline with basic tweak
- [x] Set up artifact upload for .deb packages
- [x] Configure automatic releases on tag push

### Basic Project Files
- [x] Create main `Tweak.x` with basic hook structure
- [x] Set up header files for interfaces
- [x] Create resource bundle structure
- [x] Add basic logging and debug capabilities

---

## PHASE 2: Camera Hook Implementation
**Status:** ⏳ PENDING  
**Estimated Time:** 4-6 hours

### UIImagePickerController Hooks
- [ ] Hook `presentViewController` to intercept camera presentation
- [ ] Hook `setSourceType` to redirect camera to photo library
- [ ] Hook delegate methods for image/video selection
- [ ] Test with various apps (Camera, Safari, etc.)

### AVFoundation Hooks
- [ ] Hook `AVCaptureSession.startRunning`
- [ ] Hook `AVCaptureVideoPreviewLayer` for preview replacement
- [ ] Hook `AVCapturePhotoOutput` for photo capture
- [ ] Hook `AVCaptureMovieFileOutput` for video capture
- [ ] Implement media injection into capture pipeline

### WebView Integration
- [ ] Hook WKWebView getUserMedia requests
- [ ] Hook Safari camera permission dialogs
- [ ] Intercept HTML5 `<input type="file">` with camera
- [ ] Test with Stripe KYC and similar systems

---

## PHASE 3: Media Management System
**Status:** ⏳ PENDING  
**Estimated Time:** 3-4 hours

### Media Bundle Creation
- [ ] Source realistic ID document images (various countries)
- [ ] Create convincing selfie photos (different lighting/angles)
- [ ] Generate verification videos (head movements, blinking)
- [ ] Optimize file sizes for mobile deployment
- [ ] Organize media by verification type

### MediaManager Class
- [ ] Create `MediaManager` singleton for media access
- [ ] Implement random/sequential media selection
- [ ] Add metadata support (document type, person info)
- [ ] Create caching system for performance
- [ ] Add media validation and format conversion

### Integration Points
- [ ] Connect MediaManager to camera hooks
- [ ] Implement seamless media replacement
- [ ] Add fallback mechanisms for unsupported formats
- [ ] Test media delivery performance

---

## PHASE 4: Overlay Interface System
**Status:** ⏳ PENDING  
**Estimated Time:** 3-4 hours

### OverlayView Implementation
- [ ] Create transparent overlay for camera interface
- [ ] Design single-button activation system
- [ ] Implement touch detection and button positioning
- [ ] Add visual feedback for user interactions
- [ ] Ensure overlay works across different screen sizes

### Media Selection UI
- [ ] Create media picker interface
- [ ] Implement thumbnail generation for quick preview
- [ ] Add category filters (ID, selfie, video)
- [ ] Design intuitive selection workflow
- [ ] Add preview functionality before selection

### Integration with Camera Systems
- [ ] Inject overlay into UIImagePickerController
- [ ] Add overlay to AVCaptureVideoPreviewLayer
- [ ] Handle orientation changes and rotations
- [ ] Test overlay positioning across apps

---

## PHASE 5: System Integration & Compatibility
**Status:** ⏳ PENDING  
**Estimated Time:** 4-5 hours

### iOS 13.3.1 Compatibility
- [ ] Test all hooks on target iOS version
- [ ] Verify ARM64 architecture compatibility
- [ ] Handle deprecated API usage warnings
- [ ] Implement version-specific workarounds
- [ ] Test MobileSubstrate injection

### Cross-App Testing
- [ ] Test with native Camera app
- [ ] Test with Safari web KYC
- [ ] Test with Chrome browser
- [ ] Test with banking apps
- [ ] Test with various photo apps

### Performance Optimization
- [ ] Optimize memory usage for camera hooks
- [ ] Minimize CPU impact during media replacement
- [ ] Implement lazy loading for media assets
- [ ] Profile and optimize hot code paths

---

## PHASE 6: Advanced Bypass Mechanisms
**Status:** ⏳ PENDING  
**Estimated Time:** 5-6 hours

### Detection Evasion
- [ ] Implement EXIF data manipulation
- [ ] Add realistic camera metadata to injected media
- [ ] Randomize file timestamps and properties
- [ ] Implement anti-detection techniques
- [ ] Test against common verification algorithms

### Multi-Level Hooking
- [ ] Implement redundant hook points
- [ ] Add fallback mechanisms for missed hooks
- [ ] Create comprehensive API coverage
- [ ] Handle edge cases and unusual implementations

### Real-time Processing
- [ ] Implement on-the-fly media modification
- [ ] Add dynamic overlay positioning
- [ ] Handle live video stream replacement
- [ ] Optimize for real-time performance

---

## PHASE 7: Testing & Quality Assurance
**Status:** ⏳ PENDING  
**Estimated Time:** 3-4 hours

### Comprehensive Testing
- [ ] Test all major verification systems (Stripe, etc.)
- [ ] Test across different browsers and webviews
- [ ] Verify no crashes or system instability
- [ ] Test memory leaks and resource management
- [ ] Performance testing on iPhone 7

### Edge Case Handling
- [ ] Test with low memory conditions
- [ ] Handle network failures gracefully
- [ ] Test with various camera permissions
- [ ] Handle app backgrounding/foregrounding
- [ ] Test with multiple concurrent camera requests

### User Experience Testing
- [ ] Verify seamless operation from user perspective
- [ ] Test overlay responsiveness
- [ ] Validate media selection workflow
- [ ] Ensure no visible artifacts or glitches

---

## PHASE 8: Documentation & Deployment
**Status:** ⏳ PENDING  
**Estimated Time:** 2-3 hours

### Documentation
- [ ] Create comprehensive README
- [ ] Document installation procedures
- [ ] Add troubleshooting guide
- [ ] Create media bundle guidelines
- [ ] Document known limitations

### Final Package Preparation
- [ ] Create final .deb package
- [ ] Test installation on clean device
- [ ] Verify automatic GitHub releases
- [ ] Create installation instructions
- [ ] Prepare distribution channels

### Security Documentation
- [ ] Document privacy implications
- [ ] Add legal disclaimers
- [ ] Create responsible use guidelines
- [ ] Document detection risks

---

## Success Criteria

### Primary Goals
- ✅ System-wide camera hook affecting all apps
- ✅ Successful bypass of Stripe KYC verification
- ✅ Stable operation on iPhone 7 iOS 13.3.1
- ✅ Automatic GitHub Actions build pipeline
- ✅ Simple user interaction (single button overlay)

### Secondary Goals
- ✅ Support for multiple verification systems
- ✅ High-quality realistic media bundle
- ✅ No visible detection by verification algorithms
- ✅ Minimal performance impact
- ✅ Easy installation and updates

---

## Risk Assessment

### High Risk
- 🔴 Detection by advanced verification systems
- 🔴 iOS version compatibility issues
- 🔴 MobileSubstrate injection failures

### Medium Risk
- 🟡 Performance impact on older hardware
- 🟡 App-specific hook compatibility
- 🟡 Media quality detection

### Low Risk
- 🟢 Build pipeline issues
- 🟢 Basic functionality implementation
- 🟢 User interface design

---

## Timeline
**Total Estimated Time:** 26-34 hours  
**Target Completion:** Phase-by-phase implementation  
**Critical Path:** Phases 1 → 2 → 3 → 7 (core functionality)

**Current Phase:** Phase 1 - Project Foundation & Setup 