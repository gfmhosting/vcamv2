#import <UIKit/UIKit.h>
#import "Sources/MediaManager.h"

#define SYSTEM_VERSION_GREATER_THAN_OR_EQUAL_TO(v) ([[[UIDevice currentDevice] systemVersion] compare:v options:NSNumericSearch] != NSOrderedAscending)

%group iOS13SafeMode

%hook UIImagePickerController

- (void)setSourceType:(UIImagePickerControllerSourceType)sourceType {
    @try {
        if (SYSTEM_VERSION_GREATER_THAN_OR_EQUAL_TO(@"13.0") && 
            sourceType == UIImagePickerControllerSourceTypeCamera) {
            
            NSLog(@"[CustomVCAM] Camera redirect (SAFE MODE)");
            sourceType = UIImagePickerControllerSourceTypePhotoLibrary;
            
            // Safely attempt media injection only if MediaManager is available
            if ([MediaManager class]) {
                @try {
                    MediaManager *manager = [MediaManager sharedInstanceSafe];
                    if (manager) {
                        [manager injectMediaIntoPickerSafe:self];
                    }
                } @catch (NSException *mediaException) {
                    NSLog(@"[CustomVCAM] MediaManager injection failed safely: %@", mediaException.reason);
                }
            }
        }
    } @catch (NSException *exception) {
        NSLog(@"[CustomVCAM] Hook failed safely: %@", exception.reason);
    }
    
    %orig(sourceType);
}

- (void)presentViewController:(UIViewController *)viewControllerToPresent animated:(BOOL)flag completion:(void (^)(void))completion {
    @try {
        NSLog(@"[CustomVCAM] UIImagePickerController presentViewController intercepted (SAFE)");
        
        if ([viewControllerToPresent isKindOfClass:[UIImagePickerController class]]) {
            UIImagePickerController *picker = (UIImagePickerController *)viewControllerToPresent;
            if (picker.sourceType == UIImagePickerControllerSourceTypeCamera) {
                NSLog(@"[CustomVCAM] Camera access detected, redirecting to photo library (SAFE)");
                picker.sourceType = UIImagePickerControllerSourceTypePhotoLibrary;
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