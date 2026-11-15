#import "KLImageSearchViewController.h"
#import "KLTheme.h"
#import "KLComponents.h"
#import "KLHttp.h"
#import "KLBangumiAPI.h"
#import "KLDetailViewController.h"

@interface KLImageSearchViewController () <UIImagePickerControllerDelegate, UINavigationControllerDelegate>
@property (nonatomic, strong) UIImageView *previewView;
@property (nonatomic, strong) UILabel *hintLabel;
@property (nonatomic, strong) UILabel *resultLabel;
@property (nonatomic, strong) UIButton *recognizeButton;
@property (nonatomic, strong) UIButton *bangumiButton;
@property (nonatomic, copy) NSString *matchedTitle;
@end

@implementation KLImageSearchViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = @"图片识番";
    self.view.backgroundColor = [KLTheme background];

    self.previewView = [[UIImageView alloc] initWithFrame:CGRectMake(20, 20, self.view.bounds.size.width - 40, 190)];
    self.previewView.backgroundColor = [KLTheme card];
    self.previewView.contentMode = UIViewContentModeScaleAspectFit;
    self.previewView.layer.cornerRadius = 10;
    self.previewView.clipsToBounds = YES;
    [self.view addSubview:self.previewView];

    UIButton *choose = [KLComponents softButton:@"选择图片" target:self action:@selector(chooseImage)];
    choose.frame = CGRectMake(20, 222, (self.view.bounds.size.width - 52) / 2, 36);
    [self.view addSubview:choose];

    self.recognizeButton = [KLComponents filledButton:@"识别番剧" target:self action:@selector(recognize)];
    self.recognizeButton.frame = CGRectMake(32 + (self.view.bounds.size.width - 52) / 2, 222, (self.view.bounds.size.width - 52) / 2, 36);
    [self.view addSubview:self.recognizeButton];

    self.hintLabel = [KLComponents label:[KLTheme font:11] color:[KLTheme textSecondary]];
    self.hintLabel.numberOfLines = 0;
    self.hintLabel.textAlignment = NSTextAlignmentCenter;
    self.hintLabel.frame = CGRectMake(20, 272, self.view.bounds.size.width - 40, 40);
    self.hintLabel.text = @"使用 trace.moe 识别番剧截图；识别结果仅用于匹配 Bangumi 条目。";
    [self.view addSubview:self.hintLabel];

    self.resultLabel = [KLComponents label:[KLTheme font:13] color:[KLTheme textPrimary]];
    self.resultLabel.numberOfLines = 0;
    self.resultLabel.frame = CGRectMake(20, 320, self.view.bounds.size.width - 40, 100);
    [self.view addSubview:self.resultLabel];

    self.bangumiButton = [KLComponents softButton:@"在 Bangumi 中搜索" target:self action:@selector(searchBangumi)];
    self.bangumiButton.frame = CGRectMake(20, 428, self.view.bounds.size.width - 40, 36);
    self.bangumiButton.hidden = YES;
    [self.view addSubview:self.bangumiButton];
}

- (void)chooseImage {
    UIImagePickerController *picker = [[UIImagePickerController alloc] init];
    picker.sourceType = UIImagePickerControllerSourceTypePhotoLibrary;
    picker.delegate = self;
    [self presentViewController:picker animated:YES completion:nil];
}

- (void)imagePickerController:(UIImagePickerController *)picker didFinishPickingMediaWithInfo:(NSDictionary *)info {
    UIImage *image = info[UIImagePickerControllerOriginalImage];
    [picker dismissViewControllerAnimated:YES completion:nil];
    if (!image) return;
    self.previewView.image = image;
    self.resultLabel.text = @"";
    self.bangumiButton.hidden = YES;
}

- (void)imagePickerControllerDidCancel:(UIImagePickerController *)picker {
    [picker dismissViewControllerAnimated:YES completion:nil];
}

- (void)recognize {
    if (!self.previewView.image) {
        [KLTheme showToast:@"请先选择图片" inView:self.view];
        return;
    }
    NSData *data = UIImageJPEGRepresentation(self.previewView.image, 0.8);
    if (data.length == 0) return;
    [KLComponents showHUD:@"正在识别…" inView:self.view];
    NSString *url = @"https://api.trace.moe/search?anilistInfo";
    __weak typeof(self) weakSelf = self;
    [KLHttp uploadMultipart:url headers:@{@"Accept": @"application/json"} fieldName:@"image" fileName:@"frame.jpg" mimeType:@"image/jpeg" data:data completion:^(id json, NSData *responseData, NSHTTPURLResponse *response, NSError *error) {
        __strong typeof(weakSelf) strongSelf = weakSelf;
        if (!strongSelf) return;
        [KLComponents hideHUDInView:strongSelf.view];
        NSDictionary *best = nil;
        if ([json isKindOfClass:[NSDictionary class]]) {
            NSArray *results = json[@"result"];
            if ([results isKindOfClass:[NSArray class]] && results.count) best = results.firstObject;
        }
        if (!best) {
            strongSelf.resultLabel.text = error.localizedDescription ?: @"没有识别到结果";
            return;
        }
        NSDictionary *anilist = best[@"anilist"];
        NSDictionary *title = anilist[@"title"];
        NSString *name = title[@"native"] ?: title[@"romaji"] ?: title[@"english"];
        if (![name isKindOfClass:[NSString class]]) name = @"未知番剧";
        double similarity = [best[@"similarity"] doubleValue];
        NSNumber *episode = best[@"episode"];
        strongSelf.matchedTitle = name;
        strongSelf.resultLabel.text = [NSString stringWithFormat:@"%@\n相似度 %.1f%% · 第 %@ 集\n%@", name, similarity * 100, episode ?: @0, best[@"filename"] ?: @""];
        strongSelf.bangumiButton.hidden = NO;
    }];
}

- (void)searchBangumi {
    if (!self.matchedTitle.length) return;
    [KLComponents showHUD:@"搜索 Bangumi…" inView:self.view];
    __weak typeof(self) weakSelf = self;
    [[KLBangumiAPI shared] search:self.matchedTitle limit:5 offset:0 completion:^(NSArray *items, NSInteger rawCount, NSError *error) {
        __strong typeof(weakSelf) strongSelf = weakSelf;
        if (!strongSelf) return;
        [KLComponents hideHUDInView:strongSelf.view];
        if (items.count == 0) {
            [KLTheme showToast:error.localizedDescription ?: @"Bangumi 没有匹配条目" inView:strongSelf.view];
            return;
        }
        [strongSelf.navigationController pushViewController:[[KLDetailViewController alloc] initWithBangumi:items.firstObject] animated:YES];
    }];
}

@end
