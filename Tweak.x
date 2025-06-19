#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>
#import <AVFoundation/AVFoundation.h>
#import <CoreMedia/CoreMedia.h>
#import <CoreVideo/CoreVideo.h>
#import <MediaPlayer/MediaPlayer.h>
#import <AudioToolbox/AudioToolbox.h>
#import <IOKit/hid/IOHIDEventSystem.h>
#import <IOKit/hid/IOHIDEventTypes.h>
#import <substrate.h>
#import "Sources/MediaManager.h"
#import "Sources/OverlayView.h"
#import "Sources/SimpleMediaManager.h"

static BOOL vcamEnabled = NO;
static BOOL vcamActive = NO;
static NSString *selectedMediaPath = nil;
static MediaManager *mediaManager = nil;
static OverlayView *overlayView = nil;

// Enhanced cross-process communication system
#define VCAM_APP_GROUP @"group.com.customvcam.vcam"
#define VCAM_PREFS_DOMAIN @"group.com.customvcam.vcam"
#define VCAM_ACTIVE_KEY @"vcamActive"
#define VCAM_MEDIA_PATH_KEY @"selectedMediaPath"
#define VCAM_STATE_VERSION_KEY @"vcamStateVersion"
#define VCAM_FALLBACK_FILE @"vcam_state.json"

// CFNotificationCenter notifications for real-time updates
#define VCAM_STATE_CHANGED_NOTIFICATION CFSTR("com.customvcam.vcam.stateChanged")

// Thread-safe state management
static dispatch_queue_t vcamStateQueue;
static NSInteger currentStateVersion = 0;

// Robust state management with validation and fallback
static NSDictionary *createStateDict(BOOL active, NSString *mediaPath) {
    return @{
        VCAM_ACTIVE_KEY: @(active),
        VCAM_MEDIA_PATH_KEY: mediaPath ?: @"",
        VCAM_STATE_VERSION_KEY: @(++currentStateVersion),
        @"timestamp": @([[NSDate date] timeIntervalSince1970]),
        @"processID": [[NSBundle mainBundle] bundleIdentifier] ?: @"unknown"
    };
}

static BOOL validateStateDict(NSDictionary *state) {
    if (!state || ![state isKindOfClass:[NSDictionary class]]) {
        NSLog(@"[CustomVCAM] Invalid state dictionary: not a dictionary");
        return NO;
    }
    
    // Check required keys
    if (![state objectForKey:VCAM_ACTIVE_KEY] || ![state objectForKey:VCAM_MEDIA_PATH_KEY]) {
        NSLog(@"[CustomVCAM] Invalid state dictionary: missing required keys");
        return NO;
    }
    
    // Check timestamp (reject states older than 5 minutes)
    NSNumber *timestamp = [state objectForKey:@"timestamp"];
    if (timestamp && [[NSDate date] timeIntervalSince1970] - [timestamp doubleValue] > 300) {
        NSLog(@"[CustomVCAM] Invalid state dictionary: too old (%.1fs)", [[NSDate date] timeIntervalSince1970] - [timestamp doubleValue]);
        return NO;
    }
    
    return YES;
}

// File-based fallback storage (inspired by Christian Selig's approach)
static NSURL *getSharedStateFileURL(void) {
    NSFileManager *fileManager = [NSFileManager defaultManager];
    NSURL *containerURL = [fileManager containerURLForSecurityApplicationGroupIdentifier:VCAM_APP_GROUP];
    
    if (!containerURL) {
        // Fallback to shared temp directory if App Group not available
        NSLog(@"[CustomVCAM] App Group not available, using temp directory fallback");
        return [[NSURL fileURLWithPath:NSTemporaryDirectory()] URLByAppendingPathComponent:VCAM_FALLBACK_FILE];
    }
    
    return [containerURL URLByAppendingPathComponent:VCAM_FALLBACK_FILE];
}

