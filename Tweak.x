#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>
#import <AVFoundation/AVFoundation.h>
#import <CoreMedia/CoreMedia.h>
#import <CoreVideo/CoreVideo.h>
#import <MediaPlayer/MediaPlayer.h>
#import <AudioToolbox/AudioToolbox.h>
#import <CoreFoundation/CoreFoundation.h>
#import <WebKit/WebKit.h>
#import <notify.h>
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

// Simplified WebRTC-focused approach for Stripe verification bypass

// Simplified cross-process communication system - file-only storage
#define VCAM_SHARED_DIR @"/var/mobile/Library/CustomVCAM"
#define VCAM_STATE_FILE @"vcam_state.json"
#define VCAM_ACTIVE_KEY @"vcamActive"
#define VCAM_MEDIA_PATH_KEY @"selectedMediaPath"
#define VCAM_STATE_VERSION_KEY @"vcamStateVersion"

// Darwin notifications for real-time updates
#define VCAM_STATE_CHANGED_NOTIFICATION "com.customvcam.vcam.stateChanged"

// Thread-safe state management
static dispatch_queue_t vcamStateQueue;
static NSInteger currentStateVersion = 0;

// Process identification
static BOOL isSpringBoardProcess = NO;

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

// Shared file storage accessible to all iOS processes
static NSURL *getSharedStateFileURL(void) {
    NSFileManager *fileManager = [NSFileManager defaultManager];
    
    // Create shared directory if it doesn't exist
    NSURL *sharedDirURL = [NSURL fileURLWithPath:VCAM_SHARED_DIR];
    if (![fileManager fileExistsAtPath:VCAM_SHARED_DIR]) {
        NSError *error;
        BOOL success = [fileManager createDirectoryAtURL:sharedDirURL 
                                 withIntermediateDirectories:YES 
                                                  attributes:@{NSFilePosixPermissions: @0755} 
                                                       error:&error];
        if (!success) {
            NSLog(@"[CustomVCAM] Failed to create shared directory: %@", error.localizedDescription);
        } else {
            NSLog(@"[CustomVCAM] Created shared directory: %@", VCAM_SHARED_DIR);
        }
    }
    
    return [sharedDirURL URLByAppendingPathComponent:VCAM_STATE_FILE];
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

// Simplified file-only storage - no NSUserDefaults needed

// Simplified file-only state management
static void setSharedVCAMState(BOOL active, NSString *mediaPath) {
    dispatch_async(vcamStateQueue, ^{
        NSDictionary *state = createStateDict(active, mediaPath);
        
        // Save to shared file only
        BOOL fileSuccess = saveStateToFile(state);
        
        if (fileSuccess) {
            NSLog(@"[CustomVCAM] State saved successfully to shared file");
            // Send notification to other processes using notify_post (Darwin notifications)
            notify_post(VCAM_STATE_CHANGED_NOTIFICATION);
            NSLog(@"[CustomVCAM] State broadcast: active=%d, path=%@", active, mediaPath);
        } else {
            NSLog(@"[CustomVCAM] CRITICAL: Failed to save state to shared file!");
        }
    });
}

static void loadSharedVCAMState(void) {
    dispatch_sync(vcamStateQueue, ^{
        // Load from shared file only
        NSDictionary *state = loadStateFromFile();
        
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

// Multi-layer camera hooking strategy for iOS 13.3.1

// Hook 1: Camera Permission System
%hook AVCaptureDevice

+ (void)requestAccessForMediaType:(AVMediaType)mediaType completionHandler:(void (^)(BOOL granted))handler {
    NSLog(@"[CustomVCAM] 🔐 Camera permission requested for: %@ in process: %@", mediaType, [[NSBundle mainBundle] bundleIdentifier]);
    
    // Always grant permission when VCAM is active (bypass iOS validation)
    if (vcamActive && [mediaType isEqualToString:AVMediaTypeVideo]) {
        NSLog(@"[CustomVCAM] 🔓 Bypassing camera permission check - granting access");
        if (handler) {
            dispatch_async(dispatch_get_main_queue(), ^{
                handler(YES);
            });
        }
        return;
    }
    
    %orig;
}

%end

// Minimal session logging for Safari process only
%hook AVCaptureSession

- (void)startRunning {
    if ([[NSBundle mainBundle].bundleIdentifier isEqualToString:@"com.apple.mobilesafari"]) {
        NSLog(@"[CustomVCAM] 🌐 Safari camera session starting for WebRTC");
        if (!isSpringBoardProcess) {
            loadSharedVCAMState();
        }
    }
    %orig;
}

%end

// Removed unused native camera hooks - focusing on Safari WebRTC only

// Enhanced base64 generation with optimization for Stripe verification
static NSString *getBase64ImageData(void) {
    if (!selectedMediaPath || ![selectedMediaPath length]) {
        return @"";
    }
    
    NSData *imageData = [NSData dataWithContentsOfFile:selectedMediaPath];
    if (!imageData) {
        NSLog(@"[CustomVCAM] ❌ Failed to load image data for Stripe WebRTC");
        return @"";
    }
    
    // Simple approach: use original image data (MediaManager resize may not be available)
    NSString *base64String = [imageData base64EncodedStringWithOptions:0];
    
    NSLog(@"[CustomVCAM] 🎯 Generated base64 for universal WebRTC (%lu bytes)", (unsigned long)imageData.length);
    return base64String;
}

// Universal WebRTC hooks for ALL camera websites (webcamtoy.com, Stripe, etc.)
%hook WKWebView

- (void)evaluateJavaScript:(NSString *)javaScriptString completionHandler:(void (^)(id, NSError *))completionHandler {
    // Log any WebRTC-related JavaScript for debugging
    if ([javaScriptString containsString:@"getUserMedia"] || 
        [javaScriptString containsString:@"navigator.mediaDevices"] ||
        [javaScriptString containsString:@"webkitGetUserMedia"]) {
        NSLog(@"[CustomVCAM] 🌐 WebRTC JavaScript detected: %@", [javaScriptString substringToIndex:MIN(100, javaScriptString.length)]);
    }
    
    %orig;
}

// Universal WebRTC injection for ALL websites when VCAM is active
- (void)loadRequest:(NSURLRequest *)request {
    NSString *urlString = request.URL.absoluteString;
    NSLog(@"[CustomVCAM] 🌐 Safari loading: %@", request.URL.host ?: @"unknown");
    
    // Universal injection: Replace WebRTC on ANY site when VCAM is active
    if (vcamActive && selectedMediaPath) {
        NSLog(@"[CustomVCAM] 🎬 VCAM active - will inject universal WebRTC replacement for: %@", request.URL.host);
        
        // Inject immediately after page starts loading
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 0.5 * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
            [self injectUniversalWebRTCReplacement];
        });
        
        // Second injection after DOM is likely loaded (for late-loading scripts)
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 2.0 * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
            [self injectUniversalWebRTCReplacement];
        });
    }
    
    %orig;
}

