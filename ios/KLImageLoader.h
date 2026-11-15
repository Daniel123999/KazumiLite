#import <UIKit/UIKit.h>

@interface KLImageLoader : NSObject

+ (instancetype)shared;

- (UIImage *)memoryImageForURL:(NSString *)url;
- (void)loadURL:(NSString *)url completion:(void (^)(UIImage *image, NSError *error))completion;
- (void)cancelURL:(NSString *)url;
- (void)clearMemoryCache;
- (void)clearDiskCache;

@end

@interface KLAsyncImageView : UIImageView

@property (nonatomic, copy) NSString *imageURL;
@property (nonatomic, strong) UIColor *placeholderColor;
@property (nonatomic, assign) BOOL rounded;

- (void)setImageURL:(NSString *)imageURL placeholder:(UIImage *)placeholder;
- (void)cancelLoading;

@end
