#import "KLDanmakuSettingsViewController.h"
#import "KLTheme.h"
#import "KLComponents.h"
#import "KLStore.h"
#import "KLDanmakuAPI.h"

@interface KLDanmakuSettingsViewController () <UITableViewDataSource, UITableViewDelegate>
@property (nonatomic, strong) UITableView *tableView;
@property (nonatomic, strong) NSArray *rows;
@end

@implementation KLDanmakuSettingsViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = @"弹幕设置";
    self.view.backgroundColor = [KLTheme background];
    self.rows = @[
        @{@"title": @"默认开启弹幕", @"key": @"danmakuEnabled", @"type": @"switch"},
        @{@"title": @"字号", @"key": @"danmakuFontSize", @"type": @"number", @"min": @12, @"max": @28, @"step": @1},
        @{@"title": @"不透明度", @"key": @"danmakuOpacity", @"type": @"number", @"min": @0.2, @"max": @1.0, @"step": @0.1},
        @{@"title": @"持续时间（秒）", @"key": @"danmakuDuration", @"type": @"number", @"min": @4, @"max": @15, @"step": @1},
        @{@"title": @"显示区域", @"key": @"danmakuArea", @"type": @"number", @"min": @0.3, @"max": @1.0, @"step": @0.1},
        @{@"title": @"滚动弹幕", @"key": @"danmakuScroll", @"type": @"switch"},
        @{@"title": @"顶部弹幕", @"key": @"danmakuTop", @"type": @"switch"},
        @{@"title": @"底部弹幕", @"key": @"danmakuBottom", @"type": @"switch"},
        @{@"title": @"描边", @"key": @"danmakuBorder", @"type": @"switch"},
        @{@"title": @"合并重复弹幕", @"key": @"danmakuDedup", @"type": @"switch"},
        @{@"title": @"跟随播放倍速", @"key": @"danmakuFollowSpeed", @"type": @"switch"},
        @{@"title": @"时间偏移（秒）", @"key": @"danmakuOffset", @"type": @"number", @"min": @(-10), @"max": @10, @"step": @0.5},
        @{@"title": @"屏蔽词", @"key": @"danmakuShield", @"type": @"text"},
        @{@"title": @"弹弹Play AppId", @"key": @"dandanAppId", @"type": @"text"},
        @{@"title": @"弹弹Play AppSecret", @"key": @"dandanAppKey", @"type": @"text"}
    ];

    self.tableView = [[UITableView alloc] initWithFrame:self.view.bounds style:UITableViewStyleGrouped];
    self.tableView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    self.tableView.dataSource = self;
    self.tableView.delegate = self;
    [KLTheme styleTableView:self.tableView];
    [self.view addSubview:self.tableView];
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView { return 1; }
- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section { return self.rows.count; }
- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section { return @"弹幕（DanDanPlay / BiliBili / 本地缓存）"; }
- (NSString *)tableView:(UITableView *)tableView titleForFooterInSection:(NSInteger)section {
    return @"未填写弹弹Play凭据时会自动尝试 B 站弹幕。屏蔽词用逗号分隔。";
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    NSDictionary *row = self.rows[indexPath.row];
    UITableViewCell *cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleValue1 reuseIdentifier:nil];
    cell.backgroundColor = [KLTheme card];
    cell.textLabel.text = row[@"title"];
    cell.textLabel.font = [KLTheme font:13];
    cell.textLabel.textColor = [KLTheme textPrimary];
    cell.detailTextLabel.font = [KLTheme font:11];
    cell.detailTextLabel.textColor = [KLTheme textSecondary];
    NSString *key = row[@"key"];
    if ([row[@"type"] isEqualToString:@"switch"]) {
        UISwitch *sw = [[UISwitch alloc] init];
        sw.onTintColor = [KLTheme accent];
        sw.on = [[KLStore shared] boolForKey:key defaultValue:YES];
        sw.tag = indexPath.row;
        [sw addTarget:self action:@selector(switchChanged:) forControlEvents:UIControlEventValueChanged];
        cell.accessoryView = sw;
        cell.selectionStyle = UITableViewCellSelectionStyleNone;
    } else if ([row[@"type"] isEqualToString:@"number"]) {
        double value = [[KLStore shared] doubleForKey:key defaultValue:[row[@"min"] doubleValue]];
        cell.detailTextLabel.text = [NSString stringWithFormat:@"%.2g", value];
        cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
    } else {
        NSString *value = [[KLStore shared] stringForKey:key defaultValue:@""];
        cell.detailTextLabel.text = key.length && [key containsString:@"AppKey"] ? (value.length ? @"已设置" : @"未设置") : (value.length ? value : @"未设置");
        cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
    }
    return cell;
}

