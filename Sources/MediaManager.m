#import "MediaManager.h"
#import <ImageIO/ImageIO.h>

@interface MediaManager () <UIImagePickerControllerDelegate, UINavigationControllerDelegate>
@property (nonatomic, weak) UIViewController *presentingViewController;
@end

@implementation MediaManager

+ (instancetype)sharedInstance {
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
        _isVideoSelected = NO;
    }
    return self;
}

- (void)presentMediaPicker:(UIViewController *)presentingViewController {
    self.presentingViewController = presentingViewController;
    
    PHAuthorizationStatus status = [PHPhotoLibrary authorizationStatus];
    if (status == PHAuthorizationStatusNotDetermined) {
        [PHPhotoLibrary requestAuthorization:^(PHAuthorizationStatus status) {
            dispatch_async(dispatch_get_main_queue(), ^{
                if (status == PHAuthorizationStatusAuthorized) {
                    [self showImagePicker];
                }
            });
        }];
    } else if (status == PHAuthorizationStatusAuthorized) {
        [self showImagePicker];
    }
}

- (void)showImagePicker {
    UIImagePickerController *picker = [[UIImagePickerController alloc] init];
    picker.delegate = self;
    picker.sourceType = UIImagePickerControllerSourceTypePhotoLibrary;
    picker.mediaTypes = @[@"public.image", @"public.movie"];
    picker.allowsEditing = NO;
    
    [self.presentingViewController presentViewController:picker animated:YES completion:nil];
}

- (void)imagePickerController:(UIImagePickerController *)picker didFinishPickingMediaWithInfo:(NSDictionary<UIImagePickerControllerInfoKey,id> *)info {
    
    NSString *mediaType = info[UIImagePickerControllerMediaType];
    
    if ([mediaType isEqualToString:@"public.image"]) {
        self.selectedImage = info[UIImagePickerControllerOriginalImage];
        self.isVideoSelected = NO;
        self.selectedVideoURL = nil;
        if (self.videoPlayer) {
            [self.videoPlayer pause];
            self.videoPlayer = nil;
            self.videoOutput = nil;
        }
    } else if ([mediaType isEqualToString:@"public.movie"]) {
        self.selectedVideoURL = info[UIImagePickerControllerMediaURL];
        self.isVideoSelected = YES;
        self.selectedImage = nil;
        [self setupVideoPlayer];
    }
    
    [picker dismissViewControllerAnimated:YES completion:nil];
}

- (void)imagePickerControllerDidCancel:(UIImagePickerController *)picker {
    [picker dismissViewControllerAnimated:YES completion:nil];
}

- (void)setupVideoPlayer {
    if (!self.selectedVideoURL) return;
    
    AVPlayerItem *item = [AVPlayerItem playerItemWithURL:self.selectedVideoURL];
    self.videoPlayer = [AVPlayer playerWithPlayerItem:item];
    
    NSDictionary *pixelBufferAttributes = @{
        (NSString *)kCVPixelBufferPixelFormatTypeKey: @(kCVPixelFormatType_32BGRA),
        (NSString *)kCVPixelBufferWidthKey: @1920,
        (NSString *)kCVPixelBufferHeightKey: @1080
    };
    
    self.videoOutput = [[AVPlayerItemVideoOutput alloc] initWithPixelBufferAttributes:pixelBufferAttributes];
    [item addOutput:self.videoOutput];
    
    [[NSNotificationCenter defaultCenter] addObserver:self 
                                             selector:@selector(videoDidReachEnd:) 
                                                 name:AVPlayerItemDidPlayToEndTimeNotification 
                                               object:item];
    
    [self.videoPlayer play];
}

- (void)videoDidReachEnd:(NSNotification *)notification {
    [self.videoPlayer seekToTime:kCMTimeZero];
    [self.videoPlayer play];
}

- (CMSampleBufferRef)createSampleBufferFromCurrentMedia:(CMTime)presentationTime {
    CVPixelBufferRef pixelBuffer = NULL;
    
    if (self.isVideoSelected && self.videoOutput) {
        pixelBuffer = [self createPixelBufferFromVideo:presentationTime];
    } else if (self.selectedImage) {
        pixelBuffer = [self createPixelBufferFromImage:self.selectedImage];
    }
    
    if (!pixelBuffer) {
        return NULL;
    }
    
    CMSampleBufferRef sampleBuffer = NULL;
    CMVideoFormatDescriptionRef formatDescription = NULL;
    
    CMVideoFormatDescriptionCreateForImageBuffer(kCFAllocatorDefault, pixelBuffer, &formatDescription);
    
    CMSampleTimingInfo timingInfo = {
        .duration = CMTimeMake(1, 30),
        .presentationTimeStamp = presentationTime,
        .decodeTimeStamp = kCMTimeInvalid
    };
    
    CMSampleBufferCreateReadyWithImageBuffer(kCFAllocatorDefault,
                                           pixelBuffer,
                                           formatDescription,
                                           &timingInfo,
                                           &sampleBuffer);
    
    [self addRandomizedMetadataToSampleBuffer:sampleBuffer];
    
    CVPixelBufferRelease(pixelBuffer);
    CFRelease(formatDescription);
    
    return sampleBuffer;
}

