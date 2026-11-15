#import "KLDanmakuAPI.h"
#import "KLHttp.h"
#import "KLStore.h"
#import <CommonCrypto/CommonDigest.h>

static NSString *KLSHA256Base64(NSString *input) {
    NSData *data = [input dataUsingEncoding:NSUTF8StringEncoding];
    unsigned char digest[CC_SHA256_DIGEST_LENGTH];
    CC_SHA256(data.bytes, (CC_LONG)data.length, digest);
    NSData *d = [NSData dataWithBytes:digest length:CC_SHA256_DIGEST_LENGTH];
    return [d base64EncodedStringWithOptions:0];
}

@interface KLBiliXMLParser : NSObject <NSXMLParserDelegate>
@property (nonatomic, strong) NSMutableArray *entries;
@property (nonatomic, strong) NSMutableString *textBuffer;
@property (nonatomic, copy) NSString *currentP;
@end

@implementation KLBiliXMLParser
- (instancetype)init {
    self = [super init];
    if (self) {
        _entries = [NSMutableArray array];
        _textBuffer = [NSMutableString string];
    }
    return self;
}
- (void)parser:(NSXMLParser *)parser didStartElement:(NSString *)elementName namespaceURI:(NSString *)namespaceURI qualifiedName:(NSString *)qName attributes:(NSDictionary *)attributeDict {
    if ([elementName isEqualToString:@"d"]) {
        self.currentP = attributeDict[@"p"];
        [self.textBuffer setString:@""];
    }
}
- (void)parser:(NSXMLParser *)parser foundCharacters:(NSString *)string {
    if (self.currentP) [self.textBuffer appendString:string];
}
- (void)parser:(NSXMLParser *)parser didEndElement:(NSString *)elementName namespaceURI:(NSString *)namespaceURI qualifiedName:(NSString *)qName {
    if ([elementName isEqualToString:@"d"] && self.currentP) {
        KLDanmakuEntry *e = [KLDanmakuEntry fromBiliXMLAttributes:@{@"p": self.currentP} text:self.textBuffer];
        if (e) [self.entries addObject:e];
        self.currentP = nil;
        [self.textBuffer setString:@""];
    }
}
@end

@interface KLDanmakuAPI ()
@end

@implementation KLDanmakuAPI

+ (instancetype)shared {
    static KLDanmakuAPI *api = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{ api = [[KLDanmakuAPI alloc] init]; });
    return api;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        _dandanAppId = [[KLStore shared] stringForKey:@"dandanAppId" defaultValue:@""];
        _dandanAppKey = [[KLStore shared] stringForKey:@"dandanAppKey" defaultValue:@""];
    }
    return self;
}

- (NSString *)cachePathForBangumi:(NSInteger)bid episode:(NSInteger)episode {
    return [[KLStore shared].danmakuPath stringByAppendingPathComponent:[NSString stringWithFormat:@"%ld-%ld.json", (long)bid, (long)episode]];
}

- (NSArray *)cachedDanmakuForBangumi:(NSInteger)bid episode:(NSInteger)episode {
    id obj = [KLStore readJSON:[self cachePathForBangumi:bid episode:episode]];
    NSMutableArray *entries = [NSMutableArray array];
    if ([obj isKindOfClass:[NSDictionary class]]) {
        for (NSDictionary *d in obj[@"comments"]) {
            KLDanmakuEntry *e = [KLDanmakuEntry fromDanDanDictionary:d];
            if (e) [entries addObject:e];
        }
    }
    return entries;
}

- (void)saveCache:(NSArray *)entries bangumi:(NSInteger)bid episode:(NSInteger)episode source:(NSString *)source {
    if (entries.count == 0) return;
    NSMutableArray *comments = [NSMutableArray array];
    for (KLDanmakuEntry *e in entries) {
        int color = (int)e.colorValue;
        [comments addObject:@{
            @"m": e.text ?: @"",
            @"p": [NSString stringWithFormat:@"%.3f,%ld,%d,%@", e.time, (long)e.mode, color, e.source ?: source ?: @"local"]
        }];
    }
    [KLStore writeJSON:@{@"source": source ?: @"", @"updatedAt": @([[NSDate date] timeIntervalSince1970]), @"comments": comments}
                 toPath:[self cachePathForBangumi:bid episode:episode]];
}

