#import <UIKit/UIKit.h>
#import <QuartzCore/QuartzCore.h>

@protocol OverlayViewDelegate <NSObject>
- (void)overlayViewDidRequestMediaSelection:(id)sender;
@end

@interface OverlayView : UIView

@property (nonatomic, weak) id<OverlayViewDelegate> delegate;
@property (nonatomic, strong) UIButton *mediaSelectButton;
@property (nonatomic, strong) CALayer *overlayLayer;

- (instancetype)initWithFrame:(CGRect)frame;
- (void)showMediaSelector;
- (void)hideMediaSelector;
- (void)updateOverlayPosition:(CGRect)newFrame;

// Button styling
- (void)styleButton;
- (void)addPulseAnimation;
- (void)removePulseAnimation;

// Touch handling
- (void)handleButtonTap:(UIButton *)sender;

@end 