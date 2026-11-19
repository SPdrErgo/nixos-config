# Portable NixOS 26.05 reference configuration.
# Machine-specific hardware-configuration.nix is NOT in the repo: generate it
# with `nixos-generate-config` (the installer below does not copy one in).
# User-level settings live in ./home.nix (home-manager).
{
  config,
  lib,
  pkgs,
  inputs,
  username,
  ...
}:

{
  imports = lib.optional (builtins.pathExists ./hardware-configuration.nix) ./hardware-configuration.nix;

  # --- Boot ---------------------------------------------------------------
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;
  boot.kernelPackages = pkgs.linuxPackages_latest;

  # --- Networking ---------------------------------------------------------
  networking.hostName = "nixos";
  networking.networkmanager.enable = true;

  # Firewall stays enabled. Open ports here if a service needs them, e.g.:
  # networking.firewall.allowedTCPPorts = [ 8080 ];

  # --- Locale / time ------------------------------------------------------
  time.timeZone = "Europe/Moscow";
  i18n.defaultLocale = "en_US.UTF-8";
  i18n.extraLocaleSettings = {
    LC_ADDRESS = "ru_RU.UTF-8";
    LC_IDENTIFICATION = "ru_RU.UTF-8";
    LC_MEASUREMENT = "ru_RU.UTF-8";
    LC_MONETARY = "ru_RU.UTF-8";
    LC_NAME = "ru_RU.UTF-8";
    LC_NUMERIC = "ru_RU.UTF-8";
    LC_PAPER = "ru_RU.UTF-8";
    LC_TELEPHONE = "ru_RU.UTF-8";
    LC_TIME = "ru_RU.UTF-8";
  };

  # --- Desktop (niri / Wayland) -------------------------------------------
  services.xserver.enable = true;
  services.displayManager.ly.enable = true;

  # Login screen: Conway's Game of Life on a dark green background.
  # Colors are 0xSSRRGGBB (see `res/config.ini` in the ly sources).
  services.displayManager.ly.settings = {
    animation = "gameoflife";
    bg = "0x000B3E1C";
    fg = "0x00EAFFEA";
    border_fg = "0x0040FF80";
    gameoflife_fg = "0x006BFF9A";
    gameoflife_frame_delay = 6;
    gameoflife_initial_density = "0.4";
    gameoflife_entropy_interval = 10;
  };

  services.xserver.xkb = {
    layout = "us,ru";
    variant = "";
    options = "grp:win_space_toggle";
  };

  services.libinput.enable = true;
  services.printing.enable = true;

  # Removable media: gvfs for Thunar/Nautilus, udisks2 as the backend.
  services.gvfs.enable = true;
  services.udisks2.enable = true;

  # Niri (Wayland session, started by the `ly` display manager).
  programs.niri.enable = true;

  # --- Audio --------------------------------------------------------------
  services.pulseaudio.enable = false;
  security.rtkit.enable = true;
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;
  };

  # --- Users --------------------------------------------------------------
  # Username comes from ./user-local.nix (installer) or ./user.nix (default).
  users.users.${username} = {
    isNormalUser = true;
    description = username;
    extraGroups = [
      "networkmanager"
      "wheel"
    ];
    shell = pkgs.zsh;
  };

  # SSH is intentionally disabled in this reference config.
  # Enable it yourself (add your key first!):
  #
  # services.openssh = {
  #   enable = true;
  #   settings.PasswordAuthentication = false;
  # };
  # users.users.${username}.openssh.authorizedKeys.keys = [ "ssh-ed25519 AAAA..." ];

  # --- Nix ----------------------------------------------------------------
  nix.settings = {
    experimental-features = [
      "nix-command"
      "flakes"
      "ca-derivations"
    ];
    auto-optimise-store = true;
    trusted-users = [
      "root"
      username
    ];

    # Binary caches. Nix tries them in priority order and moves to the next
    # one when a mirror is down; Yandex usually works from Russia, SJTU is a
    # last-resort mirror of cache.nixos.org.
    connect-timeout = 10;
    stalled-download-timeout = 30;
    download-attempts = 3;
    substituters = [
      "https://mirror.yandex.ru/nixos/?priority=10"
      "https://cache.nixos.org/?priority=40"
      "https://niri.cachix.org/?priority=50"
      "https://noctalia.cachix.org/?priority=60"
      "https://mirror.sjtu.edu.cn/nix-channels/store?priority=90"
    ];
    trusted-public-keys = [
      "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY="
      "niri.cachix.org-1:Wv0OmO7PsuocRKzfDoJ3mulSl7Z6oezYhGhR+3W2964="
      "noctalia.cachix.org-1:pCOR47nnMEo5thcxNDtzWpOxNFQsBRglJzxWPp3dkU4="
    ];
  };

  nix.gc = {
    automatic = true;
    dates = "weekly";
    options = "--delete-older-than 14d";
  };

  nix.optimise.automatic = true;

  nixpkgs.config.allowUnfree = true;

  # --- Packages -----------------------------------------------------------
  programs.firefox.enable = true;
  programs.zsh.enable = true; # required for users.users.*.shell = pkgs.zsh

  environment.systemPackages = with pkgs; [
    # base
    git
    shadow # chpasswd: used by the installer to set root/user passwords
    neovim
    wget
    curl
    htop
    tmux
    ripgrep
    fd
    jq
    tree
    unzip
    p7zip
    file
    rsync

    # development
    python3
    gcc
    gnumake

    # CTF / security basics
    nmap
    tcpdump
    exiftool
  ];

  # --- Misc ---------------------------------------------------------------
  system.stateVersion = "26.05";
}
