export ARCHS = armv7 armv7s arm64
export TARGET = iphone:clang:latest:7.0

include theos/makefiles/common.mk

TWEAK_NAME = FPSCounter
FPSCounter_FILES = Tweak.xm KMCGeigerCounter.xm
FPSCounter_FRAMEWORKS = UIKit QuartzCore SpriteKit

include $(THEOS_MAKE_PATH)/tweak.mk

after-install::
	install.exec "killall -9 Preferences"
