#import "NCDSWebDAVClient.h"

@interface NCDSWebDAVClient ()
@property (nonatomic, strong) id<NCDSServer> server;
@property (nonatomic, copy) NSString *bundleID;
@property (nonatomic, strong) NSURLSession *session;
@end

@implementation NCDSWebDAVClient

- (instancetype)initWithServer:(id<NCDSServer>)server bundleID:(NSString *)bundleID session:(NSURLSession *)session {
	self = [super init];
	if (self) {
		_server = server;
		_bundleID = [bundleID copy] ?: @"";
		_session = session;
	}
	return self;
}

- (void)ensureRemoteBaseReady:(void (^)(void))completion {
	NSString *baseDir = @".muffinsync";
	NSString *bundleDir = [NSString stringWithFormat:@".muffinsync/%@", self.bundleID ?: @""];
	NSURL *userBase = [self.server remoteUserBaseURL];
	if (!userBase) {
		if (completion) completion();
		return;
	}
	[self mkcol:baseDir baseURL:userBase completion:^{
		[self mkcol:bundleDir baseURL:userBase completion:^{
			if (completion) completion();
		}];
	}];
}

- (void)uploadData:(NSData *)data toPath:(NSString *)relativePath completion:(void (^)(BOOL ok))completion {
	if (!data || relativePath.length == 0) {
		if (completion) completion(NO);
		return;
	}
	[self ensureRemoteDirectoriesForPath:relativePath completion:^{
		NSURL *base = [self.server remoteSyncBaseURLForBundle:self.bundleID];
		NSURL *url = [base URLByAppendingPathComponent:relativePath];
		url = [self urlByAddingPathComponentsPercentEncoding:url];
		NSMutableURLRequest *req = [NSMutableURLRequest requestWithURL:url];
		req.HTTPMethod = @"PUT";
		NSString *auth = [self.server authorizationHeaderValue];
		if (auth.length > 0) {
			[req setValue:auth forHTTPHeaderField:@"Authorization"];
		}
		req.HTTPBody = data;
		NSURLSessionDataTask *task = [self.session dataTaskWithRequest:req completionHandler:^(NSData *respData, NSURLResponse *resp, NSError *error) {
			BOOL ok = (!error);
			NSHTTPURLResponse *http = (NSHTTPURLResponse *)resp;
			if (error || http.statusCode >= 300) {
				NSLog(@"[muffinsync] PUT %@ failed: %@ status=%ld", relativePath, error, (long)http.statusCode);
			}
			if (completion) completion(ok);
		}];
		[task resume];
	}];
}

- (void)uploadFileAtPath:(NSString *)fullPath relativePath:(NSString *)relativePath completion:(void (^)(void))completion {
	if (fullPath.length == 0 || relativePath.length == 0) {
		if (completion) completion();
		return;
	}
	[self ensureRemoteDirectoriesForPath:relativePath completion:^{
		NSURL *base = [self.server remoteSyncBaseURLForBundle:self.bundleID];
		NSURL *url = [base URLByAppendingPathComponent:relativePath];
		url = [self urlByAddingPathComponentsPercentEncoding:url];
		NSMutableURLRequest *req = [NSMutableURLRequest requestWithURL:url];
		req.HTTPMethod = @"PUT";
		NSString *auth = [self.server authorizationHeaderValue];
		if (auth.length > 0) {
			[req setValue:auth forHTTPHeaderField:@"Authorization"];
		}
		NSURL *fileURL = [NSURL fileURLWithPath:fullPath];
		NSURLSessionUploadTask *task = [self.session uploadTaskWithRequest:req fromFile:fileURL completionHandler:^(NSData *respData, NSURLResponse *resp, NSError *error) {
			NSHTTPURLResponse *http = (NSHTTPURLResponse *)resp;
			if (error || http.statusCode >= 300) {
				NSLog(@"[muffinsync] PUT(file) %@ failed: %@ status=%ld", relativePath, error, (long)http.statusCode);
			}
			if (completion) completion();
		}];
		[task resume];
	}];
}

