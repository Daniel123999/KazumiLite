#import "KLDownloadsViewController.h"
#import "KLTheme.h"
#import "KLComponents.h"
#import "KLDownloadManager.h"
#import "KLPlayerViewController.h"

@interface KLDownloadsViewController () <UITableViewDataSource, UITableViewDelegate>
@property (nonatomic, strong) UITableView *tableView;
@property (nonatomic, strong) NSArray *items;
@property (nonatomic, strong) UILabel *emptyLabel;
@end

@implementation KLDownloadsViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = @"下载管理";
    self.view.backgroundColor = [KLTheme background];

    self.tableView = [[UITableView alloc] initWithFrame:self.view.bounds style:UITableViewStylePlain];
    self.tableView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    self.tableView.dataSource = self;
    self.tableView.delegate = self;
    self.tableView.rowHeight = 78;
    [KLTheme styleTableView:self.tableView];
    [self.view addSubview:self.tableView];

    self.emptyLabel = [KLComponents label:[KLTheme font:12] color:[KLTheme textSecondary]];
    self.emptyLabel.text = @"没有下载任务\n在剧集页右上角「下载」离线缓存";
    self.emptyLabel.textAlignment = NSTextAlignmentCenter;
    self.emptyLabel.numberOfLines = 0;
    self.emptyLabel.frame = CGRectMake(30, 160, self.view.bounds.size.width - 60, 60);
    [self.view addSubview:self.emptyLabel];

    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(reload) name:@"KLDownloadsDidChange" object:nil];
    [self reload];
}

- (void)dealloc { [[NSNotificationCenter defaultCenter] removeObserver:self]; }

- (void)reload {
    self.items = [[KLDownloadManager shared] entries];
    [self.tableView reloadData];
    self.emptyLabel.hidden = self.items.count > 0;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section { return self.items.count; }

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    KLDownloadEntry *entry = self.items[indexPath.row];
    UITableViewCell *cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:nil];
    cell.backgroundColor = [KLTheme card];
    cell.textLabel.text = entry.title;
    cell.textLabel.font = [KLTheme mediumFont:13];
    cell.textLabel.textColor = [KLTheme textPrimary];
    cell.detailTextLabel.text = [NSString stringWithFormat:@"%@ · %@", entry.episodeTitle, [entry statusText]];
    cell.detailTextLabel.font = [KLTheme font:10];
    cell.detailTextLabel.textColor = entry.status == KLDownloadStatusCompleted ? [KLTheme success] : [KLTheme textSecondary];

    UIProgressView *progress = [[UIProgressView alloc] initWithProgressViewStyle:UIProgressViewStyleDefault];
    progress.frame = CGRectMake(0, 0, 110, 3);
    progress.progressTintColor = [KLTheme accent];
    progress.trackTintColor = [KLTheme separator];
    progress.progress = entry.progress;
    cell.accessoryView = entry.status == KLDownloadStatusDownloading ? progress : nil;
    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    KLDownloadEntry *entry = self.items[indexPath.row];
    if (entry.status != KLDownloadStatusCompleted) {
        [KLTheme showToast:[entry statusText] inView:self.view];
        return;
    }
    NSString *absolute = [[KLDownloadManager shared] absolutePathForEntry:entry];
    if (![[NSFileManager defaultManager] fileExistsAtPath:absolute]) {
        [KLTheme showToast:@"本地文件不存在" inView:self.view];
        return;
    }
    KLRule *rule = [KLRule fromDictionary:@{@"name": entry.ruleName.length ? entry.ruleName : @"本地", @"baseURL": @"", @"useNativePlayer": @YES}];
    KLRoad *road = [[KLRoad alloc] init];
    road.name = @"本地缓存";
    road.urls = @[[@"file://" stringByAppendingString:absolute]];
    road.identifiers = @[entry.episodeTitle ?: @""];
    KLPlayerViewController *player = [[KLPlayerViewController alloc] initWithBangumi:entry.bangumi rule:rule road:road roadIndex:0 episodeIndex:0 episodeTitle:entry.episodeTitle];
    player.modalPresentationStyle = UIModalPresentationFullScreen;
    [self presentViewController:player animated:YES completion:nil];
}

- (NSArray *)tableView:(UITableView *)tableView editActionsForRowAtIndexPath:(NSIndexPath *)indexPath {
    KLDownloadEntry *entry = self.items[indexPath.row];
    UITableViewRowAction *del = [UITableViewRowAction rowActionWithStyle:UITableViewRowActionStyleDestructive title:@"删除" handler:^(UITableViewRowAction *action, NSIndexPath *ip) {
        [[KLDownloadManager shared] removeEntry:entry];
        [self reload];
    }];
    return @[del];
}

@end
