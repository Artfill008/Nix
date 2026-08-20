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

  # ── ЩОДЕННІ ПРОГРАМИ ────────────────────────────────────────────────────────
  # Тільки база. Кожен вибір — з причиною і з тим, що програло.
  home.packages = with pkgs; [
    # ── Файловий менеджер, GUI ────────────────────────────────────────────────
    # nemo. Виграв: найшвидший GTK3-менеджер з нормальною поведінкою —
    # має вбудований термінал, роздільні вкладки, type-ahead пошук
    # (набираєш — і воно стрибає до файлу), і не тягне за собою DE.
    # Програв nautilus: GNOME викинув type-ahead, роздільний вигляд і
    # рядок шляху; плюс тягне gnome-shell-схеми.
    # Програв thunar: тягне xfconf/xfce-стек заради налаштувань.
    # Програв dolphin: найфункціональніший з усіх, але це Qt+KIO+KDE-фреймворки.
    nemo
    nemo-fileroller # інтеграція «розпакувати тут» у контекстне меню

    # ── Файловий менеджер, TUI ────────────────────────────────────────────────
    # yazi. Виграв: повністю асинхронний (не вішається на мережевій ФС
    # чи великій директорії), прев'ю зображень прямо в терміналі,
    # вбудований плагінний рушій на Lua.
    # Програв ranger: Python, синхронний, помітно гальмує на великих деревах.
    # Програв lf: швидкий, але прев'ю треба збирати самому зі скриптів.
    # Програв nnn: найшвидший, але вся функціональність — у bash-плагінах.
    yazi

    # ── Браузер ───────────────────────────────────────────────────────────────
    # firefox. Виграв: нативний Wayland без прапорців, єдиний рушій,
    # незалежний від Google, і найкраща поведінка з fractional scaling.
    # Програв chromium: швидший на JS, але на NVIDIA+Wayland досі потребує
    # ручних прапорців, і кожен апдейт може їх зламати.
    # TODO: якщо потрібен другий браузер — став окремо через nixmgr.
    firefox

    # ── Архіватор ─────────────────────────────────────────────────────────────
    # file-roller. Виграв: інтегрується з nemo (через nemo-fileroller),
    # розуміє все, що вміють бекенди нижче.
    # Програв xarchiver: легший, але гірше поводиться з паролями і UTF-8
    # в іменах усередині архіву.
    # Програв ark: тягне Qt/KDE.
    file-roller
    p7zip # бекенд: 7z, rar (розпакування), zip
    unar # бекенд: найкраще у світі розпакування архівів з CJK-іменами
    unzip
    zip

    # ── Перегляд зображень ────────────────────────────────────────────────────
    # imv. Виграв: нативний Wayland-клієнт, vim-подібні клавіші,
    # стартує миттєво, тримає ~15 МБ.
    # Програв loupe (GNOME): гарний, але GTK4 + libadwaita на кожен PNG.
    # Програв qimgv: Qt, більше можливостей, більше пам'яті.
    # Програв swayimg: дуже близький конкурент, чесно — паритет.
    #   imv обрано за більшу зрілість і кращу підтримку анімованих форматів.
    imv

    # ── Відеоплеєр ────────────────────────────────────────────────────────────
    # mpv. Виграв беззастережно: єдиний плеєр, де можна керувати кожним
    # аспектом декодування (а нам це потрібно — див. NVDEC на Maxwell),
    # і найкраще масштабування.
    # Програв vlc: Qt-інтерфейс і власний стек декодування, який на
    # NVIDIA legacy поводиться непередбачувано.
    mpv

    # ── PDF ───────────────────────────────────────────────────────────────────
    # zathura. Виграв: vim-клавіші, миттєвий старт, вкладки, SyncTeX.
    # Пакет `zathura` у nixpkgs — це вже обгортка з плагінами
    # (zathuraPkgs.zathuraWrapper), тобто PDF/PS/DjVu працюють з коробки.
    # Програв papers/evince: GNOME-стек. Програв okular: Qt-стек.
    zathura

    # ── Текстовий редактор ────────────────────────────────────────────────────
    # helix. Виграв: LSP, tree-sitter підсвітка і мультикурсор працюють
    # ОДРАЗУ, без жодного рядка конфігу і без плагінного менеджера.
    # Програв neovim: потужніший, але це проєкт «налаштуй собі редактор»,
    #   а ти зараз налаштовуєш систему — не варто робити дві справи одразу.
    # Програв micro: простий, але без LSP.
    helix

    # ── Калькулятор ───────────────────────────────────────────────────────────
    # qalculate-gtk. Виграв: розуміє одиниці («50 GB / 3 MB/s in minutes»),
    # валюти з оновленням курсів, символьні обчислення і системи рівнянь.
    # Програв gnome-calculator: гарний, але парсер набагато слабший.
    qalculate-gtk

    # ── Системний монітор ─────────────────────────────────────────────────────
    # btop. Виграв: показує CPU/RAM/диски/мережу/процеси і GPU через
    # nvidia-плагін, все в одному екрані, керується мишею.
    # Програв htop: тільки процеси. Програв bottom: паритет, менше зрілий.
    btop
    # GUI-варіант, коли хочеться графіків:
    mission-center

    # ── Шрифти та емодзі ──────────────────────────────────────────────────────
    # font-manager. Виграв: єдиний, що вміє і переглядати, і порівнювати,
    # і вмикати/вимикати шрифти без правки fontconfig руками.
    font-manager
    # smile — вибір емодзі для Wayland (вставляє через wtype).
    # Програв rofi-emoji: потребує rofi, якого ми не ставимо.
    smile

    # ── Дрібний тулінг, без якого боляче ──────────────────────────────────────
    ripgrep # rg — швидкий пошук по вмісту
    fd # заміна find з людським синтаксисом
    bat # cat з підсвіткою
    eza # ls з деревом і git-статусом
    dust # du, який видно
    duf # df, який видно
    jq # робота з JSON (знадобиться для налагодження moewall)
    curl
    wget
  ];

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
  };

  # ── XDG ─────────────────────────────────────────────────────────────────────
  xdg = {
    enable = true;
    userDirs = {
      enable = true;
      createDirectories = true;
    };
    mimeApps = {
      enable = true;
      defaultApplications = {
        "text/html" = "firefox.desktop";
        "x-scheme-handler/http" = "firefox.desktop";
        "x-scheme-handler/https" = "firefox.desktop";
        "application/pdf" = "org.pwmt.zathura.desktop";
        "image/png" = "imv.desktop";
        "image/jpeg" = "imv.desktop";
        "image/gif" = "imv.desktop";
        "image/webp" = "imv.desktop";
        "video/mp4" = "mpv.desktop";
        "video/x-matroska" = "mpv.desktop";
        "inode/directory" = "nemo.desktop";
      };
    };
  };
}
