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

// KVO-based volume observer (iOS 13.3.1 proven method)
static id volumeObserver = nil;
static AVAudioSession *audioSession = nil;

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

static void handleVolumeChanged(float newVolume) {
    if (!isSpringBoardProcess) return;
    
    NSTimeInterval currentTime = [[NSDate date] timeIntervalSince1970];
    
    if (lastVolumeLevel >= 0 && fabsf(newVolume - lastVolumeLevel) > 0.05) {
        NSLog(@"[CustomVCAM] KVO Volume change detected: %.2f -> %.2f", lastVolumeLevel, newVolume);
        
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
            NSLog(@"[CustomVCAM] First volume change detected via KVO");
        }
        
        lastVolumeChangeTime = currentTime;
        
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.8 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            if ([[NSDate date] timeIntervalSince1970] - lastVolumeChangeTime >= 0.8) {
                resetVolumeChangeState();
            }
        });
    }
    
    lastVolumeLevel = newVolume;
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
        
        // Setup KVO-based volume monitoring (proven iOS 13.3.1 method)
        audioSession = [AVAudioSession sharedInstance];
        NSError *audioError = nil;
        [audioSession setActive:YES error:&audioError];
        
        if (audioError) {
            NSLog(@"[CustomVCAM] AudioSession error: %@", audioError.localizedDescription);
        } else {
            NSLog(@"[CustomVCAM] AudioSession activated successfully");
        }
        
        lastVolumeLevel = audioSession.outputVolume;
        
        // Setup KVO observer on outputVolume (Medium article proven method)
        volumeObserver = [audioSession addObserverForKeyPath:@"outputVolume" 
                                                      options:NSKeyValueObservingOptionNew 
                                                        queue:[NSOperationQueue mainQueue] 
                                                   usingBlock:^(NSObject *object, NSDictionary *change) {
            
            float newVolume = [[change objectForKey:NSKeyValueChangeNewKey] floatValue];
            NSLog(@"[CustomVCAM] KVO outputVolume changed to: %.2f", newVolume);
            
            if (newVolume != lastVolumeLevel) {
                handleVolumeChanged(newVolume);
            }
        }];
        
        NSLog(@"[CustomVCAM] Media manager initialized, VCAM enabled for Stripe bypass");
        NSLog(@"[CustomVCAM] Initial volume level: %.2f", lastVolumeLevel);
        NSLog(@"[CustomVCAM] KVO volume monitoring active (iOS 13.3.1 proven method)");
    }
} 