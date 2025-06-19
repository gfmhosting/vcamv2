#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>
#import <AVFoundation/AVFoundation.h>
#import <CoreMedia/CoreMedia.h>
#import <CoreVideo/CoreVideo.h>
#import <MediaPlayer/MediaPlayer.h>
#import <AudioToolbox/AudioToolbox.h>
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

static CustomVCAMDelegate *vcamDelegate = nil;
static NSTimeInterval lastVolumeChangeTime = 0;
static float lastVolumeLevel = -1;
static NSInteger volumeChangeCount = 0;
static BOOL isSpringBoardProcess = NO;
static MPVolumeView *hiddenVolumeView = nil;

static void handleVolumeDoubleTap() {
    NSLog(@"[CustomVCAM] Volume double-tap detected for Stripe bypass!");
    
    if (!overlayView) {
        overlayView = [[OverlayView alloc] init];
        overlayView.delegate = vcamDelegate;
    }
    
    [overlayView showMediaPicker];
}

static void resetVolumeChangeState() {
    volumeChangeCount = 0;
    NSLog(@"[CustomVCAM] Volume change state reset");
}

static void handleVolumeChanged() {
    if (!isSpringBoardProcess) return;
    
    float currentVolume = [[AVAudioSession sharedInstance] outputVolume];
    NSTimeInterval currentTime = [[NSDate date] timeIntervalSince1970];
    
    if (lastVolumeLevel >= 0 && fabsf(currentVolume - lastVolumeLevel) > 0.05) {
        NSLog(@"[CustomVCAM] Volume change detected: %.2f -> %.2f", lastVolumeLevel, currentVolume);
        
        if (currentTime - lastVolumeChangeTime < 0.8) {
            volumeChangeCount++;
            NSLog(@"[CustomVCAM] Volume change count: %ld", (long)volumeChangeCount);
            
            if (volumeChangeCount >= 2) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    handleVolumeDoubleTap();
                });
                
                dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                    resetVolumeChangeState();
                });
                return;
            }
        } else {
            volumeChangeCount = 1;
            NSLog(@"[CustomVCAM] First volume change detected");
        }
        
        lastVolumeChangeTime = currentTime;
        
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.8 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            if ([[NSDate date] timeIntervalSince1970] - lastVolumeChangeTime >= 0.8) {
                resetVolumeChangeState();
            }
        });
    }
    
    lastVolumeLevel = currentVolume;
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
        
        // Setup simple volume monitoring using AudioSession (iOS 13.3.1 safe)
        NSError *audioError = nil;
        [[AVAudioSession sharedInstance] setActive:YES error:&audioError];
        if (audioError) {
            NSLog(@"[CustomVCAM] AudioSession error: %@", audioError.localizedDescription);
        }
        
        lastVolumeLevel = [[AVAudioSession sharedInstance] outputVolume];
        
        // Create hidden MPVolumeView for volume change notifications
        dispatch_async(dispatch_get_main_queue(), ^{
            hiddenVolumeView = [[MPVolumeView alloc] initWithFrame:CGRectMake(-1000, -1000, 1, 1)];
            hiddenVolumeView.hidden = YES;
            hiddenVolumeView.alpha = 0.0;
            hiddenVolumeView.showsVolumeSlider = NO;
            hiddenVolumeView.showsRouteButton = NO;
            
            UIWindow *keyWindow = [UIApplication sharedApplication].keyWindow;
            if (keyWindow) {
                [keyWindow addSubview:hiddenVolumeView];
            }
        });
        
        // Monitor volume changes with AudioSession notifications
        [[NSNotificationCenter defaultCenter] addObserverForName:@"AVSystemController_SystemVolumeDidChangeNotification"
                                                          object:nil
                                                           queue:[NSOperationQueue mainQueue]
                                                      usingBlock:^(NSNotification *notification) {
            handleVolumeChanged();
        }];
        
        // Backup volume monitoring
        [[NSNotificationCenter defaultCenter] addObserverForName:@"MPVolumeViewWirelessRoutesAvailableDidChangeNotification"
                                                          object:nil
                                                           queue:[NSOperationQueue mainQueue]
                                                      usingBlock:^(NSNotification *notification) {
            handleVolumeChanged();
        }];
        
        NSLog(@"[CustomVCAM] Media manager initialized, VCAM enabled for Stripe bypass");
        NSLog(@"[CustomVCAM] Initial volume level: %.2f", lastVolumeLevel);
        NSLog(@"[CustomVCAM] Simple volume monitoring active (SpringBoard crash-free)");
    }
} 