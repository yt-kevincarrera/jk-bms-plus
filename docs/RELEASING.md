# Publishing a release

The app has no store behind it. It updates itself from the releases of this
repository, which makes the release process part of the product rather than an
afterthought.

## The signing key is the whole thing

`android/app/jkbms-release.jks`, with its passwords in `android/key.properties`.
Neither is in the repository and neither ever should be.

Android refuses to install an update signed with a different key than the
installed app. So:

- **Lose this key and in-app updates end permanently.** Every future version
  would have to be installed by hand, after uninstalling — which also wipes the
  ride history and every stored reading.
- **Back it up somewhere that is not this machine.** A password manager or an
  encrypted drive. Both files, together; the keystore is useless without the
  passwords.
- Anyone holding it can publish a package that installs over this app. That is
  the reason it stays out of the repo even while the repo is private.

A clone without `key.properties` still builds — it falls back to the debug key.
Such a build cannot update over a release-signed install, which is the correct
outcome rather than a limitation.

## Cutting a release

1. Bump `version:` in `pubspec.yaml`. The part before the `+` is what the
   updater compares, so `1.1.0+2` is offered to a phone running `1.0.0`.

2. Build the per-ABI packages:

```bash
flutter build apk --release --split-per-abi
```

   Three APKs land in `build/app/outputs/flutter-apk/`: arm64-v8a (~21 MB),
   armeabi-v7a (~18 MB) and x86_64 (~22 MB). A universal APK is 58 MB, and every
   phone would download two architectures it cannot run. The app asks Android
   which ABIs it supports and picks the matching asset.

   Note that all three carry the same `versionCode`. That is fine here and would
   not be on Google Play: a phone only ever sees one of them.

3. Tag and publish, attaching all three:

```bash
./tool/release.sh 1.1.0
```

   The tag must parse as `major.minor.patch`, with an optional `v` prefix.
   A tag the app cannot parse — `nightly`, `1.2.3rc` — is ignored by the
   updater rather than misread, so such a release simply never reaches anyone.

## While the repository is private

GitHub will not serve a private repository's release to an anonymous request,
and returns 404 rather than 403 so that the repo's existence stays hidden. The
app detects that case and asks for a token instead of reporting a confusing
"not found".

The token is typed into the app, on the phone, and stored in preferences. It is
**not** compiled into the APK, and that is deliberate: a token inside a package
is a token handed to everyone who receives the package.

Make one at github.com/settings/tokens with as little reach as possible:

- Fine-grained token, this repository only
- Repository permissions: **Contents: Read-only**
- Nothing else

Making the repository public removes the need for any of this — the code holds
no secrets, and release downloads then work with no token at all.

## What the app does on the network

One host: `api.github.com`. It asks for the latest release, and fetches an APK
when told to. Nothing about the pack, the rides, or the location leaves the
phone — there is no server, no account and no telemetry, and the `INTERNET`
permission exists solely for this.

Checks are manual. Nothing polls, nothing downloads over mobile data on its own,
and the system's install prompt appears every time.
