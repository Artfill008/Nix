# ── ТЕМА ──────────────────────────────────────────────────────────────────────
#
# Естетика: colorful brutalism + subtle noise + sharp geometry + slight rounding
#           + expressive contrast, кольори — динамічні, з поточної шпалери.
#
# ЯК ЦЕ ПРАЦЮЄ, ОДНИМ АБЗАЦОМ:
#   moewall обирає шпалеру → викликає matugen → matugen бере зображення,
#   витягає домінантний колір і будує з нього повну палітру Material You
#   (16+ ролей: primary, surface, outline...) → підставляє її в шаблони
#   з home/matugen-templates/ → пише готові конфіги в ~/.config →
#   moewall перезавантажує споживачів (waybar, mako, mango, підсвітка).
#
# ЩО СТАТИЧНЕ, А ЩО ДИНАМІЧНЕ:
#   статичне  — геометрія (рамки, відступи, радіуси), шрифти, іконки, курсор;
#   динамічне — ТІЛЬКИ кольори.
#   Це принципово: якщо міняти й геометрію, кожна нова шпалера
#   перебудовуватиме інтерфейс, і ти ніколи не звикнеш до розташування.
#
# ══════════════════════════════════════════════════════════════════════════════
#  ЩОДО STYLIX: НЕ БЕРЕМО. Обґрунтування (це близьке рішення, не очевидне):
#
#  ЗА Stylix:
#    • покриття, якого руками не досягти: він тематизує GTK2/3/4, Qt5/Qt6,
#      kvantum, vim/helix, foot, mako, fuzzel, grub, plymouth — усе одразу;
#    • уміє генерувати схему ЗІ шпалери (stylix.image + polarity), тобто
#      формально закриває ту саму задачу, що й matugen.
#
#  ПРОТИ Stylix (і чому це переважило):
#    1. Stylix — це base16: рівно 16 кольорів. Material You — це 16+ РОЛЕЙ
#       (primary / on_primary / primary_container / surface_container_high...),
#       де кожна має задану контрастність до своєї пари. Саме ролі дають
#       «expressive contrast», який ти просиш. base16 такого поняття не має.
#    2. Stylix перезаписує конфіги, які ми хочемо тримати руками. Брутальний
#       CSS waybar — це не «тема», це макет: товщина рамок, гострі кути,
#       розміри. Stylix у нього втрутиться, і почнеться боротьба з mkForce.
#    3. Stylix застосовується під час rebuild. Наша палітра має мінятись
#       у РАНТАЙМІ, коли змінюється шпалера — без nixos-rebuild.
#       Це фундаментальна несумісність, а не незручність.
#
#  ЩО МИ ЧЕРЕЗ ЦЕ ВТРАЧАЄМО (чесно):
#    Qt-програми (virt-manager частково, qalculate-gtk — ні, він GTK)
#    і GTK-програми лишаться на статичній темі, а не на динамічній палітрі.
#    Нижче є ручний місток для GTK; для Qt його немає.
#    Якщо колись Qt-програм стане багато — Stylix варто буде переглянути.
# ══════════════════════════════════════════════════════════════════════════════
{
  config,
  lib,
  pkgs,
  ...
}:
let
  home = config.home.homeDirectory;
  tpl = ./matugen-templates;
