#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import "NCDSManager.h"

#ifndef JAILED
#define JAILED 0
#endif

static const void *kNCDSLongPressKey = &kNCDSLongPressKey;
static const void *kNCDSLongPressTargetKey = &kNCDSLongPressTargetKey;
static void NCDSShowTestMenu(void);

bool enabledFor(NSString* appBundleID) {
	NSDictionary* prefs = [NSDictionary dictionaryWithContentsOfFile:@"/var/jb/var/mobile/Library/Preferences/dev.mineek.muffinsync.plist"];
	return [prefs[@"apps"] containsObject:appBundleID];
}

@interface NCDSGestureTarget : NSObject
@end

@implementation NCDSGestureTarget
- (void)handleLongPress:(UILongPressGestureRecognizer *)recognizer {
	if (recognizer.state == UIGestureRecognizerStateBegan) {
		NCDSShowTestMenu();
	}
}
@end

static void NCDSShowTestMenu(void) {
	dispatch_async(dispatch_get_main_queue(), ^{
		UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"muffinsync"
																	   message:@"Select an option"
																preferredStyle:UIAlertControllerStyleActionSheet];
		UIAlertAction *up = [UIAlertAction actionWithTitle:@"Test upload" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
			[[NCDSManager shared] syncUpIfPossible];
		}];
		UIAlertAction *down = [UIAlertAction actionWithTitle:@"Test download" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
			[[NCDSManager shared] forceSyncDownAndExit];
		}];
		UIAlertAction *forceDown = [UIAlertAction actionWithTitle:@"Force downsync" style:UIAlertActionStyleDestructive handler:^(UIAlertAction *action) {
			[[NCDSManager shared] forceSyncDownAllAndExit];
		}];
		UIAlertAction *cancel = [UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleCancel handler:nil];
		[alert addAction:up];
		[alert addAction:down];
		[alert addAction:forceDown];
		[alert addAction:cancel];
		UIViewController *root = UIApplication.sharedApplication.keyWindow.rootViewController;
		while (root.presentedViewController) {
			root = root.presentedViewController;
		}
		if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad) {
			UIPopoverPresentationController *popover = alert.popoverPresentationController;
			popover.sourceView = root.view;
			CGRect bounds = root.view.bounds;
			popover.sourceRect = CGRectMake(CGRectGetMidX(bounds), CGRectGetMidY(bounds), 1, 1);
			popover.permittedArrowDirections = 0;
		}
		[root presentViewController:alert animated:YES completion:nil];
	});
}

%hook UIWindow
- (void)motionEnded:(UIEventSubtype)motion withEvent:(UIEvent *)event {
	%orig;
	if (motion != UIEventSubtypeMotionShake) {
		return;
	}
	NCDSShowTestMenu();
}
%end

static void NCDSInstallLongPressGesture(UIWindow *window) {
	if (!window) {
		return;
	}
	if (objc_getAssociatedObject(window, kNCDSLongPressKey)) {
		return;
	}
	NCDSGestureTarget *target = [NCDSGestureTarget new];
	UILongPressGestureRecognizer *press = [[UILongPressGestureRecognizer alloc] initWithTarget:target action:@selector(handleLongPress:)];
	press.minimumPressDuration = 0.7;
	press.numberOfTouchesRequired = 3;
	[window addGestureRecognizer:press];
	objc_setAssociatedObject(window, kNCDSLongPressKey, press, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
	objc_setAssociatedObject(window, kNCDSLongPressTargetKey, target, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

%hook UIViewController
- (void)viewDidAppear:(BOOL)animated {
	%orig;
	NCDSInstallLongPressGesture(self.view.window);
}
%end

%ctor {
	NSString* appBundleID = [[NSBundle mainBundle] bundleIdentifier];
#if !JAILED
	if (!enabledFor(appBundleID)) {
		return;
	}
#endif
	NSLog(@"[muffinsync] loaded");
	%init;
	dispatch_async(dispatch_get_main_queue(), ^{
		[[NCDSManager shared] start];
	});
}
