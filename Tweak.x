#import <UIKit/UIKit.h>
#import <AVFoundation/AVFoundation.h>
#if __has_include(<substrate.h>)
#import <substrate.h>
#elif __has_include(<substitute.h>)
#import <substitute.h>
#else
// Basic hook support without specific substrate
#endif
#import <QuartzCore/QuartzCore.h>
#import "Sources/SimpleMediaManager.h"
#import "Sources/OverlayView.h"

static BOOL vcamEnabled = NO;
static NSDate *lastVolumePress = nil;
static int volumePressCount = 0;
static NSTimer *volumeResetTimer = nil;
static BOOL springBoardReady = NO;

// Persistent state file path
#define VCAM_STATE_FILE @"/var/mobile/Library/Preferences/com.vcam.customvcam.state"

static void saveVCAMState(BOOL enabled) {
    NSDictionary *state = @{@"enabled": @(enabled)};
    [state writeToFile:VCAM_STATE_FILE atomically:YES];
    NSLog(@"[CustomVCAM] State saved to file: %@", enabled ? @"Enabled" : @"Disabled");
}

static BOOL loadVCAMState() {
    NSDictionary *state = [NSDictionary dictionaryWithContentsOfFile:VCAM_STATE_FILE];
    BOOL enabled = state ? [state[@"enabled"] boolValue] : NO;
    NSLog(@"[CustomVCAM] State loaded from file: %@", enabled ? @"Enabled" : @"Disabled");
    return enabled;
}



@interface SBVolumeControl : NSObject
- (void)increaseVolume;
- (void)decreaseVolume;
- (BOOL)handleVolumePress;
@end

@interface SpringBoard : UIApplication
- (void)applicationDidFinishLaunching:(UIApplication *)application;
@end

@interface AVCaptureVideoDataOutput (CustomVCAM)
@property (nonatomic, weak) id<AVCaptureVideoDataOutputSampleBufferDelegate> sampleBufferDelegate;
@end

// WebRTC interfaces for iOS 13.3.1 Safari
@interface RTCCameraVideoCapturer : NSObject
- (void)startCaptureWithDevice:(AVCaptureDevice *)device format:(AVCaptureDeviceFormat *)format fps:(NSInteger)fps;
- (void)stopCapture;
@end

@interface RTCVideoSource : NSObject
@end

@interface RTCVideoTrack : NSObject
@end

// Web getUserMedia interfaces
@interface WKUserMediaPermissionRequest : NSObject
- (void)allow;
- (void)deny;
@end

@interface WKWebView : NSObject
@end

// iOS 13 WebKit media interfaces - using existing AVFoundation interface



%hook SBVolumeControl

- (void)increaseVolume {
    if (springBoardReady && [self handleVolumePress]) {
        return;
    }
    %orig;
}

- (void)decreaseVolume {
    if (springBoardReady && [self handleVolumePress]) {
        return;
    }
    %orig;
}

%new
- (BOOL)handleVolumePress {
    @autoreleasepool {
        if (!springBoardReady) return NO;
        
        NSDate *now = [NSDate date];
        
        if (!lastVolumePress || [now timeIntervalSinceDate:lastVolumePress] > 0.5) {
            volumePressCount = 1;
        } else {
            volumePressCount++;
        }
        
        lastVolumePress = now;
        
        if (volumeResetTimer) {
            [volumeResetTimer invalidate];
            volumeResetTimer = nil;
        }
        
        volumeResetTimer = [NSTimer scheduledTimerWithTimeInterval:0.6 
                                                            target:[NSBlockOperation blockOperationWithBlock:^{
                                                                volumePressCount = 0;
                                                                volumeResetTimer = nil;
                                                            }]
                                                          selector:@selector(main) 
                                                          userInfo:nil 
                                                           repeats:NO];
        
        if (volumePressCount >= 2) {
            dispatch_async(dispatch_get_main_queue(), ^{
                @autoreleasepool {
                    if (springBoardReady) {
                        [[OverlayView sharedInstance] showOverlay];
                    }
                }
            });
            volumePressCount = 0;
            if (volumeResetTimer) {
                [volumeResetTimer invalidate];
                volumeResetTimer = nil;
            }
            return YES;
        }
        
        return NO;
    }
}



