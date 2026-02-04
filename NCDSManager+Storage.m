#import "NCDSManager+Storage.h"
#import "NCDSDataCodec.h"

@interface NCDSManager ()
@property (nonatomic, strong) NCDSDataCodec *codec;
- (void)uploadFileAtPath:(NSString *)fullPath relativePath:(NSString *)relativePath;
@end

static NSString *const kNCDSInitializedMarker = @"Library/Application Support/muffinsync/initialized";

@implementation NCDSManager (Storage)

- (BOOL)isContainerEmpty {
	NSFileManager *fm = NSFileManager.defaultManager;
	NSURL *docs = [fm URLsForDirectory:NSDocumentDirectory inDomains:NSUserDomainMask].firstObject;
	NSURL *appSupport = [fm URLsForDirectory:NSApplicationSupportDirectory inDomains:NSUserDomainMask].firstObject;
	NSArray<NSURL *> *targets = @[docs ?: [NSURL URLWithString:@""], appSupport ?: [NSURL URLWithString:@""]];
	for (NSURL *dir in targets) {
		if (!dir.path.length) {
			continue;
		}
		NSArray *items = [fm contentsOfDirectoryAtPath:dir.path error:nil];
		if (items.count > 0) {
			return NO;
		}
	}
	return YES;
}

- (BOOL)isInitializedMarkerPresent {
	NSString *markerPath = [self markerPath];
	return [NSFileManager.defaultManager fileExistsAtPath:markerPath];
}

- (void)writeInitializedMarker {
	NSString *markerPath = [self markerPath];
	NSString *dir = [markerPath stringByDeletingLastPathComponent];
	[NSFileManager.defaultManager createDirectoryAtPath:dir withIntermediateDirectories:YES attributes:nil error:nil];
	[@"ok" writeToFile:markerPath atomically:YES encoding:NSUTF8StringEncoding error:nil];
}

- (NSString *)markerPath {
	NSString *home = NSHomeDirectory();
	return [home stringByAppendingPathComponent:kNCDSInitializedMarker];
}

- (NSArray<NSDictionary *> *)buildAndUploadContainerFiles {
	NSFileManager *fm = NSFileManager.defaultManager;
	NSString *home = NSHomeDirectory();
	NSArray<NSString *> *roots = @[@"Documents", @"Library"];
	NSSet<NSString *> *excludedPrefixes = [NSSet setWithArray:@[
		@"Library/Caches",
		@"Library/Preferences"
	]];
	NSMutableArray<NSDictionary *> *manifest = [NSMutableArray array];
	NSUInteger uploadedCount = 0;
	for (NSString *root in roots) {
		NSString *rootPath = [home stringByAppendingPathComponent:root];
		NSDirectoryEnumerator *enumerator = [fm enumeratorAtPath:rootPath];
		for (NSString *relative in enumerator) {
			@autoreleasepool {
				BOOL skip = NO;
				for (NSString *excluded in excludedPrefixes) {
					if ([relative hasPrefix:[excluded stringByAppendingString:@"/"]] || [relative isEqualToString:excluded]) {
						[enumerator skipDescendants];
						skip = YES;
						break;
					}
				}
				if (skip) {
					continue;
				}
				NSString *fullPath = [rootPath stringByAppendingPathComponent:relative];
				BOOL isDir = NO;
				[fm fileExistsAtPath:fullPath isDirectory:&isDir];
				if (isDir) {
					continue;
				}
				if (fullPath.length == 0 || [relative hasSuffix:@".muffinsync"]) {
					continue;
				}
				NSDictionary *attrs = [fm attributesOfItemAtPath:fullPath error:nil];
				NSString *fileType = attrs[NSFileType];
				if (![fileType isEqualToString:NSFileTypeRegular]) {
					continue;
				}
				unsigned long long fileSize = [attrs[NSFileSize] unsignedLongLongValue];
				NSString *relPath = [NSString stringWithFormat:@"%@/%@", root, relative];
				[self uploadFileAtPath:fullPath relativePath:relPath];
				NSString *sha = [self.codec sha256ForFileAtPath:fullPath];
				NSDictionary *entry = @{
					@"path": relPath,
					@"size": @(fileSize),
					@"sha256": sha ?: @""
				};
				[manifest addObject:entry];
				uploadedCount += 1;
			}
		}
	}
	NSLog(@"[muffinsync] queued %lu files for upload", (unsigned long)uploadedCount);
	return manifest;
}

- (void)writeData:(NSData *)data toRelativePath:(NSString *)relative {
	NSString *fullPath = [NSHomeDirectory() stringByAppendingPathComponent:relative];
	NSString *dir = [fullPath stringByDeletingLastPathComponent];
	[NSFileManager.defaultManager createDirectoryAtPath:dir withIntermediateDirectories:YES attributes:nil error:nil];
	[data writeToFile:fullPath atomically:YES];
}

@end
