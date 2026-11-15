#import "KLWebDAV.h"
#import "KLStore.h"
#import "KLHttp.h"
#import "KLModels.h"

@interface KLWebDAV ()
@property (nonatomic, strong) NSURLSession *session;
@end

@implementation KLWebDAV

+ (instancetype)shared {
    static KLWebDAV *dav = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        dav = [[KLWebDAV alloc] init];
        [dav loadConfig];
    });
    return dav;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        NSURLSessionConfiguration *config = [NSURLSessionConfiguration defaultSessionConfiguration];
        config.timeoutIntervalForRequest = 20;
        config.timeoutIntervalForResource = 90;
        config.requestCachePolicy = NSURLRequestReloadIgnoringLocalCacheData;
        _session = [NSURLSession sessionWithConfiguration:config];
    }
    return self;
}

- (NSString *)configPath {
    return [[KLStore shared].rootPath stringByAppendingPathComponent:@"webdav.plist"];
}

- (void)loadConfig {
    NSDictionary *d = [NSDictionary dictionaryWithContentsOfFile:[self configPath]];
    self.serverURL = d[@"serverURL"] ?: @"";
    self.username = d[@"username"] ?: @"";
    self.password = d[@"password"] ?: @"";
    self.remotePath = d[@"remotePath"] ?: @"/KazumiLite/";
    self.enabled = [d[@"enabled"] boolValue];
}

- (void)saveConfig {
    NSDictionary *d = @{
        @"serverURL": self.serverURL ?: @"",
        @"username": self.username ?: @"",
        @"password": self.password ?: @"",
        @"remotePath": self.remotePath ?: @"/KazumiLite/",
        @"enabled": @(self.enabled)
    };
    [d writeToFile:[self configPath] atomically:YES];
}

- (NSString *)trimmedBase {
    NSString *base = [self.serverURL stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    while ([base hasSuffix:@"/"]) base = [base substringToIndex:base.length - 1];
    return base;
}

- (NSString *)trimmedPath {
    NSString *path = self.remotePath.length ? self.remotePath : @"/KazumiLite/";
    if (![path hasPrefix:@"/"]) path = [@"/" stringByAppendingString:path];
    if (![path hasSuffix:@"/"]) path = [path stringByAppendingString:@"/"];
    return path;
}

- (NSDictionary *)authHeaders {
    if (self.username.length == 0) return @{};
    NSString *auth = [NSString stringWithFormat:@"%@:%@", self.username, self.password ?: @""];
    NSString *b64 = [[auth dataUsingEncoding:NSUTF8StringEncoding] base64EncodedStringWithOptions:0];
    return @{@"Authorization": [@"Basic " stringByAppendingString:b64]};
}

- (NSMutableURLRequest *)requestForPath:(NSString *)name method:(NSString *)method {
    NSString *url = [[self trimmedBase] stringByAppendingString:[self trimmedPath]];
    if (name.length) url = [url stringByAppendingString:name];
    NSMutableURLRequest *req = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:url]
                                                      cachePolicy:NSURLRequestReloadIgnoringLocalCacheData
                                                  timeoutInterval:30];
    req.HTTPMethod = method;
    NSDictionary *auth = [self authHeaders];
    for (NSString *k in auth) [req setValue:auth[k] forHTTPHeaderField:k];
    return req;
}

- (void)ensureRemoteDirectory:(void (^)(BOOL))completion {
    if ([self trimmedBase].length == 0) { if (completion) completion(NO); return; }
    NSMutableURLRequest *req = [self requestForPath:nil method:@"MKCOL"];
    [[self.session dataTaskWithRequest:req completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
        NSInteger code = [(NSHTTPURLResponse *)response statusCode];
        BOOL ok = (code >= 200 && code < 300) || code == 405 || code == 301 || code == 302;
        dispatch_async(dispatch_get_main_queue(), ^{ if (completion) completion(ok); });
    }] resume];
}

- (void)testConnection:(void (^)(BOOL, NSString *))completion {
    if ([self trimmedBase].length == 0) { if (completion) completion(NO, @"请先填写服务器地址"); return; }
    NSMutableURLRequest *req = [self requestForPath:nil method:@"PROPFIND"];
    [req setValue:@"0" forHTTPHeaderField:@"Depth"];
    [req setValue:@"application/xml" forHTTPHeaderField:@"Content-Type"];
    [[self.session dataTaskWithRequest:req completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
        NSInteger code = [(NSHTTPURLResponse *)response statusCode];
        dispatch_async(dispatch_get_main_queue(), ^{
            if (code == 207 || code == 200) {
                if (completion) completion(YES, [NSString stringWithFormat:@"连接成功 (HTTP %ld)", (long)code]);
            } else if (error) {
                if (completion) completion(NO, error.localizedDescription);
            } else {
                if (completion) completion(NO, [NSString stringWithFormat:@"连接失败 (HTTP %ld)", (long)code]);
            }
        });
    }] resume];
}