%end

%hook SpringBoard

- (void)applicationDidFinishLaunching:(UIApplication *)application {
    %orig;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        springBoardReady = YES;
        NSLog(@"[CustomVCAM] SpringBoard ready - volume hooks enabled");
    });
}

%end

%hook AVCaptureDevice

+ (NSArray<AVCaptureDevice *> *)devicesWithMediaType:(AVMediaType)mediaType {
    NSArray *originalDevices = %orig;
    
    if (vcamEnabled && [mediaType isEqualToString:AVMediaTypeVideo]) {
        SimpleMediaManager *mediaManager = [SimpleMediaManager sharedInstance];
        BOOL hasMedia = [mediaManager hasAvailableMedia];
        
        if (hasMedia) {
            NSLog(@"[CustomVCAM] Camera devices requested - will provide custom content");
            // Return original devices so camera appears available, but we'll replace content
        }
    }
    
    return originalDevices;
}

+ (AVCaptureDevice *)defaultDeviceWithMediaType:(AVMediaType)mediaType {
    AVCaptureDevice *originalDevice = %orig;
    
    if (vcamEnabled && [mediaType isEqualToString:AVMediaTypeVideo]) {
        SimpleMediaManager *mediaManager = [SimpleMediaManager sharedInstance];
        BOOL hasMedia = [mediaManager hasAvailableMedia];
        
        if (hasMedia) {
            NSLog(@"[CustomVCAM] Default camera device requested - will provide custom content");
            // Return original device so camera appears available, but we'll replace content
        }
    }
    
    return originalDevice;
}

+ (AVCaptureDevice *)deviceWithUniqueID:(NSString *)deviceUniqueID {
    AVCaptureDevice *originalDevice = %orig;
    
    if (vcamEnabled && deviceUniqueID) {
        // Check if this is a camera device ID
        if ([deviceUniqueID containsString:@"Camera"] || [deviceUniqueID containsString:@"Video"]) {
            SimpleMediaManager *mediaManager = [SimpleMediaManager sharedInstance];
            BOOL hasMedia = [mediaManager hasAvailableMedia];
            
            if (hasMedia) {
                NSLog(@"[CustomVCAM] Camera device by ID requested - will provide custom content");
                // Return original device so camera appears available, but we'll replace content
            }
        }
    }
    
    return originalDevice;
}

%end

// This hook is moved below - removing duplicate

%hook AVCapturePhotoOutput

- (void)capturePhotoWithSettings:(AVCapturePhotoSettings *)settings delegate:(id<AVCapturePhotoCaptureDelegate>)delegate {
    NSLog(@"[CustomVCAM] AVCapturePhotoOutput capturePhotoWithSettings called - vcamEnabled: %@", vcamEnabled ? @"YES" : @"NO");
    
    if (!vcamEnabled) {
        NSLog(@"[CustomVCAM] VCAM disabled, proceeding with original photo capture");
        %orig;
        return;
    }
    
    SimpleMediaManager *mediaManager = [SimpleMediaManager sharedInstance];
    BOOL hasMedia = [mediaManager hasAvailableMedia];
    NSLog(@"[CustomVCAM] MediaManager hasAvailableMedia: %@", hasMedia ? @"YES" : @"NO");
    
    if (!hasMedia) {
        NSLog(@"[CustomVCAM] No media available, proceeding with original photo capture");
        %orig;
        return;
    }
    
    NSLog(@"[CustomVCAM] Photo capture intercepted - attempting to use custom media");
    %orig;
}

%end

%hook UIImagePickerController

