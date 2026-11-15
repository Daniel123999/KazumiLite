#import "KLRuleEditViewController.h"
#import "KLTheme.h"
#import "KLComponents.h"
#import "KLStore.h"
#import "KLRuleEngine.h"

@interface KLJSONEditorViewController : UIViewController <UITextViewDelegate>
@property (nonatomic, copy) NSString *jsonText;
@property (nonatomic, copy) void (^onSave)(NSString *text);
@end
@implementation KLJSONEditorViewController
- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = @"完整规则 JSON";
    self.view.backgroundColor = [KLTheme background];
    UITextView *tv = [[UITextView alloc] initWithFrame:self.view.bounds];
    tv.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    tv.font = [UIFont fontWithName:@"Menlo" size:10] ?: [KLTheme font:11];
    tv.text = self.jsonText;
    tv.textColor = [KLTheme textPrimary];
    tv.backgroundColor = [KLTheme card];
    tv.autocapitalizationType = UITextAutocapitalizationTypeNone;
    tv.autocorrectionType = UITextAutocorrectionTypeNo;
    tv.tag = 100;
    [self.view addSubview:tv];
    self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithTitle:@"保存" style:UIBarButtonItemStyleDone target:self action:@selector(save)];
}
- (void)save {
    UITextView *tv = [self.view viewWithTag:100];
    if (self.onSave) self.onSave(tv.text ?: @"");
    [self.navigationController popViewControllerAnimated:YES];
}
@end

@interface KLRuleEditViewController () <UITableViewDataSource, UITableViewDelegate>
@property (nonatomic, strong) KLRule *rule;
@property (nonatomic, strong) UITableView *tableView;
@property (nonatomic, strong) NSArray *sections;
@end

@implementation KLRuleEditViewController

