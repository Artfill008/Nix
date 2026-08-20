# Робочий стіл. DE немає — стек збирається вручну.
# Для кожного компонента: чому саме він і що програло.
#
# ЧЕСНО ПРО ЗБІРНИЙ СТЕК (де болітиме проти готового DE) — див. docs/shell-stack.md.
{
  config,
  lib,
  pkgs,
  username,
  ...
}:
{
  # ── Композитор ──────────────────────────────────────────────────────────────
  # mango 0.16.0 БЕРЕТЬСЯ З NIXPKGS. Окремий flake input не потрібен.
  # Перевірено: pkgs/by-name/ma/mango/package.nix (version = "0.16.0",
  # src = mangowm/mango tag 0.16.0, wlroots_0_20 + scenefx, enableXWayland ? true)
  # і nixos/modules/programs/wayland/mango.nix (опція programs.mango).
  #
  # Модуль programs.mango сам робить три речі, тому ми їх нижче не дублюємо:
  #   1. environment.systemPackages = [ cfg.package ]
  #   2. xdg.portal.enable + extraPortals = [ xdg-desktop-portal-wlr xdg-desktop-portal-gtk ]
  #      і config.mango з правильним розкладом: ScreenCast/ScreenShot → wlr,
  #      Secret → gnome-keyring, Inhibit → gtk, решта → gtk.
  #   3. services.displayManager.sessionPackages = [ cfg.package ]
  #      — саме завдяки цьому regreet побачить сесію «mango».
  programs.mango.enable = true;

  # XWayland потрібен (Steam, старі GTK2-програми, деякі інсталятори).
  # Він увімкнений у пакеті за замовчуванням (enableXWayland ? true),
  # але сам бінарник Xwayland має бути в системі.
  programs.xwayland.enable = true;

  # ── Дисплей-менеджер ────────────────────────────────────────────────────────
  # greetd — мінімальний, не тягне ні Qt, ні GNOME. regreet — GTK4-фронтенд
  # до нього, який виглядає як частина системи (ті самі шпалери й тема).
  # Програв SDDM: тягне Qt6/KDE-стек у boot-шлях заради екрана логіну.
  # Програв GDM: тягне половину GNOME і має власні уявлення про сесії Wayland.
  # Програв ly/lemurs: гарні, але без GTK-теми не вийде єдиної естетики.
  # Модуль regreet сам вмикає greetd (mkDefault true) і сам задає
  # default_session.command — він запускає regreet усередині `cage`
  # (одновіконний kiosk-композитор на wlroots), бо regreet — це звичайний
  # GTK4-клієнт і без композитора існувати не може.
  #
  # Користувача `greeter` створює модуль greetd (users.users.greeter,
  # isSystemUser), а default_session.user він ставить через mkDefault.
  # Тому нічого з цього дублювати не треба — лишаємо тільки явне enable,
  # щоб у конфізі було видно, що дисплей-менеджер тут є.
  services.greetd.enable = true;

  services.displayManager.regreet = {
    enable = true;

    # GTK-тема гріттера. Точні кольори regreet бере зі своєї теми,
    # matugen сюди НЕ дотягується (гріттер стартує до сесії юзера і не бачить
    # ~/.config). Тому тут — статичний темний Adwaita, а не динамічні кольори.
    theme = {
      package = pkgs.gnome-themes-extra;
      name = "Adwaita-dark";
    };
    iconTheme = {
      package = pkgs.papirus-icon-theme;
      name = "Papirus-Dark";
    };
    cursorTheme = {
      package = pkgs.bibata-cursors;
      name = "Bibata-Modern-Ice";
    };
    font = {
      package = pkgs.nerd-fonts.jetbrains-mono;
      name = "JetBrainsMono Nerd Font";
      size = 12;
    };

    # Брутальна естетика вже на екрані логіну: різка геометрія, товсті рамки,
    # без заокруглень і без тіней.
    extraCss = ''
      window, .background { background-color: #101014; }
      * { border-radius: 0; }
      entry, button {
        border: 2px solid #e0e0e0;
        background: #101014;
        color: #e0e0e0;
        padding: 8px 14px;
      }
      entry:focus { border-color: #7fd1ff; }
      button:hover { background: #e0e0e0; color: #101014; }
    '';

    settings = {
      # TODO: шлях до шпалери гріттера. Файл має бути читабельним для
      # користувача `greeter`, тому НЕ клади його в /home.
      # Пайплайн moewall кладе поточну шпалеру у /var/lib/moewall/current.png
      # саме заради цього.
      background = {
        path = "/var/lib/moewall/current.png";
        fit = "Cover";
      };
      GTK.application_prefer_dark_theme = true;
    };
  };

  # ── Аудіо ───────────────────────────────────────────────────────────────────
  # PipeWire — безальтернативно на Wayland: він єдиний дає і аудіо, і
  # screen-sharing через portal. PulseAudio програв за визначенням.
  services.pulseaudio.enable = false;
  security.rtkit.enable = true; # дозволяє PipeWire брати realtime-пріоритет
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true; # емуляція PulseAudio API для старих програм
    jack.enable = true; # для аудіододатків; коштує майже нічого
    wireplumber.enable = true;
  };

  # ── Bluetooth ───────────────────────────────────────────────────────────────
  hardware.bluetooth = {
    enable = true;
    powerOnBoot = false; # не вмикати радіо, поки не попросили — економія і безпека
    settings.General = {
      # A2DP-профілі високої якості (LDAC/aptX доступні через PipeWire).
      Enable = "Source,Sink,Media,Socket";
      Experimental = true; # потрібно для показу рівня заряду навушників
    };
  };
  # blueman — GTK-аплет у трей. Програв bluetuith (TUI, гарний, але в треї не живе)
  # і bluedevil (Qt/KDE).
  services.blueman.enable = true;

  # ── Автомонтування ──────────────────────────────────────────────────────────
  services.udisks2.enable = true; # бекенд монтування без root
  services.gvfs.enable = true; # MTP (телефон), smb, trash:// у файлменеджері
  # Сам аплет udiskie запускається як user-сервіс — див. home/default.nix.

  # ── Безпека сесії ───────────────────────────────────────────────────────────
  security.polkit.enable = true;

  # gnome-keyring: єдиний secrets-бекенд, який реалізує org.freedesktop.Secret
  # і який розуміють і GTK-, і Qt-програми, і браузери.
  # Програв KWallet: тягне KDE-стек. Програв pass+gopass: чудові для CLI,
  # але не відповідають на D-Bus Secret Service.
  services.gnome.gnome-keyring.enable = true;

  # Автовідмикання keyring паролем логіну. Працює саме тому, що ми обрали
  # greetd з паролем, а не TTY-автологін.
  security.pam.services.greetd.enableGnomeKeyring = true;

  # swaylock має бути в PAM, інакше не зможе перевірити твій пароль
  # і ти залишишся заблокованим назавжди (це не жарт — типова помилка).
  security.pam.services.swaylock = { };

  # ── Портали ─────────────────────────────────────────────────────────────────
  # xdg.portal вже налаштований модулем programs.mango.
  # Додаємо лише те, чого він не робить: змінну для GTK-діалогів.
  xdg.portal.xdgOpenUsePortal = true;

  # ── dconf ───────────────────────────────────────────────────────────────────
  # Потрібен будь-якій GTK-програмі, що зберігає налаштування, і home-manager
  # для gtk.* опцій. Без нього GTK-теми з HM мовчки не застосуються.
  programs.dconf.enable = true;

  # ── Живлення / кнопки ───────────────────────────────────────────────────────
  services.upower.enable = true; # рівень заряду для waybar
  services.logind.settings.Login = {
    HandlePowerKey = "suspend"; # кнопка живлення = сон, а не миттєве вимкнення
    HandleLidSwitch = "suspend";
    HandleLidSwitchExternalPower = "lock";
  };

  # ── Шрифти ──────────────────────────────────────────────────────────────────
  fonts = {
    enableDefaultPackages = true;
    packages = with pkgs; [
      # Основний моноширинний з іконками для бару/терміналу/редактора.
      nerd-fonts.jetbrains-mono
      # Пропорційний інтерфейсний.
      inter
      # CJK — обов'язково, як ти просив. Без цього японські назви файлів,
      # теги booru і половина аніме-контенту будуть у «тофу» (□□□).
      noto-fonts-cjk-sans
      noto-fonts-cjk-serif
      noto-fonts
      noto-fonts-color-emoji
      # Кирилиця з нормальними накресленнями.
      dejavu_fonts
      liberation_ttf
    ];

    fontconfig = {
      enable = true;
      defaultFonts = {
        # Порядок важливий: перший, що містить гліф, виграє.
        # Тому CJK іде ПІСЛЯ латинських — інакше латиниця малюватиметься
        # китайськими метриками і виглядатиме широкою.
        monospace = [
          "JetBrainsMono Nerd Font"
          "Noto Sans Mono CJK JP"
        ];
        sansSerif = [
          "Inter"
          "Noto Sans CJK JP"
        ];
        serif = [
          "Noto Serif"
          "Noto Serif CJK JP"
        ];
        emoji = [ "Noto Color Emoji" ];
      };
      # Субпіксельне згладжування під звичайну RGB-матрицю 1080p.
      subpixel.rgba = "rgb";
      hinting = {
        enable = true;
        style = "slight"; # full ламає форми у сучасних шрифтів
      };
    };
  };

  # ── Оболонка: повний список ─────────────────────────────────────────────────
  environment.systemPackages = with pkgs; [
    # ── Бар ───────────────────────────────────────────────────────────────────
    # Waybar. Виграв, бо: (а) єдиний бар з готовими модулями під wlroots
    # (tags через wlr/taskbar, tray через StatusNotifier, battery/network/pulse),
    # (б) стилізується чистим CSS — а matugen генерує CSS напряму, без обгорток.
    # Програв ironbar (Rust, легший, але модулів удвічі менше і tray сирий).
    # Програли eww / quickshell / ags: це не бари, а фреймворки — ти пишеш
    # бар з нуля, і ags тримає GJS-рантайм у пам'яті постійно.
    waybar

    # ── Лаунчер ───────────────────────────────────────────────────────────────
    # fuzzel. Виграв: нативний wayland-клієнт (~2 МБ RSS), читає .desktop,
    # вміє dmenu-режим (потрібен для cliphist і wlogout), нечіткий пошук у ядрі.
    # Програв rofi-wayland (форк, що вічно наздоганяє апстрім rofi).
    # Програв wofi (не розвивається). Програв anyrun (гарний, але тягне
    # плагінну систему на Rust заради запуску програм).
    fuzzel

    # ── Сповіщення ────────────────────────────────────────────────────────────
    # mako. Виграв: нативний wlroots, ini-конфіг (matugen генерує в нього
    # одним шаблоном), ~3 МБ, підтримує групування і режими (do-not-disturb).
    # Програв swaync: має центр історії — це реальна перевага, — але це GTK4
    # у пам'яті постійно і CSS, який доведеться синхронізувати з waybar.
    # Якщо захочеш історію сповіщень — це єдина причина мінятись.
    # Програв dunst: родом з X11, wayland-порт має слабший layer-shell.
    mako
    libnotify # notify-send — для перевірки і для скриптів

    # ── Локер ─────────────────────────────────────────────────────────────────
    # swaylock. Виграв: використовує ext-session-lock-v1 (протокол, при якому
    # композитор ГАРАНТУЄ, що екран не розблокується навіть якщо локер впаде),
    # мінімальна кодова база в критичному для безпеки шляху, PAM напряму.
    # Програв swaylock-effects: той самий локер + blur — ти blur не хочеш.
    # Програв hyprlock: тягне hyprutils/hyprlang і робить шейдери.
    # Програв gtklock: GTK3 у локері = більше коду, який може впасти.
    swaylock

    # ── Idle-демон ────────────────────────────────────────────────────────────
    # swayidle. Виграв: ext-idle-notify-v1, конфіг у вигляді аргументів
    # (тобто повністю декларується з Nix), 200 рядків коду.
    # Програв hypridle: та сама функція + залежності hypr*.
    swayidle

    # ── Polkit-агент ──────────────────────────────────────────────────────────
    # polkit_gnome. Виграв за розміром: це один невеликий GTK3-бінарник.
    # Програв lxqt-policykit (тягне Qt5), hyprpolkitagent (тягне hypr-стек),
    # kde-polkit-agent (тягне KDE).
    # ЧЕСНО: polkit_gnome фактично не розвивається. Він працює, але це
    # найімовірніший кандидат на заміну через рік-два.
    polkit_gnome

    # ── Буфер обміну ──────────────────────────────────────────────────────────
    wl-clipboard # wl-copy / wl-paste — базові примітиви
    cliphist # історія буфера; віддає у fuzzel через dmenu-режим
    # wl-clip-persist вирішує головну ваду Wayland: коли програма-джерело
    # закривається, вміст буфера ЗНИКАЄ (бо в Wayland буфер живе в клієнті).
    # Без нього «скопіював у редакторі → закрив редактор → вставив» не працює.
    wl-clip-persist

    # ── Скріншот / запис ──────────────────────────────────────────────────────
    grim # знімок (wlr-screencopy)
    slurp # вибір області мишею
    satty # редактор-анотатор поверх знімка (стрілки, текст, підсвітка)
    # Програв swappy: те саме, але розвивається повільніше.
    wf-recorder # запис екрана
    # ЧЕСНО про запис: wf-recorder кодує software (libx264). На 4C/8T це
    # 1080p60 без запасу. Апаратний NVENC доступний, але через ffmpeg,
    # а не через wf-recorder. Програв wl-screenrec: він швидший саме тому,
    # що вимагає VAAPI — а VAAPI на Maxwell через nvidia-vaapi-driver
    # ненадійний. Для серйозного запису став OBS окремо (у нього є NVENC).

    # ── Яскравість / гучність / медіа ─────────────────────────────────────────
    brightnessctl # яскравість; працює через /sys/class/backlight
    playerctl # MPRIS: play/pause/next з медіаклавіш
    pwvucontrol # GTK4-мікшер PipeWire; програв pavucontrol (GTK3, показує
    # PipeWire через шар сумісності і брехливо називає вузли)
    wiremix # TUI-мікшер, коли не хочеться відкривати GUI

    # ── Мережа / Bluetooth у треї ─────────────────────────────────────────────
    networkmanagerapplet # nm-applet --indicator → у tray waybar
    blueman # blueman-applet

    # ── Автомонтування у треї ─────────────────────────────────────────────────
    udiskie # аплет + автомонтування; програв udevil (нема треєвої частини)

    # ── Дисплеї / ввід (діагностика) ──────────────────────────────────────────
    wlr-randr # подивитись назви виходів і доступні режими — знадобиться для 75 Гц
    wev # дізнатись справжню назву клавіші для bind=
    wtype # синтетичний ввід (потрібен деяким скриптам)

    # ── Вихід із сесії ────────────────────────────────────────────────────────
    wlogout # меню power/lock/logout; програв власний fuzzel-скрипт лише тим,
    # що wlogout має нормальну сітку кнопок і теж стилізується CSS

    # ── Тема / кольори ────────────────────────────────────────────────────────
    matugen # генератор палітри Material You зі шпалери — ядро всієї теми
    swaybg # статичні шпалери; програв swww (анімовані переходи = зайвий
    # демон у пам'яті і зайві кадри на 4 ГБ VRAM)

    # ── XDG ───────────────────────────────────────────────────────────────────
    xdg-utils # xdg-open
    glib # gsettings — HM ним ставить GTK-налаштування
    gsettings-desktop-schemas
  ];

  # Автозапуск polkit-агента як user-сервісу.
  # Без агента будь-яка дія, що вимагає авторизації (монтування чужого диска,
  # запуск virt-manager), просто мовчки провалиться.
  systemd.user.services.polkit-gnome-authentication-agent-1 = {
    description = "polkit-gnome authentication agent";
    wantedBy = [ "graphical-session.target" ];
    wants = [ "graphical-session.target" ];
    after = [ "graphical-session.target" ];
    serviceConfig = {
      Type = "simple";
      ExecStart = "${pkgs.polkit_gnome}/libexec/polkit-gnome-authentication-agent-1";
      Restart = "on-failure";
      RestartSec = 1;
      TimeoutStopSec = 10;
    };
  };
}
