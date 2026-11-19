# Noctalia: bar, panels, launcher, wallpaper and shell theme.
#
# Wallpapers come from ~/.config/wallpapers (see ../shared/default.nix) and the
# shell palette is generated from the current wallpaper, so changing the
# wallpaper also recolours noctalia.
{ config, ... }:
{
  programs.noctalia = {
    enable = true;

    settings = {
      accessibility.ui_scale = 1.0;

      shell = {
        font_family = "JetBrainsMono Nerd Font Mono";
        time_format = "{:%H:%M}";
        date_format = "%a, %b %d";
        telemetry_enabled = false;
        clipboard_enabled = true;
        animation.enabled = true;
      };

      wallpaper = {
        enabled = true;
        directory = "${config.xdg.configHome}/wallpapers";
        fill_mode = "crop";
        fill_color = "#000000";
        transition = [
          "fade"
          "disc"
          "stripes"
          "wipe"
          "honeycomb"
        ];
        transition_duration = 1500;
        edge_smoothness = 0.05;
        transition_on_startup = true;
        default.path = "${config.xdg.configHome}/wallpapers/everforest_robin.png";
        automation = {
          enabled = true;
          interval_seconds = 120;
          order = "random";
          recursive = true;
        };
      };

      # Shell colours follow the wallpaper (dark mode).
      theme = {
        mode = "dark";
        source = "wallpaper";
        builtin = "Noctalia";
        wallpaper_scheme = "m3-tonal-spot";
      };

      lockscreen.enabled = true;
    };
  };
}
