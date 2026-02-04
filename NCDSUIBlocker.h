#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

@interface NCDSUIBlocker : NSObject

- (void)showAuthRequiredBlocker;
- (void)showSyncBlockerWithMessage:(NSString *)message;
- (void)hideSyncBlocker;
- (void)updateProgressCompleted:(NSInteger)completed total:(NSInteger)total;

@end
