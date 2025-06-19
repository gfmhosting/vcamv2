#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <AVFoundation/AVFoundation.h>

@interface SimpleMediaManager : NSObject

+ (instancetype)sharedInstance;
+ (BOOL)isVideoFile:(NSString *)filePath;
+ (BOOL)isImageFile:(NSString *)filePath;
+ (UIImage *)thumbnailFromVideo:(NSString *)videoPath atTime:(NSTimeInterval)time;
+ (NSString *)getMediaTypeFromPath:(NSString *)filePath;
+ (CGSize)getVideoDimensions:(NSString *)videoPath;
+ (NSTimeInterval)getVideoDuration:(NSString *)videoPath;
+ (BOOL)cleanupTempFiles;

@end 