#import <UIKit/UIKit.h>
#import <AVFoundation/AVFoundation.h>
#import "KLModels.h"
#import "KLDanmakuView.h"

@interface KLPlayerViewController : UIViewController

- (instancetype)initWithBangumi:(KLBangumiItem *)bangumi
                           rule:(KLRule *)rule
                           road:(KLRoad *)road
                      roadIndex:(NSInteger)roadIndex
                   episodeIndex:(NSInteger)episodeIndex
                   episodeTitle:(NSString *)episodeTitle;

/// Return YES when the handler started the next episode.
@property (nonatomic, copy) BOOL (^nextHandler)(KLPlayerViewController *player);
/// Return YES when the handler started the previous episode.
@property (nonatomic, copy) BOOL (^previousHandler)(KLPlayerViewController *player);
@property (nonatomic, assign) double initialPosition;

@end
