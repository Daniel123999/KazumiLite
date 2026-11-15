#import "KLDownloadManager.h"
#import "KLStore.h"
#import "KLHttp.h"
#import "KLVideoResolver.h"
#import "KLTheme.h"
#import <CommonCrypto/CommonCryptor.h>

@implementation KLDownloadEntry
+ (instancetype)fromDictionary:(NSDictionary *)d {
    KLDownloadEntry *e = [[KLDownloadEntry alloc] init];
    e.identifier = d[@"identifier"] ?: @"";
    e.title = d[@"title"] ?: @"";
    e.episodeTitle = d[@"episodeTitle"] ?: @"";
    e.episodeNumber = [d[@"episodeNumber"] integerValue];
    e.bangumi = [KLBangumiItem fromDictionary:d[@"bangumi"]];
    e.ruleName = d[@"ruleName"] ?: @"";
    e.pageURL = d[@"pageURL"] ?: @"";
    e.localPath = d[@"localPath"] ?: @"";
    e.progress = [d[@"progress"] doubleValue];
    e.status = [d[@"status"] integerValue];
    e.updatedAt = [d[@"updatedAt"] doubleValue];
    e.errorMessage = d[@"errorMessage"] ?: @"";
    return e;
}
- (NSDictionary *)toDictionary {
    return @{
        @"identifier": self.identifier ?: @"",
        @"title": self.title ?: @"",
        @"episodeTitle": self.episodeTitle ?: @"",
        @"episodeNumber": @(self.episodeNumber),
        @"bangumi": self.bangumi ? [self.bangumi toDictionary] : @{},
        @"ruleName": self.ruleName ?: @"",
        @"pageURL": self.pageURL ?: @"",
        @"localPath": self.localPath ?: @"",
        @"progress": @(self.progress),
        @"status": @(self.status),
        @"updatedAt": @(self.updatedAt),
        @"errorMessage": self.errorMessage ?: @""
    };
}
- (NSString *)statusText {
    switch (self.status) {
        case KLDownloadStatusWaiting: return @"等待中";
        case KLDownloadStatusDownloading: return [NSString stringWithFormat:@"下载中 %.0f%%", self.progress * 100];
        case KLDownloadStatusCompleted: return @"已完成";
        case KLDownloadStatusFailed: return @"失败";
        case KLDownloadStatusCancelled: return @"已取消";
        default: return @"";
    }
}
@end

@interface KLDownloadManager ()
@property (nonatomic, strong) NSMutableArray *mutableEntries;
@property (nonatomic, strong) NSOperationQueue *queue;
@property (nonatomic, strong) NSMutableDictionary *cancelFlags;
@end

@implementation KLDownloadManager

+ (instancetype)shared {
    static KLDownloadManager *m = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        m = [[KLDownloadManager alloc] init];
        [m load];
    });
    return m;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        _mutableEntries = [NSMutableArray array];
        _queue = [[NSOperationQueue alloc] init];
        _queue.maxConcurrentOperationCount = 1;
        _cancelFlags = [NSMutableDictionary dictionary];
    }
    return self;
}

- (NSString *)storeFile { return [[KLStore shared].downloadsPath stringByAppendingPathComponent:@"downloads.json"]; }

- (void)load {
    id json = [KLStore readJSON:[self storeFile]];
    [self.mutableEntries removeAllObjects];
    if ([json isKindOfClass:[NSArray class]]) {
        for (NSDictionary *d in json) {
            KLDownloadEntry *e = [KLDownloadEntry fromDictionary:d];
            if (e.identifier.length) {
                if (e.status == KLDownloadStatusDownloading) e.status = KLDownloadStatusCancelled;
                [self.mutableEntries addObject:e];
            }
        }
    }
}

- (void)save {
    NSMutableArray *arr = [NSMutableArray array];
    for (KLDownloadEntry *e in self.mutableEntries) [arr addObject:[e toDictionary]];
    [KLStore writeJSON:arr toPath:[self storeFile]];
    dispatch_async(dispatch_get_main_queue(), ^{
        [[NSNotificationCenter defaultCenter] postNotificationName:@"KLDownloadsDidChange" object:nil];
    });
}

