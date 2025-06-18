#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <AVFoundation/AVFoundation.h>
#import <SpringBoard/SpringBoard.h>
#import <CoreMedia/CoreMedia.h>
#import <WebKit/WebKit.h>
#import "Sources/MediaManager.h"
#import "Sources/OverlayView.h"
#import "Sources/SimpleMediaManager.h"

static BOOL volumeButtonPressed = NO;
static NSTimeInterval lastVolumeButtonTime = 0;
static const NSTimeInterval DOUBLE_TAP_INTERVAL = 0.5;

%hook SBVolumeHardwareButtonActions

- (void)volumeIncreasePress:(id)arg1 {
    NSTimeInterval currentTime = [[NSDate date] timeIntervalSince1970];
    
    if (currentTime - lastVolumeButtonTime < DOUBLE_TAP_INTERVAL) {
        [[MediaManager sharedManager] logDebug:@"Volume UP double tap detected"];
        [[OverlayView sharedOverlay] showOverlay];
        return;
    }
    
    lastVolumeButtonTime = currentTime;
    %orig;
}

- (void)volumeDecreasePress:(id)arg1 {
    NSTimeInterval currentTime = [[NSDate date] timeIntervalSince1970];
    
    if (currentTime - lastVolumeButtonTime < DOUBLE_TAP_INTERVAL) {
        [[MediaManager sharedManager] logDebug:@"Volume DOWN double tap detected"];
        [[OverlayView sharedOverlay] showOverlay];
        return;
    }
    
    lastVolumeButtonTime = currentTime;
    %orig;
}

%end

%hook AVCaptureVideoDataOutput

- (void)captureOutput:(AVCaptureOutput *)output didOutputSampleBuffer:(CMSampleBufferRef)sampleBuffer fromConnection:(AVCaptureConnection *)connection {
    if ([[MediaManager sharedManager] vcamEnabled]) {
        [[MediaManager sharedManager] logDebug:@"Intercepting camera output"];
        
        CMTime currentTime = CMSampleBufferGetPresentationTimeStamp(sampleBuffer);
        CVPixelBufferRef customPixelBuffer = [[MediaManager sharedManager] getCurrentFrameForTime:currentTime];
        
        if (customPixelBuffer) {
            CMSampleBufferRef customSampleBuffer = [SimpleMediaManager createSampleBufferFromPixelBuffer:customPixelBuffer withTimestamp:currentTime];
            
            if (customSampleBuffer) {
                %orig(output, customSampleBuffer, connection);
                CFRelease(customSampleBuffer);
                CVPixelBufferRelease(customPixelBuffer);
                return;
            }
            CVPixelBufferRelease(customPixelBuffer);
        }
    }
    
    %orig;
}

%end

%hook AVCaptureDevice

+ (NSArray<AVCaptureDevice *> *)devicesWithMediaType:(AVMediaType)mediaType {
    NSArray *originalDevices = %orig;
    
    if ([[MediaManager sharedManager] vcamEnabled] && [mediaType isEqualToString:AVMediaTypeVideo]) {
        [[MediaManager sharedManager] logDebug:@"Camera device enumeration intercepted"];
    }
    
    return originalDevices;
}

- (BOOL)lockForConfiguration:(NSError **)error {
    BOOL result = %orig;
    
    if ([[MediaManager sharedManager] vcamEnabled]) {
        [[MediaManager sharedManager] logDebug:@"Camera device lock for configuration intercepted"];
    }
    
    return result;
}

%end

%hook AVCaptureSession

- (void)startRunning {
    if ([[MediaManager sharedManager] vcamEnabled]) {
        [[MediaManager sharedManager] logDebug:@"AVCaptureSession startRunning intercepted"];
    }
    %orig;
}

- (void)stopRunning {
    if ([[MediaManager sharedManager] vcamEnabled]) {
        [[MediaManager sharedManager] logDebug:@"AVCaptureSession stopRunning intercepted"];
    }
    %orig;
}

%end

%hook WKWebView

- (void)_requestUserMediaAuthorizationForDevices:(unsigned long long)devices url:(NSURL *)url mainFrameURL:(NSURL *)mainFrameURL decisionHandler:(void (^)(BOOL))decisionHandler {
    if ([[MediaManager sharedManager] vcamEnabled]) {
        [[MediaManager sharedManager] logDebug:@"WebKit camera authorization intercepted"];
    }
    %orig;
}

%end

@interface RTCCameraVideoCapturer : NSObject
@end

%hook RTCCameraVideoCapturer

- (void)startCaptureWithDevice:(id)device format:(id)format fps:(int)fps completionHandler:(void (^)(NSError *))completionHandler {
    if ([[MediaManager sharedManager] vcamEnabled]) {
        [[MediaManager sharedManager] logDebug:@"WebRTC camera capture start intercepted"];
    }
    %orig;
}

- (void)captureOutput:(id)output didOutputSampleBuffer:(CMSampleBufferRef)sampleBuffer fromConnection:(id)connection {
    if ([[MediaManager sharedManager] vcamEnabled]) {
        [[MediaManager sharedManager] logDebug:@"WebRTC camera output intercepted"];
        
        CMTime currentTime = CMSampleBufferGetPresentationTimeStamp(sampleBuffer);
        CVPixelBufferRef customPixelBuffer = [[MediaManager sharedManager] getCurrentFrameForTime:currentTime];
        
        if (customPixelBuffer) {
            CMSampleBufferRef customSampleBuffer = [SimpleMediaManager createSampleBufferFromPixelBuffer:customPixelBuffer withTimestamp:currentTime];
            
            if (customSampleBuffer) {
                %orig(output, customSampleBuffer, connection);
                CFRelease(customSampleBuffer);
                CVPixelBufferRelease(customPixelBuffer);
                return;
            }
            CVPixelBufferRelease(customPixelBuffer);
        }
    }
    
    %orig;
}

%end

%ctor {
    NSLog(@"[CustomVCAM] Tweak loaded successfully");
    
    dispatch_async(dispatch_get_main_queue(), ^{
        [[MediaManager sharedManager] logDebug:@"Initializing managers"];
        [OverlayView sharedOverlay];
    });
} 