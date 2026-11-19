# Portable NixOS 26.05 reference configuration.
# Machine-specific hardware-configuration.nix is NOT in the repo: generate it
# with `nixos-generate-config` (the installer below does not copy one in).
# User-level settings live in ./home.nix (home-manager).
{
  config,
  lib,
  pkgs,
  inputs,
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

  # --- Desktop (KDE Plasma 6) ---------------------------------------------
  services.xserver.enable = true;
  services.displayManager.ly.enable = true;
  #  services.desktopManager.plasma6.enable = true;
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

  # Niri (Wayland session, available alongside Plasma in SDDM).
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
  users.users.spdr_v0x8r = {
    isNormalUser = true;
    description = "spdr_v0x8r";
    extraGroups = [
      "networkmanager"
      "wheel"
    ];
    shell = pkgs.zsh;
    packages = with pkgs; [
      kdePackages.kate
    ];
    # No SSH key in the snapshot: add your own with
    #   ssh-copy-id spdr_v0x8r@<host>
    # or put `openssh.authorizedKeys.keys = [ "ssh-ed25519 ..." ];` here.
  };

  # --- SSH ----------------------------------------------------------------
  services.openssh = {
    enable = true;
    settings = {
      PermitRootLogin = "no";
      PasswordAuthentication = true; # key auth is set up above; turn off once sure
      KbdInteractiveAuthentication = false;
    };
  };

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
      "spdr_v0x8r"
    ];

    # Binary caches (from AndrianoTurner/nixdotfiles + niri-flake).
    connect-timeout = 10;
    stalled-download-timeout = 30;
    download-attempts = 2;
    substituters = [
      "https://mirror.yandex.ru/nixos/?priority=10"
      "https://cache.nixos.org/?priority=40"
      "https://niri.cachix.org/?priority=50"
      "https://noctalia.cachix.org/?priority=60"
    ];
    trusted-public-keys = [
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
