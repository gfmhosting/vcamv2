ARCHS = arm64
TARGET = iphone:13.7:13.0

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = TTtest

TTtest_FILES = Tweak.x
TTtest_CFLAGS = -fobjc-arc -Wno-deprecated-declarations -Wno-error
TTtest_FRAMEWORKS = UIKit Foundation AVFoundation CoreMedia CoreVideo ImageIO Photos MediaPlayer AudioToolbox WebKit
TTtest_PRIVATE_FRAMEWORKS = SpringBoardServices
TTtest_LDFLAGS = -lsubstrate

include $(THEOS_MAKE_PATH)/tweak.mk

after-install::
	install.exec "sbreload"