#import "OverlayView.h"
#import "SimpleMediaManager.h"

@interface OverlayView ()
@property (nonatomic, strong) UIWindow *overlayWindow;
@property (nonatomic, strong) UIView *contentView;
@property (nonatomic, strong) NSTimer *hideTimer;
@end

@implementation OverlayView

+ (instancetype)sharedInstance {
    static OverlayView *instance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[OverlayView alloc] init];
    });
    return instance;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        [self setupOverlayWindow];
        [self setupUI];
        _vcamEnabled = NO;
    }
    return self;
}

- (void)setupOverlayWindow {
    self.overlayWindow = [[UIWindow alloc] initWithFrame:[UIScreen mainScreen].bounds];
    self.overlayWindow.windowLevel = UIWindowLevelAlert + 1000;
    self.overlayWindow.backgroundColor = [UIColor clearColor];
    self.overlayWindow.hidden = YES;
    self.overlayWindow.rootViewController = [[UIViewController alloc] init];
    
    if (@available(iOS 13.0, *)) {
        self.overlayWindow.windowScene = [UIApplication sharedApplication].connectedScenes.anyObject;
    }
}

- (void)setupUI {
    self.contentView = [[UIView alloc] init];
    self.contentView.backgroundColor = [[UIColor blackColor] colorWithAlphaComponent:0.8];
    self.contentView.layer.cornerRadius = 12.0;
    self.contentView.layer.borderWidth = 1.0;
    self.contentView.layer.borderColor = [[UIColor whiteColor] colorWithAlphaComponent:0.3].CGColor;
    self.contentView.translatesAutoresizingMaskIntoConstraints = NO;
    
    UILabel *titleLabel = [[UILabel alloc] init];
    titleLabel.text = @"Custom VCAM";
    titleLabel.textColor = [UIColor whiteColor];
    titleLabel.font = [UIFont boldSystemFontOfSize:16];
    titleLabel.textAlignment = NSTextAlignmentCenter;
    titleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    
    self.enableSwitch = [[UISwitch alloc] init];
    self.enableSwitch.on = self.vcamEnabled;
    [self.enableSwitch addTarget:self action:@selector(switchToggled:) forControlEvents:UIControlEventValueChanged];
    self.enableSwitch.translatesAutoresizingMaskIntoConstraints = NO;
    
    UILabel *enableLabel = [[UILabel alloc] init];
    enableLabel.text = @"Enable VCAM";
    enableLabel.textColor = [UIColor whiteColor];
    enableLabel.font = [UIFont systemFontOfSize:14];
    enableLabel.translatesAutoresizingMaskIntoConstraints = NO;
    
    self.selectMediaButton = [UIButton buttonWithType:UIButtonTypeSystem];
    [self.selectMediaButton setTitle:@"Select Media" forState:UIControlStateNormal];
    [self.selectMediaButton setTitleColor:[UIColor systemBlueColor] forState:UIControlStateNormal];
    self.selectMediaButton.titleLabel.font = [UIFont systemFontOfSize:14];
    self.selectMediaButton.layer.borderWidth = 1.0;
    self.selectMediaButton.layer.borderColor = [UIColor systemBlueColor].CGColor;
    self.selectMediaButton.layer.cornerRadius = 6.0;
    [self.selectMediaButton addTarget:self action:@selector(selectMediaTapped:) forControlEvents:UIControlEventTouchUpInside];
    self.selectMediaButton.translatesAutoresizingMaskIntoConstraints = NO;
    
    self.statusLabel = [[UILabel alloc] init];
    self.statusLabel.text = @"No media selected";
    self.statusLabel.textColor = [[UIColor whiteColor] colorWithAlphaComponent:0.7];
    self.statusLabel.font = [UIFont systemFontOfSize:12];
    self.statusLabel.textAlignment = NSTextAlignmentCenter;
    self.statusLabel.numberOfLines = 2;
    self.statusLabel.translatesAutoresizingMaskIntoConstraints = NO;
    
    [self.contentView addSubview:titleLabel];
    [self.contentView addSubview:enableLabel];
    [self.contentView addSubview:self.enableSwitch];
    [self.contentView addSubview:self.selectMediaButton];
    [self.contentView addSubview:self.statusLabel];
    
    [self.overlayWindow.rootViewController.view addSubview:self.contentView];
    
    [NSLayoutConstraint activateConstraints:@[
        [self.contentView.centerXAnchor constraintEqualToAnchor:self.overlayWindow.rootViewController.view.centerXAnchor],
        [self.contentView.topAnchor constraintEqualToAnchor:self.overlayWindow.rootViewController.view.safeAreaLayoutGuide.topAnchor constant:50],
        [self.contentView.widthAnchor constraintEqualToConstant:280],
        [self.contentView.heightAnchor constraintEqualToConstant:160],
        
        [titleLabel.topAnchor constraintEqualToAnchor:self.contentView.topAnchor constant:12],
        [titleLabel.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor constant:12],
        [titleLabel.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor constant:-12],
        
        [enableLabel.topAnchor constraintEqualToAnchor:titleLabel.bottomAnchor constant:12],
        [enableLabel.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor constant:12],
        
        [self.enableSwitch.centerYAnchor constraintEqualToAnchor:enableLabel.centerYAnchor],
        [self.enableSwitch.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor constant:-12],
        
        [self.selectMediaButton.topAnchor constraintEqualToAnchor:enableLabel.bottomAnchor constant:12],
        [self.selectMediaButton.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor constant:12],
        [self.selectMediaButton.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor constant:-12],
        [self.selectMediaButton.heightAnchor constraintEqualToConstant:32],
        
        [self.statusLabel.topAnchor constraintEqualToAnchor:self.selectMediaButton.bottomAnchor constant:8],
        [self.statusLabel.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor constant:12],
        [self.statusLabel.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor constant:-12],
        [self.statusLabel.bottomAnchor constraintEqualToAnchor:self.contentView.bottomAnchor constant:-12]
    ]];
}