- (void)putData:(NSData *)data name:(NSString *)name completion:(void (^)(BOOL, NSError *))completion {
    NSMutableURLRequest *req = [self requestForPath:name method:@"PUT"];
    [req setValue:@"application/octet-stream" forHTTPHeaderField:@"Content-Type"];
    req.HTTPBody = data;
    [[self.session dataTaskWithRequest:req completionHandler:^(NSData *d, NSURLResponse *response, NSError *error) {
        NSInteger code = [(NSHTTPURLResponse *)response statusCode];
        BOOL ok = code >= 200 && code < 300;
        dispatch_async(dispatch_get_main_queue(), ^{ if (completion) completion(ok, ok ? nil : (error ?: [NSError errorWithDomain:@"KLWebDAV" code:code userInfo:@{NSLocalizedDescriptionKey: [NSString stringWithFormat:@"HTTP %ld", (long)code]}])); });
    }] resume];
}

- (void)getDataNamed:(NSString *)name completion:(void (^)(NSData *, NSError *))completion {
    NSMutableURLRequest *req = [self requestForPath:name method:@"GET"];
    [[self.session dataTaskWithRequest:req completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
        NSInteger code = [(NSHTTPURLResponse *)response statusCode];
        BOOL ok = code >= 200 && code < 300;
        dispatch_async(dispatch_get_main_queue(), ^{
            if (ok && data.length) { if (completion) completion(data, nil); }
            else { if (completion) completion(nil, error ?: [NSError errorWithDomain:@"KLWebDAV" code:code userInfo:@{NSLocalizedDescriptionKey: [NSString stringWithFormat:@"HTTP %ld", (long)code]}]); }
        });
    }] resume];
}

- (NSArray *)rulesPayload {
    NSMutableArray *arr = [NSMutableArray array];
    for (KLRule *r in [[KLStore shared] allRules]) {
        if (r.localPath && [r.localPath hasPrefix:[KLStore shared].rulesPath]) [arr addObject:[r toDictionary]];
    }
    return arr;
}

- (NSData *)backupData {
    NSMutableArray *history = [NSMutableArray array];
    for (KLHistoryEntry *e in [[KLStore shared] history]) [history addObject:[e toDictionary]];
    NSMutableArray *collections = [NSMutableArray array];
    for (KLCollectionEntry *e in [[KLStore shared] collections]) [collections addObject:[e toDictionary]];
    NSMutableDictionary *settings = [NSMutableDictionary dictionary];
    NSArray *keys = @[@"danmakuEnabled", @"danmakuFontSize", @"danmakuOpacity", @"danmakuDuration", @"danmakuArea",
                      @"danmakuScroll", @"danmakuTop", @"danmakuBottom", @"danmakuBorder", @"danmakuDedup",
                      @"danmakuFollowSpeed", @"danmakuOffset", @"danmakuShield", @"defaultSpeed", @"autoPlayNext",
                      @"autoPlay", @"playResume", @"bangumiMode", @"rulesMirror"];
    for (NSString *k in keys) {
        id v = [[KLStore shared] objectForKey:k];
        if (v) settings[k] = v;
    }
    NSDictionary *payload = @{
        @"version": @1,
        @"updatedAt": @([[NSDate date] timeIntervalSince1970]),
        @"history": history,
        @"collections": collections,
        @"rules": [self rulesPayload],
        @"settings": settings
    };
    return [NSJSONSerialization dataWithJSONObject:payload options:0 error:NULL];
}

- (void)backupAll:(void (^)(BOOL, NSString *))completion {
    if (!self.enabled || [self trimmedBase].length == 0) { if (completion) completion(NO, @"WebDAV 未启用或未配置"); return; }
    [self ensureRemoteDirectory:^(BOOL ok) {
        NSData *data = [self backupData];
        if (!data) { if (completion) completion(NO, @"备份数据生成失败"); return; }
        [self putData:data name:@"kazumi-backup.json" completion:^(BOOL success, NSError *error) {
            if (completion) completion(success, success ? @"备份成功" : (error.localizedDescription ?: @"备份失败"));
        }];
    }];
}