#pragma mark - DanDan

- (NSMutableDictionary *)dandanHeadersForPath:(NSString *)path {
    NSMutableDictionary *h = [NSMutableDictionary dictionary];
    h[@"Accept"] = @"application/json";
    h[@"X-Auth"] = @"1";
    if (self.dandanAppId.length && self.dandanAppKey.length) {
        long long ts = (long long)[[NSDate date] timeIntervalSince1970];
        h[@"X-AppId"] = self.dandanAppId;
        h[@"X-Timestamp"] = [NSString stringWithFormat:@"%lld", ts];
        h[@"X-Signature"] = KLSHA256Base64([NSString stringWithFormat:@"%@%lld%@%@", self.dandanAppId, ts, path, self.dandanAppKey]);
    }
    return h;
}

- (void)searchDanDanForTitle:(NSString *)title completion:(void (^)(NSArray *, NSError *))completion {
    NSString *path = @"/api/v2/search/episodes";
    NSString *url = [@"https://api.dandanplay.net" stringByAppendingString:path];
    url = [KLHttp appendQuery:@{@"anime": title ?: @"", @"v2": @"true"} toURL:url];
    [KLHttp GET:url headers:[self dandanHeadersForPath:path] completion:^(id json, NSData *data, NSHTTPURLResponse *response, NSError *error) {
        NSArray *animes = nil;
        if ([json isKindOfClass:[NSDictionary class]]) animes = json[@"animes"];
        if (![animes isKindOfClass:[NSArray class]]) animes = @[];
        if (completion) completion(animes, error);
    }];
}

- (void)fetchDanDanComments:(NSInteger)bangumiId episode:(NSInteger)episode completion:(void (^)(NSArray *, NSError *))completion {
    NSString *episodeId = [NSString stringWithFormat:@"%ld%04ld", (long)bangumiId, (long)episode];
    NSString *path = [@"/api/v2/comment/" stringByAppendingString:episodeId];
    NSString *url = [@"https://api.dandanplay.net" stringByAppendingString:path];
    url = [KLHttp appendQuery:@{@"withRelated": @"true", @"chConvert": @"0"} toURL:url];
    [KLHttp GET:url headers:[self dandanHeadersForPath:path] completion:^(id json, NSData *data, NSHTTPURLResponse *response, NSError *error) {
        NSMutableArray *entries = [NSMutableArray array];
        if ([json isKindOfClass:[NSDictionary class]] && [json[@"comments"] isKindOfClass:[NSArray class]]) {
            for (NSDictionary *d in json[@"comments"]) {
                if (![d isKindOfClass:[NSDictionary class]]) continue;
                KLDanmakuEntry *e = [KLDanmakuEntry fromDanDanDictionary:d];
                if (e) [entries addObject:e];
            }
        }
        if (entries.count == 0 && !error) error = [NSError errorWithDomain:@"KLDanmaku" code:-2 userInfo:@{NSLocalizedDescriptionKey: @"弹幕为空或接口需要凭据"}];
        if (completion) completion(entries, error);
    }];
}

- (void)fetchForBangumi:(KLBangumiItem *)item episode:(NSInteger)episode completion:(void (^)(NSArray *, NSString *, NSError *))completion {
    if (!item) {
        if (completion) completion(nil, nil, [NSError errorWithDomain:@"KLDanmaku" code:-1 userInfo:@{NSLocalizedDescriptionKey: @"番剧信息为空"}]);
        return;
    }
    NSArray *cached = [self cachedDanmakuForBangumi:item.bid episode:episode];
    if (cached.count > 0) {
        if (completion) completion(cached, @"cache", nil);
        return;
    }
    __weak typeof(self) weakSelf = self;
    if (self.dandanAppId.length && self.dandanAppKey.length) {
        NSString *path = [NSString stringWithFormat:@"/api/v2/bangumi/bgmtv/%ld", (long)item.bid];
        NSString *url = [@"https://api.dandanplay.net" stringByAppendingString:path];
        [KLHttp GET:url headers:[self dandanHeadersForPath:path] completion:^(id json, NSData *data, NSHTTPURLResponse *response, NSError *error) {
            NSInteger dandanId = 0;
            if ([json isKindOfClass:[NSDictionary class]] && [json[@"bangumiId"] respondsToSelector:@selector(integerValue)]) {
                dandanId = [json[@"bangumiId"] integerValue];
            }
            if (dandanId > 0) {
                [weakSelf fetchDanDanComments:dandanId episode:episode completion:^(NSArray *entries, NSError *e) {
                    if (entries.count > 0) {
                        [weakSelf saveCache:entries bangumi:item.bid episode:episode source:@"dandan"];
                        if (completion) completion(entries, @"dandan", nil);
                    } else {
                        [weakSelf fetchBiliFallback:item episode:episode completion:completion];
                    }
                }];
            } else {
                [weakSelf fetchBiliFallback:item episode:episode completion:completion];
            }
        }];
    } else {
        [self fetchBiliFallback:item episode:episode completion:completion];
    }
}

