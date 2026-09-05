#!/bin/bash
# Creates a self-signed code-signing certificate in the login keychain.
#
# Why: CI produces an ad-hoc, linker-signed app with no Team ID and no
# certificate. TCC has nothing stable to key a permission grant to, so it pins
# the grant to that exact binary's cdhash. Every new build gets a new cdhash,
# the grant no longer matches, and macOS re-prompts for camera access.
#
# Signing every build with the SAME certificate gives the app a stable code
# requirement, so one grant should cover every future build.
#
# Run once. After this, use scripts/install-latest.sh for each new build.

set -euo pipefail

CN="MacRecordWidget Local Signing"
KEYCHAIN="$HOME/Library/Keychains/login.keychain-db"

if security find-identity -v -p codesigning | grep -q "$CN"; then
    echo "Certificate \"$CN\" already exists and is usable for code signing."
    exit 0
fi

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

echo "==> Generating a self-signed code-signing certificate"
openssl req -x509 -newkey rsa:2048 -sha256 -days 3650 -nodes \
    -keyout "$tmp/key.pem" -out "$tmp/cert.pem" \
    -subj "/CN=$CN" \
    -addext "basicConstraints=critical,CA:false" \
    -addext "keyUsage=critical,digitalSignature" \
    -addext "extendedKeyUsage=critical,codeSigning" 2>/dev/null

# The PKCS12 container has to be written with the legacy algorithms. OpenSSL 3
# defaults to AES-256-CBC with a SHA-256 MAC, which Apple's Security framework
# cannot read: `security import` fails with "MAC verification failed during
# PKCS12 import (wrong password?)", which is misleading, since the password is
# fine and the algorithm is the problem. A non-empty password is also required;
# an empty one fails the same way.
P12_PASS="macrecordwidget"
openssl pkcs12 -export -out "$tmp/id.p12" \
    -inkey "$tmp/key.pem" -in "$tmp/cert.pem" \
    -keypbe PBE-SHA1-3DES -certpbe PBE-SHA1-3DES -macalg sha1 \
    -passout "pass:$P12_PASS"

echo "==> Importing into the login keychain"
security import "$tmp/id.p12" -k "$KEYCHAIN" -P "$P12_PASS" \
    -T /usr/bin/codesign -T /usr/bin/security

echo "==> Trusting it for code signing"
# User-level trust. Without this the identity is present but codesign will not
# treat it as valid, and it will not show up in find-identity -v.
security add-trusted-cert -r trustRoot -p codeSign -k "$KEYCHAIN" "$tmp/cert.pem"

echo
echo "==> Pre-authorising codesign to use the key (optional)"
# Best effort, and deliberately not fatal. Without it the identity still works;
# macOS just shows a "codesign wants to use a key in your keychain" dialog the
# first time, where you click Always Allow. Getting this to run unattended needs
# the login keychain password passed on the command line, which is not worth it
# for a one-time dialog.
security set-key-partition-list -S apple-tool:,apple:,codesign: -s "$KEYCHAIN" >/dev/null 2>&1 \
    || echo "    Skipped. Click \"Always Allow\" if codesign asks for keychain access."

echo
if security find-identity -v -p codesigning | grep -q "$CN"; then
    echo "Done. \"$CN\" is ready."
    echo "Next: scripts/install-latest.sh"
else
    echo "The certificate imported but is not showing as valid for code signing."
    echo "Output of: security find-identity -v -p codesigning"
    security find-identity -v -p codesigning
    exit 1
fi
