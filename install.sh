#!/usr/bin/env bash
# Midnight Riders Dragons installer for WoW: Forever (Mac and Linux).
#   curl -fsSL https://raw.githubusercontent.com/realworldbuilder/midnight-riders-dragons/main/install.sh | bash
# Finds your Forever folder, downloads the latest release and puts it in Interface/AddOns.
# Set WOW_DIR to your "World of Warcraft" folder if it lives somewhere unusual.
set -euo pipefail

ADDON="MidnightRiders_Dragons"
ZIP_URL="https://github.com/realworldbuilder/midnight-riders-dragons/releases/latest/download/${ADDON}.zip"

say()  { printf '\033[1;35m»\033[0m %s\n' "$*"; }
fail() { printf '\033[1;31m✗\033[0m %s\n' "$*" >&2; exit 1; }

command -v curl  >/dev/null || fail "curl is needed but isn't installed."
command -v unzip >/dev/null || fail "unzip is needed but isn't installed."

# 1. Find the Forever folder.
candidates=()
[ -n "${WOW_DIR:-}" ] && candidates+=("${WOW_DIR%/}")
candidates+=(
  "/Applications/World of Warcraft"
  "$HOME/Applications/World of Warcraft"
  "$HOME/Games/World of Warcraft"
  "$HOME/.wine/drive_c/Program Files (x86)/World of Warcraft"
)
forever=""
for wow in "${candidates[@]}"; do
  if [ -d "$wow/_forever_" ]; then forever="$wow/_forever_"; break; fi
done
[ -n "$forever" ] || fail "Couldn't find World of Warcraft: Forever (a _forever_ folder). If it's somewhere else, run:
  curl -fsSL https://raw.githubusercontent.com/realworldbuilder/midnight-riders-dragons/main/install.sh | WOW_DIR=\"/path/to/World of Warcraft\" bash"
say "Found Forever: $forever"

addons="$forever/Interface/AddOns"
mkdir -p "$addons"
target="$addons/$ADDON"

# A link here means someone is developing the addon from their own folder; leave it alone.
if [ -L "$target" ]; then
  fail "$target is a link to $(readlink "$target"). Not replacing a development copy."
fi

# 2. Download and unpack into a temporary folder.
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
say "Downloading the latest Midnight Riders Dragons…"
curl -fsSL "$ZIP_URL" -o "$tmp/$ADDON.zip" || fail "Download failed. Check your internet connection and try again."
unzip -q "$tmp/$ADDON.zip" -d "$tmp/unpacked" || fail "The download wasn't a valid zip. Try again in a minute."
[ -f "$tmp/unpacked/$ADDON/$ADDON.toc" ] || fail "The download didn't contain the addon. Try again in a minute."

# 3. Swap it in.
updating=false
if [ -e "$target" ]; then updating=true; rm -rf "$target"; fi
mv "$tmp/unpacked/$ADDON" "$target"

version="$(sed -n 's/^## Version: *//p' "$target/$ADDON.toc" | tr -d '\r')"
if $updating; then
  say "Updated Midnight Riders Dragons to v$version."
else
  say "Installed Midnight Riders Dragons v$version."
fi
echo
echo "  Restart World of Warcraft: Forever (or type /reload if you were updating)."
echo "  On the character screen, make sure it's ticked under AddOns. Then type /mrdragon in game."
