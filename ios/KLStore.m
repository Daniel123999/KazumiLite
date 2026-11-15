#import "KLStore.h"

NSString *const KLStoreDidChangeNotification = @"KLStoreDidChangeNotification";

static NSString *KLSettingKey(NSString *key) { return [@"kl." stringByAppendingString:key]; }

@interface KLStore ()
@property (nonatomic, copy) NSString *rootPath;
@property (nonatomic, copy) NSString *rulesPath;
@property (nonatomic, copy) NSString *downloadsPath;
@property (nonatomic, copy) NSString *cachePath;
@property (nonatomic, copy) NSString *danmakuPath;
@property (nonatomic, strong) NSMutableArray *historyCache;
@property (nonatomic, strong) NSMutableArray *collectionCache;
@property (nonatomic, strong) NSMutableArray *ruleCache;
@end

@implementation KLStore

+ (instancetype)shared {
    static KLStore *store = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        store = [[KLStore alloc] init];
    });
    return store;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        NSString *docs = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) firstObject];
        _rootPath = [docs stringByAppendingPathComponent:@"KazumiLite"];
        _rulesPath = [_rootPath stringByAppendingPathComponent:@"rules"];
        _downloadsPath = [_rootPath stringByAppendingPathComponent:@"downloads"];
        _cachePath = [_rootPath stringByAppendingPathComponent:@"cache"];
        _danmakuPath = [_rootPath stringByAppendingPathComponent:@"danmaku"];
        _historyCache = [NSMutableArray array];
        _collectionCache = [NSMutableArray array];
        _ruleCache = [NSMutableArray array];
    }
    return self;
}

- (BOOL)prepare {
    NSFileManager *fm = [NSFileManager defaultManager];
    NSArray *dirs = @[self.rootPath, self.rulesPath, self.downloadsPath, self.cachePath, self.danmakuPath];
    for (NSString *dir in dirs) {
        if (![fm fileExistsAtPath:dir]) {
            [fm createDirectoryAtPath:dir withIntermediateDirectories:YES attributes:nil error:NULL];
        }
    }
    [self loadHistory];
    [self loadCollections];
    [self reloadRules];
    return YES;
}

#pragma mark - Settings

- (id)objectForKey:(NSString *)key {
    return [[NSUserDefaults standardUserDefaults] objectForKey:KLSettingKey(key)];
}
- (void)setObject:(id)value forKey:(NSString *)key {
    if (value) [[NSUserDefaults standardUserDefaults] setObject:value forKey:KLSettingKey(key)];
    else [[NSUserDefaults standardUserDefaults] removeObjectForKey:KLSettingKey(key)];
    [[NSUserDefaults standardUserDefaults] synchronize];
}
- (BOOL)boolForKey:(NSString *)key defaultValue:(BOOL)def {
    id v = [self objectForKey:key];
    return v == nil ? def : [v boolValue];
}
- (NSInteger)integerForKey:(NSString *)key defaultValue:(NSInteger)def {
    id v = [self objectForKey:key];
    return v == nil ? def : [v integerValue];
}
- (double)doubleForKey:(NSString *)key defaultValue:(double)def {
    id v = [self objectForKey:key];
    return v == nil ? def : [v doubleValue];
}
- (NSString *)stringForKey:(NSString *)key defaultValue:(NSString *)def {
    id v = [self objectForKey:key];
    return [v isKindOfClass:[NSString class]] ? v : def;
}
- (void)setBool:(BOOL)value forKey:(NSString *)key { [self setObject:@(value) forKey:key]; }
- (void)setInteger:(NSInteger)value forKey:(NSString *)key { [self setObject:@(value) forKey:key]; }
- (void)setDouble:(double)value forKey:(NSString *)key { [self setObject:@(value) forKey:key]; }
- (void)setString:(NSString *)value forKey:(NSString *)key { [self setObject:value forKey:key]; }

#pragma mark - History

- (NSString *)historyFile { return [self.rootPath stringByAppendingPathComponent:@"history.json"]; }
- (NSString *)collectFile { return [self.rootPath stringByAppendingPathComponent:@"collections.json"]; }

- (void)loadHistory {
    id obj = [KLStore readJSON:[self historyFile]];
    [self.historyCache removeAllObjects];
    if ([obj isKindOfClass:[NSArray class]]) {
        for (NSDictionary *d in obj) {
            KLHistoryEntry *e = [KLHistoryEntry fromDictionary:d];
            if (e.bangumi.bid > 0) [self.historyCache addObject:e];
        }
    }
    [self sortHistory];
}

- (void)sortHistory {
    [self.historyCache sortUsingComparator:^NSComparisonResult(KLHistoryEntry *a, KLHistoryEntry *b) {
        if (a.updatedAt > b.updatedAt) return NSOrderedAscending;
        if (a.updatedAt < b.updatedAt) return NSOrderedDescending;
        return NSOrderedSame;
    }];
}

