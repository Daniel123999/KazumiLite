#import "KLHomeViewController.h"
#import "KLTheme.h"
#import "KLComponents.h"
#import "KLBangumiAPI.h"
#import "KLStore.h"
#import "KLDetailViewController.h"

@interface KLHomeViewController () <UICollectionViewDataSource, UICollectionViewDelegateFlowLayout>
@property (nonatomic, strong) UISegmentedControl *segmented;
@property (nonatomic, strong) UIScrollView *weekdayBar;
@property (nonatomic, strong) UICollectionView *collectionView;
@property (nonatomic, strong) UIRefreshControl *refreshControl;
@property (nonatomic, strong) UIActivityIndicatorView *spinner;
@property (nonatomic, strong) UILabel *emptyLabel;
@property (nonatomic, strong) NSArray *days;
@property (nonatomic, strong) NSMutableArray *popular;
@property (nonatomic, assign) NSInteger selectedDay;
@property (nonatomic, assign) NSInteger popularOffset;
@property (nonatomic, assign) BOOL loading;
@property (nonatomic, assign) BOOL loadingMore;
@property (nonatomic, assign) BOOL timelineMode;
- (NSArray *)currentItems;
@end

@implementation KLHomeViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = @"番剧";
    self.view.backgroundColor = [KLTheme background];
    self.days = @[];
    self.popular = [NSMutableArray array];
    self.timelineMode = YES;

    self.segmented = [[UISegmentedControl alloc] initWithItems:@[@"时间表", @"热门"]];
    self.segmented.selectedSegmentIndex = 0;
    self.segmented.tintColor = [KLTheme accent];
    self.segmented.frame = CGRectMake(0, 0, 170, 30);
    if ([self.segmented respondsToSelector:@selector(setTitleTextAttributes:forState:)]) {
        [self.segmented setTitleTextAttributes:@{NSFontAttributeName: [KLTheme mediumFont:12]} forState:UIControlStateNormal];
    }
    [self.segmented addTarget:self action:@selector(segmentChanged) forControlEvents:UIControlEventValueChanged];
    self.navigationItem.titleView = self.segmented;

    self.weekdayBar = [[UIScrollView alloc] initWithFrame:CGRectMake(0, 0, self.view.bounds.size.width, 38)];
    self.weekdayBar.backgroundColor = [KLTheme bar];
    self.weekdayBar.showsHorizontalScrollIndicator = NO;
    [self.view addSubview:self.weekdayBar];
    UIView *line = [[UIView alloc] initWithFrame:CGRectMake(0, 37.5, self.view.bounds.size.width, 0.5)];
    line.backgroundColor = [KLTheme separator];
    [self.view addSubview:line];

    UICollectionViewFlowLayout *layout = [[UICollectionViewFlowLayout alloc] init];
    layout.minimumInteritemSpacing = 8;
    layout.minimumLineSpacing = 14;
    layout.sectionInset = UIEdgeInsetsMake(12, 14, 20, 14);
    self.collectionView = [[UICollectionView alloc] initWithFrame:CGRectMake(0, 38, self.view.bounds.size.width, self.view.bounds.size.height - 38) collectionViewLayout:layout];
    self.collectionView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    self.collectionView.backgroundColor = [KLTheme background];
    self.collectionView.dataSource = self;
    self.collectionView.delegate = self;
    self.collectionView.alwaysBounceVertical = YES;
    [self.collectionView registerClass:[KLAnimeCardCell class] forCellWithReuseIdentifier:@"card"];
    [self.view addSubview:self.collectionView];

    self.refreshControl = [[UIRefreshControl alloc] init];
    self.refreshControl.tintColor = [KLTheme accent];
    [self.refreshControl addTarget:self action:@selector(refresh) forControlEvents:UIControlEventValueChanged];
    [self.collectionView addSubview:self.refreshControl];

    self.spinner = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleGray];
    self.spinner.center = CGPointMake(self.view.bounds.size.width / 2, 160);
    [self.view addSubview:self.spinner];

    self.emptyLabel = [KLComponents label:[KLTheme font:13] color:[KLTheme textSecondary]];
    self.emptyLabel.textAlignment = NSTextAlignmentCenter;
    self.emptyLabel.numberOfLines = 0;
    self.emptyLabel.frame = CGRectMake(30, 120, self.view.bounds.size.width - 60, 60);
    self.emptyLabel.hidden = YES;
    [self.view addSubview:self.emptyLabel];

    NSInteger nsWeekday = [[NSCalendar currentCalendar] component:NSCalendarUnitWeekday fromDate:[NSDate date]];
    self.selectedDay = (NSInteger)(((nsWeekday + 5) % 7) + 1) - 1;

    [self buildWeekdayButtons];
    [self loadCalendar];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    self.navigationController.navigationBarHidden = NO;
}

