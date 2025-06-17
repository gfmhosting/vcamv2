#import <UIKit/UIKit.h>
#import <AVFoundation/AVFoundation.h>

@interface MediaProcessor : NSObject
@property (nonatomic, assign) BOOL isEnabled;
@property (nonatomic, strong) UIImage *selectedImage;
+ (instancetype)sharedInstance;
- (void)setSelectedImage:(UIImage *)image;
@end

@interface VCAMOverlay : NSObject <UIImagePickerControllerDelegate, UINavigationControllerDelegate>
@property (nonatomic, strong) UIWindow *overlayWindow;
@property (nonatomic, strong) UIViewController *rootViewController;
@property (nonatomic, strong) NSMutableArray *debugLogs;

+ (instancetype)sharedInstance;
- (void)showOverlay;
- (void)hideOverlay;
- (void)showDebugOverlay;
- (void)addDebugLog:(NSString *)message;
@end

@implementation VCAMOverlay

+ (instancetype)sharedInstance {
    static VCAMOverlay *sharedInstance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedInstance = [[self alloc] init];
    });
    return sharedInstance;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        _debugLogs = [NSMutableArray array];
    }
    return self;
}

- (void)showOverlay {
    if (!self.overlayWindow) {
        self.overlayWindow = [[UIWindow alloc] initWithFrame:[UIScreen mainScreen].bounds];
        self.overlayWindow.windowLevel = UIWindowLevelAlert + 1;
        self.rootViewController = [[UIViewController alloc] init];
        self.rootViewController.view.backgroundColor = [UIColor colorWithWhite:0.0 alpha:0.7];
        self.overlayWindow.rootViewController = self.rootViewController;
        
        // Create UI elements
        UIView *containerView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 300, 200)];
        containerView.center = self.rootViewController.view.center;
        containerView.backgroundColor = [UIColor whiteColor];
        containerView.layer.cornerRadius = 10;
        [self.rootViewController.view addSubview:containerView];
        
        UILabel *titleLabel = [[UILabel alloc] initWithFrame:CGRectMake(0, 10, 300, 30)];
        titleLabel.text = @"StripeVCAM Bypass";
        titleLabel.textAlignment = NSTextAlignmentCenter;
        titleLabel.font = [UIFont boldSystemFontOfSize:18];
        [containerView addSubview:titleLabel];
        
        UIButton *selectImageButton = [UIButton buttonWithType:UIButtonTypeSystem];
        selectImageButton.frame = CGRectMake(50, 60, 200, 40);
        [selectImageButton setTitle:@"Select Image" forState:UIControlStateNormal];
        [selectImageButton addTarget:self action:@selector(selectImage) forControlEvents:UIControlEventTouchUpInside];
        [containerView addSubview:selectImageButton];
        
        UIButton *debugButton = [UIButton buttonWithType:UIButtonTypeSystem];
        debugButton.frame = CGRectMake(50, 110, 200, 40);
        [debugButton setTitle:@"Debug Logs" forState:UIControlStateNormal];
        [debugButton addTarget:self action:@selector(showDebugOverlay) forControlEvents:UIControlEventTouchUpInside];
        [containerView addSubview:debugButton];
        
        UIButton *closeButton = [UIButton buttonWithType:UIButtonTypeSystem];
        closeButton.frame = CGRectMake(50, 160, 200, 40);
        [closeButton setTitle:@"Close" forState:UIControlStateNormal];
        [closeButton addTarget:self action:@selector(hideOverlay) forControlEvents:UIControlEventTouchUpInside];
        [containerView addSubview:closeButton];
    }
    
    [self addDebugLog:@"Overlay shown"];
    self.overlayWindow.hidden = NO;
}

- (void)hideOverlay {
    [self addDebugLog:@"Overlay hidden"];
    self.overlayWindow.hidden = YES;
}

- (void)selectImage {
    [self addDebugLog:@"Image selection started"];
    
    UIImagePickerController *picker = [[UIImagePickerController alloc] init];
    picker.sourceType = UIImagePickerControllerSourceTypePhotoLibrary;
    picker.delegate = self;
    [self.rootViewController presentViewController:picker animated:YES completion:nil];
}

