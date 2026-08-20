# ── Mango (mangowc): конфігурація композитора ─────────────────────────────────
#
# ЗВІДКИ БЕРЕТЬСЯ ПАКЕТ: з nixpkgs (pkgs.mango 0.16.0). Окремий flake input
# НЕ потрібен — я перевірив, що і пакет, і NixOS-модуль programs.mango
# є в nixos-unstable. Модуль увімкнено в modules/desktop.nix.
#
# ЗВІДКИ БЕРЕТЬСЯ СИНТАКСИС КОНФІГУ: з апстріму, тег 0.16.1 —
#   assets/config.conf         (усі ключі та їхні дефолти)
#   docs/bindings/keys.md      (повний список диспетчерів)
#   docs/configuration/basics.md   (env=, exec-once=, source=)
#   docs/configuration/monitors.md (monitorrule=)
# Я НЕ вигадував жодного ключа. Якщо якийсь не спрацює — це зміна апстріму,
# а не моя фантазія; перевіряй `mango -c ~/.config/mango/config.conf -p`.
#
# ЧОМУ НЕ ЧЕРЕЗ home-manager-модуль апстріму:
# у апстріму є nix/hm-modules.nix з опцією wayland.windowManager.mango.settings.
# Він добрий, але тягне ще один flake input, а його дефолтний пакет —
# mango-nightly з того ж флейка, тобто ми б отримали ДВІ різні збірки mango
# і два різні wlroots у замиканні. Пишемо config.conf напряму — і робимо
# ту саму перевірку синтаксису на етапі збірки, що й той модуль.
{
  config,
  lib,
  pkgs,
  ...
}:
let
  # ── Змінні, щоб не дублювати шляхи в біндах ─────────────────────────────────
  term = "${pkgs.foot}/bin/foot";
  launcher = "${pkgs.fuzzel}/bin/fuzzel";
  # Nautilus, а не nemo — див. пояснення вибору в home/default.nix.
  filemgr = "${pkgs.nautilus}/bin/nautilus";
  browser = "${pkgs.firefox}/bin/firefox";

  screenshotArea = "${pkgs.grim}/bin/grim -g \"$(${pkgs.slurp}/bin/slurp)\" - | ${pkgs.satty}/bin/satty --filename -";
  screenshotFull = "${pkgs.grim}/bin/grim - | ${pkgs.wl-clipboard}/bin/wl-copy";

  clipMenu = "${pkgs.cliphist}/bin/cliphist list | ${launcher} --dmenu | ${pkgs.cliphist}/bin/cliphist decode | ${pkgs.wl-clipboard}/bin/wl-copy";

  configText = ''
    # ══════════════════════════════════════════════════════════════════════════
    #  ЗГЕНЕРОВАНО з home/mango.nix. Правки роби ТАМ, не тут.
    # ══════════════════════════════════════════════════════════════════════════

    # ── Ефекти: ВИМКНЕНО ──────────────────────────────────────────────────────
    # 4 ГБ VRAM на 980M — і кожен ефект scenefx це додаткові позаекранні
    # буфери розміром з екран, які живуть постійно.
    # blur: 2 проходи × 1920×1080×4 байти × N шарів. Не варте того.
    blur=0
    blur_layer=0
    shadows=0
    layer_shadows=0

    # Анімації вимкнено повністю: кожен кадр анімації — це повний
    # перемальовок сцени. На 75 Гц це 75 зайвих композицій на секунду
    # рівно тоді, коли ти й так чогось чекаєш.
    animations=0
    layer_animations=0

    # Легке заокруглення — воно НЕ коштує нічого (це фрагментний шейдер
    # без додаткових буферів) і задає «м'яку брутальність», яку ти просив.
    border_radius=4
    no_radius_when_single=1

    # Прозорість не використовуємо: на NVIDIA це зайвий шлях змішування.
    focused_opacity=1.0
    unfocused_opacity=1.0

    # ── Розкладка: scroller за замовчуванням ──────────────────────────────────
    # scroller = нескінченна горизонтальна стрічка вікон, як у PaperWM/niri.
    # Кожен тег стартує саме в ній.
    tagrule=id:1,layout_name:scroller
    tagrule=id:2,layout_name:scroller
    tagrule=id:3,layout_name:scroller
    tagrule=id:4,layout_name:scroller
    tagrule=id:5,layout_name:scroller
    # 6-9 лишаємо в tile: зручно для вікон, які мають бути видні одночасно
    # (монітори, чати, документація).
    tagrule=id:6,layout_name:tile
    tagrule=id:7,layout_name:tile
    tagrule=id:8,layout_name:tile
    tagrule=id:9,layout_name:tile

    # Налаштування scroller.
    # scroller_default_proportion=0.5 — нове вікно займає половину екрана,
    # тобто в стрічці комфортно вміщаються два. 0.8 (дефолт) на 1080p
    # означає «майже одне вікно», що вбиває сенс розкладки.
    scroller_default_proportion=0.5
    scroller_default_proportion_single=1.0
    # Пресети, які циклічно перемикає SUPER+X.
    scroller_proportion_preset=0.33,0.5,0.67,1.0
    # Фокусоване вікно центрується — око не бігає по екрану.
    scroller_focus_center=1
    scroller_structs=20

    # ── Overview і jump mode ──────────────────────────────────────────────────
    # ov_tab_mode=1 — у режимі overview Tab перемикає між вікнами.
    ov_tab_mode=1
    overviewgappi=8
    overviewgappo=24
    # Гарячий кут вимкнено: на тачпаді він спрацьовує випадково.
    enable_hotarea=0
    hotarea_size=10

    # ── Проміжки і рамки ──────────────────────────────────────────────────────
    # Брутальна геометрія: невеликі внутрішні проміжки, товста рамка.
    gappih=6
    gappiv=6
    gappoh=6
    gappov=6
    borderpx=3
    no_border_when_single=1
    smartgaps=0

    # Кількість тегів. Задано ЯВНО, бо від цього залежать бінди SUPER+1..9:
    # апстрімний дефолт теж 9, але покладатися на нього означає, що зміна
    # дефолту в наступній версії Mango мовчки зламає частину біндів.
    tag_num=9

    # ── Кольори ───────────────────────────────────────────────────────────────
    # ЦІ ЗНАЧЕННЯ ПЕРЕВИЗНАЧАЮТЬСЯ ФАЙЛОМ, ЯКИЙ ГЕНЕРУЄ MATUGEN.
    # Він підключається останнім рядком (source=colors.conf), тому те,
    # що там, перемагає. Тут — запасні кольори на випадок, коли шпалери
    # ще немає (перший запуск).
    rootcolor=0x0d0d10ff
    bordercolor=0x2a2a32ff
    focuscolor=0x7fd1ffff
    urgentcolor=0xff5f5fff
    maximizescreencolor=0x7fd1ffff
    scratchpadcolor=0x5f87afff
    globalcolor=0xaf87ffff
    overlaycolor=0x5fd7afff

    # ── Поведінка фокуса ──────────────────────────────────────────────────────
    sloppyfocus=1
    warpcursor=1
    focus_on_activate=1
    focus_cross_monitor=0
    focus_cross_tag=0
    enable_floating_snap=1
    snap_distance=16

    # ── Клавіатура ────────────────────────────────────────────────────────────
    repeat_rate=40
    repeat_delay=250
    numlockon=1
    # TODO: якщо потрібна українська розкладка — постав "us,ua"
    # і додай бінд на switch_keyboard_layout нижче.
    xkb_rules_layout=us

    # ── Тачпад ────────────────────────────────────────────────────────────────
    tap_to_click=1
    tap_and_drag=1
    drag_lock=1
    trackpad_natural_scrolling=1
    disable_while_typing=1

    # ── Монітор ───────────────────────────────────────────────────────────────
    # TODO: перевір назву виходу командою `wlr-randr` у сесії.
    # На GT72S із MUX це майже напевно eDP-1.
    #
    # refresh:60 — свідомо. 75 Гц ставимо ТІЛЬКИ після того, як запрацює
    # modules/laptop/panel-75hz.nix і `wlr-randr` реально покаже режим 75.
    # Якщо поставити 75 тут раніше — mango не знайде режим і впаде
    # на дефолтний, тихо. Це не зламає систему, але й не спрацює.
    monitorrule=name:^eDP-1$,width:1920,height:1080,refresh:60,x:0,y:0,scale:1

    # ── Змінні середовища сесії ───────────────────────────────────────────────
    # УВАГА (з апстрім-документації): env= скидається при кожному reload_config.
    # Тому все критичне ставимо системно (modules/nvidia.nix), а тут — лише
    # те, що безпечно втратити.
    env=XDG_CURRENT_DESKTOP,mango
    env=XDG_SESSION_TYPE,wayland
    env=QT_QPA_PLATFORM,wayland;xcb
    env=QT_WAYLAND_DISABLE_WINDOWDECORATION,1
    env=SDL_VIDEODRIVER,wayland
    env=MOZ_ENABLE_WAYLAND,1
    env=_JAVA_AWT_WM_NONREPARENTING,1

    # ══════════════════════════════════════════════════════════════════════════
    #  КЛАВІШІ
    #  Модифікатор — SUPER. Апстрім за замовчуванням використовує ALT,
    #  але ALT конфліктує з меню програм (Alt+F, Alt+Tab у Wine тощо).
    # ══════════════════════════════════════════════════════════════════════════

    # ── keymode common: працює в БУДЬ-ЯКОМУ режимі ────────────────────────────
    keymode=common
    bind=SUPER+SHIFT,r,reload_config

    keymode=default

    # ── Запуск ────────────────────────────────────────────────────────────────
    bind=SUPER,Return,spawn,${term}
    bind=SUPER,d,spawn,${launcher}
    bind=SUPER,e,spawn,${filemgr}
    bind=SUPER,b,spawn,${browser}
    bind=SUPER+SHIFT,e,spawn,${pkgs.wlogout}/bin/wlogout
    bind=SUPER,v,spawn_shell,${clipMenu}
    bind=SUPER,period,spawn,${pkgs.gnome-characters}/bin/gnome-characters

    # ── Вікна ─────────────────────────────────────────────────────────────────
    bind=SUPER,q,killclient,
    bind=SUPER,f,togglefullscreen,
    bind=SUPER+SHIFT,f,togglemaximizescreen,
    bind=SUPER,space,togglefloating,
    bind=SUPER,c,centerwin,
    bind=SUPER,g,toggleglobal,
    bind=SUPER,i,minimized,
    bind=SUPER+SHIFT,i,restore_minimized,1
    bind=SUPER,z,toggle_scratchpad

    # ── Overview і jump mode (ти просив обидва) ───────────────────────────────
    # toggleoverview — «пташиний огляд» усіх вікон поточного тега.
    bind=SUPER,Tab,toggleoverview,
    # togglejump — той самий overview, але в режимі стрибка: набираєш
    # мітку вікна і потрапляєш прямо в нього.
    bind=SUPER+SHIFT,Tab,togglejump,

    # ── Фокус ─────────────────────────────────────────────────────────────────
    bind=SUPER,h,focusdir,left
    bind=SUPER,l,focusdir,right
    bind=SUPER,k,focusdir,up
    bind=SUPER,j,focusdir,down
    bind=SUPER,Left,focusdir,left
    bind=SUPER,Right,focusdir,right
    bind=SUPER,Up,focusdir,up
    bind=SUPER,Down,focusdir,down
    bind=SUPER,grave,focuslast,

    # ── Переміщення вікон у стрічці ───────────────────────────────────────────
    bind=SUPER+SHIFT,h,exchange_client,left
    bind=SUPER+SHIFT,l,exchange_client,right
    bind=SUPER+SHIFT,k,exchange_client,up
    bind=SUPER+SHIFT,j,exchange_client,down

    # ── Scroller: керування пропорціями і стеком ──────────────────────────────
    # SUPER+x циклічно міняє ширину фокусованого вікна за пресетами вище.
    bind=SUPER,x,switch_proportion_preset,
    # На весь екран у стрічці.
    bind=SUPER+SHIFT,x,set_proportion,1.0
    # Загнати вікно у вертикальний стек усередині стрічки (двоповерхова колонка).
    bind=SUPER+CTRL,k,scroller_stack,up
    bind=SUPER+CTRL,j,scroller_stack,down
    bind=SUPER+CTRL,h,scroller_stack,left
    bind=SUPER+CTRL,l,scroller_stack,right

    # ── Розкладки ─────────────────────────────────────────────────────────────
    bind=SUPER,n,switch_layout
    bind=SUPER+ALT,s,setlayout,scroller
    bind=SUPER+ALT,t,setlayout,tile
    bind=SUPER+ALT,m,setlayout,monocle
    bind=SUPER+ALT,g,setlayout,grid

    # ── Теги ──────────────────────────────────────────────────────────────────
    bind=SUPER,1,view,1
    bind=SUPER,2,view,2
    bind=SUPER,3,view,3
    bind=SUPER,4,view,4
    bind=SUPER,5,view,5
    bind=SUPER,6,view,6
    bind=SUPER,7,view,7
    bind=SUPER,8,view,8
    bind=SUPER,9,view,9
    # SUPER,0 свідомо НЕ прив'язаний: тегів дев'ять (tag_num=9 вище),
    # тега «0» не існує, і бінд на нього мовчки нічого не робив. Аудит A-046.

    bind=SUPER+SHIFT,1,tag,1
    bind=SUPER+SHIFT,2,tag,2
    bind=SUPER+SHIFT,3,tag,3
    bind=SUPER+SHIFT,4,tag,4
    bind=SUPER+SHIFT,5,tag,5
    bind=SUPER+SHIFT,6,tag,6
    bind=SUPER+SHIFT,7,tag,7
    bind=SUPER+SHIFT,8,tag,8
    bind=SUPER+SHIFT,9,tag,9

    # Сусідні теги, у яких щось є (пропускає порожні).
    bind=SUPER+CTRL,Left,viewtoleft_have_client,0
    bind=SUPER+CTRL,Right,viewtoright_have_client,0
    bind=SUPER+ALT,Left,tagtoleft,0
    bind=SUPER+ALT,Right,tagtoright,0

    # ── Проміжки ──────────────────────────────────────────────────────────────
    bind=SUPER+SHIFT,equal,incgaps,2
    bind=SUPER+SHIFT,minus,incgaps,-2
    bind=SUPER+SHIFT,0,togglegaps

    # ── Знімки екрана ─────────────────────────────────────────────────────────
    bind=NONE,Print,spawn_shell,${screenshotFull}
    bind=SHIFT,Print,spawn_shell,${screenshotArea}
    bind=SUPER,s,spawn_shell,${screenshotArea}

    # ── Блокування ────────────────────────────────────────────────────────────
    # bindl = працює навіть коли екран уже заблоковано.
    #
    # БУЛО SUPER+SHIFT+l — і це конфліктувало з exchange_client,right вище
    # (та сама комбінація, два різні бінди). Аудит A-045.
    # Escape вільний і його важко натиснути випадково.
    bindl=SUPER,Escape,spawn,${pkgs.swaylock}/bin/swaylock -f

    # ── Медіаклавіші ──────────────────────────────────────────────────────────
    # bindl, бо гучність і яскравість мають працювати на локскріні.
    # ЧЕРЕЗ swayosd-client, А НЕ wpctl/brightnessctl НАПРЯМУ.
    # Аудит A-042: раніше тут стояли прямі виклики, і гучність змінювалась,
    # але НІЧОГО НЕ ЗʼЯВЛЯЛОСЬ НА ЕКРАНІ — swayosd-server працював у порожнечу,
    # бо його ніхто не викликав. swayosd-client і змінює значення, і малює OSD.
    bindl=NONE,XF86AudioRaiseVolume,spawn,${pkgs.swayosd}/bin/swayosd-client --output-volume raise --max-volume 150
    bindl=NONE,XF86AudioLowerVolume,spawn,${pkgs.swayosd}/bin/swayosd-client --output-volume lower
    bindl=NONE,XF86AudioMute,spawn,${pkgs.swayosd}/bin/swayosd-client --output-volume mute-toggle
    bindl=NONE,XF86AudioMicMute,spawn,${pkgs.swayosd}/bin/swayosd-client --input-volume mute-toggle

    bindl=NONE,XF86MonBrightnessUp,spawn,${pkgs.swayosd}/bin/swayosd-client --brightness raise
    bindl=NONE,XF86MonBrightnessDown,spawn,${pkgs.swayosd}/bin/swayosd-client --brightness lower

    bindl=NONE,XF86AudioPlay,spawn,${pkgs.playerctl}/bin/playerctl play-pause
    bindl=NONE,XF86AudioNext,spawn,${pkgs.playerctl}/bin/playerctl next
    bindl=NONE,XF86AudioPrev,spawn,${pkgs.playerctl}/bin/playerctl previous

    # ── Шпалери ───────────────────────────────────────────────────────────────
    bind=SUPER+ALT,w,spawn,${pkgs.moewall}/bin/moewall next
    bind=SUPER+ALT+SHIFT,w,spawn,${pkgs.moewall}/bin/moewall refresh

    # ── Режим зміни розміру (keymode) ─────────────────────────────────────────
    # SUPER+r входить у режим, далі hjkl міняють розмір, Escape виходить.
    # Це краще за десяток біндів із CTRL+ALT: руки лишаються на місці.
    bind=SUPER,r,setkeymode,resize

    keymode=resize
    bind=NONE,h,resizewin,-40,+0
    bind=NONE,l,resizewin,+40,+0
    bind=NONE,k,resizewin,+0,-40
    bind=NONE,j,resizewin,+0,+40
    bind=NONE,Left,movewin,-40,+0
    bind=NONE,Right,movewin,+40,+0
    bind=NONE,Up,movewin,+0,-40
    bind=NONE,Down,movewin,+0,+40
    bind=NONE,Escape,setkeymode,default
    bind=NONE,Return,setkeymode,default

    keymode=default

    # ── Миша ──────────────────────────────────────────────────────────────────
    mousebind=SUPER,btn_left,moveresize,curmove
    mousebind=SUPER,btn_right,moveresize,curresize
    mousebind=NONE,btn_middle,togglemaximizescreen,0

    # Колесо з SUPER — перемикання тегів, у яких щось є.
    axisbind=SUPER,UP,viewtoleft_have_client
    axisbind=SUPER,DOWN,viewtoright_have_client

    # ── Правила шарів ─────────────────────────────────────────────────────────
    # Анімації вимкнені глобально, тому layerrule тут не потрібні.

    # ── Автозапуск ────────────────────────────────────────────────────────────
    exec-once=~/.config/mango/autostart.sh

    # ── Кольори від matugen ───────────────────────────────────────────────────
    # ОСТАННІЙ рядок: усе, що тут, перекриває значення вище.
    # source-optional, бо при першому запуску файлу ще немає.
    source-optional=~/.config/mango/colors.conf
  '';

  # Перевірка синтаксису НА ЕТАПІ ЗБІРКИ.
  # `mango -c FILE -p` — це parse-only режим із апстрім-документації
  # (docs/configuration/basics.md, секція «Validate Configuration»).
  # Якщо я десь помилився в ключі — rebuild впаде тут, а не в рантаймі
  # чорним екраном.
  validatedConfig = pkgs.runCommand "mango-config.conf" { } ''
    cp ${pkgs.writeText "mango-config-raw.conf" configText} "$out"
    ${pkgs.mango}/bin/mango -c "$out" -p
  '';
