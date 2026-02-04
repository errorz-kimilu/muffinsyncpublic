#import "NCDSManager.h"
#import "NCDSConfig.h"
#import "NCDSServer.h"
#import "NCDSWebDAVServer.h"
#import "NCDSWebDAVClient.h"
#import "NCDSDataCodec.h"
#import "NCDSKeychainBackup.h"
#import "NCDSUIBlocker.h"
#import "NCDSManager+Storage.h"
#import <UIKit/UIKit.h>

static NSString *const kNCDSManifestName = @"manifest.json";
static NSString *const kNCDSUserDefaultsName = @"userdefaults.json";
static NSString *const kNCDSKeychainName = @"keychain.json";

@interface NCDSManager ()
@property (nonatomic, copy) NSString *bundleID;
@property (nonatomic, strong) id<NCDSServer> server;
@property (nonatomic, strong) NCDSWebDAVClient *client;
@property (nonatomic, strong) NCDSDataCodec *codec;
@property (nonatomic, strong) NCDSKeychainBackup *keychain;
@property (nonatomic, strong) NCDSUIBlocker *ui;
@property (nonatomic, strong) NSURLSession *session;
@property (nonatomic, assign) BOOL syncInProgress;
@property (nonatomic, assign) BOOL exitAfterUpload;
@property (nonatomic, assign) NSInteger pendingUploads;
@property (nonatomic, assign) NSInteger totalUploads;
@property (nonatomic, assign) NSInteger completedUploads;
@property (nonatomic, assign) NSInteger totalDownloads;
@property (nonatomic, assign) NSInteger completedDownloads;
@end

@implementation NCDSManager

+ (instancetype)shared {
	static NCDSManager *mgr = nil;
	static dispatch_once_t onceToken;
	dispatch_once(&onceToken, ^{
		mgr = [[NCDSManager alloc] init];
	});
	return mgr;
}

- (void)start {
	self.bundleID = NSBundle.mainBundle.bundleIdentifier ?: @"";
	if (self.bundleID.length == 0) {
		NSLog(@"[muffinsync] failed to get bundle id?");
		return;
	}
	self.session = [NSURLSession sessionWithConfiguration:[NSURLSessionConfiguration defaultSessionConfiguration]];
	self.codec = [NCDSDataCodec new];
	self.keychain = [[NCDSKeychainBackup alloc] initWithCodec:self.codec];
	self.ui = [NCDSUIBlocker new];
	self.server = [[NCDSWebDAVServer alloc] initWithBundleID:self.bundleID];
	[self.server loadPreferences];
	self.client = [[NCDSWebDAVClient alloc] initWithServer:self.server bundleID:self.bundleID session:self.session];
	[self ensureObservers];
	[self handleFirstRunIfNeeded];
}

- (void)ensureObservers {
	NSNotificationCenter *nc = NSNotificationCenter.defaultCenter;
	[nc addObserver:self selector:@selector(appDidBecomeActive) name:UIApplicationDidBecomeActiveNotification object:nil];
	[nc addObserver:self selector:@selector(appWillResignActive) name:UIApplicationWillResignActiveNotification object:nil];
}

- (void)appDidBecomeActive {
	[self syncDownIfPossible:NO];
}

- (void)appWillResignActive {
	// [self syncUpIfPossible];
}

- (void)handleFirstRunIfNeeded {
	if (![self isContainerEmpty] || [self isInitializedMarkerPresent]) {
		return;
	}
	[self authenticateAndFetchUser:^(BOOL success) {
		if (!success) {
			[self exitAppSoon];
			return;
		}
		[self syncDownIfPossible:YES];
	}];
}

- (void)presentAlert:(UIAlertController *)alert {
	UIWindow *window = UIApplication.sharedApplication.keyWindow;
	UIViewController *root = window.rootViewController;
	while (root.presentedViewController) {
		root = root.presentedViewController;
	}
	[root presentViewController:alert animated:YES completion:nil];
}


- (void)authenticateAndFetchUser:(void (^)(BOOL success))completion {
	if (![self.server isConfigured]) {
		[self showError:[self.server configurationErrorTitle] detail:[self.server configurationErrorMessage]];
		[self.ui showAuthRequiredBlocker];
		completion(NO);
		return;
	}
	UIWindow *window = UIApplication.sharedApplication.keyWindow;
	[self.server authenticateIfNeededWithWindow:window completion:^(BOOL success) {
		if (!success) {
			[self.ui showAuthRequiredBlocker];
			completion(NO);
			return;
		}
		[self.server fetchUsernameWithCompletion:^(BOOL ok) {
			if (!ok) {
				[self.ui showAuthRequiredBlocker];
				completion(NO);
				return;
			}
			completion(YES);
		}];
	}];
}

