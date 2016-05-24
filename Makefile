DEBUG = 0
GO_EASY_ON_ME = 1

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = LetMeSwitch
LetMeSwitch_FILES = Tweak.xm
#LetMeSwitch_LIBRARIES = inspectivec

include $(THEOS_MAKE_PATH)/tweak.mk


