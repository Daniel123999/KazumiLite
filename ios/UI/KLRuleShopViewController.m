#import "KLRuleShopViewController.h"
#import "KLTheme.h"
#import "KLComponents.h"
#import "KLStore.h"
#import "KLHttp.h"

@interface KLRuleShopViewController () <UITableViewDataSource, UITableViewDelegate>
@property (nonatomic, strong) UITableView *tableView;
@property (nonatomic, strong) NSArray *items;
@property (nonatomic, strong) NSMutableDictionary *installing;
@property (nonatomic, strong) UIRefreshControl *refresh;
@end

@implementation KLRuleShopViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = @"规则商店";
    self.view.backgroundColor = [KLTheme background];
    self.items = @[];
    self.installing = [NSMutableDictionary dictionary];
    self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithTitle:@"全部更新" style:UIBarButtonItemStylePlain target:self action:@selector(installAll)];

    if ([self respondsToSelector:@selector(setAutomaticallyAdjustsScrollViewInsets:)]) {
        self.automaticallyAdjustsScrollViewInsets = YES;
    }
    self.tableView = [[UITableView alloc] initWithFrame:self.view.bounds style:UITableViewStylePlain];
    self.tableView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    self.tableView.dataSource = self;
    self.tableView.delegate = self;
    self.tableView.rowHeight = 64;
    [KLTheme styleTableView:self.tableView];
    [self.view addSubview:self.tableView];

    self.refresh = [[UIRefreshControl alloc] init];
    [self.refresh addTarget:self action:@selector(loadIndex) forControlEvents:UIControlEventValueChanged];
    [self.tableView addSubview:self.refresh];

    [self loadIndex];
}

- (NSString *)mirrorBase {
    NSString *mirror = [[KLStore shared] stringForKey:@"rulesMirror" defaultValue:@"github"];
    if ([mirror isEqualToString:@"ghfast"]) return @"https://ghfast.top/https://raw.githubusercontent.com/Predidit/KazumiRules/main/";
    if ([mirror isEqualToString:@"gitcode"]) return @"https://raw.gitcode.com/gh_mirrors/ka/KazumiRules/raw/main/";
    return @"https://raw.githubusercontent.com/Predidit/KazumiRules/main/";
}

- (NSString *)mirrorName {
    NSString *mirror = [[KLStore shared] stringForKey:@"rulesMirror" defaultValue:@"github"];
    if ([mirror isEqualToString:@"ghfast"]) return @"ghfast.top";
    if ([mirror isEqualToString:@"gitcode"]) return @"GitCode";
    return @"GitHub";
}

- (void)loadIndex {
    [KLComponents showHUD:@"获取规则列表…" inView:self.view];
    NSString *url = [[self mirrorBase] stringByAppendingString:@"index.json"];
    __weak typeof(self) weakSelf = self;
    [KLHttp GET:url headers:nil completion:^(id json, NSData *data, NSHTTPURLResponse *response, NSError *error) {
        __strong typeof(weakSelf) strongSelf = weakSelf;
        if (!strongSelf) return;
        [strongSelf.refresh endRefreshing];
        [KLComponents hideHUDInView:strongSelf.view];
        if ([json isKindOfClass:[NSArray class]]) {
            strongSelf.items = json;
            [strongSelf.tableView reloadData];
            [KLTheme showToast:[NSString stringWithFormat:@"%@ · %lu 个规则", [strongSelf mirrorName], (unsigned long)strongSelf.items.count] inView:strongSelf.view];
        } else {
            UIAlertController *ac = [UIAlertController alertControllerWithTitle:@"规则商店加载失败" message:[NSString stringWithFormat:@"%@\n\n可在设置中切换规则镜像。", error.localizedDescription ?: @"网络错误"] preferredStyle:UIAlertControllerStyleAlert];
            [ac addAction:[UIAlertAction actionWithTitle:@"重试" style:UIAlertActionStyleDefault handler:^(UIAlertAction *a) { [strongSelf loadIndex]; }]];
            [ac addAction:[UIAlertAction actionWithTitle:@"关闭" style:UIAlertActionStyleCancel handler:nil]];
            [strongSelf presentViewController:ac animated:YES completion:nil];
        }
    }];
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section { return self.items.count; }

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    NSDictionary *item = self.items[indexPath.row];
    UITableViewCell *cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:nil];
    cell.backgroundColor = [KLTheme card];
    cell.textLabel.text = item[@"name"] ?: @"";
    cell.textLabel.font = [KLTheme mediumFont:14];
    cell.textLabel.textColor = [KLTheme textPrimary];
    cell.detailTextLabel.text = [NSString stringWithFormat:@"v%@ · %@%@", item[@"version"] ?: @"?", [item[@"antiCrawlerEnabled"] boolValue] ? @"需要验证 · " : @"", item[@"author"] ?: @"KazumiRules"];
    cell.detailTextLabel.font = [KLTheme font:10];
    cell.detailTextLabel.textColor = [KLTheme textSecondary];

    KLRule *installed = nil;
    NSString *itemName = [item[@"name"] isKindOfClass:[NSString class]] ? item[@"name"] : @"";
    for (KLRule *r in [[KLStore shared] allRules]) if ([r.name.lowercaseString isEqualToString:[itemName lowercaseString]]) { installed = r; break; }
    UILabel *status = [KLComponents label:[KLTheme font:10] color:[KLTheme accent]];
    if (self.installing[itemName]) {
        status.text = @"安装中…";
        status.textColor = [KLTheme warning];
    } else if (!installed) {
        status.text = @"安装";
    } else if (![installed.version isEqualToString:[item[@"version"] description]]) {
        status.text = [NSString stringWithFormat:@"可更新 %@ → %@", installed.version, item[@"version"]];
        status.textColor = [KLTheme warning];
    } else {
        status.text = @"已安装";
        status.textColor = [KLTheme success];
    }
    status.textAlignment = NSTextAlignmentRight;
    status.frame = CGRectMake(0, 0, 120, 20);
    cell.accessoryView = status;
    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    [self installItem:self.items[indexPath.row]];
}

