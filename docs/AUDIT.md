# Аудит репозиторію

**Дата:** 2026-08-20
**Комміт:** `a10bbe4` — гілка `claude/nixos-config-from-scratch-m2xvzg`, робоче дерево чисте
**Файлів у git:** 60
**Аудитор:** агент, самоперевірка власної реалізації

## Що фактично запускалось

| Перевірка | Результат |
|---|---|
| `git status` / `log` / `ls-files` | виконано |
| `cargo check --offline` (nixmgr) | **exit 0**, 0 попереджень |
| `cargo test --offline` (nixmgr) | **exit 0**, **0 тестів** |
| `cargo check --offline` (moewall) | **exit 0**, 0 попереджень |
| `cargo test --offline` (moewall) | **exit 0**, **0 тестів** |
| Статична перевірка балансу дужок, 32 `.nix` | пройдено |
| Статична перевірка дублів атрибутів (scope-aware) | пройдено |
| Існування всіх шляхів у `imports` | пройдено |
| Імена пакетів/опцій проти сирців `nixos-unstable` | пройдено |
| `nix flake check` | **НЕ ЗАПУСКАВСЯ** |
| `nix eval` | **НЕ ЗАПУСКАВСЯ** |
| `nixos-rebuild build` | **НЕ ЗАПУСКАВСЯ** |
| `shellcheck pkgs/gt72/gt72.sh` | **НЕ ЗАПУСКАВСЯ** |

**Точна причина невиконання:** у контейнері немає `nix`, `nix-instantiate`
і `shellcheck` (`command -v` → порожньо для всіх трьох). Мережа до
`cache.nixos.org` є (HTTP 200), але без бінарника `nix` це не допомагає.
`safebooru.org` заблокований egress-проксі (HTTP 000).

Жодне твердження «збірка проходить» у цьому документі не робиться.

---

## Таблиця

