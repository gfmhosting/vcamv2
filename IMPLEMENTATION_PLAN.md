# StripeVCAM Bypass - Implementation Guide

## Project Overview
A lightweight iOS jailbreak tweak that bypasses Stripe's liveness KYC verification by replacing the camera feed with selected media. This tweak works on iPhone 7 running iOS 13.3.1 with checkra1n jailbreak.

---

## Phase 1: Project Setup & Foundation ⏰ (1-2 hours)

### Repository Structure
- [ ] Create project directory structure
- [ ] Initialize git repository
- [ ] Set up `.gitignore` for Theos projects

### Theos Configuration
- [ ] Install Theos dependencies locally for testing
- [ ] Create `Makefile` with iPhone 7 target
```makefile
TARGET := iphone:13.3.1:7.0
ARCHS := arm64

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = StripeVCAMBypass

$(TWEAK_NAME)_FILES = Tweak.xm VCAMOverlay.m MediaProcessor.m VolumeHook.m
$(TWEAK_NAME)_CFLAGS = -fobjc-arc
$(TWEAK_NAME)_FRAMEWORKS = UIKit AVFoundation CoreMedia

include $(THEOS_MAKE_PATH)/tweak.mk
```

### Package Configuration
- [ ] Create `control` file
```
Package: com.yourusername.stripevcambypass
Name: StripeVCAM Bypass
Version: 1.0.0
Architecture: iphoneos-arm
Description: Bypass Stripe KYC verification by replacing camera feed
Maintainer: Your Name
Author: Your Name
Section: Tweaks
Depends: mobilesubstrate, preferenceloader
```

### GitHub Actions Setup
- [ ] Create `.github/workflows/build.yml` file
```yaml
name: Build StripeVCAM

on:
  push:
    branches: [ main ]
  pull_request:
    branches: [ main ]

jobs:
  build:
    runs-on: ubuntu-latest
    
    steps:
    - uses: actions/checkout@v3
      
    - name: Set up Theos
      uses: Randomblock1/theos-action@v1
      with:
        theos-sdks: 'https://github.com/theos/sdks'
        theos-sdks-branch: 'master'
    
    - name: Install dependencies
      run: |
        sudo apt-get update
        sudo apt-get install -y fakeroot
    
    - name: Build package
      run: |
        make package FINALPACKAGE=1
    
    - name: Upload artifact
      uses: actions/upload-artifact@v3
      with:
        name: StripeVCAMBypass.deb
        path: packages/*.deb
        if-no-files-found: error
```

---

## Phase 2: Core Camera Hooks ⏰ (2-3 hours)

### Main Hook Implementation
- [ ] Create `Tweak.xm` with basic AVFoundation hooks
```objective-c
#import <AVFoundation/AVFoundation.h>
#import "VCAMOverlay.h"
#import "MediaProcessor.h"

%hook AVCaptureVideoDataOutput
- (void)setSampleBufferDelegate:(id)delegate queue:(dispatch_queue_t)queue {
    // Intercept and replace with custom delegate
    if ([MediaProcessor sharedInstance].isEnabled) {
        %orig([MediaProcessor sharedInstance], queue);
    } else {
        %orig;
    }
}
%end

%hook AVCaptureSession
- (void)startRunning {
    // Log session start for debugging
    NSLog(@"[StripeVCAM] AVCaptureSession startRunning");
    %orig;
}
%end
```

### Frame Replacement Engine
- [ ] Create `MediaProcessor.h` header
```objective-c
#import <Foundation/Foundation.h>
#import <AVFoundation/AVFoundation.h>
#import <UIKit/UIKit.h>

@interface MediaProcessor : NSObject <AVCaptureVideoDataOutputSampleBufferDelegate>
@property (nonatomic, assign) BOOL isEnabled;
@property (nonatomic, strong) UIImage *selectedImage;

+ (instancetype)sharedInstance;
- (void)setSelectedImage:(UIImage *)image;
- (CVPixelBufferRef)createPixelBufferFromImage:(UIImage *)image;
@end
```

- [ ] Create `MediaProcessor.m` implementation
```objective-c
#import "MediaProcessor.h"

@implementation MediaProcessor

+ (instancetype)sharedInstance {
    static MediaProcessor *sharedInstance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedInstance = [[self alloc] init];
    });
    return sharedInstance;
}

- (void)captureOutput:(AVCaptureOutput *)output didOutputSampleBuffer:(CMSampleBufferRef)sampleBuffer fromConnection:(AVCaptureConnection *)connection {
    if (!self.isEnabled || !self.selectedImage) {
        return;
    }
    
    // Replace sample buffer with our image
    CVPixelBufferRef pixelBuffer = [self createPixelBufferFromImage:self.selectedImage];
    if (pixelBuffer) {
        // Replace the frame in the sample buffer
        // Implementation details here
    }
}

- (CVPixelBufferRef)createPixelBufferFromImage:(UIImage *)image {
    // Convert UIImage to CVPixelBufferRef
    // Implementation details here
    return NULL; // Placeholder
}

@end
```

