# Обслуговування сховища. Те, чого не було у твоєму початковому списку,
# але без чого btrfs тихо деградує, а NVMe вмирає без попередження.
{
  config,
  lib,
  pkgs,
  username,
  ...
}:
{
  # ── Снапшоти: snapper ───────────────────────────────────────────────────────
  # Твій вибір. Дає ДРУГИЙ, незалежний рівень відкату:
  #   NixOS generations відкочують СИСТЕМУ (/nix/store + конфіг),
  #   snapper відкочує ДАНІ (/home) і стан кореня.
  # Одне не замінює інше: rollback покоління не поверне видалений файл,
  # а снапшот не поверне зламану конфігурацію ядра.
  #
  # ВАЖЛИВО ПРО РОЗКЛАДКУ: snapper вимагає, щоб у підтомі існував вкладений
  # підтом .snapshots. Розкладка @ @home @nix @log @snapshots саме під це.
  # /nix свідомо НЕ снапшотимо — він відтворюється з flake.lock, а снапшоти
  # стору з'їли б увесь диск за тиждень.
  services.snapper = {
    # Прибирає старі снапшоти за розкладом.
    cleanupInterval = "1d";
    # Робити снапшот кореня при кожному завантаженні. Дешево і рятує,
    # коли зрозумів «щось зламав» уже після reboot.
    snapshotRootOnBoot = true;
    # Таймери переживають вимкнений ноут: після ввімкнення пропущений
    # запуск відбудеться, а не загубиться.
    persistentTimer = true;

    configs = {
      home = {
        SUBVOLUME = "/home";
        # Дозволяємо тобі дивитись і відкочувати снапшоти без sudo.
        ALLOW_USERS = [ username ];
        TIMELINE_CREATE = true;
        TIMELINE_CLEANUP = true;
        # Скільки тримати. Підібрано під 1 ТБ NVMe і те, що btrfs-снапшоти
        # займають місце лише під ЗМІНИ, а не під копію.
        TIMELINE_LIMIT_HOURLY = 6; # останні 6 годин
        TIMELINE_LIMIT_DAILY = 7; # тиждень по днях
        TIMELINE_LIMIT_WEEKLY = 4; # місяць по тижнях
        TIMELINE_LIMIT_MONTHLY = 3;
        TIMELINE_LIMIT_QUARTERLY = 0;
        TIMELINE_LIMIT_YEARLY = 0;
      };

      root = {
        SUBVOLUME = "/";
        ALLOW_USERS = [ username ];
        # Корінь по таймеру НЕ знімаємо: на NixOS він майже незмінний,
        # усе цікаве живе в /nix і в /home. Знімок при завантаженні
        # (snapshotRootOnBoot вище) — достатньо.
        TIMELINE_CREATE = false;
        TIMELINE_CLEANUP = true;
        TIMELINE_LIMIT_DAILY = 3;
      };
    };
  };

  # ── SMART / здоров'я NVMe ───────────────────────────────────────────────────
  # 970 EVO Plus — хороший диск, але це TLC із обмеженим ресурсом запису,
  # а /nix пише багато. Хочемо знати про зношення ДО відмови.
  services.smartd = {
    enable = true;
    # Сповіщення на десктоп, а не листом у нікуди.
    notifications.wall.enable = true;
    autodetected = true;
    defaults.autodetected = "-a -o on -S on -s (S/../.././02|L/../../6/03)";
  };

  # nvme-cli для ручної перевірки: `sudo nvme smart-log /dev/nvme0`
  # Показує percentage_used, media_errors, температуру.
  environment.systemPackages = with pkgs; [
    nvme-cli
    smartmontools
    compsize # скільки реально займають дані на btrfs після стиснення
    btrfs-progs
  ];

  # ── TRIM ────────────────────────────────────────────────────────────────────
  # У hardware-configuration.nix підтоми монтуються з discard=async —
  # це безперервний фоновий TRIM, і його зазвичай достатньо.
  # Періодичний fstrim лишаємо ВИМКНЕНИМ свідомо: два механізми TRIM
  # одночасно не ламають диск, але дублюють роботу.
  # Якщо колись прибереш discard=async — увімкни це.
  services.fstrim.enable = false;

  # ── Журнал і дампи ──────────────────────────────────────────────────────────
  # Coredump за замовчуванням може з'їсти гігабайти після падіння
  # чогось великого (браузер, емулятор Android).
  systemd.coredump = {
    enable = true;
    extraConfig = ''
      Storage=external
      Compress=yes
      MaxUse=2G
      KeepFree=5G
      ProcessSizeMax=8G
    '';
  };
}
