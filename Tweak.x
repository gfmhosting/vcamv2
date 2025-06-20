#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>
#import <AVFoundation/AVFoundation.h>
#import <CoreMedia/CoreMedia.h>
#import <CoreVideo/CoreVideo.h>
#import <IOSurface/IOSurface.h>
#import <Photos/Photos.h>
#import <MediaPlayer/MediaPlayer.h>

// ========================================
// MARK: - Global State Management
// ========================================

@interface VCamManager : NSObject
@property (class, nonatomic, assign) BOOL isActive;
@property (class, nonatomic, strong) NSString *currentMediaPath;
@property (class, nonatomic, assign) CGSize lastRequestedSize;
+ (CVPixelBufferRef)getReplacementPixelBufferForSize:(CGSize)size;
+ (CMSampleBufferRef)createReplacementSampleBuffer:(CMSampleBufferRef)original;
+ (BOOL)shouldReplaceForDimensions:(CGSize)dimensions;
+ (BOOL)isVideoSampleBuffer:(CMSampleBufferRef)sampleBuffer;
+ (void)loadCustomMedia:(NSString *)mediaPath;
+ (UIViewController *)topViewController;
@end

@implementation VCamManager

static BOOL _isActive = NO;
static NSString *_currentMediaPath = nil;
static CGSize _lastRequestedSize = {0, 0};
static CVPixelBufferRef _cachedPixelBuffer = NULL;
static NSMutableDictionary *_pixelBufferCache = nil;

+ (void)initialize {
    if (self == [VCamManager class]) {
        _pixelBufferCache = [[NSMutableDictionary alloc] init];
        
        // Load any existing media on startup
        NSString *savedPath = @"/var/mobile/Library/Caches/vcam_current_media.path";
        if ([[NSFileManager defaultManager] fileExistsAtPath:savedPath]) {
            NSString *path = [NSString stringWithContentsOfFile:savedPath encoding:NSUTF8StringEncoding error:nil];
            if (path && [[NSFileManager defaultManager] fileExistsAtPath:path]) {
                [self loadCustomMedia:path];
                _isActive = YES;
                NSLog(@"[CustomVCAM] Restored media: %@", path);
            }
        }
    }
}

+ (BOOL)isActive { return _isActive; }
+ (void)setIsActive:(BOOL)active { 
    _isActive = active; 
    NSLog(@"[CustomVCAM] Active state changed: %@", active ? @"YES" : @"NO");
}

+ (NSString *)currentMediaPath { return _currentMediaPath; }
+ (void)setCurrentMediaPath:(NSString *)path { 
    _currentMediaPath = path;
    
    // Save current media path
    NSString *savedPath = @"/var/mobile/Library/Caches/vcam_current_media.path";
    if (path) {
        [path writeToFile:savedPath atomically:YES encoding:NSUTF8StringEncoding error:nil];
    } else {
        [[NSFileManager defaultManager] removeItemAtPath:savedPath error:nil];
    }
}

+ (CGSize)lastRequestedSize { return _lastRequestedSize; }
+ (void)setLastRequestedSize:(CGSize)size { _lastRequestedSize = size; }

+ (BOOL)shouldReplaceForDimensions:(CGSize)dimensions {
    if (!_isActive || !_currentMediaPath) return NO;
    
    // Only replace camera-like dimensions (avoid tiny thumbnails, etc.)
    if (dimensions.width < 100 || dimensions.height < 100) return NO;
    if (dimensions.width > 4096 || dimensions.height > 4096) return NO;
    
    return YES;
}

+ (BOOL)isVideoSampleBuffer:(CMSampleBufferRef)sampleBuffer {
    if (!sampleBuffer) return NO;
    
    CMFormatDescriptionRef formatDesc = CMSampleBufferGetFormatDescription(sampleBuffer);
    if (!formatDesc) return NO;
    
    CMMediaType mediaType = CMFormatDescriptionGetMediaType(formatDesc);
    return (mediaType == kCMMediaType_Video);
}

