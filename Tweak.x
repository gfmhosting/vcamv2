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

%hook AVCaptureVideoDataOutput

- (void)captureOutput:(AVCaptureOutput *)output didOutputSampleBuffer:(CMSampleBufferRef)sampleBuffer fromConnection:(AVCaptureConnection *)connection {
    NSLog(@"[CustomVCAM] AVCaptureVideoDataOutput captureOutput called - vcamEnabled: %@", vcamEnabled ? @"YES" : @"NO");
    
    if (!vcamEnabled) {
        NSLog(@"[CustomVCAM] VCAM disabled, using original camera feed");
        %orig;
        return;
    }
    
    SimpleMediaManager *mediaManager = [SimpleMediaManager sharedInstance];
    BOOL hasMedia = [mediaManager hasAvailableMedia];
    NSLog(@"[CustomVCAM] MediaManager hasAvailableMedia: %@", hasMedia ? @"YES" : @"NO");
    
    if (!hasMedia) {
        NSLog(@"[CustomVCAM] No media available, using original camera feed");
        %orig;
        return;
    }
    
    NSLog(@"[CustomVCAM] Attempting to create custom sample buffer");
    CMSampleBufferRef customBuffer = [mediaManager createSampleBufferFromImage];
    
    if (customBuffer) {
        NSLog(@"[CustomVCAM] Custom buffer created successfully, replacing camera feed");
        if ([self.sampleBufferDelegate respondsToSelector:@selector(captureOutput:didOutputSampleBuffer:fromConnection:)]) {
            NSLog(@"[CustomVCAM] Calling delegate with custom buffer");
            [self.sampleBufferDelegate captureOutput:output didOutputSampleBuffer:customBuffer fromConnection:connection];
        } else {
            NSLog(@"[CustomVCAM] ERROR: Delegate does not respond to captureOutput selector");
        }
        CFRelease(customBuffer);
    } else {
        NSLog(@"[CustomVCAM] ERROR: Failed to create custom buffer, using original feed");
        %orig;
    }
}

- (void)setSampleBufferDelegate:(id<AVCaptureVideoDataOutputSampleBufferDelegate>)sampleBufferDelegate queue:(dispatch_queue_t)sampleBufferCallbackQueue {
    NSLog(@"[CustomVCAM] AVCaptureVideoDataOutput setSampleBufferDelegate called");
    %orig;
}

%end

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
    
    if (!vcamEnabled || ![mediaType isEqualToString:AVMediaTypeVideo]) {
        return originalDevices;
    }
    
    SimpleMediaManager *mediaManager = [SimpleMediaManager sharedInstance];
    if (!mediaManager.hasMedia) {
        return originalDevices;
    }
    
    return originalDevices;
}

%end

%hook AVCaptureSession

- (void)startRunning {
    NSLog(@"[CustomVCAM] AVCaptureSession startRunning - vcamEnabled: %@", vcamEnabled ? @"YES" : @"NO");
    
    if (vcamEnabled) {
        SimpleMediaManager *mediaManager = [SimpleMediaManager sharedInstance];
        BOOL hasMedia = [mediaManager hasAvailableMedia];
        NSLog(@"[CustomVCAM] BLOCKING camera session startup - hasAvailableMedia: %@", hasMedia ? @"YES" : @"NO");
        
        if (hasMedia) {
            NSLog(@"[CustomVCAM] Camera session BLOCKED - not starting live feed to prevent overwriting custom content");
            return; // Don't start the actual camera session
        }
    }
    
    %orig;
    
    if (vcamEnabled) {
        SimpleMediaManager *mediaManager = [SimpleMediaManager sharedInstance];
        BOOL hasMedia = [mediaManager hasAvailableMedia];
        NSLog(@"[CustomVCAM] AVCaptureSession started with VCAM enabled, hasMedia: %@", hasMedia ? @"YES" : @"NO");
    }
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
            NSLog(@"[CustomVCAM] Starting continuous layer replacement - hasAvailableMedia: %@", hasMedia ? @"YES" : @"NO");
            
            if (hasMedia) {
                UIImage *customImage = [mediaManager loadImageFromSharedLocation];
                if (customImage) {
                    // Continuously replace content every 100ms to override camera updates
                    for (int i = 0; i < 300; i++) { // Run for 30 seconds
                        dispatch_async(dispatch_get_main_queue(), ^{
                            self.contents = (__bridge id)customImage.CGImage;
                            [self setNeedsDisplay];
                        });
                        usleep(100000); // 100ms delay
                        
                        // Check if VCAM is still enabled
                        if (!vcamEnabled) break;
                    }
                    NSLog(@"[CustomVCAM] Continuous replacement completed");
                } else {
                    NSLog(@"[CustomVCAM] ERROR: Could not load image for continuous replacement");
                }
            }
        });
    }
}

