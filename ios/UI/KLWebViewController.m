#import "KLWebViewController.h"
#import "KLTheme.h"
#import "KLComponents.h"
#import <WebKit/WebKit.h>

@interface KLWebViewController () <WKNavigationDelegate>
@property (nonatomic, copy) NSString *urlString;
@property (nonatomic, copy) NSString *pageTitle;
@property (nonatomic, strong) NSDictionary *headers;
@property (nonatomic, strong) WKWebView *webView;
@property (nonatomic, strong) UIProgressView *progressView;
@property (nonatomic, strong) UIButton *backButton;
@property (nonatomic, strong) UIButton *closeButton;
@property (nonatomic, strong) UILabel *titleLabel;
@end

@implementation KLWebViewController

- (instancetype)initWithURL:(NSString *)url title:(NSString *)title {
    return [self initWithURL:url title:title headers:nil];
}

- (instancetype)initWithURL:(NSString *)url title:(NSString *)title headers:(NSDictionary *)headers {
    self = [super init];
    if (self) {
        _urlString = [url copy];
        _pageTitle = [title copy];
        _headers = [headers copy];
    }
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = [KLTheme background];

    UIView *top = [[UIView alloc] initWithFrame:CGRectMake(0, 0, self.view.bounds.size.width, 44)];
    top.backgroundColor = [KLTheme bar];
    top.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    [self.view addSubview:top];

    self.backButton = [KLComponents iconButton:KLIconBack size:20 color:[KLTheme textPrimary] target:self action:@selector(goBack)];
    self.backButton.frame = CGRectMake(4, 5, 36, 34);
    [top addSubview:self.backButton];

    self.closeButton = [KLComponents iconButton:KLIconClose size:20 color:[KLTheme textPrimary] target:self action:@selector(close)];
    self.closeButton.frame = CGRectMake(self.view.bounds.size.width - 40, 5, 36, 34);
    self.closeButton.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin;
    [top addSubview:self.closeButton];

    self.titleLabel = [KLComponents label:[KLTheme boldFont:14] color:[KLTheme textPrimary]];
    self.titleLabel.text = self.pageTitle;
    self.titleLabel.textAlignment = NSTextAlignmentCenter;
    self.titleLabel.frame = CGRectMake(44, 0, self.view.bounds.size.width - 88, 44);
    self.titleLabel.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    [top addSubview:self.titleLabel];

    self.progressView = [[UIProgressView alloc] initWithProgressViewStyle:UIProgressViewStyleBar];
    self.progressView.frame = CGRectMake(0, 44, self.view.bounds.size.width, 2);
    self.progressView.progressTintColor = [KLTheme accent];
    self.progressView.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    [self.view addSubview:self.progressView];

    WKWebViewConfiguration *config = [[WKWebViewConfiguration alloc] init];
    config.allowsInlineMediaPlayback = YES;
    config.mediaPlaybackRequiresUserGesture = NO;
    self.webView = [[WKWebView alloc] initWithFrame:CGRectMake(0, 46, self.view.bounds.size.width, self.view.bounds.size.height - 46) configuration:config];
    self.webView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    self.webView.navigationDelegate = self;
    [self.view addSubview:self.webView];

    NSMutableURLRequest *req = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:self.urlString]];
    for (NSString *key in self.headers) [req setValue:self.headers[key] forHTTPHeaderField:key];
    [self.webView loadRequest:req];

    [self.webView addObserver:self forKeyPath:@"estimatedProgress" options:NSKeyValueObservingOptionNew context:nil];
    [self.webView addObserver:self forKeyPath:@"title" options:NSKeyValueObservingOptionNew context:nil];
}

- (void)dealloc {
    @try { [self.webView removeObserver:self forKeyPath:@"estimatedProgress"]; } @catch (__unused NSException *e) {}
    @try { [self.webView removeObserver:self forKeyPath:@"title"]; } @catch (__unused NSException *e) {}
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context {
    if ([keyPath isEqualToString:@"estimatedProgress"]) {
        CGFloat p = self.webView.estimatedProgress;
        self.progressView.progress = p;
        self.progressView.hidden = p >= 1.0;
    } else if ([keyPath isEqualToString:@"title"]) {
        if (self.webView.title.length && !self.pageTitle.length) self.titleLabel.text = self.webView.title;
    }
}

- (void)goBack {
    if (self.webView.canGoBack) [self.webView goBack];
    else [self close];
}

- (void)close {
    if (self.onClose) self.onClose();
    [self dismissViewControllerAnimated:YES completion:nil];
}

- (void)webView:(WKWebView *)webView didFinishNavigation:(WKNavigation *)navigation {
    self.progressView.hidden = YES;
}

@end
