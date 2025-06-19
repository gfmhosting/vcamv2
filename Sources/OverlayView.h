#import <UIKit/UIKit.h>
#import <Photos/Photos.h>

@protocol OverlayViewDelegate <NSObject>
- (void)overlayView:(id)overlayView didSelectMediaAtPath:(NSString *)mediaPath;
- (void)overlayViewDidCancel:(id)overlayView;
@end

@interface OverlayView : UIWindow <UIImagePickerControllerDelegate, UINavigationControllerDelegate>

@property (nonatomic, weak) id<OverlayViewDelegate> delegate;
@property (nonatomic, strong) UIViewController *containerViewController;
@property (nonatomic, strong) UIImagePickerController *imagePickerController;

- (instancetype)init;
- (void)showMediaPicker;
- (void)hideOverlay;
- (void)setupUI;

@end 