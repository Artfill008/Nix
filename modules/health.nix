# Health-check як частина системи, а не скрипт у dotfiles.
#
# ПРИНЦИП: «nix build успішний» НЕ доводить, що апаратна інтеграція працює.
# Збірка перевіряє, що конфігурація коректна. Цей модуль перевіряє,
# що РАНТАЙМ відповідає тому, що ми задекларували.
{
  config,
  lib,
  pkgs,
  ...
}:
{
  environment.systemPackages = with pkgs; [
    gt72

    # Інструменти, які gt72 використовує опційно, але без яких перевірки
    # мовчки деградують до WARNING. Ставимо, бо діагностика має працювати.
    libva-utils # vainfo — перевірка апаратного декоду (H.264 vs HEVC)
    alsa-utils # amixer — діагностика сабвуфера
    nvtopPackages.nvidia # інтерактивний монітор GPU
  ];

  # ── Перевірка після кожного switch ──────────────────────────────────────────
  # Не блокує активацію: якщо health впаде, система вже працює на новому
  # поколінні, і ти просто побачиш, що саме не так.
  # Логи: journalctl -u fennec-health
  systemd.services.fennec-health = {
    description = "Перевірка відповідності рантайму задекларованому конфігу";
    wantedBy = [ "multi-user.target" ];
    after = [
      "multi-user.target"
      "nvidia-persistenced.service"
    ];

    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = false;
      # Перевірки лише читають. Жодних змін стану.
      ProtectSystem = "strict";
      ProtectHome = "read-only";
      PrivateTmp = true;
      # health повертає ненуль при FAIL — це нормальний сигнал, а не аварія
      # юніта, тому не хочемо нескінченних рестартів.
      SuccessExitStatus = "0 1";
    };

    # Розділи, які мають сенс поза графічною сесією.
    # session/android перевіряються вручну з-під сесії: у системному
    # контексті немає ні WAYLAND_DISPLAY, ні шини користувача.
    script = ''
      ${lib.getExe pkgs.gt72} health kernel   || true
      ${lib.getExe pkgs.gt72} health nvidia   || true
      ${lib.getExe pkgs.gt72} health performance || true
      ${lib.getExe pkgs.gt72} health storage  || true
      ${lib.getExe pkgs.gt72} health services || true
    '';
  };

  # ── Нагадування при вході ───────────────────────────────────────────────────
  # Якщо після завантаження щось у FAIL — хочемо дізнатись одразу,
  # а не через тиждень, коли «чомусь не працює шаринг екрана».
  environment.etc."fennec/acceptance-test.md".text = ''
    # Acceptance test після першої збірки

    Система вважається готовою, ЛИШЕ якщо всі пункти проходять.
    Це не побажання: якщо щось із базового не працює — це TODO конфігурації,
    а не «користувач доставить сам».

    ## Автоматично
        gt72 health                 # усе
        gt72 health session         # з-під графічної сесії!
        gt72 health android

    ## Вручну — по одному сценарію
    - [ ] Завантажитись у ReGreet і залогінитись
    - [ ] Mango стартує, scroller-розкладка активна
    - [ ] Термінал відкривається (Super+Enter)
    - [ ] Лаунчер відкривається і запускає програму
    - [ ] Firefox відкривається, YouTube грає в H.264 (Stats for nerds → avc1)
    - [ ] Nautilus відкривається, показує мініатюри відео
    - [ ] ZIP відкривається подвійним кліком (File Roller)
    - [ ] PDF відкривається (Papers), картинка (Loupe), відео (Celluloid)
    - [ ] USB-флешка монтується сама, видно в Nautilus
    - [ ] Android по USB: adb devices показує пристрій
    - [ ] Android по USB: файли видно в Nautilus (MTP через GVfs)
    - [ ] Bluetooth-навушники підключаються і звук іде в них
    - [ ] Screenshot: область → редактор satty → у буфер
    - [ ] Запис екрана: gpu-screen-recorder пише файл
    - [ ] Шаринг екрана в браузері (МОНІТОР, не вікно — вибору вікна немає)
    - [ ] Clipboard: копіювання картинки між програмами
    - [ ] Clipboard: історія через cliphist у лаунчері
    - [ ] Polkit: gnome-disk-utility просить пароль і приймає його
    - [ ] Fn-яскравість працює І показує OSD
    - [ ] Fn-гучність працює І показує OSD
    - [ ] Lock (wlogout або bind) і розблокування
    - [ ] Suspend → resume: екран повертається, НЕ чорний
    - [ ] Закриття кришки → сон
    - [ ] Другий монітор: підключити, kanshi розкладає сам
    - [ ] Reboot і shutdown із меню
    - [ ] virt-manager стартує, ВМ створюється і завантажується
    - [ ] Android Studio стартує, SDK-бінарники запускаються (nix-ld!)
    - [ ] Емулятор Android стартує з прискоренням KVM
    - [ ] GeForce NOW (Flatpak) стартує і стрімить у H.264

    ## Якщо система не завантажилась
    1. У меню systemd-boot вибери попереднє покоління (стрілки + Enter).
    2. Завантажся, подивись що зламалось:
           journalctl -b -1 -p err
    3. Якщо не збирається NVIDIA — спусти гілку ядра на сходинку нижче
       в hosts/gt72s/default.nix:
           fennec.kernel.channel = "lts";
    4. Якщо не стартує графіка — увійди в tty (Ctrl+Alt+F2) і:
           gt72 health nvidia
  '';
}
