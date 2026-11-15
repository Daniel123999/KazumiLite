#import "KLHttp.h"
#import <UIKit/UIKit.h>

@interface KLTrustDelegate : NSObject <NSURLSessionDelegate>
@end

@implementation KLTrustDelegate
- (void)URLSession:(NSURLSession *)session
    didReceiveChallenge:(NSURLAuthenticationChallenge *)challenge
      completionHandler:(void (^)(NSURLSessionAuthChallengeDisposition, NSURLCredential *))completionHandler {
    if ([challenge.protectionSpace.authenticationMethod isEqualToString:NSURLAuthenticationMethodServerTrust] &&
        challenge.protectionSpace.serverTrust) {
        completionHandler(NSURLSessionAuthChallengeUseCredential,
                          [NSURLCredential credentialForTrust:challenge.protectionSpace.serverTrust]);
        return;
    }
    completionHandler(NSURLSessionAuthChallengePerformDefaultHandling, nil);
}
@end

@interface KLHttp () <NSURLSessionDelegate, NSURLSessionDownloadDelegate>
@property (nonatomic, strong) NSURLSession *session;
@end

@interface KLHttpProgressPoller : NSObject
@property (nonatomic, weak) NSURLSessionTask *task;
@property (nonatomic, copy) void (^handler)(void);
@property (nonatomic, strong) NSTimer *timer;
@end
@implementation KLHttpProgressPoller
- (void)start {
    self.timer = [NSTimer timerWithTimeInterval:0.3 target:self selector:@selector(tick:) userInfo:nil repeats:YES];
    [[NSRunLoop mainRunLoop] addTimer:self.timer forMode:NSRunLoopCommonModes];
}
- (void)tick:(NSTimer *)timer {
    if (self.handler) self.handler();
    if (!self.task || self.task.state == NSURLSessionTaskStateCompleted || self.task.state == NSURLSessionTaskStateCanceling) {
        [timer invalidate];
        self.timer = nil;
    }
}
@end

@implementation KLHttp

+ (instancetype)shared {
    static KLHttp *http = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{ http = [[KLHttp alloc] init]; });
    return http;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        NSURLSessionConfiguration *config = [NSURLSessionConfiguration defaultSessionConfiguration];
        config.timeoutIntervalForRequest = 25;
        config.timeoutIntervalForResource = 120;
        config.requestCachePolicy = NSURLRequestReloadIgnoringLocalCacheData;
        config.HTTPMaximumConnectionsPerHost = 4;
        _session = [NSURLSession sessionWithConfiguration:config
                                                 delegate:[[KLTrustDelegate alloc] init]
                                            delegateQueue:nil];
        _userAgent = [KLHttp randomUserAgent];
    }
    return self;
}

+ (NSString *)randomUserAgent {
    static NSArray *agents = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        agents = @[
            @"Mozilla/5.0 (iPhone; CPU iPhone OS 9_3_6 like Mac OS X) AppleWebKit/601.1.46 (KHTML, like Gecko) Version/9.0 Mobile/13G37 Safari/601.1",
            @"Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36",
            @"Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Safari/605.1.15",
            @"Mozilla/5.0 (Linux; Android 13) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Mobile Safari/537.36"
        ];
    });
    return agents[arc4random_uniform((uint32_t)agents.count)];
}

+ (NSString *)encode:(NSString *)string {
    if (![string isKindOfClass:[NSString class]]) return @"";
    NSMutableCharacterSet *set = [[NSCharacterSet alphanumericCharacterSet] mutableCopy];
    [set addCharactersInString:@"-._~"];
    return [string stringByAddingPercentEncodingWithAllowedCharacters:set] ?: @"";
}

+ (NSString *)queryString:(NSDictionary *)params {
    if (![params isKindOfClass:[NSDictionary class]] || params.count == 0) return @"";
    NSMutableArray *pairs = [NSMutableArray array];
    for (NSString *key in params) {
        id value = params[key];
        if (value == [NSNull null]) continue;
        [pairs addObject:[NSString stringWithFormat:@"%@=%@", [self encode:key], [self encode:[value description]]]];
    }
    return [pairs componentsJoinedByString:@"&"];
}

