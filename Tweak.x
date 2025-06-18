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
    static int callCount = 0;
    callCount++;
    CFTimeInterval timestamp = CACurrentMediaTime();
    
    NSLog(@"[CustomVCAM] === captureOutput ENTRY === Call #%d, Time: %.3f, Thread: %@", 
          callCount, timestamp, [NSThread currentThread].name ?: @"unnamed");
    NSLog(@"[CustomVCAM] Output: %p, Connection: %p, vcamEnabled: %@, Delegate: %p", 
          output, connection, vcamEnabled ? @"YES" : @"NO", self.sampleBufferDelegate);
    
    if (!vcamEnabled) {
        NSLog(@"[CustomVCAM] VCAM disabled - passing through original sample buffer");
        %orig;
        NSLog(@"[CustomVCAM] === captureOutput EXIT (ORIGINAL) === Call #%d", callCount);
        return;
    }
    
    NSLog(@"[CustomVCAM] VCAM enabled - attempting interception...");
    SimpleMediaManager *mediaManager = [SimpleMediaManager sharedInstance];
    NSLog(@"[CustomVCAM] MediaManager instance: %p", mediaManager);
    
    BOOL hasMedia = [mediaManager hasAvailableMedia];
    NSLog(@"[CustomVCAM] hasAvailableMedia returned: %@ (Time: %.3f)", hasMedia ? @"YES" : @"NO", CACurrentMediaTime());
    
    if (!hasMedia) {
        NSLog(@"[CustomVCAM] No media available - passing through original sample buffer");
        %orig;
        NSLog(@"[CustomVCAM] === captureOutput EXIT (NO_MEDIA) === Call #%d", callCount);
        return;
    }
    
    NSLog(@"[CustomVCAM] Creating custom sample buffer for replacement...");
    CMSampleBufferRef customBuffer = [mediaManager createSampleBufferFromImage];
    NSLog(@"[CustomVCAM] Custom buffer creation result: %@", customBuffer ? @"SUCCESS" : @"FAILED");
    
    if (customBuffer) {
        NSLog(@"[CustomVCAM] Custom buffer created successfully - replacing camera feed");
        NSLog(@"[CustomVCAM] Delegate check: %@", 
              [self.sampleBufferDelegate respondsToSelector:@selector(captureOutput:didOutputSampleBuffer:fromConnection:)] ? @"RESPONDS" : @"NO_RESPONSE");
        
        if ([self.sampleBufferDelegate respondsToSelector:@selector(captureOutput:didOutputSampleBuffer:fromConnection:)]) {
            NSLog(@"[CustomVCAM] *** CALLING DELEGATE WITH CUSTOM BUFFER *** (Time: %.3f)", CACurrentMediaTime());
            [self.sampleBufferDelegate captureOutput:output didOutputSampleBuffer:customBuffer fromConnection:connection];
            NSLog(@"[CustomVCAM] Delegate call completed successfully");
        } else {
            NSLog(@"[CustomVCAM] ERROR: Delegate %@ does not respond to captureOutput selector", self.sampleBufferDelegate);
        }
        
        NSLog(@"[CustomVCAM] Releasing custom buffer...");
        CFRelease(customBuffer);
        NSLog(@"[CustomVCAM] === captureOutput EXIT (CUSTOM) === Call #%d", callCount);
    } else {
        NSLog(@"[CustomVCAM] ERROR: Failed to create custom buffer - falling back to original feed");
        %orig;
        NSLog(@"[CustomVCAM] === captureOutput EXIT (FALLBACK) === Call #%d", callCount);
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
    NSLog(@"[CustomVCAM] === AVCaptureSession startRunning ENTRY === Thread: %@, vcamEnabled: %@", 
          [NSThread currentThread].name ?: @"unnamed", vcamEnabled ? @"YES" : @"NO");
    
    if (vcamEnabled) {
        NSLog(@"[CustomVCAM] VCAM is enabled, checking media availability...");
        SimpleMediaManager *mediaManager = [SimpleMediaManager sharedInstance];
        BOOL hasMedia = [mediaManager hasAvailableMedia];
        NSLog(@"[CustomVCAM] MediaManager instance: %p, hasAvailableMedia result: %@", 
              mediaManager, hasMedia ? @"YES" : @"NO");
        
        if (hasMedia) {
            NSLog(@"[CustomVCAM] *** CRITICAL: BLOCKING camera session startup to prevent live feed ***");
            NSLog(@"[CustomVCAM] Session %p will NOT start - custom content should remain visible", self);
            return; // Don't start the actual camera session
        } else {
            NSLog(@"[CustomVCAM] No media available, allowing normal camera session startup");
        }
    } else {
        NSLog(@"[CustomVCAM] VCAM disabled, normal camera session startup");
    }
    
    NSLog(@"[CustomVCAM] Calling original startRunning for session %p", self);
    %orig;
    NSLog(@"[CustomVCAM] Original startRunning completed for session %p", self);
    
    if (vcamEnabled) {
        SimpleMediaManager *mediaManager = [SimpleMediaManager sharedInstance];
        BOOL hasMedia = [mediaManager hasAvailableMedia];
        NSLog(@"[CustomVCAM] Post-startup check: session %p running, hasMedia: %@", self, hasMedia ? @"YES" : @"NO");
        NSLog(@"[CustomVCAM] Session running state: %@", [self isRunning] ? @"RUNNING" : @"STOPPED");
    }
    
    NSLog(@"[CustomVCAM] === AVCaptureSession startRunning EXIT ===");
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
        NSLog(@"[CustomVCAM] Starting background continuous replacement thread...");
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0), ^{
            SimpleMediaManager *mediaManager = [SimpleMediaManager sharedInstance];
            BOOL hasMedia = [mediaManager hasAvailableMedia];
            NSLog(@"[CustomVCAM] Background thread started - hasAvailableMedia: %@", hasMedia ? @"YES" : @"NO");
            
            if (hasMedia) {
                UIImage *customImage = [mediaManager loadImageFromSharedLocation];
                NSLog(@"[CustomVCAM] Background: Custom image loaded: %@", customImage ? @"SUCCESS" : @"FAILED");
                
                if (customImage) {
                    NSLog(@"[CustomVCAM] *** STARTING AGGRESSIVE CONTENT REPLACEMENT *** (300 iterations, 100ms interval)");
                    CFTimeInterval startTime = CACurrentMediaTime();
                    
                    // Continuously replace content every 100ms to override camera updates
                    for (int i = 0; i < 300; i++) { // Run for 30 seconds
                        CFTimeInterval currentTime = CACurrentMediaTime();
                        
                        dispatch_async(dispatch_get_main_queue(), ^{
                            self.contents = (__bridge id)customImage.CGImage;
                            [self setNeedsDisplay];
                            
                            if (i % 50 == 0) { // Log every 5 seconds
                                NSLog(@"[CustomVCAM] Continuous replacement iteration %d/300 (%.1fs elapsed)", 
                                      i, currentTime - startTime);
                            }
                        });
                        
                        usleep(100000); // 100ms delay
                        
                        // Check if VCAM is still enabled
                        if (!vcamEnabled) {
                            NSLog(@"[CustomVCAM] VCAM disabled - stopping continuous replacement at iteration %d", i);
                            break;
                        }
                    }
                    
                    CFTimeInterval totalTime = CACurrentMediaTime() - startTime;
                    NSLog(@"[CustomVCAM] Continuous replacement completed - total time: %.1fs", totalTime);
                } else {
                    NSLog(@"[CustomVCAM] ERROR: Could not load image for continuous replacement");
                }
            } else {
                NSLog(@"[CustomVCAM] No media available - skipping continuous replacement");
            }
        });
    }
}

