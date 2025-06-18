#import "OverlayView.h"
#import "MediaManager.h"

@interface OverlayView()
@property (nonatomic, strong) UIButton *selectMediaButton;
@property (nonatomic, strong) UIButton *enableVCAMButton;
@property (nonatomic, strong) UIButton *disableVCAMButton;
@property (nonatomic, strong) UILabel *statusLabel;
@property (nonatomic, strong) UIView *containerView;
@end

@implementation OverlayView

+ (instancetype)sharedOverlay {
    static OverlayView *instance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[OverlayView alloc] init];
    });
    return instance;
}

- (instancetype)init {
    CGRect screenBounds = [UIScreen mainScreen].bounds;
    self = [super initWithFrame:screenBounds];
    if (self) {
        self.isVisible = NO;
        self.hidden = YES;
        self.backgroundColor = [UIColor colorWithRed:0 green:0 blue:0 alpha:0.7];
        [self setupUI];
        [[MediaManager sharedManager] logDebug:@"OverlayView initialized"];
    }
    return self;
}

- (void)setupUI {
    self.containerView = [[UIView alloc] init];
    self.containerView.backgroundColor = [UIColor colorWithRed:0.1 green:0.1 blue:0.1 alpha:0.9];
    self.containerView.layer.cornerRadius = 15;
    self.containerView.translatesAutoresizingMaskIntoConstraints = NO;
    [self addSubview:self.containerView];
    
    self.statusLabel = [[UILabel alloc] init];
    self.statusLabel.text = @"CustomVCAM";
    self.statusLabel.textColor = [UIColor whiteColor];
    self.statusLabel.font = [UIFont boldSystemFontOfSize:18];
    self.statusLabel.textAlignment = NSTextAlignmentCenter;
    self.statusLabel.translatesAutoresizingMaskIntoConstraints = NO;
    [self.containerView addSubview:self.statusLabel];
    
    self.selectMediaButton = [UIButton buttonWithType:UIButtonTypeSystem];
    [self.selectMediaButton setTitle:@"Select Media" forState:UIControlStateNormal];
    [self.selectMediaButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    self.selectMediaButton.backgroundColor = [UIColor colorWithRed:0.2 green:0.4 blue:0.8 alpha:1.0];
    self.selectMediaButton.layer.cornerRadius = 8;
    self.selectMediaButton.translatesAutoresizingMaskIntoConstraints = NO;
    [self.selectMediaButton addTarget:self action:@selector(selectMediaTapped) forControlEvents:UIControlEventTouchUpInside];
    [self.containerView addSubview:self.selectMediaButton];
    
    self.enableVCAMButton = [UIButton buttonWithType:UIButtonTypeSystem];
    [self.enableVCAMButton setTitle:@"Enable VCAM" forState:UIControlStateNormal];
    [self.enableVCAMButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    self.enableVCAMButton.backgroundColor = [UIColor colorWithRed:0.2 green:0.8 blue:0.2 alpha:1.0];
    self.enableVCAMButton.layer.cornerRadius = 8;
    self.enableVCAMButton.translatesAutoresizingMaskIntoConstraints = NO;
    [self.enableVCAMButton addTarget:self action:@selector(enableVCAMTapped) forControlEvents:UIControlEventTouchUpInside];
    [self.containerView addSubview:self.enableVCAMButton];
    
    self.disableVCAMButton = [UIButton buttonWithType:UIButtonTypeSystem];
    [self.disableVCAMButton setTitle:@"Disable VCAM" forState:UIControlStateNormal];
    [self.disableVCAMButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    self.disableVCAMButton.backgroundColor = [UIColor colorWithRed:0.8 green:0.2 blue:0.2 alpha:1.0];
    self.disableVCAMButton.layer.cornerRadius = 8;
    self.disableVCAMButton.translatesAutoresizingMaskIntoConstraints = NO;
    [self.disableVCAMButton addTarget:self action:@selector(disableVCAMTapped) forControlEvents:UIControlEventTouchUpInside];
    [self.containerView addSubview:self.disableVCAMButton];
    
    [NSLayoutConstraint activateConstraints:@[
        [self.containerView.centerXAnchor constraintEqualToAnchor:self.centerXAnchor],
        [self.containerView.centerYAnchor constraintEqualToAnchor:self.centerYAnchor],
        [self.containerView.widthAnchor constraintEqualToConstant:280],
        [self.containerView.heightAnchor constraintEqualToConstant:200],
        
        [self.statusLabel.topAnchor constraintEqualToAnchor:self.containerView.topAnchor constant:20],
        [self.statusLabel.leadingAnchor constraintEqualToAnchor:self.containerView.leadingAnchor constant:20],
        [self.statusLabel.trailingAnchor constraintEqualToAnchor:self.containerView.trailingAnchor constant:-20],
        
        [self.selectMediaButton.topAnchor constraintEqualToAnchor:self.statusLabel.bottomAnchor constant:20],
        [self.selectMediaButton.leadingAnchor constraintEqualToAnchor:self.containerView.leadingAnchor constant:20],
        [self.selectMediaButton.trailingAnchor constraintEqualToAnchor:self.containerView.trailingAnchor constant:-20],
        [self.selectMediaButton.heightAnchor constraintEqualToConstant:40],
        
        [self.enableVCAMButton.topAnchor constraintEqualToAnchor:self.selectMediaButton.bottomAnchor constant:10],
        [self.enableVCAMButton.leadingAnchor constraintEqualToAnchor:self.containerView.leadingAnchor constant:20],
        [self.enableVCAMButton.widthAnchor constraintEqualToConstant:115],
        [self.enableVCAMButton.heightAnchor constraintEqualToConstant:40],
        
        [self.disableVCAMButton.topAnchor constraintEqualToAnchor:self.selectMediaButton.bottomAnchor constant:10],
        [self.disableVCAMButton.trailingAnchor constraintEqualToAnchor:self.containerView.trailingAnchor constant:-20],
        [self.disableVCAMButton.widthAnchor constraintEqualToConstant:115],
        [self.disableVCAMButton.heightAnchor constraintEqualToConstant:40]
    ]];
}

- (void)showOverlay {
    if (self.isVisible) return;
    
    [[MediaManager sharedManager] logDebug:@"Showing overlay"];
    self.isVisible = YES;
    self.hidden = NO;
    
    UIWindow *keyWindow = [UIApplication sharedApplication].keyWindow;
    if (keyWindow) {
        [keyWindow addSubview:self];
        [keyWindow bringSubviewToFront:self];
    }
    
    self.alpha = 0;
    [UIView animateWithDuration:0.3 animations:^{
        self.alpha = 1;
    }];
    
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(5.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [self hideOverlay];
    });
}

- (void)hideOverlay {
    if (!self.isVisible) return;
    
    [[MediaManager sharedManager] logDebug:@"Hiding overlay"];
    [UIView animateWithDuration:0.3 animations:^{
        self.alpha = 0;
    } completion:^(BOOL finished) {
        self.hidden = YES;
        self.isVisible = NO;
        [self removeFromSuperview];
    }];
}

- (void)selectMediaTapped {
    [[MediaManager sharedManager] logDebug:@"Select media button tapped"];
    [self hideOverlay];
    
    [[MediaManager sharedManager] selectMediaWithCompletion:^(BOOL success) {
        if (success) {
            [[MediaManager sharedManager] logDebug:@"Media selection completed successfully"];
        } else {
            [[MediaManager sharedManager] logDebug:@"Media selection failed"];
        }
    }];
}

- (void)enableVCAMTapped {
    [[MediaManager sharedManager] logDebug:@"Enable VCAM button tapped"];
    [[MediaManager sharedManager] enableVCAM];
    [self hideOverlay];
}

- (void)disableVCAMTapped {
    [[MediaManager sharedManager] logDebug:@"Disable VCAM button tapped"];
    [[MediaManager sharedManager] disableVCAM];
    [self hideOverlay];
}

@end 