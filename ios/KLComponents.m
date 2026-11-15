#import "KLComponents.h"
#import "KLTheme.h"
#import "KLImageLoader.h"

@implementation KLComponents

+ (UIViewController *)viewControllerForView:(UIView *)view {
    UIResponder *r = view;
    while (r && ![r isKindOfClass:[UIViewController class]]) r = r.nextResponder;
    return (UIViewController *)r;
}

+ (UIImage *)icon:(KLIconType)type size:(CGFloat)size color:(UIColor *)color {
    UIGraphicsBeginImageContextWithOptions(CGSizeMake(size, size), NO, 0);
    CGContextRef ctx = UIGraphicsGetCurrentContext();
    CGContextSetStrokeColorWithColor(ctx, color.CGColor);
    CGContextSetFillColorWithColor(ctx, color.CGColor);
    CGContextSetLineWidth(ctx, MAX(1.4, size / 14.0));
    CGContextSetLineCap(ctx, kCGLineCapRound);
    CGContextSetLineJoin(ctx, kCGLineJoinRound);
    CGFloat s = size / 24.0;
    CGContextScaleCTM(ctx, s, s);

    UIBezierPath *p = [UIBezierPath bezierPath];
    switch (type) {
        case KLIconCalendar:
            [p moveToPoint:CGPointMake(4, 6)]; [p addLineToPoint:CGPointMake(20, 6)];
            [p moveToPoint:CGPointMake(6, 3)]; [p addLineToPoint:CGPointMake(6, 8)];
            [p moveToPoint:CGPointMake(18, 3)]; [p addLineToPoint:CGPointMake(18, 8)];
            [p appendPath:[UIBezierPath bezierPathWithRoundedRect:CGRectMake(3, 5, 18, 16) cornerRadius:3]];
            [p moveToPoint:CGPointMake(3, 10)]; [p addLineToPoint:CGPointMake(21, 10)];
            break;
        case KLIconCompass:
            [p appendPath:[UIBezierPath bezierPathWithOvalInRect:CGRectMake(3, 3, 18, 18)]];
            [p moveToPoint:CGPointMake(15.5, 8.5)]; [p addLineToPoint:CGPointMake(13, 13)];
            [p addLineToPoint:CGPointMake(8.5, 15.5)]; [p addLineToPoint:CGPointMake(11, 11)];
            [p closePath];
            break;
        case KLIconHeart:
            [p moveToPoint:CGPointMake(12, 20)];
            [p addCurveToPoint:CGPointMake(4, 12.5) controlPoint1:CGPointMake(9, 17.5) controlPoint2:CGPointMake(4, 15.5)];
            [p addCurveToPoint:CGPointMake(12, 6) controlPoint1:CGPointMake(4, 7) controlPoint2:CGPointMake(8, 5)];
            [p addCurveToPoint:CGPointMake(20, 12.5) controlPoint1:CGPointMake(16, 5) controlPoint2:CGPointMake(20, 7)];
            [p addCurveToPoint:CGPointMake(12, 20) controlPoint1:CGPointMake(20, 15.5) controlPoint2:CGPointMake(15, 17.5)];
            break;
        case KLIconUser:
            [p appendPath:[UIBezierPath bezierPathWithOvalInRect:CGRectMake(8, 3.5, 8, 8)]];
            [p moveToPoint:CGPointMake(4.5, 21)];
            [p addCurveToPoint:CGPointMake(19.5, 21) controlPoint1:CGPointMake(5, 14.5) controlPoint2:CGPointMake(19, 14.5)];
            break;
        case KLIconSearch:
            [p appendPath:[UIBezierPath bezierPathWithOvalInRect:CGRectMake(3.5, 3.5, 12, 12)]];
            [p moveToPoint:CGPointMake(15, 15)]; [p addLineToPoint:CGPointMake(21, 21)];
            break;
        case KLIconPlay:
            [p moveToPoint:CGPointMake(7, 4)]; [p addLineToPoint:CGPointMake(20, 12)];
            [p addLineToPoint:CGPointMake(7, 20)]; [p closePath];
            break;
        case KLIconPause:
            [p moveToPoint:CGPointMake(8, 4)]; [p addLineToPoint:CGPointMake(8, 20)];
            [p moveToPoint:CGPointMake(16, 4)]; [p addLineToPoint:CGPointMake(16, 20)];
            break;
        case KLIconBack:
            [p moveToPoint:CGPointMake(15, 4)]; [p addLineToPoint:CGPointMake(7, 12)];
            [p addLineToPoint:CGPointMake(15, 20)];
            break;
        case KLIconForward:
            [p moveToPoint:CGPointMake(9, 4)]; [p addLineToPoint:CGPointMake(17, 12)];
            [p addLineToPoint:CGPointMake(9, 20)];
            break;
        case KLIconChevron:
            [p moveToPoint:CGPointMake(9, 5)]; [p addLineToPoint:CGPointMake(16, 12)];
            [p addLineToPoint:CGPointMake(9, 19)];
            break;
        case KLIconChevronLeft:
            [p moveToPoint:CGPointMake(15, 5)]; [p addLineToPoint:CGPointMake(8, 12)];
            [p addLineToPoint:CGPointMake(15, 19)];
            break;
        case KLIconSettings:
            [p appendPath:[UIBezierPath bezierPathWithOvalInRect:CGRectMake(8.5, 8.5, 7, 7)]];
            [p appendPath:[UIBezierPath bezierPathWithOvalInRect:CGRectMake(3.5, 3.5, 17, 17)]];
            [p moveToPoint:CGPointMake(12, 1)]; [p addLineToPoint:CGPointMake(12, 3.5)];
            [p moveToPoint:CGPointMake(12, 20.5)]; [p addLineToPoint:CGPointMake(12, 23)];
            [p moveToPoint:CGPointMake(1, 12)]; [p addLineToPoint:CGPointMake(3.5, 12)];
            [p moveToPoint:CGPointMake(20.5, 12)]; [p addLineToPoint:CGPointMake(23, 12)];
            break;
        case KLIconDownload:
            [p moveToPoint:CGPointMake(12, 3)]; [p addLineToPoint:CGPointMake(12, 15)];
            [p moveToPoint:CGPointMake(7, 10)]; [p addLineToPoint:CGPointMake(12, 15)];
            [p addLineToPoint:CGPointMake(17, 10)];
            [p moveToPoint:CGPointMake(4, 19)]; [p addLineToPoint:CGPointMake(4, 21)];
            [p addLineToPoint:CGPointMake(20, 21)]; [p addLineToPoint:CGPointMake(20, 19)];
            break;
        case KLIconCloud:
            [p moveToPoint:CGPointMake(7, 18)];
            [p addCurveToPoint:CGPointMake(5, 10) controlPoint1:CGPointMake(2, 18) controlPoint2:CGPointMake(1, 13)];
            [p addCurveToPoint:CGPointMake(13, 7) controlPoint1:CGPointMake(6, 6) controlPoint2:CGPointMake(10, 5)];
            [p addCurveToPoint:CGPointMake(19, 12) controlPoint1:CGPointMake(17, 7) controlPoint2:CGPointMake(20, 9)];
            [p addCurveToPoint:CGPointMake(17, 18) controlPoint1:CGPointMake(22, 15) controlPoint2:CGPointMake(20, 18)];
            [p addLineToPoint:CGPointMake(7, 18)];
            break;
        case KLIconRefresh:
            [p appendPath:[UIBezierPath bezierPathWithArcCenter:CGPointMake(12, 12) radius:8 startAngle:-1.2 endAngle:4.2 clockwise:YES]];
            [p moveToPoint:CGPointMake(17, 2.8)]; [p addLineToPoint:CGPointMake(19.6, 6.5)];
            [p addLineToPoint:CGPointMake(15.6, 7.2)];
            break;
        case KLIconClose:
            [p moveToPoint:CGPointMake(6, 6)]; [p addLineToPoint:CGPointMake(18, 18)];
            [p moveToPoint:CGPointMake(18, 6)]; [p addLineToPoint:CGPointMake(6, 18)];
            break;
        case KLIconMore:
            [p appendPath:[UIBezierPath bezierPathWithOvalInRect:CGRectMake(3, 10.5, 3, 3)]];
            [p appendPath:[UIBezierPath bezierPathWithOvalInRect:CGRectMake(10.5, 10.5, 3, 3)]];
            [p appendPath:[UIBezierPath bezierPathWithOvalInRect:CGRectMake(18, 10.5, 3, 3)]];
            break;
        case KLIconCheck:
            [p moveToPoint:CGPointMake(4, 12)]; [p addLineToPoint:CGPointMake(9, 17)];
            [p addLineToPoint:CGPointMake(20, 6)];
            break;
        case KLIconDanmaku:
            [p appendPath:[UIBezierPath bezierPathWithRoundedRect:CGRectMake(3, 4, 18, 13) cornerRadius:3]];
            [p moveToPoint:CGPointMake(7, 17)]; [p addLineToPoint:CGPointMake(6, 21)];
            [p addLineToPoint:CGPointMake(10, 17)];
            [p moveToPoint:CGPointMake(7, 9)]; [p addLineToPoint:CGPointMake(17, 9)];
            [p moveToPoint:CGPointMake(7, 12.5)]; [p addLineToPoint:CGPointMake(14, 12.5)];
            break;
        case KLIconList:
            [p moveToPoint:CGPointMake(4, 6)]; [p addLineToPoint:CGPointMake(20, 6)];
            [p moveToPoint:CGPointMake(4, 12)]; [p addLineToPoint:CGPointMake(20, 12)];
            [p moveToPoint:CGPointMake(4, 18)]; [p addLineToPoint:CGPointMake(20, 18)];
            break;
        case KLIconExpand:
            [p moveToPoint:CGPointMake(4, 9)]; [p addLineToPoint:CGPointMake(4, 4)];
            [p addLineToPoint:CGPointMake(9, 4)];
            [p moveToPoint:CGPointMake(15, 4)]; [p addLineToPoint:CGPointMake(20, 4)];
            [p addLineToPoint:CGPointMake(20, 9)];
            [p moveToPoint:CGPointMake(20, 15)]; [p addLineToPoint:CGPointMake(20, 20)];
            [p addLineToPoint:CGPointMake(15, 20)];
            [p moveToPoint:CGPointMake(9, 20)]; [p addLineToPoint:CGPointMake(4, 20)];
            [p addLineToPoint:CGPointMake(4, 15)];
            break;
        case KLIconShare:
            [p moveToPoint:CGPointMake(12, 3)]; [p addLineToPoint:CGPointMake(12, 15)];
            [p moveToPoint:CGPointMake(8, 7)]; [p addLineToPoint:CGPointMake(12, 3)];
            [p addLineToPoint:CGPointMake(16, 7)];
            [p moveToPoint:CGPointMake(5, 12)]; [p addLineToPoint:CGPointMake(5, 20)];
            [p addLineToPoint:CGPointMake(19, 20)]; [p addLineToPoint:CGPointMake(19, 12)];
            break;
        case KLIconStar:
            [p moveToPoint:CGPointMake(12, 3)]; [p addLineToPoint:CGPointMake(14.7, 9)];
            [p addLineToPoint:CGPointMake(21, 9.7)]; [p addLineToPoint:CGPointMake(16.2, 14)];
            [p addLineToPoint:CGPointMake(17.6, 20.5)]; [p addLineToPoint:CGPointMake(12, 17.2)];
            [p addLineToPoint:CGPointMake(6.4, 20.5)]; [p addLineToPoint:CGPointMake(7.8, 14)];
            [p addLineToPoint:CGPointMake(3, 9.7)]; [p addLineToPoint:CGPointMake(9.3, 9)];
            [p closePath];
            break;
        case KLIconTrash:
            [p moveToPoint:CGPointMake(5, 7)]; [p addLineToPoint:CGPointMake(19, 7)];
            [p moveToPoint:CGPointMake(9, 4)]; [p addLineToPoint:CGPointMake(15, 4)];
            [p moveToPoint:CGPointMake(7, 7)]; [p addLineToPoint:CGPointMake(8, 21)];
            [p addLineToPoint:CGPointMake(16, 21)]; [p addLineToPoint:CGPointMake(17, 7)];
            break;
        case KLIconPlus:
            [p moveToPoint:CGPointMake(12, 4)]; [p addLineToPoint:CGPointMake(12, 20)];
            [p moveToPoint:CGPointMake(4, 12)]; [p addLineToPoint:CGPointMake(20, 12)];
            break;
        case KLIconEdit:
            [p moveToPoint:CGPointMake(4, 20)]; [p addLineToPoint:CGPointMake(4, 16)];
            [p addLineToPoint:CGPointMake(16, 4)]; [p addLineToPoint:CGPointMake(20, 8)];
            [p addLineToPoint:CGPointMake(8, 20)]; [p closePath];
            break;
        case KLIconLink:
            [p moveToPoint:CGPointMake(10, 14)];
            [p addCurveToPoint:CGPointMake(16, 14) controlPoint1:CGPointMake(12, 16) controlPoint2:CGPointMake(14, 16)];
            [p addLineToPoint:CGPointMake(19, 11)];
            [p addCurveToPoint:CGPointMake(13, 5) controlPoint1:CGPointMake(21, 9) controlPoint2:CGPointMake(17, 3)];
            [p addLineToPoint:CGPointMake(10, 8)];
            [p moveToPoint:CGPointMake(14, 10)];
            [p addCurveToPoint:CGPointMake(8, 10) controlPoint1:CGPointMake(12, 8) controlPoint2:CGPointMake(10, 8)];
            [p addLineToPoint:CGPointMake(5, 13)];
            [p addCurveToPoint:CGPointMake(11, 19) controlPoint1:CGPointMake(3, 15) controlPoint2:CGPointMake(7, 21)];
            [p addLineToPoint:CGPointMake(14, 16)];
            break;
        case KLIconEye:
            [p moveToPoint:CGPointMake(2, 12)];
            [p addCurveToPoint:CGPointMake(22, 12) controlPoint1:CGPointMake(7, 4) controlPoint2:CGPointMake(17, 4)];
            [p addCurveToPoint:CGPointMake(2, 12) controlPoint1:CGPointMake(17, 20) controlPoint2:CGPointMake(7, 20)];
            [p appendPath:[UIBezierPath bezierPathWithOvalInRect:CGRectMake(9, 9, 6, 6)]];
            break;
        case KLIconEyeOff:
            [p moveToPoint:CGPointMake(3, 3)]; [p addLineToPoint:CGPointMake(21, 21)];
            [p moveToPoint:CGPointMake(2, 12)];
            [p addCurveToPoint:CGPointMake(14, 17) controlPoint1:CGPointMake(5, 18) controlPoint2:CGPointMake(10, 18)];
            [p moveToPoint:CGPointMake(22, 12)];
            [p addCurveToPoint:CGPointMake(10, 7) controlPoint1:CGPointMake(19, 6) controlPoint2:CGPointMake(14, 6)];
            break;
        case KLIconCamera:
            [p appendPath:[UIBezierPath bezierPathWithRoundedRect:CGRectMake(3, 6, 18, 14) cornerRadius:3]];
            [p appendPath:[UIBezierPath bezierPathWithOvalInRect:CGRectMake(9, 9.5, 6, 6)]];
            [p moveToPoint:CGPointMake(8, 6)]; [p addLineToPoint:CGPointMake(9.5, 3.5)];
            [p addLineToPoint:CGPointMake(14.5, 3.5)]; [p addLineToPoint:CGPointMake(16, 6)];
            break;
        default:
            break;
    }
    [p stroke];
    if (type == KLIconPlay || type == KLIconHeart || type == KLIconStar) {
        // leave outline style for consistency
    }
    UIImage *image = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return image;
}