- (void)downloadDataAtPath:(NSString *)relativePath completion:(void (^)(NSData *data))completion {
	NSURL *base = [self.server remoteSyncBaseURLForBundle:self.bundleID];
	NSURL *url = [base URLByAppendingPathComponent:relativePath];
	url = [self urlByAddingPathComponentsPercentEncoding:url];
	NSMutableURLRequest *req = [NSMutableURLRequest requestWithURL:url];
	req.HTTPMethod = @"GET";
	NSString *auth = [self.server authorizationHeaderValue];
	if (auth.length > 0) {
		[req setValue:auth forHTTPHeaderField:@"Authorization"];
	}
	NSURLSessionDataTask *task = [self.session dataTaskWithRequest:req completionHandler:^(NSData *data, NSURLResponse *resp, NSError *error) {
		if (error) {
			completion(nil);
			return;
		}
		completion(data);
	}];
	[task resume];
}

- (void)ensureRemoteDirectoriesForPath:(NSString *)relativePath completion:(void (^)(void))completion {
	if (relativePath.length == 0) {
		if (completion) completion();
		return;
	}
	NSArray<NSString *> *components = [relativePath pathComponents];
	if (components.count <= 1) {
		if (completion) completion();
		return;
	}
	NSMutableArray<NSString *> *dirComponents = [components mutableCopy];
	[dirComponents removeLastObject];
	NSURL *baseURL = [self.server remoteSyncBaseURLForBundle:self.bundleID];
	if (!baseURL) {
		if (completion) completion();
		return;
	}
	dispatch_async(dispatch_get_global_queue(QOS_CLASS_UTILITY, 0), ^{
		for (NSUInteger i = 0; i < dirComponents.count; i++) {
			NSString *partial = [[dirComponents subarrayWithRange:NSMakeRange(0, i + 1)] componentsJoinedByString:@"/"];
			dispatch_semaphore_t sema = dispatch_semaphore_create(0);
			[self mkcol:partial baseURL:baseURL completion:^{
				dispatch_semaphore_signal(sema);
			}];
			dispatch_semaphore_wait(sema, dispatch_time(DISPATCH_TIME_NOW, (int64_t)(5 * NSEC_PER_SEC)));
		}
		if (completion) {
			dispatch_async(dispatch_get_main_queue(), ^{
				completion();
			});
		}
	});
}

- (void)mkcol:(NSString *)relativeDir baseURL:(NSURL *)baseURL completion:(void (^)(void))completion {
	NSURL *url = [baseURL URLByAppendingPathComponent:relativeDir];
	url = [self urlByAddingPathComponentsPercentEncoding:url];
	NSMutableURLRequest *req = [NSMutableURLRequest requestWithURL:url];
	req.HTTPMethod = @"MKCOL";
	NSString *auth = [self.server authorizationHeaderValue];
	if (auth.length > 0) {
		[req setValue:auth forHTTPHeaderField:@"Authorization"];
	}
	NSURLSessionDataTask *task = [self.session dataTaskWithRequest:req completionHandler:^(NSData *data, NSURLResponse *resp, NSError *error) {
		NSHTTPURLResponse *http = (NSHTTPURLResponse *)resp;
		if (http.statusCode == 423) {
			dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
				[self mkcol:relativeDir baseURL:baseURL completion:completion];
			});
			return;
		}
		if (error || (http.statusCode >= 300 && http.statusCode != 405)) {
			NSLog(@"[muffinsync] MKCOL %@ failed: %@ status=%ld", relativeDir, error, (long)http.statusCode);
		}
		if (completion) completion();
	}];
	[task resume];
}

- (NSURL *)urlByAddingPathComponentsPercentEncoding:(NSURL *)url {
	if (!url) {
		return nil;
	}
	NSURLComponents *components = [NSURLComponents componentsWithURL:url resolvingAgainstBaseURL:NO];
	if (!components || !components.path) {
		return url;
	}
	NSArray<NSString *> *parts = components.path.pathComponents;
	NSMutableArray<NSString *> *encodedParts = [NSMutableArray array];
	for (NSString *part in parts) {
		NSString *encoded = [part stringByAddingPercentEncodingWithAllowedCharacters:[NSCharacterSet URLPathAllowedCharacterSet]];
		[encodedParts addObject:encoded ?: part];
	}
	NSString *joined = [encodedParts componentsJoinedByString:@"/"];
	if (![joined hasPrefix:@"/"]) {
		joined = [@"/" stringByAppendingString:joined];
	}
	components.percentEncodedPath = joined;
	return components.URL ?: url;
}

@end
