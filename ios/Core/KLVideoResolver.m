#import "KLVideoResolver.h"
#import "KLHttp.h"
#import "KLTheme.h"

static BOOL KLIsAdURL(NSString *url) {
    NSString *u = url.lowercaseString;
    NSArray *bad = @[@"googleads", @"googlesyndication", @"prestrain", @"adtrafficquality", @"doubleclick", @"/ad/", @"ads."];
    for (NSString *b in bad) if ([u containsString:b]) return YES;
    return NO;
}

@interface KLVideoResolver () <WKScriptMessageHandler, WKNavigationDelegate>
@property (nonatomic, strong) WKWebView *webView;
@property (nonatomic, copy) void (^completion)(NSString *, NSDictionary *, NSError *);
@property (nonatomic, strong) NSTimer *timeoutTimer;
@property (nonatomic, copy) NSString *pageURL;
@property (nonatomic, strong) KLRule *rule;
@property (nonatomic, assign) BOOL finished;
@end

@implementation KLVideoResolver

+ (instancetype)shared {
    static KLVideoResolver *resolver = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{ resolver = [[KLVideoResolver alloc] init]; });
    return resolver;
}

- (BOOL)isDirectMediaURL:(NSString *)url {
    if ([url hasPrefix:@"file://"]) return YES;
    NSString *u = url.lowercaseString;
    if ([u containsString:@".m3u8"]) return YES;
    if ([u containsString:@".mp4"]) return YES;
    if ([u containsString:@".flv"]) return YES;
    if ([u containsString:@".webm"]) return YES;
    return NO;
}

- (void)resolvePage:(NSString *)pageURL rule:(KLRule *)rule completion:(void (^)(NSString *, NSDictionary *, NSError *))completion {
    [self cancel];
    self.pageURL = pageURL;
    self.rule = rule;
    self.completion = completion;
    self.finished = NO;
    if (!pageURL.length) {
        [self finishWithURL:nil error:[NSError errorWithDomain:@"KLVideo" code:-1 userInfo:@{NSLocalizedDescriptionKey: @"播放地址为空"}]];
        return;
    }
    if ([self isDirectMediaURL:pageURL]) {
        [self finishWithURL:pageURL error:nil];
        return;
    }
    if ([pageURL hasPrefix:@"file://"]) {
        [self finishWithURL:pageURL error:nil];
        return;
    }
    if (![pageURL hasPrefix:@"http"]) {
        [self finishWithURL:nil error:[NSError errorWithDomain:@"KLVideo" code:-2 userInfo:@{NSLocalizedDescriptionKey: @"不支持的播放地址"}]];
        return;
    }

    WKWebViewConfiguration *config = [[WKWebViewConfiguration alloc] init];
    config.allowsInlineMediaPlayback = YES;
    config.mediaPlaybackRequiresUserGesture = NO;
    WKUserContentController *controller = [[WKUserContentController alloc] init];
    [controller addScriptMessageHandler:self name:@"klvideo"];
    [controller addScriptMessageHandler:self name:@"kllog"];
    config.userContentController = controller;

    NSString *hook = [self hookScript];
    WKUserScript *script = [[WKUserScript alloc] initWithSource:hook
                                                  injectionTime:WKUserScriptInjectionTimeAtDocumentStart
                                               forMainFrameOnly:NO];
    [controller addUserScript:script];
    NSString *domHook = [self domScript];
    [controller addUserScript:[[WKUserScript alloc] initWithSource:domHook
                                                       injectionTime:WKUserScriptInjectionTimeAtDocumentEnd
                                                    forMainFrameOnly:NO]];

    self.webView = [[WKWebView alloc] initWithFrame:CGRectMake(0, 0, 320, 480) configuration:config];
    self.webView.navigationDelegate = self;
    self.webView.alpha = 0.02;
    self.webView.userInteractionEnabled = NO;
    UIWindow *window = [UIApplication sharedApplication].keyWindow;
    if (!window) window = [[UIApplication sharedApplication].windows firstObject];
    [window addSubview:self.webView];

    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:pageURL]
                                                          cachePolicy:NSURLRequestReloadIgnoringLocalCacheData
                                                      timeoutInterval:25];
    if (rule.userAgent.length) [request setValue:rule.userAgent forHTTPHeaderField:@"User-Agent"];
    if (rule.referer.length) [request setValue:rule.referer forHTTPHeaderField:@"Referer"];
    [self.webView loadRequest:request];

    self.timeoutTimer = [NSTimer scheduledTimerWithTimeInterval:28 target:self selector:@selector(timeoutFired:) userInfo:nil repeats:NO];
}

