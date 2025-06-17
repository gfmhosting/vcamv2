#import "MediaProcessor.h"
#import "VCAMOverlay.h"

@implementation MediaProcessor

+ (instancetype)sharedInstance {
    static MediaProcessor *instance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[self alloc] init];
    });
    return instance;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        _replacementEnabled = NO;
        _cachedPixelBuffer = NULL;
    }
    return self;
}

- (void)dealloc {
    if (_cachedPixelBuffer) {
        CVPixelBufferRelease(_cachedPixelBuffer);
    }
}

- (void)setSelectedMedia:(UIImage *)image {
    _selectedImage = image;
    
    if (_cachedPixelBuffer) {
        CVPixelBufferRelease(_cachedPixelBuffer);
        _cachedPixelBuffer = NULL;
    }
    
    if (image) {
        _cachedPixelBuffer = [self processSelectedMedia:image];
        [[DebugOverlay shared] log:[NSString stringWithFormat:@"Media processed: %dx%d", 
                                   (int)image.size.width, (int)image.size.height]];
    }
}

- (void)enableReplacement {
    _replacementEnabled = YES;
    [[DebugOverlay shared] log:@"Media replacement enabled"];
}

- (void)disableReplacement {
    _replacementEnabled = NO;
    [[DebugOverlay shared] log:@"Media replacement disabled"];
}

- (BOOL)isReplacementEnabled {
    return _replacementEnabled;
}

- (CVPixelBufferRef)processSelectedMedia:(UIImage *)image {
    if (!image) return NULL;
    
    CGSize imageSize = image.size;
    CGSize targetSize = CGSizeMake(640, 480); // Standard camera resolution
    
    // Scale image to target size
    UIGraphicsBeginImageContext(targetSize);
    [image drawInRect:CGRectMake(0, 0, targetSize.width, targetSize.height)];
    UIImage *scaledImage = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    
    // Convert to CVPixelBuffer
    CVPixelBufferRef pixelBuffer = NULL;
    NSDictionary *options = @{
        (NSString*)kCVPixelBufferCGImageCompatibilityKey: @YES,
        (NSString*)kCVPixelBufferCGBitmapContextCompatibilityKey: @YES
    };
    
    CVReturn status = CVPixelBufferCreate(kCFAllocatorDefault,
                                         targetSize.width,
                                         targetSize.height,
                                         kCVPixelFormatType_32BGRA,
                                         (__bridge CFDictionaryRef)options,
                                         &pixelBuffer);
    
    if (status != kCVReturnSuccess) {
        [[DebugOverlay shared] log:@"Failed to create pixel buffer"];
        return NULL;
    }
    
    CVPixelBufferLockBaseAddress(pixelBuffer, 0);
    void *data = CVPixelBufferGetBaseAddress(pixelBuffer);
    
    CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
    CGContextRef context = CGBitmapContextCreate(data,
                                               targetSize.width,
                                               targetSize.height,
                                               8,
                                               CVPixelBufferGetBytesPerRow(pixelBuffer),
                                               colorSpace,
                                               kCGImageAlphaPreferredSkipFirst);
    
    CGContextDrawImage(context, CGRectMake(0, 0, targetSize.width, targetSize.height), scaledImage.CGImage);
    
    CGContextRelease(context);
    CGColorSpaceRelease(colorSpace);
    CVPixelBufferUnlockBaseAddress(pixelBuffer, 0);
    
    return pixelBuffer;
}

- (CVPixelBufferRef)getCurrentFrame {
    return _cachedPixelBuffer;
}

#pragma mark - AVCaptureVideoDataOutputSampleBufferDelegate

- (void)captureOutput:(AVCaptureOutput *)output 
didOutputSampleBuffer:(CMSampleBufferRef)sampleBuffer 
       fromConnection:(AVCaptureConnection *)connection {
    
    if (!_replacementEnabled || !_cachedPixelBuffer) {
        return;
    }
    
    // Replace the original sample buffer with our cached pixel buffer
    CVImageBufferRef imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer);
    if (imageBuffer) {
        CVPixelBufferLockBaseAddress(imageBuffer, 0);
        CVPixelBufferLockBaseAddress(_cachedPixelBuffer, 0);
        
        void *originalData = CVPixelBufferGetBaseAddress(imageBuffer);
        void *replacementData = CVPixelBufferGetBaseAddress(_cachedPixelBuffer);
        
        size_t originalBytesPerRow = CVPixelBufferGetBytesPerRow(imageBuffer);
        size_t replacementBytesPerRow = CVPixelBufferGetBytesPerRow(_cachedPixelBuffer);
        size_t originalHeight = CVPixelBufferGetHeight(imageBuffer);
        size_t replacementHeight = CVPixelBufferGetHeight(_cachedPixelBuffer);
        
        // Copy replacement data to original buffer
        size_t minBytesPerRow = MIN(originalBytesPerRow, replacementBytesPerRow);
        size_t minHeight = MIN(originalHeight, replacementHeight);
        
        for (size_t row = 0; row < minHeight; row++) {
            memcpy((char*)originalData + row * originalBytesPerRow,
                   (char*)replacementData + row * replacementBytesPerRow,
                   minBytesPerRow);
        }
        
        CVPixelBufferUnlockBaseAddress(_cachedPixelBuffer, 0);
        CVPixelBufferUnlockBaseAddress(imageBuffer, 0);
        
        static int frameCount = 0;
        frameCount++;
        if (frameCount % 30 == 0) { // Log every 30 frames (~1 second at 30fps)
            [[DebugOverlay shared] log:[NSString stringWithFormat:@"Frame replaced: %d", frameCount]];
        }
    }
}

@end 