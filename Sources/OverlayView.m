#import "OverlayView.h"
#import "MediaManager.h"

@implementation OverlayView

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        [self setupOverlay];
    }
    return self;
}

- (void)setupOverlay {
    NSLog(@"[CustomVCAM] OverlayView: Setting up camera overlay");
    
    self.backgroundColor = [UIColor clearColor];
    self.userInteractionEnabled = YES;
    
    // Create the media selection button
    self.mediaSelectButton = [UIButton buttonWithType:UIButtonTypeCustom];
    self.mediaSelectButton.frame = CGRectMake(20, 50, 60, 60);
    [self.mediaSelectButton setTitle:@"📷" forState:UIControlStateNormal];
    [self.mediaSelectButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    self.mediaSelectButton.titleLabel.font = [UIFont systemFontOfSize:24];
    
    [self.mediaSelectButton addTarget:self 
                               action:@selector(handleButtonTap:) 
                     forControlEvents:UIControlEventTouchUpInside];
    
    [self addSubview:self.mediaSelectButton];
    [self styleButton];
    
    // Create overlay layer
    self.overlayLayer = [CALayer layer];
    self.overlayLayer.frame = self.bounds;
    self.overlayLayer.backgroundColor = [[UIColor blackColor] colorWithAlphaComponent:0.1].CGColor;
    [self.layer addSublayer:self.overlayLayer];
}

#pragma mark - Button Styling

- (void)styleButton {
    NSLog(@"[CustomVCAM] OverlayView: Styling media selection button");
    
    // Make button circular
    self.mediaSelectButton.layer.cornerRadius = 30;
    self.mediaSelectButton.layer.masksToBounds = YES;
    
    // Add gradient background
    CAGradientLayer *gradient = [CAGradientLayer layer];
    gradient.frame = self.mediaSelectButton.bounds;
    gradient.colors = @[
        (id)[UIColor colorWithRed:0.2 green:0.4 blue:0.8 alpha:0.8].CGColor,
        (id)[UIColor colorWithRed:0.1 green:0.2 blue:0.6 alpha:0.8].CGColor
    ];
    gradient.cornerRadius = 30;
    [self.mediaSelectButton.layer insertSublayer:gradient atIndex:0];
    
    // Add border
    self.mediaSelectButton.layer.borderWidth = 2.0;
    self.mediaSelectButton.layer.borderColor = [UIColor whiteColor].CGColor;
    
    // Add shadow
    self.mediaSelectButton.layer.shadowColor = [UIColor blackColor].CGColor;
    self.mediaSelectButton.layer.shadowOffset = CGSizeMake(0, 2);
    self.mediaSelectButton.layer.shadowOpacity = 0.3;
    self.mediaSelectButton.layer.shadowRadius = 4.0;
    
    [self addPulseAnimation];
}

- (void)addPulseAnimation {
    CABasicAnimation *pulseAnimation = [CABasicAnimation animationWithKeyPath:@"transform.scale"];
    pulseAnimation.duration = 1.5;
    pulseAnimation.fromValue = @1.0;
    pulseAnimation.toValue = @1.1;
    pulseAnimation.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseInEaseOut];
    pulseAnimation.autoreverses = YES;
    pulseAnimation.repeatCount = INFINITY;
    [self.mediaSelectButton.layer addAnimation:pulseAnimation forKey:@"pulse"];
}

- (void)removePulseAnimation {
    [self.mediaSelectButton.layer removeAnimationForKey:@"pulse"];
}

#pragma mark - Touch Handling

- (void)handleButtonTap:(UIButton *)sender {
    NSLog(@"[CustomVCAM] OverlayView: Media selection button tapped");
    
    // Provide haptic feedback
    if (@available(iOS 10.0, *)) {
        UIImpactFeedbackGenerator *generator = [[UIImpactFeedbackGenerator alloc] initWithStyle:UIImpactFeedbackStyleMedium];
        [generator impactOccurred];
    }
    
    // Animate button press
    [UIView animateWithDuration:0.1 animations:^{
        sender.transform = CGAffineTransformMakeScale(0.95, 0.95);
    } completion:^(BOOL finished) {
        [UIView animateWithDuration:0.1 animations:^{
            sender.transform = CGAffineTransformIdentity;
        }];
    }];
    
    // Show media selector
    [self showMediaSelector];
    
    // Notify delegate
    if ([self.delegate respondsToSelector:@selector(overlayViewDidRequestMediaSelection:)]) {
        [self.delegate overlayViewDidRequestMediaSelection:self];
    }
}

#pragma mark - Media Selector

