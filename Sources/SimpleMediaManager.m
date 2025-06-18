#import "SimpleMediaManager.h"

@interface SimpleMediaManager () <UIImagePickerControllerDelegate, UINavigationControllerDelegate>
@end

@implementation SimpleMediaManager

+ (instancetype)sharedInstance {
    static SimpleMediaManager *instance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[SimpleMediaManager alloc] init];
    });
    return instance;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        _hasMedia = NO;
    }
    return self;
}

- (void)presentGallery {
    UIImagePickerController *picker = [[UIImagePickerController alloc] init];
    picker.sourceType = UIImagePickerControllerSourceTypePhotoLibrary;
    picker.mediaTypes = @[@"public.image"];
    picker.delegate = self;
    
    UIViewController *rootVC = [UIApplication sharedApplication].keyWindow.rootViewController;
    [rootVC presentViewController:picker animated:YES completion:nil];
}

- (void)imagePickerController:(UIImagePickerController *)picker didFinishPickingMediaWithInfo:(NSDictionary<UIImagePickerControllerInfoKey, id> *)info {
    self.selectedImage = info[UIImagePickerControllerOriginalImage];
    self.hasMedia = (self.selectedImage != nil);
    [picker dismissViewControllerAnimated:YES completion:nil];
    NSLog(@"[CustomVCAM] Media selected: %@", self.hasMedia ? @"YES" : @"NO");
}

- (void)imagePickerControllerDidCancel:(UIImagePickerController *)picker {
    [picker dismissViewControllerAnimated:YES completion:nil];
}

- (CMSampleBufferRef)createSampleBufferFromImage {
    @autoreleasepool {
        if (!self.selectedImage) return NULL;
        
        CVPixelBufferRef pixelBuffer = [self createPixelBufferFromImage:self.selectedImage];
        if (!pixelBuffer) return NULL;
        
        CMSampleBufferRef sampleBuffer = NULL;
        CMVideoFormatDescriptionRef formatDesc = NULL;
        
        OSStatus status = CMVideoFormatDescriptionCreateForImageBuffer(kCFAllocatorDefault, pixelBuffer, &formatDesc);
        if (status != noErr || !formatDesc) {
            CVPixelBufferRelease(pixelBuffer);
            return NULL;
        }
        
        CMSampleTimingInfo timing = {CMTimeMake(1, 30), CMTimeMake(0, 30), kCMTimeInvalid};
        status = CMSampleBufferCreateReadyWithImageBuffer(kCFAllocatorDefault, pixelBuffer, formatDesc, &timing, &sampleBuffer);
        
        if (formatDesc) CFRelease(formatDesc);
        if (pixelBuffer) CVPixelBufferRelease(pixelBuffer);
        
        if (status != noErr) {
            if (sampleBuffer) CFRelease(sampleBuffer);
            return NULL;
        }
        
        return sampleBuffer;
    }
}

- (CVPixelBufferRef)createPixelBufferFromImage:(UIImage *)image {
    if (!image) return NULL;
    
    CGSize size = CGSizeMake(1280, 720);
    
    CVPixelBufferRef pixelBuffer = NULL;
    CVPixelBufferCreate(kCFAllocatorDefault, size.width, size.height, kCVPixelFormatType_32ARGB, NULL, &pixelBuffer);
    
    CVPixelBufferLockBaseAddress(pixelBuffer, 0);
    void *data = CVPixelBufferGetBaseAddress(pixelBuffer);
    
    CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
    CGContextRef context = CGBitmapContextCreate(data, size.width, size.height, 8, CVPixelBufferGetBytesPerRow(pixelBuffer), colorSpace, kCGImageAlphaPremultipliedFirst | kCGBitmapByteOrder32Host);
    
    CGContextDrawImage(context, CGRectMake(0, 0, size.width, size.height), image.CGImage);
    
    CGContextRelease(context);
    CGColorSpaceRelease(colorSpace);
    CVPixelBufferUnlockBaseAddress(pixelBuffer, 0);
    
    return pixelBuffer;
}

@end