- (NSString *)hookScript {
    return @"(function(){"
        "function send(u){try{if(!u)return;u=String(u);if(u.indexOf('blob:')===0)return;"
        "if(u.indexOf('http')!==0&&u.indexOf('//')!==0)return;"
        "window.webkit.messageHandlers.klvideo.postMessage(u);}catch(e){}}"
        "function scan(){try{var vs=document.querySelectorAll('video');for(var i=0;i<vs.length;i++){var v=vs[i];"
        "var s=v.getAttribute('src');if(s)send(s);var ss=v.querySelectorAll('source');for(var j=0;j<ss.length;j++){send(ss[j].getAttribute('src'));}}}catch(e){}}"
        "window.__klScan=scan;"
        "var _open=XMLHttpRequest.prototype.open;XMLHttpRequest.prototype.open=function(m,u){this.__klurl=u;return _open.apply(this,arguments);};"
        "var _send=XMLHttpRequest.prototype.send;XMLHttpRequest.prototype.send=function(){var x=this;x.addEventListener('load',function(){"
        "try{var t=x.responseText||'';if(t.indexOf('#EXTM3U')>=0){send(x.__klurl);}"
        "if(t.length>0&&t.length<400000){var m=t.match(/https?:\\/\\/[^\"'\\\\s<>]+?\\.m3u8[^\"'\\\\s<>]*/g);if(m){for(var i=0;i<m.length;i++)send(m[i]);}}}catch(e){}});return _send.apply(this,arguments);};"
        "if(window.fetch){var _f=window.fetch;window.fetch=function(){var a=arguments;return _f.apply(this,a).then(function(r){try{r.clone().text().then(function(t){if(t.indexOf('#EXTM3U')>=0)send(r.url);var m=t.match(/https?:\\/\\/[^\"'\\\\s<>]+?\\.m3u8[^\"'\\\\s<>]*/g);if(m)for(var i=0;i<m.length;i++)send(m[i]);});}catch(e){}return r;});};}"
        "document.addEventListener('DOMContentLoaded',function(){scan();setTimeout(scan,1200);setTimeout(scan,3000);});"
        "setInterval(scan,2500);"
        "})();";
}

- (NSString *)domScript {
    return @"(function(){try{"
        "var html=document.documentElement.outerHTML||'';"
        "var m=html.match(/https?:\\/\\/[^\"'\\\\s<>]+?\\.m3u8[^\"'\\\\s<>]*/g);"
        "if(m){for(var i=0;i<m.length;i++)window.webkit.messageHandlers.klvideo.postMessage(m[i]);}"
        "var ifs=document.querySelectorAll('iframe');"
        "for(var j=0;j<ifs.length;j++){var s=ifs[j].getAttribute('src')||ifs[j].getAttribute('data-src');if(s)window.webkit.messageHandlers.kllog.postMessage(s);}"
        "}catch(e){}})();";
}

- (void)userContentController:(WKUserContentController *)userContentController didReceiveScriptMessage:(WKScriptMessage *)message {
    id body = message.body;
    if (![body isKindOfClass:[NSString class]]) return;
    NSString *url = body;
    if ([message.name isEqualToString:@"kllog"]) {
        if ([self isDirectMediaURL:url] && !KLIsAdURL(url)) [self finishWithURL:url error:nil];
        // Legacy parser: iframe src might be a playable URL.
        if (self.rule.useLegacyParser && [url hasPrefix:@"http"] && !KLIsAdURL(url)) {
            if (![self isDirectMediaURL:url]) {
                // Load the iframe page in the same webview to sniff deeper.
                [self.webView loadRequest:[NSURLRequest requestWithURL:[NSURL URLWithString:url]]];
            }
        }
        return;
    }
    if ([url hasPrefix:@"//"]) url = [@"https:" stringByAppendingString:url];
    if (![url hasPrefix:@"http"] || KLIsAdURL(url)) return;
    if ([self isDirectMediaURL:url]) {
        [self finishWithURL:url error:nil];
    }
}

- (void)webView:(WKWebView *)webView didFailProvisionalNavigation:(WKNavigation *)navigation withError:(NSError *)error {
    if (!self.finished) [self finishWithURL:nil error:error];
}

- (void)webView:(WKWebView *)webView didFinishNavigation:(WKNavigation *)navigation {
    [webView evaluateJavaScript:@"document.documentElement.outerHTML" completionHandler:^(id result, NSError *error) {
        if (![result isKindOfClass:[NSString class]]) return;
        NSString *html = result;
        NSRegularExpression *re = [NSRegularExpression regularExpressionWithPattern:@"https?://[^\"'\\s<>\\\\]+\\.m3u8[^\"'\\s<>\\\\]*" options:NSRegularExpressionCaseInsensitive error:NULL];
        NSArray *matches = [re matchesInString:html options:0 range:NSMakeRange(0, html.length)];
        for (NSTextCheckingResult *m in matches) {
            NSString *u = [html substringWithRange:m.range];
            u = [u stringByReplacingOccurrencesOfString:@"\\/" withString:@"/"];
            if (!KLIsAdURL(u)) { [self finishWithURL:u error:nil]; return; }
        }
    }];
}

- (void)timeoutFired:(NSTimer *)timer {
    if (!self.finished) {
        [self finishWithURL:nil error:[NSError errorWithDomain:@"KLVideo" code:-3 userInfo:@{NSLocalizedDescriptionKey: @"解析超时，该视频源可能需要网页播放"}]];
    }
}

- (void)finishWithURL:(NSString *)url error:(NSError *)error {
    if (self.finished) return;
    self.finished = YES;
    [self.timeoutTimer invalidate];
    self.timeoutTimer = nil;
    NSMutableDictionary *headers = [NSMutableDictionary dictionary];
    if (self.pageURL.length) headers[@"Referer"] = self.pageURL;
    if (self.rule.userAgent.length) headers[@"User-Agent"] = self.rule.userAgent;
    else headers[@"User-Agent"] = [KLHttp shared].userAgent;
    void (^done)(NSString *, NSDictionary *, NSError *) = self.completion;
    self.completion = nil;
    if (self.webView) {
        [self.webView stopLoading];
        [self.webView removeFromSuperview];
        self.webView = nil;
    }
    if (done) done(url, headers, error);
}

- (void)cancel {
    if (self.webView) {
        [self.webView stopLoading];
        [self.webView removeFromSuperview];
        self.webView = nil;
    }
    [self.timeoutTimer invalidate];
    self.timeoutTimer = nil;
    self.completion = nil;
    self.finished = YES;
}

@end
