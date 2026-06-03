#!/usr/bin/env bash
# Post-export fix for Godot 4.6 iOS projects built with Xcode 26+.
#
# Godot adds a `dummy.swift` shim to pull in the Swift runtime, but the generated
# Xcode project doesn't set ALWAYS_EMBED_SWIFT_STANDARD_LIBRARIES nor a Swift
# library search path, so on recent Xcode the link fails with:
#   Undefined symbol: _swift_getOpaqueTypeConformance
#   Undefined symbol: _swift_getTypeByMangledNameInContextInMetadataState
#
# Run this once after every `Export Project…` (the .xcodeproj is regenerated each
# export). Idempotent. Then in Xcode: Product → Clean Build Folder → Build.
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
if ! grep -q "ALWAYS_EMBED_SWIFT_STANDARD_LIBRARIES" "$PBX"; then
	perl -0pi -e 's/(\n(\s*)SWIFT_VERSION = 5\.0;)/$1\n$2ALWAYS_EMBED_SWIFT_STANDARD_LIBRARIES = YES;/g' "$PBX"
	changed=1
fi
if ! grep -q 'TOOLCHAIN_DIR)/usr/lib/swift' "$PBX"; then
	perl -0pi -e 's{(LIBRARY_SEARCH_PATHS = \(\n\s*"\$\(inherited\)",)}{$1\n\t\t\t\t\t"\$(TOOLCHAIN_DIR)/usr/lib/swift/\$(PLATFORM_NAME)",}g' "$PBX"
	changed=1
fi

if [ "$changed" -eq 1 ]; then
	echo "Patched $PBX for Swift runtime linking. Now Clean Build Folder + rebuild in Xcode."
else
	echo "$PBX already patched — nothing to do."
fi
