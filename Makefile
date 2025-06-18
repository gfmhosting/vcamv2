TARGET := iphone:clang:13.7:13.0
INSTALL_TARGET_PROCESSES = SpringBoard

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = CustomVCAM

CustomVCAM_FILES = Tweak.x Sources/SimpleMediaManager.m Sources/OverlayView.m
CustomVCAM_CFLAGS = -fobjc-arc -Wno-deprecated-declarations -Wno-unused-variable
CustomVCAM_FRAMEWORKS = UIKit Foundation AVFoundation Photos CoreGraphics CoreMedia VideoToolbox
CustomVCAM_PRIVATE_FRAMEWORKS = IOKit

include $(THEOS)/makefiles/tweak.mk 