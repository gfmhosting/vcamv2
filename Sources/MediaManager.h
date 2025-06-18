#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

@interface MediaManager : NSObject

// SAFE METHODS - No boot-time initialization
+ (instancetype)sharedInstanceSafe;

// SAFE Media injection methods - with error handling
- (void)injectMediaIntoPickerSafe:(UIImagePickerController *)picker;
- (NSString *)getFakeWebMediaResponseSafe;

// SAFE Media selection methods - lazy loading
- (UIImage *)getRandomIDDocumentSafe;
- (UIImage *)getRandomSelfieSafe;

// SAFE Media management - delayed until first use
- (void)loadMediaBundleSafe;
- (NSArray<UIImage *> *)getAllIDDocumentsSafe;
- (NSArray<UIImage *> *)getAllSelfiesSafe;

// SAFE Utility methods
- (UIImage *)createPlaceholderImageSafe:(NSString *)text;

@property (nonatomic, strong) NSArray<UIImage *> *idDocuments;
@property (nonatomic, strong) NSArray<UIImage *> *selfiePhotos;
@property (nonatomic, assign) BOOL mediaLoaded;
@property (nonatomic, assign) BOOL initializationSafe;

@end 