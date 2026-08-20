# Home-manager: користувацька частина.
{
  config,
  lib,
  pkgs,
  username,
  ...
}:
{
  imports = [
    ./mango.nix
    ./shell.nix
    ./terminal.nix
    ./theme.nix
  ];

  home.username = username;
  home.homeDirectory = "/home/${username}";

  # Те саме, що system.stateVersion, але для HM. Не міняй при оновленнях.
  home.stateVersion = "26.05";

  programs.home-manager.enable = true;

  # ── ПАКЕТИ РІВНЯ КОРИСТУВАЧА ────────────────────────────────────────────────
  #
  # ⚠ ВАЖЛИВА ЗМІНА ПІСЛЯ АУДИТУ (A-062, розширено).
  #
  # Раніше тут жив ПОВНИЙ набір щоденних програм: nemo, imv, mpv, zathura,
  # smile, font-manager, mission-center. Але після переходу на
  # libadwaita-first (D-060/D-061) той самий набір ролей з'явився ще й у
  # modules/apps.nix — Nautilus, Loupe, Celluloid, Papers, Characters,
  # Resources. Обидва списки були активні одночасно.
  #
  # Наслідки, які це давало:
  #   • по ДВІ програми на кожну роль — прямо проти R13.3 і D-060;
  #   • SUPER+e відкривав nemo, а не Nautilus;
  #   • ~/.config/mimeapps.list вказував на zathura/imv, і оскільки він має
  #     вищий пріоритет за /etc, подвійний клік по PDF пішов би в програму,
  #     якої немає в системі.
  #
  # ЄДИНЕ ДЖЕРЕЛО ІСТИНИ ДЛЯ ЩОДЕННИХ ПРОГРАМ — modules/apps.nix.
  # Причина саме така: це база дистрибутива, а не персональний профіль.
  # Роль «переглядач PDF» належить системі, а не конкретному home.
  #
  # Тут лишається лише те, що НЕ дублює жодну роль з apps.nix і є
  # особистим тулінгом оболонки.
  home.packages = with pkgs; [
    # ── Заміни базових утиліт, які приємніші у власному shell ────────────────
    # Це не «ще один системний монітор», а звички в терміналі.
    # bat/eza/dust/duf свідомо тут, а не в системі: вони налаштовані під
    # цю конкретну fish-конфігурацію (див. home/shell.nix).
    bat # cat з підсвіткою
    eza # ls з деревом і git-статусом
    dust # du, який видно
    duf # df, який видно
  ];

  # ЩО ПЕРЕЇХАЛО В modules/apps.nix І ЧОМУ САМЕ ТАКИЙ ПЕРЕМОЖЕЦЬ
  # (аргументацію збережено, бо вона є частиною рішення, а не сміттям):
  #
  #   Файловий менеджер: Nemo → Nautilus.
  #     Nemo мав type-ahead, split view і вбудований термінал — і це реальна
  #     втрата, чесно. Nautilus виграв інтеграцією: GVfs (Trash/MTP/SMB),
  #     портали, GTK4-діалоги і мініатюри працюють без доклеювання.
  #     Це і є той випадок, де «функціональність програє інтеграції».
  #
  #   Зображення: imv → Loupe.
  #     imv легший і має vim-клавіші. Loupe виграв ізольованим декодером
  #     (glycin) і тим, що відкривається з Nautilus як рідний.
  #
  #   Відео: mpv → Celluloid.
  #     Celluloid — це фронтенд НАД mpv, тож рушій той самий, включно з
  #     керуванням hwdec (критично: GM204 декодує апаратно лише H.264).
  #     Окремий CLI-mpv прибрано як дублювання ролі; libmpv приходить
  #     разом із Celluloid.
  #
  #   PDF: zathura → Papers.
  #     zathura має vim-клавіші і миттєвий старт. Papers на тому ж poppler,
  #     тобто якість рендера ідентична, але з sandbox і рідним виглядом.
  #
  #   Емодзі: smile → GNOME Characters. Монітор: mission-center → Resources.
  #   Шрифти: font-manager → gnome-font-viewer.
  #     У всіх трьох різниця мала; вирішила візуальна цілісність.
  #
  #   yazi, helix, file-roller, qalculate, firefox, btop, ripgrep, fd, jq,
  #   curl, wget — не зникли, вони тепер у modules/apps.nix або modules/dev.nix,
  #   тобто доступні всій системі, а не лише цьому користувачу.

  # ── Автозапуск фонових служб сесії ──────────────────────────────────────────
  # Запускаємо як systemd user-сервіси, а не з autostart.sh, бо:
  #  • systemd перезапустить те, що впало;
  #  • є нормальний журнал (journalctl --user -u mako);
  #  • є залежності і порядок запуску.
  # Прив'язка — до graphical-session.target, який піднімає mango
  # (див. autostart у home/mango.nix).

  systemd.user.services = {
    # Демон сповіщень.
    mako = {
      Unit = {
        Description = "mako notification daemon";
        PartOf = [ "graphical-session.target" ];
        After = [ "graphical-session.target" ];
      };
      Service = {
        Type = "simple";
        ExecStart = "${pkgs.mako}/bin/mako";
        Restart = "on-failure";
      };
      Install.WantedBy = [ "graphical-session.target" ];
    };

    # Історія буфера обміну: два процеси-слухачі (текст і зображення).
    cliphist-text = {
      Unit = {
        Description = "cliphist: історія текстового буфера";
        PartOf = [ "graphical-session.target" ];
        After = [ "graphical-session.target" ];
      };
      Service = {
        ExecStart = "${pkgs.bash}/bin/bash -c '${pkgs.wl-clipboard}/bin/wl-paste --type text --watch ${pkgs.cliphist}/bin/cliphist store'";
        Restart = "on-failure";
      };
      Install.WantedBy = [ "graphical-session.target" ];
    };

    cliphist-image = {
      Unit = {
        Description = "cliphist: історія буфера зображень";
        PartOf = [ "graphical-session.target" ];
        After = [ "graphical-session.target" ];
      };
      Service = {
        ExecStart = "${pkgs.bash}/bin/bash -c '${pkgs.wl-clipboard}/bin/wl-paste --type image --watch ${pkgs.cliphist}/bin/cliphist store'";
        Restart = "on-failure";
      };
      Install.WantedBy = [ "graphical-session.target" ];
    };

    # Зберігає вміст буфера після закриття програми-джерела.
    # Без цього «скопіював → закрив вікно → вставив» не працює. Це не баг
    # конкретної програми, це так влаштований Wayland.
    wl-clip-persist = {
      Unit = {
        Description = "wl-clip-persist";
        PartOf = [ "graphical-session.target" ];
        After = [ "graphical-session.target" ];
      };
      Service = {
        ExecStart = "${pkgs.wl-clip-persist}/bin/wl-clip-persist --clipboard regular";
        Restart = "on-failure";
      };
      Install.WantedBy = [ "graphical-session.target" ];
    };

    # Автомонтування USB з іконкою в треї.
    udiskie = {
      Unit = {
        Description = "udiskie: автомонтування знімних носіїв";
        PartOf = [ "graphical-session.target" ];
        After = [ "graphical-session.target" ];
      };
      Service = {
        ExecStart = "${pkgs.udiskie}/bin/udiskie --tray --appindicator --no-automount --notify";
        # --no-automount свідомо: автоматичне монтування будь-якої флешки —
        # це вектор атаки (autorun-подібні трюки через файлові системи).
        # Іконка в треї дасть змонтувати одним кліком.
        Restart = "on-failure";
      };
      Install.WantedBy = [ "graphical-session.target" ];
    };

    # Аплет мережі в треї.
    nm-applet = {
      Unit = {
        Description = "NetworkManager applet";
        PartOf = [ "graphical-session.target" ];
        After = [ "graphical-session.target" ];
      };
      Service = {
        ExecStart = "${pkgs.networkmanagerapplet}/bin/nm-applet --indicator";
        Restart = "on-failure";
      };
      Install.WantedBy = [ "graphical-session.target" ];
    };

    # Аплет Bluetooth у треї.
    blueman-applet = {
      Unit = {
        Description = "Blueman applet";
        PartOf = [ "graphical-session.target" ];
        After = [ "graphical-session.target" ];
      };
      Service = {
        ExecStart = "${pkgs.blueman}/bin/blueman-applet";
        Restart = "on-failure";
      };
      Install.WantedBy = [ "graphical-session.target" ];
    };

    # Idle: приглушити екран → заблокувати → вимкнути екран.
    swayidle = {
      Unit = {
        Description = "swayidle";
        PartOf = [ "graphical-session.target" ];
        After = [ "graphical-session.target" ];
      };
      Service = {
        ExecStart = lib.concatStringsSep " " [
          "${pkgs.swayidle}/bin/swayidle -w"
          # 5 хв: приглушити яскравість до 10% (попередження)
          "timeout 300 '${pkgs.brightnessctl}/bin/brightnessctl -s set 10%'"
          "resume '${pkgs.brightnessctl}/bin/brightnessctl -r'"
          # 10 хв: заблокувати
          "timeout 600 '${pkgs.swaylock}/bin/swaylock -f'"
          # 15 хв: погасити панель (DPMS)
          # TODO: eDP-1 — перевір справжню назву виходу через `wlr-randr`.
          "timeout 900 '${pkgs.wlr-randr}/bin/wlr-randr --output eDP-1 --off'"
          "resume '${pkgs.wlr-randr}/bin/wlr-randr --output eDP-1 --on'"
          # Перед сном — обов'язково заблокувати
          "before-sleep '${pkgs.swaylock}/bin/swaylock -f'"
        ];
        Restart = "on-failure";
      };
      Install.WantedBy = [ "graphical-session.target" ];
    };

    # ── kanshi: профілі виходів на hotplug ────────────────────────────────────
    # Аудит A-044: пакет був установлений, але без служби і без конфігу —
    # тобто «підключив монітор і воно саме розклалось» НЕ працювало.
    kanshi = {
      Unit = {
        Description = "kanshi: автоматичні профілі виходів";
        PartOf = [ "graphical-session.target" ];
        After = [ "graphical-session.target" ];
      };
      Service = {
        ExecStart = "${pkgs.kanshi}/bin/kanshi";
        Restart = "on-failure";
        RestartSec = 3;
      };
      Install.WantedBy = [ "graphical-session.target" ];
    };
  };

  # ── Конфіг kanshi ───────────────────────────────────────────────────────────
  # Профілі застосовуються за СПІВПАДІННЯМ набору підключених виходів.
  # Перший, що підійшов, виграє — тому «докстанція» має бути ВИЩЕ за «ноут сам».
  #
  # TODO ПІСЛЯ ПЕРШОГО ЗАВАНТАЖЕННЯ: перевір справжні назви виходів:
  #     wlr-randr
  # У GT72S внутрішня панель майже завжди eDP-1, але HDMI/DP залежать
  # від того, куди саме ввімкнено кабель.
  xdg.configFile."kanshi/config".text = ''
    # Ноутбук + зовнішній монітор по HDMI.
    profile docked-hdmi {
      output eDP-1 mode 1920x1080 position 0,1080
      output HDMI-A-1 mode 1920x1080 position 0,0
    }

    # Ноутбук + зовнішній по DisplayPort.
    profile docked-dp {
      output eDP-1 mode 1920x1080 position 0,1080
      output DP-1 mode 1920x1080 position 0,0
    }

    # Тільки внутрішня панель.
    # 60 Гц свідомо: 75 Гц — EXPERIMENTAL і вмикається окремо через
    # gt72s.panel75. Профіль виходів не має права робити панель непрацездатною.
    profile laptop-only {
      output eDP-1 mode 1920x1080 position 0,0
    }
  '';

  # ── XDG ─────────────────────────────────────────────────────────────────────
  xdg = {
    enable = true;
    userDirs = {
      enable = true;
      createDirectories = true;
    };
    # ── MIME ──────────────────────────────────────────────────────────────────
    # ⚠ ТУТ БУВ СЕРЙОЗНИЙ БАГ (аудит A-062, піднято до HIGH).
    #
    # Раніше цей блок задавав власний список типів, і він указував на
    # zathura / imv / mpv / nemo — тобто на програми, ЯКИХ У СИСТЕМІ ВЖЕ НЕМАЄ
    # після переходу на libadwaita-набір (D-060/D-061). А оскільки
    # ~/.config/mimeapps.list має ВИЩИЙ пріоритет за /etc, він перекривав
    # правильний системний список. Наслідок був би не «трохи не та програма»,
    # а «подвійний клік по PDF не робить нічого».
    #
    # ЄДИНЕ ДЖЕРЕЛО ІСТИНИ ТЕПЕР — modules/apps.nix
    # (xdg.mime.defaultApplications на рівні системи). Так правильніше для бази
    # дистрибутива: асоціації діють для будь-якого користувача, а не лише для
    # цього конкретного home.
    #
    # enable лишається true: home-manager має керувати цим файлом, щоб
    # програми не дописували в нього сміття за спиною. Список порожній —
    # значить система не перекривається.
    mimeApps = {
      enable = true;
      defaultApplications = { };
    };
  };
}
