#import <UIKit/UIKit.h>
#import "Sources/MediaManager.h"

#define SYSTEM_VERSION_GREATER_THAN_OR_EQUAL_TO(v) ([[[UIDevice currentDevice] systemVersion] compare:v options:NSNumericSearch] != NSOrderedAscending)

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

// Add UIApplication hook for diagnostics
%hook UIApplication

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
    @try {
        NSString *bundleID = [[NSBundle mainBundle] bundleIdentifier];
        NSLog(@"[CustomVCAM] 🔍 DIAGNOSTIC: App launched - Bundle: %@", bundleID);
        
        if ([bundleID isEqualToString:@"com.apple.camera"] || 
            [bundleID isEqualToString:@"com.apple.mobilesafari"]) {
            NSLog(@"[CustomVCAM] 🎯 TARGET APP DETECTED: %@ - CustomVCAM is active!", bundleID);
        }
    } @catch (NSException *exception) {
        NSLog(@"[CustomVCAM] didFinishLaunchingWithOptions hook failed: %@", exception.reason);
    }
    
    return %orig;
}

%end

%ctor {
    @try {
        NSString *bundleID = [[NSBundle mainBundle] bundleIdentifier];
        NSLog(@"[CustomVCAM] 🚀 STARTUP: CustomVCAM v1.0.5 loading in %@ (iOS %@)", bundleID, [[UIDevice currentDevice] systemVersion]);
        
        if (SYSTEM_VERSION_GREATER_THAN_OR_EQUAL_TO(@"13.0")) {
            %init;
            NSLog(@"[CustomVCAM] ✅ ALL HOOKS LOADED - CustomVCAM is active in %@", bundleID);
        } else {
            NSLog(@"[CustomVCAM] ❌ UNSUPPORTED iOS VERSION - tweak disabled");
        }
        
        // Immediate diagnostic test
        NSLog(@"[CustomVCAM] 📊 DIAGNOSTIC: MobileSubstrate injection successful");
        
    } @catch (NSException *exception) {
        NSLog(@"[CustomVCAM] 💥 CRITICAL FAILURE: %@", exception.reason);
    }
} 