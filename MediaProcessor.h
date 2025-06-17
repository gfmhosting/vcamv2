#import <UIKit/UIKit.h>
#import <AVFoundation/AVFoundation.h>
#import <CoreMedia/CoreMedia.h>

@interface MediaProcessor : NSObject <AVCaptureVideoDataOutputSampleBufferDelegate>

+ (instancetype)sharedInstance;
- (void)setSelectedMedia:(UIImage *)image;
- (void)enableReplacement;
- (void)disableReplacement;
- (BOOL)isReplacementEnabled;
- (CVPixelBufferRef)processSelectedMedia:(UIImage *)image;
- (CVPixelBufferRef)getCurrentFrame;

@property (nonatomic, strong) UIImage *selectedImage;
@property (nonatomic, assign) BOOL replacementEnabled;
@property (nonatomic, assign) CVPixelBufferRef cachedPixelBuffer;

@end 