in
{
  # ── matugen ─────────────────────────────────────────────────────────────────
  # Конфіг matugen керується home-manager (він статичний), а ВИХІДНІ файли —
  # ні: вони мають бути звичайними файлами, придатними до запису.
  xdg.configFile."matugen/config.toml".text = ''
    # ЗГЕНЕРОВАНО з home/theme.nix.
    #
    # TODO ПЕРЕД ПЕРШИМ ЗАПУСКОМ: звір назви змінних у шаблонах зі своєю
    # версією matugen:
    #     matugen image /шлях/до/картинки --show-colors
    # Синтаксис {{colors.<роль>.<режим>.hex}} стабільний з matugen 2.x,
    # але набір ролей між версіями трохи різниться. Якщо якийсь шаблон
    # відрендериться з порожнім місцем — винна саме назва ролі.

    [config]
    # Не намагатись самому перезапускати програми — це робить moewall,
    # і робить це точніше (він знає, що саме змінилось).
    reload_apps = false

    [templates.mango]
    input_path  = "${tpl}/mango-colors.conf"
    output_path = "${home}/.config/mango/colors.conf"

    [templates.waybar]
    input_path  = "${tpl}/waybar-colors.css"
    output_path = "${home}/.config/waybar/colors.css"

    [templates.foot]
    input_path  = "${tpl}/foot-colors.ini"
    output_path = "${home}/.config/foot/colors.ini"

    [templates.mako]
    input_path  = "${tpl}/mako-config"
    output_path = "${home}/.config/mako/config"

    [templates.fuzzel]
    input_path  = "${tpl}/fuzzel.ini"
    output_path = "${home}/.config/fuzzel/fuzzel.ini"

    [templates.fish]
    input_path  = "${tpl}/fish-colors.fish"
    output_path = "${home}/.config/fish/conf.d/matugen-colors.fish"

    [templates.rgb]
    input_path  = "${tpl}/rgb-colors.sh"
    # У /var/lib, а не в ~/.config: цей файл читає СИСТЕМНИЙ сервіс
    # gt72s-rgb, який не має права лізти в домашню директорію.
    output_path = "/var/lib/moewall/rgb-colors.sh"
  '';

  # ── Засівання файлів, якими володіє matugen ─────────────────────────────────
  # Створюємо їх ОДИН РАЗ як звичайні файли, якщо їх ще немає.
  # Без цього при першому вході foot спіткнеться на include=, а waybar —
  # на @import неіснуючого colors.css.
  home.activation.seedThemeFiles = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    seed() {
      target="$1"; content="$2"
      if [ ! -e "$target" ]; then
        $DRY_RUN_CMD mkdir -p "$(dirname "$target")"
        $DRY_RUN_CMD cp --no-preserve=mode "$content" "$target"
      fi
    }

    # Запасні кольори до першого запуску matugen: нейтральний темний
    # із блакитним акцентом. Це те, що ти побачиш рівно один раз.
    seed "${home}/.config/foot/colors.ini"   ${pkgs.writeText "foot-seed" ''
      [colors]
      background=0d0d10
      foreground=e6e6ea
      regular0=1a1a20
      regular1=ff5f5f
      regular2=5fd7af
      regular3=ffd75f
      regular4=7fd1ff
      regular5=af87ff
      regular6=5fd7d7
      regular7=e6e6ea
      bright0=3a3a44
      bright1=ff8787
      bright2=87ffd7
      bright3=ffe787
      bright4=afe7ff
      bright5=d7afff
      bright6=87ffff
      bright7=ffffff
    ''}

    seed "${home}/.config/waybar/colors.css" ${pkgs.writeText "waybar-seed" ''
      @define-color bg        #0d0d10;
      @define-color bg_alt    #16161c;
      @define-color fg        #e6e6ea;
      @define-color fg_dim    #9a9aa6;
      @define-color accent    #7fd1ff;
      @define-color accent_fg #001b2b;
      @define-color accent2   #af87ff;
      @define-color accent3   #5fd7af;
      @define-color warn      #ff5f5f;
      @define-color outline   #3a3a44;
    ''}

    seed "${home}/.config/mango/colors.conf" ${pkgs.writeText "mango-seed" ''
      focuscolor=0x7fd1ffff
      bordercolor=0x2a2a32ff
    ''}
  '';

  # ── Waybar ──────────────────────────────────────────────────────────────────
  programs.waybar = {
    enable = true;
    # Запускається з autostart.sh (див. home/mango.nix), а не systemd-сервісом:
    # waybar має стартувати ПІСЛЯ того, як композитор створив виходи.
    systemd.enable = false;

    settings.main = {
      layer = "top";
      position = "top";
      height = 30;
      spacing = 0;

      modules-left = [
        "custom/logo"
        "wlr/taskbar"
      ];
      modules-center = [ "clock" ];
      modules-right = [
        "tray"
        "pulseaudio"
        "backlight"
        "cpu"
        "memory"
        "temperature"
        "custom/gpu"
        "network"
        "bluetooth"
        "battery"
      ];

      "custom/logo" = {
        format = "◤ NIX ";
        tooltip = false;
      };

      "wlr/taskbar" = {
        format = "{icon}";
        icon-size = 16;
        on-click = "activate";
        on-click-middle = "close";
        tooltip-format = "{title}";
      };

      clock = {
        # Брутальний формат: без крапок, моноширинний, доба 24 год.
        format = "{:%H:%M  %d.%m}";
        format-alt = "{:%A, %d %B %Y}";
        tooltip-format = "<tt><small>{calendar}</small></tt>";
        calendar = {
          mode = "month";
          weeks-pos = "right";
          format = {
            months = "<span color='#ffffff'><b>{}</b></span>";
            today = "<span color='#7fd1ff'><b>{}</b></span>";
          };
        };
      };

      cpu = {
        format = "CPU {usage:>3}%";
        interval = 3;
        on-click = "foot -e btop";
      };

      memory = {
        # Показуємо і RAM, і zram-своп: при swappiness=180 своп
        # використовується активно, і це нормально — але треба бачити скільки.
        format = "RAM {percentage:>3}%";
        tooltip-format = "{used:0.1f}G / {total:0.1f}G\nSwap: {swapUsed:0.1f}G / {swapTotal:0.1f}G";
        interval = 5;
      };

      temperature = {
        # TODO: перевір шлях. Знайти можна так:
        #   for f in /sys/class/hwmon/hwmon*/name; do echo "$f: $(cat $f)"; done
        # Потрібен той hwmon, у якого name == "coretemp".
        hwmon-path-abs = "/sys/devices/platform/coretemp.0/hwmon";
        input-filename = "temp1_input";
        critical-threshold = 85;
        format = "CPU {temperatureC}°";
        format-critical = "CPU {temperatureC}° !";
        interval = 5;
      };

      "custom/gpu" = {
        # nvidia-smi йде разом із драйвером.
        exec = "${config.home.homeDirectory}/.local/bin/waybar-gpu";
        interval = 5;
        format = "{}";
        tooltip = false;
      };

      network = {
        format-wifi = "WIFI {signalStrength}%";
        format-ethernet = "ETH";
        format-disconnected = "NET --";
        tooltip-format-wifi = "{essid}\n{ipaddr}\n↓{bandwidthDownBytes} ↑{bandwidthUpBytes}";
        on-click = "foot -e nmtui";
      };

      bluetooth = {
        format = "BT {status}";
        format-disabled = "";
        format-connected = "BT {num_connections}";
        tooltip-format = "{device_alias}";
        on-click = "blueman-manager";
      };

      pulseaudio = {
        format = "VOL {volume:>3}%";
        format-muted = "VOL ---";
        format-bluetooth = "BT {volume:>3}%";
        on-click = "pwvucontrol";
        on-click-right = "wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle";
        scroll-step = 5;
      };

      backlight = {
        format = "LUM {percent:>3}%";
        on-scroll-up = "brightnessctl set 5%+";
        on-scroll-down = "brightnessctl set 5%-";
      };

      battery = {
        states = {
          warning = 25;
          critical = 10;
        };
        format = "BAT {capacity:>3}%";
        format-charging = "CHG {capacity:>3}%";
        format-plugged = "AC";
        tooltip-format = "{timeTo}\n{power:0.1f}W";
      };

      tray = {
        icon-size = 16;
        spacing = 8;
      };
    };

    # ── CSS: брутальна геометрія ────────────────────────────────────────────
    # Кольори приходять із @import — файлу, який пише matugen.
    # Шлях АБСОЛЮТНИЙ свідомо: цей style.css живе в /nix/store, і відносний
    # @import шукав би colors.css там же, а не в ~/.config.
    style = ''
      @import url("file://${home}/.config/waybar/colors.css");

      * {
        border: none;
        border-radius: 0;                    /* гостра геометрія */
        font-family: "JetBrainsMono Nerd Font", monospace;
        font-size: 12px;
        font-weight: 700;                    /* виразний контраст */
        min-height: 0;
      }

      window#waybar {
        background: @bg;
        color: @fg;
        /* Товста нижня межа замість тіні — тіні заборонені. */
        border-bottom: 2px solid @outline;
      }

      /* Кожен модуль — окремий блок із власною межею.
         Це і є «brutalism»: структура видима, нічого не зливається. */
      #clock,
      #cpu, #memory, #temperature, #custom-gpu,
      #network, #bluetooth, #pulseaudio, #backlight, #battery,
      #tray, #custom-logo {
        padding: 0 10px;
        margin: 0;
        background: @bg;
        color: @fg_dim;
        border-left: 2px solid @outline;
      }

      #custom-logo {
        background: @accent;
        color: @accent_fg;
        border-left: none;
        padding: 0 14px;
      }

      #clock {
        background: @bg_alt;
        color: @fg;
        border-left: 2px solid @outline;
        border-right: 2px solid @outline;
        padding: 0 16px;
      }

      /* Акценти на тих модулях, які показують стан системи. */
      #cpu       { color: @accent; }
      #memory    { color: @accent2; }
      #custom-gpu{ color: @accent3; }
      #backlight { color: @fg_dim; }

      #temperature.critical,
      #battery.critical {
        background: @warn;
        color: @bg;
      }

      #battery.charging { color: @accent3; }
      #battery.warning:not(.charging) { color: @accent3; }

      #pulseaudio.muted { color: @outline; }

      /* Панель задач: активне вікно підкреслене акцентом. */
      #taskbar button {
        padding: 0 8px;
        background: transparent;
        border-bottom: 3px solid transparent;
      }
      #taskbar button.active {
        border-bottom: 3px solid @accent;
        background: @bg_alt;
      }
      #taskbar button:hover {
        background: @bg_alt;
        border-bottom: 3px solid @accent2;
      }

      tooltip {
        background: @bg_alt;
        border: 2px solid @accent;
        color: @fg;
      }
    '';
  };

  # Маленький помічник для модуля GPU у барі.
  # Окремий файл, бо вбудовувати shell-конвеєр у JSON waybar — рецепт болю.
  home.file.".local/bin/waybar-gpu" = {
    executable = true;
    text = ''
      #!${pkgs.bash}/bin/bash
      # Виводить «GPU NN% / NNNN MiB». Якщо nvidia-smi немає — мовчить.
      if ! command -v nvidia-smi >/dev/null 2>&1; then
        echo ""
        exit 0
      fi
      read -r util mem < <(nvidia-smi \
        --query-gpu=utilization.gpu,memory.used \
        --format=csv,noheader,nounits | tr -d ',')
      printf 'GPU %3s%% %sM\n' "$util" "$mem"
    '';
  };

  # ── swaylock ────────────────────────────────────────────────────────────────
  programs.swaylock = {
    enable = true;
    settings = {
      # Показуємо шпалеру, а не суцільний колір: це те саме зображення,
      # тобто нуль додаткової пам'яті на декодування чогось нового.
      image = "/var/lib/moewall/current.png";
      scaling = "fill";

      # Індикатор: товсте кільце, гострі кольори, без розмиття.
      indicator = true;
      indicator-radius = 90;
      indicator-thickness = 10;
      indicator-caps-lock = true;

      ring-color = "3a3a44";
      ring-ver-color = "7fd1ff";
      ring-wrong-color = "ff5f5f";
      ring-clear-color = "af87ff";
      key-hl-color = "7fd1ff";
      bs-hl-color = "ff5f5f";

      inside-color = "0d0d10cc";
      inside-ver-color = "0d0d10cc";
      inside-wrong-color = "0d0d10cc";
      inside-clear-color = "0d0d10cc";

      text-color = "e6e6ea";
      text-ver-color = "7fd1ff";
      text-wrong-color = "ff5f5f";

      line-uses-inside = true;
      font = "Inter";
      font-size = 20;

      # Показувати спробу вводу — без цього незрозуміло, чи клавіатура жива.
      show-failed-attempts = true;
      # НЕ ставимо ignore-empty-password: порожній Enter має давати помилку,
      # а не тихо нічого не робити.
    };
  };

  # ── GTK ─────────────────────────────────────────────────────────────────────
  # Місток між статичною темою і динамічною палітрою.
  # ЧЕСНО: це саме місток, а не повноцінна динамічна тема. GTK-програми
  # отримають темну базу + нашу іконку/курсор, але їхні акценти
  # не мінятимуться зі шпалерою. Зробити інакше можна лише генеруючи
  # повну GTK-тему на кожну зміну шпалери — це секунди роботи і сотні
  # мегабайтів у сторі. Не варте того.
  gtk = {
    enable = true;
    theme = {
      package = pkgs.gnome-themes-extra;
      name = "Adwaita-dark";
    };
    iconTheme = {
      package = pkgs.papirus-icon-theme;
      name = "Papirus-Dark";
    };
    font = {
      package = pkgs.inter;
      name = "Inter";
      size = 11;
    };
    gtk3.extraConfig = {
      gtk-application-prefer-dark-theme = 1;
      # Прибираємо анімації GTK — узгоджено з вимкненими анімаціями композитора.
      gtk-enable-animations = 0;
    };
    gtk4.extraConfig = {
      gtk-application-prefer-dark-theme = 1;
    };
  };

  # ── Курсор ──────────────────────────────────────────────────────────────────
  # Bibata-Modern-Ice: гострий, високий контраст, добре видно на темному.
  # Програв Adwaita: нейтральний, але розчиняється на темному тлі.
  # Програв Catppuccin-cursors: гарний, але заокруглений — б'ється з естетикою.
  home.pointerCursor = {
    package = pkgs.bibata-cursors;
    name = "Bibata-Modern-Ice";
    size = 24;
    gtk.enable = true;
    # Обов'язково: без цього XWayland-програми покажуть курсор «хрестик».
    x11.enable = true;
  };

  # ── Qt ──────────────────────────────────────────────────────────────────────
  # Мінімум, щоб Qt-програми (virt-manager тягне трохи Qt через spice)
  # не виглядали як з 2005 року.
  qt = {
    enable = true;
    # ПЕРЕВІРЕНО за modules/misc/qt/default.nix home-manager: значення
    # platformTheme.name — це enum із конкретним переліком ("adwaita",
    # "gtk2", "qtstyleplugins", "kvantum", "lxqt", "gnome"...).
    # Значення "gtk" там НЕМАЄ — не вгадуй.
    # adwaita + adwaita-dark дає Qt-програмам вигляд, найближчий до нашої
    # GTK-теми Adwaita-dark. Це не динамічна палітра, і я про це чесно
    # написав у шапці файлу.
    platformTheme.name = "adwaita";
    style.name = "adwaita-dark";
  };

  # ── wlogout ─────────────────────────────────────────────────────────────────
  # Стилізуємо в тому ж брутальному ключі.
  xdg.configFile."wlogout/layout".text = ''
    { "label": "lock",     "action": "swaylock -f", "text": "LOCK",     "keybind": "l" }
    { "label": "logout",   "action": "pkill mango", "text": "LOGOUT",   "keybind": "e" }
    { "label": "suspend",  "action": "systemctl suspend", "text": "SUSPEND", "keybind": "s" }
    { "label": "reboot",   "action": "systemctl reboot", "text": "REBOOT", "keybind": "r" }
    { "label": "shutdown", "action": "systemctl poweroff", "text": "OFF", "keybind": "p" }
  '';

  xdg.configFile."wlogout/style.css".text = ''
    @import url("file://${home}/.config/waybar/colors.css");
    window { background-color: rgba(13, 13, 16, 0.85); }
    button {
      background: @bg_alt;
      color: @fg;
      border: 3px solid @outline;
      border-radius: 0;
      font-family: "JetBrainsMono Nerd Font";
      font-size: 18px;
      font-weight: 800;
      margin: 8px;
      background-image: none;
    }
    button:hover, button:focus {
      background: @accent;
      color: @accent_fg;
      border-color: @accent;
    }
  '';
}
