#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>
#import <AVFoundation/AVFoundation.h>
#import <CoreMedia/CoreMedia.h>
#import <CoreVideo/CoreVideo.h>
#import <substrate.h>
#import "Sources/MediaManager.h"
#import "Sources/OverlayView.h"
#import "Sources/SimpleMediaManager.h"

static BOOL vcamEnabled = NO;
static BOOL vcamActive = NO;
static NSString *selectedMediaPath = nil;
static MediaManager *mediaManager = nil;
static OverlayView *overlayView = nil;

@interface IOHIDEventSystem : NSObject
- (void)_IOHIDEventSystemClientSetMatching:(id)client matching:(id)matching;
@end

@interface SpringBoard : UIApplication
- (void)_handleVolumeButtonDown:(id)down;
- (void)_handleVolumeButtonUp:(id)up;
@end

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

static CustomVCAMDelegate *vcamDelegate = nil;

static NSTimeInterval lastVolumeButtonPress = 0;
static NSInteger volumeButtonPressCount = 0;
static NSTimer *doubleTapTimer = nil;

static void handleVolumeDoubleTap() {
    NSLog(@"[CustomVCAM] Volume double-tap detected!");
    
    if (!overlayView) {
        overlayView = [[OverlayView alloc] init];
        overlayView.delegate = vcamDelegate;
    }
    
    [overlayView showMediaPicker];
}

static void resetVolumeButtonState() {
    volumeButtonPressCount = 0;
    if (doubleTapTimer) {
        [doubleTapTimer invalidate];
        doubleTapTimer = nil;
    }
}

%hook IOHIDEventSystem

- (void)_IOHIDEventSystemClientSetMatching:(id)client matching:(id)matching {
    %orig;
    
    NSTimeInterval currentTime = [[NSDate date] timeIntervalSince1970];
    
    if (currentTime - lastVolumeButtonPress < 0.5) {
        volumeButtonPressCount++;
        
        if (volumeButtonPressCount >= 2) {
            if (doubleTapTimer) {
                [doubleTapTimer invalidate];
            }
            
            dispatch_async(dispatch_get_main_queue(), ^{
                handleVolumeDoubleTap();
            });
            
            resetVolumeButtonState();
            return;
        }
    } else {
        volumeButtonPressCount = 1;
    }
    
    lastVolumeButtonPress = currentTime;
    
    if (doubleTapTimer) {
        [doubleTapTimer invalidate];
    }
    
    doubleTapTimer = [NSTimer scheduledTimerWithTimeInterval:0.5
                                                      target:[NSBlockOperation blockOperationWithBlock:^{
                                                          resetVolumeButtonState();
                                                      }]
                                                    selector:@selector(main)
                                                    userInfo:nil
                                                     repeats:NO];
}

%end

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

%hook SpringBoard

- (void)_handleVolumeButtonDown:(id)down {
    %orig;
    
    NSTimeInterval currentTime = [[NSDate date] timeIntervalSince1970];
    
    if (currentTime - lastVolumeButtonPress < 0.5) {
        volumeButtonPressCount++;
        
        if (volumeButtonPressCount >= 2) {
            dispatch_async(dispatch_get_main_queue(), ^{
                handleVolumeDoubleTap();
            });
            
            resetVolumeButtonState();
            return;
        }
    } else {
        volumeButtonPressCount = 1;
    }
    
    lastVolumeButtonPress = currentTime;
    
    if (doubleTapTimer) {
        [doubleTapTimer invalidate];
    }
    
    doubleTapTimer = [NSTimer scheduledTimerWithTimeInterval:0.5
                                                      target:[NSBlockOperation blockOperationWithBlock:^{
                                                          resetVolumeButtonState();
                                                      }]
                                                    selector:@selector(main)
                                                    userInfo:nil
                                                     repeats:NO];
}

%end

%ctor {
    NSLog(@"[CustomVCAM] Tweak loaded successfully");
    
    mediaManager = [[MediaManager alloc] init];
    vcamDelegate = [[CustomVCAMDelegate alloc] init];
    vcamEnabled = YES;
    
    NSLog(@"[CustomVCAM] Media manager initialized, VCAM enabled for Stripe bypass");
} 