static BOOL saveStateToFile(NSDictionary *state) {
    NSURL *fileURL = getSharedStateFileURL();
    
    @try {
        NSData *jsonData = [NSJSONSerialization dataWithJSONObject:state options:0 error:nil];
        if (!jsonData) {
            NSLog(@"[CustomVCAM] Failed to serialize state to JSON");
            return NO;
        }
        
        BOOL success = [jsonData writeToURL:fileURL atomically:YES];
        if (success) {
            // Set no encryption for maximum accessibility
            [NSFileManager.defaultManager setAttributes:@{NSFileProtectionKey: NSFileProtectionNone} 
                                           ofItemAtPath:fileURL.path 
                                                  error:nil];
            NSLog(@"[CustomVCAM] State saved to file: %@", fileURL.path);
        }
        return success;
    } @catch (NSException *e) {
        NSLog(@"[CustomVCAM] Exception saving state to file: %@", e.reason);
        return NO;
    }
}

static NSDictionary *loadStateFromFile(void) {
    NSURL *fileURL = getSharedStateFileURL();
    
    @try {
        NSData *jsonData = [NSData dataWithContentsOfURL:fileURL];
        if (!jsonData) {
            NSLog(@"[CustomVCAM] No state file found at: %@", fileURL.path);
            return nil;
        }
        
        NSDictionary *state = [NSJSONSerialization JSONObjectWithData:jsonData options:0 error:nil];
        if (validateStateDict(state)) {
            NSLog(@"[CustomVCAM] State loaded from file: active=%@, path=%@", 
                  [state objectForKey:VCAM_ACTIVE_KEY], [state objectForKey:VCAM_MEDIA_PATH_KEY]);
            return state;
        } else {
            NSLog(@"[CustomVCAM] Invalid state in file, ignoring");
            return nil;
        }
    } @catch (NSException *e) {
        NSLog(@"[CustomVCAM] Exception loading state from file: %@", e.reason);
        return nil;
    }
}

// Enhanced NSUserDefaults with validation
static BOOL saveStateToUserDefaults(NSDictionary *state) {
    @try {
        NSUserDefaults *prefs = [[NSUserDefaults alloc] initWithSuiteName:VCAM_PREFS_DOMAIN];
        if (!prefs) {
            NSLog(@"[CustomVCAM] Failed to create NSUserDefaults with suite: %@", VCAM_PREFS_DOMAIN);
            return NO;
        }
        
        // Save individual values
        [prefs setBool:[[state objectForKey:VCAM_ACTIVE_KEY] boolValue] forKey:VCAM_ACTIVE_KEY];
        [prefs setObject:[state objectForKey:VCAM_MEDIA_PATH_KEY] forKey:VCAM_MEDIA_PATH_KEY];
        [prefs setInteger:[[state objectForKey:VCAM_STATE_VERSION_KEY] integerValue] forKey:VCAM_STATE_VERSION_KEY];
        [prefs setDouble:[[state objectForKey:@"timestamp"] doubleValue] forKey:@"timestamp"];
        
        BOOL success = [prefs synchronize];
        if (success) {
            NSLog(@"[CustomVCAM] State saved to NSUserDefaults: active=%@, path=%@", 
                  [state objectForKey:VCAM_ACTIVE_KEY], [state objectForKey:VCAM_MEDIA_PATH_KEY]);
        } else {
            NSLog(@"[CustomVCAM] Failed to synchronize NSUserDefaults");
        }
        return success;
    } @catch (NSException *e) {
        NSLog(@"[CustomVCAM] Exception saving to NSUserDefaults: %@", e.reason);
        return NO;
    }
}

static NSDictionary *loadStateFromUserDefaults(void) {
    @try {
        NSUserDefaults *prefs = [[NSUserDefaults alloc] initWithSuiteName:VCAM_PREFS_DOMAIN];
        if (!prefs) {
            NSLog(@"[CustomVCAM] Failed to create NSUserDefaults with suite: %@", VCAM_PREFS_DOMAIN);
            return nil;
        }
        
        // Check if any data exists
        NSObject *activeObj = [prefs objectForKey:VCAM_ACTIVE_KEY];
        if (!activeObj) {
            NSLog(@"[CustomVCAM] No data in NSUserDefaults");
            return nil;
        }
        
        NSDictionary *state = @{
            VCAM_ACTIVE_KEY: @([prefs boolForKey:VCAM_ACTIVE_KEY]),
            VCAM_MEDIA_PATH_KEY: [prefs stringForKey:VCAM_MEDIA_PATH_KEY] ?: @"",
            VCAM_STATE_VERSION_KEY: @([prefs integerForKey:VCAM_STATE_VERSION_KEY]),
            @"timestamp": @([prefs doubleForKey:@"timestamp"])
        };
        
        if (validateStateDict(state)) {
            NSLog(@"[CustomVCAM] State loaded from NSUserDefaults: active=%@, path=%@", 
                  [state objectForKey:VCAM_ACTIVE_KEY], [state objectForKey:VCAM_MEDIA_PATH_KEY]);
            return state;
        } else {
            NSLog(@"[CustomVCAM] Invalid state in NSUserDefaults");
            return nil;
        }
    } @catch (NSException *e) {
        NSLog(@"[CustomVCAM] Exception loading from NSUserDefaults: %@", e.reason);
        return nil;
    }
}

