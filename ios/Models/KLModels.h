#import <Foundation/Foundation.h>

#pragma mark - Bangumi

@interface KLBangumiItem : NSObject
@property (nonatomic, assign) NSInteger bid;
@property (nonatomic, assign) NSInteger type;
@property (nonatomic, copy) NSString *name;
@property (nonatomic, copy) NSString *nameCn;
@property (nonatomic, copy) NSString *summary;
@property (nonatomic, copy) NSString *airDate;
@property (nonatomic, assign) NSInteger airWeekday;
@property (nonatomic, assign) NSInteger rank;
@property (nonatomic, copy) NSString *imageLarge;
@property (nonatomic, copy) NSString *imageCommon;
@property (nonatomic, copy) NSString *imageMedium;
@property (nonatomic, assign) double rating;
@property (nonatomic, assign) NSInteger votes;
@property (nonatomic, copy) NSArray *tags;
@property (nonatomic, copy) NSArray *alias;
@property (nonatomic, copy) NSString *info;
@property (nonatomic, copy) NSString *epsText;

+ (instancetype)fromDictionary:(NSDictionary *)dict;
- (NSDictionary *)toDictionary;
- (NSString *)displayName;
@end

#pragma mark - Episode

@interface KLEpisode : NSObject
@property (nonatomic, assign) NSInteger eid;
@property (nonatomic, assign) double sort;
@property (nonatomic, assign) NSInteger type; // 0 本篇 1 SP 2 OP 3 ED
@property (nonatomic, copy) NSString *name;
@property (nonatomic, copy) NSString *nameCn;

+ (instancetype)fromDictionary:(NSDictionary *)dict;
- (NSString *)displayName;
@end

#pragma mark - Search / source

@interface KLSearchItem : NSObject
@property (nonatomic, copy) NSString *name;
@property (nonatomic, copy) NSString *src;
@property (nonatomic, copy) NSString *ruleName;
@property (nonatomic, copy) NSString *cover;
@property (nonatomic, copy) NSString *extra;
@end

@interface KLRoad : NSObject
@property (nonatomic, copy) NSString *name;
@property (nonatomic, copy) NSArray *urls;
@property (nonatomic, copy) NSArray *identifiers;
@end

#pragma mark - Rule

@interface KLRule : NSObject
@property (nonatomic, copy) NSString *api;
@property (nonatomic, copy) NSString *type;
@property (nonatomic, copy) NSString *name;
@property (nonatomic, copy) NSString *version;
@property (nonatomic, assign) BOOL multiSources;
@property (nonatomic, assign) BOOL useWebview;
@property (nonatomic, assign) BOOL useNativePlayer;
@property (nonatomic, assign) BOOL usePost;
@property (nonatomic, assign) BOOL useLegacyParser;
@property (nonatomic, assign) BOOL adBlocker;
@property (nonatomic, copy) NSString *userAgent;
@property (nonatomic, copy) NSString *baseURL;
@property (nonatomic, copy) NSString *searchURL;
@property (nonatomic, copy) NSString *searchList;
@property (nonatomic, copy) NSString *searchName;
@property (nonatomic, copy) NSString *searchResult;
@property (nonatomic, copy) NSString *chapterRoads;
@property (nonatomic, copy) NSString *chapterResult;
@property (nonatomic, copy) NSString *referer;
@property (nonatomic, copy) NSString *searchMode;   // xpath / api
@property (nonatomic, copy) NSString *chapterMode;  // xpath / api
@property (nonatomic, copy) NSDictionary *searchApiConfig;
@property (nonatomic, copy) NSDictionary *chapterApiConfig;
@property (nonatomic, copy) NSDictionary *antiCrawlerConfig;
@property (nonatomic, assign) BOOL enabled;
@property (nonatomic, copy) NSString *localPath;
@property (nonatomic, assign) NSInteger sortIndex;

+ (instancetype)fromDictionary:(NSDictionary *)dict;
- (NSDictionary *)toDictionary;
- (BOOL)isAPISearch;
- (BOOL)isAPIChapter;
@end

#pragma mark - History / collection

@interface KLHistoryEntry : NSObject
@property (nonatomic, strong) KLBangumiItem *bangumi;
@property (nonatomic, copy) NSString *ruleName;
@property (nonatomic, copy) NSString *episodeTitle;
@property (nonatomic, assign) NSInteger episodeNumber;
@property (nonatomic, assign) NSInteger roadIndex;
@property (nonatomic, copy) NSString *roadName;
@property (nonatomic, copy) NSString *episodePageURL;
@property (nonatomic, copy) NSArray *roadURLs;
@property (nonatomic, copy) NSArray *roadIdentifiers;
@property (nonatomic, assign) double position;
@property (nonatomic, assign) double duration;
@property (nonatomic, assign) NSTimeInterval updatedAt;

+ (instancetype)fromDictionary:(NSDictionary *)dict;
- (NSDictionary *)toDictionary;
@end

@interface KLCollectionEntry : NSObject
@property (nonatomic, strong) KLBangumiItem *bangumi;
@property (nonatomic, assign) NSInteger collectType; // 1在看 2想看 3搁置 4看过 5抛弃
@property (nonatomic, assign) NSTimeInterval updatedAt;

+ (instancetype)fromDictionary:(NSDictionary *)dict;
- (NSDictionary *)toDictionary;
- (NSString *)typeName;
@end

#pragma mark - Danmaku

@interface KLDanmakuEntry : NSObject
@property (nonatomic, copy) NSString *text;
@property (nonatomic, assign) double time;
@property (nonatomic, assign) NSInteger mode; // 1 scroll 4 bottom 5 top
@property (nonatomic, assign) NSInteger colorValue;
@property (nonatomic, copy) NSString *source;

+ (instancetype)fromDanDanDictionary:(NSDictionary *)dict;
+ (instancetype)fromBiliXMLAttributes:(NSDictionary *)attrs text:(NSString *)text;
@end

#pragma mark - Tag

@interface KLTagItem : NSObject
@property (nonatomic, copy) NSString *name;
@property (nonatomic, assign) NSInteger count;
+ (instancetype)fromDictionary:(NSDictionary *)dict;
@end