- (void)_startVideoCapture {
    if (!vcamEnabled) {
        %orig;
        return;
    }
    
    SimpleMediaManager *mediaManager = [SimpleMediaManager sharedInstance];
    if (![mediaManager hasAvailableMedia]) {
        %orig;
        return;
    }
    
    NSLog(@"[CustomVCAM] UIImagePickerController video capture intercepted");
}

- (void)_takePicture {
    if (!vcamEnabled) {
        %orig;
        return;
    }
    
    SimpleMediaManager *mediaManager = [SimpleMediaManager sharedInstance];
    if (![mediaManager hasAvailableMedia]) {
        %orig;
        return;
    }
    
    NSLog(@"[CustomVCAM] UIImagePickerController photo capture intercepted");
}

%end

%hook AVCaptureVideoPreviewLayer

- (instancetype)initWithSession:(AVCaptureSession *)session {
    NSLog(@"[CustomVCAM] AVCaptureVideoPreviewLayer initWithSession called");
    return %orig;
}

- (void)setSession:(AVCaptureSession *)session {
    NSLog(@"[CustomVCAM] AVCaptureVideoPreviewLayer setSession called");
    %orig;
    
    // Continuously replace layer content to fight camera updates
    if (vcamEnabled) {
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0), ^{
            SimpleMediaManager *mediaManager = [SimpleMediaManager sharedInstance];
            BOOL hasMedia = [mediaManager hasAvailableMedia];
            
            if (hasMedia) {
                UIImage *customImage = [mediaManager loadImageFromSharedLocation];
                if (customImage) {
                    NSLog(@"[CustomVCAM] Starting aggressive content replacement (30s)");
                    
                    // Continuously replace content every 100ms to override camera updates
                    for (int i = 0; i < 300 && vcamEnabled; i++) { // Run for 30 seconds
                        dispatch_async(dispatch_get_main_queue(), ^{
                            self.contents = (__bridge id)customImage.CGImage;
                            [self setNeedsDisplay];
                        });
                        usleep(100000); // 100ms delay
                    }
                }
            }
        });
    }
}

- (void)layoutSublayers {
    %orig;
    
    if (vcamEnabled) {
        SimpleMediaManager *mediaManager = [SimpleMediaManager sharedInstance];
        BOOL hasMedia = [mediaManager hasAvailableMedia];
        
        if (hasMedia) {
            UIImage *customImage = [mediaManager loadImageFromSharedLocation];
            if (customImage) {
                NSLog(@"[CustomVCAM] REPLACING preview layer contents with custom image");
                dispatch_async(dispatch_get_main_queue(), ^{
                    self.contents = (__bridge id)customImage.CGImage;
                    [self setNeedsDisplay];
                });
            }
        }
    }
}

- (void)display {
    if (vcamEnabled) {
        SimpleMediaManager *mediaManager = [SimpleMediaManager sharedInstance];
        BOOL hasMedia = [mediaManager hasAvailableMedia];
        
        if (hasMedia) {
            UIImage *customImage = [mediaManager loadImageFromSharedLocation];
            if (customImage) {
                NSLog(@"[CustomVCAM] INTERCEPTING display - setting custom content");
                self.contents = (__bridge id)customImage.CGImage;
                [self setNeedsDisplay];
            }
        }
    }
    
    %orig;
}

%end

%hook CALayer

- (void)setContents:(id)contents {
    NSString *className = NSStringFromClass([self class]);
    
    if (vcamEnabled && [className containsString:@"AVCaptureVideoPreview"]) {
        SimpleMediaManager *mediaManager = [SimpleMediaManager sharedInstance];
        BOOL hasMedia = [mediaManager hasAvailableMedia];
        
        if (hasMedia) {
            UIImage *customImage = [mediaManager loadImageFromSharedLocation];
            if (customImage) {
                NSLog(@"[CustomVCAM] INTERCEPTING setContents - replacing with custom image");
                %orig((__bridge id)customImage.CGImage);
                return;
            }
        }
    }
    
    %orig;
}