+ (NSString *)appendQuery:(NSDictionary *)params toURL:(NSString *)url {
    NSString *q = [self queryString:params];
    if (q.length == 0) return url;
    return [url stringByAppendingFormat:@"%@%@", [url containsString:@"?"] ? @"&" : @"?", q];
}

+ (NSMutableURLRequest *)baseRequest:(NSString *)url method:(NSString *)method headers:(NSDictionary *)headers {
    NSURL *u = [NSURL URLWithString:url];
    if (!u) return nil;
    NSMutableURLRequest *req = [NSMutableURLRequest requestWithURL:u
                                                      cachePolicy:NSURLRequestReloadIgnoringLocalCacheData
                                                  timeoutInterval:25];
    req.HTTPMethod = method ?: @"GET";
    [req setValue:[KLHttp shared].userAgent forHTTPHeaderField:@"User-Agent"];
    [req setValue:@"zh-CN,zh;q=0.9,en;q=0.8" forHTTPHeaderField:@"Accept-Language"];
    for (NSString *key in headers) {
        id value = headers[key];
        if ([value isKindOfClass:[NSString class]]) [req setValue:value forHTTPHeaderField:key];
    }
    return req;
}

+ (NSURLSessionDataTask *)requestURL:(NSString *)url
                              method:(NSString *)method
                             headers:(NSDictionary *)headers
                                body:(NSData *)body
                          completion:(KLHttpCompletion)completion {
    NSMutableURLRequest *req = [self baseRequest:url method:method headers:headers];
    if (!req) {
        if (completion) completion(nil, nil, nil, [NSError errorWithDomain:@"KLHttp" code:-1 userInfo:@{NSLocalizedDescriptionKey: @"无效的请求地址"}]);
        return nil;
    }
    if (body) req.HTTPBody = body;
    NSURLSessionDataTask *task = [[KLHttp shared].session dataTaskWithRequest:req
        completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
            NSHTTPURLResponse *http = [response isKindOfClass:[NSHTTPURLResponse class]] ? (NSHTTPURLResponse *)response : nil;
            id json = nil;
            if (data.length) {
                json = [NSJSONSerialization JSONObjectWithData:data options:0 error:NULL];
                if (!json) {
                    NSString *text = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
                    if (!text) text = [[NSString alloc] initWithData:data encoding:CFStringConvertEncodingToNSStringEncoding(kCFStringEncodingGB_18030_2000)];
                    json = text;
                }
            }
            if (http.statusCode >= 400 && !error) {
                error = [NSError errorWithDomain:@"KLHttp"
                                            code:http.statusCode
                                        userInfo:@{NSLocalizedDescriptionKey: [NSString stringWithFormat:@"HTTP %ld", (long)http.statusCode]}];
            }
            dispatch_async(dispatch_get_main_queue(), ^{
                if (completion) completion(json, data, http, error);
            });
        }];
    [task resume];
    return task;
}

+ (NSURLSessionDataTask *)GET:(NSString *)url headers:(NSDictionary *)headers completion:(KLHttpCompletion)completion {
    return [self requestURL:url method:@"GET" headers:headers body:nil completion:completion];
}

+ (NSURLSessionDataTask *)POSTJSON:(NSString *)url headers:(NSDictionary *)headers body:(id)body completion:(KLHttpCompletion)completion {
    NSMutableDictionary *h = [NSMutableDictionary dictionaryWithDictionary:headers ?: @{}];
    if (!h[@"Content-Type"]) h[@"Content-Type"] = @"application/json; charset=utf-8";
    NSData *data = nil;
    if ([body isKindOfClass:[NSData class]]) data = body;
    else if (body) data = [NSJSONSerialization dataWithJSONObject:body options:0 error:NULL];
    return [self requestURL:url method:@"POST" headers:h body:data completion:completion];
}