| ID | Підсистема | Вимога | Поточна реалізація | Доказ | Статус | Серйозність | Потрібне виправлення |
|---|---|---|---|---|---|---|---|
| A-001 | Відтворюваність | D-002: `flake.lock` — source of truth | Файлу немає в репозиторії | `git ls-files` не містить `flake.lock` | **MISSING** | **BLOCKER** | Згенерувати і закомітити |
| A-002 | Відтворюваність | R21: жодних fake-хешів | `hash = lib.fakeHash` | `pkgs/msiklm/default.nix:32` | **FAIL** | **BLOCKER** | Порахувати реальний хеш |
| A-003 | Відтворюваність | R21 + build matrix DEFAULT | `hash` за замовчуванням `lib.fakeHash`, а `gt72s.msiEc.enable` default `true` → **дефолтна збірка впаде** | `modules/laptop/msi-ec.nix:132` + `:117` | **FAIL** | **BLOCKER** | Порахувати хеш або зробити default `enable = false` |
| A-004 | Відтворюваність | R21: пін на повний SHA | `rev = "e9a7594"` — 7 символів | `pkgs/msiklm/default.nix:30` | **PARTIAL** | MEDIUM | Повний 40-символьний SHA |
| A-005 | Відтворюваність | R21: інпути пінуються | `nixpkgs`/`home-manager` без `flake.lock` не пінуються взагалі | `flake.nix:9,12` + A-001 | **FAIL** | **BLOCKER** | Наслідок A-001 |
| A-010 | Ядро | D-015: 6.18 default | `fennec.kernel.channel = "default"` → `linuxKernel.packages.linux_6_18` | `modules/kernel.nix:38`, `hosts/gt72s/default.nix:75` | **PASS** | INFO | — |
| A-011 | Ядро | D-016/D-017: latest не ламає default | Assertion блокує неперевірену пару без явного підтвердження | `modules/kernel.nix:95-110` | **PASS** | INFO | — |
| A-012 | Ядро | R4.1: канонічні імена | `linuxKernel.packages.*`, не аліас `linuxPackages_6_18` | `modules/kernel.nix:29-48` | **PASS** | INFO | — |
| A-013 | Ядро | D-015 термінологія | Канал названий «6.18 LTS» у промпті; 6.18 не LTS (LTS = 6.12) | `docs/DECISIONS.md` D-015 | **INFO** | INFO | Лише термінологія |
| A-020 | Сховище | **D-024: снапшоти = btrbk** | Реалізовано **Snapper** | `modules/storage.nix:32-70` | **SUPERSEDED** | **HIGH** | Замінити Snapper на btrbk |
| A-021 | Сховище | D-023: `/nix` не снапшотити | Конфіги snapper лише `home` і `root`; `/nix` окремий підтом | `modules/storage.nix:38,52`; `hardware-configuration.nix:79` | **PASS** | INFO | — (лишається чинним і для btrbk) |
| A-022 | Сховище | R8.1: підтоми | `@ @home @nix @log` змонтовані; `@snapshots` **не змонтований** | `hosts/gt72s/hardware-configuration.nix:51-111` | **PARTIAL** | HIGH | Додати монтування `@snapshots` |
| A-023 | Сховище | R8.2: TRIM | `discard=async` у монтуванні; `fstrim` свідомо вимкнений | `hardware-configuration.nix:56`; `storage.nix:88` | **PASS** | INFO | — |
| A-024 | Сховище | R8.3: scrub | `services.btrfs.autoScrub` monthly | `hardware-configuration.nix:120` | **PASS** | INFO | — |
| A-025 | Сховище | R8.5: SMART/NVMe | `smartd` + `nvme-cli` + `smartmontools` | `modules/storage.nix:74-86` | **PASS** | INFO | — |
| A-030 | Безпека | D-030: `mitigations=off` | Присутній, із розгорнутим поясненням ціни | `modules/performance.nix:114` | **PASS** | INFO | — |
| A-031 | Безпека | D-033: Seahorse умовно | Ставиться безумовно | `modules/apps.nix` (список пакетів) | **PARTIAL** | LOW | Рішення D-033 ще OPEN |
| A-040 | Сесія | R11.1: session startup | **Дублювання**: `programs.uwsm` піднімає сесію, і `autostart.sh` робить те саме вручну | `modules/desktop.nix` (uwsm) + `home/mango.nix:365-380` | **PARTIAL** | **HIGH** | Обрати один шлях |
| A-041 | Сесія | D-045: ReGreet | У списку сесій буде **дві** позиції: «Mango» (`sessionPackages`) і «Mango (UWSM)» | `programs.mango` модуль nixpkgs + `programs.uwsm.waylandCompositors` | **PARTIAL** | **HIGH** | Лишити один запис |
| A-042 | Сесія | R11.2: **OSD** для volume/brightness | `swayosd-server` запущено, але: немає `swayosd-libinput-backend`, і жоден бінд не викликає `swayosd-client` (`grep -c swayosd home/mango.nix` = **0**) → **OSD не показуватиметься** | `modules/desktop.nix` (user service); `home/mango.nix:290-300` | **FAIL** | **HIGH** | Або libinput-backend, або `swayosd-client` у біндах |
| A-043 | Сесія | R6.11: без дублювання | Власні udev-правила на backlight/leds дублюють `data/udev/99-swayosd.rules` із пакета | `modules/desktop.nix` (свої правила); пакет `swayosd` містить свої | **PARTIAL** | MEDIUM | `services.udev.packages = [ pkgs.swayosd ]` |
| A-044 | Сесія | R11.4: hotplug моніторів | `kanshi` **лише встановлений**: немає ні служби, ні конфігу, ні профілів | `modules/desktop.nix` (пакет); grep служби — порожньо | **PARTIAL** | **HIGH** | Додати службу + профілі |
| A-045 | Сесія | R10.5: бінди без конфліктів | `SUPER+SHIFT,l` призначений **двічі**: `exchange_client,right` і `swaylock` | `home/mango.nix:226` та `:288` | **FAIL** | **HIGH** | Перепризначити один |
| A-046 | Сесія | R10.5: теги | `bind=SUPER,0,view,0`, але `tag_num` не заданий → діє апстрімний `tag_num=9`, тега 0 не існує | `home/mango.nix:258`; `tag_num` відсутній | **FAIL** | MEDIUM | Або `tag_num=10`, або прибрати бінд |
| A-047 | Сесія | R10.5: решта біндів | terminal, launcher, close, fullscreen, floating, focus, move, resize, теги, scroller, overview, jump, screenshot, lock, media, power menu — усі присутні | `home/mango.nix:186-300` | **PASS** | INFO | — |
| A-048 | Сесія | R10.7: parser-валідація конфігу | Не запускалась | немає `mango` у середовищі | **UNVERIFIED** | MEDIUM | Перевірити на машині |
| A-049 | Сесія | R11.6: історія буфера | `cliphist-text`, `cliphist-image`, `wl-clip-persist` як user-сервіси | `home/default.nix:159-200` | **PASS** | INFO | — |
| A-050 | Сесія | R11.7: аплети | `udiskie`, `nm-applet`, `blueman-applet`, `swayidle` як user-сервіси | `home/default.nix:202-276` | **PASS** | INFO | — |
| A-051 | Сесія | R11.7: polkit-агент | systemd user service, прив'язаний до `graphical-session.target` | `modules/desktop.nix` (кінець файлу) | **PASS** | INFO | — |
| A-052 | Сесія | R11.6: портали | `programs.mango` сам налаштовує wlr+gtk і порядок; додано `xdgOpenUsePortal` | модуль nixpkgs `programs/wayland/mango.nix` | **PASS** | INFO | — |
| A-053 | Сесія | R11.6: вибір **вікна** для шаринга | `xdg-desktop-portal-wlr` вміє лише монітор | обмеження апстріму | **NOT-APPLICABLE** | INFO | Задокументовано в health-check |
| A-054 | Сесія | R11.10: чесний перелік болю | `docs/shell-stack.md`, 140 рядків | файл існує | **PASS** | INFO | — |
| A-060 | Програми | D-061: libadwaita-набір | Nautilus, Loupe, Papers, Decibels, File Roller, Text Editor, Resources, Characters | `modules/apps.nix` | **PASS** | INFO | — |
| A-061 | Програми | D-062: Celluloid | Присутній | `modules/apps.nix` | **PASS** | INFO | — |
| A-062 | Програми | R13.2: MIME | **Два джерела**: `xdg.mime.defaultApplications` (система) і `xdg.mimeApps` (home) | `modules/apps.nix`; `home/default.nix:281` | **PARTIAL** | MEDIUM | Звести до одного |
| A-063 | Програми | D-065: декод 980M | Firefox: VP9/AV1 вимкнені, VA-API увімкнено | `modules/apps.nix` (`programs.firefox.preferences`) | **PASS** | INFO | — |
| A-064 | Програми | R13.4: категорії за звичками | mail/office/torrent/cloud винесені в TODO, не проігноровані | `docs/PROGRESS.md` | **PASS** | INFO | — |
| A-070 | NVIDIA | D-011/D-012 | `legacy_580`, `open = false` | `modules/nvidia.nix:67-70` | **PASS** | INFO | — |
| A-071 | NVIDIA | R7.2 | modeset + PreserveVideoMemoryAllocations + suspend/resume-юніти | `modules/nvidia.nix`; `performance.nix:83,88` | **PASS** | INFO | — |
| A-072 | NVIDIA | **R7.5**: 32-бітний стек лише при gaming | `enable32Bit = true` **безумовно** | `modules/nvidia.nix:63` | **PARTIAL** | MEDIUM | Прив'язати до `fennec.gaming.enable` |
| A-073 | NVIDIA | R7.1: версія з піна | Без `flake.lock` версію зафіксувати неможливо | A-001 | **UNVERIFIED** | HIGH | Наслідок A-001 |
| A-080 | Продуктивність | R6.1-R6.9 | scx_lavd, zram 16 ГБ zstd, swappiness 180, page-cluster 0, max_map_count, dirty_bytes, vfs_cache_pressure, NVMe none, MGLRU, THP=madvise, oomd | `modules/performance.nix` | **PASS** | INFO | — |
| A-081 | Продуктивність | R6.11: один керівник живлення | TuneD увімкнено, PPD явно вимкнено, TLP/auto-cpufreq відсутні; health-check рахує керівників | `performance.nix:236`; `pkgs/gt72/gt72.sh` | **PASS** | INFO | — |
| A-082 | Продуктивність | R6.10: декларативність | MGLRU через `systemd.tmpfiles`, планувальник через udev | `performance.nix:166,190` | **PASS** | INFO | — |
| A-090 | Віртуалізація | R15.1/R15.2 | libvirt + OVMF + swtpm + `machine.slice` | `modules/virtualisation.nix:10-60` | **PASS** | INFO | — |
| A-100 | Android | D-098: nix-ld | Налаштований із повним списком бібліотек | `modules/android.nix:70-105` | **PASS** | INFO | — |
| A-101 | Android | D-098: udev | Правила по класу USB-інтерфейсу (`ff4201`/`ff4203`), група `adbusers` створюється вручну | `modules/android.nix:110-125` | **PASS** | INFO | Перевірити на пристрої |
| A-102 | Android | D-098: KVM | `kvm-intel`, користувач у групі `kvm`, assertion на XWayland | `modules/android.nix:130-145` | **PASS** | INFO | — |
| A-103 | Android | R: межа declarative/mutable SDK | Пояснено, що SDK керується Studio у `~/Android/Sdk` | `modules/android.nix:75-85` | **PASS** | INFO | — |
| A-110 | Flatpak | D-070 | `services.flatpak` + Flathub через ідемпотентний oneshot + тематизація | `modules/flatpak.nix` | **PASS** | INFO | — |
| A-111 | GeForce NOW | D-080 | App ID `com.nvidia.geforcenow` задокументований; репозиторій **не підтверджений** | `modules/flatpak.nix` (коментар) | **UNVERIFIED** | MEDIUM | `flatpak search geforcenow` на машині |
| A-112 | GeForce NOW | Vulkan Video на 980M | Не доводиться без заліза | — | **ON-DEVICE** | HIGH | Див. HARDWARE-VALIDATION |
| A-120 | Тема | D-050/D-052 | Matugen пише в `~/.config/*/colors.*`, не в store | `home/theme.nix:60-160` | **PASS** | INFO | — |
| A-121 | Тема | D-053: fallback | `swaybg -c '#0d0d10'`, якщо шпалери ще немає | `home/mango.nix:386` | **PASS** | INFO | — |
| A-122 | Тема | R14.1: повне покриття | Шаблони на foot, waybar, mango, mako, fuzzel, fish, rgb — **немає** для локскріна (swaylock) і ReGreet | `home/matugen-templates/` — 7 файлів | **PARTIAL** | MEDIUM | Додати шаблони |
| A-130 | moewall | D-140-D-146 | rating:safe, аспект, роздільність, яскравість, насиченість, відтінки, dedup, кеш, favourites, blacklist, атомарний запис | `tools/moewall/src/{source,analyse,state}.rs` | **PASS** | INFO | — |
| A-131 | moewall | **D-147: запис source URL** | Не знайдено | `grep -rn "source_url\|post_url\|origin"` → порожньо | **MISSING** | MEDIUM | Додати |
| A-132 | moewall | R: retries на мережевих збоях | Є таймаути, немає повторів | `tools/moewall/src/source.rs:71-82` | **MISSING** | MEDIUM | Додати backoff |
| A-133 | moewall | SafeBooru API | Ендпоінт не перевірявся; структура терпима до варіантів `file_url` | `source.rs:8-13` (самозадокументовано) | **UNVERIFIED** | HIGH | **UNVERIFIED EXTERNAL API** |
| A-134 | moewall | Компіляція | `cargo check` exit 0, 0 попереджень | запущено | **PASS** | INFO | — |
| A-135 | moewall | Тести | 0 тестів | `cargo test` → `0 passed` | **MISSING** | MEDIUM | Додати юніт-тести на аналіз/стан |
| A-140 | nixmgr | D-160/D-161 | Працює лише з `managed-packages.nix` через маркери | `tools/nixmgr/src/edit.rs:45-48` | **PASS** | INFO | — |
| A-141 | nixmgr | D-162: unfree | `nix eval` з `NIXPKGS_ALLOW_UNFREE=1` + `--impure`, з поясненням чому | `tools/nixmgr/src/meta.rs:37-74` | **PASS** | INFO | — |
| A-142 | nixmgr | D-163: транзакція | `.bak` + tmp + `rename` + `restore` | `tools/nixmgr/src/edit.rs:68,159-176` | **PASS** | INFO | — |
| A-143 | nixmgr | **R16.7: два процеси одночасно** | Локу немає взагалі | `grep -rniE "flock\|lockfile\|O_EXCL"` → порожньо | **MISSING** | **HIGH** | Додати lock-файл |
| A-144 | nixmgr | R16.1: аналіз snowfallorg | Розгорнуто в коментарях, із висновком що брати і що ні | `tools/nixmgr/src/edit.rs:3-30`, `main.rs:21-25` | **PASS** | INFO | — |
| A-145 | nixmgr | R16.6: компілюється | `cargo check` exit 0 | запущено | **PASS** | INFO | — |
| A-146 | nixmgr | Тести | 0 тестів | `cargo test` → `0 passed` | **MISSING** | MEDIUM | Тести на `between`/`replace_between` |
| A-147 | nixmgr | Довговічність запису | `rename` без `fsync` | `edit.rs:159-166` | **PARTIAL** | LOW | fsync перед rename |
| A-150 | Control plane | R17.2/R17.3 | `gt72` з підкомандами і `--json` | `pkgs/gt72/gt72.sh` | **PASS** | INFO | — |
| A-151 | Control plane | R17.4: без raw EC | `performance` іде через `tuned-adm`; `audio probe` лише читає | `gt72.sh` (cmd_performance, cmd_audio_probe) | **PASS** | INFO | — |
| A-152 | Control plane | R17.2: `fan`, `rgb`, `wallpaper`, `display` | Підкоманд **немає** — лише `status/health/performance/audio` | `gt72.sh` (usage) | **PARTIAL** | MEDIUM | Додати або задокументувати як делеговані |
| A-153 | Control plane | Валідація скрипта | shellcheck не запускався | немає бінарника | **UNVERIFIED** | MEDIUM | Ризик провалу `writeShellApplication` |
| A-160 | Health check | R19.2/R19.3 | Усі перелічені групи покриті, 5 рівнів статусу | `gt72.sh` + `modules/health.nix` | **PASS** | INFO | — |
| A-161 | Acceptance | R22 | 28-пунктовий чекліст у `/etc/fennec/acceptance-test.md` | `modules/health.nix` | **PASS** | INFO | — |
| A-170 | Ідентичність | D-173 | Реалізовано `fennec`; audit-промпт посилається на `gt72s` | `flake.nix:35` | **OPEN** | HIGH | Потрібне рішення користувача |
| A-171 | Ідентичність | D-170: розкладки | `services.xserver.xkb.layout = "ua,us"` | `hosts/gt72s/default.nix:117` | **PASS** | INFO | Синхронність із mango не перевірена |
| A-180 | GT72S | D-121: msi-ec проти BIOS | Ревізія пінована, коментар посилається на `1782EMS1.109` | `modules/laptop/msi-ec.nix:123` | **ON-DEVICE** | HIGH | Звірити з `dmidecode` |
| A-181 | GT72S | D-124: 5 зон RGB | Реалізовано 6-аргументний і 3-аргументний виклик | `modules/laptop/rgb.nix:70-79` | **ON-DEVICE** | HIGH | Потребує пристрою |
| A-182 | GT72S | D-126/D-127: woofer | Модуль pin-патча існує, за замовчуванням **вимкнений**; `gt72 audio probe` дає діагностику | `modules/laptop/audio-subwoofer.nix:76` | **ON-DEVICE** | HIGH | Правильно лишити вимкненим |
| A-183 | GT72S | D-128: 75 Гц | Вимкнено за замовчуванням, не потрібне для boot | `modules/laptop/panel-75hz.nix:86` | **ON-DEVICE** | MEDIUM | — |
| A-184 | GT72S | R6.11: fan vs thermald | `coolerGuard` (default `true`) і `thermald` (увімкнений) обидва реагують на температуру | `msi-ec.nix:138`; `performance.nix:250` | **PARTIAL** | **HIGH** | Довести відсутність боротьби |

