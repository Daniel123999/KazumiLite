#import "KLTheme.h"

NSString *const KLThemeDidChangeNotification = @"KLThemeDidChangeNotification";

static UIColor *KLColor(NSUInteger hex, CGFloat alpha) {
    return [UIColor colorWithRed:((hex >> 16) & 0xFF) / 255.0
                           green:((hex >> 8) & 0xFF) / 255.0
                            blue:(hex & 0xFF) / 255.0
                           alpha:alpha];
}

@implementation KLTheme

+ (instancetype)shared {
    static KLTheme *theme = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        theme = [[KLTheme alloc] init];
        theme.darkMode = [[NSUserDefaults standardUserDefaults] boolForKey:@"kl.darkMode"];
    });
    return theme;
}

- (void)setDarkMode:(BOOL)darkMode {
    _darkMode = darkMode;
    [[NSUserDefaults standardUserDefaults] setBool:darkMode forKey:@"kl.darkMode"];
    [[NSUserDefaults standardUserDefaults] synchronize];
}

+ (UIColor *)accent {
    return [[KLTheme shared] darkMode] ? KLColor(0xFF6E93, 1) : KLColor(0xE94F7A, 1);
}
+ (UIColor *)accentSoft {
    return [[KLTheme shared] darkMode] ? KLColor(0x3A2029, 1) : KLColor(0xFDE8EF, 1);
}
+ (UIColor *)background {
    return [[KLTheme shared] darkMode] ? KLColor(0x111114, 1) : KLColor(0xF5F6FA, 1);
}
+ (UIColor *)card {
    return [[KLTheme shared] darkMode] ? KLColor(0x1C1C22, 1) : KLColor(0xFFFFFF, 1);
}
+ (UIColor *)bar {
    return [[KLTheme shared] darkMode] ? KLColor(0x18181D, 1) : KLColor(0xFFFFFF, 1);
}
+ (UIColor *)textPrimary {
    return [[KLTheme shared] darkMode] ? KLColor(0xF2F2F5, 1) : KLColor(0x1C1C22, 1);
}
+ (UIColor *)textSecondary {
    return [[KLTheme shared] darkMode] ? KLColor(0xA2A2AD, 1) : KLColor(0x777D88, 1);
}
+ (UIColor *)textTertiary {
    return [[KLTheme shared] darkMode] ? KLColor(0x777782, 1) : KLColor(0xA0A4AD, 1);
}
+ (UIColor *)separator {
    return [[KLTheme shared] darkMode] ? KLColor(0x2A2A33, 1) : KLColor(0xE8EAF0, 1);
}
+ (UIColor *)success { return KLColor(0x35B57A, 1); }
+ (UIColor *)warning { return KLColor(0xE8A23A, 1); }
+ (UIColor *)danger  { return KLColor(0xE5484D, 1); }
+ (UIColor *)overlay { return KLColor(0x000000, 0.55); }

+ (UIColor *)colorWithHex:(NSUInteger)hex alpha:(CGFloat)alpha {
    return KLColor(hex, alpha);
}

+ (CGFloat)screenWidth { return [UIScreen mainScreen].bounds.size.width; }
+ (CGFloat)screenHeight { return [UIScreen mainScreen].bounds.size.height; }

+ (UIFont *)font:(CGFloat)size { return [UIFont systemFontOfSize:size]; }
+ (UIFont *)boldFont:(CGFloat)size { return [UIFont boldSystemFontOfSize:size]; }
+ (UIFont *)mediumFont:(CGFloat)size { return [UIFont systemFontOfSize:size weight:UIFontWeightMedium]; }

+ (void)applyGlobalAppearance {
    [[UIApplication sharedApplication] setStatusBarStyle:([[KLTheme shared] darkMode]
        ? UIStatusBarStyleLightContent : UIStatusBarStyleDefault) animated:NO];
    [[UINavigationBar appearance] setBarTintColor:[KLTheme bar]];
    [[UINavigationBar appearance] setTintColor:[KLTheme accent]];
    [[UINavigationBar appearance] setTitleTextAttributes:@{
        NSForegroundColorAttributeName: [KLTheme textPrimary],
        NSFontAttributeName: [KLTheme boldFont:17]
    }];
    [[UINavigationBar appearance] setTranslucent:NO];
    [[UITabBar appearance] setBarTintColor:[KLTheme bar]];
    [[UITabBar appearance] setTintColor:[KLTheme accent]];
    [[UITabBar appearance] setTranslucent:NO];
    [[UILabel appearanceWhenContainedInInstancesOfClasses:@[[UITableView class]]]
        setTextColor:[KLTheme textPrimary]];
}

+ (void)styleNavigationBar:(UINavigationBar *)bar {
    bar.barTintColor = [KLTheme bar];
    bar.tintColor = [KLTheme accent];
    bar.translucent = NO;
    bar.titleTextAttributes = @{
        NSForegroundColorAttributeName: [KLTheme textPrimary],
        NSFontAttributeName: [KLTheme boldFont:17]
    };
    if ([bar respondsToSelector:@selector(setShadowImage:)]) {
        bar.shadowImage = [UIImage new];
    }
}

+ (void)styleTableView:(UITableView *)tableView {
    tableView.backgroundColor = [KLTheme background];
    tableView.separatorColor = [KLTheme separator];
    tableView.tableFooterView = [[UIView alloc] initWithFrame:CGRectZero];
}

+ (void)applyCardStyle:(UIView *)view {
    [self applyCardStyle:view radius:12];
}

+ (void)applyCardStyle:(UIView *)view radius:(CGFloat)radius {
    if (!view) return;
    view.backgroundColor = [KLTheme card];
    view.layer.cornerRadius = radius;
    view.layer.masksToBounds = YES;
    view.layer.borderWidth = 0.5;
    view.layer.borderColor = [[KLTheme separator] CGColor];
}

+ (void)showToast:(NSString *)message inView:(UIView *)view {
    if (message.length == 0) return;
    UIView *host = view ?: [UIApplication sharedApplication].keyWindow;
    if (!host) return;
    UILabel *label = [[UILabel alloc] init];
    label.text = message;
    label.font = [KLTheme font:13];
    label.textColor = [UIColor whiteColor];
    label.textAlignment = NSTextAlignmentCenter;
    label.numberOfLines = 0;
    label.backgroundColor = KLColor(0x000000, 0.82);
    label.layer.cornerRadius = 8;
    label.layer.masksToBounds = YES;
    CGSize maxSize = CGSizeMake(host.bounds.size.width - 80, 200);
    CGSize size = [message boundingRectWithSize:maxSize
                                        options:NSStringDrawingUsesLineFragmentOrigin
                                     attributes:@{NSFontAttributeName: label.font}
                                        context:nil].size;
    CGFloat width = ceil(size.width) + 28;
    CGFloat height = ceil(size.height) + 18;
    label.frame = CGRectMake((host.bounds.size.width - width) / 2,
                             host.bounds.size.height - height - 90,
                             width, height);
    label.alpha = 0;
    [host addSubview:label];
    [UIView animateWithDuration:0.16 animations:^{ label.alpha = 1; } completion:^(BOOL finished) {
        [UIView animateWithDuration:0.25 delay:1.5 options:0 animations:^{ label.alpha = 0; } completion:^(BOOL finished) {
            [label removeFromSuperview];
        }];
    }];
}

@end
