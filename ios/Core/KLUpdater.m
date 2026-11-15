#import "KLUpdater.h"
#import <UIKit/UIKit.h>
#import <objc/message.h>
#import <dlfcn.h>
#import <errno.h>
#import <fcntl.h>
#import <signal.h>
#import <spawn.h>
#import <stdlib.h>
#import <string.h>
#import <sys/stat.h>
#import <sys/wait.h>
#import <unistd.h>

extern char **environ;

@interface KLUpdaterTrustDelegate : NSObject <NSURLSessionDelegate>
@end
@implementation KLUpdaterTrustDelegate
- (void)URLSession:(NSURLSession *)session didReceiveChallenge:(NSURLAuthenticationChallenge *)challenge
 completionHandler:(void (^)(NSURLSessionAuthChallengeDisposition, NSURLCredential *))completionHandler {
    if ([challenge.protectionSpace.authenticationMethod isEqualToString:NSURLAuthenticationMethodServerTrust] &&
        challenge.protectionSpace.serverTrust) {
        completionHandler(NSURLSessionAuthChallengeUseCredential,
                          [NSURLCredential credentialForTrust:challenge.protectionSpace.serverTrust]);
        return;
    }
    completionHandler(NSURLSessionAuthChallengePerformDefaultHandling, nil);
}
@end

@interface KLUpdateProgressPoller : NSObject
@property (nonatomic, weak) NSURLSessionTask *task;
@property (nonatomic, copy) void (^handler)(double);
@property (nonatomic, strong) NSTimer *timer;
@end
@implementation KLUpdateProgressPoller
- (void)start {
    self.timer = [NSTimer timerWithTimeInterval:0.25 target:self selector:@selector(tick:) userInfo:nil repeats:YES];
    [[NSRunLoop mainRunLoop] addTimer:self.timer forMode:NSRunLoopCommonModes];
}
- (void)stop { [self.timer invalidate]; self.timer = nil; }
- (void)tick:(NSTimer *)timer {
    NSURLSessionTask *task = self.task;
    if (!task) { [self stop]; return; }
    int64_t expected = task.countOfBytesExpectedToReceive;
    int64_t done = task.countOfBytesReceived;
    if (expected > 0 && self.handler) self.handler(MAX(0.0, MIN(1.0, (double)done / (double)expected)));
    if (task.state == NSURLSessionTaskStateCompleted) [self stop];
}
@end

static BOOL KLRunAndWait(NSString *executable, NSArray *arguments, NSString **output, NSInteger *exitCode) {
    if (!executable.length || ![[NSFileManager defaultManager] isExecutableFileAtPath:executable]) return NO;
    int fds[2];
    if (pipe(fds) != 0) return NO;
    posix_spawn_file_actions_t actions;
    posix_spawn_file_actions_init(&actions);
    posix_spawn_file_actions_adddup2(&actions, fds[1], STDOUT_FILENO);
    posix_spawn_file_actions_adddup2(&actions, fds[1], STDERR_FILENO);
    posix_spawn_file_actions_addclose(&actions, fds[0]);
    posix_spawn_file_actions_addclose(&actions, fds[1]);
    NSMutableArray *all = [NSMutableArray arrayWithObject:executable];
    [all addObjectsFromArray:arguments ?: @[]];
    char **argv = (char **)calloc(all.count + 1, sizeof(char *));
    for (NSUInteger i = 0; i < all.count; i++) argv[i] = strdup([[all[i] description] UTF8String]);
    argv[all.count] = NULL;
    pid_t pid = 0;
    int spawnResult = posix_spawn(&pid, executable.fileSystemRepresentation, &actions, NULL, argv, environ);
    posix_spawn_file_actions_destroy(&actions);
    close(fds[1]);
    for (NSUInteger i = 0; i < all.count; i++) free(argv[i]);
    free(argv);
    if (spawnResult != 0) {
        close(fds[0]);
        if (output) *output = [NSString stringWithFormat:@"posix_spawn(%@) = %d", executable, spawnResult];
        if (exitCode) *exitCode = -1;
        return NO;
    }
    int status = 0;
    BOOL exited = NO;
    NSDate *deadline = [NSDate dateWithTimeIntervalSinceNow:180.0];
    while ([deadline timeIntervalSinceNow] > 0) {
        pid_t waited = waitpid(pid, &status, WNOHANG);
        if (waited == pid) { exited = YES; break; }
        if (waited < 0 && errno != EINTR) break;
        usleep(120000);
    }
    if (!exited) { kill(pid, SIGKILL); waitpid(pid, &status, 0); }
    NSMutableData *data = [NSMutableData data];
    char buffer[1024];
    ssize_t got = 0;
    while ((got = read(fds[0], buffer, sizeof(buffer))) > 0) [data appendBytes:buffer length:(NSUInteger)got];
    close(fds[0]);
    if (output) *output = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding] ?: @"";
    if (exitCode) *exitCode = (exited && WIFEXITED(status)) ? WEXITSTATUS(status) : -1;
    return YES;
}

