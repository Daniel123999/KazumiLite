#import "KLDetailViewController.h"
#import "KLTheme.h"
#import "KLComponents.h"
#import "KLImageLoader.h"
#import "KLBangumiAPI.h"
#import "KLStore.h"
#import "KLSourcePickerViewController.h"
#import "KLPlayerViewController.h"

@interface KLDetailViewController () <UITableViewDataSource, UITableViewDelegate>
@property (nonatomic, strong) KLBangumiItem *item;
@property (nonatomic, strong) UIScrollView *scrollView;
@property (nonatomic, strong) UIView *headerCard;
@property (nonatomic, strong) KLAsyncImageView *coverView;
@property (nonatomic, strong) UILabel *titleLabel;
@property (nonatomic, strong) UILabel *metaLabel;
@property (nonatomic, strong) UILabel *ratingLabel;
@property (nonatomic, strong) UILabel *summaryLabel;
@property (nonatomic, strong) UILabel *tagsLabel;
@property (nonatomic, strong) UIButton *collectButton;
@property (nonatomic, strong) UIButton *playButton;
@property (nonatomic, strong) UITableView *episodeTable;
@property (nonatomic, strong) NSArray *episodes;
@property (nonatomic, strong) NSArray *comments;
@property (nonatomic, strong) UITableView *commentTable;
@property (nonatomic, assign) CGFloat episodeTableHeight;
@property (nonatomic, strong) UILabel *episodeTitleLabel;
@property (nonatomic, strong) UILabel *commentTitleLabel;
@end

@implementation KLDetailViewController

- (instancetype)initWithBangumi:(KLBangumiItem *)item {
    self = [super init];
    if (self) _item = item;
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = @"番剧详情";
    self.view.backgroundColor = [KLTheme background];
    self.automaticallyAdjustsScrollViewInsets = NO;

    self.scrollView = [[UIScrollView alloc] initWithFrame:self.view.bounds];
    self.scrollView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    self.scrollView.alwaysBounceVertical = YES;
    [self.view addSubview:self.scrollView];

    [self buildHeader];
    [self buildEpisodeSection];
    [self buildCommentSection];
    [self layoutSections];
    [self refreshCollectButton];
    [self loadDetails];
}

- (void)buildHeader {
    self.headerCard = [[UIView alloc] initWithFrame:CGRectMake(10, 10, self.view.bounds.size.width - 20, 190)];
    [KLTheme applyCardStyle:self.headerCard radius:12];
    [self.scrollView addSubview:self.headerCard];

    self.coverView = [[KLAsyncImageView alloc] initWithFrame:CGRectMake(12, 12, 86, 122)];
    self.coverView.layer.cornerRadius = 8;
    self.coverView.clipsToBounds = YES;
    self.coverView.imageURL = self.item.imageCommon.length ? self.item.imageCommon : self.item.imageLarge;
    [self.headerCard addSubview:self.coverView];

    self.titleLabel = [KLComponents label:[KLTheme boldFont:16] color:[KLTheme textPrimary]];
    self.titleLabel.numberOfLines = 3;
    self.titleLabel.frame = CGRectMake(108, 10, self.headerCard.bounds.size.width - 120, 62);
    [self.headerCard addSubview:self.titleLabel];

    self.metaLabel = [KLComponents label:[KLTheme font:11] color:[KLTheme textSecondary]];
    self.metaLabel.numberOfLines = 2;
    self.metaLabel.frame = CGRectMake(108, 74, self.headerCard.bounds.size.width - 120, 34);
    [self.headerCard addSubview:self.metaLabel];

    self.ratingLabel = [KLComponents label:[KLTheme boldFont:12] color:[KLTheme warning]];
    self.ratingLabel.frame = CGRectMake(108, 108, 120, 18);
    [self.headerCard addSubview:self.ratingLabel];

    self.collectButton = [KLComponents softButton:@"追番" target:self action:@selector(showCollectMenu)];
    self.collectButton.frame = CGRectMake(self.headerCard.bounds.size.width - 92, 106, 80, 30);
    [self.headerCard addSubview:self.collectButton];

    self.playButton = [KLComponents filledButton:@"选择播放源" target:self action:@selector(chooseSource)];
    self.playButton.frame = CGRectMake(12, 146, self.headerCard.bounds.size.width - 24, 34);
    [self.headerCard addSubview:self.playButton];

    self.summaryLabel = [KLComponents label:[KLTheme font:12] color:[KLTheme textSecondary]];
    self.summaryLabel.numberOfLines = 0;
    self.summaryLabel.frame = CGRectMake(14, 208, self.view.bounds.size.width - 28, 20);
    [self.scrollView addSubview:self.summaryLabel];

    self.tagsLabel = [KLComponents label:[KLTheme font:11] color:[KLTheme accent]];
    self.tagsLabel.numberOfLines = 2;
    self.tagsLabel.frame = CGRectMake(14, 240, self.view.bounds.size.width - 28, 20);
    [self.scrollView addSubview:self.tagsLabel];
}