%end

// Enhanced WebRTC/Safari compatibility - provide custom video for web contexts
%hook AVCaptureVideoDataOutput

- (void)captureOutput:(AVCaptureOutput *)output didOutputSampleBuffer:(CMSampleBufferRef)sampleBuffer fromConnection:(AVCaptureConnection *)connection {
    // Enhanced logging for debugging
    NSString *bundleID = [[NSBundle mainBundle] bundleIdentifier];
    NSLog(@"[CustomVCAM] DATACAPTURE - Bundle: %@, Delegate: %@, Buffer: %p, VCAM: %@", 
          bundleID, self.sampleBufferDelegate, sampleBuffer, vcamEnabled ? @"YES" : @"NO");
    
    if (!vcamEnabled) {
        NSLog(@"[CustomVCAM] DATACAPTURE: VCAM disabled, using original feed");
        %orig;
        return;
    }
    
    SimpleMediaManager *mediaManager = [SimpleMediaManager sharedInstance];
    BOOL hasMedia = [mediaManager hasAvailableMedia];
    NSLog(@"[CustomVCAM] DATACAPTURE: HasMedia: %@", hasMedia ? @"YES" : @"NO");
    
    if (!hasMedia) {
        NSLog(@"[CustomVCAM] DATACAPTURE: No media available, using original feed");
        %orig;
        return;
    }
    
    // Enhanced replacement for web contexts
    if ([bundleID isEqualToString:@"com.apple.mobilesafari"]) {
        NSLog(@"[CustomVCAM] SAFARI DATACAPTURE: Attempting to replace video data output");
    } else {
        NSLog(@"[CustomVCAM] CAMERA DATACAPTURE: Attempting to replace video data output");
    }
    
    CMSampleBufferRef customBuffer = [mediaManager createSampleBufferFromImage];
    
    if (customBuffer) {
        NSLog(@"[CustomVCAM] DATACAPTURE: Custom buffer created - Size: %p, Delegate: %@", 
              customBuffer, self.sampleBufferDelegate);
        
        if (self.sampleBufferDelegate && [self.sampleBufferDelegate respondsToSelector:@selector(captureOutput:didOutputSampleBuffer:fromConnection:)]) {
            NSLog(@"[CustomVCAM] DATACAPTURE: Calling delegate with custom buffer");
            [self.sampleBufferDelegate captureOutput:output didOutputSampleBuffer:customBuffer fromConnection:connection];
        } else {
            NSLog(@"[CustomVCAM] DATACAPTURE: ERROR - No delegate or delegate doesn't respond");
        }
        CFRelease(customBuffer);
        
        // Don't call %orig - we're completely replacing the output
        return;
    } else {
        NSLog(@"[CustomVCAM] DATACAPTURE: ERROR - Custom buffer creation failed");
        %orig;
    }
}

- (void)setSampleBufferDelegate:(id<AVCaptureVideoDataOutputSampleBufferDelegate>)sampleBufferDelegate queue:(dispatch_queue_t)sampleBufferCallbackQueue {
    NSString *bundleID = [[NSBundle mainBundle] bundleIdentifier];
    NSLog(@"[CustomVCAM] DELEGATE SET - Bundle: %@, Delegate: %@", bundleID, sampleBufferDelegate);
    %orig;
}

%end

// Comprehensive WebRTC and Web Camera Blocking for iOS 13.3.1

// Enhanced WebRTC hooks for Safari getUserMedia
%hook RTCCameraVideoCapturer

