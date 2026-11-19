#!/usr/bin/env bash
# Switch the colour theme and rebuild.
#
#   sudo /etc/nixos/scripts/theme.sh            # show current + available
#   sudo /etc/nixos/scripts/theme.sh everforest # select and rebuild
#
# The choice is stored in /etc/nixos/theme-local.nix (gitignored), so
# `git pull` never conflicts with it.
set -euo pipefail

DEST=${DEST:-/etc/nixos}
THEMES="$DEST/themes.nix"

if [ "$(id -u)" -ne 0 ]; then
  echo "Run with sudo: sudo $0 [name]" >&2
  exit 1
fi

if [ ! -f "$THEMES" ]; then
  echo "$THEMES not found" >&2
  exit 1
fi

available() {
  sed -n 's/^  \([a-z0-9-]*\) = {$/\1/p' "$THEMES"
}

current() {
  if [ -f "$DEST/theme-local.nix" ]; then
    sed -n 's/.*name *= *"\([^"]*\)".*/\1/p' "$DEST/theme-local.nix" | head -n 1
  else
    echo "catppuccin-mocha (default)"
  fi
}

case "${1:-}" in
  "" | --list | -l)
    echo "current: $(current)"
    echo "available:"
    available | sed 's/^/  /'
    exit 0
    ;;
esac

name="$1"
if ! available | grep -qx "$name"; then
  echo "Unknown theme: $name" >&2
  echo "Available: $(available | tr '\n' ' ')" >&2
  exit 1
fi

printf '{ name = "%s"; }\n' "$name" > "$DEST/theme-local.nix"
if [ -n "${SUDO_USER:-}" ]; then
  chown "$SUDO_USER":users "$DEST/theme-local.nix" || true
fi

echo "theme -> $name"
exec "$DEST/scripts/rebuild.sh"
