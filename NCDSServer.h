#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

@protocol NCDSServer <NSObject>

@property (nonatomic, readonly) NSString *username;

- (void)loadPreferences;
- (BOOL)isConfigured;
- (NSString *)configurationErrorTitle;
- (NSString *)configurationErrorMessage;

- (void)authenticateIfNeededWithWindow:(UIWindow *)window completion:(void (^)(BOOL success))completion;
- (void)fetchUsernameWithCompletion:(void (^)(BOOL ok))completion;
- (NSString *)authorizationHeaderValue;

- (NSURL *)remoteUserBaseURL;
- (NSURL *)remoteSyncBaseURLForBundle:(NSString *)bundleID;

@end