- (void)switchToggled:(UISwitch *)sender {
    self.vcamEnabled = sender.on;
    [self updateStatus:self.vcamEnabled ? @"VCAM Enabled" : @"VCAM Disabled"];
    
    [[NSNotificationCenter defaultCenter] postNotificationName:@"VCAMToggled" 
                                                        object:nil 
                                                      userInfo:@{@"enabled": @(self.vcamEnabled)}];
}

- (void)selectMediaTapped:(UIButton *)sender {
    SimpleMediaManager *mediaManager = [SimpleMediaManager sharedInstance];
    [mediaManager presentGallery];
    
    [[NSNotificationCenter defaultCenter] addObserver:self 
                                             selector:@selector(mediaSelectionChanged:) 
                                                 name:@"MediaSelectionChanged" 
                                               object:nil];
}

- (void)mediaSelectionChanged:(NSNotification *)notification {
    SimpleMediaManager *mediaManager = [SimpleMediaManager sharedInstance];
    if (mediaManager.hasMedia) {
        [self updateStatus:@"Image selected"];
    }
}

- (void)showOverlay {
    dispatch_async(dispatch_get_main_queue(), ^{
        self.overlayWindow.hidden = NO;
        [self.overlayWindow makeKeyAndVisible];
        
        self.contentView.alpha = 0.0;
        self.contentView.transform = CGAffineTransformMakeScale(0.8, 0.8);
        
        [UIView animateWithDuration:0.3 
                              delay:0.0 
             usingSpringWithDamping:0.7 
              initialSpringVelocity:0.5 
                            options:UIViewAnimationOptionCurveEaseInOut 
                         animations:^{
            self.contentView.alpha = 1.0;
            self.contentView.transform = CGAffineTransformIdentity;
        } completion:nil];
        
        [self startHideTimer];
    });
}

- (void)hideOverlay {
    dispatch_async(dispatch_get_main_queue(), ^{
        [UIView animateWithDuration:0.2 animations:^{
            self.contentView.alpha = 0.0;
            self.contentView.transform = CGAffineTransformMakeScale(0.8, 0.8);
        } completion:^(BOOL finished) {
            self.overlayWindow.hidden = YES;
        }];
        
        [self stopHideTimer];
    });
}

- (void)startHideTimer {
    [self stopHideTimer];
    self.hideTimer = [NSTimer scheduledTimerWithTimeInterval:5.0 
                                                      target:self 
                                                    selector:@selector(hideOverlay) 
                                                    userInfo:nil 
                                                     repeats:NO];
}

- (void)stopHideTimer {
    if (self.hideTimer) {
        [self.hideTimer invalidate];
        self.hideTimer = nil;
    }
}

- (void)updateStatus:(NSString *)status {
    dispatch_async(dispatch_get_main_queue(), ^{
        self.statusLabel.text = status;
    });
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    [self stopHideTimer];
}

@end 