- (NSArray *)history {
    if (self.historyCache.count == 0) [self loadHistory];
    return [self.historyCache copy];
}

- (void)recordHistory:(KLHistoryEntry *)entry {
    if (!entry || entry.bangumi.bid <= 0) return;
    [self loadHistoryIfNeeded];
    NSInteger idx = -1;
    for (NSInteger i = 0; i < self.historyCache.count; i++) {
        KLHistoryEntry *e = self.historyCache[i];
        if (e.bangumi.bid == entry.bangumi.bid &&
            [e.ruleName isEqualToString:entry.ruleName] &&
            e.episodeNumber == entry.episodeNumber &&
            e.roadIndex == entry.roadIndex) {
            idx = i;
            break;
        }
    }
    entry.updatedAt = [[NSDate date] timeIntervalSince1970];
    if (idx >= 0) [self.historyCache removeObjectAtIndex:idx];
    [self.historyCache insertObject:entry atIndex:0];
    while (self.historyCache.count > 200) [self.historyCache removeLastObject];
    [self saveHistory];
    [[NSNotificationCenter defaultCenter] postNotificationName:KLStoreDidChangeNotification object:nil];
}

- (void)loadHistoryIfNeeded {
    if (self.historyCache.count == 0) [self loadHistory];
}

- (void)saveHistory {
    NSMutableArray *arr = [NSMutableArray array];
    for (KLHistoryEntry *e in self.historyCache) [arr addObject:[e toDictionary]];
    [KLStore writeJSON:arr toPath:[self historyFile]];
}

- (void)removeHistoryForBangumi:(NSInteger)bid ruleName:(NSString *)ruleName episode:(NSInteger)episode {
    [self loadHistory];
    NSMutableArray *keep = [NSMutableArray array];
    for (KLHistoryEntry *e in self.historyCache) {
        BOOL match = e.bangumi.bid == bid;
        if (ruleName.length) match = match && [e.ruleName isEqualToString:ruleName];
        if (episode > 0) match = match && e.episodeNumber == episode;
        if (!match) [keep addObject:e];
    }
    self.historyCache = keep;
    [self saveHistory];
    [[NSNotificationCenter defaultCenter] postNotificationName:KLStoreDidChangeNotification object:nil];
}

- (void)clearHistory {
    [self.historyCache removeAllObjects];
    [self saveHistory];
    [[NSNotificationCenter defaultCenter] postNotificationName:KLStoreDidChangeNotification object:nil];
}

#pragma mark - Collection

- (void)loadCollections {
    id obj = [KLStore readJSON:[self collectFile]];
    [self.collectionCache removeAllObjects];
    if ([obj isKindOfClass:[NSArray class]]) {
        for (NSDictionary *d in obj) {
            KLCollectionEntry *e = [KLCollectionEntry fromDictionary:d];
            if (e.bangumi.bid > 0) [self.collectionCache addObject:e];
        }
    }
}

- (NSArray *)collections {
    if (self.collectionCache.count == 0) [self loadCollections];
    NSArray *copy = [self.collectionCache copy];
    return [copy sortedArrayUsingComparator:^NSComparisonResult(KLCollectionEntry *a, KLCollectionEntry *b) {
        return a.updatedAt > b.updatedAt ? NSOrderedAscending : NSOrderedDescending;
    }];
}

- (KLCollectionEntry *)collectionForBangumi:(NSInteger)bid {
    if (self.collectionCache.count == 0) [self loadCollections];
    for (KLCollectionEntry *e in self.collectionCache) if (e.bangumi.bid == bid) return e;
    return nil;
}

- (void)saveCollections {
    NSMutableArray *arr = [NSMutableArray array];
    for (KLCollectionEntry *e in self.collectionCache) [arr addObject:[e toDictionary]];
    [KLStore writeJSON:arr toPath:[self collectFile]];
}

- (void)setCollection:(KLCollectionEntry *)entry {
    if (!entry || entry.bangumi.bid <= 0) return;
    [self loadCollections];
    NSInteger idx = -1;
    for (NSInteger i = 0; i < self.collectionCache.count; i++) {
        if (((KLCollectionEntry *)self.collectionCache[i]).bangumi.bid == entry.bangumi.bid) { idx = i; break; }
    }
    entry.updatedAt = [[NSDate date] timeIntervalSince1970];
    if (idx >= 0) [self.collectionCache removeObjectAtIndex:idx];
    if (entry.collectType > 0) [self.collectionCache addObject:entry];
    [self saveCollections];
    [[NSNotificationCenter defaultCenter] postNotificationName:KLStoreDidChangeNotification object:nil];
}

- (void)removeCollectionForBangumi:(NSInteger)bid {
    [self loadCollections];
    NSInteger idx = -1;
    for (NSInteger i = 0; i < self.collectionCache.count; i++) {
        if (((KLCollectionEntry *)self.collectionCache[i]).bangumi.bid == bid) { idx = i; break; }
    }
    if (idx >= 0) [self.collectionCache removeObjectAtIndex:idx];
    [self saveCollections];
    [[NSNotificationCenter defaultCenter] postNotificationName:KLStoreDidChangeNotification object:nil];
}

