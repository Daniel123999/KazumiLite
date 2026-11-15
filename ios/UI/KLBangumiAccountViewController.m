#import "KLBangumiAccountViewController.h"
#import "KLTheme.h"
#import "KLComponents.h"
#import "KLStore.h"
#import "KLBangumiAPI.h"
#import "KLWebViewController.h"

@interface KLBangumiAccountViewController () <UITableViewDataSource, UITableViewDelegate>
@property (nonatomic, strong) UITableView *tableView;
@property (nonatomic, strong) UITextField *tokenField;
@property (nonatomic, strong) UILabel *statusLabel;
@end

@implementation KLBangumiAccountViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = @"Bangumi 账号";
    self.view.backgroundColor = [KLTheme background];

    self.tableView = [[UITableView alloc] initWithFrame:self.view.bounds style:UITableViewStyleGrouped];
    self.tableView.dataSource = self;
    self.tableView.delegate = self;
    [KLTheme styleTableView:self.tableView];
    [self.view addSubview:self.tableView];

    self.tableView.tableHeaderView = [self headerView];
}

- (UIView *)headerView {
    UIView *v = [[UIView alloc] initWithFrame:CGRectMake(0, 0, self.view.bounds.size.width, 110)];
    self.statusLabel = [KLComponents label:[KLTheme mediumFont:14] color:[KLTheme textPrimary]];
    self.statusLabel.textAlignment = NSTextAlignmentCenter;
    self.statusLabel.frame = CGRectMake(16, 12, v.bounds.size.width - 32, 22);
    [v addSubview:self.statusLabel];

    NSString *username = [[KLStore shared] stringForKey:@"bangumiUsername" defaultValue:@""];
    NSString *token = [[KLStore shared] stringForKey:@"bangumiToken" defaultValue:@""];
    self.statusLabel.text = username.length ? [NSString stringWithFormat:@"已登录：%@", username] : (token.length ? @"Token 待验证" : @"未登录 Bangumi");
    self.statusLabel.textColor = username.length ? [KLTheme success] : [KLTheme textSecondary];

    UILabel *hint = [KLComponents label:[KLTheme font:11] color:[KLTheme textSecondary]];
    hint.numberOfLines = 0;
    hint.textAlignment = NSTextAlignmentCenter;
    hint.text = @"在 next.bgm.tv/demo/access-token 创建个人 Access Token，粘贴到下方即可同步追番状态。";
    hint.frame = CGRectMake(16, 38, v.bounds.size.width - 32, 48);
    [v addSubview:hint];

    UIButton *open = [KLComponents softButton:@"打开 Token 页面" target:self action:@selector(openTokenPage)];
    open.frame = CGRectMake((v.bounds.size.width - 130) / 2, 82, 130, 26);
    [v addSubview:open];
    return v;
}

- (void)openTokenPage {
    KLWebViewController *web = [[KLWebViewController alloc] initWithURL:@"https://next.bgm.tv/demo/access-token" title:@"Bangumi Token"];
    web.modalPresentationStyle = UIModalPresentationFullScreen;
    [self presentViewController:web animated:YES completion:nil];
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView { return 2; }
- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section { return section == 0 ? 1 : 3; }
- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    return section == 0 ? @"Access Token" : @"账号操作";
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:nil];
    cell.backgroundColor = [KLTheme card];
    cell.textLabel.textColor = [KLTheme textPrimary];
    if (indexPath.section == 0) {
        self.tokenField = [[UITextField alloc] initWithFrame:CGRectMake(12, 0, cell.contentView.bounds.size.width - 24, 44)];
        self.tokenField.placeholder = @"粘贴 Access Token";
        self.tokenField.font = [KLTheme font:12];
        self.tokenField.secureTextEntry = YES;
        self.tokenField.text = [[KLStore shared] stringForKey:@"bangumiToken" defaultValue:@""];
        self.tokenField.autocapitalizationType = UITextAutocapitalizationTypeNone;
        self.tokenField.autocorrectionType = UITextAutocorrectionTypeNo;
        [cell.contentView addSubview:self.tokenField];
        cell.selectionStyle = UITableViewCellSelectionStyleNone;
    } else {
        if (indexPath.row == 0) cell.textLabel.text = @"登录 / 验证 Token";
        else if (indexPath.row == 1) cell.textLabel.text = @"退出登录";
        else cell.textLabel.text = @"立即同步追番状态";
        cell.textLabel.font = [KLTheme mediumFont:14];
        cell.textLabel.textColor = indexPath.row == 1 ? [KLTheme danger] : [KLTheme textPrimary];
    }
    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    if (indexPath.section == 0) return;
    if (indexPath.row == 0) [self login];
    else if (indexPath.row == 1) [self logout];
    else [self syncNow];
}

