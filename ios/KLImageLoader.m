#import "KLImageLoader.h"
#import "KLTheme.h"
#import "KLStore.h"
#import "KLHttp.h"
#import <CommonCrypto/CommonDigest.h>
#import <string.h>

static NSString *KLMD5(NSString *string) {
    const char *cstr = [string UTF8String];
    unsigned char digest[CC_MD5_DIGEST_LENGTH];
    CC_MD5(cstr, (CC_LONG)strlen(cstr), digest);
    NSMutableString *out = [NSMutableString stringWithCapacity:CC_MD5_DIGEST_LENGTH * 2];
    for (int i = 0; i < CC_MD5_DIGEST_LENGTH; i++) [out appendFormat:@"%02x", digest[i]];
    return out;
}

@interface KLImageLoader ()
@property (nonatomic, strong) NSCache *memory;
@property (nonatomic, strong) NSMutableDictionary *tasks;
@property (nonatomic, strong) NSMutableArray *waiting;
@property (nonatomic, assign) NSInteger activeCount;
@property (nonatomic, copy) NSString *diskPath;
@end

@implementation KLImageLoader

+ (instancetype)shared {
    static KLImageLoader *loader = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{ loader = [[KLImageLoader alloc] init]; });
    return loader;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        _memory = [[NSCache alloc] init];
        _memory.countLimit = 80;
        _tasks = [NSMutableDictionary dictionary];
        _waiting = [NSMutableArray array];
        _diskPath = [[KLStore shared].cachePath stringByAppendingPathComponent:@"images"];
        [[NSFileManager defaultManager] createDirectoryAtPath:_diskPath withIntermediateDirectories:YES attributes:nil error:NULL];
    }
    return self;
}

- (UIImage *)memoryImageForURL:(NSString *)url {
    if (!url.length) return nil;
    return [self.memory objectForKey:url];
}

- (NSString *)diskFileForURL:(NSString *)url {
    return [self.diskPath stringByAppendingPathComponent:KLMD5(url)];
}

- (void)loadURL:(NSString *)url completion:(void (^)(UIImage *, NSError *))completion {
    if (!url.length) {
        if (completion) completion(nil, [NSError errorWithDomain:@"KLImage" code:-1 userInfo:@{NSLocalizedDescriptionKey: @"空地址"}]);
        return;
    }
    UIImage *cached = [self.memory objectForKey:url];
    if (cached) { if (completion) completion(cached, nil); return; }

    NSString *file = [self diskFileForURL:url];
    UIImage *disk = [UIImage imageWithContentsOfFile:file];
    if (disk) {
        [self.memory setObject:disk forKey:url];
        if (completion) completion(disk, nil);
        return;
    }

    NSDictionary *request = @{@"url": url, @"completion": [completion copy]};
    @synchronized (self) {
        if (self.tasks[url]) return; // A duplicate request will share the first completion only; acceptable for cells.
        if (self.activeCount >= 3) {
            [self.waiting addObject:request];
            return;
        }
        self.activeCount++;
        self.tasks[url] = request;
    }
    [self startRequest:url];
}

- (void)startRequest:(NSString *)url {
    __weak typeof(self) weakSelf = self;
    NSURLSessionDataTask *task = [KLHttp GET:url headers:nil completion:^(id json, NSData *data, NSHTTPURLResponse *response, NSError *error) {
        __strong typeof(weakSelf) strongSelf = weakSelf;
        UIImage *image = nil;
        if (data.length) image = [UIImage imageWithData:data];
        if (image) {
            image = [strongSelf downscaleImage:image maxWidth:600];
            [strongSelf.memory setObject:image forKey:url];
            [data writeToFile:[strongSelf diskFileForURL:url] atomically:YES];
        }
        NSDictionary *request = nil;
        @synchronized (strongSelf) {
            request = strongSelf.tasks[url];
            [strongSelf.tasks removeObjectForKey:url];
            strongSelf.activeCount = MAX(0, strongSelf.activeCount - 1);
        }
        void (^done)(UIImage *, NSError *) = request[@"completion"];
        if (done) done(image, image ? nil : (error ?: [NSError errorWithDomain:@"KLImage" code:-2 userInfo:@{NSLocalizedDescriptionKey: @"图片解码失败"}]));
        [strongSelf drainQueue];
    }];
    @synchronized (self) {
        if (self.tasks[url]) {
            NSMutableDictionary *d = [self.tasks[url] mutableCopy];
            d[@"task"] = task;
            self.tasks[url] = d;
        }
    }
}