+ (CVPixelBufferRef)getReplacementPixelBufferForSize:(CGSize)size {
    if (!_isActive || !_currentMediaPath) return NULL;
    
    // Check cache first
    NSString *cacheKey = [NSString stringWithFormat:@"%.0fx%.0f", size.width, size.height];
    CVPixelBufferRef cachedBuffer = (__bridge CVPixelBufferRef)[_pixelBufferCache objectForKey:cacheKey];
    if (cachedBuffer && CVPixelBufferGetWidth(cachedBuffer) == (size_t)size.width) {
        return CVPixelBufferRetain(cachedBuffer);
    }
    
    // Load and resize media
    UIImage *image = nil;
    if ([_currentMediaPath.pathExtension.lowercaseString isEqualToString:@"mov"] || 
        [_currentMediaPath.pathExtension.lowercaseString isEqualToString:@"mp4"]) {
        // Video - get first frame
        AVAsset *asset = [AVAsset assetWithURL:[NSURL fileURLWithPath:_currentMediaPath]];
        AVAssetImageGenerator *generator = [AVAssetImageGenerator assetImageGeneratorWithAsset:asset];
        generator.appliesPreferredTrackTransform = YES;
        
        CMTime time = CMTimeMake(0, 1);
        CGImageRef cgImage = [generator copyCGImageAtTime:time actualTime:NULL error:NULL];
        if (cgImage) {
            image = [UIImage imageWithCGImage:cgImage];
            CGImageRelease(cgImage);
        }
    } else {
        // Image
        image = [UIImage imageWithContentsOfFile:_currentMediaPath];
    }
    
    if (!image) {
        NSLog(@"[CustomVCAM] Failed to load media: %@", _currentMediaPath);
        return NULL;
    }
    
    // Create pixel buffer
    CVPixelBufferRef pixelBuffer = NULL;
    NSDictionary *options = @{
        (NSString*)kCVPixelBufferCGImageCompatibilityKey: @YES,
        (NSString*)kCVPixelBufferCGBitmapContextCompatibilityKey: @YES
    };
    
    CVReturn result = CVPixelBufferCreate(kCFAllocatorDefault,
                                         (size_t)size.width,
                                         (size_t)size.height,
                                         kCVPixelFormatType_32BGRA,
                                         (__bridge CFDictionaryRef)options,
                                         &pixelBuffer);
    
    if (result != kCVReturnSuccess || !pixelBuffer) {
        NSLog(@"[CustomVCAM] Failed to create pixel buffer");
        return NULL;
    }
    
    // Draw image into pixel buffer
    CVPixelBufferLockBaseAddress(pixelBuffer, 0);
    void *baseAddress = CVPixelBufferGetBaseAddress(pixelBuffer);
    size_t bytesPerRow = CVPixelBufferGetBytesPerRow(pixelBuffer);
    
    CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
    CGContextRef context = CGBitmapContextCreate(baseAddress, size.width, size.height, 8,
                                               bytesPerRow, colorSpace,
                                               kCGBitmapByteOrder32Little | kCGImageAlphaPremultipliedFirst);
    
    if (context) {
        CGContextDrawImage(context, CGRectMake(0, 0, size.width, size.height), image.CGImage);
        CGContextRelease(context);
    }
    
    CGColorSpaceRelease(colorSpace);
    CVPixelBufferUnlockBaseAddress(pixelBuffer, 0);
    
    // Cache the result
    [_pixelBufferCache setObject:(__bridge id)pixelBuffer forKey:cacheKey];
    
    NSLog(@"[CustomVCAM] Created replacement pixel buffer: %.0fx%.0f", size.width, size.height);
    return pixelBuffer;
}

+ (CMSampleBufferRef)createReplacementSampleBuffer:(CMSampleBufferRef)original {
    if (!original || !_isActive) return NULL;
    
    CMFormatDescriptionRef formatDesc = CMSampleBufferGetFormatDescription(original);
    if (!formatDesc) return NULL;
    
    CMVideoDimensions dimensions = CMVideoFormatDescriptionGetDimensions(formatDesc);
    CGSize size = CGSizeMake(dimensions.width, dimensions.height);
    
    CVPixelBufferRef replacementPixelBuffer = [self getReplacementPixelBufferForSize:size];
    if (!replacementPixelBuffer) return NULL;
    
    // Create timing info from original
    CMSampleTimingInfo timingInfo;
    CMSampleBufferGetSampleTimingInfo(original, 0, &timingInfo);
    
    // Create format description for our pixel buffer
    CMVideoFormatDescriptionRef videoFormatDesc = NULL;
    CMVideoFormatDescriptionCreateForImageBuffer(kCFAllocatorDefault, 
                                                replacementPixelBuffer, 
                                                &videoFormatDesc);
    
    // Create sample buffer
    CMSampleBufferRef newSampleBuffer = NULL;
    CMSampleBufferCreateForImageBuffer(kCFAllocatorDefault,
                                     replacementPixelBuffer,
                                     true,
                                     NULL, NULL,
                                     videoFormatDesc,
                                     &timingInfo,
                                     &newSampleBuffer);
    
    CVPixelBufferRelease(replacementPixelBuffer);
    if (videoFormatDesc) CFRelease(videoFormatDesc);
    
    return newSampleBuffer;
}

