#import <UIKit/UIKit.h>
#import <QuartzCore/QuartzCore.h>

extern NSString *const KLThemeDidChangeNotification;

@interface KLTheme : NSObject

+ (instancetype)shared;

@property (nonatomic, assign) BOOL darkMode;

+ (UIColor *)accent;
+ (UIColor *)accentSoft;
+ (UIColor *)background;
+ (UIColor *)card;
+ (UIColor *)bar;
+ (UIColor *)textPrimary;
+ (UIColor *)textSecondary;
+ (UIColor *)textTertiary;
+ (UIColor *)separator;
+ (UIColor *)success;
+ (UIColor *)warning;
+ (UIColor *)danger;
+ (UIColor *)overlay;

+ (UIColor *)colorWithHex:(NSUInteger)hex alpha:(CGFloat)alpha;
+ (CGFloat)screenWidth;
+ (CGFloat)screenHeight;

+ (UIFont *)font:(CGFloat)size;
+ (UIFont *)boldFont:(CGFloat)size;
+ (UIFont *)mediumFont:(CGFloat)size;

+ (void)applyGlobalAppearance;
+ (void)styleNavigationBar:(UINavigationBar *)bar;
+ (void)styleTableView:(UITableView *)tableView;
+ (void)applyCardStyle:(UIView *)view;
+ (void)applyCardStyle:(UIView *)view radius:(CGFloat)radius;
+ (void)showToast:(NSString *)message inView:(UIView *)view;

@end