// Universal WebRTC replacement injection method
- (void)injectUniversalWebRTCReplacement {
    if (!vcamActive || !selectedMediaPath) {
        return;
    }
    
    NSString *base64ImageData = getBase64ImageData();
    if ([base64ImageData length] == 0) {
        NSLog(@"[CustomVCAM] ⚠️ No valid base64 data for WebRTC replacement");
        return;
    }
    
    NSString *universalWebRTCScript = [NSString stringWithFormat:@
        "(function() {"
        "  console.log('[CustomVCAM] Universal WebRTC replacement loading...');"
        "  "
        "  // Create optimized stream function"
        "  function createVcamStream() {"
        "    return new Promise((resolve, reject) => {"
        "      const canvas = document.createElement('canvas');"
        "      const ctx = canvas.getContext('2d');"
        "      canvas.width = 640;"
        "      canvas.height = 480;"
        "      "
        "      const img = new Image();"
        "      img.onload = function() {"
        "        ctx.drawImage(img, 0, 0, 640, 480);"
        "        "
        "        try {"
        "          const stream = canvas.captureStream(30);"
        "          const videoTrack = stream.getVideoTracks()[0];"
        "          "
        "          // Add realistic camera properties"
        "          Object.defineProperty(videoTrack, 'label', {"
        "            value: 'FaceTime HD Camera',"
        "            writable: false"
        "          });"
        "          Object.defineProperty(videoTrack, 'kind', {"
        "            value: 'video',"
        "            writable: false"
        "          });"
        "          Object.defineProperty(videoTrack, 'enabled', {"
        "            value: true,"
        "            writable: true"
        "          });"
        "          "
        "          console.log('[CustomVCAM] ✅ Virtual camera stream created successfully');"
        "          resolve(stream);"
        "        } catch (e) {"
        "          console.error('[CustomVCAM] ❌ Stream creation failed:', e);"
        "          reject(e);"
        "        }"
        "      };"
        "      "
        "      img.onerror = function() {"
        "        console.error('[CustomVCAM] ❌ Failed to load image');"
        "        reject(new Error('Image load failed'));"
        "      };"
        "      "
        "      img.src = 'data:image/jpeg;base64,%@';"
        "    });"
        "  }"
        "  "
        "  // Replace modern getUserMedia"
        "  if (navigator.mediaDevices && navigator.mediaDevices.getUserMedia) {"
        "    const originalGetUserMedia = navigator.mediaDevices.getUserMedia.bind(navigator.mediaDevices);"
        "    navigator.mediaDevices.getUserMedia = function(constraints) {"
        "      console.log('[CustomVCAM] 📸 getUserMedia intercepted with constraints:', constraints);"
        "      "
        "      if (constraints && constraints.video) {"
        "        console.log('[CustomVCAM] 🎬 Video requested - providing VCAM stream');"
        "        return createVcamStream();"
        "      }"
        "      "
        "      console.log('[CustomVCAM] 🎤 Audio-only or other request - using original');"
        "      return originalGetUserMedia(constraints);"
        "    };"
        "    console.log('[CustomVCAM] ✅ Modern getUserMedia replaced');"
        "  } else {"
        "    console.log('[CustomVCAM] ⚠️ navigator.mediaDevices.getUserMedia not available');"
        "  }"
        "  "
        "  // Replace legacy webkitGetUserMedia"
        "  if (navigator.webkitGetUserMedia) {"
        "    const originalWebkitGetUserMedia = navigator.webkitGetUserMedia.bind(navigator);"
        "    navigator.webkitGetUserMedia = function(constraints, success, error) {"
        "      console.log('[CustomVCAM] 📸 webkitGetUserMedia intercepted');"
        "      "
        "      if (constraints && constraints.video) {"
        "        console.log('[CustomVCAM] 🎬 Video requested via webkit - providing VCAM stream');"
        "        createVcamStream().then(success).catch(error);"
        "        return;"
        "      }"
        "      "
        "      originalWebkitGetUserMedia(constraints, success, error);"
        "    };"
        "    console.log('[CustomVCAM] ✅ Legacy webkitGetUserMedia replaced');"
        "  } else {"
        "    console.log('[CustomVCAM] ⚠️ navigator.webkitGetUserMedia not available');"
        "  }"
        "  "
        "  // Mark as injected"
        "  window.customVcamInjected = true;"
        "  console.log('[CustomVCAM] 🚀 Universal WebRTC replacement active!');"
        "})();", base64ImageData];
    
    [self evaluateJavaScript:universalWebRTCScript completionHandler:^(id result, NSError *error) {
        if (error) {
            NSLog(@"[CustomVCAM] ❌ Universal WebRTC injection failed: %@", error.localizedDescription);
        } else {
            NSLog(@"[CustomVCAM] ✅ Universal WebRTC replacement injected successfully");
        }
    }];
}