+ (void)loadCustomMedia:(NSString *)mediaPath {
    if (!mediaPath || ![[NSFileManager defaultManager] fileExistsAtPath:mediaPath]) {
        NSLog(@"[CustomVCAM] Invalid media path: %@", mediaPath);
        return;
    }
    
    // Clear cache when loading new media
    [_pixelBufferCache removeAllObjects];
    
    [self setCurrentMediaPath:mediaPath];
    [self setIsActive:YES];
    
    NSLog(@"[CustomVCAM] Loaded custom media: %@", mediaPath);
}

+ (UIViewController *)topViewController {
    UIViewController *topController = [UIApplication sharedApplication].keyWindow.rootViewController;
    while (topController.presentedViewController) {
        topController = topController.presentedViewController;
    }
    return topController;
}

@end

// ========================================
// MARK: - Volume Button Activation
// ========================================

@interface VCamActivator : NSObject <UIImagePickerControllerDelegate, UINavigationControllerDelegate>
+ (void)handleVolumePress;
+ (void)triggerMediaPicker;
@end

@implementation VCamActivator

static NSTimeInterval lastVolumePress = 0;
static int volumePressCount = 0;

+ (void)handleVolumePress {
    NSTimeInterval now = [[NSDate date] timeIntervalSince1970];
    
    if (now - lastVolumePress < 0.8) {
        volumePressCount++;
        if (volumePressCount >= 2) {
            NSLog(@"[CustomVCAM] DOUBLE-TAP DETECTED! Triggering media picker");
            [self triggerMediaPicker];
            volumePressCount = 0;
        }
    } else {
        volumePressCount = 1;
    }
    lastVolumePress = now;
}

+ (void)triggerMediaPicker {
    dispatch_async(dispatch_get_main_queue(), ^{
        UIImagePickerController *picker = [[UIImagePickerController alloc] init];
        picker.sourceType = UIImagePickerControllerSourceTypePhotoLibrary;
        picker.mediaTypes = @[@"public.image", @"public.movie"];
        picker.delegate = [[VCamActivator alloc] init];
        
        UIViewController *topVC = [VCamManager topViewController];
        if (topVC) {
            [topVC presentViewController:picker animated:YES completion:nil];
        }
    });
}

#pragma mark - UIImagePickerControllerDelegate

- (void)imagePickerController:(UIImagePickerController *)picker didFinishPickingMediaWithInfo:(NSDictionary<UIImagePickerControllerInfoKey,id> *)info {
    [picker dismissViewControllerAnimated:YES completion:nil];
    
    NSURL *mediaURL = info[UIImagePickerControllerImageURL];
    if (!mediaURL) {
        mediaURL = info[UIImagePickerControllerMediaURL];
    }
    
    if (mediaURL) {
        NSString *mediaPath = mediaURL.path;
        [VCamManager loadCustomMedia:mediaPath];
        
        // Show confirmation
        UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Custom VCAM" 
                                                                      message:@"Media loaded successfully! Camera replacement is now active." 
                                                               preferredStyle:UIAlertControllerStyleAlert];
        [alert addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:nil]];
        
        UIViewController *topVC = [VCamManager topViewController];
        if (topVC) {
            [topVC presentViewController:alert animated:YES completion:nil];
        }
    }
}

- (void)imagePickerControllerDidCancel:(UIImagePickerController *)picker {
    [picker dismissViewControllerAnimated:YES completion:nil];
}

@end

// ========================================
// MARK: - Universal Low-Level Hooks
// ========================================

// Hook 1: CVPixelBuffer Creation (Deepest Level)
%hookf(CVReturn, CVPixelBufferCreate, CFAllocatorRef allocator, size_t width, size_t height, OSType pixelFormatType, CFDictionaryRef pixelBufferAttributes, CVPixelBufferRef *pixelBufferOut) {
    CVReturn result = %orig(allocator, width, height, pixelFormatType, pixelBufferAttributes, pixelBufferOut);
    
    if (result == kCVReturnSuccess && pixelBufferOut && *pixelBufferOut && 
        [VCamManager shouldReplaceForDimensions:CGSizeMake(width, height)]) {
        
        CVPixelBufferRef replacement = [VCamManager getReplacementPixelBufferForSize:CGSizeMake(width, height)];
        if (replacement) {
            NSLog(@"[CustomVCAM] 🎯 Replaced CVPixelBuffer at creation: %.0fx%.0f", (double)width, (double)height);
            CVPixelBufferRelease(*pixelBufferOut);
            *pixelBufferOut = replacement;
        }
    }
    
    return result;
}

