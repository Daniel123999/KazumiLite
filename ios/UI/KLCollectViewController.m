#import "KLCollectViewController.h"
#import "KLTheme.h"
#import "KLComponents.h"
#import "KLStore.h"
#import "KLDetailViewController.h"

@interface KLCollectViewController () <UITableViewDataSource, UITableViewDelegate>
@property (nonatomic, strong) UISegmentedControl *segmented;
@property (nonatomic, strong) UITableView *tableView;
@property (nonatomic, strong) NSArray *items;
@property (nonatomic, strong) UILabel *emptyLabel;
@property (nonatomic, assign) NSInteger filter;
@end

@implementation KLCollectViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = @"追番";
    self.view.backgroundColor = [KLTheme background];
    self.filter = 0;

    self.segmented = [[UISegmentedControl alloc] initWithItems:@[@"全部", @"在看", @"想看", @"看过"]];
    self.segmented.selectedSegmentIndex = 0;
    self.segmented.tintColor = [KLTheme accent];
    self.segmented.frame = CGRectMake(14, 8, self.view.bounds.size.width - 28, 30);
    self.segmented.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    [self.segmented addTarget:self action:@selector(filterChanged) forControlEvents:UIControlEventValueChanged];
    [self.view addSubview:self.segmented];

    self.tableView = [[UITableView alloc] initWithFrame:CGRectMake(0, 46, self.view.bounds.size.width, self.view.bounds.size.height - 46) style:UITableViewStylePlain];
    self.tableView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    self.tableView.dataSource = self;
    self.tableView.delegate = self;
    self.tableView.rowHeight = 78;
    [KLTheme styleTableView:self.tableView];
    [self.view addSubview:self.tableView];

    self.emptyLabel = [KLComponents label:[KLTheme font:12] color:[KLTheme textSecondary]];
    self.emptyLabel.textAlignment = NSTextAlignmentCenter;
    self.emptyLabel.numberOfLines = 0;
    self.emptyLabel.frame = CGRectMake(30, 180, self.view.bounds.size.width - 60, 60);
    self.emptyLabel.text = @"还没有追番\n在番剧详情页点击「追番」即可收藏";
    [self.view addSubview:self.emptyLabel];

    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(reload) name:KLStoreDidChangeNotification object:nil];
    [self reload];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    self.navigationController.navigationBarHidden = NO;
    [self reload];
}

- (void)dealloc { [[NSNotificationCenter defaultCenter] removeObserver:self]; }

- (void)filterChanged {
    self.filter = self.segmented.selectedSegmentIndex;
    [self reload];
}

- (void)reload {
    NSArray *all = [[KLStore shared] collections];
    NSMutableArray *filtered = [NSMutableArray array];
    for (KLCollectionEntry *e in all) {
        if (self.filter == 0 ||
            (self.filter == 1 && e.collectType == 1) ||
            (self.filter == 2 && e.collectType == 2) ||
            (self.filter == 3 && (e.collectType == 4 || e.collectType == 5))) {
            [filtered addObject:e];
        }
    }
    self.items = filtered;
    [self.tableView reloadData];
    self.emptyLabel.hidden = self.items.count > 0;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section { return self.items.count; }

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    KLAnimeListCell *cell = [tableView dequeueReusableCellWithIdentifier:@"anime"];
    if (!cell) cell = [[KLAnimeListCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:@"anime"];
    KLCollectionEntry *entry = self.items[indexPath.row];
    [cell configureWithItem:entry.bangumi];
    cell.subtitleLabel.text = [NSString stringWithFormat:@"%@ · %@", [entry typeName], [KLComponents relativeTime:entry.updatedAt]];
    cell.detailLabel.text = entry.bangumi.tags.count ? [entry.bangumi.tags componentsJoinedByString:@" / "] : @"";
    cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    KLCollectionEntry *entry = self.items[indexPath.row];
    [self.navigationController pushViewController:[[KLDetailViewController alloc] initWithBangumi:entry.bangumi] animated:YES];
}

- (NSArray *)tableView:(UITableView *)tableView editActionsForRowAtIndexPath:(NSIndexPath *)indexPath {
    KLCollectionEntry *entry = self.items[indexPath.row];
    UITableViewRowAction *del = [UITableViewRowAction rowActionWithStyle:UITableViewRowActionStyleDestructive title:@"取消追番" handler:^(UITableViewRowAction *action, NSIndexPath *ip) {
        [[KLStore shared] removeCollectionForBangumi:entry.bangumi.bid];
        [self reload];
    }];
    return @[del];
}

@end
