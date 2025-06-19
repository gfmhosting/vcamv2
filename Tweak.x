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

@interface CustomVCAMDelegate : NSObject <OverlayViewDelegate>
@end

@implementation CustomVCAMDelegate

- (void)overlayView:(id)overlayView didSelectMediaAtPath:(NSString *)mediaPath {
    NSLog(@"[CustomVCAM] Media selected: %@", mediaPath);
    selectedMediaPath = mediaPath;
    vcamActive = YES;
    
    if ([mediaManager setMediaFromPath:mediaPath]) {
        NSLog(@"[CustomVCAM] Media injection activated for Stripe bypass");
    } else {
        NSLog(@"[CustomVCAM] Failed to set media for injection");
        vcamActive = NO;
        selectedMediaPath = nil;
    }
}

- (void)overlayViewDidCancel:(id)overlayView {
    NSLog(@"[CustomVCAM] Media selection cancelled");
}

@end

// Forward declarations
static void handleVolumeButtonPress(int buttonType);
static void resetVolumeButtonState(void);

// IOHIDEventSystem function declarations
#ifdef __cplusplus
extern "C" {
#endif

// No need to redefine IOHIDEventSystemCallback - it's already in IOKit headers

#ifdef __cplusplus
}
#endif

#define kIOHIDEventTypeButton 3
#define kIOHIDEventFieldButtonMask 0x00010002
#define kIOHIDEventFieldButtonState 0x00010001

// Volume button tracking
static NSTimeInterval lastVolumeButtonTime = 0;
static NSInteger volumeButtonCount = 0;
static BOOL isSpringBoardProcess = NO;
static CustomVCAMDelegate *vcamDelegate = nil;

static void handleVolumeButtonPress(int buttonType) {
    NSLog(@"[CustomVCAM] Volume button pressed: %d", buttonType);
    
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

// IOHIDEventSystem callback for volume button detection
static void IOHIDEventCallback(void* target, void* refcon, IOHIDServiceRef service, IOHIDEventRef event) {
    if (!isSpringBoardProcess) {
        return;
    }
    
    int eventType = IOHIDEventGetType(event);
    NSLog(@"[CustomVCAM] IOHIDEvent received: type=%d", eventType);
    
    if (eventType == kIOHIDEventTypeButton) {
        int buttonMask = IOHIDEventGetIntegerValue(event, kIOHIDEventFieldButtonMask);
        int buttonState = IOHIDEventGetIntegerValue(event, kIOHIDEventFieldButtonState);
        
        NSLog(@"[CustomVCAM] Button event: mask=0x%x, state=%d", buttonMask, buttonState);
        
        // Detect any button press (volume buttons, home button, etc.)
        if (buttonState == 1) {
            handleVolumeButtonPress(buttonMask);
        }
    }
}

%hook AVCaptureVideoDataOutput

- (void)captureOutput:(AVCaptureOutput *)output didOutputSampleBuffer:(CMSampleBufferRef)sampleBuffer fromConnection:(AVCaptureConnection *)connection {
    if (vcamActive && selectedMediaPath) {
        CMSampleBufferRef modifiedBuffer = [mediaManager createSampleBufferFromMediaPath:selectedMediaPath];
        if (modifiedBuffer) {
            %orig(output, modifiedBuffer, connection);
            CFRelease(modifiedBuffer);
            return;
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
        mediaManager = [[MediaManager alloc] init];
        vcamDelegate = [[CustomVCAMDelegate alloc] init];
        vcamEnabled = YES;
        
        // Setup IOHIDEventSystem for volume button detection
        NSLog(@"[CustomVCAM] Setting up IOHIDEventSystem for hardware volume button detection");
        
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
            @try {
                IOHIDEventSystemRef hidEventSystem = IOHIDEventSystemCreate(kCFAllocatorDefault);
                if (hidEventSystem) {
                    NSLog(@"[CustomVCAM] IOHIDEventSystem created successfully");
                    
                    // Open the event system with callback
                    Boolean result = IOHIDEventSystemOpen(hidEventSystem, IOHIDEventCallback, NULL, NULL, NULL);
                    if (result) {
                        NSLog(@"[CustomVCAM] IOHIDEventSystem opened successfully for iPhone 7 iOS 13.3.1");
                    } else {
                        NSLog(@"[CustomVCAM] Failed to open IOHIDEventSystem");
                    }
                } else {
                    NSLog(@"[CustomVCAM] Failed to create IOHIDEventSystem");
                }
            } @catch (NSException *exception) {
                NSLog(@"[CustomVCAM] IOHIDEventSystem setup failed: %@", exception.reason);
            }
        });
        
        NSLog(@"[CustomVCAM] Media manager initialized, VCAM enabled for Stripe bypass");
        NSLog(@"[CustomVCAM] IOHIDEventSystem volume button monitoring active");
    }
} 