- (void)buildEpisodeSection {
    self.episodeTitleLabel = [KLComponents label:[KLTheme boldFont:14] color:[KLTheme textPrimary]];
    self.episodeTitleLabel.text = @"剧集";
    self.episodeTitleLabel.frame = CGRectMake(14, 272, 200, 20);
    [self.scrollView addSubview:self.episodeTitleLabel];

    self.episodeTable = [[UITableView alloc] initWithFrame:CGRectMake(10, 296, self.view.bounds.size.width - 20, 0) style:UITableViewStylePlain];
    self.episodeTable.dataSource = self;
    self.episodeTable.delegate = self;
    self.episodeTable.scrollEnabled = NO;
    self.episodeTable.separatorInset = UIEdgeInsetsMake(0, 12, 0, 12);
    [KLTheme styleTableView:self.episodeTable];
    self.episodeTable.backgroundColor = [KLTheme card];
    self.episodeTable.layer.cornerRadius = 10;
    self.episodeTable.layer.masksToBounds = YES;
    [self.scrollView addSubview:self.episodeTable];
}

- (void)buildCommentSection {
    self.commentTitleLabel = [KLComponents label:[KLTheme boldFont:14] color:[KLTheme textPrimary]];
    self.commentTitleLabel.text = @"评论";
    [self.scrollView addSubview:self.commentTitleLabel];

    self.commentTable = [[UITableView alloc] initWithFrame:CGRectZero style:UITableViewStylePlain];
    self.commentTable.dataSource = self;
    self.commentTable.delegate = self;
    self.commentTable.scrollEnabled = NO;
    self.commentTable.separatorColor = [KLTheme separator];
    [KLTheme styleTableView:self.commentTable];
    self.commentTable.backgroundColor = [KLTheme card];
    self.commentTable.layer.cornerRadius = 10;
    self.commentTable.layer.masksToBounds = YES;
    [self.scrollView addSubview:self.commentTable];
}

