#!/bin/bash
# Warframe for Mac — removes the app, Wine and (unless --keep-game) the game files.
set -euo pipefail

SUPPORT="$HOME/Library/Application Support/WarframeForMac"
WRAPPER="$SUPPORT/Warframe.app"
APP="$HOME/Applications/Warframe for Mac.app"
CACHE="$HOME/Library/Caches/WarframeForMac"

KEEP_GAME=0; ASSUME_YES=0
for arg in "$@"; do
  case "$arg" in
    --keep-game) KEEP_GAME=1 ;;
    -y|--yes) ASSUME_YES=1 ;;
    -h|--help) echo "Usage: ./uninstall.sh [--keep-game] [--yes]"; exit 0 ;;
    *) echo "Unknown option: $arg" >&2; exit 2 ;;
  esac
done

if [ "$ASSUME_YES" = 0 ]; then
  if [ "$KEEP_GAME" = 1 ]; then what="the app and Wine (game files are kept)"; else what="the app, Wine and the downloaded game (~50 GB)"; fi
  read -r -p "Remove $what? [y/N] " answer
  [[ "$answer" =~ ^[Yy]$ ]] || { echo "Nothing removed."; exit 0; }
fi

# Stop anything still running from this install.
[ -x "$WRAPPER/Contents/MacOS/Sikarugir" ] && "$WRAPPER/Contents/MacOS/Sikarugir" WSS-wineserverkill >/dev/null 2>&1 || true
/usr/bin/pkill -9 -f "$WRAPPER/Contents/SharedSupport/wine" >/dev/null 2>&1 || true
sleep 1

rm -rf "$APP" "$WRAPPER" "$SUPPORT/.build" "$CACHE"
if [ "$KEEP_GAME" = 1 ]; then
  echo "Game files kept in: $SUPPORT/Game"
else
  rm -rf "$SUPPORT"
fi
/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister -u "$APP" >/dev/null 2>&1 || true

echo "Warframe for Mac was removed."
if [ -e /Library/LaunchDaemons/org.xboxoneformac.bridge.plist ]; then
  echo "The Xbox One controller service is still installed — run uninstall.sh from xboxoneformac to remove it too."
fi
