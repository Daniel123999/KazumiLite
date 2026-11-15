#import "KLPlayerViewController.h"
#import "KLTheme.h"
#import "KLComponents.h"
#import "KLStore.h"
#import "KLVideoResolver.h"
#import "KLDanmakuAPI.h"
#import "KLWebViewController.h"
#import "KLDanmakuView.h"
#import <AVFoundation/AVFoundation.h>
#import <MediaPlayer/MediaPlayer.h>
#import <CoreImage/CoreImage.h>

@interface KLPlayerViewController ()
@property (nonatomic, strong) KLBangumiItem *bangumi;
@property (nonatomic, strong) KLRule *rule;
@property (nonatomic, strong) KLRoad *road;
@property (nonatomic, assign) NSInteger roadIndex;
@property (nonatomic, assign) NSInteger episodeIndex;
@property (nonatomic, copy) NSString *episodeTitle;

@property (nonatomic, strong) AVPlayer *player;
@property (nonatomic, strong) AVPlayerItem *playerItem;
@property (nonatomic, strong) AVPlayerLayer *playerLayer;
@property (nonatomic, strong) UIView *videoContainer;
@property (nonatomic, strong) KLDanmakuView *danmakuView;

@property (nonatomic, strong) UIView *topBar;
@property (nonatomic, strong) UIView *bottomBar;
@property (nonatomic, strong) UILabel *titleLabel;
@property (nonatomic, strong) UILabel *subtitleLabel;
@property (nonatomic, strong) UIButton *backButton;
@property (nonatomic, strong) UIButton *danmakuButton;
@property (nonatomic, strong) UIButton *settingsButton;
@property (nonatomic, strong) UIButton *playButton;
@property (nonatomic, strong) UIButton *nextButton;
@property (nonatomic, strong) UIButton *prevButton;
@property (nonatomic, strong) UIButton *fullscreenButton;
@property (nonatomic, strong) UIButton *episodeButton;
@property (nonatomic, strong) UIButton *screenshotButton;
@property (nonatomic, strong) UISlider *slider;
@property (nonatomic, strong) UILabel *currentLabel;
@property (nonatomic, strong) UILabel *durationLabel;
@property (nonatomic, strong) UIActivityIndicatorView *spinner;
@property (nonatomic, strong) UILabel *statusLabel;
@property (nonatomic, strong) UIButton *retryButton;
@property (nonatomic, strong) UIButton *webButton;

@property (nonatomic, strong) id timeObserver;
@property (nonatomic, strong) NSTimer *hideTimer;
@property (nonatomic, assign) BOOL controlsVisible;
@property (nonatomic, assign) BOOL isSeeking;
@property (nonatomic, assign) BOOL ended;
@property (nonatomic, assign) BOOL usingWeb;
@property (nonatomic, assign) NSInteger danmakuEpisode;
@property (nonatomic, strong) id videoOutput;

@end

@implementation KLPlayerViewController

- (instancetype)initWithBangumi:(KLBangumiItem *)bangumi
                           rule:(KLRule *)rule
                           road:(KLRoad *)road
                      roadIndex:(NSInteger)roadIndex
                   episodeIndex:(NSInteger)episodeIndex
                   episodeTitle:(NSString *)episodeTitle {
    self = [super init];
    if (self) {
        _bangumi = bangumi;
        _rule = rule;
        _road = road;
        _roadIndex = roadIndex;
        _episodeIndex = episodeIndex;
        _episodeTitle = [episodeTitle copy];
        _controlsVisible = YES;
    }
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = [UIColor blackColor];
    self.automaticallyAdjustsScrollViewInsets = NO;

    [[AVAudioSession sharedInstance] setCategory:AVAudioSessionCategoryPlayback error:nil];
    [[AVAudioSession sharedInstance] setActive:YES error:nil];
    [self buildUI];
    [self startResolve];

    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(itemDidEnd:) name:AVPlayerItemDidPlayToEndTimeNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(appWillResign:) name:UIApplicationWillResignActiveNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(appDidBecomeActive:) name:UIApplicationDidBecomeActiveNotification object:nil];

    UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(toggleControls)];
    [self.view addGestureRecognizer:tap];

    UIPanGestureRecognizer *pan = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(handlePan:)];
    [self.view addGestureRecognizer:pan];
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    [self stopPlayback];
}

- (BOOL)prefersStatusBarHidden { return !self.controlsVisible; }
- (UIStatusBarStyle)preferredStatusBarStyle { return UIStatusBarStyleLightContent; }
- (BOOL)shouldAutorotate { return YES; }
- (UIInterfaceOrientationMask)supportedInterfaceOrientations { return UIInterfaceOrientationMaskAllButUpsideDown; }

