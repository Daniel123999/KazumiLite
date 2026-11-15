#import "KLSourceViewController.h"
#import "KLTheme.h"
#import "KLComponents.h"
#import "KLStore.h"
#import "KLRuleEngine.h"
#import "KLPlayerViewController.h"
#import "KLWebViewController.h"
#import "KLDanmakuAPI.h"
#import "KLDownloadManager.h"

@interface KLEpisodeChipCell : UICollectionViewCell
@property (nonatomic, strong) UILabel *titleLabel;
@end
@implementation KLEpisodeChipCell
- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        self.contentView.backgroundColor = [KLTheme card];
        self.contentView.layer.cornerRadius = 7;
        self.contentView.layer.borderWidth = 0.5;
        self.contentView.layer.borderColor = [[KLTheme separator] CGColor];
        _titleLabel = [KLComponents label:[KLTheme font:11] color:[KLTheme textPrimary]];
        _titleLabel.textAlignment = NSTextAlignmentCenter;
        _titleLabel.numberOfLines = 2;
        _titleLabel.frame = self.contentView.bounds;
        _titleLabel.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
        [self.contentView addSubview:_titleLabel];
    }
    return self;
}
@end

@interface KLSourceViewController () <UICollectionViewDataSource, UICollectionViewDelegateFlowLayout>
@property (nonatomic, strong) KLBangumiItem *bangumi;
@property (nonatomic, strong) KLRule *rule;
@property (nonatomic, strong) KLSearchItem *source;
@property (nonatomic, strong) NSArray *roads;
@property (nonatomic, assign) NSInteger selectedRoad;
@property (nonatomic, strong) UILabel *titleLabel;
@property (nonatomic, strong) UILabel *metaLabel;
@property (nonatomic, strong) UISegmentedControl *roadControl;
@property (nonatomic, strong) UICollectionView *collectionView;
@property (nonatomic, strong) UIActivityIndicatorView *spinner;
@property (nonatomic, strong) NSString *errorText;
@property (nonatomic, assign) BOOL autoOpened;
@end

@implementation KLSourceViewController

- (instancetype)initWithBangumi:(KLBangumiItem *)item rule:(KLRule *)rule source:(KLSearchItem *)source {
    self = [super init];
    if (self) {
        _bangumi = item;
        _rule = rule;
        _source = source;
        _roads = @[];
        _selectedRoad = 0;
    }
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = @"剧集";
    self.view.backgroundColor = [KLTheme background];

    self.titleLabel = [KLComponents label:[KLTheme boldFont:15] color:[KLTheme textPrimary]];
    self.titleLabel.numberOfLines = 2;
    self.titleLabel.frame = CGRectMake(14, 8, self.view.bounds.size.width - 28, 40);
    [self.view addSubview:self.titleLabel];

    self.metaLabel = [KLComponents label:[KLTheme font:11] color:[KLTheme textSecondary]];
    self.metaLabel.frame = CGRectMake(14, 48, self.view.bounds.size.width - 28, 18);
    [self.view addSubview:self.metaLabel];

    UIButton *web = [KLComponents softButton:@"打开源页面" target:self action:@selector(openSourcePage)];
    web.frame = CGRectMake(self.view.bounds.size.width - 116, 46, 102, 26);
    [self.view addSubview:web];

    self.roadControl = [[UISegmentedControl alloc] initWithFrame:CGRectMake(14, 76, self.view.bounds.size.width - 28, 30)];
    self.roadControl.tintColor = [KLTheme accent];
    [self.roadControl addTarget:self action:@selector(roadChanged) forControlEvents:UIControlEventValueChanged];
    [self.view addSubview:self.roadControl];

    UICollectionViewFlowLayout *layout = [[UICollectionViewFlowLayout alloc] init];
    layout.minimumInteritemSpacing = 7;
    layout.minimumLineSpacing = 7;
    layout.sectionInset = UIEdgeInsetsMake(10, 12, 20, 12);
    self.collectionView = [[UICollectionView alloc] initWithFrame:CGRectMake(0, 112, self.view.bounds.size.width, self.view.bounds.size.height - 112) collectionViewLayout:layout];
    self.collectionView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    self.collectionView.backgroundColor = [KLTheme background];
    self.collectionView.dataSource = self;
    self.collectionView.delegate = self;
    [self.collectionView registerClass:[KLEpisodeChipCell class] forCellWithReuseIdentifier:@"ep"];
    [self.view addSubview:self.collectionView];

    self.spinner = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleGray];
    self.spinner.center = CGPointMake(self.view.bounds.size.width / 2, 180);
    [self.view addSubview:self.spinner];

    self.titleLabel.text = self.source.name.length ? self.source.name : [self.bangumi displayName];
    self.metaLabel.text = [NSString stringWithFormat:@"%@ · %@", self.rule.name, [self.rule isAPISearch] ? @"API 规则" : @"XPath 规则"];
    self.roadControl.hidden = YES;

    self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithTitle:@"下载" style:UIBarButtonItemStylePlain target:self action:@selector(showDownloadMenu)];

    [self loadChapters];
}