- (CVPixelBufferRef)createPixelBufferFromImage:(UIImage *)image {
    if (!image) return NULL;
    
    CGSize size = CGSizeMake(1920, 1080);
    
    NSDictionary *options = @{
        (NSString *)kCVPixelBufferCGImageCompatibilityKey: @YES,
        (NSString *)kCVPixelBufferCGBitmapContextCompatibilityKey: @YES,
        (NSString *)kCVPixelBufferPixelFormatTypeKey: @(kCVPixelFormatType_32BGRA)
    };
    
    CVPixelBufferRef pixelBuffer = NULL;
    CVReturn status = CVPixelBufferCreate(kCFAllocatorDefault,
                                        size.width, size.height,
                                        kCVPixelFormatType_32BGRA,
                                        (__bridge CFDictionaryRef)options,
                                        &pixelBuffer);
    
    if (status != kCVReturnSuccess) {
        return NULL;
    }
    
    CVPixelBufferLockBaseAddress(pixelBuffer, 0);
    void *baseAddress = CVPixelBufferGetBaseAddress(pixelBuffer);
    
    CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
    CGContextRef context = CGBitmapContextCreate(baseAddress,
                                               size.width, size.height,
                                               8, CVPixelBufferGetBytesPerRow(pixelBuffer),
                                               colorSpace,
                                               kCGBitmapByteOrder32Little | kCGImageAlphaPremultipliedFirst);
    
    CGRect imageRect = CGRectMake(0, 0, size.width, size.height);
    CGContextDrawImage(context, imageRect, image.CGImage);
    
    CGContextRelease(context);
    CGColorSpaceRelease(colorSpace);
    CVPixelBufferUnlockBaseAddress(pixelBuffer, 0);
    
    return pixelBuffer;
}

- (CVPixelBufferRef)createPixelBufferFromVideo:(CMTime)time {
    if (!self.videoOutput || !self.videoPlayer) return NULL;
    
    CMTime currentTime = [self.videoPlayer currentTime];
    if ([self.videoOutput hasNewPixelBufferForItemTime:currentTime]) {
        return [self.videoOutput copyPixelBufferForItemTime:currentTime itemTimeForDisplay:NULL];
    }
    
    return NULL;
}

- (void)addRandomizedMetadataToSampleBuffer:(CMSampleBufferRef)sampleBuffer {
    if (!sampleBuffer) return;
    
    CMSetAttachment(sampleBuffer, CFSTR("CustomVCAMProcessed"), kCFBooleanTrue, kCMAttachmentMode_ShouldNotPropagate);
    
    NSTimeInterval now = [[NSDate date] timeIntervalSince1970];
    NSTimeInterval randomOffset = (arc4random() % 300) - 150;
    NSDate *randomDate = [NSDate dateWithTimeIntervalSince1970:now + randomOffset];
    
    CMSetAttachment(sampleBuffer, CFSTR("Timestamp"), (__bridge CFTypeRef)randomDate, kCMAttachmentMode_ShouldNotPropagate);
    
    NSDictionary *cameraMetadata = @{
        @"FocalLength": @(4.15 + ((arc4random() % 20) - 10) * 0.01),
        @"FNumber": @(1.8 + ((arc4random() % 10) - 5) * 0.01),
        @"ISO": @(25 + (arc4random() % 1600)),
        @"ExposureTime": @(1.0 / (30 + (arc4random() % 500)))
    };
    
    CMSetAttachment(sampleBuffer, CFSTR("CameraMetadata"), (__bridge CFTypeRef)cameraMetadata, kCMAttachmentMode_ShouldNotPropagate);
}

- (void)randomizeImageMetadata:(NSMutableDictionary *)metadata {
    if (!metadata) return;
    
    NSTimeInterval now = [[NSDate date] timeIntervalSince1970];
    NSTimeInterval randomOffset = (arc4random() % 300) - 150;
    NSString *randomTimestamp = [NSString stringWithFormat:@"%.0f", now + randomOffset];
    
    metadata[@"{Exif}"][@"DateTimeOriginal"] = randomTimestamp;
    metadata[@"{Exif}"][@"DateTimeDigitized"] = randomTimestamp;
    
    metadata[@"{Exif}"][@"FocalLength"] = @(4.15 + ((arc4random() % 20) - 10) * 0.01);
    metadata[@"{Exif}"][@"FNumber"] = @(1.8 + ((arc4random() % 10) - 5) * 0.01);
    metadata[@"{Exif}"][@"ISOSpeedRatings"] = @[@(25 + (arc4random() % 1600))];
    metadata[@"{Exif}"][@"ExposureTime"] = @(1.0 / (30 + (arc4random() % 500)));
}

@end 