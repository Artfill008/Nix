# Вимоги

Джерело: початкове ТЗ користувача + усі пізніші доповнення цієї розмови.
Кожна вимога має ID, за яким на неї посилається `docs/AUDIT.md`.

Статуси реалізації тут **не** ведуться — вони в `docs/PROGRESS.md` і `docs/AUDIT.md`.

---

## R1. Мета проєкту

- **R1.1** Це не персональний dotfiles-конфіг, а **фундамент власного desktop-дистрибутива**.
- **R1.2** Усі списки компонентів у ТЗ — **мінімальні вимоги**, не вичерпні.
- **R1.3** Агент діє як maintainer дистрибутива: сам знаходить прогалини,
  приховані залежності, потрібні служби та desktop-інтеграцію.
- **R1.4** Після чистої установки + `nixos-rebuild` система має бути придатною
  до роботи без ручного доставляння фундаментальних компонентів.
- **R1.5** Не додавати софт заради кількості.
- **R1.6** Ціль формулювання: не «NixOS, який працює на GT72S», а «GT72S OS на базі NixOS».

## R2. Структура

- **R2.1** Модулями, не одним файлом.
- **R2.2** Hardware-специфіка ізольована в `hosts/gt72s/` та окремих GT72S-модулях.
- **R2.3** Загальні desktop-компоненти **не** ховати в hardware-модуль.
- **R2.4** Структура має дозволяти додати `hosts/other-machine/`, `themes/other-theme/`,
  `desktop/other-compositor/` без переписування дерева.
- **R2.5** Чітке розділення: hardware / system / performance / desktop-session /
  applications / theme / user configuration.
- **R2.6** Коментарі українською; користувач хоче розуміти кожен рядок.

## R3. Вибір компонентів

- **R3.1** Для кожного компонента — **найкращий**, а не найпопулярніший варіант.
- **R3.2** Одним рядком: чому саме він і що програло.
- **R3.3** Якщо два варіанти рівні — сказати це, а не вдавати впевненість.
- **R3.4** Одна функція = один основний компонент; мінімум дублювання і фонових демонів.
- **R3.5** Не вибирати гірший компонент лише заради економії 30 МБ RAM.

## R4. Не вигадувати

- **R4.1** Не вигадувати назви пакетів. Якщо не впевнений — писати «перевір: nix search ...».
- **R4.2** Не називати перевіреним те, що фактично не запускалось.
- **R4.3** Не називати апаратну поведінку перевіреною без доказу з пристрою.

## R5. Ядро та завантаження

- **R5.1** systemd-boot, UEFI, обмеження поколінь, recovery-покоління доступне.
- **R5.2** initrd із потрібними модулями (nvme, xhci, rtsx для картрідера).
- **R5.3** Intel microcode.
- **R5.4** Firmware (`enableRedistributableFirmware`), Bluetooth-прошивка.
- **R5.5** `kernelParams`: `preempt=full`, `split_lock_detect=off`, `nowatchdog`,
  `nvme_core.default_ps_max_latency_us=0`, `mem_sleep_default=deep`,
  `nvidia-drm.modeset=1`, `NVreg_PreserveVideoMemoryAllocations=1`.
- **R5.6** Мітигації Spectre/MDS — за окремим рішенням користувача (`mitigations=off`).

## R6. Продуктивність

- **R6.1** `services.scx` = `scx_lavd`, служба реально enable.
- **R6.2** zram 16 ГБ, zstd.
- **R6.3** `vm.swappiness = 180`, `vm.page-cluster = 0`.
- **R6.4** `vm.max_map_count`, `vm.dirty_bytes`, `vm.vfs_cache_pressure`.
- **R6.5** udev: планувальник `none` для NVMe.
- **R6.6** MGLRU увімкнено.
- **R6.7** THP = madvise.
- **R6.8** governor/TuneD під плагін живлення.
- **R6.9** `systemd.oomd`.
- **R6.10** Усе декларативно, без скриптів.
- **R6.11** Жодних двох демонів, що керують одним і тим самим
  (TLP vs power-profiles-daemon vs TuneD; кілька notification daemons;
  кілька polkit-агентів; кілька portal backends; кілька clipboard managers;
  кілька automount daemons).

## R7. NVIDIA

- **R7.1** `legacy_580`, версія з пінa `flake.lock`.
- **R7.2** `open = false`, modeset, PreserveVideoMemoryAllocations.
- **R7.3** Збіг userspace/kernel пакета.
- **R7.4** Vulkan, XWayland, suspend/resume-інтеграція.
- **R7.5** 32-бітний стек — по можливості лише коли увімкнений локальний gaming-модуль.

