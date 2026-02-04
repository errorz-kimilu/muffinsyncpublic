#import "NCDSWebDAVServer.h"
#import "NCDSConfig.h"

@interface NCDSWebDAVServer ()
@property (nonatomic, copy) NSString *serverURL;
@property (nonatomic, copy) NSString *username;
@property (nonatomic, copy) NSString *password;
@end

@implementation NCDSWebDAVServer

- (instancetype)initWithBundleID:(NSString *)bundleID {
	self = [super init];
	if (self) {
		(void)bundleID;
	}
	return self;
}

- (void)loadPreferences {
	NSUserDefaults *defaults = [[NSUserDefaults alloc] initWithSuiteName:@"com.muffinsync"];
	self.serverURL = [defaults stringForKey:@"ServerURL"] ?: NCDS_SERVER_URL;
	self.username = [defaults stringForKey:@"WebDAVUsername"] ?: NCDS_WEBDAV_USER;
	self.password = [defaults stringForKey:@"WebDAVPassword"] ?: NCDS_WEBDAV_PASS;
}

- (BOOL)isConfigured {
	return (self.username.length > 0 && self.password.length > 0);
}

- (NSString *)configurationErrorTitle {
	return @"Missing WebDAV credentials";
}

- (NSString *)configurationErrorMessage {
	return @"Please set them during build";
}

- (void)authenticateIfNeededWithWindow:(UIWindow *)window completion:(void (^)(BOOL success))completion {
	(void)window;
	completion(self.username.length > 0 && self.password.length > 0);
}

- (void)fetchUsernameWithCompletion:(void (^)(BOOL ok))completion {
	completion(self.username.length > 0);
}

- (NSString *)authorizationHeaderValue {
	if (self.username.length > 0 && self.password.length > 0) {
		NSString *pair = [NSString stringWithFormat:@"%@:%@", self.username, self.password];
		NSData *data = [pair dataUsingEncoding:NSUTF8StringEncoding];
		NSString *b64 = [data base64EncodedStringWithOptions:0];
		return [NSString stringWithFormat:@"Basic %@", b64 ?: @""];
	}
	return @"";
}

- (NSURL *)remoteUserBaseURL {
	NSMutableString *base = [NSMutableString stringWithFormat:@"%@%@", self.serverURL, NCDS_WEBDAV_ROOT];
	if (![base hasSuffix:@"/"]) {
		[base appendString:@"/"];
	}
#if NCDS_WEBDAV_INCLUDE_USERNAME
	if (self.username.length > 0) {
		[base appendFormat:@"%@/", self.username];
	}
#endif
	return [NSURL URLWithString:base];
}

- (NSURL *)remoteSyncBaseURLForBundle:(NSString *)bundleID {
	NSURL *userBase = [self remoteUserBaseURL];
	NSString *relative = [NSString stringWithFormat:@".muffinsync/%@/", bundleID ?: @""];
	return [userBase URLByAppendingPathComponent:relative];
}

@end
