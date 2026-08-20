{
  lib,
  rustPlatform,
  makeWrapper,
  nix,
  nixos-rebuild,
}:
rustPlatform.buildRustPackage {
  pname = "nixmgr";
  version = "0.1.0";

  src = ./.;
  cargoLock.lockFile = ./Cargo.lock;

  nativeBuildInputs = [ makeWrapper ];

  postInstall = ''
    # nix і nixos-rebuild мають бути в PATH: інструмент викликає їх
    # як зовнішні процеси (свідомо — жодних прив'язок до C-API nix,
    # який ламається кожен мажорний реліз).
    wrapProgram $out/bin/nixmgr \
      --prefix PATH : ${
        lib.makeBinPath [
          nix
          nixos-rebuild
        ]
      }
  '';

  meta = {
    description = "Декларативний менеджер пакетів NixOS з фазі-пошуком і відкатом";
    mainProgram = "nixmgr";
    license = lib.licenses.mit;
    platforms = lib.platforms.linux;
  };
}
