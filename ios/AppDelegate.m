#import "AppDelegate.h"
#import "KLTheme.h"
#import "KLComponents.h"
#import "KLStore.h"
#import "KLUpdater.h"
#import "KLBangumiAPI.h"
#import "KLHomeViewController.h"
#import "KLSearchViewController.h"
#import "KLCollectViewController.h"
#import "KLSettingsViewController.h"
#import "KLHistoryViewController.h"
#import "KLPlayerViewController.h"

@implementation AppDelegate

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
    self.window = [[UIWindow alloc] initWithFrame:[[UIScreen mainScreen] bounds]];
    self.window.backgroundColor = [KLTheme background];

    [[KLStore shared] prepare];
    [[KLBangumiAPI shared] setToken:[[KLStore shared] stringForKey:@"bangumiToken" defaultValue:@""]];
    [KLTheme applyGlobalAppearance];

    [self rebuildRootInterface];
    [self.window makeKeyAndVisible];

    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(themeChanged:) name:KLThemeDidChangeNotification object:nil];
    [KLUpdater cleanupStalePackages];

    if ([[KLStore shared] boolForKey:@"autoCheckUpdate" defaultValue:YES]) {
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(4.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            [KLUpdater checkForUpdateWithCompletion:^(NSDictionary *releaseInfo, NSError *error) {
                if (!releaseInfo || ![KLUpdater isReleaseNewer:releaseInfo]) return;
                UIAlertController *ac = [UIAlertController alertControllerWithTitle:@"发现新版本"
                                                                           message:[NSString stringWithFormat:@"%@ (Build %@)\n\n%@", releaseInfo[@"version"], releaseInfo[@"build"], releaseInfo[@"notes"] ?: @""]
                                                                    preferredStyle:UIAlertControllerStyleAlert];
                [ac addAction:[UIAlertAction actionWithTitle:@"稍后" style:UIAlertActionStyleCancel handler:nil]];
                [ac addAction:[UIAlertAction actionWithTitle:@"更新" style:UIAlertActionStyleDefault handler:^(UIAlertAction *a) {
                    [KLTheme showToast:@"正在下载更新…" inView:self.window];
                    [KLUpdater installRelease:releaseInfo progress:nil downloadProgress:nil completion:^(NSError *e) {
                        if (e) [KLTheme showToast:e.localizedDescription inView:self.window];
                        else {
                            UIAlertController *done = [UIAlertController alertControllerWithTitle:@"安装完成" message:@"应用将重新启动" preferredStyle:UIAlertControllerStyleAlert];
                            [done addAction:[UIAlertAction actionWithTitle:@"好" style:UIAlertActionStyleDefault handler:^(UIAlertAction *x) { [KLUpdater relaunchApplication]; }]];
                            [self.window.rootViewController presentViewController:done animated:YES completion:nil];
                        }
                    }];
                }]];
                [self.window.rootViewController presentViewController:ac animated:YES completion:nil];
            }];
        });
    }
    return YES;
}

- (void)rebuildRootInterface {
    KLHomeViewController *home = [[KLHomeViewController alloc] init];
    UINavigationController *homeNav = [self navWithRoot:home];
    homeNav.tabBarItem = [self tabItem:@"时间表" icon:KLIconCalendar];

    KLSearchViewController *search = [[KLSearchViewController alloc] init];
    UINavigationController *searchNav = [self navWithRoot:search];
    searchNav.tabBarItem = [self tabItem:@"发现" icon:KLIconCompass];

    KLCollectViewController *collect = [[KLCollectViewController alloc] init];
    UINavigationController *collectNav = [self navWithRoot:collect];
    collectNav.tabBarItem = [self tabItem:@"追番" icon:KLIconHeart];

    KLSettingsViewController *settings = [[KLSettingsViewController alloc] init];
    UINavigationController *settingsNav = [self navWithRoot:settings];
    settingsNav.tabBarItem = [self tabItem:@"我的" icon:KLIconUser];

    UITabBarController *tab = [[UITabBarController alloc] init];
    tab.viewControllers = @[homeNav, searchNav, collectNav, settingsNav];
    tab.tabBar.barTintColor = [KLTheme bar];
    tab.tabBar.tintColor = [KLTheme accent];
    tab.tabBar.translucent = NO;
    self.tabBarController = tab;
    self.window.rootViewController = tab;
}

- (UINavigationController *)navWithRoot:(UIViewController *)root {
    UINavigationController *nav = [[UINavigationController alloc] initWithRootViewController:root];
    [KLTheme styleNavigationBar:nav.navigationBar];
    return nav;
}

- (UITabBarItem *)tabItem:(NSString *)title icon:(KLIconType)icon {
    UIImage *image = [[KLComponents icon:icon size:24 color:[UIColor blackColor]] imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
    UITabBarItem *item = [[UITabBarItem alloc] initWithTitle:title image:image tag:0];
    item.titlePositionAdjustment = UIOffsetMake(0, -1);
    return item;
}

- (void)themeChanged:(NSNotification *)note {
    [KLTheme applyGlobalAppearance];
    [self rebuildRootInterface];
}

- (UIInterfaceOrientationMask)application:(UIApplication *)application supportedInterfaceOrientationsForWindow:(UIWindow *)window {
    UIViewController *presented = self.window.rootViewController.presentedViewController;
    if ([presented isKindOfClass:[KLPlayerViewController class]]) {
        return UIInterfaceOrientationMaskAllButUpsideDown;
    }
    return UIInterfaceOrientationMaskPortrait;
}

- (BOOL)application:(UIApplication *)application openURL:(NSURL *)url sourceApplication:(NSString *)sourceApplication annotation:(id)annotation {
    if ([url.scheme isEqualToString:@"kazumilite"] || [url.scheme isEqualToString:@"kazumi"]) {
        NSString *host = url.host;
        if ([host isEqualToString:@"rule"]) {
            NSString *ruleURL = nil;
            NSString *query = url.query;
            for (NSString *pair in [query componentsSeparatedByString:@"&"]) {
                NSArray *kv = [pair componentsSeparatedByString:@"="];
                if (kv.count == 2 && [kv[0] isEqualToString:@"url"]) {
                    ruleURL = [kv[1] stringByRemovingPercentEncoding];
                }
            }
            if (ruleURL.length) {
                [[NSNotificationCenter defaultCenter] postNotificationName:@"KLImportRuleURL" object:ruleURL];
                [KLTheme showToast:@"正在导入规则…" inView:self.window];
            }
        }
        return YES;
    }
    return NO;
}

@end
