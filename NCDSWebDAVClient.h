#import <Foundation/Foundation.h>
#import "NCDSServer.h"

@interface NCDSWebDAVClient : NSObject

- (instancetype)initWithServer:(id<NCDSServer>)server bundleID:(NSString *)bundleID session:(NSURLSession *)session;

- (void)ensureRemoteBaseReady:(void (^)(void))completion;
- (void)uploadData:(NSData *)data toPath:(NSString *)relativePath completion:(void (^)(BOOL ok))completion;
- (void)uploadFileAtPath:(NSString *)fullPath relativePath:(NSString *)relativePath completion:(void (^)(void))completion;
- (void)downloadDataAtPath:(NSString *)relativePath completion:(void (^)(NSData *data))completion;

@end