// Unified state management with multiple storage backends
static void setSharedVCAMState(BOOL active, NSString *mediaPath) {
    dispatch_async(vcamStateQueue, ^{
        NSDictionary *state = createStateDict(active, mediaPath);
        
        // Save to both NSUserDefaults and file for redundancy
        BOOL userDefaultsSuccess = saveStateToUserDefaults(state);
        BOOL fileSuccess = saveStateToFile(state);
        
        if (!userDefaultsSuccess && !fileSuccess) {
            NSLog(@"[CustomVCAM] CRITICAL: Failed to save state to both backends!");
        } else if (!userDefaultsSuccess) {
            NSLog(@"[CustomVCAM] Warning: NSUserDefaults failed, but file storage succeeded");
        } else if (!fileSuccess) {
            NSLog(@"[CustomVCAM] Warning: File storage failed, but NSUserDefaults succeeded");
        }
        
        // Send notification to other processes
        CFNotificationCenterPostNotification(CFNotificationCenterGetDarwinCenter(),
                                           VCAM_STATE_CHANGED_NOTIFICATION,
                                           NULL, NULL, TRUE);
        
        NSLog(@"[CustomVCAM] State broadcast: active=%d, path=%@", active, mediaPath);
    });
}

static void loadSharedVCAMState(void) {
    dispatch_sync(vcamStateQueue, ^{
        NSDictionary *state = nil;
        
        // Try NSUserDefaults first, then file fallback
        state = loadStateFromUserDefaults();
        if (!state) {
            NSLog(@"[CustomVCAM] NSUserDefaults failed, trying file fallback");
            state = loadStateFromFile();
        }
        
        if (state) {
            vcamActive = [[state objectForKey:VCAM_ACTIVE_KEY] boolValue];
            NSString *path = [state objectForKey:VCAM_MEDIA_PATH_KEY];
            selectedMediaPath = ([path length] > 0) ? path : nil;
            currentStateVersion = [[state objectForKey:VCAM_STATE_VERSION_KEY] integerValue];
            
            NSLog(@"[CustomVCAM] Loaded shared state: active=%d, path=%@, version=%ld", 
                  vcamActive, selectedMediaPath, (long)currentStateVersion);
        } else {
            NSLog(@"[CustomVCAM] No valid state found, using defaults");
            vcamActive = NO;
            selectedMediaPath = nil;
            currentStateVersion = 0;
        }
    });
}

// Real-time state update notification handler
static void handleStateChangeNotification(CFNotificationCenterRef center, void *observer, CFStringRef name, const void *object, CFDictionaryRef userInfo) {
    NSLog(@"[CustomVCAM] Received state change notification");
    
    // Reload state in non-SpringBoard processes
    if (!isSpringBoardProcess) {
        loadSharedVCAMState();
        
        // Reinitialize MediaManager if needed
        if (vcamActive && selectedMediaPath && !mediaManager) {
            mediaManager = [[MediaManager alloc] init];
            NSLog(@"[CustomVCAM] MediaManager reinitialized after state change");
        }
    }
}

@interface CustomVCAMDelegate : NSObject <OverlayViewDelegate>
@end

@implementation CustomVCAMDelegate

