# GTX 980M (GM204, Maxwell 2.0) — найделікатніша частина конфігу.
#
# ФАКТИ, ПЕРЕВІРЕНІ НА ВИХІДНИКАХ nixpkgs (а не з пам'яті):
#
#  1. `nvidiaPackages.legacy_580` ІСНУЄ і в nixos-unstable (580.178.04),
#     і в nixos-26.05 (580.173.02).
#     Джерело: pkgs/os-specific/linux/nvidia-x11/default.nix, атрибут legacy_580.
#     Ручний overlay-пін НЕ потрібен. Варіант із оверлеєм — унизу файлу,
#     на випадок, якщо атрибут колись приберуть.
#
#  2. Набір `nvidiaPackages` будується як
#        lib.makeExtensible (_: callPackage ../os-specific/linux/nvidia-x11 { })
#     у pkgs/top-level/linux-kernels.nix. Тобто в ньому є ВСЕ, що визначено
#     в default.nix драйвера. Те, що в linux-kernels.nix немає аліаса
#     `nvidia_x11_legacy580` (є тільки для 340/390/470/535) — на нас не впливає.
#     Баг nixpkgs#503740 про «legacy_580 недоступний» закритий через PR #505263.
#
#  3. `hardware.nvidia.open` тепер ОБОВ'ЯЗКОВИЙ: у модулі стоїть assertion
#        assertion = cfg.open != null || cfg.datacenter.enable;
#     з текстом «You must configure hardware.nvidia.open on NVIDIA driver
#     versions >= 560». Без явного значення збірка впаде.
#     Для Maxwell відповідь однозначна: false.
#
#  ЧОМУ НЕ open-модулі: open-gpu-kernel-modules вимагають GSP-мікроконтролера
#  на самій карті. GSP з'явився в Turing (TU10x). У GM204 його фізично немає —
#  open-модуль просто не знайде пристрій. Це не питання версії драйвера.
#
#  ЧОМУ НЕ 590+: у гілці 590 NVIDIA викинула підтримку Maxwell/Pascal/Volta.
#  580 — це LTSB-гілка, підтримується до серпня 2028 (коментар у default.nix).
{
  config,
  lib,
  pkgs,
  ...
}:
{
  # ── Ядро ────────────────────────────────────────────────────────────────────
  # 6.12 LTS — свідомий вибір, а не «найновіше».
  #  + sched_ext (scx) вимагає >= 6.12 — це рівно мінімум, і він LTS;
  #  + пропрієтарний 580 гарантовано збирається проти нього;
  #  + msi-ec (out-of-tree) вимагає >= 6.5.
  #
  # Саме ЗНАЧЕННЯ гілки ядра тут більше не задається. Воно живе в
  # modules/kernel.nix як опція fennec.kernel.channel зі сходами
  # latest(7.2) → recent(7.1) → default(6.18) → lts(6.12) і з assertion,
  # який зупиняє збірку на неперевіреній парі «ядро × legacy_580» ДО того,
  # як ти витратиш пів години на компіляцію.
  #
  # Причина такого розділення: вибір ядра — це рішення про ризик, а не про
  # відеодрайвер. Тримати його в nvidia.nix означало б, що зміна ядра
  # виглядає як зміна конфігурації GPU.

  # ── Драйвер ─────────────────────────────────────────────────────────────────
  # videoDrivers треба задати навіть для чистого Wayland: цей список — тригер,
  # по якому модуль nvidia.nix взагалі вмикає свою логіку
  # (`nvidiaEnabled = lib.elem "nvidia" config.services.xserver.videoDrivers`).
  services.xserver.videoDrivers = [ "nvidia" ];

  hardware.graphics = {
    enable = true;
    # 32-бітні бібліотеки — для Steam/Wine/старих ігор. Коштує місця на диску,
    # не коштує RAM. Якщо ігри не потрібні — вимкни.
    enable32Bit = true;
  };

  hardware.nvidia = {
    package = config.boot.kernelPackages.nvidiaPackages.legacy_580;

    # Maxwell не має GSP → тільки пропрієтарні модулі. Див. пояснення вгорі.
    open = false;

    # KMS обов'язковий: без нього не буде ні Wayland, ні нормального
    # перемикання VT. Модуль сам додасть nvidia-drm.modeset=1.
    modesetting.enable = true;

    # Вмикає NVreg_PreserveVideoMemoryAllocations=1 і сервіси
    # nvidia-suspend/resume/hibernate. Це ЄДИНИЙ спосіб на NVIDIA не отримати
    # чорний екран або пошкоджені текстури після виходу зі сну:
    # вміст VRAM зберігається в RAM, а не втрачається.
    # Ціна: 4 ГБ VRAM пишуться в RAM при засинанні (у тебе 48 ГБ — не проблема).
    powerManagement.enable = true;

    # finegrained — це runtime-PM для Optimus (вимикання dGPU, коли не потрібна).
    # У нас MUX, дискретка завжди активна → false. Ввімкнення тут лише зламає сон.
    powerManagement.finegrained = false;

    # nvidia-settings як GUI. На Wayland він майже марний (більшість вкладок
    # працює лише під X11), але лишаємо — знадобиться для перевірки clocks/temp.
    nvidiaSettings = true;
  };

  # ── Змінні середовища для Wayland ───────────────────────────────────────────
  # Ставимо системно, бо їх мають бачити і greetd/regreet, і сама сесія.
  environment.sessionVariables = {
    # GBM-бекенд NVIDIA — те, через що wlroots отримує буфери.
    GBM_BACKEND = "nvidia-drm";
    # Щоб GLX/EGL-додатки під XWayland брали саме nvidia-реалізацію.
    __GLX_VENDOR_LIBRARY_NAME = "nvidia";
    # Electron/Chromium: вмикає нативний Wayland замість XWayland.
    NIXOS_OZONE_WL = "1";

    # VA-API через NVDEC. На GM204 апаратно декодуються H.264 і HEVC 8-bit;
    # AV1 і VP9 profile 2 — НІ (їх немає в кремнії). mpv все одно впорається
    # софтом на 4 ядрах для 1080p.
    LIBVA_DRIVER_NAME = "nvidia";
    NVD_BACKEND = "direct"; # без цього nvidia-vaapi-driver іде через EGL і часто падає

    # ЗАУВАЖЕННЯ: WLR_NO_HARDWARE_CURSORS більше НЕ ставимо.
    # У wlroots 0.20 (проти якого зібраний mango в nixpkgs) цю змінну прибрали,
    # а апаратні курсори на NVIDIA вже не ламаються. Якщо все ж побачиш
    # зникаючий/мерехтливий курсор — це перше, що варто спробувати повернути.
  };

  environment.systemPackages = with pkgs; [
    # Драйвер VA-API поверх NVDEC.
    # ЧЕСНО: на Maxwell це напівробоче. Якщо mpv почне сипати помилками —
    # прибери LIBVA_DRIVER_NAME вище і живи на софтовому декоді. Для 1080p
    # на 4C/8T це нормально.
    nvidia-vaapi-driver

    libva-utils # vainfo — перевірити, що саме декодується апаратно
    vulkan-tools # vulkaninfo — перевірити, що Vulkan живий (Maxwell тягне 1.3)
    mesa-demos # містить glxinfo/glxgears; окремого пакета glxinfo в nixpkgs НЕМАЄ
    # (перевірено: pkgs/by-name/gl/glxinfo → 404, в all-packages.nix теж немає)
    nvtopPackages.nvidia # монітор GPU: завантаження, VRAM, температура
  ];

  # ── Параметри модуля nvidia ─────────────────────────────────────────────────
  # PreserveVideoMemoryAllocations вже ставить powerManagement.enable,
  # але дублюємо явно — ти просив бачити його в конфізі.
  boot.extraModprobeConfig = ''
    options nvidia NVreg_PreserveVideoMemoryAllocations=1
    options nvidia NVreg_TemporaryFilePath=/var/tmp
  '';

  # ЯКЩО КОЛИСЬ legacy_580 ЗНИКНЕ З NIXPKGS — розкоментуй цей оверлей і встав
  # реальні хеші. Це і є «ручний пін 580.x», який ти просив показати.
  #
  # nixpkgs.overlays = [
  #   (final: prev: {
  #     linuxKernel = prev.linuxKernel // {
  #       packagesFor = kernel:
  #         (prev.linuxKernel.packagesFor kernel).extend (kfinal: kprev: {
  #           nvidiaPackages = kprev.nvidiaPackages.extend (nfinal: nprev: {
  #             legacy_580 = nprev.generic {
  #               version = "580.178.04";
  #               # Хеші беруться так:
  #               #   nix-prefetch-url https://download.nvidia.com/XFree86/Linux-x86_64/580.178.04/NVIDIA-Linux-x86_64-580.178.04.run
  #               sha256_64bit       = "sha256-AAAA...";
  #               sha256_aarch64     = "sha256-BBBB...";
  #               openSha256         = "sha256-CCCC...";  # не використовуємо, але поле потрібне
  #               settingsSha256     = "sha256-DDDD...";
  #               persistencedSha256 = "sha256-EEEE...";
  #             };
  #           });
  #         });
  #     };
  #   })
  # ];
  #
  # ПЕРЕВІР ПЕРЕД ВИКОРИСТАННЯМ: сигнатура `generic` у
  # pkgs/os-specific/linux/nvidia-x11/generic.nix змінюється між релізами
  # nixpkgs. Дивись, які саме аргументи очікуються у ТВОЇЙ ревізії.
}