- (void)startCaptureWithDevice:(AVCaptureDevice *)device format:(AVCaptureDeviceFormat *)format fps:(NSInteger)fps {
    NSString *bundleID = [[NSBundle mainBundle] bundleIdentifier];
    NSLog(@"[CustomVCAM] WEBRTC START - Bundle: %@, Device: %@, VCAM: %@", 
          bundleID, device.localizedName, vcamEnabled ? @"YES" : @"NO");
    
    if (vcamEnabled) {
        SimpleMediaManager *mediaManager = [SimpleMediaManager sharedInstance];
        BOOL hasMedia = [mediaManager hasAvailableMedia];
        
        if (hasMedia) {
            NSLog(@"[CustomVCAM] WEBRTC: Custom media available - hijacking capture");
            // Allow WebRTC to start so website sees camera, but content will be replaced
        }
    }
    
    %orig;
}

- (void)stopCapture {
    NSString *bundleID = [[NSBundle mainBundle] bundleIdentifier];
    NSLog(@"[CustomVCAM] WEBRTC STOP - Bundle: %@", bundleID);
    %orig;
}

%end

// Add RTCVideoSource hooks for direct WebRTC injection
%hook RTCVideoSource

- (void)adaptOutputFormatToWidth:(int)width height:(int)height fps:(int)fps {
    NSString *bundleID = [[NSBundle mainBundle] bundleIdentifier];
    NSLog(@"[CustomVCAM] WEBRTC SOURCE - Bundle: %@, Format: %dx%d@%dfps, VCAM: %@", 
          bundleID, width, height, fps, vcamEnabled ? @"YES" : @"NO");
    %orig;
}

%end

// Add WKWebView hooks for getUserMedia interception
%hook WKWebView

- (void)evaluateJavaScript:(NSString *)javaScriptString completionHandler:(void (^)(id, NSError *))completionHandler {
    if (vcamEnabled && [javaScriptString containsString:@"getUserMedia"]) {
        NSLog(@"[CustomVCAM] WEBKIT: getUserMedia JavaScript detected - Bundle: %@", 
              [[NSBundle mainBundle] bundleIdentifier]);
        NSLog(@"[CustomVCAM] WEBKIT: JS: %@", javaScriptString);
    }
    %orig;
}

%end

// Enhanced iOS 13 Safari getUserMedia hooks
%hook WKUserMediaPermissionRequest

- (void)allow {
    NSString *bundleID = [[NSBundle mainBundle] bundleIdentifier];
    NSLog(@"[CustomVCAM] WEBKIT PERMISSION - Bundle: %@, VCAM: %@", bundleID, vcamEnabled ? @"YES" : @"NO");
    
    if (vcamEnabled) {
        SimpleMediaManager *mediaManager = [SimpleMediaManager sharedInstance];
        BOOL hasMedia = [mediaManager hasAvailableMedia];
        
        if (hasMedia) {
            NSLog(@"[CustomVCAM] WEBKIT: getUserMedia permission granted - custom content ready");
            // Allow permission so website sees camera, but content will be replaced
        }
    }
    
    %orig;
}

- (void)deny {
    NSString *bundleID = [[NSBundle mainBundle] bundleIdentifier];
    NSLog(@"[CustomVCAM] WEBKIT PERMISSION DENIED - Bundle: %@", bundleID);
    %orig;
}

%end

// Enhanced AVCaptureSession hooks for all contexts
%hook AVCaptureSession

- (void)startRunning {
    NSString *bundleID = [[NSBundle mainBundle] bundleIdentifier];
    NSLog(@"[CustomVCAM] SESSION START - Bundle: %@, VCAM: %@", bundleID, vcamEnabled ? @"YES" : @"NO");
    
    if (vcamEnabled) {
        SimpleMediaManager *mediaManager = [SimpleMediaManager sharedInstance];
        BOOL hasMedia = [mediaManager hasAvailableMedia];
        
        if (hasMedia) {
            if ([bundleID isEqualToString:@"com.apple.mobilesafari"]) {
                NSLog(@"[CustomVCAM] SAFARI SESSION: Starting with custom media override");
            } else {
                NSLog(@"[CustomVCAM] CAMERA SESSION: Starting with custom media override");
            }
        }
    }
    
    %orig;
}

