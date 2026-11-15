#import "KLWebDAVViewController.h"
#import "KLTheme.h"
#import "KLComponents.h"
#import "KLWebDAV.h"
#import "KLStore.h"

@interface KLWebDAVViewController () <UITextFieldDelegate>
@property (nonatomic, strong) UIScrollView *scrollView;
@property (nonatomic, strong) UITextField *urlField;
@property (nonatomic, strong) UITextField *userField;
@property (nonatomic, strong) UITextField *passField;
@property (nonatomic, strong) UITextField *pathField;
@property (nonatomic, strong) UISwitch *enableSwitch;
@property (nonatomic, strong) UILabel *statusLabel;
@end

@implementation KLWebDAVViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = @"WebDAV 同步";
    self.view.backgroundColor = [KLTheme background];
    if ([self respondsToSelector:@selector(setAutomaticallyAdjustsScrollViewInsets:)]) {
        self.automaticallyAdjustsScrollViewInsets = YES;
    }

    self.scrollView = [[UIScrollView alloc] initWithFrame:self.view.bounds];
    self.scrollView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    self.scrollView.alwaysBounceVertical = YES;
    [self.view addSubview:self.scrollView];

    CGFloat width = self.view.bounds.size.width;
    UIView *card = [[UIView alloc] initWithFrame:CGRectMake(12, 14, width - 24, 250)];
    card.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    [KLTheme applyCardStyle:card radius:12];
    [self.scrollView addSubview:card];

    self.urlField = [self fieldWithPlaceholder:@"服务器地址，例如 https://dav.example.com" y:14 width:card.bounds.size.width];
    self.urlField.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    self.urlField.text = [KLWebDAV shared].serverURL;
    self.urlField.keyboardType = UIKeyboardTypeURL;
    [card addSubview:self.urlField];

    self.userField = [self fieldWithPlaceholder:@"用户名" y:66 width:card.bounds.size.width];
    self.userField.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    self.userField.text = [KLWebDAV shared].username;
    [card addSubview:self.userField];

    self.passField = [self fieldWithPlaceholder:@"密码" y:118 width:card.bounds.size.width];
    self.passField.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    self.passField.text = [KLWebDAV shared].password;
    self.passField.secureTextEntry = YES;
    [card addSubview:self.passField];

    self.pathField = [self fieldWithPlaceholder:@"远程目录" y:170 width:card.bounds.size.width];
    self.pathField.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    self.pathField.text = [KLWebDAV shared].remotePath;
    [card addSubview:self.pathField];

    UILabel *enable = [KLComponents label:[KLTheme font:13] color:[KLTheme textPrimary]];
    enable.text = @"启用 WebDAV 同步";
    enable.frame = CGRectMake(14, 218, 180, 22);
    [card addSubview:enable];

    self.enableSwitch = [[UISwitch alloc] initWithFrame:CGRectMake(card.bounds.size.width - 62, 214, 50, 30)];
    self.enableSwitch.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin;
    self.enableSwitch.onTintColor = [KLTheme accent];
    self.enableSwitch.on = [KLWebDAV shared].enabled;
    [card addSubview:self.enableSwitch];

    NSArray *titles = @[@"测试连接", @"立即同步", @"备份到云端", @"从云端恢复"];
    CGFloat buttonW = (width - 30) / 2;
    for (NSInteger i = 0; i < titles.count; i++) {
        UIButton *b = [KLComponents softButton:titles[i] target:self action:@selector(buttonTapped:)];
        b.tag = i;
        b.frame = CGRectMake(12 + (i % 2) * (buttonW + 6), 278 + (i / 2) * 44, buttonW, 36);
        b.autoresizingMask = UIViewAutoresizingFlexibleWidth | ((i % 2) ? UIViewAutoresizingFlexibleLeftMargin : UIViewAutoresizingFlexibleRightMargin);
        b.backgroundColor = [KLTheme card];
        b.layer.borderWidth = 0.5;
        b.layer.borderColor = [[KLTheme separator] CGColor];
        [self.scrollView addSubview:b];
    }

    self.statusLabel = [KLComponents label:[KLTheme font:11] color:[KLTheme textSecondary]];
    self.statusLabel.numberOfLines = 0;
    self.statusLabel.frame = CGRectMake(18, 372, width - 36, 80);
    self.statusLabel.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    [self.scrollView addSubview:self.statusLabel];
    self.statusLabel.text = @"备份内容：观看历史、追番列表、自定义规则与弹幕偏好。\nToken / 密码不会上传。";
}

- (void)viewDidLayoutSubviews {
    [super viewDidLayoutSubviews];
    CGFloat bottom = CGRectGetMaxY(self.statusLabel.frame) + 24.0;
    self.scrollView.contentSize = CGSizeMake(self.scrollView.bounds.size.width, MAX(bottom, self.scrollView.bounds.size.height + 1.0));
}

- (UITextField *)fieldWithPlaceholder:(NSString *)placeholder y:(CGFloat)y width:(CGFloat)width {
    UITextField *tf = [[UITextField alloc] initWithFrame:CGRectMake(14, y, width - 28, 40)];
    tf.placeholder = placeholder;
    tf.font = [KLTheme font:12];
    tf.textColor = [KLTheme textPrimary];
    tf.autocapitalizationType = UITextAutocapitalizationTypeNone;
    tf.autocorrectionType = UITextAutocorrectionTypeNo;
    tf.delegate = self;
    tf.borderStyle = UITextBorderStyleNone;
    UIView *line = [[UIView alloc] initWithFrame:CGRectMake(0, 39, width - 28, 0.5)];
    line.backgroundColor = [KLTheme separator];
    [tf addSubview:line];
    return tf;
}

- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
    [self save];
}

- (void)save {
    [KLWebDAV shared].serverURL = self.urlField.text ?: @"";
    [KLWebDAV shared].username = self.userField.text ?: @"";
    [KLWebDAV shared].password = self.passField.text ?: @"";
    [KLWebDAV shared].remotePath = self.pathField.text.length ? self.pathField.text : @"/KazumiLite/";
    [KLWebDAV shared].enabled = self.enableSwitch.on;
    [[KLWebDAV shared] saveConfig];
}

- (void)buttonTapped:(UIButton *)sender {
    [self.view endEditing:YES];
    [self save];
    if (![KLWebDAV shared].enabled) {
        [KLTheme showToast:@"请先启用 WebDAV" inView:self.view];
        return;
    }
    [KLComponents showHUD:@"处理中…" inView:self.view];
    void (^done)(BOOL, NSString *) = ^(BOOL ok, NSString *message) {
        [KLComponents hideHUDInView:self.view];
        self.statusLabel.text = message;
        self.statusLabel.textColor = ok ? [KLTheme success] : [KLTheme danger];
        [KLTheme showToast:message inView:self.view];
    };
    if (sender.tag == 0) [[KLWebDAV shared] testConnection:done];
    else if (sender.tag == 1) [[KLWebDAV shared] syncNow:done];
    else if (sender.tag == 2) [[KLWebDAV shared] backupAll:done];
    else [[KLWebDAV shared] restoreAll:done];
}

@end
