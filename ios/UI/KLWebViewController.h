#import <UIKit/UIKit.h>

@interface KLWebViewController : UIViewController

- (instancetype)initWithURL:(NSString *)url title:(NSString *)title;
- (instancetype)initWithURL:(NSString *)url title:(NSString *)title headers:(NSDictionary *)headers;

@property (nonatomic, copy) void (^onClose)(void);

@end
