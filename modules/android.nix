# Android-розробка. За твоїми словами — реальний основний workload,
# тому це повноцінний модуль, а не «доклав adb у systemPackages».
#
# ВАЖЛИВА ЗНАХІДКА, яку треба знати:
# NixOS-модуля `programs.adb` БІЛЬШЕ НЕМАЄ. Файл nixos/modules/programs/adb.nix
# віддає 404 у nixos-unstable, і в module-list.nix його теж немає.
# Пакета `android-udev-rules` у nixpkgs теж немає.
# Тому udev-правила пишемо самі — і не списком vendor ID (він завжди неповний
# і застаріває), а по КЛАСУ USB-інтерфейсу. Так працює будь-який пристрій
# будь-якого виробника, включно з китайськими без відомого VID.
{
  config,
  lib,
  pkgs,
  username,
  ...
}:
let
  cfg = config.fennec.android;
in
{
  options.fennec.android = {
    enable = lib.mkEnableOption "стек Android-розробки" // {
      default = true;
    };

    studio = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = ''
        Ставити Android Studio. Вимкни, якщо працюєш лише через CLI
        (gradle + adb) — це економить кілька гігабайт у сторі.
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    environment.systemPackages =
      with pkgs;
      [
        # adb, fastboot, mke2fs для образів тощо.
        android-tools

        # Дзеркалювання і керування пристроєм з десктопа по USB або Wi-Fi.
        # Для розробки це не іграшка: демонструвати UI, знімати відео багу,
        # тестувати без того, щоб тримати телефон у руці.
        scrcpy

        # JDK для gradle з командного рядка.
        # Android Studio несе власний JBR і НЕ використовує системний JDK —
        # цей потрібен саме для `./gradlew` у терміналі та для агентів.
        # 17, а не 21: Android Gradle Plugin досі найстабільніший на 17.
        # TODO: якщо твій проєкт вимагає іншу версію — тримай її per-project
        # у devShell, а не міняй тут.
        jdk17
      ]
      ++ lib.optional cfg.studio android-studio;

    # ── nix-ld ────────────────────────────────────────────────────────────────
    # ЦЕ НАЙВАЖЛИВІШИЙ РЯДОК УСЬОГО МОДУЛЯ.
    #
    # Android Studio завантажує SDK сам, у ~/Android/Sdk — і це звичайні
    # динамічно злінковані ELF-бінарники (aapt2, d8, emulator, ndk-build),
    # які шукають /lib64/ld-linux-x86-64.so.2. На NixOS такого шляху немає,
    # і вони просто не запускаються з «No such file or directory» — при тому,
    # що файл на місці. Це класичний і найболючіший затик Android+NixOS.
    #
    # nix-ld підставляє їм робочий динамічний лінкер і набір бібліотек.
    # Без нього ти або збираєш SDK через androidenv (декларативно, але
    # негнучко і Studio його не бачить), або страждаєш.
    programs.nix-ld = {
      enable = true;
      libraries = with pkgs; [
        # Те, чого реально просять бінарники Android SDK/NDK та емулятор.
        zlib
        zstd
        openssl
        stdenv.cc.cc.lib
        ncurses5
        expat
        libxml2
        # Емулятор — це Qt/X11-програма.
        xorg.libX11
        xorg.libXext
        xorg.libXrender
        xorg.libXtst
        xorg.libXi
        xorg.libXcursor
        xorg.libXrandr
        xorg.libxcb
        libGL
        libpulseaudio
        fontconfig
        freetype
        dbus
        nss
        nspr
      ];
    };

    # ── udev: фізичні пристрої ────────────────────────────────────────────────
    # Правила по класу інтерфейсу, а не по vendor ID.
    #   ff4201 = класFF / підклас42 / протокол01 → ADB
    #   ff4203 = класFF / підклас42 / протокол03 → fastboot
    # TAG+="uaccess" віддає доступ тому, хто зараз залогінений у графічній
    # сесії — це сучасний спосіб, який не вимагає перелогіну після додавання
    # в групу. Групу лишаємо для випадків без seat (ssh, служби).
    services.udev.extraRules = ''
      # Android ADB — будь-який виробник
      SUBSYSTEM=="usb", ENV{ID_USB_INTERFACES}=="*:ff4201:*", MODE="0660", GROUP="adbusers", TAG+="uaccess"
      # Android fastboot / bootloader
      SUBSYSTEM=="usb", ENV{ID_USB_INTERFACES}=="*:ff4203:*", MODE="0660", GROUP="adbusers", TAG+="uaccess"
      # Деякі пристрої в режимі recovery віддають ADB як клас 42/01 без ff
      SUBSYSTEM=="usb", ENV{ID_USB_INTERFACES}=="*:ff4200:*", MODE="0660", GROUP="adbusers", TAG+="uaccess"
    '';

    # Групу створюємо самі — раніше це робив модуль programs.adb, якого вже немає.
    users.groups.adbusers = { };
    users.users.${username}.extraGroups = [ "adbusers" ];

    # ── Емулятор ──────────────────────────────────────────────────────────────
    # Апаратне прискорення емулятора — це KVM. Користувач уже в групі kvm
    # (див. hosts/gt72s/default.nix), тут лише переконуємось, що модуль є.
    # Без цього емулятор працює на ARM-трансляції і це непридатно повільно.
    boot.kernelModules = [ "kvm-intel" ];

    # Емулятор — X11-програма, тож XWayland обов'язковий.
    # Він уже увімкнений у modules/desktop.nix; тут лише фіксуємо залежність
    # явно, щоб при рефакторингу ніхто не вимкнув XWayland «бо Wayland же».
    assertions = [
      {
        assertion = config.programs.xwayland.enable;
        message = ''
          fennec.android.enable = true вимагає XWayland: емулятор Android
          і частина діалогів Android Studio — це Qt/X11.
        '';
      }
    ];

    # ── Підказка про GPU ──────────────────────────────────────────────────────
    # На NVIDIA пропрієтарному емулятор треба запускати з `-gpu host`,
    # інакше він падає на SwiftShader і гальмує.
    # Це runtime-налаштування (~/.android/advancedFeatures.ini), а не Nix —
    # див. `gt72 health android`, він це перевіряє й підкаже.
    environment.sessionVariables = {
      # Studio під Wayland: поки що стабільніше через XWayland.
      # TODO: коли JetBrains допиляє Wayland-бекенд — прибрати.
      _JAVA_AWT_WM_NONREPARENTING = "1";
    };
  };
}
