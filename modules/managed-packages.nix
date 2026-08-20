# ╔═══════════════════════════════════════════════════════════════════════════╗
# ║  ЦИМ ФАЙЛОМ ВОЛОДІЄ ІНСТРУМЕНТ `nixmgr`.                                  ║
# ║  НЕ РЕДАГУЙ ЙОГО РУКАМИ.                                                  ║
# ║                                                                           ║
# ║  Усе, що ти додаєш через `nixmgr add <назва>`, опиняється тут.            ║
# ║  Твій основний конфіг (hosts/, modules/, home/) інструмент НЕ ЧИТАЄ,      ║
# ║  НЕ ПАРСИТЬ і НЕ ЗМІНЮЄ — ніколи.                                         ║
# ║                                                                           ║
# ║  Якщо файл зіпсувався: `git checkout -- modules/managed-packages.nix`     ║
# ║  або `nixmgr rollback` (інструмент тримає .bak поруч).                    ║
# ╚═══════════════════════════════════════════════════════════════════════════╝
#
# СТРУКТУРА НАВМИСНО ПРИМІТИВНА. Причина: чим простіше дерево, тим менше
# способів у машинного редактора його зламати. Тут немає ні let-in, ні
# умовних виразів, ні функцій — лише два статичні атрибути.
#
# Три місця, куди nixmgr може щось покласти:
#
#  1. environment.systemPackages — звичайні пакети (більшість).
#  2. programs.<name>.enable     — пакети, які ВИМАГАЮТЬ модуля, а не запису
#                                  в systemPackages (steam, wireshark, gamemode...).
#                                  Список таких — курована таблиця в
#                                  tools/nixmgr/data/module-packages.toml.
#  3. nixpkgs.config.allowUnfreePredicate — дозвіл на конкретний unfree-пакет.
#
{
  config,
  lib,
  pkgs,
  ...
}:
{
  # ── nixmgr:systemPackages:begin ────────────────────────────────────────────
  # Рядки між маркерами належать інструменту.
  environment.systemPackages = with pkgs; [
  ];
  # ── nixmgr:systemPackages:end ──────────────────────────────────────────────

  # ── nixmgr:programs:begin ──────────────────────────────────────────────────
  # Пакети, для яких правильна відповідь — модуль, а не systemPackages.
  # Приклад того, що сюди потрапить (зараз порожньо):
  #   programs.steam.enable = true;
  #   programs.gamemode.enable = true;
  programs = {
  };
  # ── nixmgr:programs:end ────────────────────────────────────────────────────

  # ── nixmgr:unfree:begin ────────────────────────────────────────────────────
  # Точковий дозвіл на unfree замість глобального allowUnfree.
  #
  # ЧОМУ ПРЕДИКАТ, А НЕ allowUnfree = true:
  # глобальний прапорець дозволяє ВСЕ, і ти ніколи не дізнаєшся, що саме
  # пропрієтарного приїхало в систему. Предикат — це явний список.
  #
  # УВАГА: у hosts/gt72s/default.nix наразі стоїть allowUnfree = true
  # (він потрібен для драйвера NVIDIA). Поки він там — цей предикат
  # ні на що не впливає. Якщо колись захочеш строгий режим:
  # прибери allowUnfree звідти, і працюватиме лише список нижче
  # плюс явний дозвіл на "nvidia-x11", "nvidia-settings", "nvidia-persistenced".
  nixpkgs.config.allowUnfreePredicate =
    pkg:
    builtins.elem (lib.getName pkg) [
      "nvidia-x11"
      "nvidia-settings"
      "nvidia-persistenced"
    ];
  # ── nixmgr:unfree:end ──────────────────────────────────────────────────────
}
