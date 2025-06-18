#import <UIKit/UIKit.h>
#import <AVFoundation/AVFoundation.h>
#import <substrate.h>
#import "Sources/MediaManager.h"
#import "Sources/OverlayView.h"

static BOOL vcamEnabled = NO;
static NSDate *lastVolumePress = nil;
static int volumePressCount = 0;
static NSTimer *volumeResetTimer = nil;

@interface SBVolumeControl : NSObject
- (void)increaseVolume;
- (void)decreaseVolume;
- (BOOL)handleVolumePress;
- (void)resetVolumeCount;
@end

@interface AVCaptureVideoDataOutput (CustomVCAM)
@property (nonatomic, weak) id<AVCaptureVideoDataOutputSampleBufferDelegate> sampleBufferDelegate;
@end

%hook AVCaptureVideoDataOutput

- (void)captureOutput:(AVCaptureOutput *)output didOutputSampleBuffer:(CMSampleBufferRef)sampleBuffer fromConnection:(AVCaptureConnection *)connection {
    
    if (!vcamEnabled) {
        %orig;
        return;
    }
    
    MediaManager *mediaManager = [MediaManager sharedInstance];
    if (!mediaManager.selectedImage && !mediaManager.selectedVideoURL) {
        %orig;
        return;
    }
    
    CMTime presentationTime = CMSampleBufferGetPresentationTimeStamp(sampleBuffer);
    CMSampleBufferRef customBuffer = [mediaManager createSampleBufferFromCurrentMedia:presentationTime];
    
    if (customBuffer) {
        if ([self.sampleBufferDelegate respondsToSelector:@selector(captureOutput:didOutputSampleBuffer:fromConnection:)]) {
            [self.sampleBufferDelegate captureOutput:output didOutputSampleBuffer:customBuffer fromConnection:connection];
        }
        CFRelease(customBuffer);
    } else {
        %orig;
    }
}

%end

%hook SBVolumeControl

- (void)increaseVolume {
    if ([self handleVolumePress]) {
        return;
    }
    %orig;
}

- (void)decreaseVolume {
    if ([self handleVolumePress]) {
        return;
    }
    %orig;
}

%new
- (BOOL)handleVolumePress {
    NSDate *now = [NSDate date];
    
    if (!lastVolumePress || [now timeIntervalSinceDate:lastVolumePress] > 0.5) {
        volumePressCount = 1;
    } else {
        volumePressCount++;
    }
    
    lastVolumePress = now;
    
    if (volumeResetTimer) {
        [volumeResetTimer invalidate];
    }
    
    volumeResetTimer = [NSTimer scheduledTimerWithTimeInterval:0.6 
                                                        target:self 
                                                      selector:@selector(resetVolumeCount) 
                                                      userInfo:nil 
                                                       repeats:NO];
    
    if (volumePressCount >= 2) {
        [[OverlayView sharedInstance] showOverlay];
        volumePressCount = 0;
        [volumeResetTimer invalidate];
        volumeResetTimer = nil;
        return YES;
    }
    
    return NO;
}

%new
- (void)resetVolumeCount {
    volumePressCount = 0;
    volumeResetTimer = nil;
}

%end

%hook AVCaptureDevice

+ (NSArray<AVCaptureDevice *> *)devicesWithMediaType:(AVMediaType)mediaType {
    NSArray *originalDevices = %orig;
    
    if (!vcamEnabled || ![mediaType isEqualToString:AVMediaTypeVideo]) {
        return originalDevices;
    }
    
    MediaManager *mediaManager = [MediaManager sharedInstance];
    if (!mediaManager.selectedImage && !mediaManager.selectedVideoURL) {
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
    
    MediaManager *mediaManager = [MediaManager sharedInstance];
    if (!mediaManager.selectedImage && !mediaManager.selectedVideoURL) {
        %orig;
        return;
    }
    
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        CMSampleBufferRef customBuffer = [mediaManager createSampleBufferFromCurrentMedia:CMTimeMakeWithSeconds([[NSDate date] timeIntervalSince1970], 1000000)];
        
        dispatch_async(dispatch_get_main_queue(), ^{
            if (customBuffer && [delegate respondsToSelector:@selector(captureOutput:didFinishProcessingPhoto:error:)]) {
                AVCapturePhoto *photo = [[AVCapturePhoto alloc] init];
                [delegate captureOutput:self didFinishProcessingPhoto:photo error:nil];
                CFRelease(customBuffer);
            }
        });
    });
}

%end

%hook UIImagePickerController

- (void)_startVideoCapture {
    if (!vcamEnabled) {
        %orig;
        return;
    }
    
    MediaManager *mediaManager = [MediaManager sharedInstance];
    if (!mediaManager.selectedImage && !mediaManager.selectedVideoURL) {
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
    
    MediaManager *mediaManager = [MediaManager sharedInstance];
    if (!mediaManager.selectedImage && !mediaManager.selectedVideoURL) {
        %orig;
        return;
    }
    
    NSLog(@"[CustomVCAM] UIImagePickerController photo capture intercepted");
}

%end

static void handleVCAMToggle(CFNotificationCenterRef center, void *observer, CFStringRef name, const void *object, CFDictionaryRef userInfo) {
    NSDictionary *info = (__bridge NSDictionary *)userInfo;
    NSNumber *enabled = info[@"enabled"];
    if (enabled) {
        vcamEnabled = [enabled boolValue];
        NSLog(@"[CustomVCAM] VCAM %@", vcamEnabled ? @"Enabled" : @"Disabled");
    }
}

%ctor {
    %init;
    
    NSLog(@"[CustomVCAM] Loaded for bundle: %@", [[NSBundle mainBundle] bundleIdentifier]);
    
    [[NSNotificationCenter defaultCenter] addObserverForName:@"VCAMToggled" 
                                                      object:nil 
                                                       queue:[NSOperationQueue mainQueue] 
                                                  usingBlock:^(NSNotification *note) {
        NSNumber *enabled = note.userInfo[@"enabled"];
        if (enabled) {
            vcamEnabled = [enabled boolValue];
            NSLog(@"[CustomVCAM] VCAM %@", vcamEnabled ? @"Enabled" : @"Disabled");
        }
    }];
    
    NSString *bundleID = [[NSBundle mainBundle] bundleIdentifier];
    
    if ([bundleID isEqualToString:@"com.apple.springboard"]) {
        [OverlayView sharedInstance];
        NSLog(@"[CustomVCAM] SpringBoard overlay initialized");
    }
    
    if ([bundleID isEqualToString:@"com.apple.camera"] ||
        [bundleID isEqualToString:@"com.apple.mobilesafari"] ||
        [bundleID isEqualToString:@"com.burbn.instagram"] ||
        [bundleID isEqualToString:@"com.facebook.Facebook"] ||
        [bundleID isEqualToString:@"com.snapchat.snapchat"] ||
        [bundleID isEqualToString:@"com.whatsapp.WhatsApp"] ||
        [bundleID isEqualToString:@"com.skype.skype"]) {
        
        [MediaManager sharedInstance];
        NSLog(@"[CustomVCAM] Camera hooks active for %@", bundleID);
    }
} 