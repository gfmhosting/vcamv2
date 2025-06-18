#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <AVFoundation/AVFoundation.h>
#import <CoreMedia/CoreMedia.h>

@interface SimpleMediaManager : NSObject

@property (nonatomic, strong) UIImage *selectedImage;
@property (nonatomic, assign) BOOL hasMedia;

+ (instancetype)sharedInstance;
- (void)presentGallery;
- (CMSampleBufferRef)createSampleBufferFromImage;
- (CVPixelBufferRef)createPixelBufferFromImage:(UIImage *)image;
- (BOOL)hasAvailableMedia;
- (void)saveImageToSharedLocation:(UIImage *)image;
- (UIImage *)loadImageFromSharedLocation;

@end 