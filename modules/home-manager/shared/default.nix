# Shared home-manager bits.
#
# Wallpapers live in this repo (./wallpapers) and are linked to
# ~/.config/wallpapers, where noctalia looks for them.
#
# Extra wallpapers without touching git: drop files into ./wallpapers-local
# (gitignored). They are picked up on the next rebuild and appear in the
# noctalia wallpaper picker together with the tracked ones.
{ lib, pkgs, ... }:
let
  mergedWallpapers = pkgs.symlinkJoin {
    name = "wallpapers";
    paths = [ ./wallpapers ] ++ lib.optional (builtins.pathExists ./wallpapers-local) ./wallpapers-local;
  };
in
{
  xdg.configFile."wallpapers".source = mergedWallpapers;
}
