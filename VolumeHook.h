#import <UIKit/UIKit.h>

@interface VolumeHook : NSObject

+ (instancetype)sharedInstance;
- (BOOL)handleVolumeEvent;
- (void)resetTapCount;

@property (nonatomic, assign) NSTimeInterval lastTapTime;
@property (nonatomic, assign) NSInteger tapCount;
@property (nonatomic, assign) NSTimeInterval doubleTapThreshold;

@end 