- (void)mergePayload:(NSDictionary *)payload {
    // History: merge by identity, newest wins.
    NSMutableDictionary *history = [NSMutableDictionary dictionary];
    for (KLHistoryEntry *e in [[KLStore shared] history]) {
        NSString *key = [NSString stringWithFormat:@"%ld|%@|%ld|%ld", (long)e.bangumi.bid, e.ruleName, (long)e.episodeNumber, (long)e.roadIndex];
        history[key] = e;
    }
    for (NSDictionary *d in payload[@"history"]) {
        if (![d isKindOfClass:[NSDictionary class]]) continue;
        KLHistoryEntry *remote = [KLHistoryEntry fromDictionary:d];
        if (remote.bangumi.bid <= 0) continue;
        NSString *key = [NSString stringWithFormat:@"%ld|%@|%ld|%ld", (long)remote.bangumi.bid, remote.ruleName, (long)remote.episodeNumber, (long)remote.roadIndex];
        KLHistoryEntry *local = history[key];
        if (!local || remote.updatedAt > local.updatedAt) history[key] = remote;
    }
    NSArray *sorted = [history.allValues sortedArrayUsingComparator:^NSComparisonResult(KLHistoryEntry *a, KLHistoryEntry *b) {
        return a.updatedAt > b.updatedAt ? NSOrderedAscending : NSOrderedDescending;
    }];
    NSMutableArray *historyJSON = [NSMutableArray array];
    for (KLHistoryEntry *e in sorted) [historyJSON addObject:[e toDictionary]];
    [KLStore writeJSON:historyJSON toPath:[[KLStore shared].rootPath stringByAppendingPathComponent:@"history.json"]];

    // Collections: newest wins.
    for (NSDictionary *d in payload[@"collections"]) {
        if (![d isKindOfClass:[NSDictionary class]]) continue;
        KLCollectionEntry *remote = [KLCollectionEntry fromDictionary:d];
        if (remote.bangumi.bid <= 0) continue;
        KLCollectionEntry *local = [[KLStore shared] collectionForBangumi:remote.bangumi.bid];
        if (!local || remote.updatedAt > local.updatedAt) [[KLStore shared] setCollection:remote];
    }

    // Rules: only add missing names by default.
    for (NSDictionary *d in payload[@"rules"]) {
        if (![d isKindOfClass:[NSDictionary class]]) continue;
        KLRule *rule = [KLRule fromDictionary:d];
        if (!rule.name.length) continue;
        BOOL exists = NO;
        for (KLRule *r in [[KLStore shared] allRules]) if ([r.name.lowercaseString isEqualToString:rule.name.lowercaseString]) { exists = YES; break; }
        if (!exists) [[KLStore shared] saveRule:rule];
    }

    NSDictionary *settings = payload[@"settings"];
    if ([settings isKindOfClass:[NSDictionary class]]) {
        for (NSString *k in settings) [[KLStore shared] setObject:settings[k] forKey:k];
    }
    [[KLStore shared] reloadAllData];
}

- (void)restoreAll:(void (^)(BOOL, NSString *))completion {
    if (!self.enabled || [self trimmedBase].length == 0) { if (completion) completion(NO, @"WebDAV 未启用或未配置"); return; }
    [self getDataNamed:@"kazumi-backup.json" completion:^(NSData *data, NSError *error) {
        if (!data) { if (completion) completion(NO, error.localizedDescription ?: @"云端没有备份"); return; }
        id json = [NSJSONSerialization JSONObjectWithData:data options:0 error:NULL];
        if (![json isKindOfClass:[NSDictionary class]]) { if (completion) completion(NO, @"备份格式不正确"); return; }
        [self mergePayload:json];
        [[NSNotificationCenter defaultCenter] postNotificationName:KLStoreDidChangeNotification object:nil];
        if (completion) completion(YES, @"恢复完成");
    }];
}

- (void)syncNow:(void (^)(BOOL, NSString *))completion {
    if (!self.enabled || [self trimmedBase].length == 0) { if (completion) completion(NO, @"WebDAV 未启用或未配置"); return; }
    [self ensureRemoteDirectory:^(BOOL ok) {
        [self getDataNamed:@"kazumi-backup.json" completion:^(NSData *data, NSError *error) {
            if (data) {
                id json = [NSJSONSerialization JSONObjectWithData:data options:0 error:NULL];
                if ([json isKindOfClass:[NSDictionary class]]) [self mergePayload:json];
            }
            NSData *merged = [self backupData];
            [self putData:merged name:@"kazumi-backup.json" completion:^(BOOL success, NSError *e) {
                [[NSNotificationCenter defaultCenter] postNotificationName:KLStoreDidChangeNotification object:nil];
                if (completion) completion(success, success ? @"同步完成" : (e.localizedDescription ?: @"同步失败"));
            }];
        }];
    }];
}

@end
