SIMULATOR = 0

ifeq ($(SIMULATOR),1)
	TARGET = simulator:clang:latest:8.0
	ARCHS = x86_64 i386
else
	ifeq ($(THEOS_PACKAGE_SCHEME),rootless)
		TARGET = iphone:clang:latest:14.0
		ARCHS = arm64 arm64e
	else
		TARGET = iphone:clang:14.5:8.0
		export PREFIX = $(THEOS)/toolchain/Xcode11.xctoolchain/usr/bin/
	endif
endif

PACKAGE_VERSION = 1.2.0

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = LetMeSwitch
$(TWEAK_NAME)_FILES = Tweak.xm
$(TWEAK_NAME)_USE_SUBSTRATE = 1

include $(THEOS_MAKE_PATH)/tweak.mk

all::
ifeq ($(SIMULATOR),1)
	@rm -f /opt/simject/$(TWEAK_NAME).dylib
	@cp -v $(THEOS_OBJ_DIR)/$(TWEAK_NAME).dylib /opt/simject
	@cp -v $(PWD)/$(TWEAK_NAME).plist /opt/simject
endif
