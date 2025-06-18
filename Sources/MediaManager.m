#import "MediaManager.h"

@implementation MediaManager

+ (instancetype)sharedInstance {
    static MediaManager *sharedInstance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedInstance = [[self alloc] init];
    });
    return sharedInstance;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        _mediaLoaded = NO;
        _idDocuments = @[];
        _selfiePhotos = @[];
        _videoPaths = @[];
        [self loadMediaBundle];
    }
    return self;
}

#pragma mark - Media Injection Methods

- (void)injectMediaIntoPicker:(UIImagePickerController *)picker {
    NSLog(@"[CustomVCAM] MediaManager: Injecting media into picker");
    
    if (!self.mediaLoaded) {
        [self loadMediaBundle];
    }
    
    // For now, just ensure photo library is selected
    picker.sourceType = UIImagePickerControllerSourceTypePhotoLibrary;
    picker.allowsEditing = NO;
    
    // TODO: Implement custom media selection overlay
}

- (void)setupFakeStream:(AVCaptureSession *)session {
    NSLog(@"[CustomVCAM] MediaManager: Setting up fake camera stream");
    
    // Block the real camera session from starting
    // TODO: Implement media stream replacement
}

- (NSString *)getFakeWebMediaResponse {
    NSLog(@"[CustomVCAM] MediaManager: Generating fake web media response");
    
    // Return a fake media data URL for web contexts
    UIImage *fakeImage = [self getRandomSelfie];
    if (fakeImage) {
        NSData *imageData = UIImageJPEGRepresentation(fakeImage, 0.8);
        NSString *base64String = [imageData base64EncodedStringWithOptions:0];
        return [NSString stringWithFormat:@"data:image/jpeg;base64,%@", base64String];
    }
    
    return @"data:image/jpeg;base64,/9j/4AAQSkZJRgABAQAAAQABAAD//gA7Q1JFQV..."; // Placeholder
}

#pragma mark - Media Selection Methods

- (UIImage *)getRandomIDDocument {
    if (self.idDocuments.count > 0) {
        NSUInteger randomIndex = arc4random_uniform((uint32_t)self.idDocuments.count);
        return self.idDocuments[randomIndex];
    }
    
    // Return placeholder if no documents loaded
    return [self createPlaceholderImage:@"ID Document"];
}

- (UIImage *)getRandomSelfie {
    if (self.selfiePhotos.count > 0) {
        NSUInteger randomIndex = arc4random_uniform((uint32_t)self.selfiePhotos.count);
        return self.selfiePhotos[randomIndex];
    }
    
    // Return placeholder if no selfies loaded
    return [self createPlaceholderImage:@"Selfie"];
}

- (NSString *)getRandomVideoPath {
    if (self.videoPaths.count > 0) {
        NSUInteger randomIndex = arc4random_uniform((uint32_t)self.videoPaths.count);
        return self.videoPaths[randomIndex];
    }
    
    return nil;
}

#pragma mark - Media Management

- (void)loadMediaBundle {
    NSLog(@"[CustomVCAM] MediaManager: Loading media bundle");
    
    // Create media directory paths
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSLibraryDirectory, NSUserDomainMask, YES);
    NSString *libraryPath = [paths firstObject];
    NSString *mediaPath = [libraryPath stringByAppendingPathComponent:@"CustomVCAM/Media"];
    
    // Create directory if it doesn't exist
    NSFileManager *fileManager = [NSFileManager defaultManager];
    if (![fileManager fileExistsAtPath:mediaPath]) {
        [fileManager createDirectoryAtPath:mediaPath withIntermediateDirectories:YES attributes:nil error:nil];
        NSLog(@"[CustomVCAM] Created media directory: %@", mediaPath);
    }
    
    // Load media files from bundle
    NSMutableArray *loadedIDs = [NSMutableArray array];
    NSMutableArray *loadedSelfies = [NSMutableArray array];
    NSMutableArray *loadedVideos = [NSMutableArray array];
    
    // For now, create placeholder content
    [loadedIDs addObject:[self createPlaceholderImage:@"Driver License"]];
    [loadedIDs addObject:[self createPlaceholderImage:@"Passport"]];
    [loadedSelfies addObject:[self createPlaceholderImage:@"Selfie 1"]];
    [loadedSelfies addObject:[self createPlaceholderImage:@"Selfie 2"]];
    
    self.idDocuments = [loadedIDs copy];
    self.selfiePhotos = [loadedSelfies copy];
    self.videoPaths = [loadedVideos copy];
    self.mediaLoaded = YES;
    
    NSLog(@"[CustomVCAM] Loaded %lu ID documents, %lu selfies, %lu videos", 
          (unsigned long)self.idDocuments.count, 
          (unsigned long)self.selfiePhotos.count, 
          (unsigned long)self.videoPaths.count);
}

- (NSArray<UIImage *> *)getAllIDDocuments {
    return self.idDocuments;
}

- (NSArray<UIImage *> *)getAllSelfies {
    return self.selfiePhotos;
}

- (NSArray<NSString *> *)getAllVideoPaths {
    return self.videoPaths;
}

#pragma mark - Utility Methods

- (UIImage *)addRandomNoise:(UIImage *)image {
    // Add subtle noise to make image look more realistic
    // TODO: Implement noise addition algorithm
    return image;
}

- (UIImage *)adjustImageMetadata:(UIImage *)image {
    // Adjust EXIF and metadata to look realistic
    // TODO: Implement metadata manipulation
    return image;
}

- (NSData *)createFakeEXIFData {
    // Create realistic EXIF data for camera images
    // TODO: Implement EXIF generation
    return [NSData data];
}

- (UIImage *)createPlaceholderImage:(NSString *)text {
    CGSize size = CGSizeMake(640, 480);
    UIGraphicsBeginImageContextWithOptions(size, NO, 0.0);
    
    CGContextRef context = UIGraphicsGetCurrentContext();
    CGContextSetFillColorWithColor(context, [UIColor lightGrayColor].CGColor);
    CGContextFillRect(context, CGRectMake(0, 0, size.width, size.height));
    
    NSDictionary *attributes = @{
        NSFontAttributeName: [UIFont systemFontOfSize:24],
        NSForegroundColorAttributeName: [UIColor blackColor]
    };
    
    CGSize textSize = [text sizeWithAttributes:attributes];
    CGPoint textPoint = CGPointMake((size.width - textSize.width) / 2, (size.height - textSize.height) / 2);
    [text drawAtPoint:textPoint withAttributes:attributes];
    
    UIImage *image = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    
    return image;
}

@end 