---

## Phase 3: Volume Button Integration ⏰ (1 hour)

### Volume Button Hook
- [ ] Create `VolumeHook.h` header
```objective-c
#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

@interface VolumeHook : NSObject
+ (instancetype)sharedInstance;
- (BOOL)handleVolumeButtonWithEvent:(id)event;
@end
```

- [ ] Create `VolumeHook.m` implementation
```objective-c
#import "VolumeHook.h"
#import "VCAMOverlay.h"

@interface VolumeHook ()
@property (nonatomic, assign) NSTimeInterval lastVolumePress;
@property (nonatomic, assign) BOOL wasVolumeUp;
@end

@implementation VolumeHook

+ (instancetype)sharedInstance {
    static VolumeHook *sharedInstance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedInstance = [[self alloc] init];
    });
    return sharedInstance;
}

- (BOOL)handleVolumeButtonWithEvent:(id)event {
    // Detect double tap on volume buttons
    // Implementation details here
    
    // If double tap detected, show overlay
    [[VCAMOverlay sharedInstance] showOverlay];
    return YES; // Handled
}

@end
```

- [ ] Add volume button hook in `Tweak.xm`
```objective-c
%hook SpringBoard
- (void)_handleVolumeEvent:(id)event {
    if ([[VolumeHook sharedInstance] handleVolumeButtonWithEvent:event]) {
        return;
    }
    %orig;
}
%end
```

---

## Phase 4: Overlay UI Implementation ⏰ (2 hours)

### Main Overlay
- [ ] Create `VCAMOverlay.h` header
```objective-c
#import <UIKit/UIKit.h>

@interface VCAMOverlay : NSObject
@property (nonatomic, strong) UIWindow *overlayWindow;
@property (nonatomic, strong) UIViewController *rootViewController;

+ (instancetype)sharedInstance;
- (void)showOverlay;
- (void)hideOverlay;
- (void)showDebugOverlay;
@end
```

- [ ] Create `VCAMOverlay.m` implementation
```objective-c
#import "VCAMOverlay.h"
#import "MediaProcessor.h"

@implementation VCAMOverlay

+ (instancetype)sharedInstance {
    static VCAMOverlay *sharedInstance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedInstance = [[self alloc] init];
    });
    return sharedInstance;
}

- (void)showOverlay {
    if (!self.overlayWindow) {
        self.overlayWindow = [[UIWindow alloc] initWithFrame:[UIScreen mainScreen].bounds];
        self.overlayWindow.windowLevel = UIWindowLevelAlert + 1;
        self.rootViewController = [[UIViewController alloc] init];
        self.overlayWindow.rootViewController = self.rootViewController;
        
        // Create UI elements
        UIButton *selectImageButton = [UIButton buttonWithType:UIButtonTypeSystem];
        [selectImageButton setTitle:@"Select Image" forState:UIControlStateNormal];
        [selectImageButton addTarget:self action:@selector(selectImage) forControlEvents:UIControlEventTouchUpInside];
        
        UIButton *debugButton = [UIButton buttonWithType:UIButtonTypeSystem];
        [debugButton setTitle:@"Debug Logs" forState:UIControlStateNormal];
        [debugButton addTarget:self action:@selector(showDebugOverlay) forControlEvents:UIControlEventTouchUpInside];
        
        // Add to view hierarchy and position
        // Implementation details here
    }
    
    self.overlayWindow.hidden = NO;
}

- (void)hideOverlay {
    self.overlayWindow.hidden = YES;
}

- (void)selectImage {
    UIImagePickerController *picker = [[UIImagePickerController alloc] init];
    picker.sourceType = UIImagePickerControllerSourceTypePhotoLibrary;
    picker.delegate = self;
    [self.rootViewController presentViewController:picker animated:YES completion:nil];
}

- (void)showDebugOverlay {
    // Show debug overlay implementation
}

#pragma mark - UIImagePickerControllerDelegate

- (void)imagePickerController:(UIImagePickerController *)picker didFinishPickingMediaWithInfo:(NSDictionary *)info {
    UIImage *selectedImage = info[UIImagePickerControllerOriginalImage];
    [[MediaProcessor sharedInstance] setSelectedImage:selectedImage];
    [[MediaProcessor sharedInstance] setIsEnabled:YES];
    
    [picker dismissViewControllerAnimated:YES completion:^{
        [self hideOverlay];
    }];
}

@end
```

