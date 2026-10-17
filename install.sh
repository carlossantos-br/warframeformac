#!/bin/bash
# Warframe for Mac — installer.
# Builds a Wine wrapper (Sikarugir + D3DMetal), installs the official Warframe
# launcher into it and adds "Warframe for Mac" to ~/Applications.
# Running it again repairs the install and keeps the downloaded game files.
set -euo pipefail

TEMPLATE_VERSION="1.0.11"
TEMPLATE_URL="https://github.com/Sikarugir-App/Wrapper/releases/download/v1.0/Template-${TEMPLATE_VERSION}.tar.xz"
TEMPLATE_SHA256="9fa15479e7ff6abd99c1d07be285fb95f41fc6991586502427152b1f7d6ccb8a"
ENGINE="WS12WineSikarugir10.0_6"
ENGINE_URL="https://github.com/Sikarugir-App/Engines/releases/download/v1.0/${ENGINE}.tar.xz"
ENGINE_SHA256="9da7ee0cbf386522f3a9906943726d9c3c125dbbd9ab120e3cde80e88d6091b2"
MSI_URL="https://content.warframe.com/dl/Warframe.msi"
CONTROLLER_REPO="https://github.com/carlossantos-br/xboxoneformac"

SUPPORT="$HOME/Library/Application Support/WarframeForMac"
WRAPPER="$SUPPORT/Warframe.app"
GAME="$SUPPORT/Game"
CACHE="$HOME/Library/Caches/WarframeForMac"
APP="$HOME/Applications/Warframe for Mac.app"
HERE="$(cd "$(dirname "$0")" && pwd)"
NEEDED_GB=60
LAUNCHER_PATH='/users/Sikarugir/AppData/Local/Warframe/Downloaded/Public/Tools/Launcher.exe'
# The launcher (CEF) draws a black window under Wine without these flags.
LAUNCHER_FLAGS='--in-process-gpu --disable-gpu-compositing --disable-gpu-sandbox'

OPEN_WHEN_DONE=1
for arg in "$@"; do
  case "$arg" in
    --no-open) OPEN_WHEN_DONE=0 ;;
    -h|--help) echo "Usage: ./install.sh [--no-open]"; exit 0 ;;
    *) echo "Unknown option: $arg" >&2; exit 2 ;;
  esac
done

say()  { printf '\n\033[1m==> %s\033[0m\n' "$*"; }
info() { printf '    %s\n' "$*"; }
die()  { printf '\n\033[31mError:\033[0m %s\n' "$*" >&2; exit 1; }

game_running() { /usr/bin/pgrep -f 'Warframe\.x64\.exe|Tools[/\\]Launcher\.exe' >/dev/null 2>&1; }

stop_wine() {
  [ -x "$WRAPPER/Contents/MacOS/Sikarugir" ] && "$WRAPPER/Contents/MacOS/Sikarugir" WSS-wineserverkill >/dev/null 2>&1 || true
  /usr/bin/pkill -9 -f "$WRAPPER/Contents/SharedSupport/wine" >/dev/null 2>&1 || true
}

winpath() { local p="$1"; printf 'Z:%s' "${p//\//\\}"; }

# Runs a Windows program inside the wrapper, then stops everything it left
# running (the Warframe installer opens the launcher by itself when done).
wine_do() {
  local w="$1"; shift
  local env=(WINEPREFIX="$w/Contents/SharedSupport/prefix" WINEDEBUG=-all USER=Sikarugir
             DYLD_FALLBACK_LIBRARY_PATH="$w/Contents/Frameworks:/usr/lib")
  env "${env[@]}" "$w/Contents/SharedSupport/wine/bin/wine" "$@" >/dev/null 2>&1 || true
  sleep 3
  env "${env[@]}" "$w/Contents/SharedSupport/wine/bin/wineserver" -k >/dev/null 2>&1 || true
  env "${env[@]}" "$w/Contents/SharedSupport/wine/bin/wineserver" -w >/dev/null 2>&1 || true
}

fetch() { # url sha256 dest
  if [ -f "$3" ] && [ -n "$2" ] && [ "$(shasum -a 256 "$3" | cut -d' ' -f1)" = "$2" ]; then
    info "already downloaded: $(basename "$3")"; return
  fi
  info "downloading $(basename "$3")"
  curl -fL --retry 3 --progress-bar -o "$3.part" "$1"
  if [ -n "$2" ] && [ "$(shasum -a 256 "$3.part" | cut -d' ' -f1)" != "$2" ]; then
    rm -f "$3.part"; die "checksum mismatch for $(basename "$3") — download again later."
  fi
  mv "$3.part" "$3"
}

