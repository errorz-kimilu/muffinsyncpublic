#import <Foundation/Foundation.h>

@class NCDSDataCodec;

@interface NCDSKeychainBackup : NSObject

- (instancetype)initWithCodec:(NCDSDataCodec *)codec;
- (NSDictionary *)dumpKeychain;
- (void)restoreKeychainFromDump:(NSDictionary *)dump;

@end
