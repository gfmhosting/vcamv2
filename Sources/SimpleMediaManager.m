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
    
    if (self.selectedImage) {
        NSLog(@"[CustomVCAM] Media selected successfully - size: %.0fx%.0f", 
              self.selectedImage.size.width, self.selectedImage.size.height);
        
        // Save image to shared location for other processes
        [self saveImageToSharedLocation:self.selectedImage];
    } else {
        NSLog(@"[CustomVCAM] ERROR: Media selection failed");
    }
    
    [picker dismissViewControllerAnimated:YES completion:^{
        // Notify overlay about media selection
        [[NSNotificationCenter defaultCenter] postNotificationName:@"MediaSelectionChanged" 
                                                            object:nil 
                                                          userInfo:@{@"hasMedia": @(self.hasMedia)}];
    }];
}

- (void)imagePickerControllerDidCancel:(UIImagePickerController *)picker {
    [picker dismissViewControllerAnimated:YES completion:nil];
}

- (CMSampleBufferRef)createSampleBufferFromImage {
    @autoreleasepool {
        NSString *bundleID = [[NSBundle mainBundle] bundleIdentifier];
        NSLog(@"[CustomVCAM] MEDIAMGR: createSampleBufferFromImage called - Bundle: %@", bundleID);
        
        UIImage *imageToUse = self.selectedImage;
        
        if (!imageToUse) {
            NSLog(@"[CustomVCAM] MEDIAMGR: No local selectedImage, trying shared file");
            imageToUse = [self loadImageFromSharedLocation];
        }
        
        if (!imageToUse) {
            NSLog(@"[CustomVCAM] MEDIAMGR: ERROR - No image available (local or shared)");
            return NULL;
        }
        
        NSLog(@"[CustomVCAM] MEDIAMGR: Creating buffer from image %.0fx%.0f for bundle %@", 
              imageToUse.size.width, imageToUse.size.height, bundleID);
        
        CVPixelBufferRef pixelBuffer = [self createPixelBufferFromImage:imageToUse];
        if (!pixelBuffer) {
            NSLog(@"[CustomVCAM] MEDIAMGR: ERROR - Failed to create pixel buffer");
            return NULL;
        }
        
        NSLog(@"[CustomVCAM] MEDIAMGR: Pixel buffer created successfully");
        
        CMSampleBufferRef sampleBuffer = NULL;
        CMVideoFormatDescriptionRef formatDesc = NULL;
        
        OSStatus status = CMVideoFormatDescriptionCreateForImageBuffer(kCFAllocatorDefault, pixelBuffer, &formatDesc);
        if (status != noErr || !formatDesc) {
            NSLog(@"[CustomVCAM] MEDIAMGR: ERROR - Format description failed (status: %d)", (int)status);
            CVPixelBufferRelease(pixelBuffer);
            return NULL;
        }
        
        NSLog(@"[CustomVCAM] MEDIAMGR: Format description created");
        
        CMSampleTimingInfo timing = {CMTimeMake(1, 30), CMTimeMake(0, 30), kCMTimeInvalid};
        status = CMSampleBufferCreateReadyWithImageBuffer(kCFAllocatorDefault, pixelBuffer, formatDesc, &timing, &sampleBuffer);
        
        if (formatDesc) CFRelease(formatDesc);
        if (pixelBuffer) CVPixelBufferRelease(pixelBuffer);
        
        if (status != noErr) {
            NSLog(@"[CustomVCAM] MEDIAMGR: ERROR - Sample buffer creation failed (status: %d)", (int)status);
            if (sampleBuffer) CFRelease(sampleBuffer);
            return NULL;
        }
        
        NSLog(@"[CustomVCAM] MEDIAMGR: Sample buffer created successfully for %@", bundleID);
        return sampleBuffer;
    }
}

- (CVPixelBufferRef)createPixelBufferFromImage:(UIImage *)image {
    NSLog(@"[CustomVCAM] createPixelBufferFromImage called");
    
    if (!image) {
        NSLog(@"[CustomVCAM] ERROR: Image is NULL");
        return NULL;
    }
    
    CGSize size = CGSizeMake(1280, 720);
    NSLog(@"[CustomVCAM] Creating pixel buffer with size: %.0fx%.0f", size.width, size.height);
    
    CVPixelBufferRef pixelBuffer = NULL;
    OSStatus result = CVPixelBufferCreate(kCFAllocatorDefault, size.width, size.height, kCVPixelFormatType_32ARGB, NULL, &pixelBuffer);
    
    if (result != kCVReturnSuccess || !pixelBuffer) {
        NSLog(@"[CustomVCAM] ERROR: CVPixelBufferCreate failed (status: %d)", (int)result);
        return NULL;
    }
    
    NSLog(@"[CustomVCAM] CVPixelBuffer created successfully");
    
    CVPixelBufferLockBaseAddress(pixelBuffer, 0);
    void *data = CVPixelBufferGetBaseAddress(pixelBuffer);
    
    if (!data) {
        NSLog(@"[CustomVCAM] ERROR: Failed to get pixel buffer base address");
        CVPixelBufferRelease(pixelBuffer);
        return NULL;
    }
    
    CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
    CGContextRef context = CGBitmapContextCreate(data, size.width, size.height, 8, CVPixelBufferGetBytesPerRow(pixelBuffer), colorSpace, kCGImageAlphaPremultipliedFirst | kCGBitmapByteOrder32Host);
    
    if (!context) {
        NSLog(@"[CustomVCAM] ERROR: Failed to create graphics context");
        CGColorSpaceRelease(colorSpace);
        CVPixelBufferUnlockBaseAddress(pixelBuffer, 0);
        CVPixelBufferRelease(pixelBuffer);
        return NULL;
    }
    
    NSLog(@"[CustomVCAM] Drawing image to context");
    CGContextDrawImage(context, CGRectMake(0, 0, size.width, size.height), image.CGImage);
    
    CGContextRelease(context);
    CGColorSpaceRelease(colorSpace);
    CVPixelBufferUnlockBaseAddress(pixelBuffer, 0);
    
    NSLog(@"[CustomVCAM] Pixel buffer creation completed successfully");
    return pixelBuffer;
}

- (BOOL)hasAvailableMedia {
    if (self.selectedImage) {
        return YES;
    }
    
    // Check for shared image file
    UIImage *sharedImage = [self loadImageFromSharedLocation];
    if (sharedImage) {
        self.selectedImage = sharedImage;
        self.hasMedia = YES;
        return YES;
    }
    
    return NO;
}

- (void)saveImageToSharedLocation:(UIImage *)image {
    if (image) {
        NSString *imagePath = @"/var/mobile/Library/Preferences/com.vcam.customvcam.image";
        NSData *imageData = UIImageJPEGRepresentation(image, 0.8);
        [imageData writeToFile:imagePath atomically:YES];
    }
}

- (UIImage *)loadImageFromSharedLocation {
    NSString *imagePath = @"/var/mobile/Library/Preferences/com.vcam.customvcam.image";
    NSData *imageData = [NSData dataWithContentsOfFile:imagePath];
    if (imageData) {
        UIImage *image = [UIImage imageWithData:imageData];
        return image;
    }
    return nil;
}

@end