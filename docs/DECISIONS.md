# Рішення

Кожне рішення має статус: **LOCKED** / **OPEN** / **EXPERIMENTAL** / **SUPERSEDED**.

LOCKED не перепитується. Питання дозволені лише для OPEN, і лише коли
відповідь реально змінює архітектуру.

Останнє оновлення: 2026-08-20.

---

## Платформа

| ID | Рішення | Статус |
|---|---|---|
| D-001 | nixpkgs канал `nixos-unstable` | LOCKED |
| D-002 | `flake.lock` є source of truth; версії перевіряти проти пінa | LOCKED |
| D-003 | Flakes + home-manager як NixOS-модуль (одне замикання) | LOCKED |
| D-004 | Модульна структура, коментарі українською | LOCKED |

**Обґрунтування D-001:** пакет `mango` 0.16.0 і модуль `programs.mango` існують
тільки в unstable. У `nixos-26.05` обидва шляхи віддають 404.

---

## Залізо і ядро

| ID | Рішення | Статус |
|---|---|---|
| D-010 | MSI GT72S 6QE: i7-6820HK, GTX 980M (GM204), 48 ГБ, 970 EVO Plus, 1080p 75 Гц, апаратний MUX | LOCKED |
| D-011 | NVIDIA **лише** пропрієтарний `legacy_580`; 590+ не бачить Maxwell | LOCKED |
| D-012 | `hardware.nvidia.open = false` — у GM204 немає GSP | LOCKED |
| D-013 | Жодного автоматичного fallback на nouveau/NVK | LOCKED |
| D-014 | Не брати production/stable гілку драйвера наосліп | LOCKED |
| D-015 | Ядро **6.18 за замовчуванням**, 7.2 окремим opt-in | LOCKED |
| D-016 | latest-ядро не повинно ламати робочий default | LOCKED |
| D-017 | NVIDIA 580 + latest вважається **неперевіреним**, доки не пройде реальний build/boot | EXPERIMENTAL |

**Обґрунтування D-015/D-017:** у `nvidia-x11/default.nix` блок `legacy_580`
не має ні `patches`, ні `broken`; kernel-compat патчі визначені в `let`, але
не застосовані до жодної гілки. Hydra цю пару не збирає.

> Термінологічна поправка: 6.18 — це **не** LTS. LTS у nixpkgs — 6.12
> (`linuxKernel.packages.linux_6_12`). У конфізі 6.18 обраний як
> *nixpkgs default*, і саме так названий канал `default`.

---

## Диск і файлова система

| ID | Рішення | Статус |
|---|---|---|
| D-020 | Шифрування диска **вимкнене** | LOCKED |
| D-021 | Btrfs, підтоми `@ @home @nix @log @snapshots` | LOCKED |
| D-022 | Без дискового swap; zram 16 ГБ zstd | LOCKED |
| D-023 | `/nix` **не** снапшотити | LOCKED |
| D-024 | Снапшоти: **btrbk** | LOCKED |
| ~~D-024a~~ | ~~Снапшоти: Snapper~~ | **SUPERSEDED** → D-024 |
| D-025 | Retention розумний для десктопу; volatile/VM/cache не роздувають снапшоти | LOCKED |

**Історія D-024a → D-024.** У ранньому раунді питань користувач обрав
«@ @home @nix @log @snapshots + snapper». Пізніше в canonical LOCKED-списку
рішення змінено на **btrbk**. Причина зміни користувачем не пояснена; діє
пріоритет «найновіше явне рішення». Реалізація в `modules/storage.nix` досі
містить Snapper — це divergence, зафіксований в `docs/AUDIT.md` як A-020.

---

## Безпека

| ID | Рішення | Статус |
|---|---|---|
| D-030 | `mitigations=off` — свідоме рішення користувача | LOCKED |
| D-031 | Окремого менеджера паролів немає (користувач їх не любить) | LOCKED |
| D-032 | gnome-keyring лишається як Secret Service-інфраструктура, розблокування через PAM | LOCKED |
| D-033 | Seahorse — **тільки якщо** потрібен системному secret stack | OPEN |

**D-030 наслідок:** health-check зобов'язаний показувати кількість відкритих
вразливостей, а не мовчати. Це не заперечення рішення, а видимість ціни.

---

## Сесія і робочий стіл

