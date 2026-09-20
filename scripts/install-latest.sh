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

# Deliberately NOT `--status success`. That filter is served from an index
# that lags behind the run itself: a run `gh run watch` has just reported as
# successful can still be missing from it for a minute or so, and the query
# then silently returns the *previous* build. That has installed the wrong
# binary twice, with nothing in the output to say so.
#
# So take the newest run whatever its state, and refuse to continue unless it
# is a finished, successful one. Being told to wait beats being handed a stale
# app that looks installed.
if [ $# -ge 1 ]; then
    run_id="$1"
else
    read -r run_id run_status run_conclusion <<<"$(gh run list \
        --workflow "Build macOS App" --branch main --limit 1 \
        --json databaseId,status,conclusion \
        --jq '.[0] | "\(.databaseId) \(.status) \(.conclusion // "-")"')"
    if [ "$run_status" != "completed" ] || [ "$run_conclusion" != "success" ]; then
        echo "Latest CI run $run_id is $run_status/$run_conclusion, not installing." >&2
        echo "Wait for it, or pass a run id: scripts/install-latest.sh <run-id>" >&2
        exit 1
    fi
fi

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
