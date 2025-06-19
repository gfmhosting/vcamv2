#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>
#import <AVFoundation/AVFoundation.h>
#import <CoreMedia/CoreMedia.h>
#import <CoreVideo/CoreVideo.h>
#import <MediaPlayer/MediaPlayer.h>
#import <AudioToolbox/AudioToolbox.h>
#import <IOKit/hid/IOHIDEventSystem.h>
#import <IOKit/hid/IOHIDEventTypes.h>
#import <substrate.h>
#import "Sources/MediaManager.h"
#import "Sources/OverlayView.h"
#import "Sources/SimpleMediaManager.h"

static BOOL vcamEnabled = NO;
static BOOL vcamActive = NO;
static NSString *selectedMediaPath = nil;
static MediaManager *mediaManager = nil;
static OverlayView *overlayView = nil;

// Shared preferences key for cross-process communication
#define VCAM_PREFS_DOMAIN @"com.customvcam.vcam"
#define VCAM_ACTIVE_KEY @"vcamActive"
#define VCAM_MEDIA_PATH_KEY @"selectedMediaPath"

// Cross-process communication helpers
static void setSharedVCAMState(BOOL active, NSString *mediaPath) {
    NSUserDefaults *prefs = [[NSUserDefaults alloc] initWithSuiteName:VCAM_PREFS_DOMAIN];
    [prefs setBool:active forKey:VCAM_ACTIVE_KEY];
    if (mediaPath) {
        [prefs setObject:mediaPath forKey:VCAM_MEDIA_PATH_KEY];
    } else {
        [prefs removeObjectForKey:VCAM_MEDIA_PATH_KEY];
    }
    [prefs synchronize];
    NSLog(@"[CustomVCAM] Shared state updated: active=%d, path=%@", active, mediaPath);
}

static void loadSharedVCAMState(void) {
    NSUserDefaults *prefs = [[NSUserDefaults alloc] initWithSuiteName:VCAM_PREFS_DOMAIN];
    vcamActive = [prefs boolForKey:VCAM_ACTIVE_KEY];
    selectedMediaPath = [prefs stringForKey:VCAM_MEDIA_PATH_KEY];
    NSLog(@"[CustomVCAM] Loaded shared state: active=%d, path=%@", vcamActive, selectedMediaPath);
}

@interface CustomVCAMDelegate : NSObject <OverlayViewDelegate>
@end

@implementation CustomVCAMDelegate

- (void)overlayView:(id)overlayView didSelectMediaAtPath:(NSString *)mediaPath {
    NSLog(@"[CustomVCAM] Media selected: %@", mediaPath);
    selectedMediaPath = mediaPath;
    vcamActive = YES;
    
    // Share state across processes
    setSharedVCAMState(YES, mediaPath);
    
    if ([mediaManager setMediaFromPath:mediaPath]) {
        NSLog(@"[CustomVCAM] Media injection activated for Stripe bypass");
    } else {
        NSLog(@"[CustomVCAM] Failed to set media for injection");
        vcamActive = NO;
        selectedMediaPath = nil;
        setSharedVCAMState(NO, nil);
    }
}

- (void)overlayViewDidCancel:(id)overlayView {
    NSLog(@"[CustomVCAM] Media selection cancelled");
    vcamActive = NO;
    selectedMediaPath = nil;
    setSharedVCAMState(NO, nil);
}

@end

// Forward declarations
static void handleVolumeButtonPress(BOOL isVolumeUp);
static void resetVolumeButtonState(void);

// SpringBoard volume button tracking
static NSTimeInterval lastVolumeButtonTime = 0;
static NSInteger volumeButtonCount = 0;
static BOOL isSpringBoardProcess = NO;
static CustomVCAMDelegate *vcamDelegate = nil;

static void handleVolumeButtonPress(BOOL isVolumeUp) {
    NSLog(@"[CustomVCAM] Volume button pressed: %s", isVolumeUp ? "UP" : "DOWN");
    
    NSTimeInterval currentTime = [[NSDate date] timeIntervalSince1970];
    
    if (currentTime - lastVolumeButtonTime < 0.8) {
        volumeButtonCount++;
        NSLog(@"[CustomVCAM] Volume button count: %ld (within 0.8s)", (long)volumeButtonCount);
        
        if (volumeButtonCount >= 2) {
            NSLog(@"[CustomVCAM] DOUBLE-TAP DETECTED! Triggering media picker");
            dispatch_async(dispatch_get_main_queue(), ^{
                if (!overlayView) {
                    overlayView = [[OverlayView alloc] init];
                    overlayView.delegate = vcamDelegate;
                }
                [overlayView showMediaPicker];
            });
            
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                resetVolumeButtonState();
            });
            return;
        }
    } else {
        volumeButtonCount = 1;
        NSLog(@"[CustomVCAM] First volume button press detected");
    }
    
    lastVolumeButtonTime = currentTime;
    
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.8 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        if ([[NSDate date] timeIntervalSince1970] - lastVolumeButtonTime >= 0.8) {
            resetVolumeButtonState();
        }
    });
}

