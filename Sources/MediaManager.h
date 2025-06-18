#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <Photos/Photos.h>
#import <AVFoundation/AVFoundation.h>
#import <CoreMedia/CoreMedia.h>
#import <VideoToolbox/VideoToolbox.h>

@interface MediaManager : NSObject

@property (nonatomic, strong) UIImage *selectedImage;
@property (nonatomic, strong) NSURL *selectedVideoURL;
@property (nonatomic, assign) BOOL isVideoSelected;
@property (nonatomic, strong) AVPlayer *videoPlayer;
@property (nonatomic, strong) AVPlayerItemVideoOutput *videoOutput;

+ (instancetype)sharedInstance;
- (void)presentMediaPicker:(UIViewController *)presentingViewController;
- (CMSampleBufferRef)createSampleBufferFromCurrentMedia:(CMTime)presentationTime;
- (CVPixelBufferRef)createPixelBufferFromImage:(UIImage *)image;
- (CVPixelBufferRef)createPixelBufferFromVideo:(CMTime)time;
- (void)randomizeImageMetadata:(NSMutableDictionary *)metadata;

@end 