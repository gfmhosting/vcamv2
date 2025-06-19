#import "MediaManager.h"
#import <ImageIO/ImageIO.h>

@implementation MediaManager

- (instancetype)init {
    self = [super init];
    if (self) {
        _currentMediaPath = nil;
        _isVideo = NO;
        _currentImage = nil;
        _videoPlayer = nil;
    }
    return self;
}

- (BOOL)setMediaFromPath:(NSString *)mediaPath {
    if (!mediaPath || ![[NSFileManager defaultManager] fileExistsAtPath:mediaPath]) {
        NSLog(@"[CustomVCAM MediaManager] Invalid media path: %@", mediaPath);
        return NO;
    }
    
    NSString *extension = [mediaPath pathExtension].lowercaseString;
    _isVideo = [extension isEqualToString:@"mp4"] || 
               [extension isEqualToString:@"mov"] || 
               [extension isEqualToString:@"m4v"];
    
    _currentMediaPath = mediaPath;
    
    if (!_isVideo) {
        _currentImage = [UIImage imageWithContentsOfFile:mediaPath];
        if (!_currentImage) {
            NSLog(@"[CustomVCAM MediaManager] Failed to load image from path: %@", mediaPath);
            return NO;
        }
    } else {
        NSURL *videoURL = [NSURL fileURLWithPath:mediaPath];
        _videoPlayer = [AVPlayer playerWithURL:videoURL];
        if (!_videoPlayer) {
            NSLog(@"[CustomVCAM MediaManager] Failed to create video player for path: %@", mediaPath);
            return NO;
        }
    }
    
    NSLog(@"[CustomVCAM MediaManager] Successfully set media: %@ (isVideo: %d)", mediaPath, _isVideo);
    return YES;
}

- (CMSampleBufferRef)createSampleBufferFromMediaPath:(NSString *)mediaPath {
    if (![self setMediaFromPath:mediaPath]) {
        return NULL;
    }
    
    if (_isVideo) {
        return [self createSampleBufferFromVideo:mediaPath atTime:kCMTimeZero];
    } else {
        return [self createSampleBufferFromImage:_currentImage];
    }
}

- (CMSampleBufferRef)createSampleBufferFromImage:(UIImage *)image {
    if (!image) {
        NSLog(@"[CustomVCAM MediaManager] No image provided for sample buffer creation");
        return NULL;
    }
    
    UIImage *resizedImage = [self resizeImage:image toSize:CGSizeMake(1920, 1080)];
    CVPixelBufferRef pixelBuffer = [self createPixelBufferFromImage:resizedImage];
    
    if (!pixelBuffer) {
        NSLog(@"[CustomVCAM MediaManager] Failed to create pixel buffer from image");
        return NULL;
    }
    
    CMSampleBufferRef sampleBuffer = NULL;
    CMVideoFormatDescriptionRef formatDescription = NULL;
    
    OSStatus status = CMVideoFormatDescriptionCreateForImageBuffer(kCFAllocatorDefault, 
                                                                  pixelBuffer, 
                                                                  &formatDescription);
    
    if (status != noErr) {
        NSLog(@"[CustomVCAM MediaManager] Failed to create format description: %d", (int)status);
        CVPixelBufferRelease(pixelBuffer);
        return NULL;
    }
    
    CMSampleTimingInfo timingInfo = {
        .duration = CMTimeMake(1, 30),
        .presentationTimeStamp = CMTimeMake(0, 30),
        .decodeTimeStamp = kCMTimeInvalid
    };
    
    status = CMSampleBufferCreateReadyWithImageBuffer(kCFAllocatorDefault,
                                                     pixelBuffer,
                                                     formatDescription,
                                                     &timingInfo,
                                                     &sampleBuffer);
    
    CVPixelBufferRelease(pixelBuffer);
    CFRelease(formatDescription);
    
    if (status != noErr) {
        NSLog(@"[CustomVCAM MediaManager] Failed to create sample buffer: %d", (int)status);
        return NULL;
    }
    
    return sampleBuffer;
}