---

## A. BLOCKERS — заважають першій збірці

| ID | Проблема | Чому блокує |
|---|---|---|
| A-003 | `gt72s.msiEc.enable` = `true` за замовчуванням, а `hash` = `lib.fakeHash` | `nixos-rebuild build` для **дефолтної** матриці впаде на hash mismatch. Прямо суперечить «default 6.18 повинен лишатися buildable» |
| A-002 | `pkgs/msiklm` з `lib.fakeHash` | `nix flake check` будує `packages.*` → провал. `nix build .#msiklm` теж |
| A-001 / A-005 | `flake.lock` відсутній | D-002 називає його source of truth. Без нього версії не пінуються, і твердження «NVIDIA 580.x з піна» не має підстав |

Це три окремі причини, і жодна з них не виявляється статичним аналізом —
обидва fakeHash проходять eval і падають на етапі fixed-output derivation.

## B. WRONG / SUPERSEDED IMPLEMENTATIONS

| ID | Реалізовано | Актуальне рішення |
|---|---|---|
| A-020 | Snapper (`modules/storage.nix:32-70`) | **btrbk** (D-024) |

Це єдина знайдена superseded-реалізація. Вона потрапила в код тому, що
раніший раунд питань зафіксував Snapper, а пізніший canonical-список змінив
рішення на btrbk. Реалізація за пізнішим рішенням **не** переписувалась.