- (void)overlayView:(id)overlayView didSelectMediaAtPath:(NSString *)mediaPath {
    NSLog(@"[CustomVCAM] Media selected: %@", mediaPath);
    
    // Validate media file exists and is accessible
    if (!mediaPath || ![mediaPath length] || ![[NSFileManager defaultManager] fileExistsAtPath:mediaPath]) {
        NSLog(@"[CustomVCAM] ERROR: Selected media file is invalid or missing: %@", mediaPath);
        [self overlayViewDidCancel:overlayView];
        return;
    }
    
    selectedMediaPath = mediaPath;
    vcamActive = YES;
    
    // Share state across processes with robust error handling
    setSharedVCAMState(YES, mediaPath);
    
    if ([mediaManager setMediaFromPath:mediaPath]) {
        NSLog(@"[CustomVCAM] Media injection activated for Stripe bypass");
        NSLog(@"[CustomVCAM] Camera replacement now active in all processes");
    } else {
        NSLog(@"[CustomVCAM] Failed to set media for injection, reverting state");
        vcamActive = NO;
        selectedMediaPath = nil;
        setSharedVCAMState(NO, nil);
    }
}

- (void)overlayViewDidCancel:(id)overlayView {
    NSLog(@"[CustomVCAM] Media selection cancelled");
    vcamActive = NO;
    selectedMediaPath = nil;
    setSharedVCAMState(NO, nil);
}

@end

// Forward declarations
static void handleVolumeButtonPress(BOOL isVolumeUp);
static void resetVolumeButtonState(void);

// SpringBoard volume button tracking
static NSTimeInterval lastVolumeButtonTime = 0;
static NSInteger volumeButtonCount = 0;
static BOOL isSpringBoardProcess = NO;
static CustomVCAMDelegate *vcamDelegate = nil;

static void handleVolumeButtonPress(BOOL isVolumeUp) {
    NSLog(@"[CustomVCAM] Volume button pressed: %s", isVolumeUp ? "UP" : "DOWN");
    
    NSTimeInterval currentTime = [[NSDate date] timeIntervalSince1970];
    
    if (currentTime - lastVolumeButtonTime < 0.8) {
        volumeButtonCount++;
        NSLog(@"[CustomVCAM] Volume button count: %ld (within 0.8s)", (long)volumeButtonCount);
        
        if (volumeButtonCount >= 2) {
            NSLog(@"[CustomVCAM] DOUBLE-TAP DETECTED! Triggering media picker");
            dispatch_async(dispatch_get_main_queue(), ^{
                if (!overlayView) {
                    overlayView = [[OverlayView alloc] init];
                    overlayView.delegate = vcamDelegate;
                }
                [overlayView showMediaPicker];
            });
            
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                resetVolumeButtonState();
            });
            return;
        }
    } else {
        volumeButtonCount = 1;
        NSLog(@"[CustomVCAM] First volume button press detected");
    }
    
    lastVolumeButtonTime = currentTime;
    
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.8 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        if ([[NSDate date] timeIntervalSince1970] - lastVolumeButtonTime >= 0.8) {
            resetVolumeButtonState();
        }
    });
}

static void resetVolumeButtonState() {
    volumeButtonCount = 0;
    NSLog(@"[CustomVCAM] Volume button state reset");
}

// SpringBoard volume button hooks
@interface SBVolumeControl : NSObject
- (void)increaseVolume;
- (void)decreaseVolume;
- (void)_changeVolumeBy:(float)arg1;
@end

%hook SBVolumeControl

- (void)increaseVolume {
    NSLog(@"[CustomVCAM] SpringBoard volume UP detected");
    if (isSpringBoardProcess) {
        handleVolumeButtonPress(YES);
    }
    %orig;
}

- (void)decreaseVolume {
    NSLog(@"[CustomVCAM] SpringBoard volume DOWN detected");
    if (isSpringBoardProcess) {
        handleVolumeButtonPress(NO);
    }
    %orig;
}

%end

// Alternative hook for iOS 13
@interface SBHUDController : NSObject
- (void)_presentHUD:(id)arg1 autoDismissWithDelay:(double)arg2;
@end

%hook SBHUDController

- (void)_presentHUD:(id)hud autoDismissWithDelay:(double)delay {
    NSLog(@"[CustomVCAM] SBHUDController HUD presented: %@", hud);
    
    // Check if this is a volume HUD
    NSString *hudClassName = NSStringFromClass([hud class]);
    if ([hudClassName containsString:@"Volume"] || [hudClassName containsString:@"SBRingerHUD"]) {
        NSLog(@"[CustomVCAM] Volume HUD detected via SBHUDController");
        if (isSpringBoardProcess) {
            handleVolumeButtonPress(YES); // We can't easily determine up/down here
        }
    }
    
    %orig;
}

%end

%hook AVCaptureVideoDataOutput