- (void)fetchBiliFallback:(KLBangumiItem *)item episode:(NSInteger)episode completion:(void (^)(NSArray *, NSString *, NSError *))completion {
    __weak typeof(self) weakSelf = self;
    [self fetchBiliForTitle:[item displayName] episode:episode completion:^(NSArray *entries, NSString *matchedTitle, NSError *error) {
        if (entries.count > 0) {
            [weakSelf saveCache:entries bangumi:item.bid episode:episode source:@"bilibili"];
            if (completion) completion(entries, @"bilibili", nil);
        } else {
            if (completion) completion(@[], nil, error ?: [NSError errorWithDomain:@"KLDanmaku" code:-3 userInfo:@{NSLocalizedDescriptionKey: @"未找到弹幕（可在设置中配置弹弹Play凭据）"}]);
        }
    }];
}

#pragma mark - BiliBili

- (void)fetchBiliForTitle:(NSString *)title episode:(NSInteger)episode completion:(void (^)(NSArray *, NSString *, NSError *))completion {
    NSString *url = [KLHttp appendQuery:@{@"search_type": @"media_bangumi", @"keyword": title ?: @""} toURL:@"https://api.bilibili.com/x/web-interface/search/type"];
    NSDictionary *headers = @{@"Referer": @"https://www.bilibili.com/", @"Accept": @"application/json"};
    [KLHttp GET:url headers:headers completion:^(id json, NSData *data, NSHTTPURLResponse *response, NSError *error) {
        NSArray *results = nil;
        if ([json isKindOfClass:[NSDictionary class]] && [json[@"data"] isKindOfClass:[NSDictionary class]]) {
            results = json[@"data"][@"result"];
        }
        if (![results isKindOfClass:[NSArray class]]) results = nil;
        if (![results isKindOfClass:[NSArray class]] || results.count == 0) {
            // Try the public PGC search endpoint as a fallback.
            NSString *u2 = [KLHttp appendQuery:@{@"keyword": title ?: @"", @"season_type": @"1", @"page": @"1", @"pagesize": @"10"} toURL:@"https://api.bilibili.com/pgc/season/search/new/type"];
            [KLHttp GET:u2 headers:headers completion:^(id j2, NSData *d2, NSHTTPURLResponse *r2, NSError *e2) {
                NSArray *list = nil;
                if ([j2 isKindOfClass:[NSDictionary class]]) {
                    id data = j2[@"data"];
                    if ([data isKindOfClass:[NSDictionary class]]) list = data[@"list"];
                    if (![list isKindOfClass:[NSArray class]]) list = j2[@"result"];
                }
                if (![list isKindOfClass:[NSArray class]]) list = nil;
                NSInteger seasonId = 0;
                NSString *matched = title;
                for (NSDictionary *d in list) {
                    if (![d isKindOfClass:[NSDictionary class]]) continue;
                    NSInteger sid = [d[@"season_id"] integerValue];
                    if (sid > 0) { seasonId = sid; matched = d[@"title"] ?: title; break; }
                }
                if (seasonId > 0) {
                    [[KLDanmakuAPI shared] fetchBiliForSeason:seasonId episode:episode completion:^(NSArray *entries, NSError *e3) {
                        if (completion) completion(entries, matched, e3 ?: e2);
                    }];
                } else {
                    if (completion) completion(@[], nil, e2 ?: [NSError errorWithDomain:@"KLDanmaku" code:-4 userInfo:@{NSLocalizedDescriptionKey: @"B 站搜索无结果"}]);
                }
            }];
            return;
        }
        NSDictionary *best = nil;
        for (NSDictionary *d in results) {
            if (![d isKindOfClass:[NSDictionary class]]) continue;
            NSInteger sid = [d[@"season_id"] integerValue];
            if (sid > 0) { best = d; break; }
        }
        if (!best) {
            if (completion) completion(@[], nil, [NSError errorWithDomain:@"KLDanmaku" code:-5 userInfo:@{NSLocalizedDescriptionKey: @"B 站未匹配到番剧"}]);
            return;
        }
        NSString *rawTitle = [best[@"title"] isKindOfClass:[NSString class]] ? best[@"title"] : title;
        NSString *cleanTitle = [rawTitle stringByReplacingOccurrencesOfString:@"<[^>]+>" withString:@"" options:NSRegularExpressionSearch range:NSMakeRange(0, rawTitle.length)];
        [[KLDanmakuAPI shared] fetchBiliForSeason:[best[@"season_id"] integerValue] episode:episode completion:^(NSArray *entries, NSError *e) {
            if (completion) completion(entries, cleanTitle, e);
        }];
    }];
}