- (void)layoutSublayers {
    NSLog(@"[CustomVCAM] === layoutSublayers ENTRY === Layer: %p, Thread: %@, vcamEnabled: %@", 
          self, [NSThread currentThread].name ?: @"unnamed", vcamEnabled ? @"YES" : @"NO");
    NSLog(@"[CustomVCAM] Layer frame: %@, bounds: %@", NSStringFromCGRect(self.frame), NSStringFromCGRect(self.bounds));
    NSLog(@"[CustomVCAM] Current layer contents: %@", self.contents ? @"EXISTS" : @"NULL");
    
    NSLog(@"[CustomVCAM] Calling original layoutSublayers...");
    %orig;
    NSLog(@"[CustomVCAM] Original layoutSublayers completed, contents after: %@", self.contents ? @"EXISTS" : @"NULL");
    
    if (vcamEnabled) {
        NSLog(@"[CustomVCAM] VCAM enabled, starting replacement process...");
        SimpleMediaManager *mediaManager = [SimpleMediaManager sharedInstance];
        NSLog(@"[CustomVCAM] MediaManager instance: %p", mediaManager);
        
        BOOL hasMedia = [mediaManager hasAvailableMedia];
        NSLog(@"[CustomVCAM] hasAvailableMedia returned: %@", hasMedia ? @"YES" : @"NO");
        
        if (hasMedia) {
            NSLog(@"[CustomVCAM] Loading custom image from shared location...");
            UIImage *customImage = [mediaManager loadImageFromSharedLocation];
            NSLog(@"[CustomVCAM] Image loaded: %p, size: %@", customImage, 
                  customImage ? NSStringFromCGSize(customImage.size) : @"NULL");
            
            if (customImage) {
                NSLog(@"[CustomVCAM] *** REPLACING LAYER CONTENTS *** CGImage: %p", customImage.CGImage);
                NSLog(@"[CustomVCAM] Dispatching to main queue for content replacement...");
                
                dispatch_async(dispatch_get_main_queue(), ^{
                    NSLog(@"[CustomVCAM] Main queue: Setting layer contents to custom image");
                    self.contents = (__bridge id)customImage.CGImage;
                    NSLog(@"[CustomVCAM] Content set, calling setNeedsDisplay...");
                    [self setNeedsDisplay];
                    NSLog(@"[CustomVCAM] setNeedsDisplay called, contents now: %@", self.contents ? @"EXISTS" : @"NULL");
                });
            } else {
                NSLog(@"[CustomVCAM] ERROR: Custom image is NULL - replacement failed");
            }
        } else {
            NSLog(@"[CustomVCAM] No media available - skipping replacement");
        }
    } else {
        NSLog(@"[CustomVCAM] VCAM disabled - no replacement");
    }
    
    NSLog(@"[CustomVCAM] === layoutSublayers EXIT === Final contents: %@", self.contents ? @"EXISTS" : @"NULL");
}