- (void)stopRunning {
    NSString *bundleID = [[NSBundle mainBundle] bundleIdentifier];
    NSLog(@"[CustomVCAM] SESSION STOP - Bundle: %@", bundleID);
    %orig;
}

- (void)addOutput:(AVCaptureOutput *)output {
    NSString *bundleID = [[NSBundle mainBundle] bundleIdentifier];
    NSLog(@"[CustomVCAM] SESSION ADD OUTPUT - Bundle: %@, Output: %@", bundleID, NSStringFromClass([output class]));
    %orig;
}

- (void)addInput:(AVCaptureInput *)input {
    NSString *bundleID = [[NSBundle mainBundle] bundleIdentifier];
    NSLog(@"[CustomVCAM] SESSION ADD INPUT - Bundle: %@, Input: %@", bundleID, NSStringFromClass([input class]));
    %orig;
}

%end

// Allow device discovery but replace content
%hook AVCaptureDeviceDiscoverySession

+ (instancetype)discoverySessionWithDeviceTypes:(NSArray *)deviceTypes mediaType:(AVMediaType)mediaType position:(AVCaptureDevicePosition)position {
    if (vcamEnabled && [mediaType isEqualToString:AVMediaTypeVideo]) {
        SimpleMediaManager *mediaManager = [SimpleMediaManager sharedInstance];
        BOOL hasMedia = [mediaManager hasAvailableMedia];
        
        if (hasMedia) {
            NSLog(@"[CustomVCAM] Device discovery for web - will provide custom content");
            // Return normal session so cameras appear available
        }
    }
    
    return %orig;
}

- (NSArray<AVCaptureDevice *> *)devices {
    if (vcamEnabled) {
        SimpleMediaManager *mediaManager = [SimpleMediaManager sharedInstance];
        BOOL hasMedia = [mediaManager hasAvailableMedia];
        
        if (hasMedia) {
            NSLog(@"[CustomVCAM] Device discovery returning cameras - content will be replaced");
            // Return original devices so cameras appear available
        }
    }
    
    return %orig;
}

%end

// Additional iOS 13 WebKit media blocking - forward declaration
@class WKPreferences;

// WebKit preferences hook removed to avoid compilation conflicts on iOS 13

// Allow all camera access methods - content replacement will handle the rest

%hook AVCaptureVideoThumbnailOutput

- (void)captureOutput:(AVCaptureOutput *)output didOutputSampleBuffer:(CMSampleBufferRef)sampleBuffer fromConnection:(AVCaptureConnection *)connection {
    NSLog(@"[CustomVCAM] AVCaptureVideoThumbnailOutput captureOutput called - vcamEnabled: %@", vcamEnabled ? @"YES" : @"NO");
    
    if (!vcamEnabled) {
        NSLog(@"[CustomVCAM] VCAM disabled, using original thumbnail feed");
        %orig;
        return;
    }
    
    SimpleMediaManager *mediaManager = [SimpleMediaManager sharedInstance];
    BOOL hasMedia = [mediaManager hasAvailableMedia];
    NSLog(@"[CustomVCAM] MediaManager hasAvailableMedia: %@", hasMedia ? @"YES" : @"NO");
    
    if (!hasMedia) {
        NSLog(@"[CustomVCAM] No media available, using original thumbnail feed");
        %orig;
        return;
    }
    
    NSLog(@"[CustomVCAM] Thumbnail output intercepted - this might be the preview layer");
    %orig;
}

%end

%hook AVCaptureStillImageOutput

