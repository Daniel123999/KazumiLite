#import "KLRulesViewController.h"
#import "KLTheme.h"
#import "KLComponents.h"
#import "KLStore.h"
#import "KLRuleEditViewController.h"
#import "KLRuleShopViewController.h"
#import "KLHttp.h"

@interface KLRulesViewController () <UITableViewDataSource, UITableViewDelegate>
@property (nonatomic, strong) UITableView *tableView;
@property (nonatomic, strong) NSArray *rules;
@end

@implementation KLRulesViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = @"规则管理";
    self.view.backgroundColor = [KLTheme background];
    self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemAdd target:self action:@selector(showAddMenu)];

    self.tableView = [[UITableView alloc] initWithFrame:self.view.bounds style:UITableViewStylePlain];
    self.tableView.dataSource = self;
    self.tableView.delegate = self;
    self.tableView.rowHeight = 66;
    [KLTheme styleTableView:self.tableView];
    [self.view addSubview:self.tableView];

    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(reload) name:KLStoreDidChangeNotification object:nil];
    [self reload];
}

- (void)viewWillAppear:(BOOL)animated { [super viewWillAppear:animated]; [self reload]; }
- (void)dealloc { [[NSNotificationCenter defaultCenter] removeObserver:self]; }

- (void)reload {
    self.rules = [[KLStore shared] allRules];
    [self.tableView reloadData];
    self.navigationItem.prompt = [NSString stringWithFormat:@"%lu 个规则 · 点击编辑，左滑删除", (unsigned long)self.rules.count];
}

- (void)showAddMenu {
    UIAlertController *ac = [UIAlertController alertControllerWithTitle:@"添加规则" message:nil preferredStyle:UIAlertControllerStyleActionSheet];
    [ac addAction:[UIAlertAction actionWithTitle:@"新建规则" style:UIAlertActionStyleDefault handler:^(UIAlertAction *a) {
        KLRuleEditViewController *vc = [[KLRuleEditViewController alloc] initWithRule:nil];
        [self.navigationController pushViewController:vc animated:YES];
    }]];
    [ac addAction:[UIAlertAction actionWithTitle:@"从剪贴板导入" style:UIAlertActionStyleDefault handler:^(UIAlertAction *a) {
        [self importFromText:[[UIPasteboard generalPasteboard] string]];
    }]];
    [ac addAction:[UIAlertAction actionWithTitle:@"从 URL 导入" style:UIAlertActionStyleDefault handler:^(UIAlertAction *a) {
        UIAlertController *input = [UIAlertController alertControllerWithTitle:@"规则 URL" message:@"支持单条规则 JSON 或规则数组" preferredStyle:UIAlertControllerStyleAlert];
        [input addTextFieldWithConfigurationHandler:^(UITextField *tf) { tf.placeholder = @"https://…"; tf.keyboardType = UIKeyboardTypeURL; }];
        [input addAction:[UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:nil]];
        [input addAction:[UIAlertAction actionWithTitle:@"导入" style:UIAlertActionStyleDefault handler:^(UIAlertAction *x) {
            NSString *url = input.textFields.firstObject.text;
            [KLComponents showHUD:@"下载规则…" inView:self.view];
            [[KLHttp GET:url headers:nil completion:^(id json, NSData *data, NSHTTPURLResponse *response, NSError *error) {
                [KLComponents hideHUDInView:self.view];
                if (data.length) [self importFromText:[[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding]];
                else [KLTheme showToast:error.localizedDescription ?: @"下载失败" inView:self.view];
            }] resume];
        }]];
        [self presentViewController:input animated:YES completion:nil];
    }]];
    [ac addAction:[UIAlertAction actionWithTitle:@"打开规则商店" style:UIAlertActionStyleDefault handler:^(UIAlertAction *a) {
        [self.navigationController pushViewController:[[KLRuleShopViewController alloc] init] animated:YES];
    }]];
    [ac addAction:[UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:nil]];
    [self presentViewController:ac animated:YES completion:nil];
}

// Small helper so this file does not need to import KLHttp twice.

- (void)importFromText:(NSString *)text {
    if (text.length == 0) { [KLTheme showToast:@"剪贴板为空" inView:self.view]; return; }
    id json = [NSJSONSerialization JSONObjectWithData:[text dataUsingEncoding:NSUTF8StringEncoding] options:0 error:NULL];
    if (!json) {
        // Support Kazumi share URLs of the form kazumi://rule?url=...
        NSRange range = [text rangeOfString:@"http"];
        if (range.location != NSNotFound) {
            NSString *url = [text substringFromIndex:range.location];
            [[[NSURLSession sharedSession] dataTaskWithURL:[NSURL URLWithString:url] completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    if (data.length) [self importFromText:[[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding]];
                    else [KLTheme showToast:@"下载规则失败" inView:self.view];
                });
            }] resume];
            return;
        }
        [KLTheme showToast:@"不是有效的规则 JSON" inView:self.view];
        return;
    }
    NSArray *items = [json isKindOfClass:[NSArray class]] ? json : @[json];
    NSInteger count = 0;
    for (NSDictionary *d in items) {
        KLRule *rule = [KLRule fromDictionary:d];
        if (rule.name.length) { [[KLStore shared] saveRule:rule]; count++; }
    }
    [self reload];
    [KLTheme showToast:[NSString stringWithFormat:@"已导入 %ld 个规则", (long)count] inView:self.view];
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section { return self.rules.count; }

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    KLRule *rule = self.rules[indexPath.row];
    UITableViewCell *cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:nil];
    cell.backgroundColor = [KLTheme card];
    cell.textLabel.text = [NSString stringWithFormat:@"%@  v%@", rule.name, rule.version.length ? rule.version : @"?"];
    cell.textLabel.font = [KLTheme mediumFont:14];
    cell.textLabel.textColor = [KLTheme textPrimary];
    cell.detailTextLabel.text = [NSString stringWithFormat:@"%@ · %@ · %@", [rule isAPISearch] ? @"API搜索" : @"XPath搜索", [rule isAPIChapter] ? @"API章节" : @"XPath章节", rule.baseURL ?: @""];
    cell.detailTextLabel.font = [KLTheme font:9];
    cell.detailTextLabel.textColor = [KLTheme textSecondary];
    UISwitch *sw = [[UISwitch alloc] init];
    sw.onTintColor = [KLTheme accent];
    sw.on = rule.enabled;
    sw.tag = indexPath.row;
    [sw addTarget:self action:@selector(toggleRule:) forControlEvents:UIControlEventValueChanged];
    cell.accessoryView = sw;
    return cell;
}

