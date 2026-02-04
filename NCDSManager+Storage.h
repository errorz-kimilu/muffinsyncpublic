#import "NCDSManager.h"

@interface NCDSManager (Storage)

- (BOOL)isContainerEmpty;
- (BOOL)isInitializedMarkerPresent;
- (void)writeInitializedMarker;
- (NSArray<NSDictionary *> *)buildAndUploadContainerFiles;
- (void)writeData:(NSData *)data toRelativePath:(NSString *)relative;

@end
