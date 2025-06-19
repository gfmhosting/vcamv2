#import <Foundation/Foundation.h>
#import <AVFoundation/AVFoundation.h>
#import <CoreMedia/CoreMedia.h>
#import <CoreVideo/CoreVideo.h>
#import <UIKit/UIKit.h>

@interface MediaManager : NSObject

@property (nonatomic, strong) NSString *currentMediaPath;
@property (nonatomic, assign) BOOL isVideo;
@property (nonatomic, strong) UIImage *currentImage;
@property (nonatomic, strong) AVPlayer *videoPlayer;

- (instancetype)init;
- (BOOL)setMediaFromPath:(NSString *)mediaPath;
- (CMSampleBufferRef)createSampleBufferFromMediaPath:(NSString *)mediaPath;
- (CMSampleBufferRef)createSampleBufferFromImage:(UIImage *)image;
- (CMSampleBufferRef)createSampleBufferFromVideo:(NSString *)videoPath atTime:(CMTime)time;
- (CVPixelBufferRef)createPixelBufferFromImage:(UIImage *)image;
- (UIImage *)resizeImage:(UIImage *)image toSize:(CGSize)size;
- (void)cleanup;

@end 