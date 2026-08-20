# УВАГА: цей файл — ШАБЛОН. Він НЕ згенерований на твоїй машині.
#
# Перед першою збіркою зроби так:
#   sudo nixos-generate-config --root /mnt --no-filesystems   # у live-середовищі
# або, якщо система вже стоїть:
#   sudo nixos-generate-config --show-hardware-config
# і ЗАМІНИ вміст цього файлу згенерованим, залишивши мої btrfs-опції нижче.
#
# UUID нижче — плейсхолдери. Реальні бери з `blkid` або `lsblk -f`.
{
  config,
  lib,
  pkgs,
  modulesPath,
  ...
}:
{
  imports = [
    (modulesPath + "/installer/scan/not-detected.nix")
  ];

  # ── initrd ──────────────────────────────────────────────────────────────────
  # nvme — щоб побачити 970 EVO Plus; xhci_pci/usb_storage — USB-клавіатура і
  # флешки на етапі initrd (знадобиться, якщо колись додаси LUKS).
  boot.initrd.availableKernelModules = [
    "xhci_pci"
    "ahci"
    "nvme"
    "usb_storage"
    "usbhid"
    "sd_mod"
    "rtsx_pci_sdmmc"
  ];
  boot.initrd.kernelModules = [ ];

  # kvm-intel — апаратна віртуалізація для libvirt.
  boot.kernelModules = [ "kvm-intel" ];
  boot.extraModulePackages = [ ];

  # ── Файлові системи ─────────────────────────────────────────────────────────
  # btrfs із підтомами. Опції підібрані під NVMe + SSD:
  #   compress=zstd:1 — рівень 1, не 3: на NVMe вузьке місце — CPU, не диск.
  #                     zstd:1 дає ~2x стиснення майже безкоштовно.
  #   noatime         — прибирає запис часу доступу при кожному читанні.
  #   ssd             — btrfs-алокатор під SSD (зазвичай визначає сам, ставимо явно).
  #   space_cache=v2  — новий формат кешу вільного місця, швидше монтується.
  #   discard=async   — TRIM у фоні, не блокує операції (краще за fstrim-таймер).
  #
  # TODO: заміни UUID на свої.
  fileSystems."/" = {
    device = "/dev/disk/by-uuid/00000000-0000-0000-0000-000000000000";
    fsType = "btrfs";
    options = [
      "subvol=@"
      "compress=zstd:1"
      "noatime"
      "ssd"
      "space_cache=v2"
      "discard=async"
    ];
  };

  fileSystems."/home" = {
    device = "/dev/disk/by-uuid/00000000-0000-0000-0000-000000000000";
    fsType = "btrfs";
    options = [
      "subvol=@home"
      "compress=zstd:1"
      "noatime"
      "ssd"
      "space_cache=v2"
      "discard=async"
    ];
  };

  # /nix окремим підтомом і БЕЗ compress-force: стор і так переважно стиснений,
  # а компресія на кожному читанні бінарників з'їдає CPU.
  fileSystems."/nix" = {
    device = "/dev/disk/by-uuid/00000000-0000-0000-0000-000000000000";
    fsType = "btrfs";
    options = [
      "subvol=@nix"
      "compress=zstd:1"
      "noatime"
      "ssd"
      "space_cache=v2"
      "discard=async"
    ];
  };

  # Окремий підтом під снапшоти. Тримати /var/log поза @ корисно, бо інакше
  # кожен снапшот кореня тягне за собою журнали.
  fileSystems."/var/log" = {
    device = "/dev/disk/by-uuid/00000000-0000-0000-0000-000000000000";
    fsType = "btrfs";
    options = [
      "subvol=@log"
      "compress=zstd:1"
      "noatime"
      "ssd"
      "space_cache=v2"
      "discard=async"
    ];
    neededForBoot = true;
  };

  # ── btrfs top-level ─────────────────────────────────────────────────────────
  # subvolid=5 — це КОРІНЬ файлової системи, над усіма підтомами.
  # Потрібен btrbk: щоб створювати снапшоти сусідніх підтомів (@ і @home)
  # і складати їх у @snapshots, він має бачити їх усі з одного місця.
  # Без цього монтування @snapshots існує на диску, але недосяжний —
  # саме це і було знайдено аудитом як A-022.
  #
  # noexec/nosuid/nodev: тут не запускається нічого, це суто службова точка.
  # TODO: той самий UUID, що й у решти підтомів.
  fileSystems."/.btrfs" = {
    device = "/dev/disk/by-uuid/00000000-0000-0000-0000-000000000000";
    fsType = "btrfs";
    options = [
      "subvolid=5"
      "noatime"
      "ssd"
      "space_cache=v2"
      "nosuid"
      "nodev"
      "noexec"
    ];
  };

  # TODO: заміни UUID ESP-розділу (він короткий, вигляду 1234-ABCD).
  fileSystems."/boot" = {
    device = "/dev/disk/by-uuid/0000-0000";
    fsType = "vfat";
    options = [
      "fmask=0077"
      "dmask=0077"
    ];
  };

  # Swap-розділу немає — свідомо. Замість нього zram (див. modules/performance.nix).
  swapDevices = [ ];

  # ── Btrfs scrub ─────────────────────────────────────────────────────────────
  # Раз на місяць перевіряє контрольні суми всіх даних. На NVMe це швидко
  # і це єдиний спосіб дізнатись про тиху деградацію ДО того, як щось зламається.
  services.btrfs.autoScrub = {
    enable = true;
    interval = "monthly";
    fileSystems = [ "/" ];
  };

  # ── Мікрокод і платформа ────────────────────────────────────────────────────
  # Skylake має рівно один достойний спосіб отримати виправлення — мікрокод.
  # Особливо важливо, бо ти вимкнув програмні мітигації (див. performance.nix).
  hardware.cpu.intel.updateMicrocode = lib.mkDefault config.hardware.enableRedistributableFirmware;
  hardware.enableRedistributableFirmware = true;

  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";

  # У GT72S апаратний MUX: iGPU (HD 530) вимкнена в BIOS, малює лише 980M.
  # Тому НЕ вмикаємо hardware.nvidia.prime і не тягнемо intel-media-driver
  # для рендера — але лишаємо i915 доступним, якщо колись переключиш MUX.
  # TODO: якщо в BIOS увімкнеш Optimus/switchable — треба буде додати prime-конфіг.
}