- (void)installItem:(NSDictionary *)item {
    NSString *name = item[@"name"];
    if (!name.length) return;
    self.installing[name] = @YES;
    [self.tableView reloadData];
    NSString *url = [[self mirrorBase] stringByAppendingString:[name stringByAppendingString:@".json"]];
    __weak typeof(self) weakSelf = self;
    [KLHttp GET:url headers:nil completion:^(id json, NSData *data, NSHTTPURLResponse *response, NSError *error) {
        __strong typeof(weakSelf) strongSelf = weakSelf;
        if (!strongSelf) return;
        [strongSelf.installing removeObjectForKey:name];
        if ([json isKindOfClass:[NSDictionary class]]) {
            KLRule *rule = [KLRule fromDictionary:json];
            if (rule.name.length) {
                rule.enabled = YES;
                [[KLStore shared] saveRule:rule];
                [KLTheme showToast:[NSString stringWithFormat:@"已安装 %@ v%@", rule.name, rule.version] inView:strongSelf.view];
            }
        } else {
            [KLTheme showToast:[NSString stringWithFormat:@"%@ 下载失败", name] inView:strongSelf.view];
        }
        [strongSelf.tableView reloadData];
    }];
}

- (void)installAll {
    if (self.items.count == 0) return;
    UIAlertController *ac = [UIAlertController alertControllerWithTitle:@"安装 / 更新全部规则？" message:@"将依次下载规则仓库中的全部规则，可能耗时较长。" preferredStyle:UIAlertControllerStyleAlert];
    [ac addAction:[UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:nil]];
    [ac addAction:[UIAlertAction actionWithTitle:@"开始" style:UIAlertActionStyleDefault handler:^(UIAlertAction *a) {
        [self installSequentially:0];
    }]];
    [self presentViewController:ac animated:YES completion:nil];
}

- (void)installSequentially:(NSInteger)index {
    if (index >= (NSInteger)self.items.count) {
        [KLTheme showToast:@"全部规则已更新" inView:self.view];
        return;
    }
    NSDictionary *item = self.items[index];
    NSString *name = item[@"name"];
    self.installing[name] = @YES;
    [self.tableView reloadData];
    NSString *url = [[self mirrorBase] stringByAppendingString:[name stringByAppendingString:@".json"]];
    __weak typeof(self) weakSelf = self;
    [KLHttp GET:url headers:nil completion:^(id json, NSData *data, NSHTTPURLResponse *response, NSError *error) {
        __strong typeof(weakSelf) strongSelf = weakSelf;
        if (!strongSelf) return;
        [strongSelf.installing removeObjectForKey:name];
        if ([json isKindOfClass:[NSDictionary class]]) {
            KLRule *rule = [KLRule fromDictionary:json];
            if (rule.name.length) {
                rule.enabled = YES;
                [[KLStore shared] saveRule:rule];
            }
        }
        [strongSelf.tableView reloadData];
        [strongSelf installSequentially:index + 1];
    }];
}

@end
