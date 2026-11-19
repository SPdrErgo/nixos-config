#!/usr/bin/env bash
# Rebuild this machine from /etc/nixos.
#
# `path:` is required: /etc/nixos is a git checkout, but
# hardware-configuration.nix and user-local.nix are gitignored, and a plain
# git flake reference would leave them out of the build.
#
#   sudo /etc/nixos/scripts/rebuild.sh
set -euo pipefail

exec nixos-rebuild switch --flake "path:/etc/nixos#nixos" "$@"
