# KazumiLite — iPhone 4S / iOS 9.3.6 / armv7
# Requires Theos + iPhoneOS9.3.sdk (see .github/workflows/build-ios.yml)
TARGET := iphone:clang:9.3:9.0
ARCHS := armv7
INSTALL_TARGET_PROCESSES = KazumiLite

include $(THEOS)/makefiles/common.mk

APPLICATION_NAME = KazumiLite

KazumiLite_FILES = $(wildcard *.m) $(wildcard Models/*.m) $(wildcard Core/*.m) $(wildcard UI/*.m)
KazumiLite_FRAMEWORKS = UIKit Foundation CoreFoundation CoreGraphics QuartzCore AVFoundation CoreMedia CoreText WebKit Security ImageIO MobileCoreServices MediaPlayer CoreImage
KazumiLite_LIBRARIES = xml2 z
KazumiLite_USE_MODULES = 0
USE_MODULES = 0
KazumiLite_CFLAGS = -fobjc-arc -Wno-deprecated-declarations -Wno-deprecated-module-dot-map -Wno-error \
	-I. -IModels -ICore -IUI \
	-I$(THEOS)/sdks/iPhoneOS9.3.sdk/usr/include/libxml2
KazumiLite_INFOPLIST = $(THEOS_PROJECT_DIR)/Info.plist
KazumiLite_RESOURCE_DIRS = icons
KazumiLite_CODESIGN_FLAGS = -Sentitlements.plist
KazumiLite_LDFLAGS = -Wl,-undefined,dynamic_lookup

include $(THEOS_MAKE_PATH)/application.mk
