#import "KLSearchViewController.h"
#import "KLTheme.h"
#import "KLComponents.h"
#import "KLImageLoader.h"
#import "KLBangumiAPI.h"
#import "KLStore.h"
#import "KLRuleEngine.h"
#import "KLDetailViewController.h"
#import "KLSourceViewController.h"
#import "KLImageSearchViewController.h"

@interface KLSearchViewController () <UISearchBarDelegate, UITableViewDataSource, UITableViewDelegate>
@property (nonatomic, strong) UISearchBar *searchBar;
@property (nonatomic, strong) UISegmentedControl *segmented;
@property (nonatomic, strong) UITableView *tableView;
@property (nonatomic, strong) NSMutableArray *results;
@property (nonatomic, strong) NSArray *recent;
@property (nonatomic, assign) NSInteger mode; // 0 bangumi, 1 rules
@property (nonatomic, assign) BOOL loading;
@property (nonatomic, strong) NSURLSessionDataTask *searchTask;
@property (nonatomic, copy) NSString *keyword;
@property (nonatomic, strong) UILabel *hintLabel;
@end

@implementation KLSearchViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = @"发现";
    self.view.backgroundColor = [KLTheme background];
    self.results = [NSMutableArray array];
    self.mode = 0;
    self.recent = [[KLStore shared] objectForKey:@"searchHistory"] ?: @[];

    self.searchBar = [[UISearchBar alloc] initWithFrame:CGRectMake(0, 0, self.view.bounds.size.width, 44)];
    self.searchBar.placeholder = @"搜索番剧 / 输入关键词";
    self.searchBar.delegate = self;
    self.searchBar.searchBarStyle = UISearchBarStyleMinimal;
    self.searchBar.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    [self.view addSubview:self.searchBar];

    self.segmented = [[UISegmentedControl alloc] initWithItems:@[@"番剧", @"视频源"]];
    self.segmented.selectedSegmentIndex = 0;
    self.segmented.tintColor = [KLTheme accent];
    self.segmented.frame = CGRectMake(14, 48, self.view.bounds.size.width - 28, 30);
    self.segmented.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    [self.segmented addTarget:self action:@selector(modeChanged) forControlEvents:UIControlEventValueChanged];
    [self.view addSubview:self.segmented];

    self.tableView = [[UITableView alloc] initWithFrame:CGRectMake(0, 86, self.view.bounds.size.width, self.view.bounds.size.height - 86) style:UITableViewStylePlain];
    self.tableView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    self.tableView.dataSource = self;
    self.tableView.delegate = self;
    self.tableView.rowHeight = 78;
    [KLTheme styleTableView:self.tableView];
    [self.view addSubview:self.tableView];

    self.hintLabel = [KLComponents label:[KLTheme font:12] color:[KLTheme textSecondary]];
    self.hintLabel.textAlignment = NSTextAlignmentCenter;
    self.hintLabel.numberOfLines = 0;
    self.hintLabel.frame = CGRectMake(30, 180, self.view.bounds.size.width - 60, 60);
    self.hintLabel.text = @"输入关键词开始搜索\n视频源模式会同时调用所有已启用规则";
    [self.view addSubview:self.hintLabel];

    self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithImage:[KLComponents icon:KLIconCamera size:20 color:[KLTheme textPrimary]] style:UIBarButtonItemStylePlain target:self action:@selector(openImageSearch)];
}

- (void)openImageSearch {
    [self.navigationController pushViewController:[[KLImageSearchViewController alloc] init] animated:YES];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    self.navigationController.navigationBarHidden = NO;
    self.recent = [[KLStore shared] objectForKey:@"searchHistory"] ?: @[];
    if (self.results.count == 0) [self.tableView reloadData];
}

- (void)modeChanged {
    self.mode = self.segmented.selectedSegmentIndex;
    self.hintLabel.text = self.mode == 0 ? @"输入关键词搜索 Bangumi 番剧" : @"同时调用所有已启用规则搜索视频源";
    [self.results removeAllObjects];
    [self.tableView reloadData];
    if (self.keyword.length) [self performSearch:self.keyword];
}

