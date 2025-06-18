#import <UIKit/UIKit.h>

@interface OverlayView : UIView

@property (nonatomic, assign) BOOL vcamEnabled;
@property (nonatomic, strong) UISwitch *enableSwitch;
@property (nonatomic, strong) UIButton *selectMediaButton;
@property (nonatomic, strong) UILabel *statusLabel;

+ (instancetype)sharedInstance;
- (void)showOverlay;
- (void)hideOverlay;
- (void)updateStatus:(NSString *)status;

@end 