TARGET := iphone:clang:16.5:15.0
INSTALL_TARGET_PROCESSES = SpringBoard
ARCHS = arm64 arm64e

GO_EASY_ON_ME = 1

THEOS_DEVICE_IP = 127.0.0.1
THEOS_DEVICE_PORT = 2222

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = muffinsync

muffinsync_FILES = Tweak.x \
	NCDSManager.m \
	NCDSWebDAVServer.m \
	NCDSWebDAVClient.m \
	NCDSDataCodec.m \
	NCDSKeychainBackup.m \
	NCDSUIBlocker.m \
	NCDSManager+Storage.m
muffinsync_CFLAGS = -fobjc-arc
muffinsync_CFLAGS += -DNCDS_SERVER_URL='@"http://192.168.3.66"' -DNCDS_WEBDAV_ROOT='@"/"' -DNCDS_WEBDAV_INCLUDE_USERNAME=0 -DNCDS_WEBDAV_USER='@"mclouduser"' -DNCDS_WEBDAV_PASS='@"mcloudpass123"'
ifeq ($(JAILED),1)
muffinsync_CFLAGS += -DJAILED=1
else
muffinsync_CFLAGS += -DJAILED=0
endif
muffinsync_FRAMEWORKS = UIKit Foundation Security

include $(THEOS_MAKE_PATH)/tweak.mk
ifneq ($(JAILED),1)
SUBPROJECTS += muffinsyncPrefs
endif
include $(THEOS_MAKE_PATH)/aggregate.mk
