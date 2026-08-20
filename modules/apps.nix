# Базові щоденні програми.
#
# ПРИНЦИП (твій вибір: libadwaita-first hybrid):
#   беремо GTK4/libadwaita скрізь, де воно функціонально не гірше;
#   там, де гірше — беремо краще і чесно пишемо, ЩО САМЕ втрачаємо.
#
# Одна функція = одна програма. Тут немає «трьох переглядачів зображень».
{
  config,
  lib,
  pkgs,
  ...
}:
{
  environment.systemPackages = with pkgs; [
    # ── Файловий менеджер (GUI) ───────────────────────────────────────────────
    # Nautilus. Виграв за твоїм критерієм: єдиний FM, який повністю
    # інтегрований з тим стеком, що ми вже підняли — GVfs (Trash, MTP, SMB),
    # порталами, GTK4-діалогами і tumbler-мініатюрами. Нічого не треба
    # доклеювати.
    # ЩО ВТРАЧАЄМО, чесно: Nautilus вирізав split view, type-ahead find
    # (пошук по перших літерах без відкриття рядка пошуку) і компактний режим.
    # Nemo все це має. Якщо через тиждень type-ahead почне бісити — заміна
    # рівно на один рядок, GVfs і мініатюри працюють в обох.
    nautilus

    # ── Файловий менеджер (TUI) ───────────────────────────────────────────────
    # yazi. Виграв: асинхронний (не блокує UI на мережевих шляхах), має
    # мініатюри прямо в терміналі, плагіни на Lua.
    # Програв ranger: Python, синхронний, помітно гальмує на великих теках.
    # Програв lf: швидкий, але без мініатюр і з мінімумом можливостей.
    yazi

    # ── Перегляд зображень ────────────────────────────────────────────────────
    # Loupe. GTK4/libadwaita, апаратне масштабування, читає все через
    # glycin (ізольований декодер — картинка з інтернету не роняє переглядач).
    # Функціонально не гірший за imv для перегляду. Програв imv/swayimg:
    # вони легші, але це CLI-переглядачі без інтеграції з FM.
    loupe

    # ── Відео ─────────────────────────────────────────────────────────────────
    # Celluloid — твій вибір, і він тут об'єктивно правильний:
    # це GTK4/libadwaita-фронтенд НАД mpv, тобто ти отримуєш і вигляд,
    # і повний движок mpv (профілі, апаратний декод, шейдери, субтитри).
    # Showtime програв саме тому, що він поверх GStreamer і не дає керувати
    # декодером — а нам це критично: GM204 декодує апаратно ТІЛЬКИ H.264,
    # тож на HEVC треба свідомо падати в софт, а не гадати.
    # Конфіг mpv (hwdec) — у home/, бо це user state.
    celluloid

    # ── Аудіо ─────────────────────────────────────────────────────────────────
    # Decibels. Мінімалістичний GTK4-програвач для «клацнув на файл — заграло».
    # Це НЕ музична бібліотека. Якщо потрібна колекція з тегами — TODO нижче.
    decibels

    # ── PDF / документи ───────────────────────────────────────────────────────
    # Papers — наступник Evince на GTK4/libadwaita. Той самий poppler усередині,
    # тобто якість рендера ідентична, але сучасний UI і sandbox для документів.
    # Програв zathura: чудовий для vim-звичок, але це окремий світ клавіш
    # і жодної інтеграції з рештою.
    papers

    # ── Архіватор ─────────────────────────────────────────────────────────────
    # File Roller + бекенди. Сам по собі file-roller — це лише GUI;
    # без цих бінарників він мовчки не відкриє половину форматів.
    file-roller
    p7zip # 7z, а також rar-розпакування
    unar # найкращий розпакувальник rar/старих форматів з правильними кодуваннями
    unzip
    zip
    gnutar
    xz
    zstd

    # ── Текстовий редактор (GUI) ──────────────────────────────────────────────
    # GNOME Text Editor. Легкий, libadwaita, підсвітка синтаксису.
    # Це НЕ IDE — за твоїм рішенням основна розробка йде через Android Studio
    # і AI-агентів, тож важкий редактор у базі не потрібен.
    gnome-text-editor

    # ── Текстовий редактор (TUI fallback) ─────────────────────────────────────
    # helix. Виграв над neovim саме за твоїм критерієм «не ставити vim просто
    # тому, що Linux»: helix працює з LSP і деревом синтаксису БЕЗ конфігу
    # і без плагін-менеджера. Нуль обслуговування для запасного редактора.
    helix

    # ── Калькулятор ───────────────────────────────────────────────────────────
    # Qalculate. Не «кнопки з цифрами», а рушій: одиниці виміру, валюти,
    # символьні обчислення, ("15% від 2340 грн у доларах" — працює).
    # Програв gnome-calculator: гарніший, але рахує помітно менше.
    qalculate-gtk

    # ── Системний монітор ─────────────────────────────────────────────────────
    # Resources. GTK4/libadwaita, показує CPU/RAM/диски/мережу І GPU
    # (включно з NVIDIA через nvidia-smi) в одному вікні.
    # Програв mission-center: майже те саме, трохи менш точний по GPU.
    # Програв gnome-system-monitor: GTK3, застарілий вигляд.
    resources
    # btop — TUI-варіант, коли GUI вже не відкривається (саме той випадок,
    # коли системний монітор і потрібен).
    btop

    # ── Диски ─────────────────────────────────────────────────────────────────
    gnome-disk-utility # GUI поверх udisks2: розділи, SMART, образи
    baobab # аналізатор зайнятого місця (GTK4)

    # ── Шрифти та емодзі ──────────────────────────────────────────────────────
    gnome-font-viewer # перегляд і встановлення шрифтів
    gnome-characters # емодзі та символи, GTK4
    # Обидва — GNOME-нативні, тобто підхоплять нашу GTK-тему без бубнів.
    # Програв smile: приємний пікер емодзі, але дублює gnome-characters.

    # ── Браузери ──────────────────────────────────────────────────────────────
    # Firefox основний (див. programs.firefox нижче — там policies і VA-API).
    # Chromium для розробки: chrome://inspect для WebView на фізичному
    # Android-пристрої, DevTools, тестування Blink.
    chromium

    # ── Мініатюри ─────────────────────────────────────────────────────────────
    # tumbler — D-Bus-служба мініатюр за стандартом freedesktop.
    # Без неї Nautilus покаже сірі прямокутники замість прев'ю відео.
    tumbler
    ffmpegthumbnailer # мініатюри відео
    webp-pixbuf-loader # webp у GTK-програмах (booru віддає саме webp)
    librsvg # svg у GTK

    # ── Кодеки ────────────────────────────────────────────────────────────────
    # Без цього GTK/GStreamer-програми (Decibels, Celluloid у GStreamer-режимі,
    # прев'ю в Nautilus) не відтворять половину форматів.
    gst_all_1.gst-plugins-base
    gst_all_1.gst-plugins-good
    gst_all_1.gst-plugins-bad
    gst_all_1.gst-plugins-ugly
    gst_all_1.gst-libav
    ffmpeg

    # ── Кошик з CLI ───────────────────────────────────────────────────────────
    # `gio trash` уже є з GVfs; trash-cli додає звичні `trash-list`/`trash-restore`.
    trash-cli

    # ── Перевірка орфографії ──────────────────────────────────────────────────
    # Підхоплюється GTK-програмами і Chromium через enchant автоматично.
    # Канонічні (не-аліасні) імена: у dictionaries.nix `uk_UA = uk-ua;`,
    # тобто підкресленнєва форма — це аліас на дефісну.
    hunspell
    hunspellDicts.uk-ua
    hunspellDicts.en-us

    # ── XDG-інтеграція ────────────────────────────────────────────────────────
    xdg-utils # xdg-open — цим користуються ВСІ програми для «відкрити посилання»
    xdg-user-dirs # створює ~/Завантаження, ~/Документи тощо
    desktop-file-utils # update-desktop-database
    shared-mime-info # база MIME-типів
  ];

  # ── Firefox ─────────────────────────────────────────────────────────────────
  # Через модуль, а не просто пакет: модуль дає декларативні policies,
  # які інакше довелось би класти файлом у профіль.
  programs.firefox = {
    enable = true;

    # Politики застосовуються ДО профілю користувача і не перетираються.
    policies = {
      DisableTelemetry = true;
      DisablePocket = true;
      DisableFirefoxStudies = true;
      # Дозволяємо DRM: без цього Netflix/Spotify-web не працюють.
      EncryptedMediaExtensions = true;
    };

    preferences = {
      # ── Апаратний декод відео ───────────────────────────────────────────────
      # Вмикаємо VA-API (через nvidia-vaapi-driver, див. modules/nvidia.nix).
      "media.ffmpeg.vaapi.enabled" = true;
      "media.rdd-ffmpeg.enabled" = true;
      "gfx.webrender.all" = true;

      # ── КЛЮЧОВЕ ДЛЯ ЦІЄЇ МАШИНИ ─────────────────────────────────────────────
      # GM204 (980M) має апаратний декодер ТІЛЬКИ для H.264.
      # Фіксованого HEVC-декодера у GM204 немає — його отримали лише GM206
      # (GTX 960/950) і GM200. AV1 немає взагалі.
      #
      # YouTube за замовчуванням віддає VP9 або AV1. Обидва підуть у софт,
      # з'їдять CPU і посадять батарею. Вимикаємо їх, щоб YouTube віддавав H.264:
      "media.mediasource.vp9.enabled" = false;
      "media.av1.enabled" = false;
      # Перевірити результат: правий клік на відео → Stats for nerds →
      # у рядку codecs має бути avc1, а не vp09/av01.
    };
  };

  # ── Chromium ────────────────────────────────────────────────────────────────
  # Прапорці для Wayland + VA-API. Без ozone Chromium піде через XWayland
  # і буде розмитим і без апаратного декоду.
  environment.sessionVariables.NIXOS_OZONE_WL = "1";

  # ── MIME: чим що відкривати ─────────────────────────────────────────────────
  # Без цього «відкрити PDF з браузера» або «magnet-посилання» роблять нічого,
  # або відкривають випадкову програму. Це той пункт, який у зібраному стеку
  # найчастіше забувають — і потім два дні дивуються.
  xdg.mime = {
    enable = true;
    defaultApplications = {
      # Тексти
      "text/plain" = "org.gnome.TextEditor.desktop";
      "text/markdown" = "org.gnome.TextEditor.desktop";
      "application/json" = "org.gnome.TextEditor.desktop";

      # Документи
      "application/pdf" = "org.gnome.Papers.desktop";

      # Зображення
      "image/png" = "org.gnome.Loupe.desktop";
      "image/jpeg" = "org.gnome.Loupe.desktop";
      "image/gif" = "org.gnome.Loupe.desktop";
      "image/webp" = "org.gnome.Loupe.desktop";
      "image/svg+xml" = "org.gnome.Loupe.desktop";
      "image/avif" = "org.gnome.Loupe.desktop";

      # Відео
      "video/mp4" = "io.github.celluloid_player.Celluloid.desktop";
      "video/x-matroska" = "io.github.celluloid_player.Celluloid.desktop";
      "video/webm" = "io.github.celluloid_player.Celluloid.desktop";
      "video/quicktime" = "io.github.celluloid_player.Celluloid.desktop";

      # Аудіо
      "audio/mpeg" = "org.gnome.Decibels.desktop";
      "audio/flac" = "org.gnome.Decibels.desktop";
      "audio/x-vorbis+ogg" = "org.gnome.Decibels.desktop";
      "audio/x-wav" = "org.gnome.Decibels.desktop";

      # Архіви
      "application/zip" = "org.gnome.FileRoller.desktop";
      "application/x-7z-compressed" = "org.gnome.FileRoller.desktop";
      "application/vnd.rar" = "org.gnome.FileRoller.desktop";
      "application/x-tar" = "org.gnome.FileRoller.desktop";
      "application/gzip" = "org.gnome.FileRoller.desktop";
      "application/zstd" = "org.gnome.FileRoller.desktop";

      # Теки
      "inode/directory" = "org.gnome.Nautilus.desktop";

      # Посилання — тут вирішується «клікнув лінк у Telegram → відкрився браузер»
      "x-scheme-handler/http" = "firefox.desktop";
      "x-scheme-handler/https" = "firefox.desktop";
      "x-scheme-handler/about" = "firefox.desktop";
      "x-scheme-handler/unknown" = "firefox.desktop";
      # TODO: magnet-посилання нікуди не ведуть, поки не поставиш торент-клієнт.
      # Коли поставиш — додай сюди "x-scheme-handler/magnet".
    };
  };

  # Служба мініатюр має бути піднята на рівні системи, інакше tumbler
  # не зареєструється в D-Bus і Nautilus його не знайде.
  services.tumbler.enable = true;

}
