# Пакет для gt72 — control plane машини.
#
# ЧОМУ writeShellApplication, А НЕ writeShellScriptBin:
# writeShellApplication проганяє shellcheck ПІД ЧАС ЗБІРКИ. Тобто помилка
# в скрипті — це провал `nixos-rebuild`, а не сюрприз о третій ночі.
# Це рівно те, що ти просив від валідації: збірка є частиною перевірки.
#
# ЧОМУ ЦЕ ПОКИ SHELL, А НЕ RUST:
# Стабільним API для майбутнього GTK4/Relm4 фронтенду є НАБІР ПІДКОМАНД
# і формат `--json`, а не мова реалізації. Контракт зафіксований зараз;
# коли з'явиться час — усередині все переписується на Rust, і жоден
# споживач цього не помітить. Писати третій Rust-бінарник (після nixmgr
# і moewall) заради набору sysfs-проб було б передчасно.
{
  lib,
  writeShellApplication,
  # Явні залежності: у чистому середовищі Nix жодна з них не «просто є».
  coreutils,
  gnugrep,
  systemd,
  util-linux,
  procps,
  alsa-utils,
  kmod,
}:
writeShellApplication {
  name = "gt72";

  # Усе, що скрипт викликає і що МАЄ бути гарантовано.
  # Свідомо НЕ додаємо сюди nvidia-smi, sensors, wlr-randr, adb, nvme, snapper,
  # tuned-adm, vainfo, bluetoothctl: вони можуть бути відсутні (модуль вимкнено,
  # сесія не піднята), і скрипт це коректно обробляє через `command -v`.
  # Жорстка залежність зробила б health-check недоступним саме тоді,
  # коли він найпотрібніший.
  runtimeInputs = [
    coreutils
    gnugrep
    systemd # systemctl, busctl
    util-linux # mount
    procps # pgrep, sysctl
    alsa-utils # amixer — для gt72 audio probe
    kmod # lsmod
  ];

  text = builtins.readFile ./gt72.sh;

  meta = {
    description = "Control plane і health-check для MSI GT72S 6QE";
    longDescription = ''
      Єдина точка керування апаратними функціями GT72S.

      Розділяє декларативний стан (яким володіє Nix) і рантайм-стан
      (яким володіє цей інструмент). Зміна профілю продуктивності або
      перевірка здоров'я системи не потребують nixos-rebuild.

      Режим --json призначений як стабільний API для GUI-фронтенду.
    '';
    platforms = lib.platforms.linux;
    mainProgram = "gt72";
  };
}
