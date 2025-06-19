ARCHS = arm64
TARGET = iphone:13.7:13.0

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = CustomVCAM

CustomVCAM_FILES = Tweak.x Sources/MediaManager.m Sources/OverlayView.m Sources/SimpleMediaManager.m
CustomVCAM_CFLAGS = -fobjc-arc
CustomVCAM_FRAMEWORKS = UIKit Foundation AVFoundation CoreMedia CoreVideo ImageIO Photos PhotosUI
CustomVCAM_PRIVATE_FRAMEWORKS = IOKit SpringBoardServices
CustomVCAM_LDFLAGS = -lsubstrate

include $(THEOS_MAKE_PATH)/tweak.mk

after-install::
	install.exec "sbreload" 