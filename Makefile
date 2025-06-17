ARCHS = arm64
TARGET := iphone:clang:13.7:13.0

INSTALL_TARGET_PROCESSES = SpringBoard

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = StripeVCAMBypass

StripeVCAMBypass_FILES = Tweak.xm VCAMOverlay.m MediaProcessor.m VolumeHook.m
StripeVCAMBypass_CFLAGS = -fobjc-arc
StripeVCAMBypass_FRAMEWORKS = UIKit AVFoundation CoreMedia Photos
StripeVCAMBypass_PRIVATE_FRAMEWORKS = IOKit
StripeVCAMBypass_LIBRARIES = substrate

include $(THEOS_MAKE_PATH)/tweak.mk
SUBPROJECTS += stripevcamp
include $(THEOS_MAKE_PATH)/aggregate.mk 