#import <Foundation/Foundation.h>

@interface KLWebDAV : NSObject

+ (instancetype)shared;

@property (nonatomic, copy) NSString *serverURL;
@property (nonatomic, copy) NSString *username;
@property (nonatomic, copy) NSString *password;
@property (nonatomic, copy) NSString *remotePath;
@property (nonatomic, assign) BOOL enabled;

- (void)loadConfig;
- (void)saveConfig;

- (void)testConnection:(void (^)(BOOL success, NSString *message))completion;
- (void)backupAll:(void (^)(BOOL success, NSString *message))completion;
- (void)restoreAll:(void (^)(BOOL success, NSString *message))completion;
- (void)syncNow:(void (^)(BOOL success, NSString *message))completion;

@end
