#import "KLBangumiAPI.h"
#import "KLHttp.h"
#import "KLStore.h"

static NSString *KLApiBase(void) {
    NSString *mode = [[KLStore shared] stringForKey:@"bangumiMode" defaultValue:@"official"];
    if ([mode isEqualToString:@"mirror"]) return @"https://api.kazumi.fyi";
    if ([mode isEqualToString:@"custom"]) {
        NSString *custom = [[KLStore shared] stringForKey:@"bangumiCustomBase" defaultValue:@""];
        if (custom.length) return [custom stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    }
    return @"https://api.bgm.tv";
}

static NSString *KLNextBase(void) {
    NSString *mode = [[KLStore shared] stringForKey:@"bangumiMode" defaultValue:@"official"];
    if ([mode isEqualToString:@"mirror"]) return @"https://api.kazumi.fyi";
    return @"https://next.bgm.tv";
}

static NSString *KLUserAgent(void) {
    return @"KazumiLite/1.0 (iOS 9; armv7; https://github.com/Daniel123999/KazumiLite)";
}

@interface KLBangumiAPI ()
@property (nonatomic, strong) NSMutableDictionary *cache;
@end

@implementation KLBangumiAPI

+ (instancetype)shared {
    static KLBangumiAPI *api = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{ api = [[KLBangumiAPI alloc] init]; });
    return api;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        _token = [[KLStore shared] stringForKey:@"bangumiToken" defaultValue:@""];
        _username = [[KLStore shared] stringForKey:@"bangumiUsername" defaultValue:@""];
        _cache = [NSMutableDictionary dictionary];
    }
    return self;
}

- (NSDictionary *)headersWithAuth:(BOOL)auth {
    NSMutableDictionary *h = [NSMutableDictionary dictionary];
    h[@"User-Agent"] = KLUserAgent();
    h[@"Accept"] = @"application/json";
    if (auth && self.token.length) h[@"Authorization"] = [@"Bearer " stringByAppendingString:self.token];
    return h;
}

- (void)calendar:(void (^)(NSArray *, NSError *))completion {
    NSString *url = [KLNextBase() stringByAppendingString:
        ([KLNextBase() containsString:@"kazumi.fyi"] ? @"/kazumi/v1/calendar/season" : @"/p1/calendar")];
    NSDictionary *headers = [self headersWithAuth:NO];
    [KLHttp GET:url headers:headers completion:^(id json, NSData *data, NSHTTPURLResponse *response, NSError *error) {
        if (error || ![json isKindOfClass:[NSDictionary class]]) {
            // Fallback to the official calendar host.
            NSString *fallback = @"https://next.bgm.tv/p1/calendar";
            [KLHttp GET:fallback headers:headers completion:^(id json2, NSData *d2, NSHTTPURLResponse *r2, NSError *e2) {
                if (![json2 isKindOfClass:[NSDictionary class]]) {
                    if (completion) completion(nil, e2 ?: error);
                    return;
                }
                [self parseCalendar:json2 completion:completion];
            }];
            return;
        }
        [self parseCalendar:json completion:completion];
    }];
}

- (void)parseCalendar:(NSDictionary *)json completion:(void (^)(NSArray *, NSError *))completion {
    NSMutableArray *days = [NSMutableArray array];
    for (NSInteger i = 1; i <= 7; i++) {
        NSArray *list = json[[NSString stringWithFormat:@"%ld", (long)i]];
        NSMutableArray *items = [NSMutableArray array];
        if ([list isKindOfClass:[NSArray class]]) {
            for (NSDictionary *wrapper in list) {
                if (![wrapper isKindOfClass:[NSDictionary class]]) continue;
                NSDictionary *subject = [wrapper[@"subject"] isKindOfClass:[NSDictionary class]] ? wrapper[@"subject"] : wrapper;
                KLBangumiItem *item = [KLBangumiItem fromDictionary:subject];
                if (item && item.bid > 0) {
                    item.airWeekday = i;
                    [items addObject:item];
                }
            }
        }
        [days addObject:items];
    }
    if (completion) completion(days, nil);
}

