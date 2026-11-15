#import "KLSettingsViewController.h"
#import "KLTheme.h"
#import "KLComponents.h"
#import "KLStore.h"
#import "KLUpdater.h"
#import "KLImageLoader.h"
#import "KLHistoryViewController.h"
#import "KLDanmakuSettingsViewController.h"
#import "KLPlaySettingsViewController.h"
#import "KLBangumiAccountViewController.h"
#import "KLWebDAVViewController.h"
#import "KLRulesViewController.h"
#import "KLRuleShopViewController.h"
#import "KLDownloadsViewController.h"
#import "KLAboutViewController.h"

@interface KLSettingsViewController () <UITableViewDataSource, UITableViewDelegate>
@property (nonatomic, strong) UITableView *tableView;
@property (nonatomic, strong) NSArray *sections;
@end

@implementation KLSettingsViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = @"我的";
    self.view.backgroundColor = [KLTheme background];

    self.sections = @[
        @[@{@"title": @"Bangumi 账号", @"sub": @"登录后同步追番状态", @"action": @"account"},
          @{@"title": @"观看历史", @"sub": @"继续上次观看", @"action": @"history"},
          @{@"title": @"WebDAV 同步", @"sub": @"历史 / 追番 / 规则备份", @"action": @"webdav"},
          @{@"title": @"下载管理", @"sub": @"离线缓存与本地文件", @"action": @"downloads"}],
        @[@{@"title": @"播放设置", @"sub": @"倍速 / 连播 / 解码", @"action": @"play"},
          @{@"title": @"弹幕设置", @"sub": @"字体 / 透明度 / 屏蔽词", @"action": @"danmaku"},
          @{@"title": @"规则管理", @"sub": @"导入与编辑 XPath / API 规则", @"action": @"rules"},
          @{@"title": @"规则商店", @"sub": @"从 KazumiRules 在线更新", @"action": @"shop"}],
        @[@{@"title": @"Bangumi 线路", @"sub": @"官方 / 镜像 / 自定义", @"action": @"bangumiMode"},
          @{@"title": @"规则镜像", @"sub": @"GitHub / ghfast / GitCode", @"action": @"rulesMirror"},
          @{@"title": @"清理图片缓存", @"sub": @"释放本地存储空间", @"action": @"clearCache"}],
        @[@{@"title": @"夜间模式", @"action": @"dark", @"switch": @"dark"},
          @{@"title": @"自动检查更新", @"action": @"autoUpdate", @"switch": @"autoUpdate"}],
        @[@{@"title": @"检查更新", @"sub": @"当前版本 1.0.0 (Build 1)", @"action": @"checkUpdate"},
          @{@"title": @"关于 Kazumi Lite", @"sub": @"GPL-3.0 · 项目说明与免责声明", @"action": @"about"}]
    ];

    self.tableView = [[UITableView alloc] initWithFrame:self.view.bounds style:UITableViewStyleGrouped];
    self.tableView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    self.tableView.dataSource = self;
    self.tableView.delegate = self;
    [KLTheme styleTableView:self.tableView];
    [self.view addSubview:self.tableView];

    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(themeChanged) name:KLThemeDidChangeNotification object:nil];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    self.navigationController.navigationBarHidden = NO;
    [self.tableView reloadData];
}

- (void)dealloc { [[NSNotificationCenter defaultCenter] removeObserver:self]; }
- (void)themeChanged { [self.tableView reloadData]; }

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView { return self.sections.count; }
- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section { return [self.sections[section] count]; }

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    NSArray *titles = @[@"账号与同步", @"播放与规则", @"网络与存储", @"通用", @"更新与关于"];
    return section < (NSInteger)titles.count ? titles[section] : nil;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    NSDictionary *row = self.sections[indexPath.section][indexPath.row];
    UITableViewCell *cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:nil];
    cell.backgroundColor = [KLTheme card];
    cell.textLabel.text = row[@"title"];
    cell.textLabel.font = [KLTheme mediumFont:14];
    cell.textLabel.textColor = [KLTheme textPrimary];
    cell.detailTextLabel.text = row[@"sub"];
    cell.detailTextLabel.font = [KLTheme font:10];
    cell.detailTextLabel.textColor = [KLTheme textSecondary];
    cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
    if (row[@"switch"]) {
        UISwitch *sw = [[UISwitch alloc] init];
        sw.onTintColor = [KLTheme accent];
        NSString *key = row[@"switch"];
        if ([key isEqualToString:@"dark"]) sw.on = [[KLTheme shared] darkMode];
        else sw.on = [[KLStore shared] boolForKey:key defaultValue:YES];
        sw.tag = indexPath.section * 100 + indexPath.row;
        [sw addTarget:self action:@selector(switchChanged:) forControlEvents:UIControlEventValueChanged];
        cell.accessoryView = sw;
        cell.selectionStyle = UITableViewCellSelectionStyleNone;
        cell.detailTextLabel.text = nil;
    } else {
        cell.accessoryView = nil;
    }
    return cell;
}

