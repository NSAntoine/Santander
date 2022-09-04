TARGET := iphone:clang:14.5:14.0
ARCHS = arm64

include $(THEOS)/makefiles/common.mk

TOOL_NAME = santanderhelper

santanderhelper_FILES = $(wildcard *.m)
santanderhelper_CFLAGS = -fobjc-arc
santanderhelper_CODESIGN_FLAGS = -Sentitlements.plist
santanderhelper_INSTALL_PATH = /usr/local/bin

include $(THEOS_MAKE_PATH)/tool.mk
