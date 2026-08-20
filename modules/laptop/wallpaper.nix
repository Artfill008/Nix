# ── Автоматичні шпалери: системна частина ─────────────────────────────────────
#
# Сам інструмент — tools/moewall (Rust). Тут лише те, що має бути на рівні
# системи: каталог стану, таймер і права.
#
# ЧОМУ ОКРЕМИЙ ІНСТРУМЕНТ, А НЕ СКРИПТ:
#  • треба валідувати зображення (декодувати, порахувати гістограму) —
#    у bash це означає ланцюжок з ImageMagick, який мовчки бреше на
#    пошкоджених файлах;
#  • треба тримати індекс уже бачених хешів і чорний список —
#    це стан, а стан у скрипті на bash завжди рано чи пізно псується;
#  • треба ретраї, таймаути і коректна поведінка при відсутності мережі;
#  • треба атомарна заміна поточної шпалери, інакше swaybg зловить
#    напівзаписаний файл.
#
# ЧОМУ /var/lib, А НЕ ~/.cache:
#  поточну шпалеру має читати regreet, який працює від користувача `greeter`
#  ще до входу в сесію. Він фізично не має доступу до /home.
{
  config,
  lib,
  pkgs,
  username,
  ...
}:
let
  cfg = config.gt72s.wallpaper;