+ (UILabel *)label:(UIFont *)font color:(UIColor *)color {
    UILabel *l = [[UILabel alloc] init];
    l.font = font ?: [KLTheme font:14];
    l.textColor = color ?: [KLTheme textPrimary];
    l.backgroundColor = [UIColor clearColor];
    return l;
}

+ (UIButton *)iconButton:(KLIconType)type size:(CGFloat)size color:(UIColor *)color target:(id)target action:(SEL)action {
    UIButton *b = [UIButton buttonWithType:UIButtonTypeCustom];
    b.frame = CGRectMake(0, 0, 34, 34);
    [b setImage:[self icon:type size:size color:color ?: [KLTheme textPrimary]] forState:UIControlStateNormal];
    if (target && action) [b addTarget:target action:action forControlEvents:UIControlEventTouchUpInside];
    return b;
}

+ (UIButton *)filledButton:(NSString *)title target:(id)target action:(SEL)action {
    UIButton *b = [UIButton buttonWithType:UIButtonTypeCustom];
    b.backgroundColor = [KLTheme accent];
    [b setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    b.titleLabel.font = [KLTheme boldFont:14];
    b.layer.cornerRadius = 9;
    [b setTitle:title forState:UIControlStateNormal];
    b.frame = CGRectMake(0, 0, 110, 36);
    if (target && action) [b addTarget:target action:action forControlEvents:UIControlEventTouchUpInside];
    return b;
}

+ (UIButton *)softButton:(NSString *)title target:(id)target action:(SEL)action {
    UIButton *b = [UIButton buttonWithType:UIButtonTypeCustom];
    b.backgroundColor = [KLTheme accentSoft];
    [b setTitleColor:[KLTheme accent] forState:UIControlStateNormal];
    b.titleLabel.font = [KLTheme mediumFont:13];
    b.layer.cornerRadius = 9;
    [b setTitle:title forState:UIControlStateNormal];
    b.frame = CGRectMake(0, 0, 110, 34);
    if (target && action) [b addTarget:target action:action forControlEvents:UIControlEventTouchUpInside];
    return b;
}

+ (UIView *)hairline {
    UIView *v = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 0, 0.5)];
    v.backgroundColor = [KLTheme separator];
    return v;
}