- (void)segmentChanged {
    self.timelineMode = self.segmented.selectedSegmentIndex == 0;
    self.weekdayBar.hidden = !self.timelineMode;
    self.collectionView.frame = CGRectMake(0, self.timelineMode ? 38 : 0,
                                          self.view.bounds.size.width,
                                          self.view.bounds.size.height - (self.timelineMode ? 38 : 0));
    if (self.timelineMode) {
        if (self.days.count == 0) [self loadCalendar];
        else [self reloadCurrent];
    } else {
        if (self.popular.count == 0) [self loadPopular:YES];
        else [self.collectionView reloadData];
    }
}

- (void)refresh {
    if (self.timelineMode) [self loadCalendar];
    else [self loadPopular:YES];
}

- (void)buildWeekdayButtons {
    for (UIView *v in self.weekdayBar.subviews) [v removeFromSuperview];
    NSArray *names = @[@"周一", @"周二", @"周三", @"周四", @"周五", @"周六", @"周日"];
    CGFloat width = self.view.bounds.size.width / 7.0;
    for (NSInteger i = 0; i < 7; i++) {
        UIButton *b = [UIButton buttonWithType:UIButtonTypeCustom];
        b.frame = CGRectMake(i * width, 0, width, 38);
        b.titleLabel.font = [KLTheme mediumFont:12];
        [b setTitle:names[i] forState:UIControlStateNormal];
        b.tag = i;
        [b addTarget:self action:@selector(daySelected:) forControlEvents:UIControlEventTouchUpInside];
        [self.weekdayBar addSubview:b];
    }
    [self updateWeekdayButtons];
}

- (void)updateWeekdayButtons {
    for (UIButton *b in self.weekdayBar.subviews) {
        if (![b isKindOfClass:[UIButton class]]) continue;
        BOOL selected = b.tag == self.selectedDay;
        [b setTitleColor:selected ? [KLTheme accent] : [KLTheme textSecondary] forState:UIControlStateNormal];
        b.titleLabel.font = selected ? [KLTheme boldFont:12] : [KLTheme mediumFont:12];
        UIView *indicator = [b viewWithTag:999];
        if (selected) {
            if (!indicator) {
                indicator = [[UIView alloc] initWithFrame:CGRectMake(b.bounds.size.width / 2 - 10, 32, 20, 3)];
                indicator.backgroundColor = [KLTheme accent];
                indicator.layer.cornerRadius = 1.5;
                indicator.tag = 999;
                [b addSubview:indicator];
            }
            indicator.hidden = NO;
        } else {
            indicator.hidden = YES;
        }
    }
}

- (void)daySelected:(UIButton *)sender {
    self.selectedDay = sender.tag;
    [self updateWeekdayButtons];
    [self reloadCurrent];
}

- (void)loadCalendar {
    if (self.loading) return;
    self.loading = YES;
    self.emptyLabel.hidden = YES;
    [self.spinner startAnimating];
    __weak typeof(self) weakSelf = self;
    [[KLBangumiAPI shared] calendar:^(NSArray *days, NSError *error) {
        __strong typeof(weakSelf) strongSelf = weakSelf;
        if (!strongSelf) return;
        strongSelf.loading = NO;
        [strongSelf.spinner stopAnimating];
        [strongSelf.refreshControl endRefreshing];
        if (days.count == 7) {
            strongSelf.days = days;
            [strongSelf reloadCurrent];
        } else {
            strongSelf.emptyLabel.text = error.localizedDescription ?: @"时间表加载失败，请检查网络或切换 Bangumi 线路";
            strongSelf.emptyLabel.hidden = NO;
            [strongSelf.collectionView reloadData];
        }
    }];
}

