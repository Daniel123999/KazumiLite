#import <Foundation/Foundation.h>
#import "KLModels.h"

typedef NS_ENUM(NSInteger, KLDownloadStatus) {
    KLDownloadStatusWaiting = 0,
    KLDownloadStatusDownloading,
    KLDownloadStatusCompleted,
    KLDownloadStatusFailed,
    KLDownloadStatusCancelled
};

@interface KLDownloadEntry : NSObject
@property (nonatomic, copy) NSString *identifier;
@property (nonatomic, copy) NSString *title;
@property (nonatomic, copy) NSString *episodeTitle;
@property (nonatomic, assign) NSInteger episodeNumber;
@property (nonatomic, strong) KLBangumiItem *bangumi;
@property (nonatomic, copy) NSString *ruleName;
@property (nonatomic, copy) NSString *pageURL;
@property (nonatomic, copy) NSString *localPath;
@property (nonatomic, assign) double progress;
@property (nonatomic, assign) NSInteger status;
@property (nonatomic, assign) double updatedAt;
@property (nonatomic, copy) NSString *errorMessage;
+ (instancetype)fromDictionary:(NSDictionary *)dict;
- (NSDictionary *)toDictionary;
- (NSString *)statusText;
@end

@interface KLDownloadManager : NSObject
+ (instancetype)shared;
@property (nonatomic, readonly) NSArray *entries;
- (void)load;
- (void)startDownloadForBangumi:(KLBangumiItem *)bangumi
                            rule:(KLRule *)rule
                       pageURL:(NSString *)pageURL
                  episodeIndex:(NSInteger)episodeIndex
                  episodeTitle:(NSString *)episodeTitle;
- (void)cancelEntry:(KLDownloadEntry *)entry;
- (void)removeEntry:(KLDownloadEntry *)entry;
- (NSString *)absolutePathForEntry:(KLDownloadEntry *)entry;
@end