+ (UIView *)cardView {
    UIView *v = [[UIView alloc] init];
    [KLTheme applyCardStyle:v];
    return v;
}

+ (UIView *)emptyViewWithText:(NSString *)text {
    UIView *v = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 200, 120)];
    UIImageView *icon = [[UIImageView alloc] initWithImage:[self icon:KLIconCompass size:42 color:[KLTheme textTertiary]]];
    icon.frame = CGRectMake(79, 16, 42, 42);
    [v addSubview:icon];
    UILabel *l = [self label:[KLTheme font:13] color:[KLTheme textSecondary]];
    l.text = text;
    l.textAlignment = NSTextAlignmentCenter;
    l.numberOfLines = 0;
    l.frame = CGRectMake(0, 68, 200, 40);
    [v addSubview:l];
    return v;
}

+ (UIActivityIndicatorView *)spinner {
    UIActivityIndicatorView *s = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleGray];
    s.hidesWhenStopped = YES;
    return s;
}

+ (void)showHUD:(NSString *)text inView:(UIView *)view {
    if (!view) return;
    [self hideHUDInView:view];
    UIView *hud = [[UIView alloc] initWithFrame:view.bounds];
    hud.tag = 0x4B4C4844;
    hud.backgroundColor = [UIColor clearColor];
    UIView *box = [[UIView alloc] initWithFrame:CGRectMake((view.bounds.size.width - 150) / 2, (view.bounds.size.height - 90) / 2, 150, 90)];
    box.backgroundColor = [KLTheme colorWithHex:0x000000 alpha:0.78];
    box.layer.cornerRadius = 12;
    UIActivityIndicatorView *sp = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleWhiteLarge];
    sp.center = CGPointMake(75, 36);
    [sp startAnimating];
    [box addSubview:sp];
    UILabel *l = [self label:[KLTheme font:12] color:[UIColor whiteColor]];
    l.tag = 0x4B4C4854;
    l.text = text;
    l.textAlignment = NSTextAlignmentCenter;
    l.frame = CGRectMake(8, 58, 134, 24);
    [box addSubview:l];
    [hud addSubview:box];
    [view addSubview:hud];
}

