#import <AVFoundation/AVFoundation.h>
#import <UIKit/UIKit.h>

@interface MediaProcessor : NSObject <AVCaptureVideoDataOutputSampleBufferDelegate>
@property (nonatomic, assign) BOOL isEnabled;
@property (nonatomic, strong) UIImage *selectedImage;

+ (instancetype)sharedInstance;
- (void)setSelectedImage:(UIImage *)image;
- (CVPixelBufferRef)createPixelBufferFromImage:(UIImage *)image;
@end

@interface VCAMOverlay : NSObject
@property (nonatomic, strong) UIWindow *overlayWindow;
@property (nonatomic, strong) UIViewController *rootViewController;

+ (instancetype)sharedInstance;
- (void)showOverlay;
- (void)hideOverlay;
- (void)showDebugOverlay;
@end

// Global variables for settings
static BOOL enabled = YES;
static BOOL debugLogging = NO;

// Implementation of MediaProcessor
@implementation MediaProcessor {
    CVPixelBufferRef _cachedPixelBuffer;
}

+ (instancetype)sharedInstance {
    static MediaProcessor *sharedInstance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedInstance = [[self alloc] init];
    });
    return sharedInstance;
}

- (void)captureOutput:(AVCaptureOutput *)output didOutputSampleBuffer:(CMSampleBufferRef)sampleBuffer fromConnection:(AVCaptureConnection *)connection {
    if (!self.isEnabled || !self.selectedImage) {
        return;
    }
    
    if (!_cachedPixelBuffer) {
        _cachedPixelBuffer = [self createPixelBufferFromImage:self.selectedImage];
    }
    
    if (_cachedPixelBuffer) {
        // Get the image buffer from the sample buffer
        CVImageBufferRef imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer);
        
        // Replace the image buffer with our cached pixel buffer
        // This is a simplified approach - in a real implementation, you would
        // need to properly handle the buffer replacement
        if (imageBuffer && _cachedPixelBuffer) {
            // In a real implementation, you would modify the sample buffer here
            if (debugLogging) {
                NSLog(@"[StripeVCAM] Replacing camera frame with custom image");
            }
        }
    }
}

- (CVPixelBufferRef)createPixelBufferFromImage:(UIImage *)image {
    CGImageRef cgImage = [image CGImage];
    if (!cgImage) return NULL;
    
    size_t width = CGImageGetWidth(cgImage);
    size_t height = CGImageGetHeight(cgImage);
    
    CVPixelBufferRef pixelBuffer = NULL;
    CVReturn status = CVPixelBufferCreate(kCFAllocatorDefault, width, height, kCVPixelFormatType_32ARGB, NULL, &pixelBuffer);
    
    if (status != kCVReturnSuccess || !pixelBuffer) {
        if (debugLogging) {
            NSLog(@"[StripeVCAM] Failed to create pixel buffer: %d", status);
        }
        return NULL;
    }
    
    CVPixelBufferLockBaseAddress(pixelBuffer, 0);
    void *baseAddress = CVPixelBufferGetBaseAddress(pixelBuffer);
    
    CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
    CGContextRef context = CGBitmapContextCreate(baseAddress, width, height, 8, CVPixelBufferGetBytesPerRow(pixelBuffer), 
                                               colorSpace, kCGImageAlphaNoneSkipFirst);
    
    CGContextDrawImage(context, CGRectMake(0, 0, width, height), cgImage);
    
    CGColorSpaceRelease(colorSpace);
    CGContextRelease(context);
    CVPixelBufferUnlockBaseAddress(pixelBuffer, 0);
    
    return pixelBuffer;
}

- (void)setSelectedImage:(UIImage *)image {
    _selectedImage = image;
    
    if (_cachedPixelBuffer) {
        CVPixelBufferRelease(_cachedPixelBuffer);
        _cachedPixelBuffer = NULL;
    }
    
    if (image) {
        _cachedPixelBuffer = [self createPixelBufferFromImage:image];
    }
}

- (void)dealloc {
    if (_cachedPixelBuffer) {
        CVPixelBufferRelease(_cachedPixelBuffer);
    }
}

@end

// Main hooks
%hook AVCaptureVideoDataOutput
- (void)setSampleBufferDelegate:(id)delegate queue:(dispatch_queue_t)queue {
    if (enabled) {
        if (debugLogging) {
            NSLog(@"[StripeVCAM] Intercepting setSampleBufferDelegate");
        }
        %orig([MediaProcessor sharedInstance], queue);
    } else {
        %orig;
    }
}
%end

%hook AVCaptureSession
- (void)startRunning {
    if (debugLogging) {
        NSLog(@"[StripeVCAM] AVCaptureSession startRunning");
    }
    %orig;
}
%end

// Volume button hook
%hook SpringBoard
- (void)_handleVolumeEvent:(id)event {
    // Simple double-tap detection would go here
    // For now, just show the overlay when any volume button is pressed
    if (enabled) {
        // Check if this is a volume button press
        // In a real implementation, you would check the event type and handle double-taps
        
        // For demonstration, show overlay on any volume press
        dispatch_async(dispatch_get_main_queue(), ^{
            [[VCAMOverlay sharedInstance] showOverlay];
        });
        
        if (debugLogging) {
            NSLog(@"[StripeVCAM] Volume button pressed, showing overlay");
        }
    }
    
    %orig;
}
%end

// Load preferences
static void loadPrefs() {
    NSDictionary *settings = [NSDictionary dictionaryWithContentsOfFile:@"/var/mobile/Library/Preferences/com.yourusername.stripevcambypass.plist"];
    enabled = settings[@"enabled"] ? [settings[@"enabled"] boolValue] : YES;
    debugLogging = settings[@"debugLogging"] ? [settings[@"debugLogging"] boolValue] : NO;
    
    if (debugLogging) {
        NSLog(@"[StripeVCAM] Preferences loaded - enabled: %d, debugLogging: %d", enabled, debugLogging);
    }
}

%ctor {
    loadPrefs();
    
    // Register for preference change notifications
    CFNotificationCenterAddObserver(
        CFNotificationCenterGetDarwinNotifyCenter(),
        NULL,
        (CFNotificationCallback)loadPrefs,
        CFSTR("com.yourusername.stripevcambypass/prefsChanged"),
        NULL,
        CFNotificationSuspensionBehaviorCoalesce
    );
    
    if (debugLogging) {
        NSLog(@"[StripeVCAM] Tweak initialized");
    }
} 