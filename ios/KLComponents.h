#import <UIKit/UIKit.h>
#import "KLModels.h"
#import "KLImageLoader.h"

typedef NS_ENUM(NSInteger, KLIconType) {
    KLIconCalendar = 0,
    KLIconCompass,
    KLIconHeart,
    KLIconUser,
    KLIconSearch,
    KLIconPlay,
    KLIconPause,
    KLIconBack,
    KLIconForward,
    KLIconChevron,
    KLIconChevronLeft,
    KLIconSettings,
    KLIconDownload,
    KLIconCloud,
    KLIconRefresh,
    KLIconClose,
    KLIconMore,
    KLIconCheck,
    KLIconDanmaku,
    KLIconList,
    KLIconExpand,
    KLIconShare,
    KLIconStar,
    KLIconTrash,
    KLIconPlus,
    KLIconEdit,
    KLIconLink,
    KLIconEye,
    KLIconEyeOff,
    KLIconCamera
};

@interface KLComponents : NSObject

+ (UIImage *)icon:(KLIconType)type size:(CGFloat)size color:(UIColor *)color;
+ (UILabel *)label:(UIFont *)font color:(UIColor *)color;
+ (UIButton *)iconButton:(KLIconType)type size:(CGFloat)size color:(UIColor *)color target:(id)target action:(SEL)action;
+ (UIButton *)filledButton:(NSString *)title target:(id)target action:(SEL)action;
+ (UIButton *)softButton:(NSString *)title target:(id)target action:(SEL)action;
+ (UIView *)hairline;
+ (UIView *)cardView;
+ (UIView *)emptyViewWithText:(NSString *)text;
+ (UIActivityIndicatorView *)spinner;
+ (void)showHUD:(NSString *)text inView:(UIView *)view;
+ (void)updateHUD:(NSString *)text inView:(UIView *)view;
+ (void)hideHUDInView:(UIView *)view;
+ (void)showTextSheet:(NSString *)title text:(NSString *)text inView:(UIView *)view;
+ (NSString *)formatCount:(NSInteger)count;
+ (NSString *)formatDuration:(double)seconds;
+ (NSString *)relativeTime:(NSTimeInterval)timestamp;
+ (NSString *)weekdayName:(NSInteger)weekday;
+ (CGFloat)heightForText:(NSString *)text width:(CGFloat)width font:(UIFont *)font;

@end

@interface KLAnimeCardCell : UICollectionViewCell
@property (nonatomic, strong) KLAsyncImageView *coverView;
@property (nonatomic, strong) UILabel *titleLabel;
@property (nonatomic, strong) UILabel *subLabel;
@property (nonatomic, strong) UILabel *badgeLabel;
- (void)configureWithItem:(KLBangumiItem *)item;
@end

@interface KLAnimeListCell : UITableViewCell
@property (nonatomic, strong) KLAsyncImageView *coverView;
@property (nonatomic, strong) UILabel *titleLabel;
@property (nonatomic, strong) UILabel *subtitleLabel;
@property (nonatomic, strong) UILabel *detailLabel;
- (void)configureWithItem:(KLBangumiItem *)item;
@end