+ (void)updateHUD:(NSString *)text inView:(UIView *)view {
    UIView *hud = [view viewWithTag:0x4B4C4844];
    UILabel *l = (UILabel *)[hud viewWithTag:0x4B4C4854];
    if (l) l.text = text;
}

+ (void)hideHUDInView:(UIView *)view {
    UIView *hud = [view viewWithTag:0x4B4C4844];
    [hud removeFromSuperview];
}

+ (void)showTextSheet:(NSString *)title text:(NSString *)text inView:(UIView *)view {
    UIAlertController *ac = [UIAlertController alertControllerWithTitle:title message:text preferredStyle:UIAlertControllerStyleAlert];
    [ac addAction:[UIAlertAction actionWithTitle:@"复制" style:UIAlertActionStyleDefault handler:^(UIAlertAction *a) {
        [[UIPasteboard generalPasteboard] setString:text ?: @""];
    }]];
    [ac addAction:[UIAlertAction actionWithTitle:@"关闭" style:UIAlertActionStyleCancel handler:nil]];
    UIViewController *vc = view ? [self viewControllerForView:view] : nil;
    [vc presentViewController:ac animated:YES completion:nil];
}

+ (NSString *)formatCount:(NSInteger)count {
    if (count >= 100000000) return [NSString stringWithFormat:@"%.1f亿", count / 100000000.0];
    if (count >= 10000) return [NSString stringWithFormat:@"%.1f万", count / 10000.0];
    return [NSString stringWithFormat:@"%ld", (long)count];
}

