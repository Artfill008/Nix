{
  lib,
  rustPlatform,
  pkg-config,
  matugen,
  swaybg,
  makeWrapper,
}:
rustPlatform.buildRustPackage {
  pname = "moewall";
  version = "0.1.0";

  src = ./.;

  # Cargo.lock лежить у репозиторії, тому НІЯКОГО cargoHash не потрібно:
  # nix читає лок напряму і сам вирахує все, що треба.
  # Це помітно зручніше за cargoHash, який доводиться оновлювати руками
  # при кожній зміні залежностей.
  cargoLock.lockFile = ./Cargo.lock;

  nativeBuildInputs = [
    pkg-config
    makeWrapper
  ];

  # openssl НЕ потрібен: reqwest зібраний з rustls-tls.

  postInstall = ''
    # matugen і swaybg мають бути в PATH інструмента незалежно від
    # того, що є в оточенні сесії.
    wrapProgram $out/bin/moewall \
      --prefix PATH : ${
        lib.makeBinPath [
          matugen
          swaybg
        ]
      }
  '';

  meta = {
    description = "Автоматичні шпалери з фільтрацією за кольором і матугеном";
    mainProgram = "moewall";
    license = lib.licenses.mit;
    platforms = lib.platforms.linux;
  };
}
