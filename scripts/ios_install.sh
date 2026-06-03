#!/usr/bin/env bash
# Install a built .app onto a connected iOS device via devicectl (Xcode 15+).
# Usage: scripts/ios_install.sh <path/to/App.app> [device-udid]
set -euo pipefail

APP="${1:?usage: ios_install.sh <App.app> [device-udid]}"
DEVICE="${2:-}"

if [ ! -d "$APP" ]; then
	echo "App bundle not found: $APP" >&2
	exit 1
fi

if [ -z "$DEVICE" ]; then
	JSON="$(mktemp)"
	xcrun devicectl list devices --json-output "$JSON" >/dev/null 2>&1 || true
	DEVICE="$(python3 - "$JSON" <<'PY'
import json, sys
try:
    data = json.load(open(sys.argv[1]))
except Exception:
    print(""); sys.exit(0)
devices = data.get("result", {}).get("devices", [])
# Prefer a device whose tunnel is actually connected.
def udid(d):
    return d.get("identifier") or d.get("hardwareProperties", {}).get("udid", "")
for d in devices:
    if d.get("connectionProperties", {}).get("tunnelState") == "connected":
        print(udid(d)); sys.exit(0)
for d in devices:
    if udid(d):
        print(udid(d)); sys.exit(0)
print("")
PY
)"
	rm -f "$JSON"
fi

if [ -z "$DEVICE" ]; then
	echo "No connected device found." >&2
	echo "Connect an unlocked, trusted iPhone/iPad, or pass one explicitly:" >&2
	echo "  make install DEVICE=<udid>     (list: xcrun devicectl list devices)" >&2
	exit 1
fi

echo "Installing $(basename "$APP") onto device $DEVICE ..."
xcrun devicectl device install app --device "$DEVICE" "$APP"
echo "Done. On first launch, trust the developer in:"
echo "  Settings → General → VPN & Device Management → <your Apple ID>"