- (void)buildUI {
    self.videoContainer = [[UIView alloc] initWithFrame:self.view.bounds];
    self.videoContainer.backgroundColor = [UIColor blackColor];
    self.videoContainer.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    [self.view addSubview:self.videoContainer];

    self.playerLayer = [AVPlayerLayer playerLayerWithPlayer:nil];
    self.playerLayer.frame = self.videoContainer.bounds;
    self.playerLayer.videoGravity = AVLayerVideoGravityResizeAspect;
    [self.videoContainer.layer addSublayer:self.playerLayer];

    self.danmakuView = [[KLDanmakuView alloc] initWithFrame:self.videoContainer.bounds];
    self.danmakuView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    self.danmakuView.danmakuEnabled = [[KLStore shared] boolForKey:@"danmakuEnabled" defaultValue:YES];
    [self.videoContainer addSubview:self.danmakuView];

    self.topBar = [[UIView alloc] initWithFrame:CGRectMake(0, 0, self.view.bounds.size.width, 44)];
    self.topBar.backgroundColor = [KLTheme colorWithHex:0x000000 alpha:0.45];
    self.topBar.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    [self.view addSubview:self.topBar];

    self.backButton = [KLComponents iconButton:KLIconBack size:21 color:[UIColor whiteColor] target:self action:@selector(closePlayer)];
    self.backButton.frame = CGRectMake(4, 5, 36, 34);
    [self.topBar addSubview:self.backButton];

    self.titleLabel = [KLComponents label:[KLTheme mediumFont:13] color:[UIColor whiteColor]];
    self.titleLabel.frame = CGRectMake(44, 4, self.view.bounds.size.width - 150, 20);
    self.titleLabel.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    [self.topBar addSubview:self.titleLabel];

    self.subtitleLabel = [KLComponents label:[KLTheme font:10] color:[KLTheme colorWithHex:0xFFFFFF alpha:0.65]];
    self.subtitleLabel.frame = CGRectMake(44, 23, self.view.bounds.size.width - 150, 16);
    self.subtitleLabel.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    [self.topBar addSubview:self.subtitleLabel];

    self.danmakuButton = [KLComponents iconButton:KLIconDanmaku size:20 color:[UIColor whiteColor] target:self action:@selector(toggleDanmaku)];
    self.danmakuButton.frame = CGRectMake(self.view.bounds.size.width - 76, 5, 34, 34);
    self.danmakuButton.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin;
    [self.topBar addSubview:self.danmakuButton];

    self.settingsButton = [KLComponents iconButton:KLIconMore size:20 color:[UIColor whiteColor] target:self action:@selector(showSettings)];
    self.settingsButton.frame = CGRectMake(self.view.bounds.size.width - 40, 5, 34, 34);
    self.settingsButton.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin;
    [self.topBar addSubview:self.settingsButton];

    self.bottomBar = [[UIView alloc] initWithFrame:CGRectMake(0, self.view.bounds.size.height - 88, self.view.bounds.size.width, 88)];
    self.bottomBar.backgroundColor = [KLTheme colorWithHex:0x000000 alpha:0.45];
    self.bottomBar.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleTopMargin;
    [self.view addSubview:self.bottomBar];

    self.playButton = [KLComponents iconButton:KLIconPlay size:24 color:[UIColor whiteColor] target:self action:@selector(togglePlay)];
    self.playButton.frame = CGRectMake(12, 6, 38, 38);
    [self.bottomBar addSubview:self.playButton];

    self.currentLabel = [KLComponents label:[KLTheme font:10] color:[UIColor whiteColor]];
    self.currentLabel.text = @"00:00";
    self.currentLabel.frame = CGRectMake(54, 14, 40, 18);
    [self.bottomBar addSubview:self.currentLabel];

    self.slider = [[UISlider alloc] initWithFrame:CGRectMake(94, 12, self.view.bounds.size.width - 176, 24)];
    self.slider.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    self.slider.minimumTrackTintColor = [KLTheme accent];
    self.slider.maximumTrackTintColor = [KLTheme colorWithHex:0xFFFFFF alpha:0.3];
    [self.slider addTarget:self action:@selector(sliderTouchDown) forControlEvents:UIControlEventTouchDown];
    [self.slider addTarget:self action:@selector(sliderChanged) forControlEvents:UIControlEventValueChanged];
    [self.slider addTarget:self action:@selector(sliderTouchUp) forControlEvents:UIControlEventTouchUpInside | UIControlEventTouchUpOutside | UIControlEventTouchCancel];
    [self.bottomBar addSubview:self.slider];

    self.durationLabel = [KLComponents label:[KLTheme font:10] color:[UIColor whiteColor]];
    self.durationLabel.text = @"00:00";
    self.durationLabel.textAlignment = NSTextAlignmentRight;
    self.durationLabel.frame = CGRectMake(self.view.bounds.size.width - 76, 14, 40, 18);
    self.durationLabel.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin;
    [self.bottomBar addSubview:self.durationLabel];

    self.prevButton = [KLComponents iconButton:KLIconBack size:17 color:[UIColor whiteColor] target:self action:@selector(previousEpisode)];
    self.prevButton.frame = CGRectMake(12, 48, 36, 30);
    [self.bottomBar addSubview:self.prevButton];

    self.nextButton = [KLComponents iconButton:KLIconForward size:17 color:[UIColor whiteColor] target:self action:@selector(nextEpisode)];
    self.nextButton.frame = CGRectMake(50, 48, 36, 30);
    [self.bottomBar addSubview:self.nextButton];

    self.episodeButton = [KLComponents softButton:@"选集" target:self action:@selector(showEpisodeList)];
    self.episodeButton.frame = CGRectMake(96, 48, 58, 28);
    self.episodeButton.backgroundColor = [KLTheme colorWithHex:0xFFFFFF alpha:0.16];
    [self.episodeButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    [self.bottomBar addSubview:self.episodeButton];

    self.screenshotButton = [KLComponents iconButton:KLIconCamera size:18 color:[UIColor whiteColor] target:self action:@selector(takeScreenshot)];
    self.screenshotButton.frame = CGRectMake(160, 48, 34, 30);
    [self.bottomBar addSubview:self.screenshotButton];

    self.fullscreenButton = [KLComponents iconButton:KLIconExpand size:18 color:[UIColor whiteColor] target:self action:@selector(toggleFullscreen)];
    self.fullscreenButton.frame = CGRectMake(self.view.bounds.size.width - 46, 48, 34, 30);
    self.fullscreenButton.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin;
    [self.bottomBar addSubview:self.fullscreenButton];

    self.spinner = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleWhiteLarge];
    self.spinner.center = CGPointMake(self.view.bounds.size.width / 2, self.view.bounds.size.height / 2);
    self.spinner.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleRightMargin | UIViewAutoresizingFlexibleTopMargin | UIViewAutoresizingFlexibleBottomMargin;
    [self.view addSubview:self.spinner];

    self.statusLabel = [KLComponents label:[KLTheme font:12] color:[UIColor whiteColor]];
    self.statusLabel.textAlignment = NSTextAlignmentCenter;
    self.statusLabel.numberOfLines = 0;
    self.statusLabel.frame = CGRectMake(24, self.view.bounds.size.height / 2 + 40, self.view.bounds.size.width - 48, 44);
    self.statusLabel.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleTopMargin;
    [self.view addSubview:self.statusLabel];

    self.retryButton = [KLComponents softButton:@"重试" target:self action:@selector(startResolve)];
    self.retryButton.frame = CGRectMake(self.view.bounds.size.width / 2 - 108, self.view.bounds.size.height / 2 + 90, 100, 34);
    self.retryButton.hidden = YES;
    [self.view addSubview:self.retryButton];

    self.webButton = [KLComponents softButton:@"网页播放" target:self action:@selector(openWebPlayer)];
    self.webButton.frame = CGRectMake(self.view.bounds.size.width / 2 + 8, self.view.bounds.size.height / 2 + 90, 100, 34);
    self.webButton.hidden = YES;
    [self.view addSubview:self.webButton];

    [self updateTitle];
    [self showControlsAnimated:NO];
    [self scheduleHide];
}