- (UIImage *)downscaleImage:(UIImage *)image maxWidth:(CGFloat)maxWidth {
    if (image.size.width <= maxWidth) return image;
    CGFloat scale = maxWidth / image.size.width;
    CGSize size = CGSizeMake(maxWidth, image.size.height * scale);
    UIGraphicsBeginImageContextWithOptions(size, NO, 1.0);
    [image drawInRect:CGRectMake(0, 0, size.width, size.height)];
    UIImage *result = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return result ?: image;
}

- (void)drainQueue {
    NSDictionary *next = nil;
    @synchronized (self) {
        if (self.waiting.count == 0 || self.activeCount >= 3) return;
        next = self.waiting.firstObject;
        [self.waiting removeObjectAtIndex:0];
        self.activeCount++;
        self.tasks[next[@"url"]] = next;
    }
    if (next) [self startRequest:next[@"url"]];
}

- (void)cancelURL:(NSString *)url {
    if (!url.length) return;
    @synchronized (self) {
        NSDictionary *request = self.tasks[url];
        [request[@"task"] cancel];
        [self.tasks removeObjectForKey:url];
        NSMutableArray *keep = [NSMutableArray array];
        for (NSDictionary *d in self.waiting) if (![d[@"url"] isEqualToString:url]) [keep addObject:d];
        self.waiting = keep;
    }
}

- (void)clearMemoryCache { [self.memory removeAllObjects]; }
- (void)clearDiskCache {
    [[NSFileManager defaultManager] removeItemAtPath:self.diskPath error:NULL];
    [[NSFileManager defaultManager] createDirectoryAtPath:self.diskPath withIntermediateDirectories:YES attributes:nil error:NULL];
}

@end

@interface KLAsyncImageView ()
@property (nonatomic, strong) UIActivityIndicatorView *spinner;
@end

@implementation KLAsyncImageView

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        self.clipsToBounds = YES;
        self.contentMode = UIViewContentModeScaleAspectFill;
        self.backgroundColor = [KLTheme separator];
        _placeholderColor = [KLTheme separator];
        _spinner = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleWhite];
        _spinner.hidesWhenStopped = YES;
        _spinner.center = CGPointMake(CGRectGetWidth(frame) / 2, CGRectGetHeight(frame) / 2);
        _spinner.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleRightMargin | UIViewAutoresizingFlexibleTopMargin | UIViewAutoresizingFlexibleBottomMargin;
        [self addSubview:_spinner];
    }
    return self;
}

- (void)layoutSubviews {
    [super layoutSubviews];
    self.spinner.center = CGPointMake(CGRectGetWidth(self.bounds) / 2, CGRectGetHeight(self.bounds) / 2);
    if (self.rounded) self.layer.cornerRadius = MIN(CGRectGetWidth(self.bounds), CGRectGetHeight(self.bounds)) / 2;
}

- (void)setImageURL:(NSString *)imageURL placeholder:(UIImage *)placeholder {
    [self cancelLoading];
    _imageURL = [imageURL copy];
    self.image = placeholder;
    self.backgroundColor = self.placeholderColor;
    if (!imageURL.length) return;

    UIImage *cached = [[KLImageLoader shared] memoryImageForURL:imageURL];
    if (cached) { self.image = cached; return; }
    [self.spinner startAnimating];
    __weak typeof(self) weakSelf = self;
    [[KLImageLoader shared] loadURL:imageURL completion:^(UIImage *image, NSError *error) {
        __strong typeof(weakSelf) strongSelf = weakSelf;
        [strongSelf.spinner stopAnimating];
        if (![strongSelf.imageURL isEqualToString:imageURL]) return;
        if (image) {
            strongSelf.image = image;
            strongSelf.backgroundColor = [UIColor clearColor];
        }
    }];
}

- (void)cancelLoading {
    if (self.imageURL.length) [[KLImageLoader shared] cancelURL:self.imageURL];
    [self.spinner stopAnimating];
}

@end
