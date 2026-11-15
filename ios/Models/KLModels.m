#import "KLModels.h"

static NSString *KLString(id value) {
    if ([value isKindOfClass:[NSString class]]) return value;
    if (value == nil || value == [NSNull null]) return @"";
    return [value description];
}
static NSInteger KLInt(id value) {
    if ([value respondsToSelector:@selector(integerValue)]) return [value integerValue];
    return 0;
}
static double KLDouble(id value) {
    if ([value respondsToSelector:@selector(doubleValue)]) return [value doubleValue];
    return 0;
}
static NSArray *KLArray(id value) {
    return [value isKindOfClass:[NSArray class]] ? value : @[];
}
static NSDictionary *KLDict(id value) {
    return [value isKindOfClass:[NSDictionary class]] ? value : @{};
}

@implementation KLBangumiItem

+ (instancetype)fromDictionary:(NSDictionary *)dict {
    if (![dict isKindOfClass:[NSDictionary class]]) return nil;
    KLBangumiItem *item = [[KLBangumiItem alloc] init];
    item.bid = KLInt(dict[@"id"]);
    item.type = KLInt(dict[@"type"]) ?: 2;
    item.name = KLString(dict[@"name"]);
    NSString *cn = KLString(dict[@"name_cn"]);
    if (cn.length == 0) cn = KLString(dict[@"nameCN"]);
    item.nameCn = cn.length ? cn : item.name;
    item.summary = KLString(dict[@"summary"]);
    NSString *date = KLString(dict[@"date"]);
    if (date.length == 0) date = KLString(KLDict(dict[@"airtime"])[@"date"]);
    item.airDate = date;
    item.airWeekday = KLInt(dict[@"air_weekday"]);

    NSDictionary *rating = KLDict(dict[@"rating"]);
    item.rank = KLInt(rating[@"rank"]);
    item.rating = KLDouble(rating[@"score"]);
    item.votes = KLInt(rating[@"total"]);

    NSDictionary *images = KLDict(dict[@"images"]);
    item.imageLarge = KLString(images[@"large"]);
    item.imageCommon = KLString(images[@"common"]);
    item.imageMedium = KLString(images[@"medium"]);
    if (item.imageCommon.length == 0) item.imageCommon = item.imageMedium;
    if (item.imageCommon.length == 0) item.imageCommon = KLString(dict[@"image"]);

    NSMutableArray *tags = [NSMutableArray array];
    for (id raw in KLArray(dict[@"tags"])) {
        if ([raw isKindOfClass:[NSDictionary class]]) {
            NSString *n = KLString(raw[@"name"]);
            if (n.length) [tags addObject:n];
        } else if ([raw isKindOfClass:[NSString class]]) {
            [tags addObject:raw];
        }
    }
    item.tags = tags;

    NSMutableArray *aliases = [NSMutableArray array];
    for (id box in KLArray(dict[@"infobox"])) {
        if ([box isKindOfClass:[NSDictionary class]] && [KLString(box[@"key"]) isEqualToString:@"别名"]) {
            id values = box[@"values"] ?: box[@"value"];
            if ([values isKindOfClass:[NSArray class]]) {
                for (id v in values) {
                    NSString *s = [v isKindOfClass:[NSDictionary class]] ? KLString(v[@"v"]) : KLString(v);
                    if (s.length) [aliases addObject:s];
                }
            } else if (KLString(values).length) {
                [aliases addObject:KLString(values)];
            }
        }
    }
    item.alias = aliases;
    item.info = KLString(dict[@"info"]);
    item.epsText = KLString(dict[@"eps"]);
    return item;
}

- (NSDictionary *)toDictionary {
    NSMutableDictionary *d = [NSMutableDictionary dictionary];
    d[@"id"] = @(self.bid);
    d[@"type"] = @(self.type);
    d[@"name"] = self.name ?: @"";
    d[@"name_cn"] = self.nameCn ?: @"";
    d[@"summary"] = self.summary ?: @"";
    d[@"date"] = self.airDate ?: @"";
    d[@"air_weekday"] = @(self.airWeekday);
    d[@"rating"] = @{@"rank": @(self.rank), @"score": @(self.rating), @"total": @(self.votes)};
    d[@"images"] = @{@"large": self.imageLarge ?: @"", @"common": self.imageCommon ?: @"", @"medium": self.imageMedium ?: @""};
    d[@"tags"] = self.tags ?: @[];
    d[@"alias"] = self.alias ?: @[];
    d[@"info"] = self.info ?: @"";
    return d;
}

- (NSString *)displayName {
    if (self.nameCn.length && ![self.nameCn isEqualToString:self.name]) return self.nameCn;
    return self.name.length ? self.name : self.nameCn;
}

@end

@implementation KLEpisode

