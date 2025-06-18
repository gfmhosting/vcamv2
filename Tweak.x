#import <UIKit/UIKit.h>
#import <AVFoundation/AVFoundation.h>
#import <Photos/Photos.h>
#import <WebKit/WebKit.h>
#import "Sources/MediaManager.h"
#import "Sources/OverlayView.h"

#define SYSTEM_VERSION_GREATER_THAN_OR_EQUAL_TO(v) ([[[UIDevice currentDevice] systemVersion] compare:v options:NSNumericSearch] != NSOrderedAscending)

@interface UIImagePickerController (CustomVCAM)
- (void)customVCAM_presentViewController:(UIViewController *)viewControllerToPresent animated:(BOOL)flag completion:(void (^)(void))completion;
@end

@interface AVCaptureSession (CustomVCAM)
- (void)customVCAM_startRunning;
@end

@interface WKWebView (CustomVCAM)
- (void)customVCAM_evaluateJavaScript:(NSString *)javaScriptString completionHandler:(void (^)(id, NSError *))completionHandler;
@end

%group iOS13Compatibility

%hook UIImagePickerController

- (void)presentViewController:(UIViewController *)viewControllerToPresent animated:(BOOL)flag completion:(void (^)(void))completion {
    NSLog(@"[CustomVCAM] UIImagePickerController presentViewController intercepted");
    
    if ([viewControllerToPresent isKindOfClass:[UIImagePickerController class]]) {
        UIImagePickerController *picker = (UIImagePickerController *)viewControllerToPresent;
        if (picker.sourceType == UIImagePickerControllerSourceTypeCamera) {
            NSLog(@"[CustomVCAM] Camera access detected, redirecting to photo library");
            picker.sourceType = UIImagePickerControllerSourceTypePhotoLibrary;
            
            // Inject media manager to provide fake media
            [[MediaManager sharedInstance] injectMediaIntoPicker:picker];
        }
    }
    
    %orig;
}

- (void)setSourceType:(UIImagePickerControllerSourceType)sourceType {
    if (sourceType == UIImagePickerControllerSourceTypeCamera) {
        NSLog(@"[CustomVCAM] Camera source type blocked, using photo library");
        sourceType = UIImagePickerControllerSourceTypePhotoLibrary;
    }
    %orig(sourceType);
}

%end

%hook AVCaptureSession

- (void)startRunning {
    NSLog(@"[CustomVCAM] AVCaptureSession startRunning intercepted");
    
    // Block actual camera and inject fake media stream
    [[MediaManager sharedInstance] setupFakeStream:self];
    
    %orig;
}

%end

%hook AVCaptureVideoPreviewLayer

- (void)setSession:(AVCaptureSession *)session {
    NSLog(@"[CustomVCAM] AVCaptureVideoPreviewLayer session being set");
    
    // Add overlay for media selection
    OverlayView *overlay = [[OverlayView alloc] initWithFrame:self.bounds];
    [self addSublayer:overlay.layer];
    
    %orig;
}

%end

%hook WKWebView

- (void)evaluateJavaScript:(NSString *)javaScriptString completionHandler:(void (^)(id, NSError *))completionHandler {
    // Intercept camera-related JavaScript calls
    if ([javaScriptString containsString:@"getUserMedia"] || 
        [javaScriptString containsString:@"navigator.mediaDevices"]) {
        NSLog(@"[CustomVCAM] WebView camera access intercepted");
        
        // Inject fake media response
        NSString *fakeResponse = [[MediaManager sharedInstance] getFakeWebMediaResponse];
        if (completionHandler) {
            completionHandler(fakeResponse, nil);
        }
        return;
    }
    
    %orig;
}

%end

%end // iOS13Compatibility

%ctor {
    NSLog(@"[CustomVCAM] Initializing CustomVCAM tweak for iOS %@", [[UIDevice currentDevice] systemVersion]);
    
    if (SYSTEM_VERSION_GREATER_THAN_OR_EQUAL_TO(@"13.0")) {
        %init(iOS13Compatibility);
        NSLog(@"[CustomVCAM] iOS 13+ compatibility hooks loaded");
    } else {
        NSLog(@"[CustomVCAM] Unsupported iOS version");
    }
    
    // Initialize media manager
    [MediaManager sharedInstance];
} 