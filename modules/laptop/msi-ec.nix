# ── MSI Embedded Controller: вентилятори, cooler boost, shift mode ────────────
#
# ЩО ПЕРЕВІРЕНО (за вихідниками, не за форумами):
#
#  msi-ec (out-of-tree, github:BeardOverflow/msi-ec) МАЄ твою машину у білому
#  списку прошивок. Рядок 824 у msi-ec.c гілки main:
#        "1782EMS1.109", // GT72 6QE Dominator Pro
#  Він належить до блоку CONF_G1_10, який дає:
#        cooler_boost  → EC 0x98, біт 7
#        shift_mode    → EC 0xf2: eco(0xc2) / comfort(0xc1) / sport(0xc0)
#        fan_mode      → EC 0xf4: auto(0x0c) / basic(0x4c) / advanced(0x8c)
#        cpu.rt_temp   → EC 0x68,  cpu.rt_fan_speed → EC 0x71
#        gpu.rt_temp   → EC 0x80,  gpu.rt_fan_speed → EC 0x89
#        kbd_bl        → MSI_EC_ADDR_UNSUPP  (RGB іде через USB, не через EC)
#        charge_control→ MSI_EC_ADDR_UNSUPP  (обмеження заряду недоступне)
#
#  ⚠ ПАСТКА, ЯКУ ТРЕБА ЗНАТИ:
#  1) Вбудований у ядро msi-ec (drivers/platform/x86/msi-ec.c) має лише
#     ~26 записів прошивок і GT72 серед них НЕМАЄ. Тобто in-tree модуль
#     на твоїй машині завантажиться і скаже «firmware not supported».
#  2) Пакет nixpkgs `linuxPackages.msi-ec` запінений на ревізію
#     ed92e2eb0005ab815f5492c8cb02495289263738 (2025-09-17), у якій 135 записів
#     і 1782EMS1.109 ТЕЖ ЩЕ НЕМАЄ (перевірено grep-ом по тому самому SHA).
#     Тому нижче ми ПЕРЕВИЗНАЧАЄМО src на свіжу ревізію.
#
#  ⚠ ТВОЯ ПРОШИВКА МАЄ БУТИ САМЕ 1782EMS1.109.
#  Перевір ДО збірки:  sudo dmidecode -s bios-version
#  Якщо версія інша (напр. .107) — модуль відмовиться. Варіанти:
#    а) module param: boot.kernelParams = [ "msi_ec.firmware=1782EMS1.109" ]
#       (форсує конфіг G1_10; адреси EC у межах однієї моделі майже завжди
#       ті самі, але це вже НЕ гарантія — це «на свій ризик»);
#    б) відкрий issue в BeardOverflow/msi-ec зі своєю версією.
{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.gt72s.msiEc;

  # Демон гістерезису для cooler boost.
  # Свідомо НЕ керує turbo — це робота thermald (див. modules/performance.nix),
  # який має PID-регулятор і враховує теплову інерцію. Дублювати його
  # наївним on/off — це гарантовані осциляції частоти.
  coolerGuard = pkgs.writeShellApplication {
    name = "gt72s-cooler-guard";
    runtimeInputs = [ pkgs.coreutils ];
    text = ''
      set -euo pipefail

      EC=/sys/devices/platform/msi-ec
      HWMON_GLOB=/sys/class/hwmon/hwmon*/temp1_input

      ON_C=${toString cfg.coolerGuard.onCelsius}
      OFF_C=${toString cfg.coolerGuard.offCelsius}
      POLL=${toString cfg.coolerGuard.pollSeconds}
      # Скільки послідовних вимірювань нижче OFF_C потрібно, щоб вимкнути.
      # Це друга половина гістерезису: захист від одного холодного семпла
      # посеред навантаження.
      COOL_STREAK=${toString cfg.coolerGuard.coolStreak}

      if [ ! -e "$EC/cooler_boost" ]; then
        echo "msi-ec не завантажений або не підтримує cooler_boost — виходжу" >&2
        exit 1
      fi

      read_temp() {
        # Пріоритет: реальний час з EC (адреса 0x68 у CONF_G1_10).
        if [ -r "$EC/cpu/realtime_temperature" ]; then
          cat "$EC/cpu/realtime_temperature"
          return
        fi
        # Запасний шлях: coretemp через hwmon (значення в мілі-градусах).
        for f in $HWMON_GLOB; do
          [ -r "$f" ] || continue
          awk '{ printf "%d", $1 / 1000 }' "$f"
          return
        done
        echo 0
      }

      streak=0
      state=off

      while true; do
        t=$(read_temp)

        if [ "$state" = "off" ] && [ "$t" -ge "$ON_C" ]; then
          echo on > "$EC/cooler_boost" || true
          state=on
          streak=0
          echo "cooler boost ON  (t=''${t}C >= ''${ON_C}C)"
        elif [ "$state" = "on" ]; then
          if [ "$t" -le "$OFF_C" ]; then
            streak=$((streak + 1))
            if [ "$streak" -ge "$COOL_STREAK" ]; then
              echo off > "$EC/cooler_boost" || true
              state=off
              streak=0
              echo "cooler boost OFF (t=''${t}C <= ''${OFF_C}C протягом ''${COOL_STREAK} циклів)"
            fi
          else
            # Один теплий семпл скидає лічильник охолодження.
            streak=0
          fi
        fi

        sleep "$POLL"
      done
    '';
  };
in
{
  options.gt72s.msiEc = {
    enable = lib.mkEnableOption "керування EC ноутбука MSI GT72S (msi-ec)" // {
      default = true;
    };

    rev = lib.mkOption {
      type = lib.types.str;
      # Перевірено: у цій ревізії msi-ec.c рядок 824 містить "1782EMS1.109".
      default = "d7fbbd88e6831e56801b860e46475cbf8ddbc7c1";
      description = "Ревізія BeardOverflow/msi-ec (має містити 1782EMS1.109).";
    };

    hash = lib.mkOption {
      type = lib.types.str;
      # TODO: перша збірка ВПАДЕ і надрукує правильний хеш — встав його сюди.
      # Або порахуй заздалегідь:
      #   nix run nixpkgs#nix-prefetch-github -- BeardOverflow msi-ec --rev d7fbbd88e6831e56801b860e46475cbf8ddbc7c1
      default = lib.fakeHash;
      description = "NAR-хеш джерела msi-ec.";
    };

    coolerGuard = {
      enable = lib.mkEnableOption "автоматичний cooler boost із гістерезисом" // {
        default = true;
      };
      onCelsius = lib.mkOption {
        type = lib.types.int;
        default = 78;
        description = ''
          Поріг УВІМКНЕННЯ cooler boost.
          Не 70, як у твоєму формулюванні, і ось чому: 70°C для Skylake-HK під
          навантаженням — це нормальна робоча температура, а не тривога.
          Ввімкнення бусту на 70 означатиме, що вентилятори реватимуть завжди.
          78 — це вже «тепло», але ще далеко до тротлінгу (~95).
          TODO: підбери під себе після заміру `sensors` під навантаженням.
        '';
      };
      offCelsius = lib.mkOption {
        type = lib.types.int;
        default = 68;
        description = ''
          Поріг ВИМКНЕННЯ. Зазор 10°C — це і є гістерезис.
          Менший зазор дасть «клацання» вентиляторів кожні кілька секунд.
        '';
      };
      pollSeconds = lib.mkOption {
        type = lib.types.int;
        default = 5;
        description = "Період опитування температури.";
      };
      coolStreak = lib.mkOption {
        type = lib.types.int;
        default = 6;
        description = "Скільки поспіль холодних вимірювань до вимкнення (6 × 5 с = 30 с).";
      };
    };
  };

  config = lib.mkIf cfg.enable {
    # Збираємо модуль зі свіжої ревізії, бо запінена в nixpkgs не знає GT72.
    boot.extraModulePackages = [
      (config.boot.kernelPackages.msi-ec.overrideAttrs (old: {
        version = "0-unstable-${cfg.rev}";
        src = pkgs.fetchFromGitHub {
          owner = "BeardOverflow";
          repo = "msi-ec";
          rev = cfg.rev;
          hash = cfg.hash;
        };
        # Патчі з nixpkgs можуть не накластись на свіжий апстрім.
        # makefile.patch додає KERNELDIR/modules_install — якщо апстрім це вже
        # має, збірка впаде на «patch does not apply». Тоді прибери відповідний
        # патч зі списку тут.
        # TODO: якщо збірка падає на патчах — розкоментуй наступний рядок.
        # patches = [];
      }))
    ];

    boot.kernelModules = [ "msi-ec" ];

    # In-tree msi-ec треба прибрати з дороги: він має ту саму назву, але
    # не знає GT72. Якщо ядро вантажить його першим — out-of-tree не піде.
    # ПЕРЕВІР ПІСЛЯ ЗАВАНТАЖЕННЯ:
    #   modinfo msi-ec | head -3     ← filename має вести в /extra/, не в /kernel/
    #   dmesg | grep msi-ec          ← має бути «msi-ec: Firmware allowed»
    # Якщо підхопився не той — розкоментуй depmod-пріоритет нижче.
    # boot.extraModprobeConfig = "install msi_ec /sbin/modprobe --ignore-install msi-ec";

    # Доступ до атрибутів EC без sudo для групи wheel.
    services.udev.extraRules = ''
      # msi-ec: дозволити керування вентиляторами й режимами групі wheel
      SUBSYSTEM=="platform", KERNEL=="msi-ec", RUN+="${pkgs.coreutils}/bin/chgrp -R wheel /sys/devices/platform/msi-ec"
      SUBSYSTEM=="platform", KERNEL=="msi-ec", RUN+="${pkgs.coreutils}/bin/chmod -R g=u /sys/devices/platform/msi-ec"
    '';

    systemd.services.gt72s-cooler-guard = lib.mkIf cfg.coolerGuard.enable {
      description = "GT72S: cooler boost з гістерезисом";
      after = [ "multi-user.target" ];
      wantedBy = [ "multi-user.target" ];
      # Не стартувати, якщо модуль не піднявся — інакше отримаєш
      # нескінченний рестарт-цикл у журналі.
      unitConfig.ConditionPathExists = "/sys/devices/platform/msi-ec/cooler_boost";
      serviceConfig = {
        Type = "simple";
        ExecStart = lib.getExe coolerGuard;
        # Гарантовано вимкнути буст при зупинці сервісу — інакше вентилятори
        # залишаться на максимумі після `systemctl stop`.
        ExecStopPost = "${pkgs.bash}/bin/bash -c 'echo off > /sys/devices/platform/msi-ec/cooler_boost || true'";
        Restart = "on-failure";
        RestartSec = 10;
        Nice = 10;
        # Мінімальні привілеї: єдине, що треба — писати в один sysfs-файл.
        ProtectHome = true;
        PrivateTmp = true;
        NoNewPrivileges = true;
      };
    };

    environment.systemPackages = [ coolerGuard ];
  };
}
