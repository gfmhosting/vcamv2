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
    
    if (@available(iOS 14, *)) {
        [self showPHPickerViewController];
    } else {
        [self showUIImagePickerController];
    }
}

- (void)showPHPickerViewController API_AVAILABLE(ios(14)) {
    PHPickerConfiguration *configuration = [[PHPickerConfiguration alloc] init];
    configuration.selectionLimit = 1;
    configuration.filter = [PHPickerFilter anyFilterMatchingSubfilters:@[
        [PHPickerFilter imagesFilter],
        [PHPickerFilter videosFilter]
    ]];
    
    _phPickerViewController = [[PHPickerViewController alloc] initWithConfiguration:configuration];
    _phPickerViewController.delegate = self;
    _phPickerViewController.modalPresentationStyle = UIModalPresentationFormSheet;
    
    if (@available(iOS 13.0, *)) {
        _phPickerViewController.view.layer.cornerRadius = 12;
    }
    
    [_containerViewController presentViewController:_phPickerViewController animated:YES completion:nil];
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
    
    if (_phPickerViewController) {
        [_phPickerViewController dismissViewControllerAnimated:YES completion:^{
            self.hidden = YES;
            self->_phPickerViewController = nil;
        }];
    } else if (_imagePickerController) {
        [_imagePickerController dismissViewControllerAnimated:YES completion:^{
            self.hidden = YES;
            self->_imagePickerController = nil;
        }];
    } else {
        self.hidden = YES;
    }
}

#pragma mark - PHPickerViewControllerDelegate

- (void)picker:(PHPickerViewController *)picker didFinishPicking:(NSArray<PHPickerResult *> *)results API_AVAILABLE(ios(14)) {
    NSLog(@"[CustomVCAM OverlayView] PHPicker finished with %lu results", (unsigned long)results.count);
    
    if (results.count == 0) {
        [self hideOverlay];
        if ([self.delegate respondsToSelector:@selector(overlayViewDidCancel:)]) {
            [self.delegate overlayViewDidCancel:self];
        }
        return;
    }
    
    PHPickerResult *result = results.firstObject;
    NSItemProvider *itemProvider = result.itemProvider;
    
    if ([itemProvider hasItemConformingToTypeIdentifier:@"public.image"]) {
        [self handleImageItemProvider:itemProvider];
    } else if ([itemProvider hasItemConformingToTypeIdentifier:@"public.movie"]) {
        [self handleVideoItemProvider:itemProvider];
    } else {
        NSLog(@"[CustomVCAM OverlayView] Unsupported media type selected");
        [self hideOverlay];
    }
}

- (void)handleImageItemProvider:(NSItemProvider *)itemProvider {
    [itemProvider loadObjectOfClass:[UIImage class] completionHandler:^(__kindof id<NSItemProviderReading> _Nullable object, NSError * _Nullable error) {
        if (error) {
            NSLog(@"[CustomVCAM OverlayView] Error loading image: %@", error.localizedDescription);
            dispatch_async(dispatch_get_main_queue(), ^{
                [self hideOverlay];
            });
            return;
        }
        
        UIImage *image = (UIImage *)object;
        if (image) {
            NSString *imagePath = [self saveImageToTempDirectory:image];
            if (imagePath) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    [self hideOverlay];
                    if ([self.delegate respondsToSelector:@selector(overlayView:didSelectMediaAtPath:)]) {
                        [self.delegate overlayView:self didSelectMediaAtPath:imagePath];
                    }
                });
            } else {
                dispatch_async(dispatch_get_main_queue(), ^{
                    [self hideOverlay];
                });
            }
        }
    }];
}

- (void)handleVideoItemProvider:(NSItemProvider *)itemProvider {
    [itemProvider loadFileRepresentationForTypeIdentifier:@"public.movie" completionHandler:^(NSURL * _Nullable url, NSError * _Nullable error) {
        if (error) {
            NSLog(@"[CustomVCAM OverlayView] Error loading video: %@", error.localizedDescription);
            dispatch_async(dispatch_get_main_queue(), ^{
                [self hideOverlay];
            });
            return;
        }
        
        if (url) {
            NSString *videoPath = [self copyVideoToTempDirectory:url];
            if (videoPath) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    [self hideOverlay];
                    if ([self.delegate respondsToSelector:@selector(overlayView:didSelectMediaAtPath:)]) {
                        [self.delegate overlayView:self didSelectMediaAtPath:videoPath];
                    }
                });
            } else {
                dispatch_async(dispatch_get_main_queue(), ^{
                    [self hideOverlay];
                });
            }
        }
    }];
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
    NSString *tempDir = NSTemporaryDirectory();
    NSString *filename = [NSString stringWithFormat:@"customvcam_image_%@.jpg", [[NSUUID UUID] UUIDString]];
    NSString *imagePath = [tempDir stringByAppendingPathComponent:filename];
    
    NSData *imageData = UIImageJPEGRepresentation(image, 0.8);
    if ([imageData writeToFile:imagePath atomically:YES]) {
        NSLog(@"[CustomVCAM OverlayView] Saved image to: %@", imagePath);
        return imagePath;
    } else {
        NSLog(@"[CustomVCAM OverlayView] Failed to save image to temp directory");
        return nil;
    }
}

- (NSString *)copyVideoToTempDirectory:(NSURL *)videoURL {
    NSString *tempDir = NSTemporaryDirectory();
    NSString *filename = [NSString stringWithFormat:@"customvcam_video_%@.mp4", [[NSUUID UUID] UUIDString]];
    NSString *videoPath = [tempDir stringByAppendingPathComponent:filename];
    
    NSError *error;
    if ([[NSFileManager defaultManager] copyItemAtPath:videoURL.path toPath:videoPath error:&error]) {
        NSLog(@"[CustomVCAM OverlayView] Copied video to: %@", videoPath);
        return videoPath;
    } else {
        NSLog(@"[CustomVCAM OverlayView] Failed to copy video: %@", error.localizedDescription);
        return nil;
    }
}

- (void)touchesBegan:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
    UITouch *touch = [touches anyObject];
    CGPoint location = [touch locationInView:self];
    
    if (!_phPickerViewController && !_imagePickerController) {
        CGRect pickerFrame = CGRectZero;
        
        if (_phPickerViewController) {
            pickerFrame = _phPickerViewController.view.frame;
        } else if (_imagePickerController) {
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