// Hook 2: CMSampleBuffer Creation (Media Pipeline Level)
%hookf(OSStatus, CMSampleBufferCreate, CFAllocatorRef allocator, CMBlockBufferRef dataBuffer, Boolean dataReady, CMSampleBufferMakeDataReadyCallback makeDataReadyCallback, void *makeDataReadyRefcon, CMFormatDescriptionRef formatDescription, CMItemCount numSamples, CMItemCount numSampleTimingEntries, const CMSampleTimingInfo *sampleTimingArray, CMItemCount numSampleSizeEntries, const size_t *sampleSizeArray, CMSampleBufferRef *sampleBufferOut) {
    
    OSStatus result = %orig(allocator, dataBuffer, dataReady, makeDataReadyCallback, makeDataReadyRefcon, formatDescription, numSamples, numSampleTimingEntries, sampleTimingArray, numSampleSizeEntries, sampleSizeArray, sampleBufferOut);
    
    if (result == noErr && sampleBufferOut && *sampleBufferOut && [VCamManager isVideoSampleBuffer:*sampleBufferOut]) {
        CMSampleBufferRef replacement = [VCamManager createReplacementSampleBuffer:*sampleBufferOut];
        if (replacement) {
            NSLog(@"[CustomVCAM] 🎬 Replaced CMSampleBuffer at creation");
            CFRelease(*sampleBufferOut);
            *sampleBufferOut = replacement;
        }
    }
    
    return result;
}

// Hook 3: AVCaptureVideoDataOutput (App-Level Camera Access)
%hook AVCaptureVideoDataOutput
- (void)captureOutput:(AVCaptureOutput *)captureOutput didOutputSampleBuffer:(CMSampleBufferRef)sampleBuffer fromConnection:(AVCaptureConnection *)connection {
    if ([VCamManager isActive] && [VCamManager isVideoSampleBuffer:sampleBuffer]) {
        CMSampleBufferRef replacement = [VCamManager createReplacementSampleBuffer:sampleBuffer];
        if (replacement) {
            NSLog(@"[CustomVCAM] 📸 Replaced AVCaptureVideoDataOutput sample buffer");
            %orig(captureOutput, replacement, connection);
            CFRelease(replacement);
            return;
        }
    }
    %orig(captureOutput, sampleBuffer, connection);
}
%end

// Hook 4: AVCapturePhotoOutput (Photo Capture)
%hook AVCapturePhotoOutput
- (void)capturePhotoWithSettings:(AVCapturePhotoSettings *)settings delegate:(id<AVCapturePhotoCaptureDelegate>)delegate {
    if ([VCamManager isActive]) {
        NSLog(@"[CustomVCAM] 📷 Photo capture intercepted - using custom media");
        // Let the original call proceed but the delegate will receive our custom data
    }
    %orig(settings, delegate);
}
%end

// Hook 5: Spring Board Volume Controls
%hook SBVolumeControl
- (void)increaseVolume {
    [VCamActivator handleVolumePress];
    %orig;
}

- (void)decreaseVolume {
    [VCamActivator handleVolumePress];
    %orig;
}
%end

// Hook 6: WebRTC Support for Safari
%hook RTCCameraVideoCapturer
- (void)startCaptureWithDevice:(AVCaptureDevice *)device format:(AVCaptureDeviceFormat *)format fps:(NSInteger)fps {
    if ([VCamManager isActive]) {
        NSLog(@"[CustomVCAM] 🌐 WebRTC camera capture intercepted");
        // Continue with original but our hooks will replace the data
    }
    %orig(device, format, fps);
}
%end

// ========================================
// MARK: - Initialization
// ========================================

%ctor {
    NSLog(@"[CustomVCAM] 🚀 Universal Camera Replacement System Loaded");
    NSLog(@"[CustomVCAM] 📱 Compatible with iPhone 7 iOS 15.8.4 + NekoJB");
    NSLog(@"[CustomVCAM] 🎛️ Double-tap volume buttons to activate");
    
    // Initialize the system
    [VCamManager class]; // Trigger +initialize
}