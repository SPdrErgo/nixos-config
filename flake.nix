{
  description = "NixOS VM configuration (nixos-26.05)";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-26.05";

    home-manager = {
      url = "github:nix-community/home-manager/release-26.05";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    niri = {
      url = "github:sodiboo/niri-flake";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    noctalia = {
      url = "github:noctalia-dev/noctalia/cachix";
    };

    zen-browser.url = "github:0xc000022070/zen-browser-flake";
  };

  outputs =
    {
      self,
      nixpkgs,
      home-manager,
      ...
    }@inputs:
    let
      system = "x86_64-linux";
      pkgs = nixpkgs.legacyPackages.${system};
      username = (import ./user.nix).username;

      # One-command installer for a fresh NixOS (minimal) system:
      #   sudo nix --extra-experimental-features 'nix-command flakes' \
      #     run github:SPdrErgo/nixos-config#install
      installer = pkgs.writeShellScriptBin "nixos-config-install" ''
        export PATH="${pkgs.coreutils}/bin:$PATH"
        set -euo pipefail

        if [ "''${EUID}" -ne 0 ]; then
          echo "Run as root:" >&2
          echo "  sudo nix --extra-experimental-features 'nix-command flakes' run github:SPdrErgo/nixos-config#install" >&2
          exit 1
        fi

        SRC=${self}
        STAMP=$(date +%Y%m%d-%H%M%S)

        if [ ! -e /etc/NIXOS ]; then
          echo "Not a NixOS system (/etc/NIXOS missing)." >&2
          exit 1
        fi

        if [ ! -f /etc/nixos/hardware-configuration.nix ]; then
          echo "Missing /etc/nixos/hardware-configuration.nix." >&2
          echo "Generate it first:  sudo nixos-generate-config" >&2
          exit 1
        fi
        HW=$(mktemp)
        cp /etc/nixos/hardware-configuration.nix "$HW"

        if [ -d /etc/nixos ]; then
          cp -a /etc/nixos "/etc/nixos.bak-$STAMP"
        fi

        rm -rf /etc/nixos
        mkdir -p /etc/nixos
        cp -a "$SRC/." /etc/nixos/
        chmod -R u+w /etc/nixos
        cp "$HW" /etc/nixos/hardware-configuration.nix
        echo "kept existing /etc/nixos/hardware-configuration.nix"

        USER_NAME="nixos"
        if [ -n "$(printenv SUDO_USER)" ]; then
          USER_NAME="$(printenv SUDO_USER)"
        fi
        read -r -p "Username [$USER_NAME]: " input
        if [ -n "$input" ]; then
          USER_NAME="$input"
        fi
        if ! printf '%s' "$USER_NAME" | grep -qE '^[a-z_][a-z0-9_-]*$' || [ "$USER_NAME" = root ]; then
          echo "Invalid username: $USER_NAME" >&2
          exit 1
        fi
        printf '{ username = "%s"; }\n' "$USER_NAME" > /etc/nixos/user.nix

        export NIX_CONFIG="experimental-features = nix-command flakes"
        /run/current-system/sw/bin/nixos-rebuild switch --flake /etc/nixos#nixos \
          --option extra-substituters "https://mirror.yandex.ru/nixos https://niri.cachix.org https://noctalia.cachix.org" \
          --option extra-trusted-public-keys "niri.cachix.org-1:Wv0OmO7PsuocRKzfDoJ3mulSl7Z6oezYhGhR+3W2964= noctalia.cachix.org-1:pCOR47nnMEo5thcxNDtzWpOxNFQsBRglJzxWPp3dkU4="

        # Keep the familiar ~/nixos-config path working for the `rebuild` alias.
        if [ -d "/home/$USER_NAME" ]; then
          if [ -e "/home/$USER_NAME/nixos-config" ] && [ ! -L "/home/$USER_NAME/nixos-config" ]; then
            mv "/home/$USER_NAME/nixos-config" "/home/$USER_NAME/nixos-config.bak-$STAMP"
          fi
          ln -sfn /etc/nixos "/home/$USER_NAME/nixos-config"
          chown -h "$USER_NAME":users "/home/$USER_NAME/nixos-config" || true
        fi

        if [ -t 0 ] && [ -x /run/wrappers/bin/passwd ]; then
          echo
          echo "Set a password for $USER_NAME:"
          /run/wrappers/bin/passwd "$USER_NAME" || true
        fi

        echo "Done. Config installed to /etc/nixos."
      '';

      # Full install from the minimal ISO. Wipes the target disk:
      #   sudo nix --extra-experimental-features 'nix-command flakes' \
      #     run github:SPdrErgo/nixos-config#install-iso -- /dev/vda
      isoInstaller = pkgs.writeShellScriptBin "nixos-install-iso" ''
        export PATH="${
          pkgs.lib.makeBinPath [
            pkgs.coreutils
            pkgs.util-linux
            pkgs.parted
            pkgs.btrfs-progs
            pkgs.dosfstools
          ]
        }:$PATH"
        set -euo pipefail

        # Source tree of this flake in the Nix store (the installer used to
        # forget this line and died later with "SRC: unbound variable").
        SRC=${self}

        if [ "$(id -u)" -ne 0 ]; then
          echo "Run as root: sudo nix --extra-experimental-features 'nix-command flakes' run github:SPdrErgo/nixos-config#install-iso -- /dev/vda" >&2
          exit 1
        fi

        # configuration.nix uses systemd-boot, which only works when the ISO
        # was booted in UEFI mode. Fail before the disk is wiped.
        if [ ! -d /sys/firmware/efi ]; then
          echo "Refusing: this ISO was booted in legacy BIOS mode, but the config uses systemd-boot (UEFI)." >&2
          exit 1
        fi

        DISK=""
        if [ "$#" -ge 1 ]; then
          DISK="$1"
        fi
        if [ -z "$DISK" ]; then
          echo "Usage: ... -- /dev/vda   (whole disk, will be erased)" >&2
          exit 1
        fi
        if [ ! -b "$DISK" ]; then
          echo "Not a block device: $DISK" >&2
          exit 1
        fi

        case "$DISK" in
          *[0-9]) P1="$DISK"p1; P2="$DISK"p2 ;;
          *) P1="$DISK"1; P2="$DISK"2 ;;
        esac

        if lsblk -no MOUNTPOINTS "$DISK" 2>/dev/null | grep -q '[^[:space:]]'; then
          echo "Refusing: something from $DISK is mounted (live medium?)." >&2
          exit 1
        fi

        echo "This will ERASE $DISK ($P1 + $P2) and install NixOS."
        read -r -p "Type YES to continue: " ans
        if [ "$ans" != YES ]; then
          echo "aborted"
          exit 1
        fi

        USER_NAME="nixos"
        read -r -p "Username [$USER_NAME]: " input
        if [ -n "$input" ]; then
          USER_NAME="$input"
        fi
        if ! printf '%s' "$USER_NAME" | grep -qE '^[a-z_][a-z0-9_-]*$' || [ "$USER_NAME" = root ]; then
          echo "Invalid username: $USER_NAME" >&2
          exit 1
        fi

        umount -R /mnt 2>/dev/null || true
        wipefs -a "$DISK" >/dev/null
        parted -s "$DISK" mklabel gpt
        parted -s "$DISK" mkpart ESP fat32 1MiB 513MiB
        parted -s "$DISK" set 1 esp on
        parted -s "$DISK" mkpart root btrfs 513MiB 100%
        udevadm settle

        mkfs.fat -F 32 -n NIXBOOT "$P1"
        mkfs.btrfs -f -L nixos "$P2"

        mount "$P2" /mnt
        btrfs subvolume create /mnt/@
        btrfs subvolume create /mnt/@home
        btrfs subvolume create /mnt/@nix
        umount /mnt

        opts="compress=zstd,noatime"
        mount -o "$opts,subvol=@" "$P2" /mnt
        mkdir -p /mnt/home /mnt/nix /mnt/boot
        mount -o "$opts,subvol=@home" "$P2" /mnt/home
        mount -o "$opts,subvol=@nix" "$P2" /mnt/nix
        mount "$P1" /mnt/boot

        /run/current-system/sw/bin/nixos-generate-config --root /mnt
        if [ ! -f "$SRC/flake.nix" ]; then
          echo "Internal error: flake source not found at '$SRC'." >&2
          exit 1
        fi
        cp -a "$SRC/." /mnt/etc/nixos/
        printf '{ username = "%s"; }\n' "$USER_NAME" > /mnt/etc/nixos/user.nix

        export NIX_CONFIG="experimental-features = nix-command flakes"
        /run/current-system/sw/bin/nixos-install --flake /mnt/etc/nixos#nixos \
          --option extra-substituters "https://mirror.yandex.ru/nixos https://niri.cachix.org https://noctalia.cachix.org" \
          --option extra-trusted-public-keys "niri.cachix.org-1:Wv0OmO7PsuocRKzfDoJ3mulSl7Z6oezYhGhR+3W2964= noctalia.cachix.org-1:pCOR47nnMEo5thcxNDtzWpOxNFQsBRglJzxWPp3dkU4="

        /run/current-system/sw/bin/nixos-enter --root /mnt -c "ln -sfn /etc/nixos /home/$USER_NAME/nixos-config; chown -h $USER_NAME:users /home/$USER_NAME/nixos-config" || true
        /run/current-system/sw/bin/nixos-enter --root /mnt -c "passwd $USER_NAME" || true

        umount -R /mnt
        echo "Installed. Remove the ISO and reboot."
      '';
    in
    {
      apps.${system} = {
        install = {
          type = "app";
          program = "${installer}/bin/nixos-config-install";
        };
        "install-iso" = {
          type = "app";
          program = "${isoInstaller}/bin/nixos-install-iso";
        };
      };

      # `nix fmt` / `nix fmt .` formats *.nix in this directory with nixfmt.
      # nixfmt-tree = treefmt + nixfmt, but its bundled config lives in the
      # store, so without an explicit root it would walk all of /nix/store.
      formatter.x86_64-linux =
        let
          pkgs = nixpkgs.legacyPackages.x86_64-linux;
        in
        pkgs.writeShellScriptBin "fmt" ''
          export TREEFMT_TREE_ROOT="$PWD"
          export TREEFMT_EXCLUDES="result"
          exec ${pkgs.nixfmt-tree}/bin/treefmt "$@"
        '';

      nixosConfigurations.nixos = nixpkgs.lib.nixosSystem {
        specialArgs = { inherit inputs username; };

        modules = [
          ./configuration.nix

          home-manager.nixosModules.home-manager
          {
            home-manager.useGlobalPkgs = true;
            home-manager.useUserPackages = true;
            home-manager.backupFileExtension = "hm-backup";
            home-manager.extraSpecialArgs = { inherit username; };
            home-manager.users.${username} = {
              imports = [
                inputs.niri.homeModules.config
                inputs.noctalia.homeModules.default
                inputs.zen-browser.homeModules.default
                ./home.nix
              ];
            };
          }
        ];
      };
    };
}
