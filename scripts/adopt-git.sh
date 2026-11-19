#!/usr/bin/env bash
# Turn an already installed /etc/nixos (plain copy of the repo) into a git
# checkout, so the system can be updated with `git pull`.
#
# Keeps hardware-configuration.nix and the username from user-local.nix /
# user.nix. The old /etc/nixos is backed up first.
#
#   sudo bash /etc/nixos/scripts/adopt-git.sh
set -euo pipefail

REPO="https://github.com/SPdrErgo/nixos-config"
DEST=/etc/nixos
STAMP=$(date +%Y%m%d-%H%M%S)

if [ "$(id -u)" -ne 0 ]; then
  echo "Run as root: sudo bash $0" >&2
  exit 1
fi

if [ ! -f "$DEST/hardware-configuration.nix" ]; then
  echo "$DEST/hardware-configuration.nix not found; refusing to touch $DEST." >&2
  exit 1
fi

WORK=$(mktemp -d)
trap 'rm -rf "$WORK"' EXIT
cp "$DEST/hardware-configuration.nix" "$WORK/hardware-configuration.nix"

USER_NAME="nixos"
for f in "$DEST/user-local.nix" "$DEST/user.nix"; do
  if [ -f "$f" ]; then
    found=$(sed -n 's/.*username *= *"\([^"]*\)".*/\1/p' "$f" | head -n 1)
    if [ -n "$found" ]; then
      USER_NAME="$found"
      break
    fi
  fi
done

cp -a "$DEST" "/etc/nixos.bak-$STAMP"
echo "backup: /etc/nixos.bak-$STAMP"

if [ ! -d "$DEST/.git" ]; then
  git -C "$DEST" init -q -b main
fi
git -C "$DEST" remote remove origin 2>/dev/null || true
git -C "$DEST" remote add origin "$REPO"
git -C "$DEST" config pull.rebase true

GIT_TERMINAL_PROMPT=0 git -C "$DEST" fetch origin main
git -C "$DEST" reset --hard -q FETCH_HEAD
git -C "$DEST" branch -q --set-upstream-to=origin/main main

cp "$WORK/hardware-configuration.nix" "$DEST/hardware-configuration.nix"
printf '{ username = "%s"; }\n' "$USER_NAME" > "$DEST/user-local.nix"
chown -R "$USER_NAME":users "$DEST"

echo
echo "Done. /etc/nixos is now a git checkout (username: $USER_NAME)."
echo "Apply the config with:"
echo "  sudo nixos-rebuild switch --flake 'path:/etc/nixos#nixos'"
