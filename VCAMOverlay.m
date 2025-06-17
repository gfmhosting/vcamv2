#import "VCAMOverlay.h"
#import "MediaProcessor.h"

@implementation VCAMOverlay {
    UIView *_containerView;
    UIButton *_mediaButton;
    UIButton *_debugButton;
    UIButton *_closeButton;
    BOOL _isVisible;
}

+ (instancetype)sharedInstance {
    static VCAMOverlay *instance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[self alloc] init];
    });
    return instance;
}

- (instancetype)init {
    CGRect screenBounds = [[UIScreen mainScreen] bounds];
    self = [super initWithFrame:screenBounds];
    if (self) {
        self.windowLevel = UIWindowLevelAlert + 1000;
        self.backgroundColor = [UIColor clearColor];
        self.hidden = YES;
        _isVisible = NO;
        
        [self setupUI];
        [self makeKeyAndVisible];
    }
    return self;
}

- (void)setupUI {
    _containerView = [[UIView alloc] initWithFrame:CGRectMake(50, 200, 275, 200)];
    _containerView.backgroundColor = [[UIColor blackColor] colorWithAlphaComponent:0.8];
    _containerView.layer.cornerRadius = 10;
    [self addSubview:_containerView];
    
    _mediaButton = [UIButton buttonWithType:UIButtonTypeSystem];
    _mediaButton.frame = CGRectMake(20, 20, 235, 50);
    [_mediaButton setTitle:@"📷 Select Media" forState:UIControlStateNormal];
    [_mediaButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    _mediaButton.backgroundColor = [[UIColor blueColor] colorWithAlphaComponent:0.7];
    _mediaButton.layer.cornerRadius = 8;
    [_mediaButton addTarget:self action:@selector(selectImageFromGallery) forControlEvents:UIControlEventTouchUpInside];
    [_containerView addSubview:_mediaButton];
    
    _debugButton = [UIButton buttonWithType:UIButtonTypeSystem];
    _debugButton.frame = CGRectMake(20, 80, 235, 50);
    [_debugButton setTitle:@"🐛 Debug Logs" forState:UIControlStateNormal];
    [_debugButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    _debugButton.backgroundColor = [[UIColor orangeColor] colorWithAlphaComponent:0.7];
    _debugButton.layer.cornerRadius = 8;
    [_debugButton addTarget:self action:@selector(showDebugLogs) forControlEvents:UIControlEventTouchUpInside];
    [_containerView addSubview:_debugButton];
    
    _closeButton = [UIButton buttonWithType:UIButtonTypeSystem];
    _closeButton.frame = CGRectMake(20, 140, 235, 40);
    [_closeButton setTitle:@"✖️ Close" forState:UIControlStateNormal];
    [_closeButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    _closeButton.backgroundColor = [[UIColor redColor] colorWithAlphaComponent:0.7];
    _closeButton.layer.cornerRadius = 8;
    [_closeButton addTarget:self action:@selector(hideOverlay) forControlEvents:UIControlEventTouchUpInside];
    [_containerView addSubview:_closeButton];
}

- (void)toggleOverlay {
    if (_isVisible) {
        [self hideOverlay];
    } else {
        [self showOverlay];
    }
}

- (void)showOverlay {
    self.hidden = NO;
    _isVisible = YES;
    [[DebugOverlay shared] log:@"VCAM overlay shown"];
}

- (void)hideOverlay {
    self.hidden = YES;
    _isVisible = NO;
    [[DebugOverlay shared] log:@"VCAM overlay hidden"];
}

- (void)selectImageFromGallery {
    [[DebugOverlay shared] log:@"Opening photo picker"];
    
    UIImagePickerController *picker = [[UIImagePickerController alloc] init];
    picker.sourceType = UIImagePickerControllerSourceTypePhotoLibrary;
    picker.mediaTypes = @[@"public.image", @"public.movie"];
    picker.delegate = (id<UIImagePickerControllerDelegate, UINavigationControllerDelegate>)self;
    
    UIViewController *rootVC = [UIApplication sharedApplication].keyWindow.rootViewController;
    [rootVC presentViewController:picker animated:YES completion:nil];
}

- (void)showDebugLogs {
    [[DebugOverlay shared] show];
    [self hideOverlay];
}

- (void)imagePickerController:(UIImagePickerController *)picker didFinishPickingMediaWithInfo:(NSDictionary<UIImagePickerControllerInfoKey,id> *)info {
    UIImage *selectedImage = info[UIImagePickerControllerOriginalImage];
    if (selectedImage) {
        [[MediaProcessor sharedInstance] setSelectedMedia:selectedImage];
        [[DebugOverlay shared] log:@"Media selected and processed"];
    }
    
    [picker dismissViewControllerAnimated:YES completion:^{
        [self hideOverlay];
    }];
}

- (void)imagePickerControllerDidCancel:(UIImagePickerController *)picker {
    [picker dismissViewControllerAnimated:YES completion:nil];
}

@end

@implementation DebugOverlay

static DebugOverlay *sharedDebugOverlay = nil;

+ (instancetype)shared {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedDebugOverlay = [[self alloc] init];
    });
    return sharedDebugOverlay;
}

- (instancetype)init {
    CGRect screenBounds = [[UIScreen mainScreen] bounds];
    self = [super initWithFrame:screenBounds];
    if (self) {
        self.backgroundColor = [[UIColor blackColor] colorWithAlphaComponent:0.9];
        self.hidden = YES;
        
        _logMessages = [[NSMutableArray alloc] init];
        [self setupDebugUI];
    }
    return self;
}

- (void)setupDebugUI {
    _logTextView = [[UITextView alloc] initWithFrame:CGRectMake(20, 100, self.frame.size.width - 40, self.frame.size.height - 200)];
    _logTextView.backgroundColor = [[UIColor blackColor] colorWithAlphaComponent:0.8];
    _logTextView.textColor = [UIColor greenColor];
    _logTextView.font = [UIFont fontWithName:@"Menlo" size:12];
    _logTextView.editable = NO;
    [self addSubview:_logTextView];
    
    UIButton *closeBtn = [UIButton buttonWithType:UIButtonTypeSystem];
    closeBtn.frame = CGRectMake(20, 50, 100, 40);
    [closeBtn setTitle:@"Close" forState:UIControlStateNormal];
    [closeBtn setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    [closeBtn addTarget:self action:@selector(hide) forControlEvents:UIControlEventTouchUpInside];
    [self addSubview:closeBtn];
    
    UIButton *clearBtn = [UIButton buttonWithType:UIButtonTypeSystem];
    clearBtn.frame = CGRectMake(140, 50, 100, 40);
    [clearBtn setTitle:@"Clear" forState:UIControlStateNormal];
    [clearBtn setTitleColor:[UIColor redColor] forState:UIControlStateNormal];
    [clearBtn addTarget:self action:@selector(clearLogs) forControlEvents:UIControlEventTouchUpInside];
    [self addSubview:clearBtn];
}

+ (void)log:(NSString *)message {
    [[self shared] logMessage:message];
}

- (void)logMessage:(NSString *)message {
    NSString *timestamp = [NSDateFormatter localizedStringFromDate:[NSDate date] 
                                                         dateStyle:NSDateFormatterNoStyle 
                                                         timeStyle:NSDateFormatterMediumStyle];
    NSString *logEntry = [NSString stringWithFormat:@"[%@] %@\n", timestamp, message];
    
    [_logMessages addObject:logEntry];
    
    if (_logMessages.count > 100) {
        [_logMessages removeObjectAtIndex:0];
    }
    
    dispatch_async(dispatch_get_main_queue(), ^{
        self.logTextView.text = [self.logMessages componentsJoinedByString:@""];
        [self.logTextView scrollRangeToVisible:NSMakeRange(self.logTextView.text.length, 0)];
    });
}

- (void)show {
    UIWindow *keyWindow = [UIApplication sharedApplication].keyWindow;
    [keyWindow addSubview:self];
    self.hidden = NO;
}

- (void)hide {
    self.hidden = YES;
    [self removeFromSuperview];
}

- (void)clearLogs {
    [_logMessages removeAllObjects];
    _logTextView.text = @"";
}

- (void)exportLogs {
    NSString *logsText = [_logMessages componentsJoinedByString:@""];
    UIPasteboard.generalPasteboard.string = logsText;
    [self logMessage:@"Logs copied to clipboard"];
}

@end 