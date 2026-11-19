# Shared home-manager bits.
#
# Wallpapers live in this repo (modules/home-manager/shared/wallpapers) and are
# linked to ~/.config/wallpapers, where noctalia looks for them. Nothing is
# downloaded at build time, so installs/rebuilds stay fast.
{ ... }:
{
  xdg.configFile."wallpapers".source = ./wallpapers;
}
