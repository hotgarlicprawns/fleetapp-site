#!/bin/sh
# Installs Fleet to /Applications. Read it first: it downloads one zip from the project's
# GitHub release, checks its SHA-256 against the value in version.json, and copies the app.
# It needs no sudo, changes no system setting, and sends nothing about you.
set -eu

SITE="https://fleetapp.in"

case "$(uname -s)-$(uname -m)" in
  Darwin-arm64) ;;
  *) echo "Fleet needs a Mac with Apple Silicon. This machine is $(uname -s) $(uname -m)."; exit 1 ;;
esac

TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT

echo "Checking the latest version..."
curl -fsSL "$SITE/version.json" -o "$TMP/version.json"
field() { /usr/bin/plutil -extract "$1" raw -o - "$TMP/version.json"; }
VERSION=$(field version)
ZIP_URL=$(field zip)
SHA=$(field sha256)

case "$ZIP_URL" in
  https://github.com/hotgarlicprawns/*) ;;
  *) echo "Unexpected download address: $ZIP_URL"; exit 1 ;;
esac

echo "Downloading Fleet $VERSION..."
curl -fL --progress-bar "$ZIP_URL" -o "$TMP/Fleet.zip"

GOT=$(/usr/bin/shasum -a 256 "$TMP/Fleet.zip" | cut -d' ' -f1)
if [ "$GOT" != "$SHA" ]; then
  echo "The download does not match its checksum. Nothing was installed."
  exit 1
fi

/usr/bin/ditto -x -k "$TMP/Fleet.zip" "$TMP/out"
[ -d "$TMP/out/Fleet.app" ] || { echo "The download has no Fleet.app. Nothing was installed."; exit 1; }

if pgrep -xq Fleet; then
  echo "Fleet is running. It keeps running on the old version until you quit it and open it again."
fi
if [ -e /Applications/Fleet.app ]; then
  /usr/bin/trash /Applications/Fleet.app 2>/dev/null || { mv /Applications/Fleet.app "$TMP/old-Fleet.app"; mv "$TMP/old-Fleet.app" "$HOME/.Trash/Fleet-$(date +%s).app"; }
fi
/usr/bin/ditto "$TMP/out/Fleet.app" /Applications/Fleet.app

echo "Installed Fleet $VERSION in /Applications."
echo "Open it from Applications or run: open -a /Applications/Fleet.app"
