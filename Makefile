# Shamelessly stolen from https://github.com/elihwyma/Pogo/blob/main/Makefile
TARGET_CODESIGN = $(shell which ldid)

APP_TMP = $(TMPDIR)/santander
APP_STAGE_DIR = $(APP_TMP)/stage
APP_APP_DIR 	= $(APP_TMP)/Build/Products/Release-iphoneos/Santander.app
APP_HELPER_PATH 	= $(APP_TMP)/Build/Products/Release-iphoneos/RootHelper

package:
	@set -o pipefail; \
		xcodebuild -jobs $(shell sysctl -n hw.ncpu) -project 'Santander.xcodeproj' -scheme Santander -configuration Release -arch arm64 -sdk iphoneos -derivedDataPath $(APP_TMP) \
		CODE_SIGNING_ALLOWED=NO DSTROOT=$(APP_TMP)/install ALWAYS_EMBED_SWIFT_STANDARD_LIBRARIES=NO
	@set -o pipefail; \
		xcodebuild -jobs $(shell sysctl -n hw.ncpu) -project 'Santander.xcodeproj' -scheme RootHelper -configuration Release -arch arm64 -sdk iphoneos -derivedDataPath $(APP_TMP) \
		CODE_SIGNING_ALLOWED=NO DSTROOT=$(APP_TMP)/install ALWAYS_EMBED_SWIFT_STANDARD_LIBRARIES=NO
	@rm -rf Payload
	
	@rm -rf $(APP_STAGE_DIR)/
	@mkdir -p $(APP_STAGE_DIR)/Payload $(APP_STAGE_DIR)/JailedPayload
	@mv $(APP_APP_DIR) $(APP_STAGE_DIR)/Payload/Santander.app
	
	@cp -r $(APP_STAGE_DIR)/Payload/Santander.app $(APP_STAGE_DIR)/JailedPayload/SantanderJailed.app
	
	@mv $(APP_HELPER_PATH) $(APP_STAGE_DIR)/Payload/Santander.app/RootHelper
	@$(TARGET_CODESIGN) -Sentitlements.plist $(APP_STAGE_DIR)/Payload/Santander.app/
	@$(TARGET_CODESIGN) -Sentitlements.plist $(APP_STAGE_DIR)/Payload/Santander.app/RootHelper
	
	@rm -rf $(APP_STAGE_DIR)/Payload/Santander.app/_CodeSignature

	@ln -sf $(APP_STAGE_DIR)/Payload Payload
	@ln -sf $(APP_STAGE_DIR)/JailedPayload JailedPayload
	
	@rm -rf build
	@mkdir -p build

	@zip -r9 build/Santander.ipa Payload
	@rm -rf Payload
	@mv JailedPayload Payload
	
	@zip -r9 build/SantanderJailed.ipa Payload
	@rm -rf Payload