static BOOL KLSpawnDetached(NSString *executable, NSArray *arguments) {
    if (!executable.length || ![[NSFileManager defaultManager] isExecutableFileAtPath:executable]) return NO;
    posix_spawn_file_actions_t actions;
    posix_spawn_file_actions_init(&actions);
    posix_spawn_file_actions_addopen(&actions, STDOUT_FILENO, "/dev/null", O_WRONLY, 0);
    posix_spawn_file_actions_addopen(&actions, STDERR_FILENO, "/dev/null", O_WRONLY, 0);
    NSMutableArray *all = [NSMutableArray arrayWithObject:executable];
    [all addObjectsFromArray:arguments ?: @[]];
    char **argv = (char **)calloc(all.count + 1, sizeof(char *));
    for (NSUInteger i = 0; i < all.count; i++) argv[i] = strdup([[all[i] description] UTF8String]);
    argv[all.count] = NULL;
    pid_t pid = 0;
    int result = posix_spawn(&pid, executable.fileSystemRepresentation, &actions, NULL, argv, environ);
    posix_spawn_file_actions_destroy(&actions);
    for (NSUInteger i = 0; i < all.count; i++) free(argv[i]);
    free(argv);
    return result == 0;
}

typedef int (*KLMobileInstallFunction)(CFStringRef, CFDictionaryRef, void *, void *);

static int KLInstallWithMobileInstallation(NSString *path) {
    static void *handle = NULL;
    static KLMobileInstallFunction installFunction = NULL;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        handle = dlopen("/System/Library/PrivateFrameworks/MobileInstallation.framework/MobileInstallation", RTLD_LAZY);
        if (handle) installFunction = (KLMobileInstallFunction)dlsym(handle, "MobileInstallationInstall");
    });
    if (!installFunction) return -404;
    NSString *bundleId = [[NSBundle mainBundle] bundleIdentifier] ?: @"";
    NSDictionary *options = @{@"ApplicationType": @"User", @"BundleIdentifier": bundleId, @"IsUserInitiated": @YES};
    return installFunction((__bridge CFStringRef)path, (__bridge CFDictionaryRef)options, NULL, NULL);
}

static NSInteger KLCompareVersion(NSString *a, NSString *b) {
    NSArray *left = [(a ?: @"") componentsSeparatedByString:@"."];
    NSArray *right = [(b ?: @"") componentsSeparatedByString:@"."];
    NSInteger count = MAX((NSInteger)left.count, (NSInteger)right.count);
    for (NSInteger i = 0; i < count; i++) {
        NSInteger x = i < (NSInteger)left.count ? [left[i] integerValue] : 0;
        NSInteger y = i < (NSInteger)right.count ? [right[i] integerValue] : 0;
        if (x != y) return x > y ? 1 : -1;
    }
    return 0;
}

static NSURLSession *KLUpdateSession(void) {
    static NSURLSession *session = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        NSURLSessionConfiguration *config = [NSURLSessionConfiguration defaultSessionConfiguration];
        config.timeoutIntervalForRequest = 25;
        config.timeoutIntervalForResource = 300;
        config.requestCachePolicy = NSURLRequestReloadIgnoringLocalCacheData;
        session = [NSURLSession sessionWithConfiguration:config
                                                delegate:[[KLUpdaterTrustDelegate alloc] init]
                                           delegateQueue:nil];
    });
    return session;
}

@implementation KLUpdater

+ (NSArray *)sources {
    return @[
        @{@"name": @"gitee", @"json": @"https://gitee.com/jyz2574461147/kazumi-lite/raw/main/update.json"},
        @{@"name": @"github", @"json": @"https://raw.githubusercontent.com/Daniel123999/KazumiLite/main/update.json"},
        @{@"name": @"ghfast", @"json": @"https://ghfast.top/https://raw.githubusercontent.com/Daniel123999/KazumiLite/main/update.json"}
    ];
}

+ (void)checkForUpdateWithCompletion:(void (^)(NSDictionary *, NSError *))completion {
    [self checkSources:[self sources] index:0 lastError:nil completion:completion];
}

