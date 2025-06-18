#import <UIKit/UIKit.h>

@interface OverlayView : UIView

@property (nonatomic, assign) BOOL isVisible;

+ (instancetype)sharedOverlay;
- (void)showOverlay;
- (void)hideOverlay;
- (void)setupUI;

@end 