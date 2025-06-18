#import "MediaManager.h"
#import <CoreMedia/CoreMedia.h>
#import <VideoToolbox/VideoToolbox.h>

@interface MediaManager() <UIImagePickerControllerDelegate, UINavigationControllerDelegate>
@property (nonatomic, strong) AVPlayer *videoPlayer;
@property (nonatomic, strong) AVPlayerItem *playerItem;
@property (nonatomic, strong) AVAssetImageGenerator *imageGenerator;
@property (nonatomic, copy) void(^completionBlock)(BOOL success);
@end

@implementation MediaManager

+ (instancetype)sharedManager {
    static MediaManager *instance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[MediaManager alloc] init];
    });
    return instance;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        _vcamEnabled = NO;
        _isVideoMode = NO;
        [self logDebug:@"MediaManager initialized"];
    }
    return self;
}

- (void)selectMediaWithCompletion:(void(^)(BOOL success))completion {
    [self logDebug:@"Starting media selection"];
    self.completionBlock = completion;
    
    UIImagePickerController *picker = [[UIImagePickerController alloc] init];
    picker.delegate = self;
    picker.sourceType = UIImagePickerControllerSourceTypePhotoLibrary;
    picker.mediaTypes = @[@"public.image", @"public.movie"];
    picker.allowsEditing = NO;
    
    UIViewController *topVC = [self topViewController];
    if (topVC) {
        [topVC presentViewController:picker animated:YES completion:nil];
    } else {
        [self logDebug:@"ERROR: Could not find top view controller"];
        if (completion) completion(NO);
    }
}

- (UIViewController *)topViewController {
    UIViewController *topVC = [UIApplication sharedApplication].keyWindow.rootViewController;
    while (topVC.presentedViewController) {
        topVC = topVC.presentedViewController;
    }
    return topVC;
}

- (void)imagePickerController:(UIImagePickerController *)picker didFinishPickingMediaWithInfo:(NSDictionary<UIImagePickerControllerInfoKey,id> *)info {
    [picker dismissViewControllerAnimated:YES completion:nil];
    
    NSString *mediaType = info[UIImagePickerControllerMediaType];
    
    if ([mediaType isEqualToString:@"public.image"]) {
        self.selectedImage = info[UIImagePickerControllerOriginalImage];
        self.isVideoMode = NO;
        [self logDebug:@"Image selected successfully"];
        if (self.completionBlock) self.completionBlock(YES);
    } else if ([mediaType isEqualToString:@"public.movie"]) {
        self.selectedMediaURL = info[UIImagePickerControllerMediaURL];
        self.isVideoMode = YES;
        [self setupVideoPlayer];
        [self logDebug:@"Video selected successfully"];
        if (self.completionBlock) self.completionBlock(YES);
    }
}

- (void)imagePickerControllerDidCancel:(UIImagePickerController *)picker {
    [picker dismissViewControllerAnimated:YES completion:nil];
    [self logDebug:@"Media selection cancelled"];
    if (self.completionBlock) self.completionBlock(NO);
}

- (void)setupVideoPlayer {
    if (self.selectedMediaURL) {
        self.playerItem = [AVPlayerItem playerItemWithURL:self.selectedMediaURL];
        self.videoPlayer = [AVPlayer playerWithPlayerItem:self.playerItem];
        [self.videoPlayer play];
        
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(playerDidFinishPlaying:)
                                                     name:AVPlayerItemDidPlayToEndTimeNotification
                                                   object:self.playerItem];
    }
}

- (void)playerDidFinishPlaying:(NSNotification *)notification {
    [self.videoPlayer seekToTime:kCMTimeZero];
    [self.videoPlayer play];
}

- (CVPixelBufferRef)getCurrentFrameForTime:(CMTime)time {
    if (self.isVideoMode && self.videoPlayer) {
        return [self getVideoFrameAtTime:time];
    } else if (self.selectedImage) {
        return [self pixelBufferFromImage:self.selectedImage];
    }
    return NULL;
}

- (CVPixelBufferRef)getVideoFrameAtTime:(CMTime)time {
    if (!self.selectedMediaURL) return NULL;
    
    AVAsset *asset = [AVAsset assetWithURL:self.selectedMediaURL];
    AVAssetImageGenerator *generator = [AVAssetImageGenerator assetImageGeneratorWithAsset:asset];
    generator.requestedTimeToleranceAfter = kCMTimeZero;
    generator.requestedTimeToleranceBefore = kCMTimeZero;
    
    NSError *error;
    CMTime actualTime;
    CGImageRef imageRef = [generator copyCGImageAtTime:time actualTime:&actualTime error:&error];
    
    if (imageRef) {
        UIImage *image = [UIImage imageWithCGImage:imageRef];
        CGImageRelease(imageRef);
        return [self pixelBufferFromImage:image];
    }
    
    return NULL;
}

- (CVPixelBufferRef)pixelBufferFromImage:(UIImage *)image {
    if (!image) return NULL;
    
    CGSize size = CGSizeMake(1920, 1080);
    
    NSDictionary *options = @{
        (NSString*)kCVPixelBufferCGImageCompatibilityKey: @YES,
        (NSString*)kCVPixelBufferCGBitmapContextCompatibilityKey: @YES,
        (NSString*)kCVPixelBufferWidthKey: @(size.width),
        (NSString*)kCVPixelBufferHeightKey: @(size.height)
    };
    
    CVPixelBufferRef pixelBuffer = NULL;
    CVReturn status = CVPixelBufferCreate(kCFAllocatorDefault,
                                         size.width,
                                         size.height,
                                         kCVPixelFormatType_32BGRA,
                                         (__bridge CFDictionaryRef)options,
                                         &pixelBuffer);
    
    if (status != kCVReturnSuccess) return NULL;
    
    CVPixelBufferLockBaseAddress(pixelBuffer, 0);
    void *data = CVPixelBufferGetBaseAddress(pixelBuffer);
    CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
    CGContextRef context = CGBitmapContextCreate(data,
                                               size.width,
                                               size.height,
                                               8,
                                               CVPixelBufferGetBytesPerRow(pixelBuffer),
                                               colorSpace,
                                               kCGImageAlphaNoneSkipFirst);
    
    CGContextDrawImage(context, CGRectMake(0, 0, size.width, size.height), image.CGImage);
    CGContextRelease(context);
    CGColorSpaceRelease(colorSpace);
    CVPixelBufferUnlockBaseAddress(pixelBuffer, 0);
    
    return pixelBuffer;
}

- (void)enableVCAM {
    self.vcamEnabled = YES;
    [self logDebug:@"VCAM enabled"];
}

- (void)disableVCAM {
    self.vcamEnabled = NO;
    [self logDebug:@"VCAM disabled"];
}

- (void)logDebug:(NSString *)message {
    NSLog(@"[CustomVCAM] %@", message);
}

@end 