- (void)loadPopular:(BOOL)reset {
    if (self.loading || self.loadingMore) return;
    if (reset) {
        self.loading = YES;
        self.popularOffset = 0;
        [self.popular removeAllObjects];
        [self.collectionView reloadData];
        [self.spinner startAnimating];
    } else {
        self.loadingMore = YES;
    }
    self.emptyLabel.hidden = YES;
    __weak typeof(self) weakSelf = self;
    [[KLBangumiAPI shared] trendingWithLimit:24 offset:self.popularOffset completion:^(NSArray *items, NSError *error) {
        __strong typeof(weakSelf) strongSelf = weakSelf;
        if (!strongSelf) return;
        strongSelf.loading = NO;
        strongSelf.loadingMore = NO;
        [strongSelf.spinner stopAnimating];
        [strongSelf.refreshControl endRefreshing];
        if (items.count) {
            [strongSelf.popular addObjectsFromArray:items];
            strongSelf.popularOffset += items.count;
            [strongSelf.collectionView reloadData];
        } else if (strongSelf.popular.count == 0) {
            NSString *msg = error.localizedDescription ?: @"热门番剧加载失败";
            if ([error.domain isEqualToString:NSURLErrorDomain] && error.code == NSURLErrorTimedOut) {
                msg = @"请求超时，请检查网络或在“我的 → Bangumi 线路”切换镜像后重试";
            }
            strongSelf.emptyLabel.text = msg;
            strongSelf.emptyLabel.hidden = NO;
            [strongSelf.collectionView reloadData];
        }
    }];
}

- (void)reloadCurrent {
    [self updateWeekdayButtons];
    [self.collectionView reloadData];
    self.emptyLabel.hidden = self.currentItems.count > 0;
    if (self.currentItems.count == 0) self.emptyLabel.text = @"这一天还没有番剧";
}

- (NSArray *)currentItems {
    if (self.timelineMode) {
        if (self.selectedDay >= 0 && self.selectedDay < (NSInteger)self.days.count) return self.days[self.selectedDay];
        return @[];
    }
    return self.popular;
}

#pragma mark - Collection

- (NSInteger)collectionView:(UICollectionView *)collectionView numberOfItemsInSection:(NSInteger)section {
    return [self currentItems].count;
}

- (CGSize)collectionView:(UICollectionView *)collectionView layout:(UICollectionViewLayout *)collectionViewLayout sizeForItemAtIndexPath:(NSIndexPath *)indexPath {
    CGFloat width = (collectionView.bounds.size.width - 28 - 16) / 3.0;
    return CGSizeMake(floor(width), floor(width * 1.38) + 38);
}

- (UICollectionViewCell *)collectionView:(UICollectionView *)collectionView cellForItemAtIndexPath:(NSIndexPath *)indexPath {
    KLAnimeCardCell *cell = [collectionView dequeueReusableCellWithReuseIdentifier:@"card" forIndexPath:indexPath];
    NSArray *items = [self currentItems];
    if (indexPath.item < (NSInteger)items.count) [cell configureWithItem:items[indexPath.item]];
    return cell;
}

- (void)collectionView:(UICollectionView *)collectionView didSelectItemAtIndexPath:(NSIndexPath *)indexPath {
    NSArray *items = [self currentItems];
    if (indexPath.item >= (NSInteger)items.count) return;
    KLBangumiItem *item = items[indexPath.item];
    KLDetailViewController *detail = [[KLDetailViewController alloc] initWithBangumi:item];
    [self.navigationController pushViewController:detail animated:YES];
}

- (void)scrollViewDidScroll:(UIScrollView *)scrollView {
    if (self.timelineMode || self.loading || self.loadingMore) return;
    if (scrollView.contentOffset.y + scrollView.bounds.size.height > scrollView.contentSize.height - 300) {
        [self loadPopular:NO];
    }
}

@end
