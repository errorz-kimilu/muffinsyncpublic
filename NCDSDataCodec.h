#import <Foundation/Foundation.h>

@interface NCDSDataCodec : NSObject

- (id)jsonSafeObject:(id)obj;
- (id)jsonDecodeObject:(id)obj;
- (NSString *)sha256ForData:(NSData *)data;
- (NSString *)sha256ForFileAtPath:(NSString *)path;

- (void)saveLocalManifestData:(NSData *)data;
- (BOOL)isRemoteManifestNewer:(NSData *)remoteData;

@end
