#!/usr/bin/env bash
# Build the system with binary caches enabled explicitly.
# Useful before the first `nixos-rebuild switch`, when /etc/nix/nix.conf
# doesn't yet contain the substituters from configuration.nix.
set -euo pipefail
cd "$(dirname "$0")/.."

exec nix build --no-link --print-out-paths \
  --option substituters "https://cache.nixos.org https://mirror.yandex.ru/nixos https://niri.cachix.org https://noctalia.cachix.org" \
  --option trusted-public-keys "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY= niri.cachix.org-1:Wv0OmO7PsuocRKzfDoJ3mulSl7Z6oezYhGhR+3W2964= noctalia.cachix.org-1:pCOR47nnMEo5thcxNDtzWpOxNFQsBRglJzxWPp3dkU4=" \
  ".#nixosConfigurations.nixos.config.system.build.toplevel"