- (NSArray *)entries {
    return [self.mutableEntries copy];
}

- (NSString *)absolutePathForEntry:(KLDownloadEntry *)entry {
    if (!entry.localPath.length) return nil;
    if ([entry.localPath hasPrefix:@"/"]) return entry.localPath;
    return [[KLStore shared].downloadsPath stringByAppendingPathComponent:entry.localPath];
}

- (void)startDownloadForBangumi:(KLBangumiItem *)bangumi rule:(KLRule *)rule pageURL:(NSString *)pageURL episodeIndex:(NSInteger)episodeIndex episodeTitle:(NSString *)episodeTitle {
    if (!pageURL.length) return;
    NSString *identifier = [NSString stringWithFormat:@"%ld-%@-%ld", (long)bangumi.bid, rule.name ?: @"rule", (long)episodeIndex];
    for (KLDownloadEntry *e in self.mutableEntries) {
        if ([e.identifier isEqualToString:identifier] && e.status == KLDownloadStatusDownloading) return;
    }
    KLDownloadEntry *entry = [[KLDownloadEntry alloc] init];
    entry.identifier = identifier;
    entry.title = [bangumi displayName];
    entry.bangumi = bangumi;
    entry.ruleName = rule.name ?: @"";
    entry.episodeTitle = episodeTitle ?: [NSString stringWithFormat:@"第 %ld 集", (long)episodeIndex + 1];
    entry.episodeNumber = episodeIndex + 1;
    entry.pageURL = pageURL;
    entry.localPath = identifier;
    entry.status = KLDownloadStatusWaiting;
    entry.updatedAt = [[NSDate date] timeIntervalSince1970];
    [self.mutableEntries insertObject:entry atIndex:0];
    [self save];

    [[KLVideoResolver shared] resolvePage:pageURL rule:rule completion:^(NSString *videoURL, NSDictionary *headers, NSError *error) {
        if (!videoURL.length) {
            entry.status = KLDownloadStatusFailed;
            entry.errorMessage = error.localizedDescription ?: @"解析失败";
            [self save];
            return;
        }
        entry.status = KLDownloadStatusDownloading;
        [self save];
        NSDictionary *h = headers ?: @{};
        if ([videoURL.lowercaseString containsString:@".m3u8"]) {
            [self downloadHLS:videoURL headers:h entry:entry];
        } else {
            [self downloadFile:videoURL headers:h entry:entry];
        }
    }];
}

- (void)downloadFile:(NSString *)url headers:(NSDictionary *)headers entry:(KLDownloadEntry *)entry {
    NSString *dir = [[KLStore shared].downloadsPath stringByAppendingPathComponent:entry.identifier];
    [[NSFileManager defaultManager] createDirectoryAtPath:dir withIntermediateDirectories:YES attributes:nil error:NULL];
    NSString *ext = [url.pathExtension length] ? url.pathExtension : @"mp4";
    NSString *path = [dir stringByAppendingPathComponent:[@"video." stringByAppendingString:ext]];
    [KLHttp download:url toPath:path progress:^(double fraction, int64_t received, int64_t expected) {
        entry.progress = fraction;
        entry.updatedAt = [[NSDate date] timeIntervalSince1970];
        if ((NSInteger)(fraction * 100) % 5 == 0) [self save];
    } completion:^(NSString *p, NSError *error) {
        entry.status = p ? KLDownloadStatusCompleted : KLDownloadStatusFailed;
        entry.progress = p ? 1.0 : entry.progress;
        entry.errorMessage = error.localizedDescription ?: @"";
        [self save];
    }];
}

#pragma mark - HLS

