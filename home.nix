# User-level configuration managed by home-manager.
{
  config,
  lib,
  pkgs,
  username,
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
in

{
  home.username = username;
  home.homeDirectory = "/home/${username}";
  home.stateVersion = "26.05";

  programs.home-manager.enable = true;

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

  # Konsole has no home-manager module: ship a profile and make it default.
  xdg.dataFile."konsole/NixOS.profile".text = ''
    [Appearance]
    Font=JetBrainsMono Nerd Font Mono,11,-1,5,50,0,0,0,0,0

    [General]
    Name=NixOS
    Parent=FALLBACK/
  '';

  home.activation.konsoleDefaultProfile = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    $DRY_RUN_CMD ${pkgs.kdePackages.kconfig}/bin/kwriteconfig6 \
      --file "$HOME/.config/konsolerc" \
      --group "Desktop Entry" \
      --key DefaultProfile "NixOS.profile"
  '';

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

  # Thunar as the default GUI file manager.
  xdg.mimeApps = {
    enable = true;
    defaultApplications."inode/directory" = "thunar.desktop";
  };

  # Automount removable media + safe unmount (`udiskie-umount -a`).
  services.udiskie = {
    enable = true;
    automount = true;
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
          active.color = "#eab676";
          inactive.color = "#282828";
          urgent.color = "#9b0000";
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
      rebuild = "sudo nh os switch ~/nixos-config";
      update = "sudo nh os switch --update ~/nixos-config";
      clean = "sudo nh clean all";
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
    wget
    # Nerd Font с powerline-глифами (  ) — выберите его в Konsole
    nerd-fonts.jetbrains-mono

    # Niri helpers
    brightnessctl
    playerctl
    wl-clipboard
    swaylock
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
