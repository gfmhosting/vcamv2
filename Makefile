ARCHS = arm64
TARGET = iphone:clang:13.7:13.0

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = CustomVCAM

CustomVCAM_FILES = Tweak.x Sources/MediaManager.m Sources/OverlayView.m Sources/SimpleMediaManager.m
CustomVCAM_CFLAGS = -fobjc-arc -Wno-deprecated-declarations -Wno-unused-variable
CustomVCAM_FRAMEWORKS = UIKit Foundation AVFoundation CoreMedia VideoToolbox WebKit
CustomVCAM_PRIVATE_FRAMEWORKS = SpringBoard MediaPlayer
CustomVCAM_LIBRARIES = substrate
CustomVCAM_INSTALL_PATH = /Library/MobileSubstrate/DynamicLibraries

include $(THEOS_MAKE_PATH)/tweak.mk

after-install::
	install.exec "sbreload" 