#import <Foundation/Foundation.h>
#import "KLModels.h"

@interface KLRuleEngine : NSObject

+ (instancetype)shared;

- (void)searchWithRule:(KLRule *)rule
              keyword:(NSString *)keyword
           completion:(void (^)(NSArray *items, NSError *error))completion;

- (void)chaptersWithRule:(KLRule *)rule
                  source:(NSString *)source
              completion:(void (^)(NSArray *roads, NSError *error))completion;

- (NSString *)fullURLForRule:(KLRule *)rule path:(NSString *)path;
- (NSString *)buildEpisodePageURL:(KLRule *)rule source:(NSString *)source episodeURL:(NSString *)episodeURL variables:(NSDictionary *)variables;

@end
