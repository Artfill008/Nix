# ── 75 Гц на вбудованій матриці ───────────────────────────────────────────────
#
# СТАТУС: ЕКСПЕРИМЕНТАЛЬНО. Не вмикається за замовчуванням.
#
# ЩО ВСТАНОВЛЕНО ТОЧНО:
#
#  • `drm.edid_firmware=` (і, відповідно, модуль NixOS hardware.display.edid.*,
#    який його генерує) пропрієтарним драйвером NVIDIA НЕ ВРАХОВУЄТЬСЯ.
#    Цей механізм реалізований у DRM-ядрі функцією drm_edid_load(), яку
#    nvidia-drm не викликає — він будує пул режимів зі свого власного
#    читання EDID. Це підтверджено кількома звітами на forums.developer.nvidia.com
#    і на bbs.archlinux.org: файл кладеться, initrd його бачить, драйвер ігнорує.
#
#  • Що ПРАЦЮЄ: запис EDID напряму в debugfs ПІСЛЯ завантаження:
#        /sys/kernel/debug/dri/0/<connector>/edid_override
#    Після цього драйвер переперевіряє конектор і бачить нові режими.
#    Саме на цьому побудований модуль нижче.
#
#  • Побічний ефект, задокументований NVIDIA (внутрішній баг 4797139):
#    при активному edid_override вимикається VRR. Для вбудованої матриці
#    GT72S це не втрата — VRR там немає.
#
#  • Чому це БЕЗПЕЧНО спробувати: запис відбувається вже в працюючій системі,
#    а не в initrd. Поганий EDID не завадить завантаженню — у гіршому випадку
#    отримаєш чорний екран у сесії, і лікується це вимкненням сервісу з TTY
#    або перезавантаженням у попереднє покоління.
#
# ЧОГО Я НЕ ЗНАЮ І НЕ ВДАВАТИМУ, ЩО ЗНАЮ:
#
#  • Чи ТВОЯ матриця реально тримає 75 Гц. Те, що Windows їх показує,
#    вагомий аргумент, але Windows-драйвер NVIDIA приймає режими,
#    яких Linux-драйвер не приймає, і навпаки.
#  • Чи не з'явиться tearing/мерехтіння на 75 Гц — це залежить від
#    конкретної панелі та її LVDS/eDP-таймінгів.
#  • Чи прийме pixel clock сам драйвер: у нього є власна валідація,
#    і на Linux немає еквівалента `ModeValidation "AllowNonEdidModes"`
#    для Wayland (ця опція існує ТІЛЬКИ в xorg.conf).
#    Саме тому підміна EDID — єдиний шлях: ми не «просимо нестандартний
#    режим», ми переконуємо драйвер, що цей режим стандартний.
#
# ─────────────────────────────────────────────────────────────────────────────
# ПРОЦЕДУРА (роби по кроках, не пропускай):
#
#  1. Дізнайся назву конектора і поточні режими:
#       ls /sys/class/drm/                    # шукай щось на кшталт card1-eDP-1
#       wlr-randr                             # у сесії mango
#     TODO: підстав знайдену назву в gt72s.panel75.connector.
#
#  2. Збережи РІДНИЙ EDID (це твоя точка відкату):
#       sudo cat /sys/class/drm/card1-eDP-1/edid > ~/panel-original.bin
#       nix run nixpkgs#edid-decode -- ~/panel-original.bin
#     Подивись на секцію «Detailed Timing Descriptor» і на межі
#     «Maximum Pixel Clock». Якщо запас по pixel clock менший, ніж треба
#     для 75 Гц — далі можна не йти.
#
#  3. Порахуй таймінг для 75 Гц (CVT-R, зменшений blanking — менше pixel clock):
#       nix run nixpkgs#libsForQt5.libkscreen -- # не те
#       # простіше:
#       cvt -r 1920 1080 75
#     Отримаєш Modeline. Для 1920x1080@75 CVT-R це приблизно 173 МГц —
#     проти ~139 МГц для 60 Гц. Порівняй з максимумом із кроку 2.
#
#  4. Збери новий EDID. Два шляхи:
#       а) pkgs.edid-generator — приймає Modeline і будує EDID з нуля.
#          Мінус: втрачаються ідентифікатор панелі й дані про підсвітку.
#       б) wxEDID / вручну — відредагувати РІДНИЙ EDID, замінивши перший
#          Detailed Timing на 75-герцовий і перерахувавши контрольну суму.
#          Це правильніший шлях, бо решта дескрипторів лишається.
#     TODO: поклади готовий файл і вкажи шлях у gt72s.panel75.edidFile.
#
#  5. Увімкни модуль, зроби rebuild, перевір:
#       systemctl status gt72s-panel-edid
#       wlr-randr                # має з'явитись режим 1920x1080@75
#     І лише тоді додай у mango monitorrule з refresh:75 (див. home/mango.nix).
{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.gt72s.panel75;
in
{
  options.gt72s.panel75 = {
    enable = lib.mkEnableOption ''
      підміну EDID вбудованої матриці для 75 Гц (ЕКСПЕРИМЕНТАЛЬНО).
      Прочитай коментар на початку modules/laptop/panel-75hz.nix ПЕРЕД увімкненням.
    '';

    connector = lib.mkOption {
      type = lib.types.str;
      default = "eDP-1";
      example = "eDP-1";
      description = ''
        Назва конектора так, як вона виглядає у /sys/kernel/debug/dri/0/.
        Зверни увагу: у debugfs імена БЕЗ префікса «cardN-»,
        тобто "eDP-1", а не "card1-eDP-1".
        TODO: перевір `sudo ls /sys/kernel/debug/dri/0/`.
      '';
    };

    edidFile = lib.mkOption {
      type = lib.types.nullOr lib.types.path;
      default = null;
      example = lib.literalExpression "./edid/panel-75hz.bin";
      description = ''
        Двійковий EDID (128 або 256 байт) із доданим 75-герцовим таймінгом.
        TODO: створи за процедурою в коментарі вгорі файлу.
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = cfg.edidFile != null;
        message = "gt72s.panel75.enable = true, але gt72s.panel75.edidFile не заданий.";
      }
    ];

    # debugfs має бути змонтований — на NixOS він монтується за замовчуванням,
    # але сервіс нижче цього не припускає і перевіряє явно.
    systemd.services.gt72s-panel-edid = {
      description = "GT72S: підміна EDID матриці для 75 Гц";
      # Пізно в завантаженні: nvidia-drm має вже ініціалізувати конектори.
      after = [
        "systemd-modules-load.service"
        "multi-user.target"
      ];
      wantedBy = [ "multi-user.target" ];
      # Не запускатись до входу в сесію — інакше можна отримати чорний екран
      # ще до появи greetd, і лікувати доведеться з іншого TTY.
      before = [ "greetd.service" ];

      unitConfig = {
        ConditionPathIsMountPoint = "/sys/kernel/debug";
      };

      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
      };

      script = ''
        set -euo pipefail
        DRI=/sys/kernel/debug/dri

        # Знаходимо картку, у якої є потрібний конектор (їх може бути кілька).
        target=""
        for card in "$DRI"/*; do
          if [ -d "$card/${cfg.connector}" ]; then
            target="$card/${cfg.connector}"
            break
          fi
        done

        if [ -z "$target" ]; then
          echo "Конектор ${cfg.connector} не знайдено у $DRI — перевір назву." >&2
          echo "Доступні:" >&2
          ls -1 "$DRI"/*/ >&2 || true
          exit 1
        fi

        if [ ! -w "$target/edid_override" ]; then
          echo "edid_override недоступний для запису — драйвер його не експортує." >&2
          exit 1
        fi

        cat ${cfg.edidFile} > "$target/edid_override"
        echo "EDID підмінено для ${cfg.connector}"

        # Змусити драйвер перечитати конектор.
        if [ -w "$target/force" ]; then
          echo on > "$target/force" || true
        fi
      '';

      # Відкат при зупинці сервісу: повернути рідний EDID.
      preStop = ''
        DRI=/sys/kernel/debug/dri
        for card in "$DRI"/*; do
          if [ -w "$card/${cfg.connector}/edid_override" ]; then
            echo reset > "$card/${cfg.connector}/edid_override" || true
          fi
        done
      '';
    };

    environment.systemPackages = with pkgs; [
      read-edid # get-edid / parse-edid
      edid-generator # якщо підеш шляхом 4а
      wlr-randr # перевірити, які режими бачить композитор
    ];

    # ── АЛЬТЕРНАТИВА, ЯКА ТУТ НЕ ПРАЦЮЄ (лишаю, щоб ти не витрачав час) ────────
    # NixOS має гарний декларативний модуль:
    #     hardware.display.edid.modelines."PANEL_75" = "173.00 1920 ...";
    #     hardware.display.outputs."eDP-1".edid = "PANEL_75.bin";
    # Він збирає EDID через pkgs.edid-generator і додає
    #     drm.edid_firmware=eDP-1:edid/PANEL_75.bin
    # у kernelParams. Це ІДЕАЛЬНИЙ шлях — для amdgpu, i915 і nouveau.
    # Для пропрієтарного nvidia він не робить нічого (див. пояснення вгорі).
    # Якщо колись перейдеш на nouveau/NVK — переходь на цей модуль,
    # він набагато чистіший за запис у debugfs.
  };
}