- (void)captureOutput:(AVCaptureOutput *)output didOutputSampleBuffer:(CMSampleBufferRef)sampleBuffer fromConnection:(AVCaptureConnection *)connection {
    // Refresh shared state for real-time updates (non-SpringBoard processes)
    if (!isSpringBoardProcess) {
        static NSTimeInterval lastStateCheck = 0;
        NSTimeInterval now = [[NSDate date] timeIntervalSince1970];
        
        // Check state every 0.5 seconds or if we haven't loaded yet
        if (now - lastStateCheck > 0.5 || currentStateVersion == 0) {
            loadSharedVCAMState();
            lastStateCheck = now;
        }
    }
    
    if (vcamActive && selectedMediaPath && [selectedMediaPath length] > 0) {
        NSLog(@"[CustomVCAM] Camera capture detected - replacing with: %@", selectedMediaPath);
        
        // Ensure MediaManager is initialized for non-SpringBoard processes
        if (!mediaManager) {
            mediaManager = [[MediaManager alloc] init];
            NSLog(@"[CustomVCAM] MediaManager initialized for camera replacement");
        }
        
        // Validate media file exists before processing
        if ([[NSFileManager defaultManager] fileExistsAtPath:selectedMediaPath]) {
            CMSampleBufferRef modifiedBuffer = [mediaManager createSampleBufferFromMediaPath:selectedMediaPath];
            if (modifiedBuffer) {
                NSLog(@"[CustomVCAM] Successfully created replacement sample buffer");
                %orig(output, modifiedBuffer, connection);
                CFRelease(modifiedBuffer);
                return;
            } else {
                NSLog(@"[CustomVCAM] Failed to create replacement sample buffer, disabling VCAM");
                // Disable VCAM if media processing fails
                setSharedVCAMState(NO, nil);
            }
        } else {
            NSLog(@"[CustomVCAM] Media file no longer exists: %@, disabling VCAM", selectedMediaPath);
            setSharedVCAMState(NO, nil);
        }
    }
    
    %orig;
}

%end

%ctor {
    NSString *bundleIdentifier = [[NSBundle mainBundle] bundleIdentifier];
    isSpringBoardProcess = [bundleIdentifier isEqualToString:@"com.apple.springboard"];
    
    // Initialize thread-safe state management queue
    vcamStateQueue = dispatch_queue_create("com.customvcam.vcam.state", DISPATCH_QUEUE_SERIAL);
    
    NSLog(@"[CustomVCAM] Tweak loaded in process: %@ (SpringBoard: %@)", bundleIdentifier, isSpringBoardProcess ? @"YES" : @"NO");
    
    if (isSpringBoardProcess) {
        // SpringBoard: Handle volume buttons and media selection
        mediaManager = [[MediaManager alloc] init];
        vcamDelegate = [[CustomVCAMDelegate alloc] init];
        vcamEnabled = YES;
        
        // Load existing state to maintain persistence across SpringBoard restarts
        loadSharedVCAMState();
        
        NSLog(@"[CustomVCAM] Media manager initialized, VCAM enabled for Stripe bypass");
        NSLog(@"[CustomVCAM] SpringBoard volume button hooks active for iPhone 7 iOS 13.3.1");
        NSLog(@"[CustomVCAM] Robust cross-process communication initialized");
    } else {
        // Camera/Safari: Load shared state and prepare for camera replacement
        loadSharedVCAMState();
        
        // Register for real-time state change notifications
        CFNotificationCenterAddObserver(CFNotificationCenterGetDarwinCenter(),
                                      NULL,
                                      handleStateChangeNotification,
                                      VCAM_STATE_CHANGED_NOTIFICATION,
                                      NULL,
                                      CFNotificationSuspensionBehaviorDeliverImmediately);
        
        // Initialize MediaManager if we have active state
        if (vcamActive && selectedMediaPath) {
            mediaManager = [[MediaManager alloc] init];
            NSLog(@"[CustomVCAM] MediaManager pre-initialized for active VCAM state");
        }
        
        NSLog(@"[CustomVCAM] Camera replacement ready in %@", bundleIdentifier);
        NSLog(@"[CustomVCAM] Loaded state: active=%d, path=%@, version=%ld", vcamActive, selectedMediaPath, (long)currentStateVersion);
        NSLog(@"[CustomVCAM] Real-time state notifications registered");
    }
} 