- (void)updateTitle {
    self.titleLabel.text = [self.bangumi displayName];
    NSString *ep = self.episodeTitle.length ? self.episodeTitle : [NSString stringWithFormat:@"第 %ld 集", (long)self.episodeIndex + 1];
    self.subtitleLabel.text = [NSString stringWithFormat:@"%@ · %@", self.rule.name ?: @"", ep];
    self.episodeButton.enabled = self.road.urls.count > 1;
    self.prevButton.hidden = self.episodeIndex <= 0;
    self.nextButton.hidden = self.episodeIndex >= (NSInteger)self.road.urls.count - 1;
}

- (void)viewDidLayoutSubviews {
    [super viewDidLayoutSubviews];
    CGRect bounds = self.view.bounds;
    self.videoContainer.frame = bounds;
    self.playerLayer.frame = bounds;
    self.danmakuView.frame = bounds;
    self.topBar.frame = CGRectMake(0, 0, bounds.size.width, 44);
    self.bottomBar.frame = CGRectMake(0, bounds.size.height - 88, bounds.size.width, 88);
    self.spinner.center = CGPointMake(bounds.size.width / 2, bounds.size.height / 2);
    self.statusLabel.frame = CGRectMake(24, bounds.size.height / 2 + 40, bounds.size.width - 48, 44);
    self.retryButton.frame = CGRectMake(bounds.size.width / 2 - 108, bounds.size.height / 2 + 90, 100, 34);
    self.webButton.frame = CGRectMake(bounds.size.width / 2 + 8, bounds.size.height / 2 + 90, 100, 34);
    self.slider.frame = CGRectMake(94, 12, bounds.size.width - 176, 24);
    self.durationLabel.frame = CGRectMake(bounds.size.width - 76, 14, 40, 18);
    self.fullscreenButton.frame = CGRectMake(bounds.size.width - 46, 48, 34, 30);
    self.danmakuButton.frame = CGRectMake(bounds.size.width - 76, 5, 34, 34);
    self.settingsButton.frame = CGRectMake(bounds.size.width - 40, 5, 34, 34);
    self.titleLabel.frame = CGRectMake(44, 4, bounds.size.width - 150, 20);
    self.subtitleLabel.frame = CGRectMake(44, 23, bounds.size.width - 150, 16);
}

- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
    [self saveProgress];
}

- (void)closePlayer {
    [self saveProgress];
    [self stopPlayback];
    if (self.presentingViewController) [self dismissViewControllerAnimated:YES completion:nil];
    else [self.navigationController popViewControllerAnimated:YES];
}

#pragma mark - Resolve

- (void)startResolve {
    self.ended = NO;
    self.usingWeb = NO;
    self.retryButton.hidden = YES;
    self.webButton.hidden = YES;
    self.statusLabel.text = @"正在解析视频源…";
    [self.spinner startAnimating];
    [self stopPlayback];

    if (!self.rule.useNativePlayer) {
        self.statusLabel.text = @"该规则使用网页播放";
        [self.spinner stopAnimating];
        [self openWebPlayer];
        return;
    }
    NSString *pageURL = nil;
    if (self.episodeIndex >= 0 && self.episodeIndex < (NSInteger)self.road.urls.count) {
        pageURL = self.road.urls[self.episodeIndex];
    }
    if (!pageURL.length) {
        [self showError:@"没有可播放的剧集地址"];
        return;
    }
    __weak typeof(self) weakSelf = self;
    [[KLVideoResolver shared] resolvePage:pageURL rule:self.rule completion:^(NSString *videoURL, NSDictionary *headers, NSError *error) {
        __strong typeof(weakSelf) strongSelf = weakSelf;
        if (!strongSelf) return;
        if (videoURL.length) {
            [strongSelf playVideoURL:videoURL headers:headers pageURL:pageURL];
        } else {
            [strongSelf showError:error.localizedDescription ?: @"解析失败"];
        }
    }];
}

- (void)playVideoURL:(NSString *)url headers:(NSDictionary *)headers pageURL:(NSString *)pageURL {
    [self.spinner stopAnimating];
    self.statusLabel.text = @"";
    NSMutableDictionary *options = [NSMutableDictionary dictionary];
    if (headers.count) options[@"AVURLAssetHTTPHeaderFieldsKey"] = headers;
    NSURL *mediaURL = [NSURL URLWithString:url];
    if (!mediaURL) { [self showError:@"视频地址无效"]; return; }
    AVURLAsset *asset = [AVURLAsset URLAssetWithURL:mediaURL options:options.count ? options : nil];
    self.playerItem = [AVPlayerItem playerItemWithAsset:asset];
    self.player = [AVPlayer playerWithPlayerItem:self.playerItem];
    self.playerLayer.player = self.player;
    self.player.volume = 1.0;
    self.player.actionAtItemEnd = AVPlayerActionAtItemEndPause;
    [self.playerItem addObserver:self forKeyPath:@"status" options:NSKeyValueObservingOptionNew context:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(itemFailed:) name:AVPlayerItemFailedToPlayToEndTimeNotification object:self.playerItem];

    [self.player play];
    [self.playButton setImage:[KLComponents icon:KLIconPause size:24 color:[UIColor whiteColor]] forState:UIControlStateNormal];

    [self addTimeObserver];
    [self loadDanmaku];
    [self updateNowPlaying];
    [self scheduleHide];
}

- (void)showError:(NSString *)message {
    [self.spinner stopAnimating];
    self.statusLabel.text = message;
    self.retryButton.hidden = NO;
    self.webButton.hidden = NO;
}