| ID | Рішення | Статус |
|---|---|---|
| D-040 | Композитор Mango; без GNOME Shell/KWin як основного DE | LOCKED |
| D-041 | Розкладка scroller за замовчуванням | LOCKED |
| D-042 | Overview + jump mode обов'язкові | LOCKED |
| D-043 | XWayland обов'язковий | LOCKED |
| D-044 | Повноцінний custom shell; Mango-конфіг не placeholder | LOCKED |
| D-045 | Login: greetd + **ReGreet** | LOCKED |
| D-046 | Без постійного blur, без важких шейдерів, анімації вимкнені (4 ГБ VRAM) | LOCKED |

---

## Тема

| ID | Рішення | Статус |
|---|---|---|
| D-050 | **Matugen** як джерело палітри | LOCKED |
| D-051 | Естетика: colorful brutalism, subtle noise, sharp geometry, slight rounding, expressive кольори зі шпалер | LOCKED |
| D-052 | Палітра змінюється **runtime**, без `nixos-rebuild` | LOCKED |
| D-053 | Статичний fallback-вигляд має існувати | LOCKED |
| ~~D-054~~ | ~~Catppuccin / Rose Pine / Sakura Dusk / Neon Moe~~ | **SUPERSEDED** → D-051 |
| D-055 | Stylix **не** використовується | LOCKED |

**Обґрунтування D-055:** Stylix — це тематизація на етапі eval. Тема тут
керується Matugen у рантаймі (зміна шпалер не запускає rebuild). Два джерела
істини для кольорів суперечили б D-052.

---

## Програми

| ID | Рішення | Статус |
|---|---|---|
| D-060 | libadwaita-first hybrid; **функціональність перемагає**, коли libadwaita-варіант гірший | LOCKED |
| D-061 | Nautilus, Loupe, Papers, Decibels, File Roller, GNOME Text Editor, Resources, Characters | LOCKED |
| D-062 | Відео — **Celluloid** (GTK4-фронтенд до mpv) | LOCKED |
| D-063 | Firefox — основний браузер | LOCKED |
| D-064 | Chromium — окремо для Android/WebView-розробки | LOCKED |
| D-065 | Врахувати межі апаратного декоду 980M; не змушувати VP9/AV1 йти на CPU | LOCKED |

**Апаратний факт під D-065:** GM204 має фіксований декодер **тільки для H.264**.
HEVC отримали лише GM206/GM200; AV1 не декодує жоден Maxwell.

---

## Flatpak

| ID | Рішення | Статус |
|---|---|---|
| D-070 | Flatpak увімкнено, Flathub, повна portal-інтеграція | LOCKED |
| D-071 | Flatpak-застосунки можуть лишатися **імперативним user state** | LOCKED |
| D-072 | Nix/nixmgr — основний package/control layer; Flatpak — fallback | LOCKED |

**Технічна межа:** модуль `services.flatpak` має рівно дві опції (`enable`,
`package`). Декларативних remotes/packages не існує — тому імперативність
застосунків не компроміс, а точна відповідність можливостям.

---

## Ігри

| ID | Рішення | Статус |
|---|---|---|
| D-080 | **GeForce NOW first-class** (нативний Linux-клієнт, Flatpak `com.nvidia.geforcenow`) | LOCKED |
| D-081 | Локальні ігри — не основний workload | LOCKED |
| D-082 | `modules/gaming.nix` готовий, default **disabled** | LOCKED |
| D-083 | При enable: Steam + Proton + 32-bit графіка + GameMode | LOCKED |
| D-084 | Gamescope — окремий optional toggle | LOCKED |

---

## Розробка

| ID | Рішення | Статус |
|---|---|---|
| D-090 | AI-assisted development first | LOCKED |
| D-091 | Claude Code + Codex — first-class (обидва є в nixpkgs) | LOCKED |
| D-092 | Універсальні базові інструменти в системі | LOCKED |
| D-093 | direnv + nix-direnv | LOCKED |
| D-094 | `uv` для Python-workflow | LOCKED |
| D-095 | Podman + Distrobox | LOCKED |
| D-096 | Language toolchains — переважно per-project devShell | LOCKED |
| D-097 | Android-розробка — **first-class основний workload** | LOCKED |
| D-098 | Android Studio, adb, fastboot, udev, KVM, JDK/SDK, фізичні пристрої | LOCKED |
| ~~D-099~~ | ~~Neovim як основний редактор~~ | **SUPERSEDED** → D-090 (IDE + агенти основні; helix як легкий fallback) |

**Технічна знахідка під D-098:** NixOS-модуля `programs.adb` більше **не існує**
(`nixos/modules/programs/adb.nix` → 404, у `module-list.nix` відсутній), пакета
`android-udev-rules` теж немає. Правила пишемо самі, по класу USB-інтерфейсу.

---

## Друк і сканування

