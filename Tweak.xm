#import <UIKit/UIKit.h>
#import <AVFoundation/AVFoundation.h>
#import <CoreMedia/CoreMedia.h>
#import <substrate.h>
#import "VCAMOverlay.h"
#import "MediaProcessor.h"
#import "VolumeHook.h"

@interface SpringBoard : UIApplication
@end

@interface AVCaptureSession (Private)
- (BOOL)isWebViewContext;
@end

@interface WKWebView : UIView
@end

static BOOL isStripeKYCActive = NO;
static NSString *currentProcessName = nil;

%hook AVCaptureSession

- (void)startRunning {
    NSString *bundleID = [[NSBundle mainBundle] bundleIdentifier];
    BOOL isWebContext = [bundleID containsString:@"safari"] || 
                       [bundleID containsString:@"webkit"] ||
                       [self isWebViewContext];
    
    if (isWebContext) {
        [[MediaProcessor sharedInstance] enableReplacement];
        [[DebugOverlay shared] log:@"AVCaptureSession started - VCAM enabled for web context"];
        isStripeKYCActive = YES;
    }
    
    %orig;
}

- (void)stopRunning {
    if (isStripeKYCActive) {
        [[MediaProcessor sharedInstance] disableReplacement];
        [[DebugOverlay shared] log:@"AVCaptureSession stopped - VCAM disabled"];
        isStripeKYCActive = NO;
    }
    %orig;
}

- (BOOL)isWebViewContext {
    UIViewController *topVC = [UIApplication sharedApplication].keyWindow.rootViewController;
    while (topVC.presentedViewController) {
        topVC = topVC.presentedViewController;
    }
    
    for (UIView *subview in topVC.view.subviews) {
        if ([subview isKindOfClass:%c(WKWebView)]) {
            return YES;
        }
    }
    return NO;
}

%end

%hook AVCaptureVideoDataOutput

- (void)setSampleBufferDelegate:(id<AVCaptureVideoDataOutputSampleBufferDelegate>)sampleBufferDelegate queue:(dispatch_queue_t)sampleBufferCallbackQueue {
    if (isStripeKYCActive && [[MediaProcessor sharedInstance] isReplacementEnabled]) {
        %orig([MediaProcessor sharedInstance], sampleBufferCallbackQueue);
        [[DebugOverlay shared] log:@"Sample buffer delegate intercepted"];
    } else {
        %orig(sampleBufferDelegate, sampleBufferCallbackQueue);
    }
}

%end

%hook SpringBoard

- (void)volumeChanged:(id)arg1 {
    if ([[VolumeHook sharedInstance] handleVolumeEvent]) {
        [[DebugOverlay shared] log:@"Volume button double-tap detected"];
        [[VCAMOverlay sharedInstance] toggleOverlay];
        return;
    }
    %orig;
}

%end

%ctor {
    currentProcessName = [[NSProcessInfo processInfo] processName];
    [[DebugOverlay shared] log:[NSString stringWithFormat:@"StripeVCAM loaded in process: %@", currentProcessName]];
} 