- (void)captureStillImageAsynchronouslyFromConnection:(AVCaptureConnection *)connection completionHandler:(void (^)(CMSampleBufferRef, NSError *))handler {
    NSLog(@"[CustomVCAM] AVCaptureStillImageOutput captureStillImageAsynchronouslyFromConnection called - vcamEnabled: %@", vcamEnabled ? @"YES" : @"NO");
    
    if (!vcamEnabled) {
        NSLog(@"[CustomVCAM] VCAM disabled, proceeding with original still image capture");
        %orig;
        return;
    }
    
    SimpleMediaManager *mediaManager = [SimpleMediaManager sharedInstance];
    BOOL hasMedia = [mediaManager hasAvailableMedia];
    NSLog(@"[CustomVCAM] MediaManager hasAvailableMedia: %@", hasMedia ? @"YES" : @"NO");
    
    if (!hasMedia) {
        NSLog(@"[CustomVCAM] No media available, proceeding with original still image capture");
        %orig;
        return;
    }
    
    NSLog(@"[CustomVCAM] Still image capture intercepted - attempting to use custom media");
    
    CMSampleBufferRef customBuffer = [mediaManager createSampleBufferFromImage];
    if (customBuffer && handler) {
        NSLog(@"[CustomVCAM] Calling completion handler with custom buffer");
        handler(customBuffer, nil);
        CFRelease(customBuffer);
    } else {
        NSLog(@"[CustomVCAM] Failed to create custom buffer, falling back to original");
        %orig;
    }
}

%end



// REMOVED: NSObject +alloc hook - was causing SpringBoard crash due to infinite allocation loop

%ctor {
    %init;
    
    NSString *bundleID = [[NSBundle mainBundle] bundleIdentifier];
    NSLog(@"[CustomVCAM] Loaded for bundle: %@", bundleID);
    
    // Enhanced logging for WebContent processes
    if ([bundleID containsString:@"WebContent"]) {
        NSLog(@"[CustomVCAM] WebContent process detected - WebRTC hooks active");
    }
    
    // Load initial state from file
    vcamEnabled = loadVCAMState();
    NSLog(@"[CustomVCAM] Initial state loaded: vcamEnabled=%@", vcamEnabled ? @"YES" : @"NO");
    
    [[NSNotificationCenter defaultCenter] addObserverForName:@"VCAMToggled" 
                                                      object:nil 
                                                       queue:[NSOperationQueue mainQueue] 
                                                  usingBlock:^(NSNotification *note) {
        NSNumber *enabled = note.userInfo[@"enabled"];
        if (enabled) {
            BOOL oldValue = vcamEnabled;
            vcamEnabled = [enabled boolValue];
            
            // Save state to file for other processes
            saveVCAMState(vcamEnabled);
            
            NSLog(@"[CustomVCAM] VCAM %@ in %@", 
                  vcamEnabled ? @"ENABLED" : @"DISABLED",
                  [[NSBundle mainBundle] bundleIdentifier]);
        }
    }];
    
    if ([bundleID isEqualToString:@"com.apple.springboard"]) {
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(3.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            @autoreleasepool {
                [OverlayView sharedInstance];
                NSLog(@"[CustomVCAM] SpringBoard overlay initialized (delayed)");
            }
        });
    }
    
    if ([bundleID isEqualToString:@"com.apple.camera"] ||
        [bundleID isEqualToString:@"com.apple.mobilesafari"]) {
        
        [SimpleMediaManager sharedInstance];
        NSLog(@"[CustomVCAM] Hooks active for %@ - VCAM: %@", bundleID, vcamEnabled ? @"ENABLED" : @"DISABLED");
        
        // Periodic state sync for cross-process communication
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_LOW, 0), ^{
            for (int i = 0; i < 60; i++) {
                sleep(3);
                
                // Check for state changes from file
                BOOL fileState = loadVCAMState();
                if (fileState != vcamEnabled) {
                    NSLog(@"[CustomVCAM] State sync: %@ -> %@", 
                          vcamEnabled ? @"ENABLED" : @"DISABLED", 
                          fileState ? @"ENABLED" : @"DISABLED");
                    vcamEnabled = fileState;
                }
            }
        });
    }
} 