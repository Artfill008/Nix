# Локальний ігровий стек.
#
# ЗА ТВОЇМ РІШЕННЯМ ЦЕЙ МОДУЛЬ ВИМКНЕНИЙ.
# Основний ігровий фронтенд — GeForce NOW (див. modules/flatpak.nix).
# Тут усе написано і готове; вмикається одним рядком у hosts/gt72s/default.nix:
#     fennec.gaming.enable = true;
{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.fennec.gaming;
in
{
  options.fennec.gaming = {
    enable = lib.mkEnableOption ''
      локальний ігровий стек: Steam + Proton + GameMode + 32-бітна графіка.

      Вимкнено за замовчуванням: основний ігровий шлях на цій машині —
      GeForce NOW, а локальний стек тягне кілька десятків гігабайт
      і 32-бітні дублікати всього графічного стеку.
    '';

    gamescope = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = ''
        Окремий тумблер, як ти й просив.

        Gamescope — мікрокомпозитор, який ізолює гру від композитора хоста:
        дає власний масштаб, фіксований FPS-ліміт і рятує від проблем
        з фокусом у Wayland.

        ЧОМУ ОКРЕМО І ЧОМУ ВИМКНЕНО: на NVIDIA пропрієтарному, та ще й на
        Maxwell, gamescope історично найпроблемніший — від чорного екрана
        до втрати апаратного курсора. Вмикай, коли конкретна гра цього
        потребує, а не «про всяк випадок».
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    programs.steam = {
      enable = true;
      # Відкриває порти для Remote Play і локального кооперативу.
      remotePlay.openFirewall = true;
      localNetworkGameTransfers.openFirewall = true;
      # gamescope як сесія для Steam Big Picture — лише якщо явно ввімкнено.
      gamescopeSession.enable = cfg.gamescope;
    };

    # GameMode: під час гри тимчасово міняє governor, пріоритет процесу
    # і вимикає економію. Працює через D-Bus на запит самої гри —
    # тобто не фоновий демон, що постійно щось крутить.
    programs.gamemode = {
      enable = true;
      settings = {
        general = {
          renice = 10;
          # НЕ чіпаємо governor тут: цим керує TuneD (див. performance.nix).
          # Два керівники governor — це саме той конфлікт, якого ми уникаємо.
          inhibit_screensaver = 1;
        };
        # GameMode вміє смикати TuneD-профіль через D-Bus — правильний спосіб
        # співіснування замість боротьби за sysfs.
        custom = {
          start = "${pkgs.libnotify}/bin/notify-send 'GameMode' 'Профіль продуктивності увімкнено'";
          end = "${pkgs.libnotify}/bin/notify-send 'GameMode' 'Профіль продуктивності вимкнено'";
        };
      };
    };

    environment.systemPackages =
      with pkgs;
      [
        mangohud # оверлей FPS/температур; на 980M корисно бачити троттлінг
        protonup-qt # керування версіями Proton-GE
      ]
      ++ lib.optional cfg.gamescope gamescope;

    # 32-бітна графіка вже увімкнена в modules/nvidia.nix
    # (hardware.graphics.enable32Bit = true) — потрібна для старих ігор і Wine.

    warnings = lib.optional cfg.gamescope ''
      fennec.gaming.gamescope увімкнено на NVIDIA Maxwell.
      Якщо побачиш чорний екран або зниклий курсор у грі — це перше,
      що треба вимкнути.
    '';
  };
}
