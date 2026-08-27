#!/usr/bin/env bash
# Builds the per-ABI packages and publishes them as a GitHub release.
#
# Usage: ./tool/release.sh 1.1.0 ["release notes"]
#
# The version must match pubspec.yaml, because the app compares the release tag
# against the version Android reports for the installed package. A tag ahead of
# the built APK would offer an update that installs and still looks old.
set -euo pipefail

VERSION="${1:-}"
NOTES="${2:-}"

if [[ -z "$VERSION" ]]; then
  echo "usage: $0 <version> [notes]" >&2
  exit 1
fi

if ! [[ "$VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
  echo "error: version must be major.minor.patch, got '$VERSION'" >&2
  exit 1
fi

cd "$(dirname "$0")/.."

PUBSPEC_VERSION="$(grep -m1 '^version:' pubspec.yaml | sed 's/version:[[:space:]]*//' | cut -d+ -f1)"
if [[ "$PUBSPEC_VERSION" != "$VERSION" ]]; then
  echo "error: pubspec.yaml says $PUBSPEC_VERSION, you asked for $VERSION." >&2
  echo "       Bump pubspec first -- the app compares the tag against the" >&2
  echo "       version baked into the APK, and a mismatch offers an update" >&2
  echo "       that installs and still reports the old number." >&2
  exit 1
fi

if [[ -n "$(git status --porcelain)" ]]; then
  echo "error: working tree is dirty. Commit first, so the tag points at what" >&2
  echo "       was actually built." >&2
  exit 1
fi

if [[ ! -f android/key.properties ]]; then
  echo "error: android/key.properties is missing, so this would be signed with" >&2
  echo "       the debug key and could not install over an existing release." >&2
  echo "       See docs/RELEASING.md." >&2
  exit 1
fi

echo "==> Testing"
flutter test

echo "==> Building split APKs"
flutter build apk --release --split-per-abi

OUT="build/app/outputs/flutter-apk"
STAGE="$(mktemp -d)"
trap 'rm -rf "$STAGE"' EXIT

# Renamed on the way out: the ABI has to survive into the asset name, because
# that is how the app picks the right one for the phone asking.
for abi in arm64-v8a armeabi-v7a x86_64; do
  src="$OUT/app-$abi-release.apk"
  if [[ ! -f "$src" ]]; then
    echo "error: expected $src" >&2
    exit 1
  fi
  cp "$src" "$STAGE/jk-bms-plus-$VERSION-$abi.apk"
done

echo "==> Publishing v$VERSION"

# The branch goes up before the tag. Tagging and pushing only the tag leaves the
# commits reachable from the tag but absent from the branch on the remote, and
# the next merge rebases them into different hashes -- at which point the
# release tag names a commit that is on no branch. Happened once; hence this.
BRANCH="$(git rev-parse --abbrev-ref HEAD)"
echo "    pushing $BRANCH"
git push origin "$BRANCH"

git tag -a "v$VERSION" -m "v$VERSION"
git push origin "v$VERSION"

if [[ -n "$NOTES" ]]; then
  gh release create "v$VERSION" "$STAGE"/*.apk --title "v$VERSION" --notes "$NOTES"
else
  gh release create "v$VERSION" "$STAGE"/*.apk --title "v$VERSION" --generate-notes
fi

echo "==> Done. Assets:"
ls -lh "$STAGE"
