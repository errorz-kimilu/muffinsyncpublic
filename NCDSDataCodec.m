#import "NCDSDataCodec.h"
#import <CommonCrypto/CommonCrypto.h>

static NSString *const kNCDSLocalManifest = @"Library/Application Support/muffinsync/local_manifest.json";
static NSString *const kNCDSLocalManifestHash = @"Library/Application Support/muffinsync/local_manifest.sha256";
static NSString *const kNCDSTypeKey = @"__ncds_type";
static NSString *const kNCDSDataKey = @"base64";
static NSString *const kNCDSDateKey = @"iso8601";
static NSString *const kNCDSURLKey = @"url";

@implementation NCDSDataCodec

- (id)jsonSafeObject:(id)obj {
	if (!obj || obj == [NSNull null]) {
		return [NSNull null];
	}
	if ([obj isKindOfClass:[NSString class]] ||
		[obj isKindOfClass:[NSNumber class]]) {
		return obj;
	}
	if ([obj isKindOfClass:[NSDate class]]) {
		NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
		formatter.locale = [NSLocale localeWithLocaleIdentifier:@"en_US_POSIX"];
		formatter.timeZone = [NSTimeZone timeZoneWithAbbreviation:@"UTC"];
		formatter.dateFormat = @"yyyy-MM-dd'T'HH:mm:ss'Z'";
		return @{
			kNCDSTypeKey: @"date",
			kNCDSDateKey: [formatter stringFromDate:obj] ?: @""
		};
	}
	if ([obj isKindOfClass:[NSData class]]) {
		return @{
			kNCDSTypeKey: @"data",
			kNCDSDataKey: [obj base64EncodedStringWithOptions:0] ?: @""
		};
	}
	if ([obj isKindOfClass:[NSURL class]]) {
		return @{
			kNCDSTypeKey: @"url",
			kNCDSURLKey: [obj absoluteString] ?: @""
		};
	}
	if ([obj isKindOfClass:[NSArray class]]) {
		NSMutableArray *arr = [NSMutableArray array];
		for (id item in (NSArray *)obj) {
			[arr addObject:[self jsonSafeObject:item] ?: [NSNull null]];
		}
		return arr;
	}
	if ([obj isKindOfClass:[NSDictionary class]]) {
		NSMutableDictionary *dict = [NSMutableDictionary dictionary];
		for (id key in (NSDictionary *)obj) {
			id value = [(NSDictionary *)obj objectForKey:key];
			NSString *keyString = [key isKindOfClass:[NSString class]] ? key : [key description];
			dict[keyString] = [self jsonSafeObject:value] ?: [NSNull null];
		}
		return dict;
	}
	return [obj description];
}

- (id)jsonDecodeObject:(id)obj {
	if (!obj || obj == [NSNull null]) {
		return nil;
	}
	if ([obj isKindOfClass:[NSArray class]]) {
		NSMutableArray *arr = [NSMutableArray array];
		for (id item in (NSArray *)obj) {
			id decoded = [self jsonDecodeObject:item];
			if (decoded) {
				[arr addObject:decoded];
			} else {
				[arr addObject:[NSNull null]];
			}
		}
		return arr;
	}
	if ([obj isKindOfClass:[NSDictionary class]]) {
		NSString *type = obj[kNCDSTypeKey];
		if ([type isEqualToString:@"data"]) {
			NSString *b64 = obj[kNCDSDataKey] ?: @"";
			return [[NSData alloc] initWithBase64EncodedString:b64 options:0];
		}
		if ([type isEqualToString:@"date"]) {
			NSString *iso = obj[kNCDSDateKey] ?: @"";
			NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
			formatter.locale = [NSLocale localeWithLocaleIdentifier:@"en_US_POSIX"];
			formatter.timeZone = [NSTimeZone timeZoneWithAbbreviation:@"UTC"];
			formatter.dateFormat = @"yyyy-MM-dd'T'HH:mm:ss'Z'";
			return [formatter dateFromString:iso];
		}
		if ([type isEqualToString:@"url"]) {
			NSString *url = obj[kNCDSURLKey] ?: @"";
			return [NSURL URLWithString:url];
		}
		NSMutableDictionary *dict = [NSMutableDictionary dictionary];
		for (id key in (NSDictionary *)obj) {
			id value = [(NSDictionary *)obj objectForKey:key];
			dict[key] = [self jsonDecodeObject:value] ?: [NSNull null];
		}
		return dict;
	}
	return obj;
}

- (NSString *)sha256ForData:(NSData *)data {
	uint8_t digest[CC_SHA256_DIGEST_LENGTH] = {0};
	CC_SHA256(data.bytes, (CC_LONG)data.length, digest);
	NSMutableString *hex = [NSMutableString stringWithCapacity:CC_SHA256_DIGEST_LENGTH * 2];
	for (int i = 0; i < CC_SHA256_DIGEST_LENGTH; i++) {
		[hex appendFormat:@"%02x", digest[i]];
	}
	return hex;
}

- (NSString *)sha256ForFileAtPath:(NSString *)path {
	NSFileHandle *handle = [NSFileHandle fileHandleForReadingAtPath:path];
	if (!handle) {
		return @"";
	}
	CC_SHA256_CTX ctx;
	CC_SHA256_Init(&ctx);
	while (true) {
		@autoreleasepool {
			NSData *data = [handle readDataOfLength:64 * 1024];
			if (data.length == 0) {
				break;
			}
			CC_SHA256_Update(&ctx, data.bytes, (CC_LONG)data.length);
		}
	}
	[handle closeFile];
	uint8_t digest[CC_SHA256_DIGEST_LENGTH] = {0};
	CC_SHA256_Final(digest, &ctx);
	NSMutableString *hex = [NSMutableString stringWithCapacity:CC_SHA256_DIGEST_LENGTH * 2];
	for (int i = 0; i < CC_SHA256_DIGEST_LENGTH; i++) {
		[hex appendFormat:@"%02x", digest[i]];
	}
	return hex;
}

- (NSString *)localManifestPath {
	NSString *home = NSHomeDirectory();
	return [home stringByAppendingPathComponent:kNCDSLocalManifest];
}

- (NSString *)localManifestHashPath {
	NSString *home = NSHomeDirectory();
	return [home stringByAppendingPathComponent:kNCDSLocalManifestHash];
}

- (void)saveLocalManifestData:(NSData *)data {
	if (!data) {
		return;
	}
	NSString *path = [self localManifestPath];
	NSString *dir = [path stringByDeletingLastPathComponent];
	[NSFileManager.defaultManager createDirectoryAtPath:dir withIntermediateDirectories:YES attributes:nil error:nil];
	[data writeToFile:path atomically:YES];
	NSString *hash = [self sha256ForData:data];
	[hash writeToFile:[self localManifestHashPath] atomically:YES encoding:NSUTF8StringEncoding error:nil];
}

- (BOOL)isRemoteManifestNewer:(NSData *)remoteData {
	if (!remoteData) {
		return NO;
	}
	NSString *localHash = [NSString stringWithContentsOfFile:[self localManifestHashPath] encoding:NSUTF8StringEncoding error:nil];
	NSString *remoteHash = [self sha256ForData:remoteData];
	if (localHash.length == 0) {
		return YES;
	}
	return ![localHash isEqualToString:remoteHash];
}

@end
