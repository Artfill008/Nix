# Оверлей із нашими власними пакетами.
# Підключається у flake.nix і застосовується і до системи, і до home-manager.
final: prev: {
  # Керування RGB-підсвіткою MSI (немає в nixpkgs).
  msiklm = final.callPackage ../pkgs/msiklm { };

  # Наш інструмент автошпалер (Rust).
  moewall = final.callPackage ../tools/moewall { };

  # Наш менеджер декларативних пакетів (Rust).
  nixmgr = final.callPackage ../tools/nixmgr { };

  # Control plane машини: профілі, статус, health-check.
  # Збирається через writeShellApplication, тобто shellcheck проганяється
  # під час nixos-rebuild — помилка в скрипті завалить збірку, а не рантайм.
  gt72 = final.callPackage ../pkgs/gt72 { };
}
