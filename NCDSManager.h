#import <Foundation/Foundation.h>

@interface NCDSManager : NSObject

+ (instancetype)shared;
- (void)start;
- (void)syncUpIfPossible;
- (void)forceSyncDownAndExit;
- (void)forceSyncDownAllAndExit;

@end
