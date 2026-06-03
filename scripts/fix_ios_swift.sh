#!/usr/bin/env bash
# Post-export fix for Godot 4.6 iOS projects built with Xcode 26+.
#
# Godot 4.6's iOS template ships a SwiftUI-based app launcher inside libgodot.a,
# so the app must link the Swift runtime. The generated Xcode project doesn't,
# so the link fails with:
#   Undefined symbols: _swift_getOpaqueTypeConformance,
#                      _swift_getTypeByMangledNameInContextInMetadataState
# (these live in libswiftCore). The templates are also built for iOS 14, so a
# lower deployment target both warns and breaks Swift-in-OS linking.
#
# This script makes the exported project link:
#   1. deployment target ≥ 14.0  (matches the templates; Swift ships in iOS 14)
#   2. add $(SDKROOT)/usr/lib/swift to LIBRARY_SEARCH_PATHS  (where libswiftCore is)
#   3. force-link swiftCore via OTHER_LDFLAGS  (Xcode 26 ignores the autolink hint)
#
# Run once after every `Export Project…` (the .xcodeproj is regenerated each
# export). Idempotent. Then open the project in Xcode and Build / Archive.
#
# NOTE: when Godot reports "[Xcode Build]: Failed to run xcodebuild" during the
# export, that's just Godot's own auto-build — the Xcode project IS still written
# to build/ios/. Ignore it, run this script, then build in Xcode.
#
# Usage: scripts/fix_ios_swift.sh [path/to/project.pbxproj]
set -euo pipefail

PBX="${1:-build/ios/lemmings.xcodeproj/project.pbxproj}"
if [ ! -f "$PBX" ]; then
	echo "pbxproj not found: $PBX" >&2
	echo "Pass the path, e.g.: scripts/fix_ios_swift.sh build/ios/lemmings.xcodeproj/project.pbxproj" >&2
	exit 1
fi

changed=0

# 1. Deployment target → 14.0 (raise anything lower; leave 14+ alone).
if grep -qE "IPHONEOS_DEPLOYMENT_TARGET = (12|13)\." "$PBX"; then
	perl -0pi -e 's/IPHONEOS_DEPLOYMENT_TARGET = (?:12|13)\.\d+;/IPHONEOS_DEPLOYMENT_TARGET = 14.0;/g' "$PBX"
	changed=1
fi

# 2. SDK Swift library path (libswiftCore.tbd lives here).
if ! grep -q 'SDKROOT)/usr/lib/swift' "$PBX"; then
	perl -0pi -e 's{(LIBRARY_SEARCH_PATHS = \(\n\s*"\$\(inherited\)",)}{$1\n\t\t\t\t\t"\$(SDKROOT)/usr/lib/swift",}g' "$PBX"
	changed=1
fi

# 3. Force-link swiftCore (Xcode 26's linker drops the static-archive autolink hint).
if ! grep -q 'OTHER_LDFLAGS = ("-lswiftCore")' "$PBX"; then
	perl -0pi -e 's{(\n(\s*)SWIFT_VERSION = 5\.0;)}{$1\n$2OTHER_LDFLAGS = ("-lswiftCore");}g' "$PBX"
	changed=1
fi

if [ "$changed" -eq 1 ]; then
	echo "Patched $PBX (deployment target 14 + Swift runtime link)."
	echo "Now open build/ios/lemmings.xcodeproj in Xcode and Build / Archive."
else
	echo "$PBX already patched — nothing to do."
fi
