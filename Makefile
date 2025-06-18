ARCHS = arm64
TARGET = iphone:13.7:10.0
INSTALL_TARGET_PROCESSES = SpringBoard

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = CustomVCAM

CustomVCAM_FILES = Tweak.x Sources/MediaManager.m
CustomVCAM_CFLAGS = -fobjc-arc -Wno-deprecated-declarations -Wno-unused-variable -DSAFE_MODE
CustomVCAM_FRAMEWORKS = UIKit Foundation CoreGraphics Photos
CustomVCAM_LIBRARIES = substrate

include $(THEOS)/makefiles/tweak.mk

after-install::
	install.exec "killall -9 SpringBoard" 