+ (NSURLSessionDataTask *)POSTForm:(NSString *)url headers:(NSDictionary *)headers parameters:(NSDictionary *)parameters completion:(KLHttpCompletion)completion {
    NSMutableDictionary *h = [NSMutableDictionary dictionaryWithDictionary:headers ?: @{}];
    if (!h[@"Content-Type"]) h[@"Content-Type"] = @"application/x-www-form-urlencoded; charset=UTF-8";
    NSData *data = [[self queryString:parameters] dataUsingEncoding:NSUTF8StringEncoding];
    return [self requestURL:url method:@"POST" headers:h body:data completion:completion];
}

+ (NSURLSessionDataTask *)uploadMultipart:(NSString *)url
                                 headers:(NSDictionary *)headers
                               fieldName:(NSString *)fieldName
                                fileName:(NSString *)fileName
                                mimeType:(NSString *)mimeType
                                    data:(NSData *)data
                              completion:(KLHttpCompletion)completion {
    NSString *boundary = [NSString stringWithFormat:@"----KazumiLite%08X", arc4random()];
    NSMutableDictionary *h = [NSMutableDictionary dictionaryWithDictionary:headers ?: @{}];
    h[@"Content-Type"] = [NSString stringWithFormat:@"multipart/form-data; boundary=%@", boundary];
    NSMutableData *body = [NSMutableData data];
    [body appendData:[[NSString stringWithFormat:@"--%@\r\n", boundary] dataUsingEncoding:NSUTF8StringEncoding]];
    [body appendData:[[NSString stringWithFormat:@"Content-Disposition: form-data; name=\"%@\"; filename=\"%@\"\r\n", fieldName, fileName] dataUsingEncoding:NSUTF8StringEncoding]];
    [body appendData:[[NSString stringWithFormat:@"Content-Type: %@\r\n\r\n", mimeType] dataUsingEncoding:NSUTF8StringEncoding]];
    [body appendData:data];
    [body appendData:[[NSString stringWithFormat:@"\r\n--%@--\r\n", boundary] dataUsingEncoding:NSUTF8StringEncoding]];
    return [self requestURL:url method:@"POST" headers:h body:body completion:completion];
}

+ (void)download:(NSString *)url
          toPath:(NSString *)path
        progress:(void (^)(double, int64_t, int64_t))progress
      completion:(void (^)(NSString *, NSError *))completion {
    NSMutableURLRequest *req = [self baseRequest:url method:@"GET" headers:nil];
    if (!req) {
        if (completion) completion(nil, [NSError errorWithDomain:@"KLHttp" code:-1 userInfo:@{NSLocalizedDescriptionKey: @"无效的下载地址"}]);
        return;
    }
    req.timeoutInterval = 600;
    NSURLSessionDownloadTask *task = [[KLHttp shared].session downloadTaskWithRequest:req
        completionHandler:^(NSURL *location, NSURLResponse *response, NSError *error) {
            if (error || !location) {
                dispatch_async(dispatch_get_main_queue(), ^{ if (completion) completion(nil, error ?: [NSError errorWithDomain:@"KLHttp" code:-2 userInfo:@{NSLocalizedDescriptionKey: @"下载失败"}]); });
                return;
            }
            NSString *dir = [path stringByDeletingLastPathComponent];
            [[NSFileManager defaultManager] createDirectoryAtPath:dir withIntermediateDirectories:YES attributes:nil error:NULL];
            [[NSFileManager defaultManager] removeItemAtPath:path error:NULL];
            NSError *moveError = nil;
            [[NSFileManager defaultManager] moveItemAtURL:location toURL:[NSURL fileURLWithPath:path] error:&moveError];
            dispatch_async(dispatch_get_main_queue(), ^{ if (completion) completion(moveError ? nil : path, moveError); });
        }];
    if (progress) {
        KLHttpProgressPoller *poller = [[KLHttpProgressPoller alloc] init];
        poller.task = task;
        poller.handler = ^{
            int64_t expected = task.countOfBytesExpectedToReceive;
            int64_t received = task.countOfBytesReceived;
            if (expected > 0) progress((double)received / (double)expected, received, expected);
        };
        [poller start];
    }
    [task resume];
}

@end