- (void)showDebugOverlay {
    [self addDebugLog:@"Debug overlay shown"];
    
    UIViewController *debugVC = [[UIViewController alloc] init];
    debugVC.view.backgroundColor = [UIColor whiteColor];
    
    UITextView *logView = [[UITextView alloc] initWithFrame:CGRectMake(10, 50, debugVC.view.bounds.size.width - 20, debugVC.view.bounds.size.height - 100)];
    logView.editable = NO;
    logView.text = [self getDebugLogs];
    logView.font = [UIFont systemFontOfSize:14];
    [debugVC.view addSubview:logView];
    
    UIButton *closeButton = [UIButton buttonWithType:UIButtonTypeSystem];
    closeButton.frame = CGRectMake(10, 10, 80, 30);
    [closeButton setTitle:@"Close" forState:UIControlStateNormal];
    [closeButton addTarget:self action:@selector(closeDebugOverlay:) forControlEvents:UIControlEventTouchUpInside];
    [debugVC.view addSubview:closeButton];
    
    UIButton *clearButton = [UIButton buttonWithType:UIButtonTypeSystem];
    clearButton.frame = CGRectMake(debugVC.view.bounds.size.width - 90, 10, 80, 30);
    [clearButton setTitle:@"Clear" forState:UIControlStateNormal];
    [clearButton addTarget:self action:@selector(clearDebugLogs:) forControlEvents:UIControlEventTouchUpInside];
    [debugVC.view addSubview:clearButton];
    
    [self.rootViewController presentViewController:debugVC animated:YES completion:nil];
}

- (NSString *)getDebugLogs {
    if (self.debugLogs.count == 0) {
        return @"No logs available.";
    }
    
    return [self.debugLogs componentsJoinedByString:@"\n"];
}

- (void)addDebugLog:(NSString *)message {
    // Add timestamp to message
    NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
    formatter.dateFormat = @"HH:mm:ss";
    NSString *timestamp = [formatter stringFromDate:[NSDate date]];
    
    NSString *logEntry = [NSString stringWithFormat:@"[%@] %@", timestamp, message];
    [self.debugLogs addObject:logEntry];
    
    // Keep log size manageable
    if (self.debugLogs.count > 100) {
        [self.debugLogs removeObjectAtIndex:0];
    }
    
    // Also log to system console
    NSLog(@"[StripeVCAM] %@", message);
}

- (void)closeDebugOverlay:(UIButton *)sender {
    [self.rootViewController dismissViewControllerAnimated:YES completion:nil];
}

- (void)clearDebugLogs:(UIButton *)sender {
    [self.debugLogs removeAllObjects];
    [self addDebugLog:@"Logs cleared"];
    
    // Update the text view
    UIViewController *presentedVC = self.rootViewController.presentedViewController;
    for (UIView *subview in presentedVC.view.subviews) {
        if ([subview isKindOfClass:[UITextView class]]) {
            UITextView *textView = (UITextView *)subview;
            textView.text = @"Logs cleared.";
            break;
        }
    }
}

#pragma mark - UIImagePickerControllerDelegate

- (void)imagePickerController:(UIImagePickerController *)picker didFinishPickingMediaWithInfo:(NSDictionary *)info {
    UIImage *selectedImage = info[UIImagePickerControllerOriginalImage];
    
    if (selectedImage) {
        [self addDebugLog:[NSString stringWithFormat:@"Image selected: %dx%d", (int)selectedImage.size.width, (int)selectedImage.size.height]];
        [[MediaProcessor sharedInstance] setSelectedImage:selectedImage];
        [[MediaProcessor sharedInstance] setIsEnabled:YES];
    } else {
        [self addDebugLog:@"Failed to get selected image"];
    }
    
    [picker dismissViewControllerAnimated:YES completion:^{
        [self hideOverlay];
    }];
}

- (void)imagePickerControllerDidCancel:(UIImagePickerController *)picker {
    [self addDebugLog:@"Image selection cancelled"];
    [picker dismissViewControllerAnimated:YES completion:nil];
}

@end 