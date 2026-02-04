#import "NCDSUIBlocker.h"

@interface NCDSUIBlocker ()
@property (nonatomic, strong) UIWindow *blockingWindow;
@property (nonatomic, strong) UIWindow *syncWindow;
@property (nonatomic, weak) UIProgressView *syncProgressView;
@property (nonatomic, weak) UILabel *syncStatusLabel;
@end

@implementation NCDSUIBlocker

- (void)showAuthRequiredBlocker {
	dispatch_async(dispatch_get_main_queue(), ^{
		if (self.blockingWindow) {
			return;
		}
		UIWindow *window = [[UIWindow alloc] initWithFrame:UIScreen.mainScreen.bounds];
		window.windowLevel = UIWindowLevelAlert + 1;
		UIViewController *root = [UIViewController new];
		window.rootViewController = root;
		window.hidden = NO;
		self.blockingWindow = window;

		UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"mCloud authentication required"
																	   message:@"Authentication failed, or was cancelled. Please re-run the app, or disable muffinsync for this app."
																preferredStyle:UIAlertControllerStyleAlert];
		[root presentViewController:alert animated:YES completion:nil];
	});
}

- (void)showSyncBlockerWithMessage:(NSString *)message {
	dispatch_async(dispatch_get_main_queue(), ^{
		if (self.syncWindow) {
			return;
		}
		UIWindow *window = [[UIWindow alloc] initWithFrame:UIScreen.mainScreen.bounds];
		window.windowLevel = UIWindowLevelAlert + 2;
		UIViewController *root = [UIViewController new];
		root.view.backgroundColor = [UIColor colorWithWhite:0 alpha:0.5];
		window.rootViewController = root;
		window.hidden = NO;
		self.syncWindow = window;

		UIActivityIndicatorView *spinner = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleLarge];
		spinner.translatesAutoresizingMaskIntoConstraints = NO;
		[spinner startAnimating];

		UILabel *label = [[UILabel alloc] init];
		label.translatesAutoresizingMaskIntoConstraints = NO;
		label.text = message ?: @"Syncing";
		label.textColor = UIColor.whiteColor;
		label.font = [UIFont boldSystemFontOfSize:16.0];
		label.numberOfLines = 0;
		label.textAlignment = NSTextAlignmentCenter;

		UIProgressView *progress = [[UIProgressView alloc] initWithProgressViewStyle:UIProgressViewStyleDefault];
		progress.translatesAutoresizingMaskIntoConstraints = NO;
		progress.progress = 0.0f;

		UILabel *status = [[UILabel alloc] init];
		status.translatesAutoresizingMaskIntoConstraints = NO;
		status.textColor = UIColor.whiteColor;
		status.font = [UIFont systemFontOfSize:12.0];
		status.numberOfLines = 1;
		status.textAlignment = NSTextAlignmentCenter;

		[root.view addSubview:spinner];
		[root.view addSubview:label];
		[root.view addSubview:progress];
		[root.view addSubview:status];

		[NSLayoutConstraint activateConstraints:@[
			[spinner.centerXAnchor constraintEqualToAnchor:root.view.centerXAnchor],
			[spinner.centerYAnchor constraintEqualToAnchor:root.view.centerYAnchor constant:-12],
			[label.topAnchor constraintEqualToAnchor:spinner.bottomAnchor constant:12],
			[label.leadingAnchor constraintGreaterThanOrEqualToAnchor:root.view.leadingAnchor constant:24],
			[label.trailingAnchor constraintLessThanOrEqualToAnchor:root.view.trailingAnchor constant:-24],
			[label.centerXAnchor constraintEqualToAnchor:root.view.centerXAnchor],
			[progress.topAnchor constraintEqualToAnchor:label.bottomAnchor constant:16],
			[progress.leadingAnchor constraintEqualToAnchor:root.view.leadingAnchor constant:32],
			[progress.trailingAnchor constraintEqualToAnchor:root.view.trailingAnchor constant:-32],
			[status.topAnchor constraintEqualToAnchor:progress.bottomAnchor constant:8],
			[status.centerXAnchor constraintEqualToAnchor:root.view.centerXAnchor]
		]];

		self.syncProgressView = progress;
		self.syncStatusLabel = status;
	});
}

- (void)hideSyncBlocker {
	dispatch_async(dispatch_get_main_queue(), ^{
		self.syncWindow.hidden = YES;
		self.syncWindow = nil;
		self.syncProgressView = nil;
		self.syncStatusLabel = nil;
	});
}

- (void)updateProgressCompleted:(NSInteger)completed total:(NSInteger)total {
	dispatch_async(dispatch_get_main_queue(), ^{
		if (!self.syncWindow) {
			return;
		}
		if (total <= 0) {
			self.syncProgressView.progress = 0.0f;
			self.syncStatusLabel.text = @"";
			return;
		}
		float progress = (float)completed / (float)MAX(total, 1);
		self.syncProgressView.progress = progress;
		NSInteger remaining = MAX(total - completed, 0);
		self.syncStatusLabel.text = [NSString stringWithFormat:@"%ld of %ld files (remaining %ld)", (long)completed, (long)total, (long)remaining];
		[self.syncProgressView.superview layoutIfNeeded];
	});
}

@end