## R8. Сховище

- **R8.1** Btrfs, підтоми `@ @home @nix @log @snapshots`.
- **R8.2** TRIM.
- **R8.3** Btrfs maintenance (scrub).
- **R8.4** btrbk; `/nix` не снапшотити.
- **R8.5** SMART/NVMe моніторинг.

## R9. Система

- **R9.1** Firewall, DNS, NTP, локаль, часовий пояс.
- **R9.2** journald, coredump policy, tmpfiles, udev, PAM, polkit.
- **R9.3** Networking, Bluetooth, живлення/поведінка кришки.
- **R9.4** Nix GC + store optimisation.
- **R9.5** Update — **явна** операція; автооновлення немає.
- **R9.6** Стратегія rollback: попереднє покоління завжди лишається.

## R10. Композитор Mango

- **R10.1** Наявність у nixpkgs; інакше flake input з пінoм на тег, не на main.
- **R10.2** XWayland, scroller за замовчуванням, overview + jump mode.
- **R10.3** blur/shadows/animations вимкнені.
- **R10.4** Робочий базовий конфіг із розкладкою клавіш, не порожній файл.
- **R10.5** Обов'язкові бінди: terminal, launcher, close, fullscreen, floating,
  focus, move, resize, workspace/navigation, scroller navigation, overview,
  jump mode, screenshot, lock, volume, brightness, media keys, power menu,
  monitor/output basics.
- **R10.6** Автозапуск **усіх** shell-компонентів; після login нічого не запускати руками.
- **R10.7** Конфіг має проходити реальну parser-валідацію, якщо Mango це підтримує.

## R11. Оболонка (повна сесія від login до shutdown)

Мінімальний перелік: бар, лаунчер, демон сповіщень, локер, idle-демон,
portals (wlr + gtk), polkit-агент, keyring, менеджер буфера обміну,
скріншот + запис екрана, яскравість, гучність, аплет мережі, аплет Bluetooth,
автомонтування USB, дисплей-менеджер.

Додатково обов'язково перевірити:

- **R11.1** session startup; DBus/session environment; XDG environment; systemd user integration
- **R11.2** XWayland; PipeWire; WirePlumber; аудіоконтролі; медіаклавіші; OSD для volume/brightness
- **R11.3** power menu; logout/reboot/shutdown/suspend; idle/suspend behaviour; поведінка кришки
- **R11.4** конфігурація виходів; hotplug моніторів; шпалери; курсор
- **R11.5** конфігурація вводу; розкладки клавіатури
- **R11.6** історія буфера; drag-and-drop; GTK/Qt file picker; xdg-desktop-portal; портал захоплення екрана
- **R11.7** polkit-агент; Secret Service/keyring; NetworkManager UI; Bluetooth UI; udisks2; автомонтування
- **R11.8** GVfs або кращий аналог; мініатюри; MIME-хендлери; відкриття посилань
- **R11.9** сповіщення від звичайних програм; tray/status notifier
- **R11.10** Чесно написати, що працює гірше, ніж у готовому DE, і де саме болітиме.

## R12. Desktop completeness (сценарії)

Система готова, лише якщо працює: підключення USB; Bluetooth-навушники;
відкриття ZIP; screenshot; шаринг екрана в браузері; magnet/URL/PDF;
Fn-гучність; блокування; закриття кришки; другий монітор; копіювання
картинки між програмами; polkit-діалог; Android через USB.

## R13. Програми

Браузер, dev-браузер, термінал, GUI-файловий менеджер, TUI-файловий менеджер,
архіватор, перегляд зображень, відеоплеєр, аудіоплеєр, PDF, текстовий редактор,
калькулятор, системний монітор, дискові утиліти, менеджер шрифтів, emoji-пікер,
скріншот, запис екрана.

- **R13.1** Для кожного — чому саме він.
- **R13.2** MIME/default handlers налаштовані.
- **R13.3** Не по 2-3 випадкові програми на одну роль.
- **R13.4** Категорії, що залежать від звичок (mail, calendar, office, torrent,
  password manager, cloud sync) — не ігнорувати мовчки, а винести в питання або TODO.

## R14. Тема

- **R14.1** Тематизувати не лише бар: GTK3, GTK4/libadwaita, Qt, іконки, курсор,
  шрифти, термінал, рамки Mango, бар, лаунчер, сповіщення, локскрін, шпалери, OSD.