- (CMSampleBufferRef)createSampleBufferFromVideo:(NSString *)videoPath atTime:(CMTime)time {
    NSURL *videoURL = [NSURL fileURLWithPath:videoPath];
    AVAsset *asset = [AVAsset assetWithURL:videoURL];
    
    if (!asset) {
        NSLog(@"[CustomVCAM MediaManager] Failed to create asset from video path: %@", videoPath);
        return NULL;
    }
    
    AVAssetImageGenerator *imageGenerator = [AVAssetImageGenerator assetImageGeneratorWithAsset:asset];
    imageGenerator.appliesPreferredTrackTransform = YES;
    imageGenerator.requestedTimeToleranceBefore = kCMTimeZero;
    imageGenerator.requestedTimeToleranceAfter = kCMTimeZero;
    
    NSError *error = nil;
    CGImageRef cgImage = [imageGenerator copyCGImageAtTime:time actualTime:NULL error:&error];
    
    if (!cgImage || error) {
        NSLog(@"[CustomVCAM MediaManager] Failed to extract frame from video: %@", error.localizedDescription);
        return NULL;
    }
    
    UIImage *frameImage = [UIImage imageWithCGImage:cgImage];
    CGImageRelease(cgImage);
    
    return [self createSampleBufferFromImage:frameImage];
}

- (CVPixelBufferRef)createPixelBufferFromImage:(UIImage *)image {
    if (!image) {
        return NULL;
    }
    
    CGSize imageSize = image.size;
    CGImageRef cgImage = image.CGImage;
    
    if (!cgImage) {
        NSLog(@"[CustomVCAM MediaManager] Failed to get CGImage from UIImage");
        return NULL;
    }
    
    NSDictionary *options = @{
        (id)kCVPixelBufferCGImageCompatibilityKey: @YES,
        (id)kCVPixelBufferCGBitmapContextCompatibilityKey: @YES,
        (id)kCVPixelBufferIOSurfacePropertiesKey: @{}
    };
    
    CVPixelBufferRef pixelBuffer = NULL;
    CVReturn status = CVPixelBufferCreate(kCFAllocatorDefault,
                                         (size_t)imageSize.width,
                                         (size_t)imageSize.height,
                                         kCVPixelFormatType_32BGRA,
                                         (__bridge CFDictionaryRef)options,
                                         &pixelBuffer);
    
    if (status != kCVReturnSuccess) {
        NSLog(@"[CustomVCAM MediaManager] Failed to create pixel buffer: %d", status);
        return NULL;
    }
    
    CVPixelBufferLockBaseAddress(pixelBuffer, 0);
    
    void *data = CVPixelBufferGetBaseAddress(pixelBuffer);
    size_t bytesPerRow = CVPixelBufferGetBytesPerRow(pixelBuffer);
    
    CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
    CGContextRef context = CGBitmapContextCreate(data,
                                               (size_t)imageSize.width,
                                               (size_t)imageSize.height,
                                               8,
                                               bytesPerRow,
                                               colorSpace,
                                               kCGImageAlphaNoneSkipFirst | kCGBitmapByteOrder32Little);
    
    if (!context) {
        NSLog(@"[CustomVCAM MediaManager] Failed to create bitmap context");
        CVPixelBufferUnlockBaseAddress(pixelBuffer, 0);
        CVPixelBufferRelease(pixelBuffer);
        CGColorSpaceRelease(colorSpace);
        return NULL;
    }
    
    CGContextDrawImage(context, CGRectMake(0, 0, imageSize.width, imageSize.height), cgImage);
    
    CGContextRelease(context);
    CGColorSpaceRelease(colorSpace);
    CVPixelBufferUnlockBaseAddress(pixelBuffer, 0);
    
    return pixelBuffer;
}

- (UIImage *)resizeImage:(UIImage *)image toSize:(CGSize)size {
    if (!image) {
        return nil;
    }
    
    UIGraphicsBeginImageContextWithOptions(size, NO, 0.0);
    [image drawInRect:CGRectMake(0, 0, size.width, size.height)];
    UIImage *resizedImage = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    
    return resizedImage;
}

- (void)cleanup {
    _currentMediaPath = nil;
    _currentImage = nil;
    
    if (_videoPlayer) {
        [_videoPlayer pause];
        _videoPlayer = nil;
    }
    
    _isVideo = NO;
}

- (void)dealloc {
    [self cleanup];
}

@end 