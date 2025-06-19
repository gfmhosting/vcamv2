ARCHS = arm64
TARGET = iphone:13.7:13.0

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = CustomVCAM

CustomVCAM_FILES = Tweak.x
CustomVCAM_CFLAGS = -fobjc-arc -Wno-deprecated-declarations -Wno-error
CustomVCAM_FRAMEWORKS = UIKit Foundation AVFoundation CoreMedia CoreVideo ImageIO Photos MediaPlayer AudioToolbox WebKit
CustomVCAM_PRIVATE_FRAMEWORKS = SpringBoardServices
CustomVCAM_LDFLAGS = -lsubstrate

include $(THEOS_MAKE_PATH)/tweak.mk

after-install::
	install.exec "sbreload"