- (void)login {
    NSString *token = [self.tokenField.text stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    if (token.length == 0) { [KLTheme showToast:@"请输入 Token" inView:self.view]; return; }
    [KLComponents showHUD:@"验证 Token…" inView:self.view];
    __weak typeof(self) weakSelf = self;
    [[KLBangumiAPI shared] validateToken:token completion:^(NSString *username, NSError *error) {
        __strong typeof(weakSelf) strongSelf = weakSelf;
        if (!strongSelf) return;
        [KLComponents hideHUDInView:strongSelf.view];
        if (username.length) {
            [[KLStore shared] setString:token forKey:@"bangumiToken"];
            [[KLStore shared] setString:username forKey:@"bangumiUsername"];
            [KLBangumiAPI shared].token = token;
            [KLBangumiAPI shared].username = username;
            strongSelf.statusLabel.text = [NSString stringWithFormat:@"已登录：%@", username];
            strongSelf.statusLabel.textColor = [KLTheme success];
            [KLTheme showToast:@"登录成功" inView:strongSelf.view];
        } else {
            [KLTheme showToast:error.localizedDescription ?: @"Token 无效" inView:strongSelf.view];
        }
    }];
}

- (void)logout {
    [[KLStore shared] setString:@"" forKey:@"bangumiToken"];
    [[KLStore shared] setString:@"" forKey:@"bangumiUsername"];
    [KLBangumiAPI shared].token = @"";
    [KLBangumiAPI shared].username = @"";
    self.tokenField.text = @"";
    self.statusLabel.text = @"未登录 Bangumi";
    self.statusLabel.textColor = [KLTheme textSecondary];
    [self.tableView reloadData];
}

- (void)syncNow {
    NSString *token = [[KLStore shared] stringForKey:@"bangumiToken" defaultValue:@""];
    NSString *username = [[KLStore shared] stringForKey:@"bangumiUsername" defaultValue:@""];
    if (token.length == 0 || username.length == 0) { [KLTheme showToast:@"请先登录" inView:self.view]; return; }
    [KLComponents showHUD:@"正在拉取追番状态…" inView:self.view];
    __weak typeof(self) weakSelf = self;
    [[KLBangumiAPI shared] userCollections:username token:token completion:^(NSArray *items, NSError *error) {
        __strong typeof(weakSelf) strongSelf = weakSelf;
        if (!strongSelf) return;
        NSInteger count = 0;
        for (KLBangumiItem *item in items) {
            KLCollectionEntry *existing = [[KLStore shared] collectionForBangumi:item.bid];
            if (!existing) {
                KLCollectionEntry *e = [[KLCollectionEntry alloc] init];
                e.bangumi = item;
                e.collectType = 1;
                [[KLStore shared] setCollection:e];
                count++;
            }
        }
        [KLComponents hideHUDInView:strongSelf.view];
        if (error) [KLTheme showToast:error.localizedDescription inView:strongSelf.view];
        else [KLTheme showToast:[NSString stringWithFormat:@"同步完成，新增 %ld 条", (long)count] inView:strongSelf.view];
    }];
}

@end