## C. MISSING REQUIREMENTS

| ID | Вимога | Стан |
|---|---|---|
| A-143 | R16.7: безпека при двох одночасних `nixmgr` | локу немає взагалі |
| A-131 | D-147: запис source URL у moewall | відсутнє |
| A-132 | retries на мережевих збоях moewall | відсутнє |
| A-022 | монтування підтому `@snapshots` | у `fileSystems` його немає |
| A-135, A-146 | тести для обох крейтів | 0 тестів у кожному |
| A-152 | `gt72 fan` / `rgb` / `wallpaper` / `display` | підкоманд немає |

## D. PARTIAL IMPLEMENTATIONS

| ID | Що не доведено до daily-driver якості |
|---|---|
| A-042 | **OSD гучності/яскравості фактично не працюватиме** — сервер є, джерела подій немає |
| A-044 | kanshi встановлений, але без служби і профілів — hotplug моніторів не реалізований |
| A-040, A-041 | uwsm і `autostart.sh` дублюють підйом сесії; у ReGreet буде два записи «Mango» |
| A-045 | `SUPER+SHIFT+l` призначений двічі |
| A-046 | `view,0` при `tag_num=9` |
| A-072 | 32-бітна графіка безумовна (R7.5 просив прив'язку до gaming) |
| A-062 | MIME визначені у двох місцях |
| A-122 | немає matugen-шаблонів для локскріна і ReGreet |
| A-184 | `coolerGuard` і `thermald` обидва активні за замовчуванням |
| A-043 | власні udev-правила дублюють правила з пакета swayosd |

## E. REPRODUCIBILITY PROBLEMS

1. **A-001** — `flake.lock` відсутній.
2. **A-002** — `lib.fakeHash` у `pkgs/msiklm/default.nix:32`.
3. **A-003** — `lib.fakeHash` як default опції в `modules/laptop/msi-ec.nix:132`.
4. **A-004** — скорочений `rev = "e9a7594"` замість повного SHA.

Чого **не** знайдено (перевірено grep-ом по всьому дереву): `fetchGit` без ревізії,
`curl | sh`, встановлення пакетів в activation scripts, посилань на `main`/`master`
без піна, home-manager конфігів, що пишуть у store.

## F. ON-DEVICE VALIDATION

Повний перелік із командами — `docs/HARDWARE-VALIDATION.md`.
Коротко: A-112 (Vulkan Video / GFN), A-180 (msi-ec vs BIOS), A-181 (RGB-зони),
A-182 (woofer), A-183 (75 Гц), A-101 (Android USB), A-048 (парсер конфігу Mango),
A-133 (SafeBooru API — недоступний і з мережі агента).

## G. VERIFIED GOOD

Це те, під чим стоїть **фактично запущена** команда або прочитаний сирець
апстріму, а не враження:

- Обидва Rust-крейти компілюються: `cargo check` exit 0, **0 попереджень**.
- 32 `.nix` збалансовані за дужками; дублів атрибутів у межах області немає;
  усі шляхи в `imports` існують.
- Кожне ім'я пакета й опції звірене з сирцями `nixos-unstable`
  (`by-name/`, `all-packages.nix`, `module-list.nix`), а не з пам'яті.
- Виявлено і виправлено два deprecated-імені: `linuxPackages_6_18` (аліас),
  `nixfmt-rfc-style` (аліас із попередженням).
- Виявлено, що `programs.adb` більше не існує в nixpkgs — правила написані самі.
- Покриття біндів Mango (A-047) повне за списком R10.5.
- Розділення declarative/runtime витримане: matugen пише в `~/.config`, не в store.

## H. PROPOSED FIX ORDER

Порядок підібраний так, щоб кожен крок був перевірюваним і не блокувався наступним.

1. **A-001** — згенерувати `flake.lock`. Без нього решту не перевірити.
2. **A-003, A-002, A-004** — реальні хеші для `msi-ec` і `msiklm`.
   Після цього вперше стає можливим `nixos-rebuild build`.
3. **Запустити збірку дефолтної матриці.** Усе нижче — вже проти робочої бази.
4. **A-020** — Snapper → btrbk, разом із **A-022** (монтування `@snapshots`).
   Одна зміна, одна підсистема.
5. **A-040/A-041** — вирішити uwsm vs autostart і прибрати другий запис сесії.
   Це передумова для A-042 і A-044, бо всі троє залежать від того,
   хто саме піднімає `graphical-session.target`.
6. **A-042** — OSD; **A-044** — kanshi. Обидва стають тривіальними після кроку 5.
7. **A-045, A-046** — конфлікт біндів і `view,0`. Дешево, ізольовано.
8. **A-184** — довести розмежування `coolerGuard` vs `thermald` (або вимкнути одне).
9. **A-143** — lock у nixmgr; **A-131, A-132** — source URL і retries в moewall.
10. **A-072, A-062, A-043, A-122** — дрібні чистки.
11. **A-135, A-146** — тести.
12. **A-170** — рішення про ім'я хоста (потребує тебе, не коду).

Кроки 1-3 обов'язково послідовні. Кроки 4, 9, 10, 11 незалежні один від одного.

---

# REMEDIATION PASS — 2026-08-20

Комміти: `ec37517`, `858497c`, `7b132e0`, `38aa174`.
Старі findings **не видалені** — нижче їхній стан після виправлень.

## Що фактично запускалось у цьому проході

| Перевірка | Результат |
|---|---|
| `bash -n bootstrap.sh` | **exit 0** |
| `cargo check --offline` × 2 крейти | **exit 0**, 0 попереджень |
| баланс дужок, 33 `.nix` | пройдено |
| дублі атрибутів (scope-aware) | 3 відомі хибні спрацювання, передивлені вручну |
| існування імпортів | пройдено |
| `nix flake check` / `eval` / `build` | **НЕ ЗАПУСКАЛИСЬ — у середовищі немає `nix`** |
| `shellcheck` | **НЕ ЗАПУСКАВСЯ — немає бінарника** |

## Стан попередніх findings

| ID | Було | Стало | Як саме |
|---|---|---|---|
| A-001 | BLOCKER: немає flake.lock | **BLOCKED-ON-DEVICE** | Згенерувати без `nix` неможливо. `bootstrap.sh` крок 7 створює його на машині і вимагає закомітити |
| A-002 | BLOCKER: fakeHash у msiklm | **RESOLVED (обхід)** | Прибрано з `packages.<system>`, тож `nix flake check` більше не падає. Повний SHA підставлено. Хеш рахує bootstrap крок 6 |
| A-003 | BLOCKER: fakeHash у дефолтній збірці | **RESOLVED** | Дефолт бере `msi-ec` із nixpkgs (справжній хеш). Своя ревізія — opt-in `overrideSource` + assertion |
| A-004 | скорочений rev | **RESOLVED** | Повний 40-символьний SHA |
| A-020 | SUPERSEDED: Snapper | **RESOLVED** | Замінено на btrbk згідно D-024 |
| A-022 | @snapshots не змонтований | **RESOLVED** | Додано `/.btrfs` (subvolid=5) |
| A-040 | uwsm × autostart дублювання | **RESOLVED (як задокументовано)** | autostart ідемпотентний під обома; пояснено в `desktop.nix` |
| A-041 | два записи сесії | **RESOLVED (свідоме рішення)** | Другий запис лишено як recovery-шлях, задокументовано |
| A-042 | OSD не працює | **RESOLVED** | Бінди на `swayosd-client` + системний `swayosd-libinput-backend` |
| A-043 | дубльовані udev-правила | **RESOLVED** | `services.udev.packages = [ pkgs.swayosd ]` |
| A-044 | kanshi без служби | **RESOLVED** | User-сервіс + конфіг із трьома профілями |
| A-045 | конфлікт SUPER+SHIFT+l | **RESOLVED** | Блокування на SUPER+Escape |
| A-046 | `view,0` при tag_num=9 | **RESOLVED** | Бінд прибрано, `tag_num=9` задано явно |
| A-062 | MIME у двох місцях | **RESOLVED, серйозніше ніж вважалось** | Див. A-190 нижче |
| A-072 | 32-бітна графіка безумовна | **ВІДКРИТО** | Не чіпав: прив'язка до gaming вимагає перевірки, що Flatpak-GFN не потребує 32-біт |
| A-111 | GFN репозиторій | **BLOCKED-ON-DEVICE** | `flatpak search geforcenow` на машині |
| A-122 | немає шаблонів теми для локскріна/ReGreet | **ВІДКРИТО** | REQ-244..246 |
| A-131 | moewall не пише source URL | **ВІДКРИТО** | REQ-377 |
| A-132 | moewall без retry | **ВІДКРИТО** | REQ-378 |
| A-133 | SafeBooru API | **BLOCKED-ON-DEVICE** | Хост заблокований проксі агента |
| A-143 | nixmgr без локу | **ВІДКРИТО** | REQ-342 |
| A-152 | gt72 без fan/rgb/wallpaper | **ВІДКРИТО** | REQ-349 |
| A-153 | gt72.sh без shellcheck | **BLOCKED-ON-DEVICE** | Немає бінарника; `writeShellApplication` перевірить під час першої збірки |
| A-170 | ім'я хоста | **OPEN** | Потрібне твоє рішення |
| A-184 | coolerGuard × thermald | **BLOCKED-ON-DEVICE** | Процедура перевірки — `HARDWARE-VALIDATION.md §5` |

## Нові findings цього проходу

| ID | Підсистема | Проблема | Доказ | Серйозність | Стан |
|---|---|---|---|---|---|
| A-190 | Програми | `home/default.nix` встановлював **повний старий набір** (nemo, imv, mpv, zathura, smile, font-manager, mission-center) паралельно з libadwaita-набором із `apps.nix`. По дві програми на роль; `SUPER+e` відкривав nemo | git diff `7b132e0` | **HIGH** | **RESOLVED** |
| A-191 | MIME | `~/.config/mimeapps.list` вказував на zathura/imv — програми, яких у системі вже немає. Має вищий пріоритет за `/etc`, тож подвійний клік по PDF не робив би **нічого** | `home/default.nix` до `7b132e0` | **HIGH** | **RESOLVED** |
| A-192 | Bootstrap | Детекція і політика заліза не були розділені: автоматизація мусила або затерти опції монтування, або втратити UUID | `hosts/gt72s/hardware-configuration.nix` до `38aa174` | HIGH | **RESOLVED** |

**A-190/A-191 — це промах першого аудиту.** Я перевірив `modules/apps.nix` і
`modules/desktop.nix`, але не список пакетів у `home/default.nix`, і тому
оцінив дублювання MIME як MEDIUM «два джерела», хоча насправді там був
непрацездатний набір асоціацій.
