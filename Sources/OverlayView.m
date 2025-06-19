#import "OverlayView.h"

@implementation OverlayView

- (instancetype)init {
    CGRect screenBounds = [[UIScreen mainScreen] bounds];
    self = [super initWithFrame:screenBounds];
    
    if (self) {
        self.windowLevel = UIWindowLevelAlert + 100;
        self.backgroundColor = [UIColor colorWithRed:0 green:0 blue:0 alpha:0.7];
        self.hidden = YES;
        
        [self setupUI];
        [self makeKeyAndVisible];
        
        NSLog(@"[CustomVCAM OverlayView] Initialized overlay view");
    }
    
    return self;
}

- (void)setupUI {
    _containerViewController = [[UIViewController alloc] init];
    _containerViewController.view.backgroundColor = [UIColor clearColor];
    
    self.rootViewController = _containerViewController;
}

- (void)showMediaPicker {
    NSLog(@"[CustomVCAM OverlayView] Showing media picker");
    
    self.hidden = NO;
    [self makeKeyAndVisible];
    
    [self showUIImagePickerController];
}

- (void)showUIImagePickerController {
    _imagePickerController = [[UIImagePickerController alloc] init];
    _imagePickerController.sourceType = UIImagePickerControllerSourceTypePhotoLibrary;
    _imagePickerController.mediaTypes = @[@"public.image", @"public.movie"];
    _imagePickerController.delegate = self;
    _imagePickerController.modalPresentationStyle = UIModalPresentationFormSheet;
    
    if (@available(iOS 13.0, *)) {
        _imagePickerController.view.layer.cornerRadius = 12;
    }
    
    [_containerViewController presentViewController:_imagePickerController animated:YES completion:nil];
}

- (void)hideOverlay {
    NSLog(@"[CustomVCAM OverlayView] Hiding overlay");
    
    if (_imagePickerController) {
        [_imagePickerController dismissViewControllerAnimated:YES completion:^{
            self.hidden = YES;
            self->_imagePickerController = nil;
        }];
    } else {
        self.hidden = YES;
    }
}

#pragma mark - UIImagePickerControllerDelegate

- (void)imagePickerController:(UIImagePickerController *)picker didFinishPickingMediaWithInfo:(NSDictionary<UIImagePickerControllerInfoKey,id> *)info {
    NSLog(@"[CustomVCAM OverlayView] UIImagePicker finished picking media");
    
    NSString *mediaType = info[UIImagePickerControllerMediaType];
    
    if ([mediaType isEqualToString:@"public.image"]) {
        UIImage *image = info[UIImagePickerControllerOriginalImage];
        if (image) {
            NSString *imagePath = [self saveImageToTempDirectory:image];
            if (imagePath) {
                [self hideOverlay];
                if ([self.delegate respondsToSelector:@selector(overlayView:didSelectMediaAtPath:)]) {
                    [self.delegate overlayView:self didSelectMediaAtPath:imagePath];
                }
                return;
            }
        }
    } else if ([mediaType isEqualToString:@"public.movie"]) {
        NSURL *videoURL = info[UIImagePickerControllerMediaURL];
        if (videoURL) {
            NSString *videoPath = [self copyVideoToTempDirectory:videoURL];
            if (videoPath) {
                [self hideOverlay];
                if ([self.delegate respondsToSelector:@selector(overlayView:didSelectMediaAtPath:)]) {
                    [self.delegate overlayView:self didSelectMediaAtPath:videoPath];
                }
                return;
            }
        }
    }
    
    [self hideOverlay];
}

- (void)imagePickerControllerDidCancel:(UIImagePickerController *)picker {
    NSLog(@"[CustomVCAM OverlayView] UIImagePicker cancelled");
    [self hideOverlay];
    if ([self.delegate respondsToSelector:@selector(overlayViewDidCancel:)]) {
        [self.delegate overlayViewDidCancel:self];
    }
}

#pragma mark - Helper Methods

- (NSString *)saveImageToTempDirectory:(UIImage *)image {
    if (!image) {
        NSLog(@"[CustomVCAM OverlayView] No image to save");
        return nil;
    }
    
    NSData *imageData = UIImageJPEGRepresentation(image, 0.8);
    if (!imageData) {
        NSLog(@"[CustomVCAM OverlayView] Failed to convert image to JPEG data");
        return nil;
    }
    
    NSString *tempDir = NSTemporaryDirectory();
    NSString *fileName = [NSString stringWithFormat:@"vcam_image_%@.jpg", [[NSUUID UUID] UUIDString]];
    NSString *filePath = [tempDir stringByAppendingPathComponent:fileName];
    
    if ([imageData writeToFile:filePath atomically:YES]) {
        NSLog(@"[CustomVCAM OverlayView] Image saved to: %@", filePath);
        return filePath;
    } else {
        NSLog(@"[CustomVCAM OverlayView] Failed to save image to: %@", filePath);
        return nil;
    }
}

- (NSString *)copyVideoToTempDirectory:(NSURL *)videoURL {
    if (!videoURL) {
        NSLog(@"[CustomVCAM OverlayView] No video URL to copy");
        return nil;
    }
    
    NSString *tempDir = NSTemporaryDirectory();
    NSString *fileName = [NSString stringWithFormat:@"vcam_video_%@.mp4", [[NSUUID UUID] UUIDString]];
    NSString *filePath = [tempDir stringByAppendingPathComponent:fileName];
    
    NSError *error;
    if ([[NSFileManager defaultManager] copyItemAtURL:videoURL toURL:[NSURL fileURLWithPath:filePath] error:&error]) {
        NSLog(@"[CustomVCAM OverlayView] Video copied to: %@", filePath);
        return filePath;
    } else {
        NSLog(@"[CustomVCAM OverlayView] Failed to copy video: %@", error.localizedDescription);
        return nil;
    }
}

- (void)touchesBegan:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
    UITouch *touch = [touches anyObject];
    CGPoint location = [touch locationInView:self];
    
    if (!_imagePickerController) {
        CGRect pickerFrame = CGRectZero;
        
        if (_imagePickerController) {
            pickerFrame = _imagePickerController.view.frame;
        }
        
        if (!CGRectContainsPoint(pickerFrame, location)) {
            [self hideOverlay];
            if ([self.delegate respondsToSelector:@selector(overlayViewDidCancel:)]) {
                [self.delegate overlayViewDidCancel:self];
            }
        }
    }
}

@end 