- (void)switchChanged:(UISwitch *)sw {
    NSInteger section = sw.tag / 100;
    NSInteger row = sw.tag % 100;
    NSDictionary *item = self.sections[section][row];
    if ([item[@"switch"] isEqualToString:@"dark"]) {
        [[KLTheme shared] setDarkMode:sw.on];
        [[NSNotificationCenter defaultCenter] postNotificationName:KLThemeDidChangeNotification object:nil];
        [KLTheme applyGlobalAppearance];
        [self.tableView reloadData];
    } else {
        [[KLStore shared] setBool:sw.on forKey:item[@"switch"]];
    }
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    NSDictionary *row = self.sections[indexPath.section][indexPath.row];
    NSString *action = row[@"action"];
    if ([action isEqualToString:@"account"]) [self.navigationController pushViewController:[[KLBangumiAccountViewController alloc] init] animated:YES];
    else if ([action isEqualToString:@"history"]) [self.navigationController pushViewController:[[KLHistoryViewController alloc] init] animated:YES];
    else if ([action isEqualToString:@"webdav"]) [self.navigationController pushViewController:[[KLWebDAVViewController alloc] init] animated:YES];
    else if ([action isEqualToString:@"downloads"]) [self.navigationController pushViewController:[[KLDownloadsViewController alloc] init] animated:YES];
    else if ([action isEqualToString:@"play"]) [self.navigationController pushViewController:[[KLPlaySettingsViewController alloc] init] animated:YES];
    else if ([action isEqualToString:@"danmaku"]) [self.navigationController pushViewController:[[KLDanmakuSettingsViewController alloc] init] animated:YES];
    else if ([action isEqualToString:@"rules"]) [self.navigationController pushViewController:[[KLRulesViewController alloc] init] animated:YES];
    else if ([action isEqualToString:@"shop"]) [self.navigationController pushViewController:[[KLRuleShopViewController alloc] init] animated:YES];
    else if ([action isEqualToString:@"bangumiMode"]) [self showBangumiMode];
    else if ([action isEqualToString:@"rulesMirror"]) [self showRulesMirror];
    else if ([action isEqualToString:@"clearCache"]) [self clearCache];
    else if ([action isEqualToString:@"checkUpdate"]) [self checkUpdate];
    else if ([action isEqualToString:@"about"]) [self.navigationController pushViewController:[[KLAboutViewController alloc] init] animated:YES];
}

- (void)showBangumiMode {
    NSString *mode = [[KLStore shared] stringForKey:@"bangumiMode" defaultValue:@"official"];
    UIAlertController *ac = [UIAlertController alertControllerWithTitle:@"Bangumi 线路" message:@"官方线路在部分地区可能不可达" preferredStyle:UIAlertControllerStyleActionSheet];
    [ac addAction:[UIAlertAction actionWithTitle:[mode isEqualToString:@"official"] ? @"✓ 官方 api.bgm.tv" : @"官方 api.bgm.tv" style:UIAlertActionStyleDefault handler:^(UIAlertAction *a) {
        [[KLStore shared] setString:@"official" forKey:@"bangumiMode"];
        [KLTheme showToast:@"已切换到官方线路" inView:self.view];
    }]];
    [ac addAction:[UIAlertAction actionWithTitle:[mode isEqualToString:@"mirror"] ? @"✓ Kazumi 镜像" : @"Kazumi 镜像" style:UIAlertActionStyleDefault handler:^(UIAlertAction *a) {
        [[KLStore shared] setString:@"mirror" forKey:@"bangumiMode"];
        [KLTheme showToast:@"已切换到 Kazumi 镜像" inView:self.view];
    }]];
    [ac addAction:[UIAlertAction actionWithTitle:@"自定义线路" style:UIAlertActionStyleDefault handler:^(UIAlertAction *a) {
        UIAlertController *input = [UIAlertController alertControllerWithTitle:@"自定义 Bangumi API" message:@"例如 https://api.bgm.tv" preferredStyle:UIAlertControllerStyleAlert];
        [input addTextFieldWithConfigurationHandler:^(UITextField *tf) {
            tf.text = [[KLStore shared] stringForKey:@"bangumiCustomBase" defaultValue:@""];
            tf.placeholder = @"https://…";
            tf.keyboardType = UIKeyboardTypeURL;
        }];
        [input addAction:[UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:nil]];
        [input addAction:[UIAlertAction actionWithTitle:@"保存" style:UIAlertActionStyleDefault handler:^(UIAlertAction *x) {
            [[KLStore shared] setString:input.textFields.firstObject.text ?: @"" forKey:@"bangumiCustomBase"];
            [[KLStore shared] setString:@"custom" forKey:@"bangumiMode"];
        }]];
        [self presentViewController:input animated:YES completion:nil];
    }]];
    [ac addAction:[UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:nil]];
    [self presentViewController:ac animated:YES completion:nil];
}

