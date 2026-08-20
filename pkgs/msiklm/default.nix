# MSIKLM — MSI Keyboard Light Manager.
# У nixpkgs його НЕМАЄ (перевірено: pkgs/by-name/ms/msiklm → 404,
# і в all-packages.nix згадок немає). Тому пакуємо самі.
#
# Що це: керує підсвіткою SteelSeries-клавіатур MSI через USB HID (1770:ff00).
# Саме так підсвітка керується на GT72S — НЕ через EC (msi-ec явно позначає
# kbd_bl як MSI_EC_ADDR_UNSUPP для конфігу CONF_G1_10 з нашою прошивкою).
#
# Зони (з src/msiklm.h, enum region — перевірено дослівно):
#   left=1, middle=2, right=3, logo=4, front_left=5, front_right=6, mouse=7
# Тобто 3 зони клавіатури + 2 передні зони — рівно те, що тобі потрібно.
{
  lib,
  stdenv,
  fetchFromGitHub,
  hidapi,
  pkg-config,
}:
stdenv.mkDerivation (finalAttrs: {
  pname = "msiklm";
  # Тегів у репозиторії немає (перевірено), тому пінимось на конкретний комміт.
  # e9a7594 — «Minor update», 2023-03-14, останній на master.
  version = "0-unstable-2023-03-14";

  src = fetchFromGitHub {
    owner = "Gibtnix";
    repo = "MSIKLM";
    # TODO: підстав повний 40-символьний SHA. Скорочений теж працює в
    # fetchFromGitHub, але повний надійніший.
    rev = "e9a7594";
    # TODO: перша збірка впаде і надрукує правильний хеш — встав його сюди.
    hash = lib.fakeHash;
  };

  nativeBuildInputs = [ pkg-config ];
  # Makefile лінкується з -lhidapi-libusb (перевірено у Makefile).
  buildInputs = [ hidapi ];

  # Makefile жорстко ставить CC=gcc і INSTALLPREFIX=/usr/local/bin,
  # тому install-ціль не використовуємо, кладемо руками.
  makeFlags = [ "CC=${stdenv.cc.targetPrefix}cc" ];

  installPhase = ''
    runHook preInstall
    install -Dm755 msiklm $out/bin/msiklm
    runHook postInstall
  '';

  meta = {
    description = "Керування підсвіткою SteelSeries-клавіатур ноутбуків MSI";
    homepage = "https://github.com/Gibtnix/MSIKLM";
    license = lib.licenses.mit;
    platforms = lib.platforms.linux;
    mainProgram = "msiklm";
  };
})