+ (NSString *)formatDuration:(double)seconds {
    if (seconds <= 0 || isinf(seconds) || isnan(seconds)) return @"00:00";
    NSInteger total = (NSInteger)seconds;
    NSInteger h = total / 3600;
    NSInteger m = (total % 3600) / 60;
    NSInteger s = total % 60;
    if (h > 0) return [NSString stringWithFormat:@"%ld:%02ld:%02ld", (long)h, (long)m, (long)s];
    return [NSString stringWithFormat:@"%02ld:%02ld", (long)m, (long)s];
}

+ (NSString *)relativeTime:(NSTimeInterval)timestamp {
    if (timestamp <= 0) return @"";
    NSTimeInterval delta = [[NSDate date] timeIntervalSince1970] - timestamp;
    if (delta < 60) return @"刚刚";
    if (delta < 3600) return [NSString stringWithFormat:@"%ld 分钟前", (long)(delta / 60)];
    if (delta < 86400) return [NSString stringWithFormat:@"%ld 小时前", (long)(delta / 3600)];
    if (delta < 86400 * 7) return [NSString stringWithFormat:@"%ld 天前", (long)(delta / 86400)];
    NSDateFormatter *f = [[NSDateFormatter alloc] init];
    f.dateFormat = @"yyyy-MM-dd";
    return [f stringFromDate:[NSDate dateWithTimeIntervalSince1970:timestamp]];
}

