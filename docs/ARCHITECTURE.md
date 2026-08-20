# Архітектура

## Дерево (фактичне, 60 файлів у git станом на a10bbe4)

```
flake.nix                     інпути, overlay, nixosConfigurations, packages, devShell
flake.lock                    ВІДСУТНІЙ (див. AUDIT A-002)
overlays/default.nix          msiklm, moewall, nixmgr, gt72

hosts/gt72s/                  ПРОФІЛЬ ЗАЛІЗА (не ім'я машини)
  default.nix                 склеювання модулів + ідентичність + Nix settings
  hardware-configuration.nix  ШАБЛОН: initrd, підтоми btrfs, microcode

modules/                      загальносистемне
  kernel.nix                  fennec.kernel.channel + assertion на пару з NVIDIA
  nvidia.nix                  legacy_580, open=false, modeset, VRAM через сон
  performance.nix             scx_lavd, zram, oomd, kernelParams, sysctl, MGLRU, TuneD
  storage.nix                 снапшоти, SMART, coredump        ← реалізує Snapper (SUPERSEDED)
  virtualisation.nix          libvirt, OVMF, swtpm, machine.slice
  desktop.nix                 сесія: mango, greetd/regreet, pipewire, портали, shell-пакети
  apps.nix                    щоденні програми, MIME, кодеки, мініатюри, Firefox
  dev.nix                     AI-агенти, build-інфраструктура, podman, syncthing
  android.nix                 Studio, adb, nix-ld, udev, KVM
  flatpak.nix                 remote, тематизація, GeForce NOW
  health.nix                  gt72 + systemd-юніт + acceptance checklist
  gaming.nix                  повний, enable=false
  printing.nix                повний, enable=false
  managed-packages.nix        ВЛАСНІСТЬ nixmgr — руками не чіпати
  laptop/                     GT72S-специфічне
    msi-ec.nix                EC, cooler boost, гістерезис
    rgb.nix                   msiklm ← палітра matugen
    audio-subwoofer.nix       pin-патч кодека (за замовчуванням вимкнено)
    panel-75hz.nix            EDID-override (за замовчуванням вимкнено)
    wallpaper.nix             moewall як служба + конфіг

home/                         home-manager
  default.nix                 пакети, user-сервіси, xdg.userDirs, xdg.mimeApps
  mango.nix                   config.conf + autostart.sh
  theme.nix                   matugen config + шаблони + GTK/курсор
  shell.nix                   fish, git, starship
  terminal.nix                foot
  matugen-templates/          7 шаблонів палітри

pkgs/
  msiklm/default.nix          RGB-утиліта (немає в nixpkgs)  ← lib.fakeHash
  gt72/{default.nix,gt72.sh}  control plane, writeShellApplication

tools/
  moewall/                    Rust: SafeBooru → аналіз → matugen → RGB
  nixmgr/                     Rust: fuzzy пошук → атрибут → managed-packages.nix
```

## Простори імен опцій

| Префікс | Призначення |
|---|---|
| `fennec.*` | Рішення рівня дистрибутива: `kernel.channel`, `gaming`, `printing`, `android` |
| `gt72s.*` | Специфічне для цієї моделі заліза: `msiEc`, `rgb`, `audio`, `panel75`, `wallpaper` |

Розділення дозволяє додати `hosts/thinkpad/` без `gt72s.*` і без переписування
`modules/` (вимога R2.4).

## Потік теми (runtime, без rebuild)

```
moewall next
   │
   ├─ SafeBooru API (tags: rating:safe + …)      ← UNVERIFIED EXTERNAL API
   ├─ завантаження в /var/lib/moewall/cache
   ├─ analyse.rs: роздільність → аспект → яскравість → насиченість → відтінок
   │              (відкидає washed-out і не-16:9)
   ├─ state.json: seen / blacklist / favourites / cache_order   (атомарний запис)
   ├─ current.png
   │
   ├─ matugen  ──► ~/.config/{foot,waybar,mango,mako,fuzzel}/colors.*
   │                                    │
   │                                    ├─ waybar   reload
   │                                    ├─ mako     reload
   │                                    └─ mango    reload_config
   │
   └─ rgb-colors.sh ──► msiklm ──► 3 зони клавіатури + 2 фронтальні
```

Ключове: **усі цілі matugen — mutable-файли в `~/.config`**, а не symlink'и
в Nix store. Home-manager кладе туди лише *шаблони*; згенеровані `colors.*`
належать рантайму (вимога R14.4, R18.3).

## Потік керування (control plane)

```
користувач / майбутній GTK4 GUI
        │
        ▼
   gt72 <підкоманда> [--json]        ← стабільний контракт
        │
        ├─ status        nvidia-smi, sensors, tuned-adm
        ├─ health        порівняння /etc/fennec/* із рантаймом
        ├─ performance   tuned-adm profile        (НЕ прямий запис у sysfs)
        └─ audio probe   читання /proc/asound/... (нічого не змінює)
```

`gt72` свідомо не пише в EC. Керування живленням іде через TuneD —
єдиного обраного керівника (вимога R6.11).

## Потік nixmgr

```
nixmgr add <приблизна назва>
   │
   ├─ nix search --json          fuzzy-ранжування (nucleo-matcher)
   ├─ вибір точного атрибута
   ├─ nix eval meta              unfree / broken     (NIXPKGS_ALLOW_UNFREE=1 + --impure)
   ├─ курована таблиця           data/module-packages.toml → programs.*.enable?
   ├─ backup + запис між маркерами nixmgr:*:begin/end
   ├─ nix eval → nixos-rebuild
   └─ провал → restore з .bak
```

Інструмент читає і пише **виключно** `modules/managed-packages.nix`.
Решту дерева не парсить (вимога R16.3).

## Межа declarative / runtime

| Declarative (Nix) | Runtime (інструменти) |
|---|---|
| ядро, драйвери, служби, пакети | поточні шпалери |
| основа сесії Mango | палітра matugen |
| системні дефолти, шаблони | поточний стан RGB |
| fallback-тема | історія буфера |
| механізми | яскравість/гучність |
| | тимчасовий профіль продуктивності |
| | кеш SafeBooru, favourites, blacklist |

## Відомі архітектурні натяги

1. **uwsm vs autostart.sh.** Обидва роблять експорт середовища і підйом
   `graphical-session.target`. Це дублювання (AUDIT A-041).
2. **MIME у двох місцях.** `modules/apps.nix` (`xdg.mime.defaultApplications`)
   і `home/default.nix` (`xdg.mimeApps`). Два джерела істини (AUDIT A-062).
3. **`allowUnfree` глобально** в `hosts/gt72s/default.nix` робить
   `allowUnfreePredicate` у `managed-packages.nix` неефективним (задокументовано
   в самому файлі, але лишається натягом).