in
{
  xdg.configFile."mango/config.conf".source = validatedConfig;

  # ── autostart.sh ────────────────────────────────────────────────────────────
  # Запускається один раз при старті композитора.
  # Головне його завдання — підняти graphical-session.target, до якого
  # прив'язані всі user-сервіси з home/default.nix.
  xdg.configFile."mango/autostart.sh" = {
    executable = true;
    text = ''
      #!${pkgs.bash}/bin/bash

      # 1. Віддати змінні сесії в systemd і D-Bus.
      #    Без цього user-сервіси (mako, waybar) не побачать WAYLAND_DISPLAY
      #    і мовчки не запустяться.
      ${pkgs.dbus}/bin/dbus-update-activation-environment --systemd \
        DISPLAY WAYLAND_DISPLAY XDG_CURRENT_DESKTOP XDG_SESSION_TYPE \
        XCURSOR_THEME XCURSOR_SIZE NIXOS_OZONE_WL

      # 2. Підняти target, до якого прив'язані сервіси сесії.
      systemctl --user reset-failed
      systemctl --user start graphical-session.target

      # 3. Шпалери. swaybg читає файл, який підтримує moewall.
      #    -m fill: заповнити екран із обрізанням, без чорних смуг.
      if [ -f /var/lib/moewall/current.png ]; then
        ${pkgs.swaybg}/bin/swaybg -i /var/lib/moewall/current.png -m fill &
      else
        # Перший запуск: рівний фон, поки moewall не завантажив першу шпалеру.
        ${pkgs.swaybg}/bin/swaybg -c '#0d0d10' &
      fi

      # 4. Бар. Запускаємо тут, а не сервісом, бо waybar має стартувати
      #    ПІСЛЯ того, як композитор створив виходи — інакше він не побачить
      #    монітор і покаже порожню смугу.
      ${pkgs.waybar}/bin/waybar &

      # 5. Перша шпалера, якщо її ще немає (у фоні, не блокує старт).
      if [ ! -f /var/lib/moewall/current.png ]; then
        ${pkgs.moewall}/bin/moewall next &
      fi
    '';
  };
}