- (void)fetchBiliForSeason:(NSInteger)seasonId episode:(NSInteger)episode completion:(void (^)(NSArray *, NSError *))completion {
    NSString *url = [KLHttp appendQuery:@{@"season_id": @(seasonId)} toURL:@"https://api.bilibili.com/pgc/view/web/season"];
    NSDictionary *headers = @{@"Referer": @"https://www.bilibili.com/", @"Accept": @"application/json"};
    [KLHttp GET:url headers:headers completion:^(id json, NSData *data, NSHTTPURLResponse *response, NSError *error) {
        NSArray *episodes = nil;
        if ([json isKindOfClass:[NSDictionary class]] && [json[@"result"] isKindOfClass:[NSDictionary class]]) {
            episodes = json[@"result"][@"episodes"];
        }
        if (![episodes isKindOfClass:[NSArray class]] || episodes.count == 0) {
            if (completion) completion(@[], error ?: [NSError errorWithDomain:@"KLDanmaku" code:-6 userInfo:@{NSLocalizedDescriptionKey: @"B 站番剧集数获取失败"}]);
            return;
        }
        NSDictionary *target = nil;
        for (NSDictionary *ep in episodes) {
            if (![ep isKindOfClass:[NSDictionary class]]) continue;
            NSInteger epNum = [ep[@"ep"] integerValue] ?: [ep[@"title"] integerValue];
            if (epNum == episode) { target = ep; break; }
        }
        if (!target && episode > 0 && episode <= episodes.count) target = episodes[episode - 1];
        long long cid = target ? [target[@"cid"] longLongValue] : 0;
        if (cid <= 0) {
            if (completion) completion(@[], [NSError errorWithDomain:@"KLDanmaku" code:-7 userInfo:@{NSLocalizedDescriptionKey: @"未匹配到对应集数"}]);
            return;
        }
        [self fetchBiliXMLForCid:cid completion:completion];
    }];
}

- (void)fetchBiliXMLForCid:(long long)cid completion:(void (^)(NSArray *, NSError *))completion {
    NSString *url = [NSString stringWithFormat:@"https://comment.bilibili.com/%lld.xml", cid];
    NSDictionary *headers = @{@"Referer": @"https://www.bilibili.com/"};
    [KLHttp GET:url headers:headers completion:^(id json, NSData *data, NSHTTPURLResponse *response, NSError *error) {
        if (data.length == 0) {
            if (completion) completion(@[], error ?: [NSError errorWithDomain:@"KLDanmaku" code:-8 userInfo:@{NSLocalizedDescriptionKey: @"B 站弹幕下载失败"}]);
            return;
        }
        KLBiliXMLParser *parser = [[KLBiliXMLParser alloc] init];
        NSXMLParser *xml = [[NSXMLParser alloc] initWithData:data];
        xml.delegate = parser;
        [xml parse];
        if (completion) completion(parser.entries, parser.entries.count ? nil : [NSError errorWithDomain:@"KLDanmaku" code:-9 userInfo:@{NSLocalizedDescriptionKey: @"B 站弹幕为空"}]);
    }];
}

@end
