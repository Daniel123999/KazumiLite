#import <Foundation/Foundation.h>

@interface KLDlnaDevice : NSObject
@property (nonatomic, copy) NSString *name;
@property (nonatomic, copy) NSString *location;
@property (nonatomic, copy) NSString *controlURL;
@end

@interface KLDlnaController : NSObject

+ (instancetype)shared;

- (void)discover:(void (^)(NSArray *devices, NSError *error))completion;
- (void)castURL:(NSString *)url toDevice:(KLDlnaDevice *)device completion:(void (^)(BOOL success, NSString *message))completion;
- (void)stopDevice:(KLDlnaDevice *)device completion:(void (^)(BOOL success, NSString *message))completion;

@end
