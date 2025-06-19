#import <UIKit/UIKit.h>
#import <Photos/Photos.h>
#import <PhotosUI/PhotosUI.h>

@protocol OverlayViewDelegate <NSObject>
- (void)overlayView:(id)overlayView didSelectMediaAtPath:(NSString *)mediaPath;
- (void)overlayViewDidCancel:(id)overlayView;
@end

@interface OverlayView : UIWindow <UIImagePickerControllerDelegate, UINavigationControllerDelegate, PHPickerViewControllerDelegate>

@property (nonatomic, weak) id<OverlayViewDelegate> delegate;
@property (nonatomic, strong) UIViewController *containerViewController;
@property (nonatomic, strong) UIImagePickerController *imagePickerController;
@property (nonatomic, strong) PHPickerViewController *phPickerViewController;

- (instancetype)init;
- (void)showMediaPicker;
- (void)hideOverlay;
- (void)setupUI;

@end 