- (void)layoutSections {
    CGFloat width = self.view.bounds.size.width;
    self.summaryLabel.text = self.item.summary.length ? self.item.summary : @"暂无简介";
    CGFloat summaryHeight = [KLComponents heightForText:self.summaryLabel.text width:width - 28 font:self.summaryLabel.font];
    summaryHeight = MIN(MAX(20, summaryHeight), 90);
    self.summaryLabel.frame = CGRectMake(14, 208, width - 28, summaryHeight);

    NSArray *tags = self.item.tags.count ? self.item.tags : self.item.alias;
    if (tags.count) {
        NSMutableArray *limited = [NSMutableArray array];
        for (NSInteger i = 0; i < (NSInteger)tags.count && i < 6; i++) [limited addObject:[NSString stringWithFormat:@"#%@", tags[i]]];
        self.tagsLabel.text = [limited componentsJoinedByString:@"  "];
        self.tagsLabel.frame = CGRectMake(14, 214 + summaryHeight, width - 28, 18);
    } else {
        self.tagsLabel.text = @"";
        self.tagsLabel.frame = CGRectMake(14, 214 + summaryHeight, width - 28, 0);
    }
    CGFloat y = 220 + summaryHeight + (tags.count ? 24 : 0);

    self.titleLabel.text = [self.item displayName];
    NSString *meta = [NSString stringWithFormat:@"%@ · %@ · 排名 #%ld",
                      self.item.airDate.length ? self.item.airDate : @"放送时间未知",
                      [KLComponents weekdayName:self.item.airWeekday],
                      (long)self.item.rank];
    self.metaLabel.text = meta;
    self.ratingLabel.text = self.item.rating > 0 ? [NSString stringWithFormat:@"★ %.1f  (%@ 人评分)", self.item.rating, [KLComponents formatCount:self.item.votes]] : @"暂无评分";

    self.episodeTitleLabel.frame = CGRectMake(14, y, width - 28, 20);
    y += 26;
    self.episodeTable.frame = CGRectMake(10, y, width - 20, self.episodeTableHeight);
    y += self.episodeTableHeight + 14;

    self.commentTitleLabel.frame = CGRectMake(14, y, width - 28, 20);
    y += 26;
    CGFloat commentHeight = 0;
    for (NSDictionary *c in self.comments) {
        NSString *text = c[@"comment"] ?: @"";
        commentHeight += MAX(58, [KLComponents heightForText:text width:width - 44 font:[KLTheme font:12]] + 38);
    }
    self.commentTable.frame = CGRectMake(10, y, width - 20, commentHeight);
    y += commentHeight + 20;
    self.scrollView.contentSize = CGSizeMake(width, MAX(y, self.view.bounds.size.height + 1));
}

- (void)viewDidLayoutSubviews {
    [super viewDidLayoutSubviews];
    self.scrollView.frame = self.view.bounds;
    [self layoutSections];
}

- (void)loadDetails {
    NSInteger bid = self.item.bid;
    __weak typeof(self) weakSelf = self;
    [[KLBangumiAPI shared] subject:bid completion:^(KLBangumiItem *item, NSError *error) {
        if (item) {
            weakSelf.item = item;
            [weakSelf buildHeaderContent];
            [weakSelf layoutSections];
        }
    }];
    [[KLBangumiAPI shared] episodes:bid completion:^(NSArray *episodes, NSError *error) {
        __strong typeof(weakSelf) strongSelf = weakSelf;
        if (!strongSelf) return;
        strongSelf.episodes = episodes ?: @[];
        strongSelf.episodeTableHeight = MIN(260, MAX(44, episodes.count * 44.0));
        [strongSelf.episodeTable reloadData];
        [strongSelf layoutSections];
    }];
    [[KLBangumiAPI shared] comments:bid limit:8 offset:0 completion:^(NSArray *comments, NSError *error) {
        __strong typeof(weakSelf) strongSelf = weakSelf;
        if (!strongSelf) return;
        strongSelf.comments = comments ?: @[];
        [strongSelf.commentTable reloadData];
        [strongSelf layoutSections];
    }];
}

- (void)buildHeaderContent {
    self.coverView.imageURL = self.item.imageCommon.length ? self.item.imageCommon : self.item.imageLarge;
    self.titleLabel.text = [self.item displayName];
    self.metaLabel.text = [NSString stringWithFormat:@"%@ · %@",
                           self.item.airDate.length ? self.item.airDate : @"放送时间未知",
                           [KLComponents weekdayName:self.item.airWeekday]];
}

#pragma mark - Collect

- (void)refreshCollectButton {
    KLCollectionEntry *entry = [[KLStore shared] collectionForBangumi:self.item.bid];
    NSString *title = entry ? entry.typeName : @"追番";
    [self.collectButton setTitle:title forState:UIControlStateNormal];
}