+ (instancetype)fromDictionary:(NSDictionary *)dict {
    KLEpisode *e = [[KLEpisode alloc] init];
    e.eid = KLInt(dict[@"id"]);
    id sort = dict[@"sort"] ?: dict[@"ep"];
    e.sort = KLDouble(sort);
    e.type = KLInt(dict[@"type"]);
    e.name = KLString(dict[@"name"]);
    e.nameCn = KLString(dict[@"name_cn"]);
    return e;
}

- (NSString *)displayName {
    NSString *base = self.nameCn.length ? self.nameCn : self.name;
    if (base.length == 0) base = [NSString stringWithFormat:@"第 %.0f 集", self.sort];
    return base;
}

@end

@implementation KLSearchItem
@end

@implementation KLRoad
@end

@implementation KLRule

+ (instancetype)fromDictionary:(NSDictionary *)dict {
    if (![dict isKindOfClass:[NSDictionary class]]) return nil;
    KLRule *r = [[KLRule alloc] init];
    r.api = KLString(dict[@"api"]);
    r.type = KLString(dict[@"type"]);
    r.name = KLString(dict[@"name"]);
    r.version = KLString(dict[@"version"]);
    r.multiSources = [dict[@"muliSources"] boolValue] || [dict[@"multiSources"] boolValue];
    r.useWebview = dict[@"useWebview"] == nil ? YES : [dict[@"useWebview"] boolValue];
    r.useNativePlayer = dict[@"useNativePlayer"] == nil ? YES : [dict[@"useNativePlayer"] boolValue];
    r.usePost = [dict[@"usePost"] boolValue];
    r.useLegacyParser = [dict[@"useLegacyParser"] boolValue];
    r.adBlocker = [dict[@"adBlocker"] boolValue];
    r.userAgent = KLString(dict[@"userAgent"]);
    r.baseURL = KLString(dict[@"baseURL"]);
    r.searchURL = KLString(dict[@"searchURL"]);
    r.searchList = KLString(dict[@"searchList"]);
    r.searchName = KLString(dict[@"searchName"]);
    r.searchResult = KLString(dict[@"searchResult"]);
    r.chapterRoads = KLString(dict[@"chapterRoads"]);
    r.chapterResult = KLString(dict[@"chapterResult"]);
    r.referer = KLString(dict[@"referer"]);
    r.searchMode = KLString(dict[@"searchMode"]).length ? KLString(dict[@"searchMode"]) : @"xpath";
    r.chapterMode = KLString(dict[@"chapterMode"]).length ? KLString(dict[@"chapterMode"]) : @"xpath";
    r.searchApiConfig = KLDict(dict[@"searchApiConfig"]);
    r.chapterApiConfig = KLDict(dict[@"chapterApiConfig"]);
    r.antiCrawlerConfig = KLDict(dict[@"antiCrawlerConfig"]);
    r.enabled = dict[@"enabled"] == nil ? YES : [dict[@"enabled"] boolValue];
    return r;
}

- (NSDictionary *)toDictionary {
    NSMutableDictionary *d = [NSMutableDictionary dictionary];
    if (self.api) d[@"api"] = self.api;
    d[@"type"] = self.type.length ? self.type : @"anime";
    d[@"name"] = self.name ?: @"";
    d[@"version"] = self.version ?: @"";
    d[@"muliSources"] = @(self.multiSources);
    d[@"useWebview"] = @(self.useWebview);
    d[@"useNativePlayer"] = @(self.useNativePlayer);
    d[@"usePost"] = @(self.usePost);
    d[@"useLegacyParser"] = @(self.useLegacyParser);
    d[@"adBlocker"] = @(self.adBlocker);
    d[@"userAgent"] = self.userAgent ?: @"";
    d[@"baseURL"] = self.baseURL ?: @"";
    d[@"searchURL"] = self.searchURL ?: @"";
    d[@"searchList"] = self.searchList ?: @"";
    d[@"searchName"] = self.searchName ?: @"";
    d[@"searchResult"] = self.searchResult ?: @"";
    d[@"chapterRoads"] = self.chapterRoads ?: @"";
    d[@"chapterResult"] = self.chapterResult ?: @"";
    d[@"referer"] = self.referer ?: @"";
    d[@"searchMode"] = self.searchMode ?: @"xpath";
    d[@"chapterMode"] = self.chapterMode ?: @"xpath";
    if (self.searchApiConfig.count) d[@"searchApiConfig"] = self.searchApiConfig;
    if (self.chapterApiConfig.count) d[@"chapterApiConfig"] = self.chapterApiConfig;
    if (self.antiCrawlerConfig.count) d[@"antiCrawlerConfig"] = self.antiCrawlerConfig;
    d[@"enabled"] = @(self.enabled);
    return d;
}