- (void)showRulesMirror {
    NSString *mode = [[KLStore shared] stringForKey:@"rulesMirror" defaultValue:@"github"];
    UIAlertController *ac = [UIAlertController alertControllerWithTitle:@"规则镜像" message:nil preferredStyle:UIAlertControllerStyleActionSheet];
    NSArray *names = @[@"github", @"ghfast", @"gitcode"];
    NSArray *labels = @[@"GitHub raw", @"ghfast.top", @"GitCode 镜像"];
    for (NSInteger i = 0; i < names.count; i++) {
        NSString *title = [mode isEqualToString:names[i]] ? [@"✓ " stringByAppendingString:labels[i]] : labels[i];
        [ac addAction:[UIAlertAction actionWithTitle:title style:UIAlertActionStyleDefault handler:^(UIAlertAction *a) {
            [[KLStore shared] setString:names[i] forKey:@"rulesMirror"];
            [KLTheme showToast:[NSString stringWithFormat:@"规则镜像：%@", labels[i]] inView:self.view];
        }]];
    }
    [ac addAction:[UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:nil]];
    [self presentViewController:ac animated:YES completion:nil];
}

- (void)clearCache {
    [[KLImageLoader shared] clearDiskCache];
    [[KLImageLoader shared] clearMemoryCache];
    [KLTheme showToast:@"图片缓存已清理" inView:self.view];
}

- (void)checkUpdate {
    [KLComponents showHUD:@"检查更新…" inView:self.view];
    [KLUpdater checkForUpdateWithCompletion:^(NSDictionary *releaseInfo, NSError *error) {
        [KLComponents hideHUDInView:self.view];
        if (error || !releaseInfo) {
            UIAlertController *ac = [UIAlertController alertControllerWithTitle:@"检查更新失败" message:error.localizedDescription ?: @"无法连接更新服务器" preferredStyle:UIAlertControllerStyleAlert];
            [ac addAction:[UIAlertAction actionWithTitle:@"好" style:UIAlertActionStyleDefault handler:nil]];
            [self presentViewController:ac animated:YES completion:nil];
            return;
        }
        BOOL newer = [KLUpdater isReleaseNewer:releaseInfo];
        NSString *msg = [NSString stringWithFormat:@"当前 1.0.0 (Build 1)\n最新 %@ (Build %@)\n\n%@", releaseInfo[@"version"], releaseInfo[@"build"], releaseInfo[@"notes"] ?: @""];
        UIAlertController *ac = [UIAlertController alertControllerWithTitle:newer ? @"发现新版本" : @"已是最新版本" message:msg preferredStyle:UIAlertControllerStyleAlert];
        if (newer) {
            [ac addAction:[UIAlertAction actionWithTitle:@"更新" style:UIAlertActionStyleDefault handler:^(UIAlertAction *a) {
                [KLComponents showHUD:@"正在下载更新…" inView:self.view];
                [KLUpdater installRelease:releaseInfo progress:^(NSString *status) {
                    [KLComponents updateHUD:status inView:self.view];
                } downloadProgress:nil completion:^(NSError *e) {
                    [KLComponents hideHUDInView:self.view];
                    if (e) [KLTheme showToast:e.localizedDescription inView:self.view];
                    else {
                        UIAlertController *done = [UIAlertController alertControllerWithTitle:@"安装完成" message:@"应用将重新启动" preferredStyle:UIAlertControllerStyleAlert];
                        [done addAction:[UIAlertAction actionWithTitle:@"好" style:UIAlertActionStyleDefault handler:^(UIAlertAction *x) { [KLUpdater relaunchApplication]; }]];
                        [self presentViewController:done animated:YES completion:nil];
                    }
                }];
            }]];
        }
        [ac addAction:[UIAlertAction actionWithTitle:@"关闭" style:UIAlertActionStyleCancel handler:nil]];
        [self presentViewController:ac animated:YES completion:nil];
    }];
}

@end
