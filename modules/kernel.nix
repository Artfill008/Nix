# Вибір ядра винесений в окремий модуль, бо це найризикованіше рішення в усьому
# конфізі — і єдине, де провал збірки лишає тебе без графіки.
#
# КОНТЕКСТ (перевірено у nixos-unstable, не з пам'яті):
#   • pkgs/os-specific/linux/nvidia-x11/default.nix:157 — legacy_580 = 580.178.04
#   • у цього блоку НЕМАЄ ні `patches`, ні `broken`
#   • kernel-compat патчі (gpl_symbols_linux_615_patch, kernel_6_19_patch)
#     визначені у `let` цього ж файлу, але НЕ застосовані до жодної гілки
#   • Hydra збирає nvidia_x11 = production (595) проти дефолтного ядра,
#     а не legacy_580 проти 7.2
#
# Тобто «580 + 7.2» — це комбінація, яку ніхто не гарантував. Вона може
# зібратись; може і ні. Тому тут сходи, а не одне жорстке значення.
{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.fennec.kernel;

  # Канонічні шляхи, а НЕ аліаси.
  # `pkgs.linuxPackages_6_18` теж працює, але живе в pkgs/top-level/aliases.nix
  # (рядок 1479) — тобто існує лише поки істинний config.allowAliases, і апстрім
  # має повне право його прибрати. linuxKernel.packages.* — це те, НА ЩО
  # аліас вказує. Для бази дистрибутива беремо стабільну форму.
  channels = {
    lts = {
      packages = pkgs.linuxKernel.packages.linux_6_12;
      label = "6.12 LTS";
      nvidiaTested = true;
    };
    default = {
      packages = pkgs.linuxKernel.packages.linux_6_18;
      label = "6.18";
      nvidiaTested = true;
    };
    recent = {
      packages = pkgs.linuxKernel.packages.linux_7_1;
      label = "7.1";
      nvidiaTested = false;
    };
    latest = {
      packages = pkgs.linuxKernel.packages.linux_7_2;
      label = "7.2";
      nvidiaTested = false;
    };
  };

  chosen = channels.${cfg.channel};
in
{
  options.fennec.kernel = {
    channel = lib.mkOption {
      type = lib.types.enum [
        "lts"
        "default"
        "recent"
        "latest"
      ];
      default = "default";
      description = ''
        Гілка ядра. Сходи вниз при проблемах зі збіркою NVIDIA-модуля:

          latest  (7.2)      — найновіше, що є в nixpkgs
          recent  (7.1)      — попереднє мейнлайн
          default (6.18)     — те, що nixpkgs вважає дефолтом і реально збирає
          lts     (6.12)     — найконсервативніше, мінімум сюрпризів

        Якщо `nixos-rebuild` падає на збірці nvidia-x11 — спускайся на сходинку
        нижче. Це рівно один рядок і одна перезбірка, система при цьому
        лишається на попередньому поколінні і завантажується.
      '';
    };

    acknowledgeUntestedNvidia = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = ''
        Підтвердження, що ти свідомо береш ядро, проти якого nixpkgs не збирає
        legacy_580. Без цього прапорця на «recent»/«latest» збірка зупиниться
        з поясненням — щоб ти не дізнався про проблему вже після reboot.
      '';
    };
  };

  config = {
    boot.kernelPackages = chosen.packages;

    # Зупиняємо збірку ДО того, як вона витратить пів години на компіляцію
    # ядра і впаде на nvidia-модулі.
    assertions = [
      {
        assertion = chosen.nvidiaTested || cfg.acknowledgeUntestedNvidia;
        message = ''
          fennec.kernel.channel = "${cfg.channel}" (ядро ${chosen.label})

          NVIDIA legacy_580 у nixpkgs не має kernel-compat патчів, і Hydra не
          збирає його проти цієї гілки ядра. Збірка модуля може впасти.

          Якщо ти свідомо це робиш:
              fennec.kernel.acknowledgeUntestedNvidia = true;

          Якщо ні — постав fennec.kernel.channel = "default" (6.18).

          Порада: перевір ДО switch, не після:
              nixos-rebuild build --flake .#fennec
          Це збере все, але нічого не активує.
        '';
      }
      {
        # Модуль services.scx має власний assertion на >= 6.12, але він
        # спрацює пізніше і з менш зрозумілим текстом.
        assertion = lib.versionAtLeast chosen.packages.kernel.version "6.12";
        message = "scx_lavd потребує sched_ext, тобто ядро >= 6.12. Обране: ${chosen.label}.";
      }
    ];

    warnings = lib.optional (!chosen.nvidiaTested) ''
      Ядро ${chosen.label} з NVIDIA legacy_580 — неперевірена комбінація.
      Після reboot обов'язково: gt72 health nvidia
    '';

    # Кладемо обрану гілку в /etc, щоб health-check міг порівняти
    # «що задекларовано» з «що реально завантажено» без парсингу Nix.
    environment.etc."fennec/kernel-channel".text = ''
      channel=${cfg.channel}
      label=${chosen.label}
      version=${chosen.packages.kernel.version}
      nvidia_tested=${if chosen.nvidiaTested then "yes" else "no"}
    '';
  };
}
