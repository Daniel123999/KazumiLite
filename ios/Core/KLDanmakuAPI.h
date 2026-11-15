#import <Foundation/Foundation.h>
#import "KLModels.h"

@interface KLDanmakuAPI : NSObject

+ (instancetype)shared;

@property (nonatomic, copy) NSString *dandanAppId;
@property (nonatomic, copy) NSString *dandanAppKey;

- (void)fetchForBangumi:(KLBangumiItem *)item
                episode:(NSInteger)episode
             completion:(void (^)(NSArray *entries, NSString *source, NSError *error))completion;

- (void)searchDanDanForTitle:(NSString *)title
                  completion:(void (^)(NSArray *animes, NSError *error))completion;

- (void)fetchDanDanComments:(NSInteger)bangumiId
                    episode:(NSInteger)episode
                 completion:(void (^)(NSArray *entries, NSError *error))completion;

- (void)fetchBiliForTitle:(NSString *)title
                  episode:(NSInteger)episode
               completion:(void (^)(NSArray *entries, NSString *matchedTitle, NSError *error))completion;

- (void)fetchBiliForSeason:(NSInteger)seasonId
                   episode:(NSInteger)episode
                completion:(void (^)(NSArray *entries, NSError *error))completion;

- (NSArray *)cachedDanmakuForBangumi:(NSInteger)bid episode:(NSInteger)episode;
- (void)saveCache:(NSArray *)entries bangumi:(NSInteger)bid episode:(NSInteger)episode source:(NSString *)source;

@end
