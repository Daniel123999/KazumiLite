#import <Foundation/Foundation.h>

typedef void (^KLHttpCompletion)(id json, NSData *data, NSHTTPURLResponse *response, NSError *error);

@interface KLHttp : NSObject

+ (instancetype)shared;

@property (nonatomic, copy) NSString *userAgent;

+ (NSURLSessionDataTask *)GET:(NSString *)url
                     headers:(NSDictionary *)headers
                  completion:(KLHttpCompletion)completion;

+ (NSURLSessionDataTask *)POSTJSON:(NSString *)url
                          headers:(NSDictionary *)headers
                             body:(id)body
                       completion:(KLHttpCompletion)completion;

+ (NSURLSessionDataTask *)POSTForm:(NSString *)url
                          headers:(NSDictionary *)headers
                       parameters:(NSDictionary *)parameters
                       completion:(KLHttpCompletion)completion;

+ (NSURLSessionDataTask *)requestURL:(NSString *)url
                              method:(NSString *)method
                             headers:(NSDictionary *)headers
                                body:(NSData *)body
                          completion:(KLHttpCompletion)completion;

+ (NSURLSessionDataTask *)uploadMultipart:(NSString *)url
                                 headers:(NSDictionary *)headers
                               fieldName:(NSString *)fieldName
                                fileName:(NSString *)fileName
                                mimeType:(NSString *)mimeType
                                    data:(NSData *)data
                              completion:(KLHttpCompletion)completion;

+ (void)download:(NSString *)url
          toPath:(NSString *)path
        progress:(void (^)(double fraction, int64_t received, int64_t expected))progress
      completion:(void (^)(NSString *path, NSError *error))completion;

+ (NSString *)encode:(NSString *)string;
+ (NSString *)queryString:(NSDictionary *)params;
+ (NSString *)randomUserAgent;
+ (NSString *)appendQuery:(NSDictionary *)params toURL:(NSString *)url;

@end