- (void)searchBarSearchButtonClicked:(UISearchBar *)searchBar {
    [searchBar resignFirstResponder];
    NSString *kw = [searchBar.text stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    if (kw.length == 0) return;
    [self saveRecent:kw];
    [self performSearch:kw];
}

- (void)searchBar:(UISearchBar *)searchBar textDidChange:(NSString *)searchText {
    if (searchText.length == 0) {
        [self.results removeAllObjects];
        [self.tableView reloadData];
        self.hintLabel.hidden = NO;
    }
}

- (void)saveRecent:(NSString *)keyword {
    NSMutableArray *list = [NSMutableArray arrayWithArray:self.recent ?: @[]];
    [list removeObject:keyword];
    [list insertObject:keyword atIndex:0];
    while (list.count > 10) [list removeLastObject];
    self.recent = list;
    [[KLStore shared] setObject:list forKey:@"searchHistory"];
}

- (void)performSearch:(NSString *)keyword {
    self.keyword = keyword;
    self.hintLabel.hidden = YES;
    if (self.searchTask) [self.searchTask cancel];
    self.loading = YES;
    [self.results removeAllObjects];
    [self.tableView reloadData];
    [KLComponents showHUD:self.mode == 0 ? @"搜索中…" : @"正在调用规则…" inView:self.view];

    if (self.mode == 0) {
        __weak typeof(self) weakSelf = self;
        [[KLBangumiAPI shared] search:keyword limit:20 offset:0 completion:^(NSArray *items, NSInteger rawCount, NSError *error) {
            __strong typeof(weakSelf) strongSelf = weakSelf;
            if (!strongSelf) return;
            strongSelf.loading = NO;
            [KLComponents hideHUDInView:strongSelf.view];
            [strongSelf.results addObjectsFromArray:items ?: @[]];
            [strongSelf.tableView reloadData];
            if (strongSelf.results.count == 0) {
                NSString *msg = error.localizedDescription ?: @"没有找到番剧";
                if ([error.domain isEqualToString:NSURLErrorDomain] && error.code == NSURLErrorTimedOut) {
                    msg = @"请求超时，请检查网络或切换 Bangumi 线路后重试";
                }
                strongSelf.hintLabel.text = msg;
                strongSelf.hintLabel.hidden = NO;
            }
        }];
    } else {
        [self searchRules:keyword];
    }
}

- (void)searchRules:(NSString *)keyword {
    NSArray *rules = [[KLStore shared] enabledRules];
    if (rules.count == 0) {
        [KLComponents hideHUDInView:self.view];
        self.hintLabel.text = @"没有启用的规则，请到 我的 → 规则管理 导入";
        self.hintLabel.hidden = NO;
        return;
    }
    NSMutableArray *merged = [NSMutableArray array];
    __block NSInteger pending = rules.count;
    __weak typeof(self) weakSelf = self;
    for (KLRule *rule in rules) {
        [[KLRuleEngine shared] searchWithRule:rule keyword:keyword completion:^(NSArray *items, NSError *error) {
            __strong typeof(weakSelf) strongSelf = weakSelf;
            if (!strongSelf) return;
            @synchronized (merged) {
                if (items.count) [merged addObjectsFromArray:items];
                pending--;
                if (pending <= 0) {
                    [KLComponents hideHUDInView:strongSelf.view];
                    [strongSelf.results removeAllObjects];
                    [strongSelf.results addObjectsFromArray:merged];
                    [strongSelf.tableView reloadData];
                    if (merged.count == 0) {
                        strongSelf.hintLabel.text = @"所有规则都没有结果\n可尝试切换番剧模式，或检查规则是否失效";
                        strongSelf.hintLabel.hidden = NO;
                    }
                } else {
                    [KLComponents updateHUD:[NSString stringWithFormat:@"已完成 %ld/%lu 个规则…", (long)(rules.count - pending), (unsigned long)rules.count] inView:strongSelf.view];
                }
            }
        }];
    }
}

#pragma mark - Table

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    if (self.results.count == 0) return self.recent.count;
    return self.results.count;
}