### Debug Overlay
- [ ] Create debug log viewer in `VCAMOverlay.m`
```objective-c
- (void)showDebugOverlay {
    UIViewController *debugVC = [[UIViewController alloc] init];
    UITextView *logView = [[UITextView alloc] initWithFrame:debugVC.view.bounds];
    logView.editable = NO;
    logView.text = [self getDebugLogs];
    [debugVC.view addSubview:logView];
    
    UIButton *closeButton = [UIButton buttonWithType:UIButtonTypeSystem];
    [closeButton setTitle:@"Close" forState:UIControlStateNormal];
    [closeButton addTarget:self action:@selector(closeDebugOverlay:) forControlEvents:UIControlEventTouchUpInside];
    // Position button
    
    [self.rootViewController presentViewController:debugVC animated:YES completion:nil];
}

- (NSString *)getDebugLogs {
    // Collect and return debug logs
    return @"Debug logs will appear here";
}

- (void)closeDebugOverlay:(UIButton *)sender {
    [self.rootViewController dismissViewControllerAnimated:YES completion:nil];
}
```

---

## Phase 5: Preferences & Settings ⏰ (1 hour)

### PreferenceLoader Setup
- [ ] Create `Preferences` directory
- [ ] Create `StripeVCAMPrefs.plist` for settings

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>entry</key>
    <dict>
        <key>cell</key>
        <string>PSLinkCell</string>
        <key>label</key>
        <string>StripeVCAM Bypass</string>
        <key>icon</key>
        <string>icon.png</string>
    </dict>
    <key>items</key>
    <array>
        <dict>
            <key>cell</key>
            <string>PSSwitchCell</string>
            <key>default</key>
            <true/>
            <key>defaults</key>
            <string>com.yourusername.stripevcambypass</string>
            <key>key</key>
            <string>enabled</string>
            <key>label</key>
            <string>Enabled</string>
        </dict>
        <dict>
            <key>cell</key>
            <string>PSGroupCell</string>
            <key>label</key>
            <string>Debug Options</string>
        </dict>
        <dict>
            <key>cell</key>
            <string>PSSwitchCell</string>
            <key>default</key>
            <false/>
            <key>defaults</key>
            <string>com.yourusername.stripevcambypass</string>
            <key>key</key>
            <string>debugLogging</string>
            <key>label</key>
            <string>Debug Logging</string>
        </dict>
    </array>
</dict>
</plist>
```

- [ ] Add preference loading to `Tweak.xm`
```objective-c
static void loadPrefs() {
    NSDictionary *settings = [NSDictionary dictionaryWithContentsOfFile:@"/var/mobile/Library/Preferences/com.yourusername.stripevcambypass.plist"];
    BOOL enabled = settings[@"enabled"] ? [settings[@"enabled"] boolValue] : YES;
    BOOL debugLogging = settings[@"debugLogging"] ? [settings[@"debugLogging"] boolValue] : NO;
    
    [MediaProcessor sharedInstance].isEnabled = enabled;
    // Set debug logging flag
}

%ctor {
    loadPrefs();
    
    // Register for preference change notifications
    CFNotificationCenterAddObserver(
        CFNotificationCenterGetDarwinNotifyCenter(),
        NULL,
        (CFNotificationCallback)loadPrefs,
        CFSTR("com.yourusername.stripevcambypass/prefsChanged"),
        NULL,
        CFNotificationSuspensionBehaviorCoalesce
    );
}
```

---

## Phase 6: Testing & Deployment ⏰ (2 hours)

### Local Testing
- [ ] Build locally with Theos
- [ ] Test on device via SSH installation
```bash
# On your computer
scp packages/com.yourusername.stripevcambypass_1.0.0_iphoneos-arm.deb root@[device-ip]:/tmp/

# On your device
dpkg -i /tmp/com.yourusername.stripevcambypass_1.0.0_iphoneos-arm.deb
killall -9 SpringBoard  # Respring
```

### GitHub Actions Testing
- [ ] Push to GitHub
- [ ] Verify GitHub Actions build completes successfully
- [ ] Download artifact and test on device

### Stripe KYC Testing
- [ ] Test with actual Stripe KYC flow
- [ ] Verify camera feed replacement works
- [ ] Check for any detection mechanisms

---

## Phase 7: Documentation & Finalization ⏰ (1 hour)

### README Creation
- [ ] Create comprehensive README.md
- [ ] Include installation instructions
- [ ] Document usage instructions
- [ ] Add troubleshooting section

### Final Package
- [ ] Update version number if needed
- [ ] Create final build
- [ ] Test final package

---

## Troubleshooting Tips

### Common Issues
- If volume button detection doesn't work, try adjusting the timing threshold
- If camera feed replacement fails, check if the app is using a custom camera implementation
- For memory issues, reduce the size of selected images

### Debug Logs
- Enable debug logging in settings
- Check logs via the debug overlay
- Look for "[StripeVCAM]" prefix in system logs

---

## Resources

### Documentation
- [Theos Wiki](https://theos.dev/docs/)
- [MobileSubstrate Documentation](http://iphonedevwiki.net/index.php/MobileSubstrate)
- [AVFoundation Framework Reference](https://developer.apple.com/documentation/avfoundation)

### Tools
- [Theos](https://github.com/theos/theos)
- [PreferenceLoader](https://github.com/dustinhowett/preferenceloader)
- [Flipboard FLEX](https://github.com/FLEXTool/FLEX) (for runtime inspection) 