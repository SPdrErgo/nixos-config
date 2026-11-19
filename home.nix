# User-level configuration managed by home-manager.
{
  config,
  lib,
  pkgs,
  username,
  theme,
  ...
}:

let
  # Helpers for niri binds (from AndrianoTurner/nixdotfiles).
  bindWith = key: options: actionName: actionArgs: {
    ${key} = options // {
      action.${actionName} = actionArgs;
    };
  };

  bind =
    key: actionName: actionArgs:
    bindWith key { } actionName actionArgs;
  spawn = key: command: bind key "spawn" command;
  spawnWith =
    key: options: command:
    bindWith key options "spawn" command;
  spawnShellWith =
    key: options: command:
    bindWith key options "spawn-sh" command;

  # Wallpapers are fetched from GitHub at build time and installed into
  # ~/.local/share/wallpapers (pinned by hash, so builds are reproducible).
  # Source: https://github.com/D3Ext/aesthetic-wallpapers
  wallpaperBase = "https://raw.githubusercontent.com/D3Ext/aesthetic-wallpapers/main/images";
  fetchWallpaper = file: hash: pkgs.fetchurl {
    url = "${wallpaperBase}/${file}";
    inherit hash;
  };
  wallpapers = {
    "everforest-robin.png" = fetchWallpaper "everforest_robin.png" "sha256-cMjUEMDpGuwlAftlPWM75qcM9DuVsxdSbH7PC5enXDw=";
    "everforest-one-piece.png" = fetchWallpaper "everforest_one_piece.png" "sha256-xhUFWVWUBIj4LElsI8e35u8kPrFSW+LkQB0Ib08aEXc=";
    "plant.png" = fetchWallpaper "plant.png" "sha256-CCuJTnX+jbN4KpzQ9z+jRv5sFRKpV+0XD2Pmgnp7fk4=";
    "forest-bridge.jpg" = fetchWallpaper "forest-bridge.jpg" "sha256-JfM9ZbT5SSO6NgIA5crhYpv8MFcK17RjCI9brbm7Hzo=";
  };
  defaultWallpaper = wallpapers."everforest-robin.png";
in

