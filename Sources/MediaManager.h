#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <AVFoundation/AVFoundation.h>

@interface MediaManager : NSObject

@property (nonatomic, strong) NSURL *selectedMediaURL;
@property (nonatomic, strong) UIImage *selectedImage;
@property (nonatomic, assign) BOOL isVideoMode;
@property (nonatomic, assign) BOOL vcamEnabled;

+ (instancetype)sharedManager;
- (void)selectMediaWithCompletion:(void(^)(BOOL success))completion;
- (CVPixelBufferRef)getCurrentFrameForTime:(CMTime)time;
- (void)enableVCAM;
- (void)disableVCAM;
- (void)logDebug:(NSString *)message;

@end 