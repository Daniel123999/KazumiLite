#import "KLHistoryViewController.h"
#import "KLTheme.h"
#import "KLComponents.h"
#import "KLStore.h"
#import "KLImageLoader.h"
#import "KLPlayerViewController.h"

@interface KLHistoryCell : UITableViewCell
@property (nonatomic, strong) KLAsyncImageView *coverView;
@property (nonatomic, strong) UILabel *titleLabel;
@property (nonatomic, strong) UILabel *episodeLabel;
@property (nonatomic, strong) UILabel *timeLabel;
@property (nonatomic, strong) UIView *progressTrack;
@property (nonatomic, strong) UIView *progressBar;
- (void)configureWithEntry:(KLHistoryEntry *)entry;
@end

@implementation KLHistoryCell
- (instancetype)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier {
    self = [super initWithStyle:style reuseIdentifier:reuseIdentifier];
    if (self) {
        self.backgroundColor = [KLTheme card];
        _coverView = [[KLAsyncImageView alloc] initWithFrame:CGRectMake(12, 8, 42, 58)];
        _coverView.layer.cornerRadius = 5;
        _coverView.clipsToBounds = YES;
        [self.contentView addSubview:_coverView];
        _titleLabel = [KLComponents label:[KLTheme mediumFont:13] color:[KLTheme textPrimary]];
        _titleLabel.frame = CGRectMake(64, 8, self.contentView.bounds.size.width - 78, 20);
        _titleLabel.autoresizingMask = UIViewAutoresizingFlexibleWidth;
        [self.contentView addSubview:_titleLabel];
        _episodeLabel = [KLComponents label:[KLTheme font:11] color:[KLTheme textSecondary]];
        _episodeLabel.frame = CGRectMake(64, 28, self.contentView.bounds.size.width - 78, 16);
        _episodeLabel.autoresizingMask = UIViewAutoresizingFlexibleWidth;
        [self.contentView addSubview:_episodeLabel];
        _timeLabel = [KLComponents label:[KLTheme font:10] color:[KLTheme textTertiary]];
        _timeLabel.frame = CGRectMake(64, 62, self.contentView.bounds.size.width - 78, 14);
        _timeLabel.autoresizingMask = UIViewAutoresizingFlexibleWidth;
        [self.contentView addSubview:_timeLabel];
        _progressTrack = [[UIView alloc] initWithFrame:CGRectMake(64, 50, self.contentView.bounds.size.width - 78, 3)];
        _progressTrack.backgroundColor = [KLTheme separator];
        _progressTrack.layer.cornerRadius = 1.5;
        _progressTrack.autoresizingMask = UIViewAutoresizingFlexibleWidth;
        [self.contentView addSubview:_progressTrack];
        _progressBar = [[UIView alloc] initWithFrame:_progressTrack.bounds];
        _progressBar.backgroundColor = [KLTheme accent];
        _progressBar.layer.cornerRadius = 1.5;
        [_progressTrack addSubview:_progressBar];
    }
    return self;
}
- (void)configureWithEntry:(KLHistoryEntry *)entry {
    self.coverView.imageURL = entry.bangumi.imageCommon.length ? entry.bangumi.imageCommon : entry.bangumi.imageLarge;
    self.titleLabel.text = [entry.bangumi displayName];
    self.episodeLabel.text = [NSString stringWithFormat:@"%@ · %@", entry.ruleName.length ? entry.ruleName : @"视频源", entry.episodeTitle.length ? entry.episodeTitle : [NSString stringWithFormat:@"第 %ld 集", (long)entry.episodeNumber]];
    double ratio = entry.duration > 0 ? entry.position / entry.duration : 0;
    self.progressBar.frame = CGRectMake(0, 0, self.progressTrack.bounds.size.width * MAX(0, MIN(1, ratio)), 3);
    self.timeLabel.text = [NSString stringWithFormat:@"看到 %@ / %@ · %@", [KLComponents formatDuration:entry.position], [KLComponents formatDuration:entry.duration], [KLComponents relativeTime:entry.updatedAt]];
}
- (void)prepareForReuse {
    [super prepareForReuse];
    [self.coverView cancelLoading];
    self.coverView.image = nil;
}
@end

@interface KLHistoryViewController () <UITableViewDataSource, UITableViewDelegate>
@property (nonatomic, strong) UITableView *tableView;
@property (nonatomic, strong) NSArray *items;
@property (nonatomic, strong) UILabel *emptyLabel;
@end