{
  home.username = username;
  home.homeDirectory = "/home/${username}";
  home.stateVersion = "26.05";

  programs.home-manager.enable = true;

  # Wallpapers, fetched from GitHub at build time (see the `wallpapers` binding).
  # Mod+Shift+W runs the random switcher from ~/.local/bin.
  home.file =
    (lib.mapAttrs' (
      name: src: lib.nameValuePair ".local/share/wallpapers/${name}" { source = src; }
    ) wallpapers)
    // {
      ".local/bin/wallpaper-random" = {
        executable = true;
        text = ''
          #!/usr/bin/env bash
          set -euo pipefail
          dir="$HOME/.local/share/wallpapers"
          [ -d "$dir" ] || exit 1
          file=$(find -L "$dir" -type f | shuf -n 1)
          pkill -x swaybg 2>/dev/null || true
          sleep 0.2
          exec swaybg -m fill -i "$file"
        '';
      };
    };

  # --- Git ----------------------------------------------------------------
  programs.git = {
    enable = true;
    settings = {
      # TODO: set your real name/email
      user.name = username;
      user.email = "${username}@localhost";
      init.defaultBranch = "main";
      pull.rebase = true;
    };
  };
  # --- Terminals ----------------------------------------------------------
  # JetBrainsMono Nerd Font Mono: monospace-safe glyphs for the powerline prompt.
  programs.alacritty = {
    enable = true;
    settings = {
      colors = {
        primary = {
          background = "#${theme.bg}";
          foreground = "#${theme.fg}";
        };
        cursor = {
          text = "#${theme.bg}";
          cursor = "#${theme.accent}";
        };
        normal = {
          black = "#${theme.black}";
          red = "#${theme.red}";
          green = "#${theme.green}";
          yellow = "#${theme.yellow}";
          blue = "#${theme.blue}";
          magenta = "#${theme.magenta}";
          cyan = "#${theme.cyan}";
          white = "#${theme.white}";
        };
        bright = {
          black = "#${theme.brightBlack}";
          red = "#${theme.brightRed}";
          green = "#${theme.brightGreen}";
          yellow = "#${theme.brightYellow}";
          blue = "#${theme.brightBlue}";
          magenta = "#${theme.brightMagenta}";
          cyan = "#${theme.brightCyan}";
          white = "#${theme.brightWhite}";
        };
        selection = {
          background = "#${theme.selection}";
          text = "#${theme.fg}";
        };
      };
      font = {
        normal = {
          family = "JetBrainsMono Nerd Font Mono";
          style = "Regular";
        };
        bold = {
          family = "JetBrainsMono Nerd Font Mono";
          style = "Bold";
        };
        italic = {
          family = "JetBrainsMono Nerd Font Mono";
          style = "Italic";
        };
        bold_italic = {
          family = "JetBrainsMono Nerd Font Mono";
          style = "Bold Italic";
        };
        size = 11;
      };
    };
  };

  # --- Browser ------------------------------------------------------------
  programs.zen-browser = {
    enable = true;
    setAsDefaultBrowser = true;

    extraPrefs = ''
      defaultPref("zen.workspaces.continue-where-left-off", true);
      defaultPref("zen.urlbar.behavior", "float");
      defaultPref("browser.startup.homepage", "about:blank");
      defaultPref("browser.newtabpage.enabled", false);
      defaultPref("media.ffmpeg.vaapi.enabled", true);
      defaultPref("gfx.webrender.all", true);
      defaultPref("widget.wayland.fractional-scale.enabled", true);
    '';

    policies = {
      DisableAppUpdate = true;
      DisableTelemetry = true;
      DisablePocket = true;
      ExtensionSettings = {
        "uBlock0@raymondhill.net" = {
          install_url = "https://addons.mozilla.org/firefox/downloads/latest/ublock-origin/latest.xpi";
          installation_mode = "normal_installed";
        };
        "addon@darkreader.org" = {
          install_url = "https://addons.mozilla.org/firefox/downloads/latest/darkreader/latest.xpi";
          installation_mode = "normal_installed";
        };
      };
    };

    profiles.${username} = {
      isDefault = true;
    };
  };

  # --- Editor -------------------------------------------------------------
  programs.zed-editor = {
    enable = true;

    extensions = [
      "nix"
      "toml"
      "dockerfile"
      "docker-compose"
      "html"
      "css"
      "javascript"
      "typescript"
      "python"
      "rust"
      "go"
      "yaml"
      "sql"
      "markdown"
      "git-firefly"
      "catppuccin"
    ];

    userSettings = {
      theme = "Catppuccin Mocha";
      ui_font_family = "JetBrainsMono Nerd Font Mono";
      buffer_font_family = "JetBrainsMono Nerd Font Mono";
      buffer_font_size = 13;
      telemetry = {
        metrics = false;
        diagnostics = false;
      };
      autosave.after_delay.milliseconds = 1000;
    };

    mutableUserSettings = false;
    mutableUserKeymaps = false;
    mutableUserTasks = false;
  };

  # --- Files --------------------------------------------------------------
  programs.yazi = {
    enable = true;
    enableZshIntegration = true;
    settings = {
      mgr = {
        show_hidden = true;
        show_symlink = true;
      };
      preview.wrap = "yes";
    };
  };

  # Application launcher (Mod+D).
  programs.fuzzel = {
    enable = true;
    settings = {
      main = {
        font = "JetBrainsMono Nerd Font Mono:size=11";
        terminal = "alacritty";
        layer = "overlay";
        width = 40;
        lines = 12;
        prompt = "❯ ";
        "icons-enabled" = "yes";
      };
      border = {
        width = 2;
        radius = 8;
      };
      colors = {
        background = "${theme.bg}ee";
        text = "${theme.fg}d9";
        prompt = "${theme.accent}ff";
        placeholder = "${theme.white}ff";
        input = "${theme.fg}ee";
        match = "${theme.accent}ff";
        selection = "${theme.selection}ff";
        "selection-text" = "${theme.fg}ff";
        "selection-match" = "${theme.accent}ff";
        counter = "${theme.white}ff";
        border = "${theme.accent}ff";
      };
    };
  };

  # Thunar as the default GUI file manager.
  xdg.mimeApps = {
    enable = true;
    defaultApplications."inode/directory" = "thunar.desktop";
  };

  # Automount is off on purpose: on login udiskie tries to mount every block
  # device (including internal NTFS/LUKS partitions), and udisks2 asks for a
  # password via polkit. Mount from the tray or with `udiskie-mount -a`.
  services.udiskie = {
    enable = true;
    automount = false;
    notify = true;
    tray = "auto";
  };

  # --- Noctalia (Wayland shell / bar) -------------------------------------
  programs.noctalia = {
    enable = true;
    settings = {
      accessibility.ui_scale = 1.0;
      shell = {
        font_family = "JetBrainsMono Nerd Font Mono";
        time_format = "{:%H:%M}";
        date_format = "%a, %b %d";
        telemetry_enabled = false;
        setup_wizard_enabled = false;
        clipboard_enabled = true;
        animation.enabled = true;
      };
    };
  };

  # --- Niri (Wayland compositor) ------------------------------------------
  programs.niri = {
    package = pkgs.niri;
    settings = {
      prefer-no-csd = true;
      hotkey-overlay.skip-at-startup = true;

      spawn-at-startup = [
        { argv = [ "noctalia" ]; }
        # Wallpaper (niri has no background of its own).
        # Mod+Shift+W switches to a random one from ~/.local/share/wallpapers.
        {
          argv = [
            "swaybg"
            "-m"
            "fill"
            "-i"
            "${defaultWallpaper}"
          ];
        }
      ];

      xwayland-satellite = {
        enable = true;
        path = lib.getExe pkgs.xwayland-satellite;
      };

      input = {
        keyboard = {
          xkb = {
            layout = "us,ru";
            options = "grp:alt_shift_toggle";
          };
          repeat-delay = 150;
          repeat-rate = 40;
          numlock = true;
        };

        touchpad.enable = true;
        warp-mouse-to-focus.enable = true;
        focus-follows-mouse = {
          enable = true;
          max-scroll-amount = "0%";
        };
      };

      gestures.hot-corners.enable = false;

      layout = {
        gaps = 8;
        center-focused-column = "never";
        preset-column-widths = [
          { proportion = 0.33333; }
          { proportion = 0.5; }
          { proportion = 0.66667; }
        ];
        default-column-width.proportion = 0.45;

        focus-ring = {
          enable = true;
          width = 4;
          active.color = "#${theme.accent}";
          inactive.color = "#${theme.selection}";
          urgent.color = "#${theme.red}";
        };

        border.enable = false;
      };

      cursor = {
        hide-when-typing = true;
        hide-after-inactive-ms = 1500;
      };

      animations = { };

      binds =
        # Apps
        (spawn "Mod+Return" [ "alacritty" ])
        // (spawn "Mod+D" [ "fuzzel" ])
        // (spawn "Mod+Shift+W" [ "/home/${username}/.local/bin/wallpaper-random" ])
        // (spawn "Mod+E" [
          "alacritty"
          "-e"
          "yazi"
        ])
        // (spawn "Mod+X" [
          "noctalia"
          "msg"
          "panel-toggle"
          "control-center"
          "notifications"
        ])
        // (bind "Ctrl+Alt+L" "spawn" [
          "swaylock"
          "-f"
        ])
        # Window management
        // (bind "Mod+Q" "close-window" [ ])
        // (bind "Mod+F" "maximize-column" [ ])
        // (bind "Mod+Shift+F" "fullscreen-window" [ ])
        // (bind "Mod+V" "toggle-window-floating" [ ])
        // (bind "Mod+M" "maximize-window-to-edges" [ ])
        // (bind "Mod+C" "center-column" [ ])
        // (bind "Mod+Minus" "set-column-width" "-10%")
        // (bind "Mod+Equal" "set-column-width" "+10%")
        // (bind "Mod+Shift+Minus" "set-window-height" "-10%")
        // (bind "Mod+Shift+Equal" "set-window-height" "+10%")
        # Focus
        // (bind "Mod+H" "focus-column-left" [ ])
        // (bind "Mod+L" "focus-column-right" [ ])
        // (bind "Mod+K" "focus-window-up" [ ])
        // (bind "Mod+J" "focus-window-down" [ ])
        // (bind "Mod+Left" "focus-column-left" [ ])
        // (bind "Mod+Right" "focus-column-right" [ ])
        // (bind "Mod+Up" "focus-window-up" [ ])
        // (bind "Mod+Down" "focus-window-down" [ ])
        # Move
        // (bind "Mod+Shift+H" "move-column-left" [ ])
        // (bind "Mod+Shift+L" "move-column-right" [ ])
        // (bind "Mod+Shift+K" "move-window-up" [ ])
        // (bind "Mod+Shift+J" "move-window-down" [ ])
        // (bind "Mod+Shift+Left" "move-column-left" [ ])
        // (bind "Mod+Shift+Right" "move-column-right" [ ])
        // (bind "Mod+Shift+Up" "move-window-up" [ ])
        // (bind "Mod+Shift+Down" "move-window-down" [ ])
        # Workspaces
        // (bind "Mod+1" "focus-workspace" 1)
        // (bind "Mod+2" "focus-workspace" 2)
        // (bind "Mod+3" "focus-workspace" 3)
        // (bind "Mod+4" "focus-workspace" 4)
        // (bind "Mod+5" "focus-workspace" 5)
        // (bind "Mod+6" "focus-workspace" 6)
        // (bind "Mod+Shift+1" "move-column-to-workspace" 1)
        // (bind "Mod+Shift+2" "move-column-to-workspace" 2)
        // (bind "Mod+Shift+3" "move-column-to-workspace" 3)
        // (bind "Mod+Shift+4" "move-column-to-workspace" 4)
        // (bind "Mod+Shift+5" "move-column-to-workspace" 5)
        // (bind "Mod+Shift+6" "move-column-to-workspace" 6)
        // (bindWith "Mod+WheelScrollDown" { cooldown-ms = 150; } "focus-workspace-down" [ ])
        // (bindWith "Mod+WheelScrollUp" { cooldown-ms = 150; } "focus-workspace-up" [ ])
        // (bind "Mod+Shift+WheelScrollDown" "focus-column-left" [ ])
        // (bind "Mod+Shift+WheelScrollUp" "focus-column-right" [ ])
        // (bind "Mod+Page_Down" "focus-workspace-down" [ ])
        // (bind "Mod+Page_Up" "focus-workspace-up" [ ])
        # Screenshots
        // (bind "Print" "screenshot" [ ])
        // (bind "Ctrl+Print" "screenshot-screen" [ ])
        // (bind "Alt+Print" "screenshot-window" [ ])
        // (bind "Mod+Shift+S" "screenshot" [ ])
        # Session
        // (bind "Mod+Shift+E" "quit" [ ])
        // (bind "Ctrl+Alt+Delete" "quit" [ ])
        // (bind "Mod+Shift+P" "power-off-monitors" [ ])
        // (bindWith "Mod+O" { repeat = false; } "toggle-overview" [ ])
        // (bindWith "Mod+Escape" { allow-inhibiting = false; } "toggle-keyboard-shortcuts-inhibit" [ ])
        // (bind "Mod+Shift+Slash" "show-hotkey-overlay" [ ])
        # Volume
        // (spawnShellWith "XF86AudioRaiseVolume" {
          allow-when-locked = true;
        } "wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%+ -l 1.0")
        // (spawnShellWith "XF86AudioLowerVolume" {
          allow-when-locked = true;
        } "wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-")
        // (spawnShellWith "XF86AudioMute" {
          allow-when-locked = true;
        } "wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle")
        // (spawnShellWith "XF86AudioMicMute" {
          allow-when-locked = true;
        } "wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle")
        # Media
        // (spawnShellWith "XF86AudioPlay" { allow-when-locked = true; } "playerctl play-pause")
        // (spawnShellWith "XF86AudioPause" { allow-when-locked = true; } "playerctl play-pause")
        // (spawnShellWith "XF86AudioStop" { allow-when-locked = true; } "playerctl stop")
        // (spawnShellWith "XF86AudioNext" { allow-when-locked = true; } "playerctl next")
        // (spawnShellWith "XF86AudioPrev" { allow-when-locked = true; } "playerctl previous")
        # Brightness
        // (spawnWith "XF86MonBrightnessUp" { allow-when-locked = true; } [
          "brightnessctl"
          "s"
          "10%+"
        ])
        // (spawnWith "XF86MonBrightnessDown" { allow-when-locked = true; } [
          "brightnessctl"
          "s"
          "10%-"
        ]);

      window-rules = [
        {
          matches = [ { title = "^Picture-in-Picture$"; } ];
          open-floating = true;
          default-column-width.fixed = 480;
          default-window-height.fixed = 270;
        }
        {
          # Noctalia settings UI opens as a regular window.
          matches = [ { app-id = "dev.noctalia.Noctalia"; } ];
          open-floating = true;
          default-column-width.fixed = 1080;
          default-window-height.fixed = 920;
        }
        {
          geometry-corner-radius = {
            top-left = 20.0;
            top-right = 20.0;
            bottom-right = 20.0;
            bottom-left = 20.0;
          };
          clip-to-geometry = true;
        }
      ];
    };
  };

  # --- Shell --------------------------------------------------------------
  programs.zsh = {
    enable = true;
    enableCompletion = true;
    autosuggestion.enable = true;
    syntaxHighlighting.enable = true;
    history = {
      size = 10000;
      save = 10000;
      ignoreDups = true;
      share = true;
      path = "$HOME/.zsh_history";
    };
    shellAliases = {
      ll = "ls -lah";
      la = "ls -A";
      # /etc/nixos is a git checkout, but hardware-configuration.nix and
      # user-local.nix are gitignored, so rebuilds go through `path:`.
      rebuild = "sudo /etc/nixos/scripts/rebuild.sh";
      update = "git -C /etc/nixos pull --ff-only && sudo /etc/nixos/scripts/rebuild.sh";
      upgrade = "nix flake update --flake /etc/nixos && sudo /etc/nixos/scripts/rebuild.sh";
      clean = "sudo nh clean all";
      theme = "sudo /etc/nixos/scripts/theme.sh";
      matrix = "cmatrix";
    };
  };

  # --- Prompt (Catppuccin Powerline) --------------------------------------
  programs.starship = {
    enable = true;
    enableZshIntegration = true;
    settings = builtins.fromTOML (builtins.readFile ./starship-catppuccin-powerline.toml);
  };

  programs.zoxide = {
    enable = true;
    enableZshIntegration = true;
  };

  programs.direnv = {
    enable = true;
    nix-direnv.enable = true;
  };

  programs.fzf.enable = true;
  programs.bat.enable = true;
  programs.btop.enable = true;

  home.packages = with pkgs; [
    fastfetch
    cmatrix
    wget
    # Nerd Font с powerline-глифами (  ) — выберите его в терминале
    nerd-fonts.jetbrains-mono

    # Niri helpers
    brightnessctl
    playerctl
    wl-clipboard
    swaylock
    swaybg
    procps # pkill for the wallpaper switcher
    xwayland-satellite

    # GUI file manager (Thunar + thumbnails + removable media)
    thunar
    thunar-volman
    tumbler
    xfconf

    # Yazi previews / integrations
    chafa
    ffmpegthumbnailer
    imagemagick
    poppler-utils

    # Nix Helper
    nh
    telegram-desktop
  ];
}
