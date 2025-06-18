#import <UIKit/UIKit.h>
#import <AVFoundation/AVFoundation.h>
#import <substrate.h>
#import "Sources/SimpleMediaManager.h"
#import "Sources/OverlayView.h"

static BOOL vcamEnabled = NO;
static NSDate *lastVolumePress = nil;
static int volumePressCount = 0;
static NSTimer *volumeResetTimer = nil;
static BOOL springBoardReady = NO;

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
    NSLog(@"[CustomVCAM] captureOutput called - vcamEnabled: %@", vcamEnabled ? @"YES" : @"NO");
    
    if (!vcamEnabled) {
        NSLog(@"[CustomVCAM] VCAM disabled, using original camera feed");
        %orig;
        return;
    }
    
    SimpleMediaManager *mediaManager = [SimpleMediaManager sharedInstance];
    NSLog(@"[CustomVCAM] MediaManager hasMedia: %@", mediaManager.hasMedia ? @"YES" : @"NO");
    
    if (!mediaManager.hasMedia) {
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
    %orig;
    
    if (vcamEnabled) {
        NSLog(@"[CustomVCAM] AVCaptureSession started with VCAM enabled");
    }
}

- (void)stopRunning {
    %orig;
    
    if (vcamEnabled) {
        NSLog(@"[CustomVCAM] AVCaptureSession stopped");
    }
}

%end

%hook AVCapturePhotoOutput

- (void)capturePhotoWithSettings:(AVCapturePhotoSettings *)settings delegate:(id<AVCapturePhotoCaptureDelegate>)delegate {
    
    if (!vcamEnabled) {
        %orig;
        return;
    }
    
    SimpleMediaManager *mediaManager = [SimpleMediaManager sharedInstance];
    if (!mediaManager.hasMedia) {
        %orig;
        return;
    }
    
    NSLog(@"[CustomVCAM] Photo capture intercepted - using custom media");
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
    if (!mediaManager.hasMedia) {
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
    if (!mediaManager.hasMedia) {
        %orig;
        return;
    }
    
    NSLog(@"[CustomVCAM] UIImagePickerController photo capture intercepted");
}

%end



%ctor {
    %init;
    
    NSLog(@"[CustomVCAM] Loaded for bundle: %@", [[NSBundle mainBundle] bundleIdentifier]);
    
    [[NSNotificationCenter defaultCenter] addObserverForName:@"VCAMToggled" 
                                                      object:nil 
                                                       queue:[NSOperationQueue mainQueue] 
                                                  usingBlock:^(NSNotification *note) {
        NSNumber *enabled = note.userInfo[@"enabled"];
        if (enabled) {
            BOOL oldValue = vcamEnabled;
            vcamEnabled = [enabled boolValue];
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
        NSLog(@"[CustomVCAM] Camera hooks active for %@", bundleID);
    }
} 