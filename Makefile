ARCHS = arm64
TARGET = iphone:13.0:13.0
INSTALL_TARGET_PROCESSES = SpringBoard

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = CustomVCAM

CustomVCAM_FILES = Tweak.x Sources/MediaManager.m Sources/OverlayView.m
CustomVCAM_CFLAGS = -fobjc-arc -Wno-deprecated-declarations -Wno-unused-variable
CustomVCAM_FRAMEWORKS = UIKit Foundation AVFoundation Photos CoreGraphics QuartzCore
CustomVCAM_LIBRARIES = substrate

include $(THEOS)/makefiles/tweak.mk

after-install::
	install.exec "killall -9 SpringBoard" 