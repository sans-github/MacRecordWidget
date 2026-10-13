# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Build

**Never build or install locally.** CI builds on every push to main (`.github/workflows/build.yml`, newest GitHub macOS runner, ad-hoc signed, zipped `.app` artifact). The local toolchain is often newer than CI's and accepts code CI rejects, so CI is the only verdict that counts.

To install a build:

1. Once per machine: `scripts/create-signing-cert.sh` (self-signed cert "__APP__ Local Signing" in the login keychain).
2. Each build: `scripts/install-latest.sh [run-id]`. It downloads the newest successful run, refuses if that run's commit is not local HEAD, re-signs with the cert, installs to `/Applications`, and verifies the installed cdhash.

Why re-sign: a CI build is ad-hoc signed with no Team ID, so TCC pins any permission grant (camera, mic, screen) to that exact binary's cdhash and re-prompts on every new build. Signing every build with the same certificate gives a stable code requirement. Do not add `--options runtime` unless the matching `com.apple.security.device.*` entitlements are added, or the app is killed when it touches the device.

## Architecture

- Bundle ID `__BUNDLE_ID__`, scheme `__APP__`, minimum macOS 14.0.
- Swift sources live in `__APP__/` (the Xcode target's group), not `src/`.

## Design

UI follows `.claude/skills/macos-design-system` (semantic capsules, red for capture, blue for everything else lit) on top of `.claude/skills/macos-hig`. Mocks live in `mocks/` and are approved before Swift is written.

## Gotchas

- Adding a source file requires four `project.pbxproj` edits by hand (`PBXBuildFile`, `PBXFileReference`, the group's `children`, and the sources build phase) unless the project uses synchronized folder groups.
- Every privacy-sensitive device the app touches needs its `INFOPLIST_KEY_NS*UsageDescription` set in **both** build configurations. Without it macOS terminates the app the moment the device is accessed.
- `@MainActor` on `App` and on views that touch main-actor state should be explicit, not left to inference.
