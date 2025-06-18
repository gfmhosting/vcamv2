#import <UIKit/UIKit.h>
#import "Sources/MediaManager.h"

#define SYSTEM_VERSION_GREATER_THAN_OR_EQUAL_TO(v) ([[[UIDevice currentDevice] systemVersion] compare:v options:NSNumericSearch] != NSOrderedAscending)

%group iOS13SafeMode

%hook UIImagePickerController

- (void)setSourceType:(UIImagePickerControllerSourceType)sourceType {
    @try {
        NSString *bundleID = [[NSBundle mainBundle] bundleIdentifier];
        
        if (SYSTEM_VERSION_GREATER_THAN_OR_EQUAL_TO(@"13.0") && 
            sourceType == UIImagePickerControllerSourceTypeCamera) {
            
            NSLog(@"[CustomVCAM] 🚫 Camera setSourceType BLOCKED in %@ - switching to photo library", bundleID);
            sourceType = UIImagePickerControllerSourceTypePhotoLibrary;
            
            // Safely attempt media injection only if MediaManager is available
            if ([MediaManager class]) {
                @try {
                    MediaManager *manager = [MediaManager sharedInstanceSafe];
                    if (manager) {
                        [manager injectMediaIntoPickerSafe:self];
                        NSLog(@"[CustomVCAM] ✅ MediaManager injection completed for %@", bundleID);
                    }
                } @catch (NSException *mediaException) {
                    NSLog(@"[CustomVCAM] ⚠️ MediaManager injection failed safely: %@", mediaException.reason);
                }
            }
        } else {
            NSLog(@"[CustomVCAM] setSourceType called in %@ - sourceType: %ld (not blocking)", bundleID, (long)sourceType);
        }
    } @catch (NSException *exception) {
        NSLog(@"[CustomVCAM] setSourceType hook failed safely: %@", exception.reason);
    }
    
    %orig(sourceType);
}

- (void)presentViewController:(UIViewController *)viewControllerToPresent animated:(BOOL)flag completion:(void (^)(void))completion {
    @try {
        NSString *bundleID = [[NSBundle mainBundle] bundleIdentifier];
        NSLog(@"[CustomVCAM] UIImagePickerController presentViewController intercepted in %@ (SAFE)", bundleID);
        
        if ([viewControllerToPresent isKindOfClass:[UIImagePickerController class]]) {
            UIImagePickerController *picker = (UIImagePickerController *)viewControllerToPresent;
            if (picker.sourceType == UIImagePickerControllerSourceTypeCamera) {
                NSLog(@"[CustomVCAM] 🎯 CAMERA ACCESS BLOCKED in %@ - redirecting to photo library", bundleID);
                picker.sourceType = UIImagePickerControllerSourceTypePhotoLibrary;
                
                // Special handling for Safari web KYC
                if ([bundleID isEqualToString:@"com.apple.mobilesafari"]) {
                    NSLog(@"[CustomVCAM] 🌐 WEB KYC DETECTED - Safari camera redirect active");
                }
            }
        }
    } @catch (NSException *exception) {
        NSLog(@"[CustomVCAM] presentViewController hook failed safely: %@", exception.reason);
    }
    
    %orig;
}

%end

%end // iOS13SafeMode

%ctor {
    @try {
        NSLog(@"[CustomVCAM] Initializing CustomVCAM tweak (SAFE MODE) for iOS %@", [[UIDevice currentDevice] systemVersion]);
        
        if (SYSTEM_VERSION_GREATER_THAN_OR_EQUAL_TO(@"13.0")) {
            %init(iOS13SafeMode);
            NSLog(@"[CustomVCAM] iOS 13+ safe hooks loaded successfully");
        } else {
            NSLog(@"[CustomVCAM] Unsupported iOS version - tweak disabled");
        }
        
        // DO NOT initialize MediaManager during boot - wait for actual use
        NSLog(@"[CustomVCAM] Tweak initialization completed safely");
        
    } @catch (NSException *exception) {
        NSLog(@"[CustomVCAM] CRITICAL: Tweak initialization failed: %@", exception.reason);
    }
} 