#import "KLSourcePickerViewController.h"
#import "KLTheme.h"
#import "KLComponents.h"
#import "KLStore.h"
#import "KLRuleEngine.h"
#import "KLSourceViewController.h"
#import "KLWebViewController.h"
#import "KLRulesViewController.h"

@interface KLSourcePickerViewController () <UITableViewDataSource, UITableViewDelegate>
@property (nonatomic, strong) KLBangumiItem *item;
@property (nonatomic, strong) UITableView *tableView;
@property (nonatomic, strong) NSArray *rules;
@property (nonatomic, strong) UILabel *headerLabel;
@property (nonatomic, strong) UIActivityIndicatorView *spinner;
@property (nonatomic, strong) NSURLSessionDataTask *task;
@end

@implementation KLSourcePickerViewController

- (instancetype)initWithBangumi:(KLBangumiItem *)item {
    self = [super init];
    if (self) _item = item;
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = @"选择播放源";
    self.view.backgroundColor = [KLTheme background];
    self.rules = [[KLStore shared] enabledRules];

    self.tableView = [[UITableView alloc] initWithFrame:self.view.bounds style:UITableViewStyleGrouped];
    self.tableView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    self.tableView.dataSource = self;
    self.tableView.delegate = self;
    [KLTheme styleTableView:self.tableView];
    [self.view addSubview:self.tableView];

    self.headerLabel = [KLComponents label:[KLTheme font:12] color:[KLTheme textSecondary]];
    self.headerLabel.numberOfLines = 0;
    self.headerLabel.text = [NSString stringWithFormat:@"为《%@》选择规则源。规则可导入/编辑，搜索失败时可手动粘贴播放页链接。", [self.item displayName]];
    self.headerLabel.textAlignment = NSTextAlignmentCenter;

    self.spinner = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleWhiteLarge];
    self.spinner.color = [KLTheme accent];

    self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithTitle:@"手动" style:UIBarButtonItemStylePlain target:self action:@selector(manualInput)];
}

- (void)manualInput {
    UIAlertController *ac = [UIAlertController alertControllerWithTitle:@"手动输入播放页" message:@"粘贴视频源的剧集页面链接，将直接用内置播放器解析" preferredStyle:UIAlertControllerStyleAlert];
    [ac addTextFieldWithConfigurationHandler:^(UITextField *tf) {
        tf.placeholder = @"https://…";
        tf.text = [[UIPasteboard generalPasteboard] string];
        tf.keyboardType = UIKeyboardTypeURL;
    }];
    [ac addAction:[UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:nil]];
    [ac addAction:[UIAlertAction actionWithTitle:@"解析" style:UIAlertActionStyleDefault handler:^(UIAlertAction *a) {
        NSString *url = ac.textFields.firstObject.text;
        if (url.length < 8) return;
        KLSearchItem *item = [[KLSearchItem alloc] init];
        item.name = [self.item displayName];
        item.src = url;
        item.ruleName = @"手动链接";
        KLRule *rule = [KLRule fromDictionary:@{@"name": @"手动链接", @"baseURL": url, @"useNativePlayer": @YES}];
        KLSourceViewController *vc = [[KLSourceViewController alloc] initWithBangumi:self.item rule:rule source:item];
        vc.initialEpisode = self.initialEpisode;
        [self.navigationController pushViewController:vc animated:YES];
    }]];
    [self presentViewController:ac animated:YES completion:nil];
}