- (void)loadChapters {
    [self.spinner startAnimating];
    self.errorText = nil;
    __weak typeof(self) weakSelf = self;
    [[KLRuleEngine shared] chaptersWithRule:self.rule source:self.source.src completion:^(NSArray *roads, NSError *error) {
        __strong typeof(weakSelf) strongSelf = weakSelf;
        if (!strongSelf) return;
        [strongSelf.spinner stopAnimating];
        if (roads.count == 0) {
            strongSelf.errorText = error.localizedDescription ?: @"未解析到剧集";
            [strongSelf showError];
            return;
        }
        strongSelf.roads = roads;
        [strongSelf setupRoads];
        [strongSelf.collectionView reloadData];
        if (strongSelf.initialEpisode > 0 && !strongSelf.autoOpened) {
            strongSelf.autoOpened = YES;
            [strongSelf openEpisode:strongSelf.initialEpisode - 1];
        }
    }];
}

- (void)showError {
    UIAlertController *ac = [UIAlertController alertControllerWithTitle:@"解析失败" message:self.errorText preferredStyle:UIAlertControllerStyleAlert];
    [ac addAction:[UIAlertAction actionWithTitle:@"重试" style:UIAlertActionStyleDefault handler:^(UIAlertAction *a) { [self loadChapters]; }]];
    [ac addAction:[UIAlertAction actionWithTitle:@"网页打开" style:UIAlertActionStyleDefault handler:^(UIAlertAction *a) { [self openSourcePage]; }]];
    [ac addAction:[UIAlertAction actionWithTitle:@"返回换源" style:UIAlertActionStyleCancel handler:^(UIAlertAction *a) { [self.navigationController popViewControllerAnimated:YES]; }]];
    [self presentViewController:ac animated:YES completion:nil];
}

- (void)setupRoads {
    [self.roadControl removeAllSegments];
    if (self.roads.count <= 1) {
        self.roadControl.hidden = YES;
        self.collectionView.frame = CGRectMake(0, 104, self.view.bounds.size.width, self.view.bounds.size.height - 104);
        return;
    }
    self.roadControl.hidden = NO;
    for (NSInteger i = 0; i < self.roads.count; i++) {
        KLRoad *r = self.roads[i];
        [self.roadControl insertSegmentWithTitle:r.name atIndex:i animated:NO];
    }
    self.roadControl.selectedSegmentIndex = 0;
    self.collectionView.frame = CGRectMake(0, 116, self.view.bounds.size.width, self.view.bounds.size.height - 116);
}

- (void)roadChanged {
    self.selectedRoad = MAX(0, self.roadControl.selectedSegmentIndex);
    [self.collectionView reloadData];
}

