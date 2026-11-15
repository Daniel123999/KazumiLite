#import <Foundation/Foundation.h>
#import "KLModels.h"

@interface KLBangumiAPI : NSObject

+ (instancetype)shared;

@property (nonatomic, copy) NSString *token;
@property (nonatomic, copy) NSString *username;

- (void)calendar:(void (^)(NSArray *days, NSError *error))completion;
- (void)trendingWithLimit:(NSInteger)limit offset:(NSInteger)offset completion:(void (^)(NSArray *items, NSError *error))completion;
- (void)search:(NSString *)keyword limit:(NSInteger)limit offset:(NSInteger)offset completion:(void (^)(NSArray *items, NSInteger rawCount, NSError *error))completion;
- (void)subject:(NSInteger)bid completion:(void (^)(KLBangumiItem *item, NSError *error))completion;
- (void)episodes:(NSInteger)bid completion:(void (^)(NSArray *episodes, NSError *error))completion;
- (void)comments:(NSInteger)bid limit:(NSInteger)limit offset:(NSInteger)offset completion:(void (^)(NSArray *comments, NSError *error))completion;
- (void)relations:(NSInteger)bid completion:(void (^)(NSArray *items, NSError *error))completion;
- (void)validateToken:(NSString *)token completion:(void (^)(NSString *username, NSError *error))completion;
- (void)updateCollection:(NSInteger)bid type:(NSInteger)type completion:(void (^)(BOOL ok, NSError *error))completion;
- (void)userCollections:(NSString *)username token:(NSString *)token completion:(void (^)(NSArray *items, NSError *error))completion;

@end
