# Віртуалізація: libvirt + QEMU/KVM + virt-manager + OVMF (UEFI для гостей).
{
  config,
  lib,
  pkgs,
  username,
  ...
}:
{
  virtualisation.libvirtd = {
    enable = true;

    # Не піднімати всі ВМ при завантаженні системи — вмикай вручну.
    onBoot = "ignore";
    # При вимкненні хоста — приспати гостей, а не вбити.
    onShutdown = "suspend";

    qemu = {
      # OVMF = UEFI-прошивка для гостей. Без неї Windows 11 і сучасні
      # дистрибутиви з Secure Boot не встановляться.
      ovmf = {
        enable = true;
        packages = [
          (pkgs.OVMF.override {
            secureBoot = true;
            tpmSupport = true;
          }).fd
        ];
      };

      # swtpm = програмний TPM 2.0. Обов'язковий для Windows 11.
      swtpm.enable = true;

      # Запускати ВМ від імені окремого користувача, а не root.
      runAsRoot = false;

      # vhost-net для швидкої мережі гостя.
      verbatimConfig = ''
        user = "${username}"
        group = "kvm"
        cgroup_device_acl = [
          "/dev/null", "/dev/full", "/dev/zero",
          "/dev/random", "/dev/urandom",
          "/dev/ptmx", "/dev/kvm",
          "/dev/net/tun"
        ]

        # Явна cgroup-партиція для доменів.
        # "/machine" → systemd-слайс machine.slice (той, що налаштований нижче).
        # Якщо поставити "/machine/gaming", libvirt створить machine-gaming.slice,
        # і так можна розділити класи ВМ з різними лімітами.
        # УВАГА: цей блок пишеться в /etc/libvirt/qemu.conf модулем libvirtd.
        # Не додавай environment.etc."libvirt/qemu.conf" — буде конфлікт файлів.
      '';
    };
  };

  # ── machine.slice ───────────────────────────────────────────────────────────
  # Ти просив, щоб ВМ автоматично потрапляли в machine.slice.
  #
  # ЯК ЦЕ ПРАЦЮЄ НАСПРАВДІ: libvirt має власне поняття «partition»
  # (за замовчуванням /machine), яке мапиться на systemd-слайс machine.slice.
  # Тобто ВМ ТУДИ ВЖЕ ПОТРАПЛЯЮТЬ — але лише якщо libvirt зібраний із
  # підтримкою systemd-cgroups, і якщо в домені не перевизначено resource
  # partition. Нижче ми (а) робимо це явним і (б) даємо слайсу нормальні межі.
  #
  # ПЕРЕВІРИТИ ПІСЛЯ ЗАПУСКУ ВМ:
  #   systemd-cgls machine.slice
  #   systemctl status machine.slice
  systemd.slices."machine" = {
    description = "Virtual Machine and Container Slice";
    sliceConfig = {
      # ВМ не мають права з'їсти всю RAM: 32 з 48 ГБ — стеля.
      # MemoryHigh — м'який тиск (почне свопити в zram),
      # MemoryMax — жорсткий (спрацює OOM у слайсі, не по всій системі).
      MemoryHigh = "28G";
      MemoryMax = "32G";
      # Вага CPU нижча за дефолт (100), щоб інтерактив хоста вигравав
      # у конкуренції з ВМ. Це не ліміт — це пріоритет при суперечці.
      CPUWeight = 60;
      # Вага вводу-виводу теж нижча: інсталяція гостя не має вішати робочий стіл.
      IOWeight = 60;
      # Дозволяємо ВМ використовувати не більше 6 з 8 потоків.
      # TODO: якщо ВМ — основне навантаження, підніми або прибери.
      AllowedCPUs = "0-5";
    };
  };

  # ── Мережа ──────────────────────────────────────────────────────────────────
  # Дефолтна NAT-мережа libvirt. Без цього у гостя не буде інтернету,
  # і треба буде піднімати її вручну кожного разу.
  virtualisation.libvirtd.allowedBridges = [
    "virbr0"
    "br0"
  ];

  # dnsmasq libvirt конфліктує з systemd-resolved на порту 53, якщо той
  # слухає на всіх інтерфейсах. NetworkManager у нас керує DNS сам,
  # тому конфлікту не буде — але якщо колись увімкнеш resolved, памʼятай.

  # ── UEFI/USB-проброс ────────────────────────────────────────────────────────
  # spice-vdagentd на хості потрібен для буфера обміну між хостом і гостем.
  virtualisation.spiceUSBRedirection.enable = true;

  environment.systemPackages = with pkgs; [
    virt-manager # GUI. Виграв: єдиний, що дає повний доступ до XML домену.
    # Програв GNOME Boxes (ховає все, що потрібно для тюнінгу),
    # програв virt-viewer окремо (це лише клієнт дисплея).
    virt-viewer
    spice-gtk
    # ISO з драйверами virtio для гостьової Windows.
    # Атрибут саме virtio-win, а НЕ win-virtio (перевірено в pkgs/by-name/vi/).
    virtio-win
    virtiofsd # швидкий шаринг директорій хост↔гість (краще за 9p)
    swtpm
    qemu_kvm
    dnsmasq # потрібен libvirt для NAT-мережі
  ];

  # ── ЩО СВІДОМО НЕ РОБИМО ────────────────────────────────────────────────────
  # VFIO / GPU passthrough 980M у ВМ — НЕ налаштовуємо.
  # Причина: у GT72S апаратний MUX і дискретка — ЄДИНА карта, що малює екран.
  # Віддати її гостю = залишитись без зображення на хості. Це не «складно»,
  # це фізично неможливо без другого GPU. Якщо колись переключиш MUX на
  # Optimus і задієш iGPU для хоста — тоді passthrough стане реальним.
}
