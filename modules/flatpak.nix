# Flatpak — за твоїм рішенням: інфраструктура декларативна, самі застосунки
# лишаються імперативним user state.
#
# Це не компроміс, а точна відповідність можливостям: NixOS-модуль
# services.flatpak має РІВНО дві опції — `enable` і `package` (перевірено,
# весь модуль — 71 рядок). Декларативних remotes чи packages там немає.
# Тому «встановити flatpak-програму» принципово не є Nix-операцією.
{
  config,
  lib,
  pkgs,
  ...
}:
{
  services.flatpak.enable = true;

  # ── Remote: Flathub ─────────────────────────────────────────────────────────
  # Додаємо декларативно через ідемпотентний oneshot. `--if-not-exists` робить
  # повтор безпечним, тому це не «скрипт», а декларація стану: після кожного
  # switch remote гарантовано на місці.
  systemd.services.flatpak-repo = {
    description = "Реєстрація Flathub як remote для Flatpak";
    wantedBy = [ "multi-user.target" ];
    after = [ "network-online.target" ];
    wants = [ "network-online.target" ];
    path = [ pkgs.flatpak ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
    };
    script = ''
      flatpak remote-add --if-not-exists flathub \
        https://dl.flathub.org/repo/flathub.flatpakrepo
    '';
  };

  # ── Тематизація Flatpak-програм ─────────────────────────────────────────────
  # Головна відома проблема Flatpak: пісочниця не бачить твої теми, шрифти
  # і курсор, тож програма виглядає як чужа ОС посеред твого десктопу.
  # Ці override-и відкривають рівно те, що потрібно, у режимі лише для читання.
  #
  # Робимо це теж oneshot-ом, бо flatpak зберігає override у власній базі —
  # Nix туди писати не вміє.
  systemd.services.flatpak-theming = {
    description = "Доступ Flatpak-програм до тем, шрифтів і курсорів хоста";
    wantedBy = [ "multi-user.target" ];
    after = [ "flatpak-repo.service" ];
    path = [ pkgs.flatpak ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
    };
    script = ''
      # Теми GTK, іконки, курсори з системного профілю.
      flatpak override --system --filesystem=/run/current-system/sw/share/X11/fonts:ro
      flatpak override --system --filesystem=/run/current-system/sw/share/icons:ro
      flatpak override --system --filesystem=xdg-config/gtk-3.0:ro
      flatpak override --system --filesystem=xdg-config/gtk-4.0:ro
      # Шрифти користувача (matugen нічого сюди не пише, але хай буде).
      flatpak override --system --filesystem=xdg-data/fonts:ro
      # Тема курсора з home-manager.
      flatpak override --system --filesystem=xdg-data/icons:ro
    '';
  };

  # ── GeForce NOW ─────────────────────────────────────────────────────────────
  # Твій основний ігровий фронтенд. Нативний Linux-клієнт NVIDIA вийшов
  # з бети 13 серпня 2026, розповсюджується як Flatpak `com.nvidia.geforcenow`.
  #
  # ЧОМУ ЦЕ САМЕ FLATPAK, А НЕ NIX-ПАКЕТ: у nixpkgs його немає, і це логічно —
  # клієнт оновлюється часто і тягне власний рантайм.
  #
  # ВСТАНОВЛЕННЯ (одна команда, робиться один раз):
  #     flatpak install flathub com.nvidia.geforcenow
  #
  # TODO / ПЕРЕВІР НА МАШИНІ: я НЕ зміг підтвердити, чи клієнт лежить саме
  # на Flathub, чи у власному репозиторії NVIDIA — джерела кажуть «офіційний
  # Flatpak-репозиторій», не називаючи URL. Тому спершу:
  #     flatpak search geforcenow
  # і якщо на Flathub його немає — додай репозиторій NVIDIA за інструкцією
  # з їхнього сайту і пропиши його URL сюди, у flatpak-repo вище.
  # Вигаданий URL я сюди не пишу свідомо.
  #
  # ЩО ВАЖЛИВО САМЕ ДЛЯ ЦІЄЇ МАШИНИ:
  #   GM204 (980M) має апаратний декодер ТІЛЬКИ H.264. HEVC у нього немає
  #   (його отримали GM206 і GM200), AV1 немає взагалі.
  #   Якщо GFN узгодить HEVC — декод піде на CPU, і i7-6820HK на 1080p60
  #   це витягне, але з високим завантаженням і гарячим ноутом.
  #   У налаштуваннях клієнта примусово вибери H.264.
  #   Перевірити, що бачить система: `gt72 health video`
  #
  #   Друге: Flatpak-програмі потрібне GL-розширення під ТОЧНУ версію
  #   драйвера хоста (org.freedesktop.Platform.GL.nvidia-580-178-04).
  #   Flatpak зазвичай тягне його сам; якщо GFN не стартує з помилкою GL —
  #   це майже завжди саме воно. Перевірити:
  #       flatpak list --runtime | grep -i nvidia
  #   Версія має збігатися з `cat /proc/driver/nvidia/version`.

  # Flatpak-програми мають бачити наші портали (файловий діалог, скріншот,
  # шаринг екрана). Портали вже підняті модулем programs.mango,
  # тут лише переконуємось, що xdg-desktop-portal-gtk присутній —
  # саме він обслуговує file chooser для не-GTK4 програм у пісочниці.
  xdg.portal.extraPortals = [ pkgs.xdg-desktop-portal-gtk ];
}