# ---------------------------------------------------------------- checks
say "Checking this Mac"
[ -f "$HERE/launcher/WarframeForMac" ] && [ -f "$HERE/assets/WarframeForMac.icns" ] \
  || die "Run install.sh from inside the warframeformac folder (git clone or the full ZIP)."
[ "$(sysctl -n hw.optional.arm64 2>/dev/null || echo 0)" = "1" ] || die "Apple Silicon (M1 or newer) is required."
MACOS_MAJOR="$(sw_vers -productVersion | cut -d. -f1)"
[ "$MACOS_MAJOR" -ge 14 ] || die "macOS 14 Sonoma or newer is required (this Mac has $(sw_vers -productVersion))."
info "Apple Silicon, macOS $(sw_vers -productVersion)"

if ! /usr/bin/arch -x86_64 /usr/bin/true 2>/dev/null; then
  info "Rosetta 2 is missing — installing it (macOS may ask for your password)."
  sudo /usr/sbin/softwareupdate --install-rosetta --agree-to-license
fi
info "Rosetta 2 ready"

game_running && die "Warframe is open. Close it and run the installer again."

REPAIR=0; [ -d "$WRAPPER" ] && REPAIR=1
if [ ! -d "$GAME/Downloaded" ]; then
  FREE_GB=$(( $(df -k "$HOME" | awk 'NR==2 {print $4}') / 1048576 ))
  [ "$FREE_GB" -ge "$NEEDED_GB" ] || die "Warframe needs about ${NEEDED_GB} GB free; this Mac has ${FREE_GB} GB. Free some space and try again."
  info "${FREE_GB} GB free"
fi

# ---------------------------------------------------------------- downloads
say "Downloading Wine (Sikarugir) and the official Warframe installer"
mkdir -p "$CACHE" "$GAME"
fetch "$TEMPLATE_URL" "$TEMPLATE_SHA256" "$CACHE/Template-$TEMPLATE_VERSION.tar.xz"
fetch "$ENGINE_URL" "$ENGINE_SHA256" "$CACHE/$ENGINE.tar.xz"
rm -f "$CACHE/Warframe.msi"
fetch "$MSI_URL" "" "$CACHE/Warframe.msi"
[ "$(od -An -tx1 -N4 "$CACHE/Warframe.msi" | tr -d ' \n')" = "d0cf11e0" ] || die "The Warframe installer download is not valid. Try again later."

# ---------------------------------------------------------------- wrapper
say "Building the Wine wrapper"
STAGE="$SUPPORT/.build"
rm -rf "$STAGE"; mkdir -p "$STAGE"
tar -xJf "$CACHE/Template-$TEMPLATE_VERSION.tar.xz" -C "$STAGE"
NEW="$STAGE/Warframe.app"
mv "$STAGE/Template-$TEMPLATE_VERSION.app" "$NEW"
tar -xJf "$CACHE/$ENGINE.tar.xz" -C "$NEW/Contents/SharedSupport"
mv "$NEW/Contents/SharedSupport/wswine.bundle" "$NEW/Contents/SharedSupport/wine"
xattr -cr "$NEW" 2>/dev/null || true

PL="$NEW/Contents/Info.plist"
plutil -replace CFBundleName -string "Warframe for Mac (Wine)" "$PL"
plutil -replace CFBundleIdentifier -string "org.warframeformac.wine" "$PL"
plutil -replace D3DMETAL -integer 1 "$PL"
plutil -replace WINEDEBUG -string "-all" "$PL"
plutil -replace "Program Name and Path" -string "$LAUNCHER_PATH" "$PL"
plutil -replace "Program Flags" -string "$LAUNCHER_FLAGS" "$PL"

info "creating the Windows environment (takes a minute)"
"$NEW/Contents/MacOS/Sikarugir" WSS-wineprefixcreate >/dev/null 2>&1 || true
[ -f "$NEW/Contents/SharedSupport/prefix/system.reg" ] || die "Wine could not create its environment."

# Game files live outside the wrapper, so a repair never re-downloads ~50 GB.
ln -s "$GAME" "$NEW/Contents/SharedSupport/prefix/drive_c/Warframe"

REGFILE="$NEW/Contents/SharedSupport/prefix/drive_c/warframeformac.reg"
cat > "$REGFILE" <<'REG'
REGEDIT4