in
{
  options.gt72s.wallpaper = {
    enable = lib.mkEnableOption "автоматичні шпалери moewall" // {
      default = true;
    };

    stateDir = lib.mkOption {
      type = lib.types.str;
      default = "/var/lib/moewall";
      description = "Каталог стану: кеш, індекс, поточна шпалера, палітра.";
    };

    interval = lib.mkOption {
      type = lib.types.str;
      default = "6h";
      description = ''
        Як часто міняти шпалеру автоматично.
        Формат systemd OnUnitActiveSec. Постав "0" щоб вимкнути автозміну
        і міняти лише вручну.
      '';
    };

    cacheSize = lib.mkOption {
      type = lib.types.int;
      default = 60;
      description = "Скільки шпалер тримати в локальному кеші (LRU).";
    };

    tags = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [
        # Safebooru за визначенням містить лише safe-контент, але явний
        # rating:safe лишаємо як другий бар'єр — на випадок помилок індексації.
        "rating:safe"
        # Формат: шукаємо саме шпалери, а не арт довільної форми.
        "wallpaper"
        # Роздільна здатність: absurdres = >= 3200px по стороні,
        # highres = >= 1600px. Беремо highres, щоб не відсікти рівно 1920x1080.
        "highres"
        # Прибираємо те, що майже завжди дає світлий або порожній фон.
        "-monochrome"
        "-greyscale"
        "-sketch"
        "-comic"
        "-4koma"
        "-photo"
        "-simple_background"
        "-white_background"
        "-transparent_background"
      ];
      description = ''
        Теги запиту до Safebooru. Синтаксис — той самий, що на сайті.
        Мінус перед тегом = виключити.

        ⚠ ПЕРЕВІР ЗАПИТ ВРУЧНУ ПЕРЕД ЗБІРКОЮ:
          curl -s 'https://safebooru.org/index.php?page=dapi&s=post&q=index&json=1&limit=5&tags=rating:safe+wallpaper+highres' | head -c 2000
        Я НЕ ЗМІГ перевірити цей endpoint звідси — safebooru.org заблокований
        проксі мого середовища. Структуру API (page=dapi&s=post&q=index,
        параметри tags/limit/pid/json, стеля limit=1000) я звірив за
        документацією сайту через кеш пошуку, але поля відповіді —
        НЕ перевіряв. moewall написаний терпимо до обох варіантів
        (file_url або directory+image), але якщо запит поверне порожнечу —
        першим ділом дивись саме сюди.
      '';
    };

    preferHues = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [
        "green"
        "blue"
        "purple"
        "cyan"
        "teal"
      ];
      description = "Бажані домінантні відтінки (використовується в оцінці).";
    };

    maxMeanLuma = lib.mkOption {
      type = lib.types.int;
      default = 110;
      description = ''
        Максимальна середня яскравість (0-255). Вище — вважаємо
        «засвічене / переважно біле» і відкидаємо.
        110 ≈ помірно темне зображення. Підніми до 130, якщо кандидатів мало.
      '';
    };

    minSaturation = lib.mkOption {
      type = lib.types.int;
      default = 40;
      description = ''
        Мінімальна середня насиченість (0-255). Відсікає washed-out
        і майже сірі зображення, які дають нудну палітру matugen.
      '';
    };
  };

  config = lib.mkIf cfg.enable {

    # Каталог стану належить користувачу (щоб user-сервіс міг писати),
    # але читається всіма (щоб regreet від імені `greeter` бачив шпалеру).
    systemd.tmpfiles.rules = [
      "d ${cfg.stateDir}       0755 ${username} users - -"
      "d ${cfg.stateDir}/cache 0755 ${username} users - -"
    ];

    # Конфіг інструмента генерується з Nix — тобто фільтри теж декларативні.
    environment.etc."moewall/config.toml".text = ''
      # ЗГЕНЕРОВАНО з modules/laptop/wallpaper.nix. Руками не редагувати.
      state_dir   = "${cfg.stateDir}"
      cache_size  = ${toString cfg.cacheSize}

      [source]
      kind     = "safebooru"
      base_url = "https://safebooru.org/index.php"
      tags     = ${builtins.toJSON cfg.tags}
      # Скільки постів тягнути за один запит (стеля API — 1000).
      page_limit = 100
      # Скільки сторінок максимум переглянути, поки не назбираємо кандидатів.
      max_pages  = 5

      [filter]
      # Точне 16:9 = 1.7778. Допуск ±0.06 пропускає 16:10 (1.6) — ні,
      # 1.6 відсікається; пропускає 1.85:1 (кіно) — так, і це нормально.
      target_aspect    = 1.7778
      aspect_tolerance = 0.06
      min_width        = 1920
      min_height       = 1080
      # Відсікає «розтягнуті мініатюри»: файл, менший за 250 КБ при 1080p,
      # майже завжди перетиснутий JPEG з артефактами.
      min_bytes        = 250000
      # Верхня межа: 4K-PNG на 30 МБ немає сенсу качати на 1080p-екран.
      max_bytes        = 15000000
      max_mean_luma    = ${toString cfg.maxMeanLuma}
      min_saturation   = ${toString cfg.minSaturation}
      prefer_hues      = ${builtins.toJSON cfg.preferHues}

      [apply]
      # matugen викликається з цим режимом; dark — бо тема темна.
      matugen_mode   = "dark"
      # Куди покласти поточну шпалеру (її читає і swaybg, і regreet).
      current_link   = "${cfg.stateDir}/current.png"
      # Файл палітри для RGB-підсвітки (див. modules/laptop/rgb.nix).
      rgb_palette    = "${cfg.stateDir}/rgb-colors.sh"
    '';

    # ── Таймер автозміни ──────────────────────────────────────────────────────
    # Це USER-таймер, а не системний: застосування шпалери потребує
    # WAYLAND_DISPLAY, тобто живої сесії.
    systemd.user.services.moewall = {
      description = "moewall: оновити шпалеру і палітру";
      # Не запускати, поки немає сесії — інакше swaybg не зможе під'єднатись.
      after = [ "graphical-session.target" ];
      partOf = [ "graphical-session.target" ];
      serviceConfig = {
        Type = "oneshot";
        ExecStart = "${lib.getExe pkgs.moewall} next";
        # Мережа може бути недоступна — це не привід сипати помилками в журнал.
        SuccessExitStatus = [
          0
          75
        ]; # 75 = EX_TEMPFAIL, наш код для «нема мережі»
      };
    };

    systemd.user.timers.moewall = lib.mkIf (cfg.interval != "0") {
      description = "moewall: періодична зміна шпалери";
      wantedBy = [ "timers.target" ];
      timerConfig = {
        OnUnitActiveSec = cfg.interval;
        # Перший запуск через 2 хвилини після старту сесії — щоб не змагатись
        # за мережу з NetworkManager під час логіну.
        OnStartupSec = "2min";
        # Розкид, щоб не збігатися з іншими таймерами.
        RandomizedDelaySec = "5min";
        Persistent = true;
      };
    };

    # ── Пункти в лаунчері ─────────────────────────────────────────────────────
    # Це звичайні .desktop-файли, тому вони автоматично з'являться у fuzzel.
    environment.systemPackages = [
      pkgs.moewall
      pkgs.matugen
      pkgs.swaybg

      (pkgs.makeDesktopItem {
        name = "moewall-next";
        desktopName = "Шпалери: наступна";
        icon = "preferences-desktop-wallpaper";
        exec = "${lib.getExe pkgs.moewall} next";
        categories = [ "Settings" ];
        keywords = [
          "wallpaper"
          "moewall"
        ];
      })
      (pkgs.makeDesktopItem {
        name = "moewall-refresh";
        desktopName = "Шпалери: завантажити нові";
        icon = "view-refresh";
        exec = "${lib.getExe pkgs.moewall} refresh";
        categories = [ "Settings" ];
      })
      (pkgs.makeDesktopItem {
        name = "moewall-keep";
        desktopName = "Шпалери: залишити в улюблених";
        icon = "starred";
        exec = "${lib.getExe pkgs.moewall} keep";
        categories = [ "Settings" ];
      })
      (pkgs.makeDesktopItem {
        name = "moewall-blacklist";
        desktopName = "Шпалери: у чорний список";
        icon = "edit-delete";
        exec = "${lib.getExe pkgs.moewall} blacklist";
        categories = [ "Settings" ];
      })
    ];
  };
}
