#import <UIKit/UIKit.h>
#import <AVFoundation/AVFoundation.h>
#import <substrate.h>
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
    if (vcamEnabled && [mediaType isEqualToString:AVMediaTypeVideo]) {
        SimpleMediaManager *mediaManager = [SimpleMediaManager sharedInstance];
        BOOL hasMedia = [mediaManager hasAvailableMedia];
        
        if (hasMedia) {
            NSLog(@"[CustomVCAM] BLOCKING camera device access - returning empty device list");
            return @[]; // Return empty array - no cameras available
        }
    }
    
    return %orig;
}

+ (AVCaptureDevice *)defaultDeviceWithMediaType:(AVMediaType)mediaType {
    if (vcamEnabled && [mediaType isEqualToString:AVMediaTypeVideo]) {
        SimpleMediaManager *mediaManager = [SimpleMediaManager sharedInstance];
        BOOL hasMedia = [mediaManager hasAvailableMedia];
        
        if (hasMedia) {
            NSLog(@"[CustomVCAM] BLOCKING default camera device access");
            return nil; // No default camera available
        }
    }
    
    return %orig;
}

+ (AVCaptureDevice *)deviceWithUniqueID:(NSString *)deviceUniqueID {
    if (vcamEnabled && deviceUniqueID) {
        // Check if this is a camera device ID
        if ([deviceUniqueID containsString:@"Camera"] || [deviceUniqueID containsString:@"Video"]) {
            SimpleMediaManager *mediaManager = [SimpleMediaManager sharedInstance];
            BOOL hasMedia = [mediaManager hasAvailableMedia];
            
            if (hasMedia) {
                NSLog(@"[CustomVCAM] BLOCKING camera device by ID: %@", deviceUniqueID);
                return nil;
            }
        }
    }
    
    return %orig;
}

%end

%hook AVCaptureSession

- (void)startRunning {
    if (vcamEnabled) {
        SimpleMediaManager *mediaManager = [SimpleMediaManager sharedInstance];
        BOOL hasMedia = [mediaManager hasAvailableMedia];
        
        if (hasMedia) {
            NSLog(@"[CustomVCAM] BLOCKING camera session startup - VCAM enabled with media");
            return; // Don't start the actual camera session
        }
    }
    
    %orig;
}

- (void)stopRunning {
    NSLog(@"[CustomVCAM] AVCaptureSession stopRunning called");
    %orig;
}

- (void)addOutput:(AVCaptureOutput *)output {
    NSLog(@"[CustomVCAM] AVCaptureSession addOutput: %@", NSStringFromClass([output class]));
    %orig;
}

- (void)addInput:(AVCaptureInput *)input {
    NSLog(@"[CustomVCAM] AVCaptureSession addInput: %@", NSStringFromClass([input class]));
    %orig;
}

%end

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

// Add WebRTC/Safari compatibility - provide custom video when camera blocked
%hook AVCaptureVideoDataOutput

- (void)captureOutput:(AVCaptureOutput *)output didOutputSampleBuffer:(CMSampleBufferRef)sampleBuffer fromConnection:(AVCaptureConnection *)connection {
    if (!vcamEnabled) {
        %orig;
        return;
    }
    
    SimpleMediaManager *mediaManager = [SimpleMediaManager sharedInstance];
    BOOL hasMedia = [mediaManager hasAvailableMedia];
    
    if (!hasMedia) {
        %orig;
        return;
    }
    
    NSLog(@"[CustomVCAM] INTERCEPTING video data output - replacing with custom media");
    CMSampleBufferRef customBuffer = [mediaManager createSampleBufferFromImage];
    
    if (customBuffer) {
        NSLog(@"[CustomVCAM] Custom buffer created - feed replaced successfully");
        if ([self.sampleBufferDelegate respondsToSelector:@selector(captureOutput:didOutputSampleBuffer:fromConnection:)]) {
            [self.sampleBufferDelegate captureOutput:output didOutputSampleBuffer:customBuffer fromConnection:connection];
        }
        CFRelease(customBuffer);
    } else {
        NSLog(@"[CustomVCAM] ERROR: Custom buffer creation failed - using original feed");
        %orig;
    }
}

