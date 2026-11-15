#import <UIKit/UIKit.h>
#import "KLModels.h"

@interface KLDanmakuView : UIView

@property (nonatomic, assign) BOOL danmakuEnabled;
@property (nonatomic, assign) BOOL playing;
@property (nonatomic, assign) double playbackTime;
@property (nonatomic, assign) double timeOffset;
@property (nonatomic, strong) NSArray *entries;

- (void)reloadSettings;
- (void)clear;
- (void)playbackTimeChanged:(double)time playing:(BOOL)playing;

@end