- (void)display {
    static int displayCount = 0;
    displayCount++;
    CFTimeInterval timestamp = CACurrentMediaTime();
    
    NSLog(@"[CustomVCAM] === display ENTRY === Call #%d, Time: %.3f, Layer: %p, Thread: %@", 
          displayCount, timestamp, self, [NSThread currentThread].name ?: @"unnamed");
    NSLog(@"[CustomVCAM] vcamEnabled: %@, Layer bounds: %@", vcamEnabled ? @"YES" : @"NO", NSStringFromCGRect(self.bounds));
    NSLog(@"[CustomVCAM] Current layer contents before display: %@", self.contents ? @"EXISTS" : @"NULL");
    
    if (vcamEnabled) {
        NSLog(@"[CustomVCAM] VCAM enabled - attempting preview layer interception...");
        SimpleMediaManager *mediaManager = [SimpleMediaManager sharedInstance];
        NSLog(@"[CustomVCAM] MediaManager instance: %p", mediaManager);
        
        BOOL hasMedia = [mediaManager hasAvailableMedia];
        NSLog(@"[CustomVCAM] hasAvailableMedia: %@ (Time: %.3f)", hasMedia ? @"YES" : @"NO", CACurrentMediaTime());
        
        if (hasMedia) {
            NSLog(@"[CustomVCAM] *** CRITICAL POINT *** Preview layer display intercepted - attempting replacement");
            UIImage *customImage = [mediaManager loadImageFromSharedLocation];
            NSLog(@"[CustomVCAM] Custom image for display: %@", customImage ? @"LOADED" : @"NULL");
            
            if (customImage) {
                NSLog(@"[CustomVCAM] Setting custom content BEFORE calling original display");
                self.contents = (__bridge id)customImage.CGImage;
                NSLog(@"[CustomVCAM] Custom content set, calling setNeedsDisplay");
                [self setNeedsDisplay];
                NSLog(@"[CustomVCAM] Layer contents after custom set: %@", self.contents ? @"EXISTS" : @"NULL");
            }
        } else {
            NSLog(@"[CustomVCAM] No media available - allowing normal display");
        }
    } else {
        NSLog(@"[CustomVCAM] VCAM disabled - normal display processing");
    }
    
    NSLog(@"[CustomVCAM] Calling original display method...");
    %orig;
    NSLog(@"[CustomVCAM] Original display completed, final layer contents: %@", self.contents ? @"EXISTS" : @"NULL");
    NSLog(@"[CustomVCAM] === display EXIT === Call #%d, Time: %.3f", displayCount, CACurrentMediaTime());
}