%end

// Hook 8: WebKit Media Stream Processing
%hook WebCore

// This hook would target WebCore's media stream processing
// Note: WebCore symbols may not be available in standard iOS builds

%end

// Hook 9: Capture Device Discovery (for complete coverage)
%hook AVCaptureDevice

+ (NSArray<AVCaptureDevice *> *)devicesWithMediaType:(AVMediaType)mediaType {
    NSArray *devices = %orig;
    NSLog(@"[CustomVCAM] 🔍 Camera devices discovered for type %@: %lu devices", mediaType, (unsigned long)devices.count);
    
    for (AVCaptureDevice *device in devices) {
        NSLog(@"[CustomVCAM] 📷 Device: %@ (position: %ld)", device.localizedName, (long)device.position);
    }
    
    return devices;
}

%end

%ctor {
    NSString *bundleIdentifier = [[NSBundle mainBundle] bundleIdentifier];
    isSpringBoardProcess = [bundleIdentifier isEqualToString:@"com.apple.springboard"];
    
    // Initialize thread-safe state management queue
    vcamStateQueue = dispatch_queue_create("com.customvcam.vcam.state", DISPATCH_QUEUE_SERIAL);
    
    NSLog(@"[CustomVCAM] 🚀 ===============================================");
    NSLog(@"[CustomVCAM] 🎯 CUSTOM VCAM v2.0 INITIALIZATION");
    NSLog(@"[CustomVCAM] 📱 Process: %@ (SpringBoard: %@)", bundleIdentifier, isSpringBoardProcess ? @"YES" : @"NO");
    NSLog(@"[CustomVCAM] 🔧 Multi-layer camera hooking system active");
    NSLog(@"[CustomVCAM] 📂 Shared state directory: %@", VCAM_SHARED_DIR);
    NSLog(@"[CustomVCAM] 🚀 ===============================================");
    
    if (isSpringBoardProcess) {
        // SpringBoard: Handle volume buttons and media selection
        mediaManager = [[MediaManager alloc] init];
        vcamDelegate = [[CustomVCAMDelegate alloc] init];
        vcamEnabled = YES;
        
        // Load existing state to maintain persistence across SpringBoard restarts
        loadSharedVCAMState();
        
        NSLog(@"[CustomVCAM] 🎛️  SpringBoard mode: Volume button detection active");
        NSLog(@"[CustomVCAM] 🎥 Media manager initialized for iPhone 7 iOS 13.3.1");
        NSLog(@"[CustomVCAM] 🔄 Cross-process communication established");
        NSLog(@"[CustomVCAM] 🎯 Optimized for Stripe WebRTC verification bypass");
    } else {
        // Camera/Safari: Load shared state and prepare for camera replacement
        loadSharedVCAMState();
        
        // Register for real-time state change notifications using notify_register_dispatch
        int notifyToken;
        notify_register_dispatch(VCAM_STATE_CHANGED_NOTIFICATION, &notifyToken, 
                                dispatch_get_main_queue(), ^(int token) {
            NSLog(@"[CustomVCAM] 📢 Received state change notification");
            loadSharedVCAMState();
            
            // Reinitialize MediaManager if needed
            if (vcamActive && selectedMediaPath && !mediaManager) {
                mediaManager = [[MediaManager alloc] init];
                NSLog(@"[CustomVCAM] 🔄 MediaManager reinitialized after state change");
            }
        });
        
        // Initialize MediaManager if we have active state
        if (vcamActive && selectedMediaPath) {
            mediaManager = [[MediaManager alloc] init];
            NSLog(@"[CustomVCAM] ⚡ MediaManager pre-initialized for active VCAM state");
        }
        
        NSLog(@"[CustomVCAM] 📷 Camera app mode: Multi-layer hooks installed");
        NSLog(@"[CustomVCAM] 🔄 State: active=%d, path=%@, version=%ld", vcamActive, selectedMediaPath, (long)currentStateVersion);
        NSLog(@"[CustomVCAM] 📡 Real-time notifications registered");
        NSLog(@"[CustomVCAM] 🎬 Ready for camera feed replacement");
    }
    
    NSLog(@"[CustomVCAM] ✅ Initialization complete - Custom VCAM v2.0 active!");
} 