+ (NSString *)weekdayName:(NSInteger)weekday {
    NSArray *names = @[@"周一", @"周二", @"周三", @"周四", @"周五", @"周六", @"周日"];
    if (weekday >= 1 && weekday <= 7) return names[weekday - 1];
    return @"";
}

+ (CGFloat)heightForText:(NSString *)text width:(CGFloat)width font:(UIFont *)font {
    if (!text.length) return 0;
    return ceil([text boundingRectWithSize:CGSizeMake(width, CGFLOAT_MAX)
                                    options:NSStringDrawingUsesLineFragmentOrigin
                                 attributes:@{NSFontAttributeName: font}
                                    context:nil].size.height);
}

@end

@implementation KLAnimeCardCell

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        self.contentView.backgroundColor = [UIColor clearColor];
        _coverView = [[KLAsyncImageView alloc] initWithFrame:CGRectMake(0, 0, frame.size.width, frame.size.height - 38)];
        _coverView.layer.cornerRadius = 8;
        _coverView.clipsToBounds = YES;
        [self.contentView addSubview:_coverView];

        _badgeLabel = [KLComponents label:[KLTheme font:9] color:[UIColor whiteColor]];
        _badgeLabel.backgroundColor = [KLTheme colorWithHex:0x000000 alpha:0.62];
        _badgeLabel.textAlignment = NSTextAlignmentCenter;
        _badgeLabel.layer.cornerRadius = 4;
        _badgeLabel.layer.masksToBounds = YES;
        _badgeLabel.frame = CGRectMake(4, 4, 34, 15);
        [_coverView addSubview:_badgeLabel];

        _titleLabel = [KLComponents label:[KLTheme mediumFont:12] color:[KLTheme textPrimary]];
        _titleLabel.numberOfLines = 2;
        _titleLabel.frame = CGRectMake(0, frame.size.height - 36, frame.size.width, 32);
        [self.contentView addSubview:_titleLabel];

        _subLabel = [KLComponents label:[KLTheme font:10] color:[KLTheme textSecondary]];
        _subLabel.frame = CGRectMake(0, frame.size.height - 15, frame.size.width, 14);
        [self.contentView addSubview:_subLabel];
    }
    return self;
}

