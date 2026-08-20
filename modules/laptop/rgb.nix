# ── RGB-підсвітка GT72S, синхронізована з палітрою matugen ────────────────────
#
# ЩО РЕАЛЬНО ПІДТРИМУЄТЬСЯ (перевірено за вихідниками, не за форумами):
#
#  • Клавіатура GT72S — SteelSeries, USB HID 1770:ff00. Керується MSIKLM.
#    Зони з src/msiklm.h (enum region):
#      left=1, middle=2, right=3, logo=4, front_left=5, front_right=6, mouse=7
#    Тобто 3 зони клавіатури + 2 передні («light bar») — саме твоя конфігурація.
#
#  • Через EC це НЕ керується: msi-ec для конфігу CONF_G1_10 (твоя прошивка
#    1782EMS1.109) явно позначає kbd_bl.bl_state_address = MSI_EC_ADDR_UNSUPP
#    з коментарем «RGB». Тобто USB — єдиний шлях.
#
#  ⚠ ЧЕСНО ПРО НЕВИЗНАЧЕНІСТЬ:
#  Я НЕ можу підтвердити з вихідників, що саме твоя GT72S 6QE має фізичні
#  зони front_left/front_right. MSIKLM підтримує «до семи зон, наскільки
#  їх підтримує пристрій» — тобто він надішле команду, а прошивка або
#  застосує її, або мовчки проігнорує.
#  ПЕРЕВІР НА МАШИНІ (це займе хвилину):
#      lsusb | grep -i 1770            # має бути 1770:ff00
#      sudo msiklm test                # має сказати, що клавіатуру знайдено
#      sudo msiklm "[255;0;0],[0;255;0],[0;0;255],[0;0;0],[255;0;255],[0;255;255]" high normal
#  Якщо передні зони засвітились — усе працює. Якщо ні — постав
#  gt72s.rgb.zones = 3 нижче, і модуль перестане їх чіпати.
{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.gt72s.rgb;

  # Застосовує палітру до підсвітки.
  # Кольори читає з файлу, який генерує matugen (див. home/theme.nix,
  # шаблон rgb-colors). Формат файлу — прості KEY=RRGGBB рядки.
  applyRgb = pkgs.writeShellApplication {
    name = "gt72s-rgb-apply";
    runtimeInputs = [
      pkgs.msiklm
      pkgs.coreutils
      pkgs.gnused
    ];
    text = ''
      set -euo pipefail

      PALETTE="''${1:-${cfg.paletteFile}}"

      if [ ! -r "$PALETTE" ]; then
        echo "Палітра $PALETTE не знайдена — нічого не роблю" >&2
        exit 0
      fi

      # shellcheck disable=SC1090
      . "$PALETTE"

      # hex «RRGGBB» → «R;G;B» у форматі, який чекає msiklm.
      hex2rgb() {
        local h="''${1#\#}"
        printf '[%d;%d;%d]' "0x''${h:0:2}" "0x''${h:2:2}" "0x''${h:4:2}"
      }

      KB_L=$(hex2rgb "''${RGB_KB_LEFT:-202020}")
      KB_M=$(hex2rgb "''${RGB_KB_MIDDLE:-202020}")
      KB_R=$(hex2rgb "''${RGB_KB_RIGHT:-202020}")
      LOGO=$(hex2rgb "''${RGB_LOGO:-000000}")
      FR_L=$(hex2rgb "''${RGB_BAR_LEFT:-202020}")
      FR_R=$(hex2rgb "''${RGB_BAR_RIGHT:-202020}")

      ${
        if cfg.zones >= 6 then
          ''ARGS="$KB_L,$KB_M,$KB_R,$LOGO,$FR_L,$FR_R"''
        else
          ''ARGS="$KB_L,$KB_M,$KB_R"''
      }

      # Режим normal = статичний. Свідомо не breathe/wave: анімація підсвітки
      # це постійні USB-транзакції і зайве пробудження контролера.
      msiklm "$ARGS" ${cfg.brightness} normal
    '';
  };
in
{
  options.gt72s.rgb = {
    enable = lib.mkEnableOption "синхронізація RGB-підсвітки з палітрою matugen";

    zones = lib.mkOption {
      type = lib.types.enum [
        3
        6
      ];
      default = 6;
      description = ''
        6 = 3 зони клавіатури + logo + 2 передні зони.
        3 = тільки клавіатура (постав, якщо передні зони не реагують).
      '';
    };

    brightness = lib.mkOption {
      type = lib.types.enum [
        "off"
        "low"
        "medium"
        "high"
      ];
      default = "medium";
      description = "Яскравість підсвітки (enum brightness з msiklm.h).";
    };

    paletteFile = lib.mkOption {
      # types.str, а НЕ types.path: path змусив би Nix трактувати значення
      # як шлях у сторі, а нам потрібен саме рантайм-шлях у /var/lib,
      # якого на момент обчислення конфігу ще не існує.
      type = lib.types.str;
      default = "/var/lib/moewall/rgb-colors.sh";
      description = ''
        Файл із кольорами, який генерує matugen.
        Лежить у /var/lib, а не в ~/.config, бо системний сервіс
        (який має право на USB HID) не має читати домашню директорію.
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    # Джерело msiklm ще не має справжнього NAR-хешу (див. pkgs/msiklm/default.nix).
    # Зупиняємо збірку тут, зрозумілим текстом, замість того щоб дати їй впасти
    # на «hash mismatch» уже під час завантаження джерел.
    #
    # Принцип, який це захищає: RGB-підсвітка НЕ МАЄ ПРАВА ламати завантаження
    # системи. Поки хеш невідомий — фіча просто недоступна.
    assertions = [
      {
        assertion = pkgs.msiklm.src.outputHash or "" != lib.fakeHash;
        message = ''
          gt72s.rgb.enable = true, але джерело msiklm ще з lib.fakeHash.

          Порахуй хеш і встав його у pkgs/msiklm/default.nix:
              nix run nixpkgs#nix-prefetch-github -- \
                Gibtnix MSIKLM --rev e9a75942d85612869e32f14d4ec0e6ad5b4514ed

          Або просто запусти ./bootstrap.sh — він робить це автоматично.
        '';
      }
    ];

    environment.systemPackages = [
      pkgs.msiklm
      applyRgb
    ];

    # udev-правило: дати групі wheel доступ до HID-пристрою клавіатури,
    # щоб msiklm працював без sudo.
    # 1770:ff00 — VID/PID SteelSeries-клавіатур MSI.
    services.udev.extraRules = ''
      # MSI SteelSeries keyboard backlight
      SUBSYSTEM=="usb", ATTRS{idVendor}=="1770", ATTRS{idProduct}=="ff00", MODE="0660", GROUP="wheel"
      SUBSYSTEM=="hidraw", ATTRS{idVendor}=="1770", ATTRS{idProduct}=="ff00", MODE="0660", GROUP="wheel"
    '';

    # Сервіс, який застосовує палітру. Запускається:
    #   • при завантаженні (щоб підсвітка збігалася зі шпалерою після ребуту);
    #   • після виходу зі сну (EC скидає підсвітку в дефолт);
    #   • за сигналом від moewall, коли змінилась шпалера.
    systemd.services.gt72s-rgb = {
      description = "GT72S: застосувати палітру до RGB-підсвітки";
      wantedBy = [ "multi-user.target" ];
      after = [
        "multi-user.target"
        "moewall.service"
      ];
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
        ExecStart = lib.getExe applyRgb;
        # Якщо палітри ще немає (перший запуск до першої шпалери) — не падати.
        SuccessExitStatus = [
          0
          1
        ];
      };
    };

    # Після пробудження EC скидає підсвітку — застосовуємо повторно.
    systemd.services.gt72s-rgb-resume = {
      description = "GT72S: відновити RGB після сну";
      wantedBy = [ "post-resume.target" ];
      after = [ "post-resume.target" ];
      serviceConfig = {
        Type = "oneshot";
        ExecStart = lib.getExe applyRgb;
      };
    };

    # ── FALLBACK, ЯКЩО ПРЯМЕ КЕРУВАННЯ НЕ ЗАПРАЦЮЄ ────────────────────────────
    # Якщо `msiklm test` не бачить пристрій (інша ревізія клавіатури,
    # інший VID/PID), варіанти в порядку спадання надійності:
    #
    #  1. OpenRGB (pkgs.openrgb). Має плагін під MSI SteelSeries, але
    #     підтримка саме GT-серії неповна. Плюс: у нього є SDK-сервер,
    #     тобто кольори можна слати по TCP замість запуску бінарника.
    #     Мінус: тримає демон у пам'яті і вимагає i2c-dev для інших пристроїв.
    #
    #  2. Форк E1DIGITALPF/OpenRGB-msi-steelseries — саме під цю клавіатуру,
    #     але це форк без релізів; пакувати доведеться так само вручну.
    #
    #  3. Нічого. Підсвітка лишається на тому, що виставив BIOS.
    #     Система від цього НЕ ламається: сервіси вище мовчки виходять,
    #     якщо пристрою немає, і нічого не тягнуть за собою.
    #
    # Саме тому цей модуль ізольований і вимикається одним `enable = false`.
  };
}
