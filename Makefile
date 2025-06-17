TARGET := iphone:clang:latest:7.0
ARCHS := arm64

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = StripeVCAMBypass

$(TWEAK_NAME)_FILES = Tweak.xm VCAMOverlay.m
$(TWEAK_NAME)_CFLAGS = -fobjc-arc
$(TWEAK_NAME)_FRAMEWORKS = UIKit AVFoundation CoreMedia

include $(THEOS_MAKE_PATH)/tweak.mk

after-install::
	install.exec "killall -9 SpringBoard" 