- (void)configureWithItem:(KLBangumiItem *)item {
    self.coverView.imageURL = item.imageCommon.length ? item.imageCommon : item.imageLarge;
    self.titleLabel.text = [item displayName];
    self.subLabel.text = item.rating > 0 ? [NSString stringWithFormat:@"★ %.1f", item.rating] : @"";
    self.badgeLabel.hidden = item.rating <= 0;
    self.badgeLabel.text = item.rating > 0 ? [NSString stringWithFormat:@"%.1f", item.rating] : @"";
}

- (void)prepareForReuse {
    [super prepareForReuse];
    [self.coverView cancelLoading];
    self.coverView.image = nil;
    self.titleLabel.text = nil;
    self.subLabel.text = nil;
}

@end

@implementation KLAnimeListCell

- (instancetype)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier {
    self = [super initWithStyle:style reuseIdentifier:reuseIdentifier];
    if (self) {
        self.backgroundColor = [KLTheme card];
        _coverView = [[KLAsyncImageView alloc] initWithFrame:CGRectMake(12, 8, 44, 62)];
        _coverView.layer.cornerRadius = 5;
        _coverView.clipsToBounds = YES;
        [self.contentView addSubview:_coverView];

        _titleLabel = [KLComponents label:[KLTheme mediumFont:13] color:[KLTheme textPrimary]];
        _titleLabel.numberOfLines = 2;
        _titleLabel.frame = CGRectMake(68, 8, self.contentView.bounds.size.width - 82, 36);
        _titleLabel.autoresizingMask = UIViewAutoresizingFlexibleWidth;
        [self.contentView addSubview:_titleLabel];

        _subtitleLabel = [KLComponents label:[KLTheme font:10] color:[KLTheme textSecondary]];
        _subtitleLabel.frame = CGRectMake(68, 44, self.contentView.bounds.size.width - 82, 16);
        _subtitleLabel.autoresizingMask = UIViewAutoresizingFlexibleWidth;
        [self.contentView addSubview:_subtitleLabel];

        _detailLabel = [KLComponents label:[KLTheme font:10] color:[KLTheme accent]];
        _detailLabel.frame = CGRectMake(68, 60, self.contentView.bounds.size.width - 82, 14);
        _detailLabel.autoresizingMask = UIViewAutoresizingFlexibleWidth;
        [self.contentView addSubview:_detailLabel];
    }
    return self;
}

- (void)configureWithItem:(KLBangumiItem *)item {
    self.coverView.imageURL = item.imageCommon.length ? item.imageCommon : item.imageLarge;
    self.titleLabel.text = [item displayName];
    self.subtitleLabel.text = [NSString stringWithFormat:@"★ %.1f · %@", item.rating, item.airDate.length ? item.airDate : @"放送未知"];
    NSArray *tags = item.tags;
    self.detailLabel.text = tags.count ? [tags componentsJoinedByString:@" / "] : @"";
}

- (void)prepareForReuse {
    [super prepareForReuse];
    [self.coverView cancelLoading];
    self.coverView.image = nil;
    self.titleLabel.text = nil;
    self.subtitleLabel.text = nil;
    self.detailLabel.text = nil;
}

@end
