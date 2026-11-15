#import <Foundation/Foundation.h>
#import "KLModels.h"

extern NSString *const KLStoreDidChangeNotification;

@interface KLStore : NSObject

+ (instancetype)shared;

@property (nonatomic, readonly) NSString *rootPath;
@property (nonatomic, readonly) NSString *rulesPath;
@property (nonatomic, readonly) NSString *downloadsPath;
@property (nonatomic, readonly) NSString *cachePath;
@property (nonatomic, readonly) NSString *danmakuPath;

- (BOOL)prepare;

#pragma mark - Settings

- (id)objectForKey:(NSString *)key;
- (void)setObject:(id)value forKey:(NSString *)key;
- (BOOL)boolForKey:(NSString *)key defaultValue:(BOOL)def;
- (NSInteger)integerForKey:(NSString *)key defaultValue:(NSInteger)def;
- (double)doubleForKey:(NSString *)key defaultValue:(double)def;
- (NSString *)stringForKey:(NSString *)key defaultValue:(NSString *)def;
- (void)setBool:(BOOL)value forKey:(NSString *)key;
- (void)setInteger:(NSInteger)value forKey:(NSString *)key;
- (void)setDouble:(double)value forKey:(NSString *)key;
- (void)setString:(NSString *)value forKey:(NSString *)key;

#pragma mark - History

- (NSArray *)history;
- (void)recordHistory:(KLHistoryEntry *)entry;
- (void)removeHistoryForBangumi:(NSInteger)bid ruleName:(NSString *)ruleName episode:(NSInteger)episode;
- (void)clearHistory;

#pragma mark - Collection

- (NSArray *)collections;
- (KLCollectionEntry *)collectionForBangumi:(NSInteger)bid;
- (void)setCollection:(KLCollectionEntry *)entry;
- (void)removeCollectionForBangumi:(NSInteger)bid;

#pragma mark - Rules

- (NSArray *)allRules;
- (NSArray *)enabledRules;
- (void)reloadRules;
- (void)reloadAllData;
- (void)saveRule:(KLRule *)rule;
- (void)deleteRule:(KLRule *)rule;
- (void)setRule:(KLRule *)rule enabled:(BOOL)enabled;

#pragma mark - JSON

+ (id)readJSON:(NSString *)path;
+ (BOOL)writeJSON:(id)object toPath:(NSString *)path;

@end