- (void)toggleRule:(UISwitch *)sw {
    KLRule *rule = self.rules[sw.tag];
    [[KLStore shared] setRule:rule enabled:sw.on];
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    KLRule *rule = self.rules[indexPath.row];
    KLRuleEditViewController *vc = [[KLRuleEditViewController alloc] initWithRule:rule];
    [self.navigationController pushViewController:vc animated:YES];
}

- (NSArray *)tableView:(UITableView *)tableView editActionsForRowAtIndexPath:(NSIndexPath *)indexPath {
    KLRule *rule = self.rules[indexPath.row];
    UITableViewRowAction *del = [UITableViewRowAction rowActionWithStyle:UITableViewRowActionStyleDestructive title:@"删除" handler:^(UITableViewRowAction *a, NSIndexPath *ip) {
        [[KLStore shared] deleteRule:rule];
        [self reload];
    }];
    UITableViewRowAction *share = [UITableViewRowAction rowActionWithStyle:UITableViewRowActionStyleNormal title:@"导出" handler:^(UITableViewRowAction *a, NSIndexPath *ip) {
        NSData *data = [NSJSONSerialization dataWithJSONObject:[rule toDictionary] options:NSJSONWritingPrettyPrinted error:NULL];
        NSString *text = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
        UIActivityViewController *ac = [[UIActivityViewController alloc] initWithActivityItems:@[text] applicationActivities:nil];
        [self presentViewController:ac animated:YES completion:nil];
    }];
    share.backgroundColor = [KLTheme accent];
    return @[del, share];
}

@end
