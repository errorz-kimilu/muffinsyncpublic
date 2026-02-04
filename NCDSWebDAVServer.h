#import <Foundation/Foundation.h>
#import "NCDSServer.h"

@interface NCDSWebDAVServer : NSObject <NCDSServer>

- (instancetype)initWithBundleID:(NSString *)bundleID;

@end