- (void)searchWithRule:(KLRule *)rule {
    if (self.task) [self.task cancel];
    [KLComponents showHUD:[NSString stringWithFormat:@"正在搜索 %@…", rule.name] inView:self.view];
    __weak typeof(self) weakSelf = self;
    [[KLRuleEngine shared] searchWithRule:rule keyword:[self.item displayName] completion:^(NSArray *items, NSError *error) {
        __strong typeof(weakSelf) strongSelf = weakSelf;
        if (!strongSelf) return;
        [KLComponents hideHUDInView:strongSelf.view];
        if (items.count == 0) {
            NSString *message = error.localizedDescription ?: @"没有搜索结果";
            UIAlertController *ac = [UIAlertController alertControllerWithTitle:rule.name message:message preferredStyle:UIAlertControllerStyleAlert];
            [ac addAction:[UIAlertAction actionWithTitle:@"重试" style:UIAlertActionStyleDefault handler:^(UIAlertAction *a) { [strongSelf searchWithRule:rule]; }]];
            [ac addAction:[UIAlertAction actionWithTitle:@"手动输入" style:UIAlertActionStyleDefault handler:^(UIAlertAction *a) { [strongSelf manualInput]; }]];
            [ac addAction:[UIAlertAction actionWithTitle:@"关闭" style:UIAlertActionStyleCancel handler:nil]];
            [strongSelf presentViewController:ac animated:YES completion:nil];
            return;
        }
        if (items.count == 1) {
            [strongSelf openItem:items.firstObject rule:rule];
            return;
        }
        UIAlertController *ac = [UIAlertController alertControllerWithTitle:[NSString stringWithFormat:@"%@ · 选择条目", rule.name] message:nil preferredStyle:UIAlertControllerStyleActionSheet];
        NSInteger limit = MIN((NSInteger)items.count, 12);
        for (NSInteger i = 0; i < limit; i++) {
            KLSearchItem *si = items[i];
            [ac addAction:[UIAlertAction actionWithTitle:si.name style:UIAlertActionStyleDefault handler:^(UIAlertAction *a) {
                [strongSelf openItem:si rule:rule];
            }]];
        }
        [ac addAction:[UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:nil]];
        [strongSelf presentViewController:ac animated:YES completion:nil];
    }];
}

- (void)openItem:(KLSearchItem *)item rule:(KLRule *)rule {
    KLSourceViewController *vc = [[KLSourceViewController alloc] initWithBangumi:self.item rule:rule source:item];
    vc.initialEpisode = self.initialEpisode;
    [self.navigationController pushViewController:vc animated:YES];
}

#pragma mark - Table

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView { return 2; }
- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return section == 0 ? 1 : self.rules.count;
}
- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    return section == 0 ? nil : @"已启用规则";
}
- (UIView *)tableView:(UITableView *)tableView viewForHeaderInSection:(NSInteger)section {
    if (section == 0) {
        UIView *v = [[UIView alloc] initWithFrame:CGRectMake(0, 0, tableView.bounds.size.width, 60)];
        self.headerLabel.frame = CGRectMake(16, 8, tableView.bounds.size.width - 32, 48);
        [v addSubview:self.headerLabel];
        return v;
    }
    return nil;
}
- (CGFloat)tableView:(UITableView *)tableView heightForHeaderInSection:(NSInteger)section { return section == 0 ? 64 : 28; }

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:nil];
    cell.backgroundColor = [KLTheme card];
    cell.textLabel.textColor = [KLTheme textPrimary];
    cell.detailTextLabel.textColor = [KLTheme textSecondary];
    if (indexPath.section == 0) {
        cell.textLabel.text = @"规则商店 / 管理规则";
        cell.textLabel.font = [KLTheme mediumFont:14];
        cell.detailTextLabel.text = [NSString stringWithFormat:@"已启用 %lu 个规则，可在线更新与编辑", (unsigned long)self.rules.count];
        cell.detailTextLabel.font = [KLTheme font:11];
        cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
        cell.imageView.image = [KLComponents icon:KLIconList size:20 color:[KLTheme accent]];
    } else {
        KLRule *rule = self.rules[indexPath.row];
        cell.textLabel.text = rule.name;
        cell.textLabel.font = [KLTheme mediumFont:14];
        cell.detailTextLabel.text = [NSString stringWithFormat:@"v%@ · %@ · %@", rule.version.length ? rule.version : @"?", [rule isAPISearch] ? @"API" : @"XPath", rule.useNativePlayer ? @"内置播放器" : @"网页播放"];
        cell.detailTextLabel.font = [KLTheme font:10];
        cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
    }
    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    if (indexPath.section == 0) {
        [self.navigationController pushViewController:[[KLRulesViewController alloc] init] animated:YES];
        return;
    }
    [self searchWithRule:self.rules[indexPath.row]];
}

@end
