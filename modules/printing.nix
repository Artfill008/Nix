# Друк і сканування.
#
# ЗА ТВОЇМ РІШЕННЯМ ЦЕЙ МОДУЛЬ ВИМКНЕНИЙ.
# Написаний повністю; вмикається одним рядком:
#     fennec.printing.enable = true;
#
# Ціна вмикання — три фонові служби (cupsd, cups-browsed, avahi-daemon)
# і mDNS-трафік у локальній мережі.
{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.fennec.printing;
in
{
  options.fennec.printing = {
    enable = lib.mkEnableOption "друк через CUPS з автовиявленням мережевих принтерів";

    scanning = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Додатково: SANE + simple-scan для МФУ.";
    };
  };

  config = lib.mkIf cfg.enable {
    services.printing = {
      enable = true;
      # Драйвери. gutenprint покриває більшість Epson/Canon,
      # hplip — HP (включно зі сканером у МФУ).
      # TODO: якщо принтер Brother — драйвер у nixpkgs називається інакше
      # і залежить від моделі. Перевір: nix search nixpkgs brother
      drivers = with pkgs; [
        gutenprint
        hplip
      ];
      # Дозволяємо CUPS самому знаходити IPP-принтери.
      browsing = true;
    };

    # ── Avahi ─────────────────────────────────────────────────────────────────
    # mDNS: саме він робить «принтер знайшовся сам».
    # Без нього довелося б вбивати IP принтера руками.
    services.avahi = {
      enable = true;
      nssmdns4 = true;
      openFirewall = true;
      # Ми лише шукаємо, а не публікуємо себе в мережі.
      publish.enable = false;
    };

    # GUI для керування чергою і додавання принтерів.
    environment.systemPackages =
      with pkgs;
      [
        system-config-printer
      ]
      ++ lib.optional cfg.scanning simple-scan;

    # ── Сканування ────────────────────────────────────────────────────────────
    hardware.sane = lib.mkIf cfg.scanning {
      enable = true;
      # hplip-сканери потребують окремого бекенду.
      extraBackends = [ pkgs.hplip ];
    };
    # Користувач має бути в групі scanner — інакше сканер видно, але не читається.
    users.groups.scanner = lib.mkIf cfg.scanning { };
  };
}