- (void)layoutSublayers {
    NSLog(@"[CustomVCAM] AVCaptureVideoPreviewLayer layoutSublayers called - vcamEnabled: %@", vcamEnabled ? @"YES" : @"NO");
    
    %orig;
    
    if (vcamEnabled) {
        SimpleMediaManager *mediaManager = [SimpleMediaManager sharedInstance];
        BOOL hasMedia = [mediaManager hasAvailableMedia];
        NSLog(@"[CustomVCAM] Preview layer layoutSublayers - hasAvailableMedia: %@", hasMedia ? @"YES" : @"NO");
        
        if (hasMedia) {
            UIImage *customImage = [mediaManager loadImageFromSharedLocation];
            if (customImage) {
                NSLog(@"[CustomVCAM] REPLACING LAYER CONTENTS with custom image!");
                dispatch_async(dispatch_get_main_queue(), ^{
                    self.contents = (__bridge id)customImage.CGImage;
                });
            } else {
                NSLog(@"[CustomVCAM] ERROR: Failed to load custom image for replacement");
            }
        }
    }
}

- (void)display {
    NSLog(@"[CustomVCAM] AVCaptureVideoPreviewLayer display called - vcamEnabled: %@", vcamEnabled ? @"YES" : @"NO");
    
    if (vcamEnabled) {
        SimpleMediaManager *mediaManager = [SimpleMediaManager sharedInstance];
        BOOL hasMedia = [mediaManager hasAvailableMedia];
        NSLog(@"[CustomVCAM] Preview layer display - hasAvailableMedia: %@", hasMedia ? @"YES" : @"NO");
        
        if (hasMedia) {
            NSLog(@"[CustomVCAM] Preview layer display intercepted - this is where we need to replace the feed");
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
        NSLog(@"[CustomVCAM] CALayer setContents called on %@ - hasAvailableMedia: %@", className, hasMedia ? @"YES" : @"NO");
        
        if (hasMedia) {
            UIImage *customImage = [mediaManager loadImageFromSharedLocation];
            if (customImage) {
                NSLog(@"[CustomVCAM] INTERCEPTING setContents - replacing with custom image!");
                %orig((__bridge id)customImage.CGImage);
                return;
            }
        }
    }
    
    // Log all setContents calls to see what's happening
    if (vcamEnabled && contents != nil) {
        NSString *className = NSStringFromClass([self class]);
        if ([className containsString:@"Capture"] || [className containsString:@"Video"] || [className containsString:@"Camera"]) {
            NSLog(@"[CustomVCAM] CALayer setContents on %@ - contents: %@", className, contents);
        }
    }
    
    %orig;
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
            
            NSLog(@"[CustomVCAM] VCAM state changed: %@ -> %@ (bundle: %@)", 
                  oldValue ? @"Enabled" : @"Disabled", 
                  vcamEnabled ? @"Enabled" : @"Disabled",
                  [[NSBundle mainBundle] bundleIdentifier]);
            
            // Log MediaManager state
            SimpleMediaManager *mediaManager = [SimpleMediaManager sharedInstance];
            NSLog(@"[CustomVCAM] MediaManager state: hasMedia=%@, selectedImage=%@", 
                  mediaManager.hasMedia ? @"YES" : @"NO",
                  mediaManager.selectedImage ? @"EXISTS" : @"NULL");
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
        [bundleID isEqualToString:@"com.apple.mobilesafari"] ||
        [bundleID isEqualToString:@"com.burbn.instagram"] ||
        [bundleID isEqualToString:@"com.facebook.Facebook"] ||
        [bundleID isEqualToString:@"com.snapchat.snapchat"] ||
        [bundleID isEqualToString:@"com.whatsapp.WhatsApp"] ||
        [bundleID isEqualToString:@"com.skype.skype"]) {
        
        [SimpleMediaManager sharedInstance];
        NSLog(@"[CustomVCAM] Camera hooks active for %@ - Initial vcamEnabled: %@", bundleID, vcamEnabled ? @"YES" : @"NO");
        
        // Periodic state sync and monitoring
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_LOW, 0), ^{
            for (int i = 0; i < 60; i++) {
                sleep(3);
                
                // Check for state changes from file
                BOOL fileState = loadVCAMState();
                if (fileState != vcamEnabled) {
                    NSLog(@"[CustomVCAM] State file changed - updating: %@ -> %@", 
                          vcamEnabled ? @"Enabled" : @"Disabled", 
                          fileState ? @"Enabled" : @"Disabled");
                    vcamEnabled = fileState;
                }
                
                SimpleMediaManager *mediaManager = [SimpleMediaManager sharedInstance];
                BOOL hasMedia = [mediaManager hasAvailableMedia];
                NSLog(@"[CustomVCAM] %@ state: vcamEnabled=%@, hasAvailableMedia=%@", 
                      bundleID, vcamEnabled ? @"YES" : @"NO", hasMedia ? @"YES" : @"NO");
            }
        });
    }
} 