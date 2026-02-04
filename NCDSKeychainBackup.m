#import "NCDSKeychainBackup.h"
#import "NCDSDataCodec.h"
#import <Security/Security.h>

@interface NCDSKeychainBackup ()
@property (nonatomic, strong) NCDSDataCodec *codec;
@end

@implementation NCDSKeychainBackup

- (instancetype)initWithCodec:(NCDSDataCodec *)codec {
	self = [super init];
	if (self) {
		_codec = codec;
	}
	return self;
}

- (NSDictionary *)dumpKeychain {
	return @{
		@"generic": [self keychainItemsForClass:kSecClassGenericPassword],
		@"internet": [self keychainItemsForClass:kSecClassInternetPassword]
	};
}

- (NSArray *)keychainItemsForClass:(CFTypeRef)klass {
	NSDictionary *query = @{
		(__bridge id)kSecClass: (__bridge id)klass,
		(__bridge id)kSecReturnAttributes: @YES,
		(__bridge id)kSecReturnData: @YES,
		(__bridge id)kSecMatchLimit: (__bridge id)kSecMatchLimitAll
	};
	CFTypeRef result = NULL;
	OSStatus status = SecItemCopyMatching((__bridge CFDictionaryRef)query, &result);
	if (status != errSecSuccess || !result) {
		return @[];
	}
	NSArray *items = CFBridgingRelease(result);
	NSMutableArray *encoded = [NSMutableArray array];
	for (NSDictionary *item in items) {
		NSMutableDictionary *mutable = [item mutableCopy];
		NSData *data = item[(__bridge id)kSecValueData];
		if (data) {
			mutable[@"_valueDataBase64"] = [data base64EncodedStringWithOptions:0];
			[mutable removeObjectForKey:(__bridge id)kSecValueData];
		}
		id safeItem = [self.codec jsonSafeObject:mutable];
		if (safeItem) {
			[encoded addObject:safeItem];
		}
	}
	return encoded;
}

- (void)restoreKeychainFromDump:(NSDictionary *)dump {
	if (![dump isKindOfClass:[NSDictionary class]]) {
		return;
	}
	[self restoreKeychainItems:dump[@"generic"] classType:kSecClassGenericPassword];
	[self restoreKeychainItems:dump[@"internet"] classType:kSecClassInternetPassword];
}

- (void)restoreKeychainItems:(NSArray *)items classType:(CFTypeRef)klass {
	if (![items isKindOfClass:[NSArray class]]) {
		return;
	}
	for (NSDictionary *item in items) {
		NSMutableDictionary *attrs = [[self.codec jsonDecodeObject:item] mutableCopy];
		NSString *b64 = attrs[@"_valueDataBase64"];
		[attrs removeObjectForKey:@"_valueDataBase64"];
		if (b64.length > 0) {
			attrs[(__bridge id)kSecValueData] = [[NSData alloc] initWithBase64EncodedString:b64 options:0];
		}
		attrs[(__bridge id)kSecClass] = (__bridge id)klass;
		OSStatus status = SecItemAdd((__bridge CFDictionaryRef)attrs, NULL);
		if (status == errSecDuplicateItem) {
			NSMutableDictionary *query = [attrs mutableCopy];
			[query removeObjectForKey:(__bridge id)kSecValueData];
			NSMutableDictionary *update = [NSMutableDictionary dictionary];
			if (attrs[(__bridge id)kSecValueData]) {
				update[(__bridge id)kSecValueData] = attrs[(__bridge id)kSecValueData];
			}
			SecItemUpdate((__bridge CFDictionaryRef)query, (__bridge CFDictionaryRef)update);
		}
	}
}

@end
