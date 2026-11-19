#!/usr/bin/env bash
# Print the Nix binary caches that answer right now (space separated).
#
# Nix already falls back to the next substituter when one is down, but a dead
# first mirror can stall downloads for a long time. Used by the installers and
# by cached-build.sh; safe to run anywhere with curl.
#
#   ./scripts/nix-caches.sh          # reachable caches only
#   ./scripts/nix-caches.sh --all    # the full list, in priority order
set -u

CACHES=(
  "https://mirror.yandex.ru/nixos"
  "https://cache.nixos.org"
  "https://niri.cachix.org"
  "https://noctalia.cachix.org"
  "https://mirror.sjtu.edu.cn/nix-channels/store"
)

if [ "${1:-}" = "--all" ]; then
  printf '%s\n' "${CACHES[*]}"
  exit 0
fi

reachable=()
for url in "${CACHES[@]}"; do
  if curl -fsS --connect-timeout 4 --max-time 8 "$url/nix-cache-info" -o /dev/null 2>/dev/null; then
    reachable+=("$url")
  fi
done

if [ "${#reachable[@]}" -eq 0 ]; then
  # Nothing answered: let Nix try everything and report a normal error.
  printf '%s\n' "${CACHES[*]}"
else
  printf '%s\n' "${reachable[*]}"
fi
