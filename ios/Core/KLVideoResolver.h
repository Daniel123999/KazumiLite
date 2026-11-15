#import <Foundation/Foundation.h>
#import <WebKit/WebKit.h>
#import "KLModels.h"

@interface KLVideoResolver : NSObject

+ (instancetype)shared;

/// Resolve a playable media URL from an episode page.
/// If the page is already a direct media URL it returns immediately.
- (void)resolvePage:(NSString *)pageURL
               rule:(KLRule *)rule
         completion:(void (^)(NSString *videoURL, NSDictionary *headers, NSError *error))completion;

- (void)cancel;
- (BOOL)isDirectMediaURL:(NSString *)url;

@end