- (void)trendingWithLimit:(NSInteger)limit offset:(NSInteger)offset completion:(void (^)(NSArray *, NSError *))completion {
    NSString *url = [NSString stringWithFormat:@"%@/p1/trending/subjects?type=2&limit=%ld&offset=%ld", KLNextBase(), (long)limit, (long)offset];
    [KLHttp GET:url headers:[self headersWithAuth:NO] completion:^(id json, NSData *data, NSHTTPURLResponse *response, NSError *error) {
        NSMutableArray *items = [NSMutableArray array];
        if ([json isKindOfClass:[NSDictionary class]] && [json[@"data"] isKindOfClass:[NSArray class]]) {
            for (NSDictionary *wrapper in json[@"data"]) {
                if (![wrapper isKindOfClass:[NSDictionary class]]) continue;
                NSDictionary *subject = wrapper[@"subject"] ?: wrapper;
                KLBangumiItem *item = [KLBangumiItem fromDictionary:subject];
                if (item && item.bid > 0) [items addObject:item];
            }
        }
        if (items.count == 0) {
            [self search:@"" limit:limit offset:offset completion:^(NSArray *list, NSInteger raw, NSError *e) {
                if (completion) completion(list ?: @[], error ?: e);
            }];
            return;
        }
        if (completion) completion(items, error);
    }];
}

- (void)search:(NSString *)keyword limit:(NSInteger)limit offset:(NSInteger)offset completion:(void (^)(NSArray *, NSInteger, NSError *))completion {
    NSString *url = [NSString stringWithFormat:@"%@/v0/search/subjects?limit=%ld&offset=%ld", KLApiBase(), (long)limit, (long)offset];
    NSDictionary *body = @{
        @"keyword": keyword ?: @"",
        @"sort": @"heat",
        @"filter": @{@"type": @[@2], @"nsfw": @NO}
    };
    [KLHttp POSTJSON:url headers:[self headersWithAuth:NO] body:body completion:^(id json, NSData *data, NSHTTPURLResponse *response, NSError *error) {
        NSMutableArray *items = [NSMutableArray array];
        NSInteger rawCount = 0;
        if ([json isKindOfClass:[NSDictionary class]] && [json[@"data"] isKindOfClass:[NSArray class]]) {
            NSArray *list = json[@"data"];
            rawCount = list.count;
            for (NSDictionary *dict in list) {
                KLBangumiItem *item = [KLBangumiItem fromDictionary:dict];
                if (item && item.bid > 0 && item.displayName.length) [items addObject:item];
            }
        }
        if (completion) completion(items, rawCount, error);
    }];
}

- (void)subject:(NSInteger)bid completion:(void (^)(KLBangumiItem *, NSError *))completion {
    NSString *url = [NSString stringWithFormat:@"%@/p1/subjects/%ld", KLNextBase(), (long)bid];
    [KLHttp GET:url headers:[self headersWithAuth:NO] completion:^(id json, NSData *data, NSHTTPURLResponse *response, NSError *error) {
        if (![json isKindOfClass:[NSDictionary class]]) {
            NSString *fallback = [NSString stringWithFormat:@"%@/v0/subjects/%ld", KLApiBase(), (long)bid];
            [KLHttp GET:fallback headers:[self headersWithAuth:NO] completion:^(id json2, NSData *d2, NSHTTPURLResponse *r2, NSError *e2) {
                KLBangumiItem *item = [KLBangumiItem fromDictionary:json2];
                if (completion) completion(item, item ? nil : (e2 ?: error));
            }];
            return;
        }
        KLBangumiItem *item = [KLBangumiItem fromDictionary:json];
        if (completion) completion(item, item ? nil : error);
    }];
}

- (void)episodes:(NSInteger)bid completion:(void (^)(NSArray *, NSError *))completion {
    NSMutableArray *all = [NSMutableArray array];
    __block NSInteger offset = 0;
    __block NSInteger total = -1;
    __block void (^fetch)(void);
    fetch = ^void(void) {
        NSString *url = [NSString stringWithFormat:@"%@/v0/episodes?subject_id=%ld&offset=%ld&limit=100", KLApiBase(), (long)bid, (long)offset];
        [KLHttp GET:url headers:[self headersWithAuth:NO] completion:^(id json, NSData *data, NSHTTPURLResponse *response, NSError *error) {
            if (![json isKindOfClass:[NSDictionary class]]) {
                if (completion) completion(all.count ? all : nil, error);
                return;
            }
            NSArray *list = json[@"data"];
            total = [json[@"total"] integerValue];
            for (NSDictionary *d in list) {
                KLEpisode *e = [KLEpisode fromDictionary:d];
                if (e) [all addObject:e];
            }
            offset += list.count;
            if (list.count > 0 && (total <= 0 || offset < total)) fetch();
            else if (completion) completion(all, nil);
        }];
    };
    fetch();
}