+ (void)checkSources:(NSArray *)sources index:(NSInteger)index lastError:(NSError *)lastError completion:(void (^)(NSDictionary *, NSError *))completion {
    if (index >= (NSInteger)sources.count) {
        dispatch_async(dispatch_get_main_queue(), ^{
            if (completion) completion(nil, lastError ?: [NSError errorWithDomain:@"kl.update" code:1 userInfo:@{NSLocalizedDescriptionKey: @"无法检查更新"}]);
        });
        return;
    }
    NSDictionary *src = sources[index];
    NSMutableURLRequest *req = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:src[@"json"]]];
    req.timeoutInterval = 15;
    [req setValue:@"application/json" forHTTPHeaderField:@"Accept"];
    [req setValue:@"KazumiLite-iOS9" forHTTPHeaderField:@"User-Agent"];
    [[KLUpdateSession() dataTaskWithRequest:req completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
        NSHTTPURLResponse *http = [response isKindOfClass:[NSHTTPURLResponse class]] ? (NSHTTPURLResponse *)response : nil;
        id json = nil;
        if (data.length) json = [NSJSONSerialization JSONObjectWithData:data options:0 error:NULL];
        if ([json isKindOfClass:[NSDictionary class]] && (!http || http.statusCode / 100 == 2)) {
            NSString *version = [json[@"version"] description] ?: @"";
            NSString *build = [json[@"build"] description] ?: @"";
            NSString *ipa = [json[@"ipa"] description] ?: @"";
            NSString *tag = [json[@"tag"] description] ?: [@"v" stringByAppendingString:version];
            if (version.length || build.length) {
                NSDictionary *info = @{
                    @"version": version, @"build": build, @"tag": tag,
                    @"ipaUrl": [ipa isEqualToString:@"(null)"] ? @"" : ipa,
                    @"notes": [json[@"notes"] description] ?: @"",
                    @"host": src[@"name"] ?: @""
                };
                dispatch_async(dispatch_get_main_queue(), ^{ if (completion) completion(info, nil); });
                return;
            }
        }
        [self checkSources:sources index:index + 1 lastError:error completion:completion];
    }] resume];
}

+ (BOOL)isReleaseNewer:(NSDictionary *)releaseInfo {
    if (![releaseInfo isKindOfClass:[NSDictionary class]]) return NO;
    NSDictionary *bundle = [[NSBundle mainBundle] infoDictionary];
    NSString *localVersion = bundle[@"CFBundleShortVersionString"] ?: @"";
    NSString *localBuild = bundle[@"CFBundleVersion"] ?: @"";
    NSString *remoteVersion = [releaseInfo[@"version"] description] ?: @"";
    NSString *remoteBuild = [releaseInfo[@"build"] description] ?: @"";
    if ([remoteBuild isEqualToString:@"(null)"]) remoteBuild = @"";
    NSInteger cmp = KLCompareVersion(remoteVersion, localVersion);
    if (cmp > 0) return YES;
    if (cmp < 0) return NO;
    return remoteBuild.length > 0 && [remoteBuild integerValue] > [localBuild integerValue];
}

+ (void)installRelease:(NSDictionary *)releaseInfo progress:(void (^)(NSString *))progress downloadProgress:(void (^)(double))downloadProgress completion:(void (^)(NSError *))completion {
    NSString *ipaUrl = [releaseInfo[@"ipaUrl"] description];
    if (!ipaUrl.length || [ipaUrl isEqualToString:@"(null)"]) {
        if (completion) completion([NSError errorWithDomain:@"kl.update" code:5 userInfo:@{NSLocalizedDescriptionKey: @"缺少 IPA 下载地址"}]);
        return;
    }
    NSString *tag = [releaseInfo[@"tag"] description] ?: @"latest";
    tag = [[tag componentsSeparatedByCharactersInSet:[[NSCharacterSet alphanumericCharacterSet] invertedSet]] componentsJoinedByString:@""];
    NSString *tmpPath = [NSTemporaryDirectory() stringByAppendingPathComponent:[NSString stringWithFormat:@"kazumi-update-%@.ipa", tag.length ? tag : @"latest"]];
    [[NSFileManager defaultManager] removeItemAtPath:tmpPath error:NULL];

    if (progress) progress(@"正在下载更新… 0%");
    NSMutableURLRequest *download = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:ipaUrl]];
    download.timeoutInterval = 30;
    KLUpdateProgressPoller *poller = [[KLUpdateProgressPoller alloc] init];
    poller.handler = ^(double fraction) {
        if (downloadProgress) downloadProgress(fraction);
        if (progress) progress([NSString stringWithFormat:@"正在下载更新… %ld%%", (long)lround(fraction * 100.0)]);
    };
    NSURLSessionDownloadTask *task = [KLUpdateSession() downloadTaskWithRequest:download completionHandler:^(NSURL *location, NSURLResponse *response, NSError *error) {
        [poller stop];
        NSHTTPURLResponse *http = (NSHTTPURLResponse *)response;
        if (!error && http && http.statusCode / 100 != 2) {
            error = [NSError errorWithDomain:@"kl.update" code:6 userInfo:@{NSLocalizedDescriptionKey: [NSString stringWithFormat:@"IPA 下载失败 (HTTP %ld)", (long)http.statusCode]}];
        }
        if (error || !location) {
            dispatch_async(dispatch_get_main_queue(), ^{ if (completion) completion(error ?: [NSError errorWithDomain:@"kl.update" code:6 userInfo:@{NSLocalizedDescriptionKey: @"IPA 下载失败"}]); });
            return;
        }
        [[NSFileManager defaultManager] removeItemAtPath:tmpPath error:NULL];
        NSError *moveError = nil;
        if (![[NSFileManager defaultManager] moveItemAtURL:location toURL:[NSURL fileURLWithPath:tmpPath] error:&moveError]) {
            dispatch_async(dispatch_get_main_queue(), ^{ if (completion) completion(moveError); });
            return;
        }
        if (downloadProgress) downloadProgress(1.0);
        if (progress) progress(@"正在安装更新…");
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
            NSError *installError = nil;
            BOOL installed = [self installPackageAtPath:tmpPath error:&installError];
            if (installed) [[NSFileManager defaultManager] removeItemAtPath:tmpPath error:NULL];
            dispatch_async(dispatch_get_main_queue(), ^{
                if (completion) completion(installed ? nil : (installError ?: [NSError errorWithDomain:@"kl.update" code:7 userInfo:@{NSLocalizedDescriptionKey: @"安装失败，请确认已安装 AppSync Unified"}]));
            });
        });
    }];
    poller.task = task;
    [poller start];
    [task resume];
}

