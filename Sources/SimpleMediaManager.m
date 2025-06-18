#import "SimpleMediaManager.h"

@implementation SimpleMediaManager

+ (CMSampleBufferRef)createSampleBufferFromPixelBuffer:(CVPixelBufferRef)pixelBuffer withTimestamp:(CMTime)timestamp {
    if (!pixelBuffer) return NULL;
    
    CMVideoFormatDescriptionRef formatDescription = NULL;
    OSStatus status = CMVideoFormatDescriptionCreateForImageBuffer(kCFAllocatorDefault, pixelBuffer, &formatDescription);
    
    if (status != noErr) {
        [self logDebug:[NSString stringWithFormat:@"Failed to create format description: %d", (int)status]];
        return NULL;
    }
    
    CMSampleTimingInfo timingInfo;
    timingInfo.duration = CMTimeMake(1, 30);
    timingInfo.presentationTimeStamp = timestamp;
    timingInfo.decodeTimeStamp = kCMTimeInvalid;
    
    CMSampleBufferRef sampleBuffer = NULL;
    status = CMSampleBufferCreateReadyWithImageBuffer(kCFAllocatorDefault,
                                                     pixelBuffer,
                                                     formatDescription,
                                                     &timingInfo,
                                                     &sampleBuffer);
    
    CFRelease(formatDescription);
    
    if (status != noErr) {
        [self logDebug:[NSString stringWithFormat:@"Failed to create sample buffer: %d", (int)status]];
        return NULL;
    }
    
    return sampleBuffer;
}

+ (void)logDebug:(NSString *)message {
    NSLog(@"[CustomVCAM][SimpleMediaManager] %@", message);
}

@end 