- (CGFloat)tableView:(UITableView *)tableView heightForHeaderInSection:(NSInteger)section {
    return self.results.count == 0 ? 30 : 0;
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    return self.results.count == 0 && self.recent.count ? @"最近搜索" : nil;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    if (self.results.count == 0) {
        UITableViewCell *cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:nil];
        cell.backgroundColor = [KLTheme card];
        cell.textLabel.text = self.recent[indexPath.row];
        cell.textLabel.font = [KLTheme font:13];
        cell.textLabel.textColor = [KLTheme textPrimary];
        cell.imageView.image = [KLComponents icon:KLIconSearch size:16 color:[KLTheme textTertiary]];
        return cell;
    }
    if (self.mode == 0) {
        KLAnimeListCell *cell = [tableView dequeueReusableCellWithIdentifier:@"anime"];
        if (!cell) cell = [[KLAnimeListCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:@"anime"];
        KLBangumiItem *item = self.results[indexPath.row];
        [cell configureWithItem:item];
        cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
        return cell;
    }
    UITableViewCell *cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:nil];
    cell.backgroundColor = [KLTheme card];
    cell.textLabel.textColor = [KLTheme textPrimary];
    cell.detailTextLabel.textColor = [KLTheme textSecondary];
    cell.imageView.image = nil;
    {
        KLSearchItem *item = self.results[indexPath.row];
        cell.textLabel.text = item.name;
        cell.textLabel.font = [KLTheme mediumFont:13];
        cell.detailTextLabel.text = [NSString stringWithFormat:@"来源：%@", item.ruleName];
        cell.detailTextLabel.font = [KLTheme font:10];
        cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
        cell.imageView.image = [KLComponents icon:KLIconPlay size:22 color:[KLTheme accent]];
    }
    return cell;
}

- (UIImage *)imageFromView:(UIView *)view {
    UIGraphicsBeginImageContextWithOptions(view.bounds.size, NO, 0);
    [view.layer renderInContext:UIGraphicsGetCurrentContext()];
    UIImage *image = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return image;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    if (self.results.count == 0) {
        NSString *kw = self.recent[indexPath.row];
        self.searchBar.text = kw;
        [self performSearch:kw];
        return;
    }
    if (self.mode == 0) {
        KLBangumiItem *item = self.results[indexPath.row];
        [self.navigationController pushViewController:[[KLDetailViewController alloc] initWithBangumi:item] animated:YES];
    } else {
        KLSearchItem *item = self.results[indexPath.row];
        [self openSourceItem:item];
    }
}

- (void)openSourceItem:(KLSearchItem *)item {
    [KLComponents showHUD:@"正在匹配番剧信息…" inView:self.view];
    KLRule *rule = nil;
    for (KLRule *r in [[KLStore shared] allRules]) if ([r.name isEqualToString:item.ruleName]) { rule = r; break; }
    if (!rule) {
        [KLComponents hideHUDInView:self.view];
        [KLTheme showToast:@"规则已被删除" inView:self.view];
        return;
    }
    __weak typeof(self) weakSelf = self;
    [[KLBangumiAPI shared] search:item.name limit:5 offset:0 completion:^(NSArray *items, NSInteger rawCount, NSError *error) {
        __strong typeof(weakSelf) strongSelf = weakSelf;
        if (!strongSelf) return;
        [KLComponents hideHUDInView:strongSelf.view];
        KLBangumiItem *bangumi = nil;
        for (KLBangumiItem *b in items) {
            if ([b displayName].length && ([item.name containsString:[b displayName]] || [[b displayName] containsString:item.name])) {
                bangumi = b;
                break;
            }
        }
        if (!bangumi) bangumi = items.firstObject;
        if (!bangumi) {
            bangumi = [[KLBangumiItem alloc] init];
            bangumi.name = item.name;
            bangumi.nameCn = item.name;
        }
        KLSourceViewController *vc = [[KLSourceViewController alloc] initWithBangumi:bangumi rule:rule source:item];
        [strongSelf.navigationController pushViewController:vc animated:YES];
    }];
}

@end