- (void)openWebPlayer {
    NSString *pageURL = nil;
    if (self.episodeIndex >= 0 && self.episodeIndex < (NSInteger)self.road.urls.count) pageURL = self.road.urls[self.episodeIndex];
    if (!pageURL.length) return;
    self.usingWeb = YES;
    [self.player pause];
    KLWebViewController *web = [[KLWebViewController alloc] initWithURL:pageURL title:self.episodeTitle ?: [self.bangumi displayName]];
    web.modalPresentationStyle = UIModalPresentationFullScreen;
    [self presentViewController:web animated:YES completion:nil];
}

#pragma mark - Playback

- (void)addTimeObserver {
    if (self.timeObserver) [self.player removeTimeObserver:self.timeObserver];
    __weak typeof(self) weakSelf = self;
    self.timeObserver = [self.player addPeriodicTimeObserverForInterval:CMTimeMake(1, 2) queue:dispatch_get_main_queue() usingBlock:^(CMTime time) {
        [weakSelf timeUpdated];
    }];
}

- (void)timeUpdated {
    double current = CMTimeGetSeconds(self.player.currentTime);
    double duration = CMTimeGetSeconds(self.playerItem.duration);
    if (isnan(current) || isinf(current)) current = 0;
    if (isnan(duration) || isinf(duration)) duration = 0;
    if (!self.isSeeking && duration > 0) {
        self.slider.maximumValue = duration;
        self.slider.value = current;
    }
    self.currentLabel.text = [KLComponents formatDuration:current];
    self.durationLabel.text = [KLComponents formatDuration:duration];
    [self.danmakuView playbackTimeChanged:current playing:(self.player.rate > 0.01)];
    if (current > 1) [self saveProgressThrottled];
}

- (void)togglePlay {
    if (!self.player) return;
    if (self.player.rate > 0.01) {
        [self.player pause];
        [self.playButton setImage:[KLComponents icon:KLIconPlay size:24 color:[UIColor whiteColor]] forState:UIControlStateNormal];
        [self.danmakuView playbackTimeChanged:CMTimeGetSeconds(self.player.currentTime) playing:NO];
    } else {
        if (self.ended) { [self.player seekToTime:kCMTimeZero]; self.ended = NO; }
        [self.player play];
        [self.playButton setImage:[KLComponents icon:KLIconPause size:24 color:[UIColor whiteColor]] forState:UIControlStateNormal];
        [self.danmakuView playbackTimeChanged:CMTimeGetSeconds(self.player.currentTime) playing:YES];
    }
    [self scheduleHide];
}

- (void)sliderTouchDown { self.isSeeking = YES; [self cancelHide]; }
- (void)sliderChanged {
    double value = self.slider.value;
    self.currentLabel.text = [KLComponents formatDuration:value];
}
- (void)sliderTouchUp {
    double value = self.slider.value;
    [self.player seekToTime:CMTimeMakeWithSeconds(value, NSEC_PER_SEC) toleranceBefore:kCMTimeZero toleranceAfter:kCMTimeZero];
    self.isSeeking = NO;
    [self scheduleHide];
}

- (void)handlePan:(UIPanGestureRecognizer *)pan {
    if (!self.player) return;
    CGPoint translation = [pan translationInView:self.view];
    if (pan.state == UIGestureRecognizerStateBegan) {
        [self cancelHide];
        [self showControlsAnimated:YES];
    } else if (pan.state == UIGestureRecognizerStateChanged) {
        if (fabs(translation.x) > fabs(translation.y)) {
            double duration = CMTimeGetSeconds(self.playerItem.duration);
            double delta = translation.x / CGRectGetWidth(self.view.bounds) * 60;
            double target = CMTimeGetSeconds(self.player.currentTime) + delta;
            target = MAX(0, MIN(duration > 0 ? duration : target, target));
            self.currentLabel.text = [KLComponents formatDuration:target];
        }
    } else if (pan.state == UIGestureRecognizerStateEnded || pan.state == UIGestureRecognizerStateCancelled) {
        if (fabs(translation.x) > fabs(translation.y) && fabs(translation.x) > 20) {
            double duration = CMTimeGetSeconds(self.playerItem.duration);
            double delta = translation.x / CGRectGetWidth(self.view.bounds) * 60;
            double target = CMTimeGetSeconds(self.player.currentTime) + delta;
            target = MAX(0, MIN(duration > 0 ? duration : target, target));
            [self.player seekToTime:CMTimeMakeWithSeconds(target, NSEC_PER_SEC)];
            [KLTheme showToast:[NSString stringWithFormat:@"跳转到 %@", [KLComponents formatDuration:target]] inView:self.view];
        }
        [self scheduleHide];
    }
}

