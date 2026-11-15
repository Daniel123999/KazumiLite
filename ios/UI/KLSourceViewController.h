#import <UIKit/UIKit.h>
#import "KLModels.h"

@interface KLSourceViewController : UIViewController
- (instancetype)initWithBangumi:(KLBangumiItem *)item rule:(KLRule *)rule source:(KLSearchItem *)source;
@property (nonatomic, assign) NSInteger initialEpisode;
@end