| ID | Рішення | Статус |
|---|---|---|
| D-100 | Не входить у базу; optional disabled module | LOCKED |

---

## Віртуалізація

| ID | Рішення | Статус |
|---|---|---|
| D-110 | libvirt + virt-manager + OVMF | LOCKED |
| D-111 | Процеси ВМ у `machine.slice` | LOCKED |

---

## GT72S hardware-first

| ID | Рішення | Статус |
|---|---|---|
| D-120 | Система інтегрує конкретний MSI GT72S 6QE, а не «ноутбук взагалі» | LOCKED |
| D-121 | `msi-ec` перевіряти проти точного BIOS/model support | LOCKED |
| D-122 | Cooler Boost / fan / thermal інтеграція | LOCKED |
| D-123 | MSIKLM/RGB investigation | LOCKED |
| D-124 | 3 зони клавіатури + 2 фронтальні, якщо залізо реально доступне | LOCKED |
| D-125 | Matugen → RGB у рантаймі | LOCKED |
| D-126 | Фізичний Dynaudio woofer **існує**; не списувати як «можливо пасивний» | LOCKED |
| ~~D-126a~~ | ~~Woofer може бути пасивним резонатором~~ | **SUPERSEDED** → D-126 |
| D-127 | Audio routing/subwoofer потребує реальної hardware validation | ON-DEVICE |
| D-128 | 75 Гц — experimental, не потрібне для boot | EXPERIMENTAL |
| D-129 | Рівні зрілості: STABLE / SUPPORTED-WITH-QUIRK / EXPERIMENTAL / UNSUPPORTED | LOCKED |
| D-130 | Жодних raw EC writes наосліп | LOCKED |

---

## Шпалери (moewall)

| ID | Рішення | Статус |
|---|---|---|
| D-140 | Джерело SafeBooru, **safe only** | LOCKED |
| D-141 | Близько до 16:9, достатня роздільність для 1080p | LOCKED |
| D-142 | Уникати washed-out/білих; перевага темним і кольоровим | LOCKED |
| D-143 | Бажані відтінки: green/blue/purple/cyan/teal | LOCKED |
| D-144 | Кеш, уникнення дублікатів, ручний next/refresh | LOCKED |
| D-145 | Favourite/keep, blacklist | LOCKED |
| D-146 | Аналіз кольору → Matugen → RGB | LOCKED |
| D-147 | Запис source URL | LOCKED |
| D-148 | Усе це — рантайм, **без rebuild** | LOCKED |

---

## Control plane

| ID | Рішення | Статус |
|---|---|---|
| D-150 | Nix бере максимум reproducible state | LOCKED |
| D-151 | Користувач не редагує Nix руками для звичайних дій | LOCKED |
| D-152 | Майбутній CLI + GTK4/libadwaita GUI | LOCKED |
| D-153 | Апаратні функції — не набір випадкових shell-скриптів | LOCKED |
| D-154 | Privileged helper має мінімальні привілеї | LOCKED |

---

## nixmgr

| ID | Рішення | Статус |
|---|---|---|
| D-160 | `managed-packages.nix` належить **тільки** nixmgr | LOCKED |
| D-161 | Основні конфіги nixmgr не парсить і не редагує **ніколи** | LOCKED |
| D-162 | Fuzzy пошук → точний атрибут → unfree detection → курована таблиця модулів | LOCKED |
| D-163 | Safe edit, eval/build, rollback файлу при провалі | LOCKED |
| D-164 | Rust-скелет має компілюватись | LOCKED |
| D-165 | Майбутній GTK4/Relm4 фронтенд не має вимагати переписування core | LOCKED |

---

## Ідентичність системи

| ID | Рішення | Статус |
|---|---|---|
| D-170 | Розкладки `ua,us` | LOCKED |
| D-171 | Часовий пояс Europe/Kyiv; LANG=en_US.UTF-8 з українськими LC_TIME/MONETARY/MEASUREMENT | OPEN (припущення агента, не підтверджене явно) |
| D-172 | Ім'я користувача `mango` | OPEN (виведене з `home/mango.nix`, не підтверджене явно) |
| D-173 | Ім'я хоста | **OPEN — КОНФЛІКТ** |

**D-173 конфлікт.** Користувач явно написав «host **fennec**», і так і реалізовано
(`flake.nix`, `nixosConfigurations.fennec`). Але пізніший audit-промпт двічі
посилається на `nixosConfigurations.gt72s` і `nixos-rebuild build --flake .#gt72s`.
Агент **не змінював** реалізацію самостійно. Потрібне явне рішення користувача:
чи `fennec` лишається іменем хоста, чи повертаємось до `gt72s`.