- (void)syncDownIfPossible:(BOOL)isFirstRun {
	if (self.syncInProgress) {
		return;
	}
	self.syncInProgress = YES;
	[self authenticateAndFetchUser:^(BOOL success) {
		if (!success) {
			self.syncInProgress = NO;
			return;
		}
		[self.ui showSyncBlockerWithMessage:@"Syncing with mCloud"];
		[self downloadAndRestoreWithCompletion:^(BOOL restored) {
			if (restored) {
				[self writeInitializedMarker];
			} else if (isFirstRun) {
				[self.ui showAuthRequiredBlocker];
			}
			[self.ui hideSyncBlocker];
			self.syncInProgress = NO;
			if (restored) {
				[self exitAppSoon];
			}
		}];
	}];
}

- (void)forceSyncDownAndExit {
	if (self.syncInProgress) {
		return;
	}
	self.syncInProgress = YES;
	[self authenticateAndFetchUser:^(BOOL success) {
		if (!success) {
			self.syncInProgress = NO;
			return;
		}
		[self.ui showSyncBlockerWithMessage:@"Syncing with mCloud"];
		[self downloadAndRestoreWithCompletion:^(BOOL restored) {
			[self.ui hideSyncBlocker];
			self.syncInProgress = NO;
			[self exitAppSoon];
		}];
	}];
}

- (void)forceSyncDownAllAndExit {
	if (self.syncInProgress) {
		return;
	}
	self.syncInProgress = YES;
	[self authenticateAndFetchUser:^(BOOL success) {
		if (!success) {
			self.syncInProgress = NO;
			return;
		}
		[self.ui showSyncBlockerWithMessage:@"Syncing with mCloud"];
		[self downloadAndRestoreWithCompletion:^(BOOL restored) {
			[self.ui hideSyncBlocker];
			self.syncInProgress = NO;
			[self exitAppSoon];
		} force:YES];
	}];
}

- (void)syncUpIfPossible {
	[self authenticateAndFetchUser:^(BOOL success) {
		if (!success) {
			return;
		}
		self.exitAfterUpload = YES;
		[self.ui showSyncBlockerWithMessage:@"Syncing with mCloud"];
		[self backupAndUpload];
	}];
}

- (void)backupAndUpload {
	self.pendingUploads = 0;
	self.totalUploads = 0;
	self.completedUploads = 0;
	[self.client ensureRemoteBaseReady:^{
		[self backupAndUploadInternal];
	}];
}

- (void)backupAndUploadInternal {
	NSDictionary *defaults = NSUserDefaults.standardUserDefaults.dictionaryRepresentation ?: @{};
	id defaultsSafe = [self.codec jsonSafeObject:defaults];
	NSData *defaultsData = [NSJSONSerialization dataWithJSONObject:defaultsSafe options:0 error:nil];
	[self uploadData:defaultsData toPath:kNCDSUserDefaultsName];

	NSDictionary *keychainDump = [self.keychain dumpKeychain];
	id keychainSafe = [self.codec jsonSafeObject:keychainDump];
	NSData *keychainData = [NSJSONSerialization dataWithJSONObject:keychainSafe options:0 error:nil];
	[self uploadData:keychainData toPath:kNCDSKeychainName];

	NSArray<NSDictionary *> *manifest = [self buildAndUploadContainerFiles];
	NSData *manifestData = [NSJSONSerialization dataWithJSONObject:manifest options:0 error:nil];
	[self uploadData:manifestData toPath:kNCDSManifestName];
	[self.codec saveLocalManifestData:manifestData];
}

- (void)downloadAndRestoreWithCompletion:(void (^)(BOOL restored))completion {
	[self downloadAndRestoreWithCompletion:completion force:NO];
}

