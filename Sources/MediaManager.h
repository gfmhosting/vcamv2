#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <AVFoundation/AVFoundation.h>
#import <Photos/Photos.h>

@interface MediaManager : NSObject

+ (instancetype)sharedInstance;

// Media injection methods
- (void)injectMediaIntoPicker:(UIImagePickerController *)picker;
- (void)setupFakeStream:(AVCaptureSession *)session;
- (NSString *)getFakeWebMediaResponse;

// Media selection methods
- (UIImage *)getRandomIDDocument;
- (UIImage *)getRandomSelfie;
- (NSString *)getRandomVideoPath;

// Media management
- (void)loadMediaBundle;
- (NSArray<UIImage *> *)getAllIDDocuments;
- (NSArray<UIImage *> *)getAllSelfies;
- (NSArray<NSString *> *)getAllVideoPaths;

// Utility methods
- (UIImage *)addRandomNoise:(UIImage *)image;
- (UIImage *)adjustImageMetadata:(UIImage *)image;
- (NSData *)createFakeEXIFData;

@property (nonatomic, strong) NSArray<UIImage *> *idDocuments;
@property (nonatomic, strong) NSArray<UIImage *> *selfiePhotos;
@property (nonatomic, strong) NSArray<NSString *> *videoPaths;
@property (nonatomic, assign) BOOL mediaLoaded;

@end 