- (BOOL)isAPISearch { return [self.searchMode isEqualToString:@"api"]; }
- (BOOL)isAPIChapter { return [self.chapterMode isEqualToString:@"api"]; }

@end

@implementation KLHistoryEntry

+ (instancetype)fromDictionary:(NSDictionary *)dict {
    KLHistoryEntry *e = [[KLHistoryEntry alloc] init];
    e.bangumi = [KLBangumiItem fromDictionary:KLDict(dict[@"bangumi"])];
    e.ruleName = KLString(dict[@"ruleName"]);
    e.episodeTitle = KLString(dict[@"episodeTitle"]);
    e.episodeNumber = KLInt(dict[@"episodeNumber"]);
    e.roadIndex = KLInt(dict[@"roadIndex"]);
    e.roadName = KLString(dict[@"roadName"]);
    e.episodePageURL = KLString(dict[@"episodePageURL"]);
    e.roadURLs = KLArray(dict[@"roadURLs"]);
    e.roadIdentifiers = KLArray(dict[@"roadIdentifiers"]);
    e.position = KLDouble(dict[@"position"]);
    e.duration = KLDouble(dict[@"duration"]);
    e.updatedAt = KLDouble(dict[@"updatedAt"]);
    return e;
}

- (NSDictionary *)toDictionary {
    NSMutableDictionary *d = [NSMutableDictionary dictionary];
    if (self.bangumi) d[@"bangumi"] = [self.bangumi toDictionary];
    d[@"ruleName"] = self.ruleName ?: @"";
    d[@"episodeTitle"] = self.episodeTitle ?: @"";
    d[@"episodeNumber"] = @(self.episodeNumber);
    d[@"roadIndex"] = @(self.roadIndex);
    d[@"roadName"] = self.roadName ?: @"";
    d[@"episodePageURL"] = self.episodePageURL ?: @"";
    d[@"roadURLs"] = self.roadURLs ?: @[];
    d[@"roadIdentifiers"] = self.roadIdentifiers ?: @[];
    d[@"position"] = @(self.position);
    d[@"duration"] = @(self.duration);
    d[@"updatedAt"] = @(self.updatedAt > 0 ? self.updatedAt : [[NSDate date] timeIntervalSince1970]);
    return d;
}

@end

@implementation KLCollectionEntry

+ (instancetype)fromDictionary:(NSDictionary *)dict {
    KLCollectionEntry *e = [[KLCollectionEntry alloc] init];
    e.bangumi = [KLBangumiItem fromDictionary:KLDict(dict[@"bangumi"])];
    e.collectType = KLInt(dict[@"collectType"]);
    e.updatedAt = KLDouble(dict[@"updatedAt"]);
    return e;
}

- (NSDictionary *)toDictionary {
    return @{
        @"bangumi": self.bangumi ? [self.bangumi toDictionary] : @{},
        @"collectType": @(self.collectType),
        @"updatedAt": @(self.updatedAt > 0 ? self.updatedAt : [[NSDate date] timeIntervalSince1970])
    };
}

- (NSString *)typeName {
    switch (self.collectType) {
        case 1: return @"在看";
        case 2: return @"想看";
        case 3: return @"搁置";
        case 4: return @"看过";
        case 5: return @"抛弃";
        default: return @"未收藏";
    }
}

@end

@implementation KLDanmakuEntry

+ (instancetype)fromDanDanDictionary:(NSDictionary *)dict {
    NSString *p = KLString(dict[@"p"]);
    NSArray *parts = [p componentsSeparatedByString:@","];
    if (parts.count < 3) return nil;
    KLDanmakuEntry *e = [[KLDanmakuEntry alloc] init];
    e.time = [parts[0] doubleValue];
    e.mode = [parts[1] integerValue];
    e.colorValue = [parts[2] integerValue];
    e.source = parts.count > 3 ? parts[3] : @"dandan";
    e.text = KLString(dict[@"m"]);
    return e.text.length ? e : nil;
}

+ (instancetype)fromBiliXMLAttributes:(NSDictionary *)attrs text:(NSString *)text {
    NSArray *parts = [KLString(attrs[@"p"]) componentsSeparatedByString:@","];
    if (parts.count < 4) return nil;
    KLDanmakuEntry *e = [[KLDanmakuEntry alloc] init];
    e.time = [parts[0] doubleValue];
    e.mode = [parts[1] integerValue];
    e.colorValue = [parts[3] integerValue];
    e.source = @"bilibili";
    e.text = text;
    return e.text.length ? e : nil;
}

@end

@implementation KLTagItem
+ (instancetype)fromDictionary:(NSDictionary *)dict {
    KLTagItem *t = [[KLTagItem alloc] init];
    t.name = KLString(dict[@"name"]);
    t.count = KLInt(dict[@"count"]);
    return t;
}
@end
