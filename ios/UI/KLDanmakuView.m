#import "KLDanmakuView.h"
#import "KLStore.h"
#import "KLTheme.h"

@interface KLDanmakuItem : NSObject
@property (nonatomic, copy) NSString *text;
@property (nonatomic, assign) double start;
@property (nonatomic, assign) double duration;
@property (nonatomic, assign) NSInteger mode;
@property (nonatomic, strong) UIColor *color;
@property (nonatomic, assign) NSInteger lane;
@property (nonatomic, assign) CGFloat width;
@property (nonatomic, assign) CGFloat y;
@end
@implementation KLDanmakuItem
@end

@interface KLDanmakuView ()
@property (nonatomic, strong) NSMutableArray *active;
@property (nonatomic, strong) NSArray *sortedEntries;
@property (nonatomic, assign) NSInteger pointer;
@property (nonatomic, assign) NSTimeInterval lastWallTime;
@property (nonatomic, assign) BOOL needsReset;
@property (nonatomic, strong) NSTimer *timer;
@property (nonatomic, assign) CGFloat fontSize;
@property (nonatomic, assign) CGFloat opacity;
@property (nonatomic, assign) CGFloat duration;
@property (nonatomic, assign) CGFloat area;
@property (nonatomic, assign) BOOL showScroll;
@property (nonatomic, assign) BOOL showTop;
@property (nonatomic, assign) BOOL showBottom;
@property (nonatomic, assign) BOOL showBorder;
@property (nonatomic, assign) BOOL dedup;
@property (nonatomic, assign) BOOL followSpeed;
@property (nonatomic, assign) NSInteger lineCount;
@property (nonatomic, strong) NSMutableArray *scrollLaneFree;
@property (nonatomic, strong) NSMutableArray *topLaneFree;
@property (nonatomic, strong) NSMutableArray *bottomLaneFree;
@property (nonatomic, copy) NSArray *shieldKeywords;
@end

@implementation KLDanmakuView

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        self.backgroundColor = [UIColor clearColor];
        self.userInteractionEnabled = NO;
        self.clipsToBounds = YES;
        _active = [NSMutableArray array];
        _sortedEntries = @[];
        _scrollLaneFree = [NSMutableArray array];
        _topLaneFree = [NSMutableArray array];
        _bottomLaneFree = [NSMutableArray array];
        [self reloadSettings];
    }
    return self;
}

- (void)dealloc { [_timer invalidate]; }

- (void)willMoveToWindow:(UIWindow *)newWindow {
    [super willMoveToWindow:newWindow];
    if (newWindow) {
        if (!self.timer) {
            self.timer = [NSTimer timerWithTimeInterval:1.0 / 30.0 target:self selector:@selector(tick:) userInfo:nil repeats:YES];
        }
        [[NSRunLoop mainRunLoop] addTimer:self.timer forMode:NSRunLoopCommonModes];
    } else {
        [self.timer invalidate];
        self.timer = nil;
    }
}

- (void)reloadSettings {
    KLStore *store = [KLStore shared];
    self.fontSize = MAX(12, [store doubleForKey:@"danmakuFontSize" defaultValue:16]);
    self.opacity = [store doubleForKey:@"danmakuOpacity" defaultValue:1.0];
    self.duration = MAX(3, [store doubleForKey:@"danmakuDuration" defaultValue:8.0]);
    self.area = [store doubleForKey:@"danmakuArea" defaultValue:1.0];
    self.showScroll = [store boolForKey:@"danmakuScroll" defaultValue:YES];
    self.showTop = [store boolForKey:@"danmakuTop" defaultValue:YES];
    self.showBottom = [store boolForKey:@"danmakuBottom" defaultValue:NO];
    self.showBorder = [store boolForKey:@"danmakuBorder" defaultValue:YES];
    self.dedup = [store boolForKey:@"danmakuDedup" defaultValue:NO];
    self.followSpeed = [store boolForKey:@"danmakuFollowSpeed" defaultValue:YES];
    NSString *keywords = [store stringForKey:@"danmakuShield" defaultValue:@""];
    self.shieldKeywords = [keywords componentsSeparatedByCharactersInSet:[NSCharacterSet characterSetWithCharactersInString:@",，"]];
    [self rebuildLanes];
    [self setNeedsDisplay];
}

