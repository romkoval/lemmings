# iOS build pipeline for the Lemmings clone — Godot 4.6 + Xcode 26.
#
# Why a Makefile: Godot's GUI "Export" to a .ipa runs xcodebuild itself against
# the freshly-generated (unpatched) Xcode project, which fails on the Swift
# runtime link. This pipeline instead exports the project *headless* (which does
# NOT auto-build), patches it (scripts/fix_ios_swift.sh), then builds/installs.
#
#   make install            # export → patch → signed Debug build → install on device
#   make build              # export → patch → signed Debug build (no install)
#   make ipa                # export → patch → Release archive → export .ipa (TestFlight)
#   make export / make patch   # individual steps
#   make clean
#
# Override any variable, e.g.:  make install DEVICE=<udid>   or   make GODOT=/path/to/godot
GODOT     ?= godot
PRESET    ?= iOS
TEAM      ?= 2HVHF23TWZ
BUILD_DIR ?= build/ios
CONFIG    ?= Debug
DEVICE    ?=

XCODEPROJ := $(BUILD_DIR)/lemmings.xcodeproj
PBXPROJ   := $(XCODEPROJ)/project.pbxproj
APP       := $(BUILD_DIR)/build/$(CONFIG)-iphoneos/lemmings.app
FIX       := scripts/fix_ios_swift.sh

ifeq ($(CONFIG),Release)
EXPORT_FLAG := --export-release
else
EXPORT_FLAG := --export-debug
endif

.PHONY: all build install ipa export patch clean

all: build

# 1) Headless export → generates the Xcode project. Godot also tries to run
#    xcodebuild on the still-unpatched project and fails — that's EXPECTED and
#    harmless (the .xcodeproj is written first). We ignore Godot's exit code and
#    just assert the project exists; the patch + build below do the real work.
export:
	@mkdir -p $(BUILD_DIR)
	-@$(GODOT) --headless $(EXPORT_FLAG) "$(PRESET)" $(BUILD_DIR)/lemmings.ipa 2>&1 | grep -viE "Failed to run xcodebuild|export.*failed" || true
	@test -f $(PBXPROJ) || { echo "ERROR: $(PBXPROJ) not generated — check the Godot export preset/templates"; exit 1; }
	@echo "Exported Xcode project → $(XCODEPROJ)"

# 2) Patch the generated project: Swift runtime link + iOS 14 + universal family.
patch: export
	@chmod +x $(FIX)
	@$(FIX) $(PBXPROJ)

# 3) Signed device build (automatic provisioning via your Apple ID in Xcode).
build: patch
	xcodebuild -project $(XCODEPROJ) -target lemmings -configuration $(CONFIG) \
		-sdk iphoneos -destination 'generic/platform=iOS' \
		-allowProvisioningUpdates DEVELOPMENT_TEAM=$(TEAM) \
		build
	@echo "Built: $(APP)"

# 4) Install onto a connected iPhone/iPad (auto-detected, or pass DEVICE=<udid>).
install: build
	@chmod +x scripts/ios_install.sh
	@scripts/ios_install.sh "$(APP)" "$(DEVICE)"

# Release archive + .ipa for TestFlight / App Store. Override METHOD if needed
# (app-store-connect | release-testing | debugging).
METHOD ?= app-store-connect
ipa: CONFIG := Release
ipa:
	@$(MAKE) patch CONFIG=Release
	xcodebuild -project $(XCODEPROJ) -scheme lemmings -configuration Release \
		-sdk iphoneos -allowProvisioningUpdates DEVELOPMENT_TEAM=$(TEAM) \
		-archivePath $(BUILD_DIR)/lemmings.xcarchive archive
	@printf '<?xml version="1.0" encoding="UTF-8"?>\n<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">\n<plist version="1.0"><dict>\n<key>method</key><string>$(METHOD)</string>\n<key>teamID</key><string>$(TEAM)</string>\n<key>signingStyle</key><string>automatic</string>\n<key>destination</key><string>export</string>\n</dict></plist>\n' > $(BUILD_DIR)/ExportOptions.plist
	xcodebuild -exportArchive -archivePath $(BUILD_DIR)/lemmings.xcarchive \
		-exportPath $(BUILD_DIR)/ipa -exportOptionsPlist $(BUILD_DIR)/ExportOptions.plist \
		-allowProvisioningUpdates
	@echo "IPA → $(BUILD_DIR)/ipa/  (upload to App Store Connect / TestFlight)"

clean:
	rm -rf $(BUILD_DIR)
