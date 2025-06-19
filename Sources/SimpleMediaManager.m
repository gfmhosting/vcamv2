#import "SimpleMediaManager.h"

@implementation SimpleMediaManager

+ (instancetype)sharedInstance {
    static SimpleMediaManager *sharedInstance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedInstance = [[self alloc] init];
    });
    return sharedInstance;
}

+ (BOOL)isVideoFile:(NSString *)filePath {
    if (!filePath) return NO;
    
    NSString *extension = [filePath pathExtension].lowercaseString;
    NSArray *videoExtensions = @[@"mp4", @"mov", @"m4v", @"avi", @"mkv", @"wmv", @"flv"];
    
    return [videoExtensions containsObject:extension];
}

+ (BOOL)isImageFile:(NSString *)filePath {
    if (!filePath) return NO;
    
    NSString *extension = [filePath pathExtension].lowercaseString;
    NSArray *imageExtensions = @[@"jpg", @"jpeg", @"png", @"gif", @"bmp", @"tiff", @"heic", @"heif"];
    
    return [imageExtensions containsObject:extension];
}

+ (UIImage *)thumbnailFromVideo:(NSString *)videoPath atTime:(NSTimeInterval)time {
    if (![self isVideoFile:videoPath]) {
        NSLog(@"[CustomVCAM SimpleMediaManager] Not a video file: %@", videoPath);
        return nil;
    }
    
    NSURL *videoURL = [NSURL fileURLWithPath:videoPath];
    AVAsset *asset = [AVAsset assetWithURL:videoURL];
    
    AVAssetImageGenerator *imageGenerator = [AVAssetImageGenerator assetImageGeneratorWithAsset:asset];
    imageGenerator.appliesPreferredTrackTransform = YES;
    imageGenerator.requestedTimeToleranceBefore = kCMTimeZero;
    imageGenerator.requestedTimeToleranceAfter = kCMTimeZero;
    
    CMTime requestedTime = CMTimeMakeWithSeconds(time, 600);
    
    NSError *error = nil;
    CGImageRef cgImage = [imageGenerator copyCGImageAtTime:requestedTime actualTime:NULL error:&error];
    
    if (error || !cgImage) {
        NSLog(@"[CustomVCAM SimpleMediaManager] Failed to generate thumbnail: %@", error.localizedDescription);
        return nil;
    }
    
    UIImage *thumbnail = [UIImage imageWithCGImage:cgImage];
    CGImageRelease(cgImage);
    
    return thumbnail;
}

+ (NSString *)getMediaTypeFromPath:(NSString *)filePath {
    if ([self isVideoFile:filePath]) {
        return @"video";
    } else if ([self isImageFile:filePath]) {
        return @"image";
    } else {
        return @"unknown";
    }
}

+ (CGSize)getVideoDimensions:(NSString *)videoPath {
    if (![self isVideoFile:videoPath]) {
        return CGSizeZero;
    }
    
    NSURL *videoURL = [NSURL fileURLWithPath:videoPath];
    AVAsset *asset = [AVAsset assetWithURL:videoURL];
    
    NSArray *videoTracks = [asset tracksWithMediaType:AVMediaTypeVideo];
    if (videoTracks.count == 0) {
        return CGSizeZero;
    }
    
    AVAssetTrack *videoTrack = videoTracks.firstObject;
    CGSize naturalSize = videoTrack.naturalSize;
    CGAffineTransform transform = videoTrack.preferredTransform;
    
    CGSize transformedSize = CGSizeApplyAffineTransform(naturalSize, transform);
    
    return CGSizeMake(fabs(transformedSize.width), fabs(transformedSize.height));
}

+ (NSTimeInterval)getVideoDuration:(NSString *)videoPath {
    if (![self isVideoFile:videoPath]) {
        return 0.0;
    }
    
    NSURL *videoURL = [NSURL fileURLWithPath:videoPath];
    AVAsset *asset = [AVAsset assetWithURL:videoURL];
    
    CMTime duration = asset.duration;
    if (CMTIME_IS_VALID(duration)) {
        return CMTimeGetSeconds(duration);
    }
    
    return 0.0;
}

+ (BOOL)cleanupTempFiles {
    NSString *tempDir = NSTemporaryDirectory();
    NSFileManager *fileManager = [NSFileManager defaultManager];
    NSError *error = nil;
    
    NSArray *tempFiles = [fileManager contentsOfDirectoryAtPath:tempDir error:&error];
    if (error) {
        NSLog(@"[CustomVCAM SimpleMediaManager] Error reading temp directory: %@", error.localizedDescription);
        return NO;
    }
    
    NSUInteger cleanedCount = 0;
    
    for (NSString *filename in tempFiles) {
        if ([filename hasPrefix:@"customvcam_"]) {
            NSString *filePath = [tempDir stringByAppendingPathComponent:filename];
            
            NSError *deleteError = nil;
            if ([fileManager removeItemAtPath:filePath error:&deleteError]) {
                cleanedCount++;
            } else {
                NSLog(@"[CustomVCAM SimpleMediaManager] Failed to delete temp file %@: %@", filename, deleteError.localizedDescription);
            }
        }
    }
    
    NSLog(@"[CustomVCAM SimpleMediaManager] Cleaned up %lu temp files", (unsigned long)cleanedCount);
    return YES;
}

@end