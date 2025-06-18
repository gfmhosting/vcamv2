#import "MediaManager.h"

@implementation MediaManager

+ (instancetype)sharedInstanceSafe {
    static MediaManager *sharedInstance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        @try {
            sharedInstance = [[self alloc] initSafe];
        } @catch (NSException *exception) {
            NSLog(@"[CustomVCAM] MediaManager sharedInstance creation failed safely: %@", exception.reason);
            sharedInstance = nil;
        }
    });
    return sharedInstance;
}

- (instancetype)initSafe {
    self = [super init];
    if (self) {
        @try {
            _mediaLoaded = NO;
            _initializationSafe = YES;
            _idDocuments = @[];
            _selfiePhotos = @[];
            
            NSLog(@"[CustomVCAM] MediaManager initialized safely (no file operations during boot)");
        } @catch (NSException *exception) {
            NSLog(@"[CustomVCAM] MediaManager initialization failed: %@", exception.reason);
            _initializationSafe = NO;
            return nil;
        }
    }
    return self;
}

#pragma mark - SAFE Media Injection Methods

- (void)injectMediaIntoPickerSafe:(UIImagePickerController *)picker {
    @try {
        NSLog(@"[CustomVCAM] MediaManager: Injecting media into picker (SAFE)");
        
        if (!self.initializationSafe || !picker) {
            NSLog(@"[CustomVCAM] MediaManager: Cannot inject - unsafe state or nil picker");
            return;
        }
        
        // Safely ensure photo library is selected
        picker.sourceType = UIImagePickerControllerSourceTypePhotoLibrary;
        picker.allowsEditing = NO;
        
        // Delay media loading until actually needed
        if (!self.mediaLoaded) {
            [self loadMediaBundleSafe];
        }
        
        NSLog(@"[CustomVCAM] MediaManager: Photo library injection completed safely");
        
    } @catch (NSException *exception) {
        NSLog(@"[CustomVCAM] MediaManager: injectMediaIntoPickerSafe failed: %@", exception.reason);
    }
}

- (NSString *)getFakeWebMediaResponseSafe {
    @try {
        NSLog(@"[CustomVCAM] MediaManager: Generating fake web media response (SAFE)");
        
        if (!self.initializationSafe) {
            return @"data:image/jpeg;base64,/9j/4AAQSkZJRgABAQAAAQABAAD//gA7Q1JFQV..."; // Safe fallback
        }
        
        UIImage *fakeImage = [self getRandomSelfieSafe];
        if (fakeImage) {
            NSData *imageData = UIImageJPEGRepresentation(fakeImage, 0.8);
            if (imageData) {
                NSString *base64String = [imageData base64EncodedStringWithOptions:0];
                return [NSString stringWithFormat:@"data:image/jpeg;base64,%@", base64String];
            }
        }
        
        return @"data:image/jpeg;base64,/9j/4AAQSkZJRgABAQAAAQABAAD//gA7Q1JFQV..."; // Safe fallback
        
    } @catch (NSException *exception) {
        NSLog(@"[CustomVCAM] MediaManager: getFakeWebMediaResponseSafe failed: %@", exception.reason);
        return @"data:image/jpeg;base64,/9j/4AAQSkZJRgABAQAAAQABAAD//gA7Q1JFQV..."; // Safe fallback
    }
}

#pragma mark - SAFE Media Selection Methods

- (UIImage *)getRandomIDDocumentSafe {
    @try {
        if (!self.initializationSafe) {
            return [self createPlaceholderImageSafe:@"ID Document (Safe Mode)"];
        }
        
        if (!self.mediaLoaded) {
            [self loadMediaBundleSafe];
        }
        
        if (self.idDocuments.count > 0) {
            NSUInteger randomIndex = arc4random_uniform((uint32_t)self.idDocuments.count);
            return self.idDocuments[randomIndex];
        }
        
        return [self createPlaceholderImageSafe:@"ID Document"];
        
    } @catch (NSException *exception) {
        NSLog(@"[CustomVCAM] getRandomIDDocumentSafe failed: %@", exception.reason);
        return [self createPlaceholderImageSafe:@"ID Document (Error)"];
    }
}

- (UIImage *)getRandomSelfieSafe {
    @try {
        if (!self.initializationSafe) {
            return [self createPlaceholderImageSafe:@"Selfie (Safe Mode)"];
        }
        
        if (!self.mediaLoaded) {
            [self loadMediaBundleSafe];
        }
        
        if (self.selfiePhotos.count > 0) {
            NSUInteger randomIndex = arc4random_uniform((uint32_t)self.selfiePhotos.count);
            return self.selfiePhotos[randomIndex];
        }
        
        return [self createPlaceholderImageSafe:@"Selfie"];
        
    } @catch (NSException *exception) {
        NSLog(@"[CustomVCAM] getRandomSelfieSafe failed: %@", exception.reason);
        return [self createPlaceholderImageSafe:@"Selfie (Error)"];
    }
}

#pragma mark - SAFE Media Management