- (instancetype)initWithRule:(KLRule *)rule {
    self = [super init];
    if (self) {
        if (rule) _rule = rule;
        else {
            _rule = [KLRule fromDictionary:@{
                @"name": @"", @"version": @"1.0", @"baseURL": @"", @"searchURL": @"",
                @"searchList": @"", @"searchName": @"", @"searchResult": @"",
                @"chapterRoads": @"", @"chapterResult": @"",
                @"useWebview": @YES, @"useNativePlayer": @YES, @"usePost": @NO,
                @"useLegacyParser": @NO, @"adBlocker": @NO, @"enabled": @YES,
                @"searchMode": @"xpath", @"chapterMode": @"xpath"
            }];
        }
    }
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = self.rule.name.length ? @"编辑规则" : @"新建规则";
    self.view.backgroundColor = [KLTheme background];
    self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithTitle:@"保存" style:UIBarButtonItemStyleDone target:self action:@selector(saveRule)];

    self.sections = @[
        @[@{@"key": @"name", @"title": @"规则名称", @"type": @"text"},
          @{@"key": @"version", @"title": @"版本", @"type": @"text"},
          @{@"key": @"baseURL", @"title": @"站点根地址", @"type": @"url"},
          @{@"key": @"referer", @"title": @"Referer", @"type": @"url"},
          @{@"key": @"userAgent", @"title": @"User-Agent", @"type": @"text"}],
        @[@{@"key": @"searchMode", @"title": @"搜索模式", @"type": @"mode"},
          @{@"key": @"searchURL", @"title": @"搜索 URL（@keyword）", @"type": @"url"},
          @{@"key": @"searchList", @"title": @"结果列表 XPath", @"type": @"text"},
          @{@"key": @"searchName", @"title": @"条目名称 XPath", @"type": @"text"},
          @{@"key": @"searchResult", @"title": @"条目链接 XPath", @"type": @"text"},
          @{@"key": @"usePost", @"title": @"POST 搜索", @"type": @"switch"}],
        @[@{@"key": @"chapterMode", @"title": @"章节模式", @"type": @"mode"},
          @{@"key": @"chapterRoads", @"title": @"线路列表 XPath", @"type": @"text"},
          @{@"key": @"chapterResult", @"title": @"剧集列表 XPath", @"type": @"text"},
          @{@"key": @"useLegacyParser", @"title": @"旧版 iframe 解析", @"type": @"switch"}],
        @[@{@"key": @"useWebview", @"title": @"允许 WebView", @"type": @"switch"},
          @{@"key": @"useNativePlayer", @"title": @"内置播放器", @"type": @"switch"},
          @{@"key": @"adBlocker", @"title": @"广告拦截", @"type": @"switch"},
          @{@"key": @"enabled", @"title": @"启用规则", @"type": @"switch"}],
        @[@{@"key": @"json", @"title": @"编辑完整 JSON（API 规则）", @"type": @"action"},
          @{@"key": @"test", @"title": @"测试搜索", @"type": @"action"},
          @{@"key": @"export", @"title": @"导出规则 JSON", @"type": @"action"}]
    ];

    self.tableView = [[UITableView alloc] initWithFrame:self.view.bounds style:UITableViewStyleGrouped];
    self.tableView.dataSource = self;
    self.tableView.delegate = self;
    [KLTheme styleTableView:self.tableView];
    [self.view addSubview:self.tableView];
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView { return self.sections.count; }
- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section { return [self.sections[section] count]; }
- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    NSArray *titles = @[@"基本信息", @"搜索规则", @"章节规则", @"播放与开关", @"工具"];
    return titles[section];
}
- (NSString *)tableView:(UITableView *)tableView titleForFooterInSection:(NSInteger)section {
    if (section == 1) return @"XPath 仅支持 // 开头的选择器；API 规则请在完整 JSON 中配置 searchApiConfig / chapterApiConfig。";
    if (section == 2) return @"chapterResult 通常填 //a，程序会读取 href 与文本。";
    return nil;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    NSDictionary *row = self.sections[indexPath.section][indexPath.row];
    UITableViewCell *cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleValue1 reuseIdentifier:nil];
    cell.backgroundColor = [KLTheme card];
    cell.textLabel.text = row[@"title"];
    cell.textLabel.font = [KLTheme font:13];
    cell.textLabel.textColor = [KLTheme textPrimary];
    cell.detailTextLabel.font = [KLTheme font:10];
    cell.detailTextLabel.textColor = [KLTheme textSecondary];
    NSString *type = row[@"type"];
    if ([type isEqualToString:@"switch"]) {
        UISwitch *sw = [[UISwitch alloc] init];
        sw.onTintColor = [KLTheme accent];
        sw.on = [[self.rule valueForKey:row[@"key"]] boolValue];
        sw.tag = indexPath.section * 100 + indexPath.row;
        [sw addTarget:self action:@selector(switchChanged:) forControlEvents:UIControlEventValueChanged];
        cell.accessoryView = sw;
        cell.selectionStyle = UITableViewCellSelectionStyleNone;
    } else if ([type isEqualToString:@"mode"]) {
        NSString *value = [self.rule valueForKey:row[@"key"]];
        cell.detailTextLabel.text = [value isEqualToString:@"api"] ? @"API / JSONPath" : @"XPath";
        cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
    } else if ([type isEqualToString:@"action"]) {
        cell.detailTextLabel.text = nil;
        cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
        cell.textLabel.textColor = [KLTheme accent];
    } else {
        NSString *value = [self.rule valueForKey:row[@"key"]];
        cell.detailTextLabel.text = value.length > 42 ? [[value substringToIndex:42] stringByAppendingString:@"…"] : (value.length ? value : @"未设置");
        cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
    }
    return cell;
}

- (void)switchChanged:(UISwitch *)sw {
    NSInteger section = sw.tag / 100;
    NSInteger row = sw.tag % 100;
    NSDictionary *item = self.sections[section][row];
    [self.rule setValue:@(sw.on) forKey:item[@"key"]];
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    NSDictionary *row = self.sections[indexPath.section][indexPath.row];
    NSString *type = row[@"type"];
    if ([type isEqualToString:@"switch"]) return;
    if ([type isEqualToString:@"mode"]) {
        [self chooseModeForKey:row[@"key"] title:row[@"title"]];
    } else if ([type isEqualToString:@"action"]) {
        if ([row[@"key"] isEqualToString:@"json"]) [self editJSON];
        else if ([row[@"key"] isEqualToString:@"test"]) [self testSearch];
        else if ([row[@"key"] isEqualToString:@"export"]) [self exportRule];
    } else {
        [self editValueForKey:row[@"key"] title:row[@"title"] isURL:[type isEqualToString:@"url"]];
    }
}

- (void)chooseModeForKey:(NSString *)key title:(NSString *)title {
    UIAlertController *ac = [UIAlertController alertControllerWithTitle:title message:nil preferredStyle:UIAlertControllerStyleActionSheet];
    [ac addAction:[UIAlertAction actionWithTitle:@"XPath" style:UIAlertActionStyleDefault handler:^(UIAlertAction *a) {
        [self.rule setValue:@"xpath" forKey:key];
        [self.tableView reloadData];
    }]];
    [ac addAction:[UIAlertAction actionWithTitle:@"API / JSONPath" style:UIAlertActionStyleDefault handler:^(UIAlertAction *a) {
        [self.rule setValue:@"api" forKey:key];
        [self.tableView reloadData];
    }]];
    [ac addAction:[UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:nil]];
    [self presentViewController:ac animated:YES completion:nil];
}

