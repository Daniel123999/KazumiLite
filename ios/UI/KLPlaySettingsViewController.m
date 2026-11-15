#import "KLPlaySettingsViewController.h"
#import "KLTheme.h"
#import "KLComponents.h"
#import "KLStore.h"

@interface KLPlaySettingsViewController () <UITableViewDataSource, UITableViewDelegate>
@property (nonatomic, strong) UITableView *tableView;
@property (nonatomic, strong) NSArray *rows;
@end

@implementation KLPlaySettingsViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = @"播放设置";
    self.view.backgroundColor = [KLTheme background];
    if ([self respondsToSelector:@selector(setAutomaticallyAdjustsScrollViewInsets:)]) {
        self.automaticallyAdjustsScrollViewInsets = YES;
    }
    self.rows = @[
        @{@"title": @"默认倍速", @"key": @"defaultSpeed", @"type": @"speed"},
        @{@"title": @"自动连播下一集", @"key": @"autoPlayNext", @"type": @"switch"},
        @{@"title": @"打开后自动播放", @"key": @"autoPlay", @"type": @"switch"},
        @{@"title": @"从上次进度继续", @"key": @"playResume", @"type": @"switch"},
        @{@"title": @"低内存模式", @"key": @"lowMemory", @"type": @"switch"},
        @{@"title": @"广告分片过滤", @"key": @"adFilter", @"type": @"switch"},
        @{@"title": @"硬解优先（AVPlayer）", @"key": @"hwDecode", @"type": @"switch"}
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
- (NSString *)tableView:(UITableView *)tableView titleForFooterInSection:(NSInteger)section {
    return @"iOS 9 / iPhone 4S 使用系统 AVPlayer 硬解 H.264；低内存模式会限制预加载。\n提示：部分视频源需要网页播放，可在播放页右上角切换。";
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
    if ([row[@"type"] isEqualToString:@"switch"]) {
        UISwitch *sw = [[UISwitch alloc] init];
        sw.onTintColor = [KLTheme accent];
        sw.on = [[KLStore shared] boolForKey:row[@"key"] defaultValue:YES];
        sw.tag = indexPath.row;
        [sw addTarget:self action:@selector(switchChanged:) forControlEvents:UIControlEventValueChanged];
        cell.accessoryView = sw;
        cell.selectionStyle = UITableViewCellSelectionStyleNone;
    } else {
        cell.detailTextLabel.text = [NSString stringWithFormat:@"%.2gx", [[KLStore shared] doubleForKey:@"defaultSpeed" defaultValue:1.0]];
        cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
    }
    return cell;
}

- (void)switchChanged:(UISwitch *)sw {
    [[KLStore shared] setBool:sw.on forKey:self.rows[sw.tag][@"key"]];
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    NSDictionary *row = self.rows[indexPath.row];
    if (![row[@"type"] isEqualToString:@"speed"]) return;
    NSArray *speeds = @[@0.5, @0.75, @1.0, @1.25, @1.5, @2.0];
    UIAlertController *ac = [UIAlertController alertControllerWithTitle:@"默认倍速" message:nil preferredStyle:UIAlertControllerStyleActionSheet];
    for (NSNumber *s in speeds) {
        [ac addAction:[UIAlertAction actionWithTitle:[NSString stringWithFormat:@"%.2gx", s.doubleValue] style:UIAlertActionStyleDefault handler:^(UIAlertAction *a) {
            [[KLStore shared] setDouble:s.doubleValue forKey:@"defaultSpeed"];
            [self.tableView reloadData];
        }]];
    }
    [ac addAction:[UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:nil]];
    [self presentViewController:ac animated:YES completion:nil];
}

@end
