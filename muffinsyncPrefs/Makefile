TARGET := iphone:clang:16.5:15.0
ARCHS = arm64 arm64e
GO_EASY_ON_ME = 1

include $(THEOS)/makefiles/common.mk

BUNDLE_NAME = muffinsyncPrefs

muffinsyncPrefs_FILES = NCDSPRootListController.m
muffinsyncPrefs_FRAMEWORKS = UIKit
muffinsyncPrefs_PRIVATE_FRAMEWORKS = Preferences
muffinsyncPrefs_INSTALL_PATH = /Library/PreferenceBundles
muffinsyncPrefs_CFLAGS = -fobjc-arc
muffinsyncPrefs_EXTRA_FRAMEWORKS = AltList

include $(THEOS_MAKE_PATH)/bundle.mk
