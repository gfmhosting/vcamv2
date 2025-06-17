#import <UIKit/UIKit.h>
#import <Photos/Photos.h>

@interface VCAMOverlay : UIWindow

+ (instancetype)sharedInstance;
- (void)toggleOverlay;
- (void)showMediaPicker;
- (void)showDebugLogs;
- (void)selectImageFromGallery;
- (void)hideOverlay;

@end

@interface DebugOverlay : UIView

+ (instancetype)shared;
+ (void)log:(NSString *)message;
- (void)show;
- (void)hide;
- (void)exportLogs;
- (void)clearLogs;

@property (nonatomic, strong) UITextView *logTextView;
@property (nonatomic, strong) NSMutableArray *logMessages;

@end 