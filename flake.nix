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

        export NIX_CONFIG="experimental-features = nix-command flakes"
        /run/current-system/sw/bin/nixos-rebuild switch --flake /etc/nixos#nixos \
          --option extra-substituters "https://mirror.yandex.ru/nixos https://niri.cachix.org https://noctalia.cachix.org" \
          --option extra-trusted-public-keys "niri.cachix.org-1:Wv0OmO7PsuocRKzfDoJ3mulSl7Z6oezYhGhR+3W2964= noctalia.cachix.org-1:pCOR47nnMEo5thcxNDtzWpOxNFQsBRglJzxWPp3dkU4="

        # Keep the familiar ~/nixos-config path working for the `rebuild` alias.
        if [ -d /home/spdr_v0x8r ]; then
          if [ -e /home/spdr_v0x8r/nixos-config ] && [ ! -L /home/spdr_v0x8r/nixos-config ]; then
            mv /home/spdr_v0x8r/nixos-config "/home/spdr_v0x8r/nixos-config.bak-$STAMP"
          fi
          ln -sfn /etc/nixos /home/spdr_v0x8r/nixos-config
          chown -h spdr_v0x8r:users /home/spdr_v0x8r/nixos-config || true
        fi

        if [ -t 0 ] && [ -x /run/wrappers/bin/passwd ]; then
          echo
          echo "Set a password for spdr_v0x8r:"
          /run/wrappers/bin/passwd spdr_v0x8r || true
        fi

        echo "Done. Config installed to /etc/nixos."
      '';
    in
    {
      apps.${system}.install = {
        type = "app";
        program = "${installer}/bin/nixos-config-install";
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
        specialArgs = { inherit inputs; };

        modules = [
          ./configuration.nix

          home-manager.nixosModules.home-manager
          {
            home-manager.useGlobalPkgs = true;
            home-manager.useUserPackages = true;
            home-manager.backupFileExtension = "hm-backup";
            home-manager.users.spdr_v0x8r = {
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