%end

%hook CALayer

- (void)setContents:(id)contents {
    NSString *className = NSStringFromClass([self class]);
    CFTimeInterval timestamp = CACurrentMediaTime();
    
    NSLog(@"[CustomVCAM] === setContents ENTRY === Time: %.3f, Layer: %p (%@), Thread: %@", 
          timestamp, self, className, [NSThread currentThread].name ?: @"unnamed");
    NSLog(@"[CustomVCAM] Incoming contents: %@, Current contents: %@, vcamEnabled: %@", 
          contents ? @"EXISTS" : @"NULL", self.contents ? @"EXISTS" : @"NULL", vcamEnabled ? @"YES" : @"NO");
    NSLog(@"[CustomVCAM] Layer frame: %@, bounds: %@", NSStringFromCGRect(self.frame), NSStringFromCGRect(self.bounds));
    
    if (vcamEnabled && [className containsString:@"AVCaptureVideoPreview"]) {
        NSLog(@"[CustomVCAM] *** DETECTED PREVIEW LAYER *** - Starting interception process...");
        SimpleMediaManager *mediaManager = [SimpleMediaManager sharedInstance];
        NSLog(@"[CustomVCAM] MediaManager instance: %p", mediaManager);
        
        BOOL hasMedia = [mediaManager hasAvailableMedia];
        NSLog(@"[CustomVCAM] hasAvailableMedia result: %@ (Time: %.3f)", hasMedia ? @"YES" : @"NO", CACurrentMediaTime());
        
        if (hasMedia) {
            NSLog(@"[CustomVCAM] Loading custom image for interception...");
            UIImage *customImage = [mediaManager loadImageFromSharedLocation];
            NSLog(@"[CustomVCAM] Custom image loaded: %p, size: %@, CGImage: %p", customImage, 
                  customImage ? NSStringFromCGSize(customImage.size) : @"NULL", customImage ? customImage.CGImage : NULL);
            
            if (customImage) {
                NSLog(@"[CustomVCAM] *** INTERCEPTING setContents *** Replacing camera feed with custom image!");
                NSLog(@"[CustomVCAM] Original content was: %@", contents ? @"EXISTS" : @"NULL");
                NSLog(@"[CustomVCAM] Setting custom CGImage: %p (Time: %.3f)", customImage.CGImage, CACurrentMediaTime());
                
                %orig((__bridge id)customImage.CGImage);
                
                NSLog(@"[CustomVCAM] Interception completed - layer contents now: %@", self.contents ? @"EXISTS" : @"NULL");
                NSLog(@"[CustomVCAM] === setContents EXIT (INTERCEPTED) === Time: %.3f", CACurrentMediaTime());
                return;
            } else {
                NSLog(@"[CustomVCAM] ERROR: Custom image is NULL - cannot intercept, falling back to original");
            }
        } else {
            NSLog(@"[CustomVCAM] No media available - passing through original content");
        }
    }
    
    // Enhanced logging for all relevant layer types
    if (vcamEnabled && contents != nil) {
        if ([className containsString:@"Capture"] || [className containsString:@"Video"] || 
            [className containsString:@"Camera"] || [className containsString:@"Preview"]) {
            NSLog(@"[CustomVCAM] *** CAMERA-RELATED LAYER *** %@ setContents - contents: %@ (Time: %.3f)", 
                  className, contents, CACurrentMediaTime());
            NSLog(@"[CustomVCAM] This might be overwriting our custom content!");
        }
    }
    
    NSLog(@"[CustomVCAM] Calling original setContents with: %@", contents ? @"EXISTS" : @"NULL");
    %orig;
    NSLog(@"[CustomVCAM] Original setContents completed - final contents: %@", self.contents ? @"EXISTS" : @"NULL");
    NSLog(@"[CustomVCAM] === setContents EXIT (ORIGINAL) === Time: %.3f", CACurrentMediaTime());
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