- (void)comments:(NSInteger)bid limit:(NSInteger)limit offset:(NSInteger)offset completion:(void (^)(NSArray *, NSError *))completion {
    NSString *url = [NSString stringWithFormat:@"%@/p1/subjects/%ld/comments?limit=%ld&offset=%ld", KLNextBase(), (long)bid, (long)limit, (long)offset];
    [KLHttp GET:url headers:[self headersWithAuth:NO] completion:^(id json, NSData *data, NSHTTPURLResponse *response, NSError *error) {
        NSArray *list = nil;
        if ([json isKindOfClass:[NSDictionary class]] && [json[@"data"] isKindOfClass:[NSArray class]]) list = json[@"data"];
        else if ([json isKindOfClass:[NSArray class]]) list = json;
        NSMutableArray *clean = [NSMutableArray array];
        for (id item in list) if ([item isKindOfClass:[NSDictionary class]]) [clean addObject:item];
        if (completion) completion(clean, error);
    }];
}

- (void)relations:(NSInteger)bid completion:(void (^)(NSArray *, NSError *))completion {
    NSString *url = [NSString stringWithFormat:@"%@/v0/subjects/%ld/subjects", KLApiBase(), (long)bid];
    [KLHttp GET:url headers:[self headersWithAuth:NO] completion:^(id json, NSData *data, NSHTTPURLResponse *response, NSError *error) {
        NSMutableArray *items = [NSMutableArray array];
        if ([json isKindOfClass:[NSArray class]]) {
            for (NSDictionary *d in json) {
                KLBangumiItem *item = [KLBangumiItem fromDictionary:d];
                if (item.bid > 0) [items addObject:item];
            }
        }
        if (completion) completion(items, error);
    }];
}

- (void)validateToken:(NSString *)token completion:(void (^)(NSString *, NSError *))completion {
    NSString *url = [NSString stringWithFormat:@"%@/v0/me", KLApiBase()];
    NSMutableDictionary *h = [self headersWithAuth:NO];
    h[@"Authorization"] = [@"Bearer " stringByAppendingString:token ?: @""];
    [KLHttp GET:url headers:h completion:^(id json, NSData *data, NSHTTPURLResponse *response, NSError *error) {
        NSString *name = nil;
        if ([json isKindOfClass:[NSDictionary class]]) name = json[@"username"];
        if (name.length == 0 && !error) error = [NSError errorWithDomain:@"KLBangumi" code:-2 userInfo:@{NSLocalizedDescriptionKey: @"Token 无效或已过期"}];
        if (completion) completion(name, error);
    }];
}

- (void)updateCollection:(NSInteger)bid type:(NSInteger)type completion:(void (^)(BOOL, NSError *))completion {
    if (self.token.length == 0) {
        if (completion) completion(NO, [NSError errorWithDomain:@"KLBangumi" code:401 userInfo:@{NSLocalizedDescriptionKey: @"请先在设置中登录 Bangumi"}]);
        return;
    }
    NSString *url = [NSString stringWithFormat:@"%@/v0/users/-/collections/%ld", KLApiBase(), (long)bid];
    NSMutableDictionary *h = [self headersWithAuth:YES];
    h[@"Content-Type"] = @"application/json";
    [KLHttp requestURL:url method:@"POST" headers:h body:[NSJSONSerialization dataWithJSONObject:@{@"type": @(type)} options:0 error:NULL] completion:^(id json, NSData *data, NSHTTPURLResponse *response, NSError *error) {
        BOOL ok = response.statusCode >= 200 && response.statusCode < 300;
        if (completion) completion(ok, ok ? nil : error);
    }];
}

- (void)userCollections:(NSString *)username token:(NSString *)token completion:(void (^)(NSArray *, NSError *))completion {
    if (!username.length) {
        if (completion) completion(@[], nil);
        return;
    }
    NSString *url = [NSString stringWithFormat:@"%@/v0/users/%@/collections?subject_type=2&limit=50&offset=0", KLApiBase(), [KLHttp encode:username]];
    NSMutableDictionary *h = [self headersWithAuth:NO];
    if (token.length) h[@"Authorization"] = [@"Bearer " stringByAppendingString:token];
    [KLHttp GET:url headers:h completion:^(id json, NSData *data, NSHTTPURLResponse *response, NSError *error) {
        NSMutableArray *items = [NSMutableArray array];
        if ([json isKindOfClass:[NSDictionary class]] && [json[@"data"] isKindOfClass:[NSArray class]]) {
            for (NSDictionary *d in json[@"data"]) {
                if (![d isKindOfClass:[NSDictionary class]]) continue;
                NSDictionary *subject = [d[@"subject"] isKindOfClass:[NSDictionary class]] ? d[@"subject"] : d;
                KLBangumiItem *item = [KLBangumiItem fromDictionary:subject];
                if (item.bid > 0) [items addObject:item];
            }
        }
        if (completion) completion(items, error);
    }];
}

@end