static void resetVolumeButtonState() {
    volumeButtonCount = 0;
    NSLog(@"[CustomVCAM] Volume button state reset");
}

// SpringBoard volume button hooks
@interface SBVolumeControl : NSObject
- (void)increaseVolume;
- (void)decreaseVolume;
- (void)_changeVolumeBy:(float)arg1;
@end

%hook SBVolumeControl

- (void)increaseVolume {
    NSLog(@"[CustomVCAM] SpringBoard volume UP detected");
    if (isSpringBoardProcess) {
        handleVolumeButtonPress(YES);
    }
    %orig;
}

- (void)decreaseVolume {
    NSLog(@"[CustomVCAM] SpringBoard volume DOWN detected");
    if (isSpringBoardProcess) {
        handleVolumeButtonPress(NO);
    }
    %orig;
}

%end

// Alternative hook for iOS 13
@interface SBHUDController : NSObject
- (void)_presentHUD:(id)arg1 autoDismissWithDelay:(double)arg2;
@end

%hook SBHUDController

- (void)_presentHUD:(id)hud autoDismissWithDelay:(double)delay {
    NSLog(@"[CustomVCAM] SBHUDController HUD presented: %@", hud);
    
    // Check if this is a volume HUD
    NSString *hudClassName = NSStringFromClass([hud class]);
    if ([hudClassName containsString:@"Volume"] || [hudClassName containsString:@"SBRingerHUD"]) {
        NSLog(@"[CustomVCAM] Volume HUD detected via SBHUDController");
        if (isSpringBoardProcess) {
            handleVolumeButtonPress(YES); // We can't easily determine up/down here
        }
    }
    
    %orig;
}

%end

%hook AVCaptureVideoDataOutput

- (void)captureOutput:(AVCaptureOutput *)output didOutputSampleBuffer:(CMSampleBufferRef)sampleBuffer fromConnection:(AVCaptureConnection *)connection {
    // Load shared state if not SpringBoard process
    if (!isSpringBoardProcess) {
        loadSharedVCAMState();
    }
    
    if (vcamActive && selectedMediaPath) {
        NSLog(@"[CustomVCAM] Camera capture detected - replacing with: %@", selectedMediaPath);
        
        // Ensure MediaManager is initialized for non-SpringBoard processes
        if (!mediaManager) {
            mediaManager = [[MediaManager alloc] init];
            NSLog(@"[CustomVCAM] MediaManager initialized for camera replacement");
        }
        
        CMSampleBufferRef modifiedBuffer = [mediaManager createSampleBufferFromMediaPath:selectedMediaPath];
        if (modifiedBuffer) {
            NSLog(@"[CustomVCAM] Successfully created replacement sample buffer");
            %orig(output, modifiedBuffer, connection);
            CFRelease(modifiedBuffer);
            return;
        } else {
            NSLog(@"[CustomVCAM] Failed to create replacement sample buffer");
        }
    }
    
    %orig;
}

%end

%ctor {
    NSString *bundleIdentifier = [[NSBundle mainBundle] bundleIdentifier];
    isSpringBoardProcess = [bundleIdentifier isEqualToString:@"com.apple.springboard"];
    
    NSLog(@"[CustomVCAM] Tweak loaded in process: %@ (SpringBoard: %@)", bundleIdentifier, isSpringBoardProcess ? @"YES" : @"NO");
    
    if (isSpringBoardProcess) {
        // SpringBoard: Handle volume buttons and media selection
        mediaManager = [[MediaManager alloc] init];
        vcamDelegate = [[CustomVCAMDelegate alloc] init];
        vcamEnabled = YES;
        
        NSLog(@"[CustomVCAM] Media manager initialized, VCAM enabled for Stripe bypass");
        NSLog(@"[CustomVCAM] SpringBoard volume button hooks active for iPhone 7 iOS 13.3.1");
    } else {
        // Camera/Safari: Load shared state and prepare for camera replacement
        loadSharedVCAMState();
        
        // Initialize MediaManager for camera replacement
        mediaManager = [[MediaManager alloc] init];
        
        NSLog(@"[CustomVCAM] Camera replacement ready in %@", bundleIdentifier);
        NSLog(@"[CustomVCAM] Loaded state: active=%d, path=%@", vcamActive, selectedMediaPath);
    }
} 