- (void)showCollectMenu {
    UIAlertController *ac = [UIAlertController alertControllerWithTitle:@"追番状态" message:nil preferredStyle:UIAlertControllerStyleActionSheet];
    NSArray *names = @[@"在看", @"想看", @"搁置", @"看过", @"抛弃"];
    for (NSInteger i = 0; i < names.count; i++) {
        NSInteger type = i + 1;
        [ac addAction:[UIAlertAction actionWithTitle:names[i] style:UIAlertActionStyleDefault handler:^(UIAlertAction *a) {
            [self setCollectType:type];
        }]];
    }
    if ([[KLStore shared] collectionForBangumi:self.item.bid]) {
        [ac addAction:[UIAlertAction actionWithTitle:@"取消追番" style:UIAlertActionStyleDestructive handler:^(UIAlertAction *a) {
            [self setCollectType:0];
        }]];
    }
    [ac addAction:[UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:nil]];
    [self presentViewController:ac animated:YES completion:nil];
}

- (void)setCollectType:(NSInteger)type {
    if (type == 0) {
        [[KLStore shared] removeCollectionForBangumi:self.item.bid];
    } else {
        KLCollectionEntry *entry = [[KLCollectionEntry alloc] init];
        entry.bangumi = self.item;
        entry.collectType = type;
        [[KLStore shared] setCollection:entry];
    }
    [self refreshCollectButton];
    [KLTheme showToast:type == 0 ? @"已取消追番" : [NSString stringWithFormat:@"已标记为%@", @[@"", @"在看", @"想看", @"搁置", @"看过", @"抛弃"][type]] inView:self.view];

    if ([[KLStore shared] stringForKey:@"bangumiToken" defaultValue:@""].length) {
        [[KLBangumiAPI shared] updateCollection:self.item.bid type:type completion:^(BOOL ok, NSError *error) {
            if (!ok && error) [KLTheme showToast:@"Bangumi 同步失败（仅保存到本地）" inView:self.view];
        }];
    }
}

#pragma mark - Source

- (void)chooseSource {
    KLSourcePickerViewController *picker = [[KLSourcePickerViewController alloc] initWithBangumi:self.item];
    [self.navigationController pushViewController:picker animated:YES];
}

#pragma mark - Table

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    if (tableView == self.episodeTable) return self.episodes.count;
    return self.comments.count;
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
    if (tableView == self.episodeTable) return 44;
    NSDictionary *c = self.comments[indexPath.row];
    NSString *text = c[@"comment"] ?: @"";
    return MAX(58, [KLComponents heightForText:text width:self.view.bounds.size.width - 44 font:[KLTheme font:12]] + 38);
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:nil];
    cell.backgroundColor = [KLTheme card];
    cell.textLabel.textColor = [KLTheme textPrimary];
    cell.detailTextLabel.textColor = [KLTheme textSecondary];
    if (tableView == self.episodeTable) {
        KLEpisode *ep = self.episodes[indexPath.row];
        cell.textLabel.text = [ep displayName];
        cell.textLabel.font = [KLTheme font:13];
        cell.detailTextLabel.text = [NSString stringWithFormat:@"%@ · %.0f", [self typeName:ep.type], ep.sort];
        cell.detailTextLabel.font = [KLTheme font:10];
        cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
    } else {
        NSDictionary *c = self.comments[indexPath.row];
        NSDictionary *user = c[@"user"];
        cell.textLabel.text = [NSString stringWithFormat:@"%@  ★ %@", user[@"nickname"] ?: @"匿名", c[@"score"] ?: @0];
        cell.textLabel.font = [KLTheme mediumFont:11];
        cell.detailTextLabel.text = c[@"comment"] ?: @"";
        cell.detailTextLabel.numberOfLines = 0;
        cell.detailTextLabel.font = [KLTheme font:12];
        cell.accessoryType = UITableViewCellAccessoryNone;
    }
    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    if (tableView == self.episodeTable) {
        KLEpisode *ep = self.episodes[indexPath.row];
        KLSourcePickerViewController *picker = [[KLSourcePickerViewController alloc] initWithBangumi:self.item];
        picker.initialEpisode = (NSInteger)ep.sort;
        [self.navigationController pushViewController:picker animated:YES];
    }
}

- (NSString *)typeName:(NSInteger)type {
    switch (type) {
        case 1: return @"SP";
        case 2: return @"OP";
        case 3: return @"ED";
        default: return @"本篇";
    }
}

@end