- (KLRoad *)currentRoad {
    if (self.selectedRoad >= 0 && self.selectedRoad < (NSInteger)self.roads.count) return self.roads[self.selectedRoad];
    return nil;
}

- (void)openEpisode:(NSInteger)index {
    KLRoad *road = [self currentRoad];
    if (!road || index < 0 || index >= (NSInteger)road.urls.count) return;
    NSString *title = index < (NSInteger)road.identifiers.count ? road.identifiers[index] : [NSString stringWithFormat:@"第 %ld 集", (long)index + 1];
    KLPlayerViewController *player = [[KLPlayerViewController alloc] initWithBangumi:self.bangumi
                                                                               rule:self.rule
                                                                               road:road
                                                                          roadIndex:self.selectedRoad
                                                                       episodeIndex:index
                                                                       episodeTitle:title];
    player.modalPresentationStyle = UIModalPresentationFullScreen;
    [self presentViewController:player animated:YES completion:nil];
}

- (void)openSourcePage {
    KLWebViewController *web = [[KLWebViewController alloc] initWithURL:self.source.src title:self.source.name ?: self.rule.name];
    web.modalPresentationStyle = UIModalPresentationFullScreen;
    [self presentViewController:web animated:YES completion:nil];
}

- (void)showDownloadMenu {
    KLRoad *road = [self currentRoad];
    if (!road || road.urls.count == 0) {
        [KLTheme showToast:@"还没有可下载的剧集" inView:self.view];
        return;
    }
    UIAlertController *ac = [UIAlertController alertControllerWithTitle:@"离线下载" message:@"选择要缓存的集数（HLS 将合并为本地播放列表）" preferredStyle:UIAlertControllerStyleActionSheet];
    NSInteger limit = MIN((NSInteger)road.urls.count, 24);
    for (NSInteger i = 0; i < limit; i++) {
        NSString *name = i < (NSInteger)road.identifiers.count ? road.identifiers[i] : [NSString stringWithFormat:@"第 %ld 集", (long)i + 1];
        [ac addAction:[UIAlertAction actionWithTitle:name style:UIAlertActionStyleDefault handler:^(UIAlertAction *a) {
            [[KLDownloadManager shared] startDownloadForBangumi:self.bangumi
                                                           rule:self.rule
                                                        pageURL:road.urls[i]
                                                   episodeIndex:i
                                                   episodeTitle:name];
            [KLTheme showToast:@"已加入下载队列，可在 我的 → 下载管理 查看" inView:self.view];
        }]];
    }
    [ac addAction:[UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:nil]];
    [self presentViewController:ac animated:YES completion:nil];
}

#pragma mark - Collection

- (NSInteger)collectionView:(UICollectionView *)collectionView numberOfItemsInSection:(NSInteger)section {
    return [self currentRoad].urls.count;
}

- (CGSize)collectionView:(UICollectionView *)collectionView layout:(UICollectionViewLayout *)layout sizeForItemAtIndexPath:(NSIndexPath *)indexPath {
    CGFloat width = (collectionView.bounds.size.width - 24 - 21) / 4.0;
    return CGSizeMake(floor(width), 46);
}

- (UICollectionViewCell *)collectionView:(UICollectionView *)collectionView cellForItemAtIndexPath:(NSIndexPath *)indexPath {
    KLEpisodeChipCell *cell = [collectionView dequeueReusableCellWithReuseIdentifier:@"ep" forIndexPath:indexPath];
    KLRoad *road = [self currentRoad];
    NSString *title = indexPath.item < (NSInteger)road.identifiers.count ? road.identifiers[indexPath.item] : [NSString stringWithFormat:@"第 %ld 集", (long)indexPath.item + 1];
    cell.titleLabel.text = title;
    return cell;
}

- (void)collectionView:(UICollectionView *)collectionView didSelectItemAtIndexPath:(NSIndexPath *)indexPath {
    [self openEpisode:indexPath.item];
}

@end
