#import <Foundation/Foundation.h>
#import <CoreMedia/CoreMedia.h>

@interface SimpleMediaManager : NSObject

+ (CMSampleBufferRef)createSampleBufferFromPixelBuffer:(CVPixelBufferRef)pixelBuffer withTimestamp:(CMTime)timestamp;
+ (void)logDebug:(NSString *)message;

@end 