#pragma mark - Rules

- (void)reloadRules {
    [self.ruleCache removeAllObjects];
    NSMutableDictionary *byName = [NSMutableDictionary dictionary];

    // Bundled defaults first (lower priority).
    NSString *bundleRules = [[NSBundle mainBundle] pathForResource:@"rules" ofType:nil];
    NSArray *names = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:bundleRules error:NULL];
    for (NSString *name in names) {
        if (![name.pathExtension.lowercaseString isEqualToString:@"json"]) continue;
        id obj = [KLStore readJSON:[bundleRules stringByAppendingPathComponent:name]];
        KLRule *rule = [KLRule fromDictionary:obj];
        if (rule.name.length) {
            rule.localPath = [bundleRules stringByAppendingPathComponent:name];
            byName[rule.name.lowercaseString] = rule;
        }
    }
    // User rules override bundled ones by name.
    NSArray *userNames = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:self.rulesPath error:NULL];
    for (NSString *name in userNames) {
        if (![name.pathExtension.lowercaseString isEqualToString:@"json"]) continue;
        id obj = [KLStore readJSON:[self.rulesPath stringByAppendingPathComponent:name]];
        KLRule *rule = [KLRule fromDictionary:obj];
        if (rule.name.length) {
            rule.localPath = [self.rulesPath stringByAppendingPathComponent:name];
            byName[rule.name.lowercaseString] = rule;
        }
    }
    NSMutableArray *list = [NSMutableArray arrayWithArray:[byName allValues]];
    NSDictionary *order = [self objectForKey:@"ruleOrder"];
    if ([order isKindOfClass:[NSDictionary class]]) {
        [list sortUsingComparator:^NSComparisonResult(KLRule *a, KLRule *b) {
            NSInteger ia = [order[a.name] integerValue] ?: 9999;
            NSInteger ib = [order[b.name] integerValue] ?: 9999;
            if (ia != ib) return ia < ib ? NSOrderedAscending : NSOrderedDescending;
            return [a.name compare:b.name];
        }];
    } else {
        [list sortUsingComparator:^NSComparisonResult(KLRule *a, KLRule *b) {
            return [a.name compare:b.name];
        }];
    }
    self.ruleCache = list;
}

- (NSArray *)allRules {
    if (self.ruleCache.count == 0) [self reloadRules];
    return [self.ruleCache copy];
}

- (void)reloadAllData {
    [self loadHistory];
    [self loadCollections];
    [self reloadRules];
}

- (NSArray *)enabledRules {
    NSMutableArray *arr = [NSMutableArray array];
    for (KLRule *r in [self allRules]) if (r.enabled) [arr addObject:r];
    return arr;
}

- (void)saveRule:(KLRule *)rule {
    if (!rule.name.length) return;
    NSString *safe = [rule.name stringByReplacingOccurrencesOfString:@"/" withString:@"_"];
    NSString *path = [self.rulesPath stringByAppendingPathComponent:[safe stringByAppendingPathExtension:@"json"]];
    rule.localPath = path;
    [KLStore writeJSON:[rule toDictionary] toPath:path];
    [self reloadRules];
    [[NSNotificationCenter defaultCenter] postNotificationName:KLStoreDidChangeNotification object:nil];
}

- (void)deleteRule:(KLRule *)rule {
    if (!rule) return;
    NSString *path = rule.localPath;
    if (path.length && [path hasPrefix:self.rulesPath]) {
        [[NSFileManager defaultManager] removeItemAtPath:path error:NULL];
    } else {
        // Bundled rule: persist a disabled marker under the same name.
        rule.enabled = NO;
        [self saveRule:rule];
        return;
    }
    [self reloadRules];
    [[NSNotificationCenter defaultCenter] postNotificationName:KLStoreDidChangeNotification object:nil];
}

- (void)setRule:(KLRule *)rule enabled:(BOOL)enabled {
    rule.enabled = enabled;
    [self saveRule:rule];
}

#pragma mark - JSON

+ (id)readJSON:(NSString *)path {
    if (path.length == 0) return nil;
    NSData *data = [NSData dataWithContentsOfFile:path];
    if (data.length == 0) return nil;
    return [NSJSONSerialization JSONObjectWithData:data options:0 error:NULL];
}

+ (BOOL)writeJSON:(id)object toPath:(NSString *)path {
    if (!path.length || object == nil) return NO;
    NSData *data = [NSJSONSerialization dataWithJSONObject:object
                                                   options:NSJSONWritingPrettyPrinted
                                                     error:NULL];
    if (!data) data = [NSJSONSerialization dataWithJSONObject:object options:0 error:NULL];
    return [data writeToFile:path atomically:YES];
}

@end