@implementation KLHistoryViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = @"观看历史";
    self.view.backgroundColor = [KLTheme background];
    self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithTitle:@"清空" style:UIBarButtonItemStylePlain target:self action:@selector(clearAll)];

    self.tableView = [[UITableView alloc] initWithFrame:self.view.bounds style:UITableViewStylePlain];
    self.tableView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    self.tableView.dataSource = self;
    self.tableView.delegate = self;
    self.tableView.rowHeight = 76;
    [KLTheme styleTableView:self.tableView];
    [self.view addSubview:self.tableView];

    self.emptyLabel = [KLComponents label:[KLTheme font:12] color:[KLTheme textSecondary]];
    self.emptyLabel.text = @"还没有观看记录";
    self.emptyLabel.textAlignment = NSTextAlignmentCenter;
    self.emptyLabel.frame = CGRectMake(20, 160, self.view.bounds.size.width - 40, 30);
    [self.view addSubview:self.emptyLabel];

    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(reload) name:KLStoreDidChangeNotification object:nil];
    [self reload];
}

- (void)dealloc { [[NSNotificationCenter defaultCenter] removeObserver:self]; }

- (void)reload {
    self.items = [[KLStore shared] history];
    [self.tableView reloadData];
    self.emptyLabel.hidden = self.items.count > 0;
}

- (void)clearAll {
    UIAlertController *ac = [UIAlertController alertControllerWithTitle:@"清空观看历史？" message:nil preferredStyle:UIAlertControllerStyleAlert];
    [ac addAction:[UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:nil]];
    [ac addAction:[UIAlertAction actionWithTitle:@"清空" style:UIAlertActionStyleDestructive handler:^(UIAlertAction *a) {
        [[KLStore shared] clearHistory];
        [self reload];
    }]];
    [self presentViewController:ac animated:YES completion:nil];
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section { return self.items.count; }

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    KLHistoryCell *cell = [tableView dequeueReusableCellWithIdentifier:@"history"];
    if (!cell) cell = [[KLHistoryCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:@"history"];
    [cell configureWithEntry:self.items[indexPath.row]];
    cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    [self resumeEntry:self.items[indexPath.row]];
}

- (void)resumeEntry:(KLHistoryEntry *)entry {
    KLRule *rule = nil;
    for (KLRule *r in [[KLStore shared] allRules]) if ([r.name isEqualToString:entry.ruleName]) { rule = r; break; }
    if (!rule) {
        rule = [KLRule fromDictionary:@{@"name": entry.ruleName.length ? entry.ruleName : @"历史", @"baseURL": entry.episodePageURL ?: @"", @"useNativePlayer": @YES}];
    }
    KLRoad *road = [[KLRoad alloc] init];
    road.name = entry.roadName.length ? entry.roadName : @"播放线路";
    road.urls = entry.roadURLs.count ? entry.roadURLs : (entry.episodePageURL.length ? @[entry.episodePageURL] : @[]);
    road.identifiers = entry.roadIdentifiers ?: @[];
    if (road.urls.count == 0) {
        [KLTheme showToast:@"该记录缺少播放地址" inView:self.view];
        return;
    }
    NSInteger index = MAX(0, MIN((NSInteger)road.urls.count - 1, entry.episodeNumber - 1));
    NSString *title = index < (NSInteger)road.identifiers.count ? road.identifiers[index] : entry.episodeTitle;
    KLPlayerViewController *player = [[KLPlayerViewController alloc] initWithBangumi:entry.bangumi rule:rule road:road roadIndex:entry.roadIndex episodeIndex:index episodeTitle:title];
    player.initialPosition = entry.position;
    player.modalPresentationStyle = UIModalPresentationFullScreen;
    [self presentViewController:player animated:YES completion:nil];
}

- (NSArray *)tableView:(UITableView *)tableView editActionsForRowAtIndexPath:(NSIndexPath *)indexPath {
    KLHistoryEntry *entry = self.items[indexPath.row];
    UITableViewRowAction *del = [UITableViewRowAction rowActionWithStyle:UITableViewRowActionStyleDestructive title:@"删除" handler:^(UITableViewRowAction *action, NSIndexPath *ip) {
        [[KLStore shared] removeHistoryForBangumi:entry.bangumi.bid ruleName:entry.ruleName episode:entry.episodeNumber];
        [self reload];
    }];
    return @[del];
}

@end