- (void)loadMediaBundleSafe {
    @try {
        NSLog(@"[CustomVCAM] MediaManager: Loading media bundle (SAFE)");
        
        if (!self.initializationSafe) {
            NSLog(@"[CustomVCAM] MediaManager: Cannot load media - unsafe initialization state");
            return;
        }
        
        if (self.mediaLoaded) {
            NSLog(@"[CustomVCAM] MediaManager: Media already loaded");
            return;
        }
        
        // NO FILE OPERATIONS - Just create in-memory placeholders
        NSMutableArray *loadedIDs = [NSMutableArray array];
        NSMutableArray *loadedSelfies = [NSMutableArray array];
        
        // Create safe placeholder content without file I/O
        [loadedIDs addObject:[self createPlaceholderImageSafe:@"Driver License"]];
        [loadedIDs addObject:[self createPlaceholderImageSafe:@"Passport"]];
        [loadedIDs addObject:[self createPlaceholderImageSafe:@"National ID"]];
        
        [loadedSelfies addObject:[self createPlaceholderImageSafe:@"Selfie 1"]];
        [loadedSelfies addObject:[self createPlaceholderImageSafe:@"Selfie 2"]];
        [loadedSelfies addObject:[self createPlaceholderImageSafe:@"Selfie 3"]];
        
        self.idDocuments = [loadedIDs copy];
        self.selfiePhotos = [loadedSelfies copy];
        self.mediaLoaded = YES;
        
        NSLog(@"[CustomVCAM] Loaded %lu ID documents, %lu selfies (SAFE MODE)", 
              (unsigned long)self.idDocuments.count, 
              (unsigned long)self.selfiePhotos.count);
              
    } @catch (NSException *exception) {
        NSLog(@"[CustomVCAM] loadMediaBundleSafe failed: %@", exception.reason);
        self.mediaLoaded = NO;
    }
}

- (NSArray<UIImage *> *)getAllIDDocumentsSafe {
    @try {
        if (!self.mediaLoaded) {
            [self loadMediaBundleSafe];
        }
        return self.idDocuments ?: @[];
    } @catch (NSException *exception) {
        NSLog(@"[CustomVCAM] getAllIDDocumentsSafe failed: %@", exception.reason);
        return @[];
    }
}

- (NSArray<UIImage *> *)getAllSelfiesSafe {
    @try {
        if (!self.mediaLoaded) {
            [self loadMediaBundleSafe];
        }
        return self.selfiePhotos ?: @[];
    } @catch (NSException *exception) {
        NSLog(@"[CustomVCAM] getAllSelfiesSafe failed: %@", exception.reason);
        return @[];
    }
}

#pragma mark - SAFE Utility Methods

- (UIImage *)createPlaceholderImageSafe:(NSString *)text {
    @try {
        if (!text || text.length == 0) {
            text = @"Media";
        }
        
        CGSize size = CGSizeMake(640, 480);
        UIGraphicsBeginImageContextWithOptions(size, NO, 0.0);
        
        CGContextRef context = UIGraphicsGetCurrentContext();
        if (!context) {
            NSLog(@"[CustomVCAM] Failed to create graphics context");
            return nil;
        }
        
        // Create a realistic looking document background
        CGContextSetFillColorWithColor(context, [UIColor colorWithRed:0.95 green:0.95 blue:0.95 alpha:1.0].CGColor);
        CGContextFillRect(context, CGRectMake(0, 0, size.width, size.height));
        
        // Add a border to make it look more document-like
        CGContextSetStrokeColorWithColor(context, [UIColor darkGrayColor].CGColor);
        CGContextSetLineWidth(context, 2.0);
        CGContextStrokeRect(context, CGRectMake(5, 5, size.width - 10, size.height - 10));
        
        // Add text
        NSDictionary *attributes = @{
            NSFontAttributeName: [UIFont boldSystemFontOfSize:24],
            NSForegroundColorAttributeName: [UIColor blackColor]
        };
        
        CGSize textSize = [text sizeWithAttributes:attributes];
        CGPoint textPoint = CGPointMake((size.width - textSize.width) / 2, (size.height - textSize.height) / 2);
        [text drawAtPoint:textPoint withAttributes:attributes];
        
        // Add "SAMPLE" watermark
        NSDictionary *watermarkAttributes = @{
            NSFontAttributeName: [UIFont systemFontOfSize:18],
            NSForegroundColorAttributeName: [UIColor colorWithRed:1.0 green:0.0 blue:0.0 alpha:0.5]
        };
        
        NSString *watermark = @"SAMPLE";
        CGSize watermarkSize = [watermark sizeWithAttributes:watermarkAttributes];
        CGPoint watermarkPoint = CGPointMake((size.width - watermarkSize.width) / 2, size.height - 60);
        [watermark drawAtPoint:watermarkPoint withAttributes:watermarkAttributes];
        
        UIImage *image = UIGraphicsGetImageFromCurrentImageContext();
        UIGraphicsEndImageContext();
        
        return image;
        
    } @catch (NSException *exception) {
        NSLog(@"[CustomVCAM] createPlaceholderImageSafe failed: %@", exception.reason);
        return nil;
    }
}

@end 