- (void)switchChanged:(UISwitch *)sw {
    NSDictionary *row = self.rows[sw.tag];
    [[KLStore shared] setBool:sw.on forKey:row[@"key"]];
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    NSDictionary *row = self.rows[indexPath.row];
    NSString *type = row[@"type"];
    if ([type isEqualToString:@"switch"]) return;
    if ([type isEqualToString:@"number"]) {
        [self chooseNumberForRow:row indexPath:indexPath];
    } else {
        [self editTextForRow:row];
    }
}

- (void)chooseNumberForRow:(NSDictionary *)row indexPath:(NSIndexPath *)indexPath {
    double min = [row[@"min"] doubleValue];
    double max = [row[@"max"] doubleValue];
    double step = [row[@"step"] doubleValue];
    NSMutableArray *values = [NSMutableArray array];
    for (double v = min; v <= max + 0.001; v += step) [values addObject:@(v)];
    UIAlertController *ac = [UIAlertController alertControllerWithTitle:row[@"title"] message:nil preferredStyle:UIAlertControllerStyleActionSheet];
    double current = [[KLStore shared] doubleForKey:row[@"key"] defaultValue:min];
    NSInteger limit = MIN((NSInteger)values.count, 25);
    for (NSInteger i = 0; i < limit; i++) {
        double v = [values[i] doubleValue];
        NSString *title = [NSString stringWithFormat:@"%.2g%@", v, fabs(v - current) < 0.001 ? @"  ✓" : @""];
        [ac addAction:[UIAlertAction actionWithTitle:title style:UIAlertActionStyleDefault handler:^(UIAlertAction *a) {
            [[KLStore shared] setDouble:v forKey:row[@"key"]];
            [self.tableView reloadRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationNone];
        }]];
    }
    [ac addAction:[UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:nil]];
    [self presentViewController:ac animated:YES completion:nil];
}

- (void)editTextForRow:(NSDictionary *)row {
    UIAlertController *ac = [UIAlertController alertControllerWithTitle:row[@"title"] message:nil preferredStyle:UIAlertControllerStyleAlert];
    [ac addTextFieldWithConfigurationHandler:^(UITextField *tf) {
        tf.text = [[KLStore shared] stringForKey:row[@"key"] defaultValue:@""];
        tf.placeholder = @"请输入";
    }];
    [ac addAction:[UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:nil]];
    [ac addAction:[UIAlertAction actionWithTitle:@"保存" style:UIAlertActionStyleDefault handler:^(UIAlertAction *a) {
        NSString *value = ac.textFields.firstObject.text ?: @"";
        [[KLStore shared] setString:value forKey:row[@"key"]];
        [[KLDanmakuAPI shared] setDandanAppId:[[KLStore shared] stringForKey:@"dandanAppId" defaultValue:@""]];
        [[KLDanmakuAPI shared] setDandanAppKey:[[KLStore shared] stringForKey:@"dandanAppKey" defaultValue:@""]];
        [self.tableView reloadData];
    }]];
    [self presentViewController:ac animated:YES completion:nil];
}

@end
