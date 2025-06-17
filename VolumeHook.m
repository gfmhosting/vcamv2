#import "VolumeHook.h"
#import "VCAMOverlay.h"

@implementation VolumeHook

+ (instancetype)sharedInstance {
    static VolumeHook *instance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[self alloc] init];
    });
    return instance;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        _tapCount = 0;
        _lastTapTime = 0;
        _doubleTapThreshold = 0.3; // 300ms threshold for double-tap
    }
    return self;
}

- (BOOL)handleVolumeEvent {
    NSTimeInterval currentTime = [[NSDate date] timeIntervalSince1970];
    
    if (currentTime - _lastTapTime <= _doubleTapThreshold) {
        _tapCount++;
        
        if (_tapCount >= 2) {
            [[DebugOverlay shared] log:@"Double-tap detected on volume button"];
            [self resetTapCount];
            return YES; // Intercept the event
        }
    } else {
        _tapCount = 1; // Reset count if too much time has passed
    }
    
    _lastTapTime = currentTime;
    
    // Auto-reset after threshold
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(_doubleTapThreshold * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        if ([[NSDate date] timeIntervalSince1970] - self.lastTapTime >= self.doubleTapThreshold) {
            [self resetTapCount];
        }
    });
    
    return NO; // Don't intercept single taps
}

- (void)resetTapCount {
    _tapCount = 0;
    _lastTapTime = 0;
}

@end 