- (void)itemDidEnd:(NSNotification *)note {
    if (note.object != self.playerItem) return;
    self.ended = YES;
    [self saveProgress];
    if ([[KLStore shared] boolForKey:@"autoPlayNext" defaultValue:YES] && self.episodeIndex + 1 < (NSInteger)self.road.urls.count) {
        if (self.nextHandler && self.nextHandler(self)) return;
        [self switchToEpisode:self.episodeIndex + 1];
        return;
    }
    [self showControlsAnimated:YES];
}

- (void)itemFailed:(NSNotification *)note {
    if (note.object != self.playerItem) return;
    NSError *error = note.userInfo[AVPlayerItemFailedToPlayToEndTimeErrorKey];
    [self showError:error.localizedDescription ?: @"播放失败"];
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context {
    if (object == self.playerItem && [keyPath isEqualToString:@"status"]) {
        if (self.playerItem.status == AVPlayerItemStatusReadyToPlay) {
            [self.spinner stopAnimating];
            self.statusLabel.text = @"";
            double duration = CMTimeGetSeconds(self.playerItem.duration);
            self.slider.maximumValue = MAX(1, duration);
            self.durationLabel.text = [KLComponents formatDuration:duration];
            if (self.initialPosition > 1 && self.initialPosition < duration - 5) {
                [self.player seekToTime:CMTimeMakeWithSeconds(self.initialPosition, NSEC_PER_SEC)];
                self.initialPosition = 0;
            }
            [self.player play];
        } else if (self.playerItem.status == AVPlayerItemStatusFailed) {
            [self showError:self.playerItem.error.localizedDescription ?: @"视频加载失败"];
        }
    }
}

- (void)stopPlayback {
    if (self.timeObserver && self.player) {
        [self.player removeTimeObserver:self.timeObserver];
        self.timeObserver = nil;
    }
    if (self.playerItem) {
        @try { [self.playerItem removeObserver:self forKeyPath:@"status"]; } @catch (__unused NSException *e) {}
        [[NSNotificationCenter defaultCenter] removeObserver:self name:AVPlayerItemFailedToPlayToEndTimeNotification object:self.playerItem];
    }
    [self.player pause];
    self.player = nil;
    self.playerItem = nil;
    self.playerLayer.player = nil;
    [self.danmakuView clear];
}

- (void)nextEpisode {
    if (self.nextHandler && self.nextHandler(self)) return;
    if (self.episodeIndex + 1 < (NSInteger)self.road.urls.count) [self switchToEpisode:self.episodeIndex + 1];
}
- (void)previousEpisode {
    if (self.previousHandler && self.previousHandler(self)) return;
    if (self.episodeIndex > 0) [self switchToEpisode:self.episodeIndex - 1];
}

- (void)showEpisodeList {
    UIAlertController *ac = [UIAlertController alertControllerWithTitle:@"选集" message:nil preferredStyle:UIAlertControllerStyleActionSheet];
    NSInteger count = self.road.urls.count;
    for (NSInteger i = 0; i < count; i++) {
        NSString *name = i < (NSInteger)self.road.identifiers.count ? self.road.identifiers[i] : [NSString stringWithFormat:@"第 %ld 集", (long)i + 1];
        NSString *title = [NSString stringWithFormat:@"%@%@", i == self.episodeIndex ? @"✓ " : @"", name];
        [ac addAction:[UIAlertAction actionWithTitle:title style:UIAlertActionStyleDefault handler:^(UIAlertAction *a) {
            [self switchToEpisode:i];
        }]];
    }
    [ac addAction:[UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:nil]];
    [self presentViewController:ac animated:YES completion:nil];
}

- (void)switchToEpisode:(NSInteger)index {
    if (index < 0 || index >= (NSInteger)self.road.urls.count) return;
    self.episodeIndex = index;
    self.episodeTitle = index < (NSInteger)self.road.identifiers.count ? self.road.identifiers[index] : [NSString stringWithFormat:@"第 %ld 集", (long)index + 1];
    [self updateTitle];
    [self startResolve];
}

#pragma mark - Danmaku

- (void)toggleDanmaku {
    BOOL enabled = !self.danmakuView.danmakuEnabled;
    self.danmakuView.danmakuEnabled = enabled;
    [[KLStore shared] setBool:enabled forKey:@"danmakuEnabled"];
    [self.danmakuButton setImage:[KLComponents icon:KLIconDanmaku size:20 color:enabled ? [UIColor whiteColor] : [KLTheme colorWithHex:0xFFFFFF alpha:0.4]] forState:UIControlStateNormal];
    [KLTheme showToast:enabled ? @"弹幕已开启" : @"弹幕已关闭" inView:self.view];
    if (enabled && self.danmakuView.entries.count == 0) [self loadDanmaku];
}

- (void)loadDanmaku {
    if (![[KLStore shared] boolForKey:@"danmakuEnabled" defaultValue:YES]) return;
    NSInteger episode = self.episodeIndex + 1;
    self.danmakuEpisode = episode;
    __weak typeof(self) weakSelf = self;
    [[KLDanmakuAPI shared] fetchForBangumi:self.bangumi episode:episode completion:^(NSArray *entries, NSString *source, NSError *error) {
        __strong typeof(weakSelf) strongSelf = weakSelf;
        if (!strongSelf || strongSelf.danmakuEpisode != episode) return;
        if (entries.count) {
            strongSelf.danmakuView.entries = entries;
            strongSelf.danmakuView.timeOffset = [[KLStore shared] doubleForKey:@"danmakuOffset" defaultValue:0];
            strongSelf.danmakuView.danmakuEnabled = [[KLStore shared] boolForKey:@"danmakuEnabled" defaultValue:YES];
            [strongSelf.danmakuView reloadSettings];
            [KLTheme showToast:[NSString stringWithFormat:@"已加载 %lu 条弹幕（%@）", (unsigned long)entries.count, source ?: @"在线"] inView:strongSelf.view];
        } else if (error) {
            // Silent: not every anime has danmaku.
            NSLog(@"[KazumiLite] danmaku unavailable: %@", error.localizedDescription);
        }
    }];
}

#pragma mark - Controls

- (void)showControlsAnimated:(BOOL)animated {
    self.controlsVisible = YES;
    [UIView animateWithDuration:animated ? 0.2 : 0 animations:^{
        self.topBar.alpha = 1;
        self.bottomBar.alpha = 1;
        self.playButton.alpha = 1;
    }];
    [self setNeedsStatusBarAppearanceUpdate];
}

- (void)hideControls {
    if (self.isSeeking) return;
    self.controlsVisible = NO;
    [UIView animateWithDuration:0.25 animations:^{
        self.topBar.alpha = 0;
        self.bottomBar.alpha = 0;
    }];
    [self setNeedsStatusBarAppearanceUpdate];
}

- (void)toggleControls {
    if (self.controlsVisible) [self hideControls];
    else { [self showControlsAnimated:YES]; [self scheduleHide]; }
}

- (void)scheduleHide {
    [self cancelHide];
    self.hideTimer = [NSTimer scheduledTimerWithTimeInterval:4.0 target:self selector:@selector(hideTimerFired:) userInfo:nil repeats:NO];
}

- (void)cancelHide {
    [self.hideTimer invalidate];
    self.hideTimer = nil;
}

- (void)hideTimerFired:(NSTimer *)timer {
    if (self.player.rate > 0.01) [self hideControls];
}

- (void)showSettings {
    UIAlertController *ac = [UIAlertController alertControllerWithTitle:@"播放设置" message:nil preferredStyle:UIAlertControllerStyleActionSheet];
    [ac addAction:[UIAlertAction actionWithTitle:[NSString stringWithFormat:@"倍速 %.2gx", self.player.rate] style:UIAlertActionStyleDefault handler:^(UIAlertAction *a) {
        [self cycleSpeed];
    }]];
    [ac addAction:[UIAlertAction actionWithTitle:@"弹幕设置" style:UIAlertActionStyleDefault handler:^(UIAlertAction *a) {
        [[NSNotificationCenter defaultCenter] postNotificationName:@"KLOpenDanmakuSettings" object:nil];
    }]];
    [ac addAction:[UIAlertAction actionWithTitle:@"画面比例" style:UIAlertActionStyleDefault handler:^(UIAlertAction *a) {
        self.playerLayer.videoGravity = [self.playerLayer.videoGravity isEqualToString:AVLayerVideoGravityResizeAspect] ? AVLayerVideoGravityResizeAspectFill : AVLayerVideoGravityResizeAspect;
    }]];
    [ac addAction:[UIAlertAction actionWithTitle:@"网页播放" style:UIAlertActionStyleDefault handler:^(UIAlertAction *a) {
        [self openWebPlayer];
    }]];
    [ac addAction:[UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:nil]];
    [self presentViewController:ac animated:YES completion:nil];
}

- (void)cycleSpeed {
    NSArray *speeds = @[@0.5, @0.75, @1.0, @1.25, @1.5, @2.0];
    double current = self.player.rate > 0 ? self.player.rate : 1.0;
    NSInteger idx = 0;
    for (NSInteger i = 0; i < speeds.count; i++) if (fabs([speeds[i] doubleValue] - current) < 0.01) { idx = i; break; }
    idx = (idx + 1) % speeds.count;
    double speed = [speeds[idx] doubleValue];
    [self.player setRate:speed];
    [[KLStore shared] setDouble:speed forKey:@"defaultSpeed"];
    [KLTheme showToast:[NSString stringWithFormat:@"%.2gx 倍速", speed] inView:self.view];
}

- (void)toggleFullscreen {
    UIDeviceOrientation orientation = [UIDevice currentDevice].orientation;
    UIInterfaceOrientation target = UIInterfaceOrientationIsLandscape((UIInterfaceOrientation)orientation)
        ? UIInterfaceOrientationPortrait : UIInterfaceOrientationLandscapeRight;
    [[UIDevice currentDevice] setValue:@(target) forKey:@"orientation"];
    [UIViewController attemptRotationToDeviceOrientation];
}

#pragma mark - Screenshot

- (void)takeScreenshot {
    if (!self.playerItem) return;
    AVPlayerItemVideoOutput *output = [[AVPlayerItemVideoOutput alloc] initWithPixelBufferAttributes:@{
        (id)kCVPixelBufferPixelFormatTypeKey: @(kCVPixelFormatType_32BGRA)
    }];
    [self.playerItem addOutput:output];
    CMTime time = self.player.currentTime;
    CVPixelBufferRef buffer = [output copyPixelBufferForItemTime:time itemTimeForDisplay:nil];
    [self.playerItem removeOutput:output];
    if (!buffer) { [KLTheme showToast:@"截图失败" inView:self.view]; return; }
    CIImage *ci = [CIImage imageWithCVPixelBuffer:buffer];
    CIContext *ctx = [CIContext contextWithOptions:nil];
    CGImageRef cg = [ctx createCGImage:ci fromRect:ci.extent];
    UIImage *image = cg ? [UIImage imageWithCGImage:cg] : nil;
    if (cg) CGImageRelease(cg);
    CVPixelBufferRelease(buffer);
    if (!image) { [KLTheme showToast:@"截图失败" inView:self.view]; return; }
    NSString *path = [[KLStore shared].cachePath stringByAppendingPathComponent:
        [NSString stringWithFormat:@"shot-%.0f.png", [[NSDate date] timeIntervalSince1970]]];
    [UIImagePNGRepresentation(image) writeToFile:path atomically:YES];
    [[UIPasteboard generalPasteboard] setImage:image];
    [KLTheme showToast:@"截图已复制到剪贴板" inView:self.view];
}

#pragma mark - History / now playing

- (void)saveProgressThrottled {
    static NSTimeInterval lastSave = 0;
    NSTimeInterval now = [[NSDate date] timeIntervalSince1970];
    if (now - lastSave < 5) return;
    lastSave = now;
    [self saveProgress];
}

- (void)saveProgress {
    if (!self.player || !self.playerItem || self.usingWeb) return;
    double current = CMTimeGetSeconds(self.player.currentTime);
    double duration = CMTimeGetSeconds(self.playerItem.duration);
    if (current <= 0 || isnan(current)) return;
    KLHistoryEntry *entry = [[KLHistoryEntry alloc] init];
    entry.bangumi = self.bangumi;
    entry.ruleName = self.rule.name ?: @"";
    entry.episodeTitle = self.episodeTitle ?: @"";
    entry.episodeNumber = self.episodeIndex + 1;
    entry.roadIndex = self.roadIndex;
    entry.roadName = self.road.name ?: @"";
    if (self.episodeIndex < (NSInteger)self.road.urls.count) entry.episodePageURL = self.road.urls[self.episodeIndex];
    entry.roadURLs = self.road.urls ?: @[];
    entry.roadIdentifiers = self.road.identifiers ?: @[];
    entry.position = current;
    entry.duration = (isnan(duration) || isinf(duration)) ? 0 : duration;
    [[KLStore shared] recordHistory:entry];
}

- (void)updateNowPlaying {
    NSMutableDictionary *info = [NSMutableDictionary dictionary];
    info[MPMediaItemPropertyTitle] = self.episodeTitle ?: [self.bangumi displayName];
    info[MPMediaItemPropertyArtist] = [self.bangumi displayName];
    [MPNowPlayingInfoCenter defaultCenter].nowPlayingInfo = info;
    [[UIApplication sharedApplication] beginReceivingRemoteControlEvents];
}

- (void)appWillResign:(NSNotification *)note {
    if (self.player && !self.usingWeb) [self.player pause];
    [self saveProgress];
}

- (void)appDidBecomeActive:(NSNotification *)note {
    if (self.player && !self.ended && !self.usingWeb) [self.player play];
}

@end