- (void)rebuildLanes {
    CGFloat lineHeight = self.fontSize * 1.4;
    CGFloat usable = CGRectGetHeight(self.bounds) * MAX(0.2, MIN(1.0, self.area)) - 12;
    self.lineCount = MAX(1, (NSInteger)floor(usable / lineHeight));
    [self.scrollLaneFree removeAllObjects];
    [self.topLaneFree removeAllObjects];
    [self.bottomLaneFree removeAllObjects];
    NSInteger topCount = MAX(1, self.lineCount / 2);
    for (NSInteger i = 0; i < self.lineCount; i++) [self.scrollLaneFree addObject:@(0)];
    for (NSInteger i = 0; i < topCount; i++) [self.topLaneFree addObject:@(0)];
    for (NSInteger i = 0; i < topCount; i++) [self.bottomLaneFree addObject:@(0)];
}

- (void)setEntries:(NSArray *)entries {
    _entries = [entries copy];
    NSMutableArray *filtered = [NSMutableArray array];
    NSMutableSet *seen = [NSMutableSet set];
    for (KLDanmakuEntry *e in entries) {
        if (![e isKindOfClass:[KLDanmakuEntry class]] || e.text.length == 0) continue;
        NSString *text = [e.text stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
        if (text.length == 0) continue;
        BOOL blocked = NO;
        for (NSString *kw in self.shieldKeywords) {
            NSString *k = [kw stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
            if (k.length && [text containsString:k]) { blocked = YES; break; }
        }
        if (blocked) continue;
        if (self.dedup) {
            NSInteger bucket = (NSInteger)(e.time / 5.0);
            NSString *key = [NSString stringWithFormat:@"%@#%ld", text, (long)bucket];
            if ([seen containsObject:key]) continue;
            [seen addObject:key];
        }
        [filtered addObject:e];
    }
    [filtered sortUsingComparator:^NSComparisonResult(KLDanmakuEntry *a, KLDanmakuEntry *b) {
        if (a.time < b.time) return NSOrderedAscending;
        if (a.time > b.time) return NSOrderedDescending;
        return NSOrderedSame;
    }];
    self.sortedEntries = filtered;
    [self clear];
}

- (void)setPlaybackTime:(double)playbackTime {
    if (playbackTime < _playbackTime - 1.0 || playbackTime > _playbackTime + 3.0) {
        self.needsReset = YES;
    }
    _playbackTime = playbackTime;
}

- (void)playbackTimeChanged:(double)time playing:(BOOL)playing {
    [self setPlaybackTime:time];
    self.playing = playing;
    if (!playing) self.lastWallTime = 0;
}

- (void)clear {
    [self.active removeAllObjects];
    self.pointer = 0;
    self.playbackTime = 0;
    self.needsReset = NO;
    [self rebuildLanes];
    [self setNeedsDisplay];
}

- (void)resetIfNeeded {
    [self.active removeAllObjects];
    self.pointer = 0;
    [self rebuildLanes];
    self.needsReset = NO;
}

- (void)tick:(NSTimer *)timer {
    if (!self.danmakuEnabled || self.sortedEntries.count == 0) {
        if (self.active.count) { [self.active removeAllObjects]; [self setNeedsDisplay]; }
        return;
    }
    NSTimeInterval now = [NSDate timeIntervalSinceReferenceDate];
    if (self.lastWallTime == 0) self.lastWallTime = now;
    CGFloat delta = (CGFloat)(now - self.lastWallTime);
    self.lastWallTime = now;
    if (self.playing && delta > 0 && delta < 0.5) self.playbackTime += delta;

    double t = self.playbackTime + self.timeOffset;
    if (self.needsReset) [self resetIfNeeded];
    if (self.pointer > 0 && self.pointer <= self.sortedEntries.count) {
        KLDanmakuEntry *prev = self.sortedEntries[self.pointer - 1];
        if (t < prev.time - 1.5) [self resetIfNeeded];
    }
    while (self.pointer < self.sortedEntries.count) {
        KLDanmakuEntry *e = self.sortedEntries[self.pointer];
        if (e.time > t + 0.05) break;
        if (e.time >= t - 0.4) [self emitEntry:e atTime:t];
        self.pointer++;
    }

    NSMutableArray *keep = [NSMutableArray array];
    for (KLDanmakuItem *item in self.active) {
        double end = item.start + item.duration;
        if (item.mode == 1 || item.mode == 2 || item.mode == 3) {
            if (t < end) [keep addObject:item];
        } else {
            if (t < end) [keep addObject:item];
        }
    }
    self.active = keep;
    [self setNeedsDisplay];
}

- (void)emitEntry:(KLDanmakuEntry *)entry atTime:(double)t {
    NSInteger mode = entry.mode;
    BOOL isScroll = (mode == 1 || mode == 2 || mode == 3 || mode == 0);
    if (isScroll && !self.showScroll) return;
    if (mode == 5 && !self.showTop) return;
    if (mode == 4 && !self.showBottom) return;

    UIFont *font = [UIFont boldSystemFontOfSize:self.fontSize];
    CGFloat width = [entry.text sizeWithAttributes:@{NSFontAttributeName: font}].width + 8;
    if (width > CGRectGetWidth(self.bounds) * 1.6) return;

    KLDanmakuItem *item = [[KLDanmakuItem alloc] init];
    item.text = entry.text;
    item.start = t;
    item.mode = mode;
    item.width = width;
    int color = (int)entry.colorValue;
    item.color = [UIColor colorWithRed:((color >> 16) & 0xFF) / 255.0
                                 green:((color >> 8) & 0xFF) / 255.0
                                  blue:(color & 0xFF) / 255.0
                                 alpha:self.opacity];

    CGFloat lineHeight = self.fontSize * 1.4;
    if (isScroll) {
        CGFloat speed = (CGRectGetWidth(self.bounds) + width) / self.duration;
        NSInteger bestLane = -1;
        CGFloat bestFree = CGFLOAT_MAX;
        for (NSInteger i = 0; i < self.lineCount; i++) {
            CGFloat freeAt = [self.scrollLaneFree[i] doubleValue];
            if (freeAt <= t + 0.05 && t - freeAt >= 0) { bestLane = i; break; }
            if (freeAt < bestFree) { bestFree = freeAt; bestLane = i; }
        }
        if (bestLane < 0) return;
        if ([self.scrollLaneFree[bestLane] doubleValue] > t + 0.05) return;
        self.scrollLaneFree[bestLane] = @(t + (width + 80) / speed);
        item.lane = bestLane;
        item.y = 6 + bestLane * lineHeight;
        item.duration = self.duration;
    } else {
        NSMutableArray *lanes = (mode == 5) ? self.topLaneFree : self.bottomLaneFree;
        NSInteger lane = -1;
        for (NSInteger i = 0; i < lanes.count; i++) {
            if ([lanes[i] doubleValue] <= t) { lane = i; break; }
        }
        if (lane < 0) return;
        lanes[lane] = @(t + 4.0);
        item.lane = lane;
        if (mode == 5) item.y = 6 + lane * lineHeight;
        else item.y = CGRectGetHeight(self.bounds) - 8 - (lane + 1) * lineHeight;
        item.duration = 4.0;
    }
    [self.active addObject:item];
}

- (void)drawRect:(CGRect)rect {
    if (!self.danmakuEnabled) return;
    double t = self.playbackTime + self.timeOffset;
    UIFont *font = [UIFont boldSystemFontOfSize:self.fontSize];
    NSMutableParagraphStyle *ps = [[NSMutableParagraphStyle alloc] init];
    ps.lineBreakMode = NSLineBreakByClipping;
    for (KLDanmakuItem *item in self.active) {
        CGFloat x = 0;
        CGFloat alpha = 1.0;
        if (item.mode == 1 || item.mode == 2 || item.mode == 3 || item.mode == 0) {
            CGFloat progress = (t - item.start) / item.duration;
            x = CGRectGetWidth(self.bounds) - progress * (CGRectGetWidth(self.bounds) + item.width);
        } else {
            x = (CGRectGetWidth(self.bounds) - item.width) / 2;
        }
        if (t > item.start + item.duration - 0.4) alpha = MAX(0.0, (item.start + item.duration - t) / 0.4);
        NSMutableDictionary *attrs = [NSMutableDictionary dictionary];
        attrs[NSFontAttributeName] = font;
        attrs[NSForegroundColorAttributeName] = [item.color colorWithAlphaComponent:CGColorGetAlpha(item.color.CGColor) * alpha];
        attrs[NSStrokeColorAttributeName] = [[UIColor blackColor] colorWithAlphaComponent:0.7 * alpha];
        attrs[NSStrokeWidthAttributeName] = self.showBorder ? @(-2.5) : @0;
        attrs[NSParagraphStyleAttributeName] = ps;
        [item.text drawAtPoint:CGPointMake(x, item.y) withAttributes:attrs];
    }
}

@end
