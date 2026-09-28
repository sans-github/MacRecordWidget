# Installing MacRecordWidget

Run once, to create a local signing certificate:

```bash
scripts/create-signing-cert.sh
```

Then, for this and every later build:

```bash
scripts/install-latest.sh
```

That downloads the latest CI build, signs it, installs it to `/Applications`
and launches it. If the newest build is still running or failed, it stops and
says so rather than quietly installing the one before it. Pass a run id
(`scripts/install-latest.sh <run-id>`) to install a specific build.

### Why the certificate

CI builds are ad-hoc signed, with no Team ID and no certificate. macOS has
nothing stable to attach a permission grant to, so it pins your camera approval
to that one binary's hash. Every new build has a different hash, the grant stops
matching, and you get asked for camera access again.

Signing each build with the same local certificate gives the app a stable code
identity, so one grant covers later builds.

### Manual install

If you would rather not use the scripts: download `MacRecordWidget.zip` from the
[Actions tab](../../actions), unzip it, move `MacRecordWidget.app` to
`/Applications`, and right-click > **Open** on first launch. You will be
re-asked for camera access after every build.

