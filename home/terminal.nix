# ── Термінал ──────────────────────────────────────────────────────────────────
# foot. Виграв за трьома пунктами, кожен з яких для нас критичний:
#  1. Найменша латентність вводу серед Wayland-терміналів — він малює
#     через wl_shm/CPU і не чекає на GPU-конвеєр. На NVIDIA це перевага,
#     а не недолік: ми не витрачаємо VRAM і не залежимо від EGL.
#  2. ~10 МБ RSS проти ~80 у kitty і ~120 у ghostty.
#  3. Server-mode (footclient) — один процес на всі вікна.
#
# Програв kitty: OpenGL-рендер, тобто зайвий контекст GPU на кожне вікно.
# Програв ghostty: чудовий, але GTK4+libadwaita і помітно більший.
# Програв alacritty: теж GPU, і досі без вкладок/сплітів (за задумом автора).
# Програв wezterm: Lua-конфіг і найбільше споживання з усіх.
{
  config,
  lib,
  pkgs,
  ...
}:
{
  programs.foot = {
    enable = true;

    # Демон: перший запущений foot стає сервером, решта — легкі клієнти.
    # Економить ~8 МБ і ~40 мс на кожне нове вікно.
    server.enable = true;

    settings = {
      main = {
        term = "foot-extra";
        # Шрифт задається тут, а не через matugen — розмір і накреслення
        # не мають стрибати при зміні шпалери.
        font = "JetBrainsMono Nerd Font:size=11";
        font-bold = "JetBrainsMono Nerd Font:style=Bold:size=11";
        font-italic = "JetBrainsMono Nerd Font:style=Italic:size=11";
        # Щільність рядків. 0 = метрики шрифту як є.
        line-height = "14px";
        # Відступ від краю вікна. Брутальна естетика — мінімальний.
        pad = "6x6";
        # Не дублювати заголовок вікна — бар його не показує, а декорацій немає.
        title = "foot";
        # DPI за монітором, а не фіксований.
        dpi-aware = "no";
        # Кольори підключаються окремим файлом, який пише matugen.
        # TODO: перевір, що твоя версія foot підтримує include= у [main]:
        #   man 5 foot.ini | grep -A3 include
        include = "${config.home.homeDirectory}/.config/foot/colors.ini";
      };

      scrollback = {
        lines = 10000;
        multiplier = 3;
      };

      cursor = {
        style = "beam";
        blink = "no"; # блимання = перемальовок кожні 0.5 с у простої
      };

      mouse = {
        hide-when-typing = "yes";
      };

      # Пошук по буферу — те, чого немає в alacritty.
      key-bindings = {
        search-start = "Control+Shift+f";
        clipboard-copy = "Control+Shift+c";
        clipboard-paste = "Control+Shift+v";
        font-increase = "Control+plus";
        font-decrease = "Control+minus";
        font-reset = "Control+0";
      };

      # Кольори НЕ задаємо тут: їх пише matugen у окремий файл,
      # який foot підхоплює через include (див. home/theme.nix).
      # Тут лишається тільки прозорість — 1.0, бо блюру немає
      # і напівпрозорий термінал без блюру виглядає брудно.
      colors = {
        alpha = 1.0;
      };
    };
  };

  # ── ВАЖЛИВО ПРО КОЛЬОРИ ────────────────────────────────────────────────────
  # Файл ~/.config/foot/colors.ini НЕ керується home-manager СВІДОМО.
  # Причина: усе, що HM кладе в ~/.config, стає символьним посиланням у
  # /nix/store, тобто ДОСТУПНИМ ЛИШЕ ДЛЯ ЧИТАННЯ. matugen у такий файл
  # записати не зможе і мовчки провалиться.
  # Тому цей файл створюється один раз активаційним скриптом (home/theme.nix)
  # як звичайний файл, а далі його перезаписує matugen.
  #
  # foot підхоплює його через include= у [main] вище.
}
