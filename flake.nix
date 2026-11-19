{
  description = "NixOS 26.05 reference config (niri + home-manager)";

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

      # The installers write ./user-local.nix (gitignored) with the chosen
      # name; the tracked ./user.nix stays untouched so `git pull` is clean.
      username =
        if builtins.pathExists ./user-local.nix then
          (import ./user-local.nix).username
        else
          (import ./user.nix).username;

      # Colour theme. `theme <name>` writes ./theme-local.nix (gitignored).
      themeName =
        if builtins.pathExists ./theme-local.nix then
          (import ./theme-local.nix).name
        else
          "catppuccin-mocha";
      themes = import ./themes.nix;
      theme = themes.${themeName} or (throw "Unknown theme '${themeName}' (see themes.nix)");

      repoUrl = "https://github.com/SPdrErgo/nixos-config";

      # cache.nixos.org has to stay in this list: `--option trusted-public-keys`
      # replaces the defaults, it does not extend them.
      cacheKeys = "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY= niri.cachix.org-1:Wv0OmO7PsuocRKzfDoJ3mulSl7Z6oezYhGhR+3W2964= noctalia.cachix.org-1:pCOR47nnMEo5thcxNDtzWpOxNFQsBRglJzxWPp3dkU4=";

      # Shared by both installers: copy the flake source into $1 and turn it
      # into a git checkout of repoUrl, so the installed system can be updated
      # with `git pull`. Machine-specific files are written by the caller.
      syncConfig = ''
        sync_config() {
          local dest="$1"
          if [ ! -f "$SRC/flake.nix" ]; then
            echo "Internal error: flake source not found at '$SRC'." >&2
            return 1
          fi
          export GIT_TERMINAL_PROMPT=0
          rm -rf "$dest"
          mkdir -p "$dest"
          cp -a "$SRC/." "$dest"/
          chmod -R u+w "$dest"
          rm -rf "$dest/.git"
          git -C "$dest" init -q -b main
          git -C "$dest" remote add origin "${repoUrl}"
          git -C "$dest" config pull.rebase true
          if timeout 120 git -C "$dest" fetch -q origin main; then
            git -C "$dest" reset --hard -q FETCH_HEAD
            git -C "$dest" branch -q --set-upstream-to=origin/main main
          else
            echo "warning: could not reach ${repoUrl}" >&2
            echo "warning: files were installed from the local flake source." >&2
            echo "warning: later run: git -C $dest fetch origin && git -C $dest reset --hard origin/main" >&2
          fi
        }
      '';

      # Reads a password twice (no echo) and prints it on stdout. Prompts go to
      # stderr, so `VAR=$(read_password "Root password")` works.
      readPassword = ''
        read_password() {
          local prompt="$1" p1 p2
          while :; do
            read -r -s -p "$prompt: " p1
            echo >&2
            read -r -s -p "Repeat $prompt: " p2
            echo >&2
            if [ -z "$p1" ]; then
              echo "Password must not be empty." >&2
              continue
            fi
            if [ "$p1" = "$p2" ]; then
              printf '%s' "$p1"
              return 0
            fi
            echo "Passwords do not match." >&2
          done
        }
      '';

      # One-command installer for an existing NixOS (minimal or full):
      #   sudo nix --extra-experimental-features 'nix-command flakes' \
      #     run github:SPdrErgo/nixos-config#install
      installer = pkgs.writeShellScriptBin "nixos-config-install" ''
        export PATH="${
          pkgs.lib.makeBinPath [
            pkgs.coreutils
            pkgs.git
            pkgs.curl
          ]
        }:$PATH"
        set -euo pipefail

        SRC=${self}

        ${readPassword}

        ${syncConfig}

        if [ "''${EUID}" -ne 0 ]; then
          echo "Run as root:" >&2
          echo "  sudo nix --extra-experimental-features 'nix-command flakes' run github:SPdrErgo/nixos-config#install" >&2
          exit 1
        fi

        if [ ! -e /etc/NIXOS ]; then
          echo "Not a NixOS system (/etc/NIXOS missing)." >&2
          exit 1
        fi

        if [ ! -f /etc/nixos/hardware-configuration.nix ]; then
          echo "Missing /etc/nixos/hardware-configuration.nix." >&2
          echo "Generate it first:  sudo nixos-generate-config" >&2
          exit 1
        fi

        STAMP=$(date +%Y%m%d-%H%M%S)

        HW=$(mktemp)
        cp /etc/nixos/hardware-configuration.nix "$HW"

        OLD_USER=""
        if [ -f /etc/nixos/user-local.nix ]; then
          OLD_USER=$(sed -n 's/.*username *= *"\([^"]*\)".*/\1/p' /etc/nixos/user-local.nix | head -n 1)
        fi
        if [ -z "$OLD_USER" ] && [ -f /etc/nixos/user.nix ]; then
          OLD_USER=$(sed -n 's/.*username *= *"\([^"]*\)".*/\1/p' /etc/nixos/user.nix | head -n 1)
        fi

        cp -a /etc/nixos "/etc/nixos.bak-$STAMP"

        USER_NAME="nixos"
        if [ -n "$OLD_USER" ]; then
          USER_NAME="$OLD_USER"
        fi
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

        USER_PASS=$(read_password "Password for $USER_NAME")
        ROOT_PASS=""
        read -r -s -p "Root password (empty = keep current): " ROOT_PASS
        echo
        if [ -n "$ROOT_PASS" ]; then
          root2=""
          read -r -s -p "Repeat root password: " root2
          echo
          if [ "$ROOT_PASS" != "$root2" ]; then
            echo "Root passwords do not match." >&2
            exit 1
          fi
          unset root2
        fi

        sync_config /etc/nixos
        cp "$HW" /etc/nixos/hardware-configuration.nix
        printf '{ username = "%s"; }\n' "$USER_NAME" > /etc/nixos/user-local.nix
        chown -R "$USER_NAME":users /etc/nixos
        echo "kept existing /etc/nixos/hardware-configuration.nix"

        SUBS=$(bash "$SRC/scripts/nix-caches.sh" 2>/dev/null || true)
        if [ -z "$SUBS" ]; then
          SUBS="https://cache.nixos.org"
        fi

        export NIX_CONFIG="experimental-features = nix-command flakes"
        /run/current-system/sw/bin/nixos-rebuild switch --flake "path:/etc/nixos#nixos" \
          --option substituters "$SUBS" \
          --option trusted-public-keys "${cacheKeys}" \
          --option connect-timeout 15 \
          --option download-attempts 3

        # Keep the familiar ~/nixos-config path working for the `rebuild` alias.
        if [ -d "/home/$USER_NAME" ]; then
          if [ -e "/home/$USER_NAME/nixos-config" ] && [ ! -L "/home/$USER_NAME/nixos-config" ]; then
            mv "/home/$USER_NAME/nixos-config" "/home/$USER_NAME/nixos-config.bak-$STAMP"
          fi
          ln -sfn /etc/nixos "/home/$USER_NAME/nixos-config"
          chown -h "$USER_NAME":users "/home/$USER_NAME/nixos-config" || true
        fi

        {
          if [ -n "$ROOT_PASS" ]; then
            printf 'root:%s\n' "$ROOT_PASS"
          fi
          printf '%s:%s\n' "$USER_NAME" "$USER_PASS"
        } | ${pkgs.shadow}/bin/chpasswd
        unset ROOT_PASS USER_PASS
        echo "Passwords updated."

        echo "Done. /etc/nixos is a git checkout; update it with 'git -C /etc/nixos pull'."
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
            pkgs.cryptsetup
            pkgs.git
            pkgs.curl
          ]
        }:$PATH"
        set -euo pipefail

        # Source tree of this flake in the Nix store.
        SRC=${self}

        ${readPassword}

        ${syncConfig}

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

        umount -R /mnt 2>/dev/null || true

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

        read -r -p "Encrypt the root partition with LUKS? [y/N]: " ans
        ENCRYPT=no
        case "$ans" in
          y | Y | yes | YES) ENCRYPT=yes ;;
        esac

        USER_NAME="nixos"
        read -r -p "Username [$USER_NAME]: " input
        if [ -n "$input" ]; then
          USER_NAME="$input"
        fi
        if ! printf '%s' "$USER_NAME" | grep -qE '^[a-z_][a-z0-9_-]*$' || [ "$USER_NAME" = root ]; then
          echo "Invalid username: $USER_NAME" >&2
          exit 1
        fi

        ROOT_PASS=$(read_password "Root password")
        USER_PASS=$(read_password "Password for $USER_NAME")

        wipefs -a "$DISK" >/dev/null
        parted -s "$DISK" mklabel gpt
        parted -s "$DISK" mkpart ESP fat32 1MiB 513MiB
        parted -s "$DISK" set 1 esp on
        parted -s "$DISK" mkpart root btrfs 513MiB 100%
        udevadm settle

        mkfs.fat -F 32 -n NIXBOOT "$P1"

        ROOT_PART="$P2"
        LUKS_NAME=""
        if [ "$ENCRYPT" = yes ]; then
          while :; do
            read -r -s -p "LUKS passphrase: " luks1
            echo
            read -r -s -p "Repeat passphrase: " luks2
            echo
            if [ -z "$luks1" ]; then
              echo "Passphrase must not be empty." >&2
              continue
            fi
            if [ "$luks1" = "$luks2" ]; then
              break
            fi
            echo "Passphrases do not match." >&2
          done
          LUKS_NAME="luks-$(blkid -s UUID -o value "$P2")"
          printf '%s' "$luks1" | cryptsetup luksFormat --type luks2 --batch-mode --label cryptroot --key-file - "$P2"
          printf '%s' "$luks1" | cryptsetup open --type luks2 --key-file - "$P2" "$LUKS_NAME"
          unset luks1 luks2
          ROOT_PART="/dev/mapper/$LUKS_NAME"
          udevadm settle
          echo "LUKS enabled: $ROOT_PART"
        fi

        mkfs.btrfs -f -L nixos "$ROOT_PART"

        mount "$ROOT_PART" /mnt
        btrfs subvolume create /mnt/@
        btrfs subvolume create /mnt/@home
        btrfs subvolume create /mnt/@nix
        umount /mnt

        opts="compress=zstd,noatime"
        mount -o "$opts,subvol=@" "$ROOT_PART" /mnt
        mkdir -p /mnt/home /mnt/nix /mnt/boot
        mount -o "$opts,subvol=@home" "$ROOT_PART" /mnt/home
        mount -o "$opts,subvol=@nix" "$ROOT_PART" /mnt/nix
        mount "$P1" /mnt/boot

        /run/current-system/sw/bin/nixos-generate-config --root /mnt
        HW=$(mktemp)
        cp /mnt/etc/nixos/hardware-configuration.nix "$HW"

        sync_config /mnt/etc/nixos
        cp "$HW" /mnt/etc/nixos/hardware-configuration.nix
        printf '{ username = "%s"; }\n' "$USER_NAME" > /mnt/etc/nixos/user-local.nix

        SUBS=$(bash "$SRC/scripts/nix-caches.sh" 2>/dev/null || true)
        if [ -z "$SUBS" ]; then
          SUBS="https://cache.nixos.org"
        fi
        echo "using substituters: $SUBS"

        export NIX_CONFIG="experimental-features = nix-command flakes"
        # `path:` keeps the gitignored hardware-configuration.nix in the build.
        /run/current-system/sw/bin/nixos-install --flake "path:/mnt/etc/nixos#nixos" \
          --no-root-password \
          --option substituters "$SUBS" \
          --option trusted-public-keys "${cacheKeys}" \
          --option connect-timeout 15 \
          --option download-attempts 3

        /run/current-system/sw/bin/nixos-enter --root /mnt -c "chown -R $USER_NAME:users /etc/nixos; ln -sfn /etc/nixos /home/$USER_NAME/nixos-config; chown -h $USER_NAME:users /home/$USER_NAME/nixos-config" || true

        # Set both passwords explicitly. chpasswd reads from stdin, so no TTY
        # tricks with `passwd` inside the chroot are needed.
        PWFILE=/mnt/root/.nixos-install-pw
        {
          printf 'root:%s\n' "$ROOT_PASS"
          printf '%s:%s\n' "$USER_NAME" "$USER_PASS"
        } > "$PWFILE"
        chmod 600 "$PWFILE"
        /run/current-system/sw/bin/nixos-enter --root /mnt -c "chpasswd < /root/.nixos-install-pw"
        rm -f "$PWFILE"
        unset ROOT_PASS USER_PASS

        umount -R /mnt
        if [ -n "$LUKS_NAME" ]; then
          cryptsetup close "$LUKS_NAME" || true
        fi
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
        specialArgs = { inherit inputs username theme themeName; };

        modules = [
          ./configuration.nix

          home-manager.nixosModules.home-manager
          {
            home-manager.useGlobalPkgs = true;
            home-manager.useUserPackages = true;
            home-manager.backupFileExtension = "hm-backup";
            home-manager.extraSpecialArgs = { inherit username theme themeName; };
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
