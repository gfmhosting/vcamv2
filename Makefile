ARCHS = arm64
TARGET = iphone:clang:latest

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = CustomVCAM

CustomVCAM_FILES = Tweak.x
CustomVCAM_CFLAGS = -fobjc-arc -Wno-deprecated-declarations -Wno-error -DIOS15_COMPAT
CustomVCAM_FRAMEWORKS = UIKit Foundation AVFoundation CoreMedia CoreVideo ImageIO Photos MediaPlayer AudioToolbox WebKit IOSurface CoreGraphics QuartzCore
CustomVCAM_PRIVATE_FRAMEWORKS = SpringBoardServices IOKit MediaToolbox
CustomVCAM_LDFLAGS = -lsubstrate

include $(THEOS_MAKE_PATH)/tweak.mk

after-install::
	install.exec "sbreload"