- (void)editValueForKey:(NSString *)key title:(NSString *)title isURL:(BOOL)isURL {
    UIAlertController *ac = [UIAlertController alertControllerWithTitle:title message:nil preferredStyle:UIAlertControllerStyleAlert];
    [ac addTextFieldWithConfigurationHandler:^(UITextField *tf) {
        tf.text = [self.rule valueForKey:key] ?: @"";
        tf.autocapitalizationType = UITextAutocapitalizationTypeNone;
        tf.autocorrectionType = UITextAutocorrectionTypeNo;
        if (isURL) tf.keyboardType = UIKeyboardTypeURL;
    }];
    [ac addAction:[UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:nil]];
    [ac addAction:[UIAlertAction actionWithTitle:@"确定" style:UIAlertActionStyleDefault handler:^(UIAlertAction *a) {
        [self.rule setValue:ac.textFields.firstObject.text ?: @"" forKey:key];
        [self.tableView reloadData];
    }]];
    [self presentViewController:ac animated:YES completion:nil];
}

- (void)editJSON {
    KLJSONEditorViewController *editor = [[KLJSONEditorViewController alloc] init];
    NSData *data = [NSJSONSerialization dataWithJSONObject:[self.rule toDictionary] options:NSJSONWritingPrettyPrinted error:NULL];
    editor.jsonText = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
    __weak typeof(self) weakSelf = self;
    editor.onSave = ^(NSString *text) {
        id json = [NSJSONSerialization JSONObjectWithData:[text dataUsingEncoding:NSUTF8StringEncoding] options:0 error:NULL];
        if (![json isKindOfClass:[NSDictionary class]]) {
            [KLTheme showToast:@"JSON 格式错误" inView:weakSelf.view];
            return;
        }
        KLRule *rule = [KLRule fromDictionary:json];
        rule.localPath = weakSelf.rule.localPath;
        weakSelf.rule = rule;
        [weakSelf.tableView reloadData];
    };
    [self.navigationController pushViewController:editor animated:YES];
}

- (void)testSearch {
    UIAlertController *ac = [UIAlertController alertControllerWithTitle:@"测试搜索" message:@"输入关键词" preferredStyle:UIAlertControllerStyleAlert];
    [ac addTextFieldWithConfigurationHandler:^(UITextField *tf) { tf.placeholder = @"例如：孤独摇滚"; }];
    [ac addAction:[UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:nil]];
    [ac addAction:[UIAlertAction actionWithTitle:@"搜索" style:UIAlertActionStyleDefault handler:^(UIAlertAction *a) {
        NSString *keyword = ac.textFields.firstObject.text;
        [KLComponents showHUD:@"搜索中…" inView:self.view];
        [[KLRuleEngine shared] searchWithRule:self.rule keyword:keyword completion:^(NSArray *items, NSError *error) {
            [KLComponents hideHUDInView:self.view];
            NSMutableString *message = [NSMutableString string];
            if (error) [message appendString:error.localizedDescription];
            else {
                [message appendFormat:@"找到 %lu 条结果\n", (unsigned long)items.count];
                for (NSInteger i = 0; i < (NSInteger)items.count && i < 5; i++) {
                    KLSearchItem *item = items[i];
                    [message appendFormat:@"\n• %@\n%@", item.name, item.src];
                }
            }
            [KLComponents showTextSheet:@"搜索结果" text:message inView:self.view];
        }];
    }]];
    [self presentViewController:ac animated:YES completion:nil];
}

- (void)exportRule {
    NSData *data = [NSJSONSerialization dataWithJSONObject:[self.rule toDictionary] options:NSJSONWritingPrettyPrinted error:NULL];
    NSString *text = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
    [[UIPasteboard generalPasteboard] setString:text];
    [KLTheme showToast:@"规则 JSON 已复制" inView:self.view];
}

- (void)saveRule {
    NSString *name = [self.rule.name stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    if (name.length == 0) {
        [KLTheme showToast:@"规则名称不能为空" inView:self.view];
        return;
    }
    self.rule.name = name;
    if (self.rule.version.length == 0) self.rule.version = @"1.0";
    [[KLStore shared] saveRule:self.rule];
    [KLTheme showToast:@"规则已保存" inView:self.view];
    [self.navigationController popViewControllerAnimated:YES];
}

@end