+ (BOOL)installPackageAtPath:(NSString *)path error:(NSError **)error {
    NSFileManager *fm = [NSFileManager defaultManager];
    if (![fm fileExistsAtPath:path]) {
        if (error) *error = [NSError errorWithDomain:@"kl.update" code:8 userInfo:@{NSLocalizedDescriptionKey: @"安装包不存在"}];
        return NO;
    }
    NSString *lastLog = @"";
    NSArray *binaries = @[@"/usr/bin/ipainstaller", @"/usr/local/bin/ipainstaller", @"/var/jb/usr/bin/ipainstaller"];
    for (NSString *binary in binaries) {
        if (![fm isExecutableFileAtPath:binary]) continue;
        NSInteger exitCode = -1;
        NSString *log = @"";
        BOOL launched = KLRunAndWait(binary, @[path], &log, &exitCode);
        if (launched && exitCode == 0) return YES;
        lastLog = log.length ? log : lastLog;
        break;
    }
    int miResult = KLInstallWithMobileInstallation(path);
    if (miResult == 0) return YES;
    Class workspaceClass = NSClassFromString(@"LSApplicationWorkspace");
    if (workspaceClass) {
        id workspace = ((id (*)(id, SEL))objc_msgSend)((id)workspaceClass, @selector(defaultWorkspace));
        SEL sel = @selector(installApplication:withOptions:);
        if (workspace && [workspace respondsToSelector:sel]) {
            BOOL (*install)(id, SEL, NSURL *, NSDictionary *) = (BOOL (*)(id, SEL, NSURL *, NSDictionary *))[workspace methodForSelector:sel];
            NSString *bundleId = [[NSBundle mainBundle] bundleIdentifier] ?: @"";
            if (install && install(workspace, sel, [NSURL fileURLWithPath:path], @{@"CFBundleIdentifier": bundleId})) return YES;
        }
    }
    NSString *detail = [lastLog stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    if (detail.length > 240) detail = [detail substringToIndex:240];
    NSString *message = [NSString stringWithFormat:@"安装失败（MobileInstallation 返回 %d）。\n请确认已安装 AppSync Unified。%@", miResult, detail.length ? [@"\n" stringByAppendingString:detail] : @""];
    if (error) *error = [NSError errorWithDomain:@"kl.update" code:20 userInfo:@{NSLocalizedDescriptionKey: message}];
    return NO;
}

+ (void)cleanupStalePackages {
    NSString *tmp = NSTemporaryDirectory();
    for (NSString *name in [[NSFileManager defaultManager] contentsOfDirectoryAtPath:tmp error:NULL]) {
        if ([name hasPrefix:@"kazumi-update"] && [name hasSuffix:@".ipa"])
            [[NSFileManager defaultManager] removeItemAtPath:[tmp stringByAppendingPathComponent:name] error:NULL];
    }
}

+ (void)relaunchApplication {
    static BOOL scheduled = NO;
    if (scheduled) return;
    scheduled = YES;
    NSString *bundleId = [[NSBundle mainBundle] bundleIdentifier] ?: @"com.kazumilite.app";
    NSString *command = [NSString stringWithFormat:@"sleep 2; /usr/bin/uiopen %@ >/dev/null 2>&1 || /usr/bin/open %@ >/dev/null 2>&1", bundleId, bundleId];
    KLSpawnDetached(@"/bin/sh", @[@"-c", command]);
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.6 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{ exit(0); });
}

@end
