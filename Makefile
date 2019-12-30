TARGET = iphone:clang:9.2
ARCHS = arm64 arm64e

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = ShyLabels
$(TWEAK_NAME)_FILES = Tweak.xm
$(TWEAK_NAME)_CFLAGS = -fobjc-arc

include $(THEOS_MAKE_PATH)/tweak.mk

SUBPROJECTS += preferences

include $(THEOS_MAKE_PATH)/aggregate.mk

after-install::
	install.exec "killall -9 SpringBoard"