- (NSString *)absoluteURL:(NSString *)path base:(NSString *)base {
    if ([path hasPrefix:@"http"]) return path;
    NSURL *b = [NSURL URLWithString:base];
    if ([path hasPrefix:@"//"]) return [@"https:" stringByAppendingString:path];
    if ([path hasPrefix:@"/"]) return [NSString stringWithFormat:@"%@://%@%@", b.scheme, b.host, path];
    NSString *dir = [base substringToIndex:[base rangeOfString:@"/" options:NSBackwardsSearch].location + 1];
    return [dir stringByAppendingString:path];
}

- (void)downloadHLS:(NSString *)url headers:(NSDictionary *)headers entry:(KLDownloadEntry *)entry {
    [KLHttp GET:url headers:headers completion:^(id json, NSData *data, NSHTTPURLResponse *response, NSError *error) {
        NSString *text = [json isKindOfClass:[NSString class]] ? json : [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
        if (!text.length) {
            entry.status = KLDownloadStatusFailed;
            entry.errorMessage = @"m3u8 下载失败";
            [self save];
            return;
        }
        if ([text containsString:@"#EXT-X-STREAM-INF"]) {
            NSArray *lines = [text componentsSeparatedByCharactersInSet:[NSCharacterSet newlineCharacterSet]];
            NSInteger bestBandwidth = -1;
            NSString *bestURL = nil;
            for (NSInteger i = 0; i < (NSInteger)lines.count; i++) {
                NSString *line = [lines[i] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
                if ([line hasPrefix:@"#EXT-X-STREAM-INF"]) {
                    NSRange r = [line rangeOfString:@"BANDWIDTH="];
                    NSInteger bw = 0;
                    if (r.location != NSNotFound) {
                        NSString *rest = [line substringFromIndex:r.location + r.length];
                        NSArray *parts = [rest componentsSeparatedByCharactersInSet:[[NSCharacterSet decimalDigitCharacterSet] invertedSet]];
                        bw = [parts.firstObject integerValue];
                    }
                    NSString *next = nil;
                    for (NSInteger j = i + 1; j < (NSInteger)lines.count; j++) {
                        NSString *l = [lines[j] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
                        if (l.length && ![l hasPrefix:@"#"]) { next = l; break; }
                    }
                    if (next && bw > bestBandwidth) { bestBandwidth = bw; bestURL = [self absoluteURL:next base:url]; }
                }
            }
            if (bestURL.length) [self downloadHLS:bestURL headers:headers entry:entry];
            else {
                entry.status = KLDownloadStatusFailed;
                entry.errorMessage = @"m3u8 变体解析失败";
                [self save];
            }
            return;
        }
        [self downloadMediaPlaylist:text baseURL:url headers:headers entry:entry];
    }];
}

- (void)downloadMediaPlaylist:(NSString *)text baseURL:(NSString *)baseURL headers:(NSDictionary *)headers entry:(KLDownloadEntry *)entry {
    NSArray *lines = [text componentsSeparatedByCharactersInSet:[NSCharacterSet newlineCharacterSet]];
    NSMutableArray *segments = [NSMutableArray array];
    NSMutableArray *durations = [NSMutableArray array];
    NSString *keyURI = nil;
    NSData *keyData = nil;
    NSData *iv = nil;
    NSString *mapURI = nil;
    double maxDuration = 0;
    double currentDuration = 0;
    for (NSString *raw in lines) {
        NSString *line = [raw stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
        if ([line hasPrefix:@"#EXT-X-KEY:"]) {
            if ([line containsString:@"METHOD=NONE"]) { keyURI = nil; }
            else {
                NSRange r = [line rangeOfString:@"URI=\""];
                if (r.location != NSNotFound) {
                    NSString *rest = [line substringFromIndex:r.location + r.length];
                    NSRange end = [rest rangeOfString:@"\""];
                    if (end.location != NSNotFound) keyURI = [self absoluteURL:[rest substringToIndex:end.location] base:baseURL];
                }
                NSRange ivRange = [line rangeOfString:@"IV=0x"];
                if (ivRange.location != NSNotFound) {
                    NSString *hex = [line substringFromIndex:ivRange.location + 5];
                    hex = [hex componentsSeparatedByCharactersInSet:[[NSCharacterSet alphanumericCharacterSet] invertedSet]].firstObject;
                    iv = [self dataFromHex:hex];
                }
            }
        } else if ([line hasPrefix:@"#EXTINF:"]) {
            currentDuration = [[[line substringFromIndex:8] componentsSeparatedByString:@","].firstObject doubleValue];
            maxDuration = MAX(maxDuration, currentDuration);
        } else if ([line hasPrefix:@"#EXT-X-MAP:"]) {
            NSRange r = [line rangeOfString:@"URI=\""];
            if (r.location != NSNotFound) {
                NSString *rest = [line substringFromIndex:r.location + r.length];
                NSRange end = [rest rangeOfString:@"\""];
                if (end.location != NSNotFound) mapURI = [self absoluteURL:[rest substringToIndex:end.location] base:baseURL];
            }
        } else if (line.length && ![line hasPrefix:@"#"]) {
            [segments addObject:[self absoluteURL:line base:baseURL]];
            [durations addObject:@(currentDuration > 0 ? currentDuration : 1.0)];
            currentDuration = 0;
        }
    }
    if (segments.count == 0) {
        entry.status = KLDownloadStatusFailed;
        entry.errorMessage = @"m3u8 没有分片";
        [self save];
        return;
    }
    NSString *dir = [[KLStore shared].downloadsPath stringByAppendingPathComponent:entry.identifier];
    [[NSFileManager defaultManager] createDirectoryAtPath:dir withIntermediateDirectories:YES attributes:nil error:NULL];

    NSString *ext = [segments.firstObject.pathExtension length] ? segments.firstObject.pathExtension : @"ts";
    NSMutableArray *names = [NSMutableArray array];
    for (NSInteger i = 0; i < (NSInteger)segments.count; i++) [names addObject:[NSString stringWithFormat:@"seg_%05ld.%@", (long)i, ext]];

    // Fetch the encryption key once.
    void (^startSegments)(void) = ^{
        if (keyURI) {
            [KLHttp GET:keyURI headers:headers completion:^(id json, NSData *data, NSHTTPURLResponse *response, NSError *error) {
                keyData = data.length == 16 ? data : nil;
                [self downloadSegments:segments names:names durations:durations dir:dir key:keyData iv:iv mapURL:mapURI headers:headers entry:entry maxDuration:maxDuration];
            }];
        } else {
            [self downloadSegments:segments names:names durations:durations dir:dir key:nil iv:nil mapURL:mapURI headers:headers entry:entry maxDuration:maxDuration];
        }
    };
    startSegments();
}

- (NSData *)dataFromHex:(NSString *)hex {
    if (hex.length % 2) return nil;
    NSMutableData *d = [NSMutableData data];
    for (NSInteger i = 0; i < (NSInteger)hex.length; i += 2) {
        unsigned int byte = 0;
        [[NSScanner scannerWithString:[hex substringWithRange:NSMakeRange(i, 2)]] scanHexInt:&byte];
        [d appendBytes:&byte length:1];
    }
    return d;
}

- (void)downloadSegments:(NSArray *)segments names:(NSArray *)names durations:(NSArray *)durations dir:(NSString *)dir key:(NSData *)key iv:(NSData *)iv mapURL:(NSString *)mapURL headers:(NSDictionary *)headers entry:(KLDownloadEntry *)entry maxDuration:(double)maxDuration {
    NSMutableArray *localNames = [NSMutableArray array];
    __block NSInteger index = 0;
    __block void (^next)(void);
    next = ^{
        if (index >= (NSInteger)segments.count) {
            [self writeLocalPlaylist:localNames durations:durations maxDuration:maxDuration dir:dir hasMap:mapURL.length > 0 entry:entry];
            return;
        }
        NSString *remote = segments[index];
        NSString *localName = names[index];
        NSData *segmentIV = iv;
        if (!segmentIV) {
            unsigned char seq[16] = {0};
            NSInteger n = index;
            for (NSInteger i = 15; i >= 0 && n > 0; i--) { seq[i] = (unsigned char)(n & 0xFF); n >>= 8; }
            segmentIV = [NSData dataWithBytes:seq length:16];
        }
        [KLHttp GET:remote headers:headers completion:^(id json, NSData *data, NSHTTPURLResponse *response, NSError *error) {
            if (data.length == 0) {
                entry.status = KLDownloadStatusFailed;
                entry.errorMessage = [NSString stringWithFormat:@"分片 %ld 下载失败", (long)index];
                [self save];
                return;
            }
            NSData *output = data;
            if (key.length == 16) {
                output = [self decryptAES128:data key:key iv:segmentIV];
                if (!output.length) output = data;
            }
            [output writeToFile:[dir stringByAppendingPathComponent:localName] atomically:YES];
            [localNames addObject:localName];
            index++;
            entry.progress = (double)index / (double)segments.count;
            entry.updatedAt = [[NSDate date] timeIntervalSince1970];
            [self save];
            next();
        }];
    };
    if (mapURL.length) {
        [KLHttp GET:mapURL headers:headers completion:^(id json, NSData *data, NSHTTPURLResponse *response, NSError *error) {
            if (data.length) [data writeToFile:[dir stringByAppendingPathComponent:@"init.mp4"] atomically:YES];
            next();
        }];
    } else {
        next();
    }
}

- (NSData *)decryptAES128:(NSData *)data key:(NSData *)key iv:(NSData *)iv {
    size_t outLength = 0;
    NSMutableData *out = [NSMutableData dataWithLength:data.length + kCCBlockSizeAES128];
    CCCryptorStatus status = CCCrypt(kCCDecrypt, kCCAlgorithmAES128, kCCOptionPKCS7Padding,
                                     key.bytes, key.length, iv.bytes,
                                     data.bytes, data.length,
                                     out.mutableBytes, out.length, &outLength);
    if (status != kCCSuccess) return nil;
    out.length = outLength;
    return out;
}

- (void)writeLocalPlaylist:(NSArray *)names durations:(NSArray *)durations maxDuration:(double)maxDuration dir:(NSString *)dir hasMap:(BOOL)hasMap entry:(KLDownloadEntry *)entry {
    NSMutableString *playlist = [NSMutableString string];
    [playlist appendString:@"#EXTM3U\n#EXT-X-VERSION:3\n"];
    [playlist appendFormat:@"#EXT-X-TARGETDURATION:%ld\n", (long)ceil(MAX(1, maxDuration))];
    [playlist appendString:@"#EXT-X-MEDIA-SEQUENCE:0\n"];
    if (hasMap) [playlist appendString:@"#EXT-X-MAP:URI=\"init.mp4\"\n"];
    for (NSInteger i = 0; i < (NSInteger)names.count; i++) {
        double d = i < (NSInteger)durations.count ? [durations[i] doubleValue] : maxDuration;
        [playlist appendFormat:@"#EXTINF:%.3f,\n%@\n", MAX(0.1, d), names[i]];
    }
    [playlist appendString:@"#EXT-X-ENDLIST\n"];
    NSString *path = [dir stringByAppendingPathComponent:@"local.m3u8"];
    [playlist writeToFile:path atomically:YES encoding:NSUTF8StringEncoding error:NULL];
    entry.localPath = [NSString stringWithFormat:@"%@/local.m3u8", entry.identifier];
    entry.status = KLDownloadStatusCompleted;
    entry.progress = 1.0;
    [self save];
    [KLTheme showToast:[NSString stringWithFormat:@"下载完成：%@ %@", entry.title, entry.episodeTitle] inView:[UIApplication sharedApplication].keyWindow];
}

- (void)cancelEntry:(KLDownloadEntry *)entry {
    entry.status = KLDownloadStatusCancelled;
    [self save];
}

- (void)removeEntry:(KLDownloadEntry *)entry {
    NSString *dir = [[KLStore shared].downloadsPath stringByAppendingPathComponent:entry.identifier];
    [[NSFileManager defaultManager] removeItemAtPath:dir error:NULL];
    [self.mutableEntries removeObject:entry];
    [self save];
}

@end
