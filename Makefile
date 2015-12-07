export ARCHS = armv7 armv7s arm64
export TARGET = iphone:clang:9.1:7.0

include theos/makefiles/common.mk

TWEAK_NAME = FPSCounter
FPSCounter_FILES = Tweak.xm

include $(THEOS_MAKE_PATH)/tweak.mk

after-install::
	install.exec "killall -9 Preferences"
