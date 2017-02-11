DEBUG = 0
SIMULATOR = 0

ifeq ($(SIMULATOR),1)
	TARGET = simulator:clang:latest
	ARCHS = x86_64 i386
else
	TARGET = iphone:clang:latest
	ARCHS = armv7 arm64
endif

PACKAGE_VERSION = 1.1

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = LetMeSwitch
LetMeSwitch_FILES = Tweak.xm
LetMeSwitch_USE_SUBSTRATE = 1

include $(THEOS_MAKE_PATH)/tweak.mk

all::
ifeq ($(SIMULATOR),1)
	@rm -f /opt/simject/$(TWEAK_NAME).dylib
	@cp -v $(THEOS_OBJ_DIR)/$(TWEAK_NAME).dylib /opt/simject
	@cp -v $(PWD)/$(TWEAK_NAME).plist /opt/simject
endif