[HKEY_CURRENT_USER\Software\Digital Extremes\Warframe\Launcher]
"DownloadDir"="C:\\Warframe\\Downloaded"
"WindowMode"=dword:00000002

[HKEY_CURRENT_USER\Software\Wine\Mac Driver]
"CaptureDisplaysForFullscreen"="N"
"WindowsFloatWhenInactive"="none"
REG
wine_do "$NEW" regedit /S 'C:\warframeformac.reg'
grep -q '"WindowMode"=dword:00000002' "$NEW/Contents/SharedSupport/prefix/user.reg" || die "Could not save the display settings."
rm -f "$REGFILE"

say "Installing the official Warframe launcher"
wine_do "$NEW" msiexec /i "$(winpath "$CACHE/Warframe.msi")" /qn
[ -f "$NEW/Contents/SharedSupport/prefix/drive_c$LAUNCHER_PATH" ] || die "The Warframe installer did not finish. Run ./install.sh again."

# Keep the player's game settings (*.cfg) on a repair.
OLD_LOCAL="$WRAPPER/Contents/SharedSupport/prefix/drive_c/users/Sikarugir/AppData/Local/Warframe"
if [ "$REPAIR" = 1 ] && [ -d "$OLD_LOCAL" ]; then
  find "$OLD_LOCAL" -maxdepth 1 -name '*.cfg' -type f -exec cp -p {} "$NEW/Contents/SharedSupport/prefix/drive_c/users/Sikarugir/AppData/Local/Warframe/" \;
fi

# Re-apply the Xbox One controller bridge if xboxoneformac is installed.
BRIDGE_SDL="/Library/Application Support/XboxOneForMac/wine/libSDL2-2.0.0.dylib"
if [ -f "$BRIDGE_SDL" ]; then
  cp -p "$NEW/Contents/Frameworks/libSDL2-2.0.0.dylib" "$NEW/Contents/Frameworks/libSDL2-2.0.0.dylib.orig"
  cp "$BRIDGE_SDL" "$NEW/Contents/Frameworks/libSDL2-2.0.0.dylib"
  info "Xbox One controller support re-applied (xboxoneformac)"
fi

stop_wine
rm -rf "$WRAPPER.old"
[ -d "$WRAPPER" ] && mv "$WRAPPER" "$WRAPPER.old"
mv "$NEW" "$WRAPPER"
rm -rf "$WRAPPER.old"

# ---------------------------------------------------------------- app
say "Adding \"Warframe for Mac\" to your Applications"
NEWAPP="$STAGE/Warframe for Mac.app"
mkdir -p "$NEWAPP/Contents/MacOS" "$NEWAPP/Contents/Resources"
cp "$HERE/launcher/WarframeForMac" "$NEWAPP/Contents/MacOS/WarframeForMac"
chmod 755 "$NEWAPP/Contents/MacOS/WarframeForMac"
cp "$HERE/assets/WarframeForMac.icns" "$NEWAPP/Contents/Resources/WarframeForMac.icns"
cat > "$NEWAPP/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>CFBundleDisplayName</key><string>Warframe for Mac</string>
	<key>CFBundleExecutable</key><string>WarframeForMac</string>
	<key>CFBundleIconFile</key><string>WarframeForMac</string>
	<key>CFBundleIdentifier</key><string>org.warframeformac.launcher</string>
	<key>CFBundleName</key><string>Warframe for Mac</string>
	<key>CFBundlePackageType</key><string>APPL</string>
	<key>CFBundleShortVersionString</key><string>1.0</string>
	<key>CFBundleVersion</key><string>1</string>
	<key>LSApplicationCategoryType</key><string>public.app-category.games</string>
	<key>LSMinimumSystemVersion</key><string>14.0</string>
	<key>LSUIElement</key><true/>
</dict>
</plist>
PLIST
xattr -cr "$NEWAPP" 2>/dev/null || true
codesign --force --sign - "$NEWAPP" >/dev/null 2>&1 || true
mkdir -p "$HOME/Applications"
rm -rf "$APP"
mv "$NEWAPP" "$APP"
rm -rf "$STAGE"
/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister -f "$APP" >/dev/null 2>&1 || true

say "Done!"
info "Open \"Warframe for Mac\" from Launchpad, Spotlight or ~/Applications."
if [ ! -d "$GAME/Downloaded/Public" ]; then
  info "The first start downloads the game (~50 GB) — keep the launcher open until it finishes."
fi
info "Playing with a wired Xbox One controller? See $CONTROLLER_REPO"
[ "$OPEN_WHEN_DONE" = 1 ] && open "$APP"
exit 0