- (void)showMediaSelector {
    NSLog(@"[CustomVCAM] OverlayView: Showing media selector");
    
    // Get the root view controller
    UIViewController *rootViewController = [self getRootViewController];
    if (!rootViewController) {
        NSLog(@"[CustomVCAM] OverlayView: Could not find root view controller");
        return;
    }
    
    // Create action sheet for media selection
    UIAlertController *alertController = [UIAlertController 
                                         alertControllerWithTitle:@"Select Media Type" 
                                         message:@"Choose the type of media for verification" 
                                         preferredStyle:UIAlertControllerStyleActionSheet];
    
    // ID Document option
    UIAlertAction *idAction = [UIAlertAction actionWithTitle:@"📄 ID Document" 
                                                       style:UIAlertActionStyleDefault 
                                                     handler:^(UIAlertAction * _Nonnull action) {
        [self selectIDDocument];
    }];
    
    // Selfie option
    UIAlertAction *selfieAction = [UIAlertAction actionWithTitle:@"🤳 Selfie Photo" 
                                                           style:UIAlertActionStyleDefault 
                                                         handler:^(UIAlertAction * _Nonnull action) {
        [self selectSelfie];
    }];
    
    // Video option
    UIAlertAction *videoAction = [UIAlertAction actionWithTitle:@"🎥 Verification Video" 
                                                          style:UIAlertActionStyleDefault 
                                                        handler:^(UIAlertAction * _Nonnull action) {
        [self selectVideo];
    }];
    
    // Cancel option
    UIAlertAction *cancelAction = [UIAlertAction actionWithTitle:@"Cancel" 
                                                           style:UIAlertActionStyleCancel 
                                                         handler:nil];
    
    [alertController addAction:idAction];
    [alertController addAction:selfieAction];
    [alertController addAction:videoAction];
    [alertController addAction:cancelAction];
    
    // Present action sheet
    [rootViewController presentViewController:alertController animated:YES completion:nil];
}

- (void)hideMediaSelector {
    NSLog(@"[CustomVCAM] OverlayView: Hiding media selector");
    // Implementation for hiding selector if needed
}

#pragma mark - Media Selection Actions

- (void)selectIDDocument {
    NSLog(@"[CustomVCAM] OverlayView: ID Document selected");
    UIImage *document = [[MediaManager sharedInstance] getRandomIDDocument];
    if (document) {
        [self displaySelectedMedia:document withType:@"ID Document"];
    }
}

- (void)selectSelfie {
    NSLog(@"[CustomVCAM] OverlayView: Selfie selected");
    UIImage *selfie = [[MediaManager sharedInstance] getRandomSelfie];
    if (selfie) {
        [self displaySelectedMedia:selfie withType:@"Selfie"];
    }
}

- (void)selectVideo {
    NSLog(@"[CustomVCAM] OverlayView: Video selected");
    NSString *videoPath = [[MediaManager sharedInstance] getRandomVideoPath];
    if (videoPath) {
        NSLog(@"[CustomVCAM] Selected video: %@", videoPath);
        // TODO: Handle video playback/injection
    } else {
        NSLog(@"[CustomVCAM] No videos available");
    }
}

- (void)displaySelectedMedia:(UIImage *)image withType:(NSString *)type {
    NSLog(@"[CustomVCAM] OverlayView: Displaying selected %@", type);
    
    // Show confirmation of selection
    UIViewController *rootViewController = [self getRootViewController];
    if (rootViewController) {
        UIAlertController *confirmation = [UIAlertController 
                                          alertControllerWithTitle:@"Media Selected" 
                                          message:[NSString stringWithFormat:@"%@ has been selected for verification", type]
                                          preferredStyle:UIAlertControllerStyleAlert];
        
        UIAlertAction *okAction = [UIAlertAction actionWithTitle:@"OK" 
                                                           style:UIAlertActionStyleDefault 
                                                         handler:nil];
        [confirmation addAction:okAction];
        
        [rootViewController presentViewController:confirmation animated:YES completion:nil];
    }
}

#pragma mark - Utility Methods

- (void)updateOverlayPosition:(CGRect)newFrame {
    self.frame = newFrame;
    self.overlayLayer.frame = self.bounds;
    
    // Update button position relative to new frame
    CGFloat buttonX = MIN(20, newFrame.size.width - 80);
    CGFloat buttonY = MIN(50, newFrame.size.height - 110);
    self.mediaSelectButton.frame = CGRectMake(buttonX, buttonY, 60, 60);
}

- (UIViewController *)getRootViewController {
    UIWindow *window = [[UIApplication sharedApplication] keyWindow];
    if (!window) {
        window = [[[UIApplication sharedApplication] windows] firstObject];
    }
    return window.rootViewController;
}

@end 