# Головний файл хоста. Тільки склеювання модулів + речі, специфічні саме
# для цієї машини. Логіка живе в ./modules/*.
{
  config,
  pkgs,
  lib,
  username,
  hostname,
  ...
}:
{
  imports = [
    ./hardware-configuration.nix

    # ── Система ───────────────────────────────────────────────────────────────
    ../../modules/kernel.nix       # вибір гілки ядра + assertion на пару з NVIDIA
    ../../modules/nvidia.nix
    ../../modules/performance.nix
    ../../modules/storage.nix      # snapper, SMART, coredump
    ../../modules/virtualisation.nix

    # ── Сесія і робочий стіл ──────────────────────────────────────────────────
    ../../modules/desktop.nix

    # ── Програми ──────────────────────────────────────────────────────────────
    ../../modules/apps.nix         # щоденні програми, MIME, кодеки, мініатюри
    ../../modules/dev.nix          # AI-агенти, build-інфраструктура, контейнери
    ../../modules/android.nix      # Android Studio, adb, nix-ld, udev
    ../../modules/flatpak.nix      # інфраструктура Flatpak + GeForce NOW
    ../../modules/health.nix       # gt72 + перевірка «конфіг vs рантайм»

    # ── Написані, але вимкнені ────────────────────────────────────────────────
    # Кожен вмикається одним рядком нижче в цьому ж файлі.
    ../../modules/gaming.nix       # fennec.gaming.enable
    ../../modules/printing.nix     # fennec.printing.enable

    # Файл, яким володіє ТІЛЬКИ інструмент nixmgr. Руками не редагуємо.
    ../../modules/managed-packages.nix

    # Ноутбук-специфічні модулі. Кожен вимикається одним рядком.
    ../../modules/laptop/msi-ec.nix
    ../../modules/laptop/rgb.nix
    ../../modules/laptop/audio-subwoofer.nix
    ../../modules/laptop/panel-75hz.nix
    ../../modules/laptop/wallpaper.nix
  ];

  # ── Завантажувач ────────────────────────────────────────────────────────────
  # systemd-boot, бо UEFI + NVMe + жодного dual-boot складняка.
  # Програв GRUB: більше рухомих частин, повільніший, і його btrfs-підтримка
  # тут не потрібна (initrd вміє змонтувати btrfs сам).
  boot.loader.systemd-boot = {
    enable = true;
    # Тримаємо 10 поколінь: /boot на цих ноутах зазвичай 512 МБ-1 ГБ, а кожне
    # покоління з nvidia-модулем важить помітно. Якщо /boot великий — підніми.
    configurationLimit = 10;
    # Редактор у меню boot дозволяє дописати init=/bin/sh → обхід пароля.
    editor = false;
  };
  boot.loader.efi.canTouchEfiVariables = true;

  # Затримка меню: 3 с достатньо, щоб встигнути вибрати попереднє покоління,
  # коли поточне не завантажилось. Не став 0 — це твоя страховка.
  boot.loader.timeout = 3;

  networking.hostName = hostname;

  # ── Гілка ядра ──────────────────────────────────────────────────────────────
  # За твоїм рішенням: 6.18 як база, 7.2 доступне одним рядком.
  #
  # Щоб перейти на 7.2, треба ДВА рядки — і це навмисно, а не незручність:
  #     fennec.kernel.channel = "latest";
  #     fennec.kernel.acknowledgeUntestedNvidia = true;
  # Другий рядок існує, щоб ти не дізнався про несумісність з legacy_580
  # уже після reboot. Деталі — у modules/kernel.nix.
  fennec.kernel.channel = "default";

  # ── Вимкнені за твоїм рішенням ──────────────────────────────────────────────
  # Обидва модулі написані повністю. Вмикаються тут.
  fennec.gaming.enable = false;   # основний ігровий шлях — GeForce NOW
  fennec.printing.enable = false; # мінус три фонові служби і mDNS у мережі

  # NetworkManager, бо Wi-Fi + профілі + аплет у треї.
  # Програли: systemd-networkd (нема зручного GUI під Wi-Fi),
  # iwd напряму (менше жиру, але гірша інтеграція з nm-applet/blueman).
  networking.networkmanager = {
    enable = true;
    # iwd як бекенд замість wpa_supplicant: швидше сканування і роумінг,
    # менше RAM. Мінус: деякі корпоративні EAP-конфіги простіші на wpa_supplicant.
    wifi.backend = "iwd";
  };

  # firewalld немає; nftables-бекенд nixos-firewall достатньо.
  networking.firewall.enable = true;

  # ── Локаль / час ────────────────────────────────────────────────────────────
  # TODO: перевір, що це твої налаштування.
  time.timeZone = "Europe/Kyiv";
  i18n.defaultLocale = "en_US.UTF-8";
  i18n.extraLocaleSettings = {
    # Інтерфейс англійською (менше кривих перекладів), формати — українські.
    LC_TIME = "uk_UA.UTF-8";
    LC_MONETARY = "uk_UA.UTF-8";
    LC_MEASUREMENT = "uk_UA.UTF-8";
  };
  i18n.supportedLocales = [
    "en_US.UTF-8/UTF-8"
    "uk_UA.UTF-8/UTF-8"
    "C.UTF-8/UTF-8"
  ];

  # ── Клавіатура ──────────────────────────────────────────────────────────────
  # Одне джерело правди для розкладок. Його читають:
  #   • ReGreet (екран логіну) — через services.xserver.xkb
  #   • XWayland-програми (Android Studio, емулятор) — звідти ж
  #   • Mango — окремо, у home/mango.nix (xkb_rules_layout=ua,us)
  # Тримай ці два місця синхронними; health-check це перевіряє.
  services.xserver.xkb = {
    layout = "ua,us";
    options = "grp:alt_shift_toggle";
  };

  # Консоль лишаємо на us: у tty ти набираєш шляхи і команди, а не текст.
  # Кирилиця в tty без потреби лише заважає, коли треба щось полагодити.
  console.keyMap = "us";

  # ── Користувач ──────────────────────────────────────────────────────────────
  users.users.${username} = {
    isNormalUser = true;
    description = "Primary user";
    extraGroups = [
      "wheel" # sudo
      "networkmanager" # керування мережею без sudo
      "video" # brightnessctl, DRM-вузли
      "input" # доступ до /dev/input (потрібно деяким інструментам)
      "libvirtd" # ВМ без sudo
      "kvm"
      "audio"
    ];
    shell = pkgs.fish;
  };

  # Fish має бути ввімкнений на рівні системи, інакше не буде completions
  # для системних пакетів і chsh не прийме шелл.
  programs.fish.enable = true;

  # ── Nix ─────────────────────────────────────────────────────────────────────
  nix = {
    settings = {
      experimental-features = [
        "nix-command"
        "flakes"
      ];
      # 4C/8T: паралельні збірки допомагають, але не задирай — 48 ГБ RAM
      # закінчаться на linking великих C++ проєктів.
      max-jobs = 4;
      cores = 0; # 0 = використовувати всі потоки в межах одного job
      auto-optimise-store = true;
      # Довірені юзери можуть додавати підмінні кеші без rebuild.
      trusted-users = [
        "root"
        username
      ];
      substituters = [
        "https://cache.nixos.org"
        "https://nix-community.cachix.org"
      ];
      trusted-public-keys = [
        "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY="
        "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
      ];
    };

    gc = {
      automatic = true;
      dates = "weekly";
      options = "--delete-older-than 21d";
    };
  };

  # Дозволяємо unfree глобально (nvidia). Явно, щоб було видно в конфізі.
  nixpkgs.config.allowUnfree = true;

  # ── Базовий системний тулінг ────────────────────────────────────────────────
  environment.systemPackages = with pkgs; [
    git
    vim
    wget
    curl
    pciutils # lspci — знадобиться для перевірки GPU
    usbutils # lsusb — знадобиться для перевірки клавіатури SteelSeries
    dmidecode # dmidecode -s bios-version — потрібно для msi-ec
    lm_sensors # sensors — температури
    file
    tree
    unzip

    # Якість життя навколо nixos-rebuild
    nix-output-monitor # nom: читабельний прогрес збірки
    nvd # nvd diff: що саме змінилось між поколіннями
    nh # обгортка над nixos-rebuild з нормальним UX
  ];

  # Цей рядок НЕ означає версію системи. Він фіксує сумісність stateful-даних
  # (формат бази PostgreSQL тощо). Не міняй його при оновленнях.
  # TODO: постав ту версію, з інсталятора якої ти ставив систему.
  system.stateVersion = "26.05";
}
