#import <UIKit/UIKit.h>
#import "KLModels.h"

@interface KLSourcePickerViewController : UIViewController
- (instancetype)initWithBangumi:(KLBangumiItem *)item;
@property (nonatomic, assign) NSInteger initialEpisode;
@end
