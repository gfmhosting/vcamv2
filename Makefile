TARGET := iphone:clang:13.7:13.0
INSTALL_TARGET_PROCESSES = SpringBoard

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = CustomVCAM

CustomVCAM_FILES = Tweak.x Sources/MediaManager.m Sources/OverlayView.m
CustomVCAM_CFLAGS = -fobjc-arc
CustomVCAM_FRAMEWORKS = UIKit Foundation AVFoundation Photos CoreGraphics CoreMedia VideoToolbox
CustomVCAM_PRIVATE_FRAMEWORKS = SpringBoard IOKit

include $(THEOS)/makefiles/tweak.mk 