%end

// Comprehensive WebRTC and Web Camera Blocking for iOS 13.3.1

// Block WebRTC camera access completely
%hook RTCCameraVideoCapturer

- (void)startCaptureWithDevice:(AVCaptureDevice *)device format:(AVCaptureDeviceFormat *)format fps:(NSInteger)fps {
    if (vcamEnabled) {
        SimpleMediaManager *mediaManager = [SimpleMediaManager sharedInstance];
        BOOL hasMedia = [mediaManager hasAvailableMedia];
        
        if (hasMedia) {
            NSLog(@"[CustomVCAM] BLOCKING WebRTC camera capture - Safari getUserMedia denied");
            // Complete blocking - no camera for WebRTC
            return;
        }
    }
    
    %orig;
}

- (void)stopCapture {
    NSLog(@"[CustomVCAM] WebRTC camera capture stopped");
    %orig;
}

%end

// Block iOS 13 Safari getUserMedia permission requests
%hook WKUserMediaPermissionRequest

- (void)allow {
    if (vcamEnabled) {
        SimpleMediaManager *mediaManager = [SimpleMediaManager sharedInstance];
        BOOL hasMedia = [mediaManager hasAvailableMedia];
        
        if (hasMedia) {
            NSLog(@"[CustomVCAM] BLOCKING Safari getUserMedia permission - denying camera access");
            [self deny];
            return;
        }
    }
    
    %orig;
}

%end

// Block device discovery for web contexts
%hook AVCaptureDeviceDiscoverySession

+ (instancetype)discoverySessionWithDeviceTypes:(NSArray *)deviceTypes mediaType:(AVMediaType)mediaType position:(AVCaptureDevicePosition)position {
    if (vcamEnabled && [mediaType isEqualToString:AVMediaTypeVideo]) {
        SimpleMediaManager *mediaManager = [SimpleMediaManager sharedInstance];
        BOOL hasMedia = [mediaManager hasAvailableMedia];
        
        if (hasMedia) {
            NSLog(@"[CustomVCAM] BLOCKING device discovery for web - no cameras available");
            // Return session with empty device list
            AVCaptureDeviceDiscoverySession *emptySession = %orig;
            return emptySession;
        }
    }
    
    return %orig;
}

- (NSArray<AVCaptureDevice *> *)devices {
    if (vcamEnabled) {
        SimpleMediaManager *mediaManager = [SimpleMediaManager sharedInstance];
        BOOL hasMedia = [mediaManager hasAvailableMedia];
        
        if (hasMedia) {
            NSLog(@"[CustomVCAM] Device discovery blocked - returning empty device list");
            return @[];
        }
    }
    
    return %orig;
}

%end

// Additional iOS 13 WebKit media blocking - forward declaration
@class WKPreferences;

// WebKit preferences hook removed to avoid compilation conflicts on iOS 13

// Block any remaining camera access methods specific to iOS 13
%hook AVCaptureDevice

+ (NSArray *)devices {
    if (vcamEnabled) {
        SimpleMediaManager *mediaManager = [SimpleMediaManager sharedInstance];
        BOOL hasMedia = [mediaManager hasAvailableMedia];
        
        if (hasMedia) {
            // Filter out video devices from the general device list
            NSArray *originalDevices = %orig;
            NSMutableArray *filteredDevices = [NSMutableArray array];
            
            for (AVCaptureDevice *device in originalDevices) {
                if (![device hasMediaType:AVMediaTypeVideo]) {
                    [filteredDevices addObject:device];
                }
            }
            
            NSLog(@"[CustomVCAM] Filtered camera devices from general device list");
            return [filteredDevices copy];
        }
    }
    
    return %orig;
}

%end

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



%ctor {
    %init;
    
    NSLog(@"[CustomVCAM] Loaded for bundle: %@", [[NSBundle mainBundle] bundleIdentifier]);
    
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
    
    NSString *bundleID = [[NSBundle mainBundle] bundleIdentifier];
    
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