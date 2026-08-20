{
  description = "NixOS daily driver: MSI GT72S 6QE / Maxwell GTX 980M / mangowc";

  inputs = {
    # Канал: nixos-unstable.
    # Причина: пакет `mango` (0.16.0) і NixOS-модуль `programs.mango` є ТІЛЬКИ тут.
    # У nixos-26.05 їх немає взагалі (перевірено: raw-файли pkgs/by-name/ma/mango
    # і nixos/modules/programs/wayland/mango.nix віддають 404 на гілці nixos-26.05).
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

    home-manager = {
      url = "github:nix-community/home-manager";
      # Обов'язково: HM має збиратись проти ТОГО САМОГО nixpkgs, інакше отримаєш
      # два різні glibc/wlroots у замиканні і дивні падіння в рантаймі.
      inputs.nixpkgs.follows = "nixpkgs";
    };
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

      # TODO: заміни на свої значення перед першою збіркою.
      username = "user";
      hostname = "gt72s";

      # Оверлеї: наші власні пакети, яких немає в nixpkgs.
      overlays = [
        (import ./overlays/default.nix)
      ];

      pkgs = import nixpkgs {
        inherit system overlays;
        config = {
          # unfree потрібен для nvidia-x11 (пропрієтарний драйвер) і, за бажанням, для
          # steam/discord тощо. Без цього збірка впаде на самому драйвері.
          allowUnfree = true;
        };
      };
    in
    {
      nixosConfigurations.${hostname} = nixpkgs.lib.nixosSystem {
        inherit system;

        # specialArgs пробрасує змінні в КОЖЕН модуль, включно з тими, що
        # оцінюються до того, як `config` повністю зібраний (imports, наприклад).
        specialArgs = {
          inherit inputs username hostname;
        };

        modules = [
          # Оверлеї застосовуємо через модуль, а не через окремий `import nixpkgs`,
          # щоб і система, і home-manager бачили однакові пакети.
          { nixpkgs = { inherit overlays; config.allowUnfree = true; }; }

          ./hosts/gt72s/default.nix

          home-manager.nixosModules.home-manager
          {
            home-manager = {
              useGlobalPkgs = true;   # HM бере pkgs системи — одне замикання, не два
              useUserPackages = true; # пакети юзера йдуть у /etc/profiles, а не в ~/.nix-profile
              extraSpecialArgs = { inherit inputs username; };
              users.${username} = import ./home/default.nix;
            };
          }
        ];
      };

      # Наші інструменти доступні як `nix build .#moewall` / `.#nixmgr` / `.#msiklm`.
      packages.${system} = {
        inherit (pkgs) msiklm moewall nixmgr;
        default = pkgs.moewall;
      };

      # `nix develop` для розробки Rust-інструментів.
      devShells.${system}.default = pkgs.mkShell {
        packages = with pkgs; [
          cargo
          rustc
          rust-analyzer
          clippy
          rustfmt
          pkg-config
          openssl
        ];
      };

      formatter.${system} = pkgs.nixfmt;
    };
}
