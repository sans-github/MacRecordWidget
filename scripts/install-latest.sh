#!/bin/bash
# Downloads the latest successful CI build, re-signs it with the local
# certificate, and installs it to /Applications.
#
# The re-signing step is the point of this script. See
# scripts/create-signing-cert.sh for why an ad-hoc CI build loses its camera
# permission on every rebuild.

set -euo pipefail

CN="MacRecordWidget Local Signing"
APP="/Applications/MacRecordWidget.app"
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

if ! security find-identity -v -p codesigning | grep -q "$CN"; then
    echo "No signing certificate found. Run scripts/create-signing-cert.sh first." >&2
    exit 1
fi

cd "$REPO_ROOT"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

run_id="${1:-$(gh run list --workflow "Build macOS App" --branch main \
    --status success --limit 1 --json databaseId --jq '.[0].databaseId')}"

echo "==> Downloading run $run_id"
gh run download "$run_id" -D "$tmp"
unzip -qo "$tmp/MacRecordWidget/MacRecordWidget.zip" -d "$tmp"

echo "==> Signing with \"$CN\""
# Deliberately NOT --options runtime: the hardened runtime requires a
# com.apple.security.device.camera entitlement to touch the camera, and without
# it the app is killed the moment the preview opens.
codesign --force --deep --timestamp=none --sign "$CN" "$tmp/MacRecordWidget.app"
codesign --verify --deep --strict "$tmp/MacRecordWidget.app"

echo "==> Installing"
pkill -x MacRecordWidget 2>/dev/null || true
rm -rf "$APP"
cp -R "$tmp/MacRecordWidget.app" /Applications/
xattr -dr com.apple.quarantine "$APP"

echo "==> Installed. Code identity:"
codesign -dvvv "$APP" 2>&1 | grep -E "Identifier|Authority|TeamIdentifier|CDHash" || true

open -a "$APP"
echo "Launched."