- (void)downloadAndRestoreWithCompletion:(void (^)(BOOL restored))completion force:(BOOL)force {
	[self.client downloadDataAtPath:kNCDSManifestName completion:^(NSData *manifestData) {
		if (!manifestData) {
			completion(YES);
			return;
		}
		if (!force && ![self.codec isRemoteManifestNewer:manifestData]) {
			NSLog(@"[muffinsync] local data is up to date");
			completion(NO);
			return;
		}
		NSArray *manifest = [NSJSONSerialization JSONObjectWithData:manifestData options:0 error:nil];
		if (![manifest isKindOfClass:[NSArray class]]) {
			completion(NO);
			return;
		}
		[self.codec saveLocalManifestData:manifestData];
		self.totalDownloads = (NSInteger)manifest.count;
		self.completedDownloads = 0;
		[self.ui updateProgressCompleted:self.completedDownloads total:self.totalDownloads];
		dispatch_group_t group = dispatch_group_create();
		for (NSDictionary *entry in manifest) {
			NSString *path = entry[@"path"];
			if (path.length == 0) {
				continue;
			}
			dispatch_group_enter(group);
			[self.client downloadDataAtPath:path completion:^(NSData *data) {
				if (data) {
					[self writeData:data toRelativePath:path];
				}
				[self markDownloadComplete];
				dispatch_group_leave(group);
			}];
		}
		dispatch_group_notify(group, dispatch_get_main_queue(), ^{
			[self restoreUserDefaults];
			[self restoreKeychain];
			completion(YES);
		});
	}];
}

- (void)restoreUserDefaults {
	[self.client downloadDataAtPath:kNCDSUserDefaultsName completion:^(NSData *data) {
		if (!data) {
			return;
		}
		NSDictionary *defaults = [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
		if (![defaults isKindOfClass:[NSDictionary class]]) {
			return;
		}
		for (NSString *key in defaults) {
			id value = [self.codec jsonDecodeObject:defaults[key]];
			if (value) {
				[NSUserDefaults.standardUserDefaults setObject:value forKey:key];
			}
		}
		[NSUserDefaults.standardUserDefaults synchronize];
	}];
}

- (void)restoreKeychain {
	[self.client downloadDataAtPath:kNCDSKeychainName completion:^(NSData *data) {
		if (!data) {
			return;
		}
		NSDictionary *dump = [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
		[self.keychain restoreKeychainFromDump:dump];
	}];
}

- (void)uploadData:(NSData *)data toPath:(NSString *)relativePath {
	[self incrementPendingUploads];
	[self.client uploadData:data toPath:relativePath completion:^(BOOL ok) {
		[self markUploadComplete];
	}];
}

- (void)uploadFileAtPath:(NSString *)fullPath relativePath:(NSString *)relativePath {
	[self incrementPendingUploads];
	[self.client uploadFileAtPath:fullPath relativePath:relativePath completion:^{
		[self markUploadComplete];
	}];
}

- (void)incrementPendingUploads {
	@synchronized (self) {
		self.pendingUploads += 1;
		self.totalUploads += 1;
		[self.ui updateProgressCompleted:self.completedUploads total:self.totalUploads];
	}
}

- (void)markUploadComplete {
	BOOL shouldHide = NO;
	BOOL shouldExit = NO;
	@synchronized (self) {
		self.pendingUploads -= 1;
		self.completedUploads += 1;
		[self.ui updateProgressCompleted:self.completedUploads total:self.totalUploads];
		if (self.pendingUploads <= 0) {
			self.pendingUploads = 0;
			self.totalUploads = 0;
			self.completedUploads = 0;
			shouldHide = YES;
			if (self.exitAfterUpload) {
				self.exitAfterUpload = NO;
				shouldExit = YES;
			}
		}
	}
	if (shouldHide) {
		[self.ui hideSyncBlocker];
	}
	if (shouldExit) {
		[self exitAppSoon];
	}
}

- (void)markDownloadComplete {
	@synchronized (self) {
		self.completedDownloads += 1;
		[self.ui updateProgressCompleted:self.completedDownloads total:self.totalDownloads];
		if (self.completedDownloads >= self.totalDownloads) {
			self.totalDownloads = 0;
			self.completedDownloads = 0;
		}
	}
}

- (void)showError:(NSString *)title detail:(NSString *)detail {
	dispatch_async(dispatch_get_main_queue(), ^{
		UIAlertController *alert = [UIAlertController alertControllerWithTitle:title message:detail preferredStyle:UIAlertControllerStyleAlert];
		[alert addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:nil]];
		[self presentAlert:alert];
	});
}

- (void)exitAppSoon {
	dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
		exit(0);
	});
}

@end
