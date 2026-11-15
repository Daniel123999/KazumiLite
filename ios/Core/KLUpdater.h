#import <Foundation/Foundation.h>

@interface KLUpdater : NSObject

+ (void)checkForUpdateWithCompletion:(void (^)(NSDictionary *releaseInfo, NSError *error))completion;
+ (BOOL)isReleaseNewer:(NSDictionary *)releaseInfo;
+ (void)installRelease:(NSDictionary *)releaseInfo
              progress:(void (^)(NSString *status))progress
      downloadProgress:(void (^)(double fraction))downloadProgress
            completion:(void (^)(NSError *error))completion;
+ (void)cleanupStalePackages;
+ (void)relaunchApplication;

@end
