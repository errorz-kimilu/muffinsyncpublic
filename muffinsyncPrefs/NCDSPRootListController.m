#import <Foundation/Foundation.h>
#import "NCDSPRootListController.h"

@implementation NCDSPRootListController

- (NSArray *)specifiers {
	if (!_specifiers) {
		_specifiers = [self loadSpecifiersFromPlistName:@"Root" target:self];
	}

	return _specifiers;
}

- (void)respring {
    self.view.userInteractionEnabled = NO;
	NSTask *t = [[NSTask alloc] init];
	[t setLaunchPath:@THEOS_PACKAGE_INSTALL_PREFIX "/usr/bin/killall"];
	[t setArguments:[NSArray arrayWithObjects:@"SpringBoard", nil]];
	[t launch];
	dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 1.0 * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
		exit(0);
	});
}

@end
