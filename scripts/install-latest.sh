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
# `--limit 1` is not enough either, and that one cost a whole debugging
# session on 2026-09-28: the listing came back with a four-day-old run in
# position 0 while two newer ones existed, and the app that got installed
# predated the camera preview entirely. So ask for ten and take the newest by
# createdAt rather than trusting the order the API returns.
#
# Then check the run's commit against local HEAD. A stale listing, a build
# that has not finished, or an unpushed commit all show up here as a mismatch
# instead of as an app that quietly behaves like an older version.
if [ $# -ge 1 ]; then
    run_id="$1"
else
    read -r run_id run_status run_conclusion run_sha <<<"$(gh run list \
        --workflow "Build macOS App" --branch main --limit 10 \
        --json databaseId,status,conclusion,createdAt,headSha \
        --jq 'sort_by(.createdAt) | last | "\(.databaseId) \(.status) \(.conclusion // "-") \(.headSha)"')"
    if [ "$run_status" != "completed" ] || [ "$run_conclusion" != "success" ]; then
        echo "Latest CI run $run_id is $run_status/$run_conclusion, not installing." >&2
        echo "Wait for it, or pass a run id: scripts/install-latest.sh <run-id>" >&2
        exit 1
    fi
    head_sha="$(git rev-parse HEAD)"
    if [ "$run_sha" != "$head_sha" ]; then
        echo "Run $run_id built ${run_sha:0:7}, but local HEAD is ${head_sha:0:7}." >&2
        echo "Push first, wait for that build, or pass a run id to install this one anyway." >&2
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

# The copy is the last place a wrong binary can creep in, so prove the bundle
# on disk is the one just signed rather than whatever was there before.
signed_hash="$(codesign -dvvv "$tmp/MacRecordWidget.app" 2>&1 | awk -F= '/^CDHash/ {print $2}')"
installed_hash="$(codesign -dvvv "$APP" 2>&1 | awk -F= '/^CDHash/ {print $2}')"
if [ "$signed_hash" != "$installed_hash" ]; then
    echo "Installed app does not match what was just signed ($installed_hash vs $signed_hash)." >&2
    exit 1
fi

echo "==> Installed. Code identity:"
codesign -dvvv "$APP" 2>&1 | grep -E "Identifier|Authority|TeamIdentifier|CDHash" || true

open -a "$APP"
echo "Launched."