- **R14.2** Не допускати, щоб половина програм була світлою, половина темною,
  а file picker виглядав як інша ОС.
- **R14.3** Шрифти обов'язково з CJK; кирилиця; емодзі.
- **R14.4** Matugen-вивід **не** має намагатися писати в immutable symlink'и Nix store.
- **R14.5** Зміна шпалер не запускає rebuild; компоненти перечитують тему без
  перезапуску всієї сесії.
- **R14.6** Статичний fallback існує.
- **R14.7** Не ламати GTK/libadwaita нестабільними CSS-хаками.

## R15. Віртуалізація

- **R15.1** libvirt + virt-manager + OVMF.
- **R15.2** ВМ автоматично в `machine.slice`.

## R16. nixmgr (власний інструмент)

- **R16.1** Подивитись `nix-editor` і `nix-software-center` від snowfallorg;
  сказати, що звідти брати, а що писати самому.
- **R16.2** Окремий `managed-packages.nix`, яким володіє **тільки** інструмент.
- **R16.3** Інструмент ніколи не парсить і не чіпає основний конфіг.
- **R16.4** Архітектура: резолвінг імені через `nix search --json`; детект unfree
  через `nix eval meta`; курована таблиця для пакетів, яким потрібен модуль.
- **R16.5** Формат `managed-packages.nix` має дозволяти: безпечно додати,
  безпечно видалити, уникнути дублікатів, відкотити зміну, перевірити `nix eval`,
  запустити rebuild.
- **R16.6** Скелет на Rust: структура, залежності, основні функції; має компілюватись.
- **R16.7** Безпека при двох одночасних процесах.

## R17. Control plane / gt72

- **R17.1** Єдиний локальний control layer для model-specific функцій.
- **R17.2** Рівень команд: status / performance / fan / rgb / wallpaper / display / health.
- **R17.3** CLI — стабільний API для майбутнього GTK4/libadwaita GUI.
- **R17.4** Усередині — sysfs, systemd, D-Bus, PipeWire, validated EC interfaces,
  Matugen, compositor IPC.
- **R17.5** Privileged — з мінімально необхідними правами; не запускати великий GUI від root.

## R18. Declarative vs runtime state

- **R18.1** DECLARATIVE: hardware, служби, пакети, основа сесії, системні дефолти,
  шаблони, механізми, fallback-конфігурація.
- **R18.2** RUNTIME: поточні шпалери, палітра Matugen, історія буфера, media state,
  яскравість/гучність, поточний RGB-стан, тимчасовий performance-профіль, кеш SafeBooru.
- **R18.3** Зміна шпалер або RGB **не** запускає `nixos-rebuild`.

## R19. Health check / self test

- **R19.1** Окремий health-check, який порівнює декларований конфіг із реальним рантаймом.
- **R19.2** Покриття: kernel params, NVIDIA driver/version/modeset, Mango session,
  XWayland, portals, PipeWire/WirePlumber, аудіопристрої, Bluetooth, NetworkManager,
  LAVD, zram, sysctl, NVMe scheduler, MGLRU, THP, filesystem/TRIM, failed systemd units,
  user services, polkit, keyring, removable storage, screen capture portal,
  GT72S-специфічні інтеграції.
- **R19.3** Рівні: OK / WARNING / FAIL / NOT SUPPORTED / EXPERIMENTAL.
- **R19.4** «Nix build успішний» не є доказом, що рантайм працює.

## R20. Update policy

- **R20.1** `flake.lock` — частина source of truth.
- **R20.2** Не оновлювати inputs автоматично.
- **R20.3** Update — явна операція; перед switch зробити eval/build.
- **R20.4** Після switch — health-check; при проблемі лишається попереднє покоління.
- **R20.5** Hardware-critical версії пінити окремо; NVIDIA 580 не оновлювати на іншу гілку автоматично.

## R21. Відтворюваність

Заборонено: unpinned git main/master; `fetchGit` без фіксованої ревізії;
`lib.fakeHash` / `fakeSha256`; mutable remote assets; встановлення пакетів
в activation scripts; `curl | sh`; runtime root writes без причини;
залежності, доступні лише тому, що вони випадково є на цій машині;
home-manager конфіги, які очікують запис у immutable store-файли.

## R22. Acceptance

Після першої збірки має існувати конкретний acceptance checklist,
і система вважається готовою лише якщо всі базові пункти проходять.
Якщо базовий пункт не працює — це TODO конфігурації, а не «користувач доставить сам».
