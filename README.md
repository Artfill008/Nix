# NixOS для MSI GT72S 6QE

Daily driver: flakes + home-manager, композитор **mangowc**, драйвер
**NVIDIA legacy 580** (Maxwell GM204), динамічна тема через **matugen**.

---

## Структура

```
flake.nix                          вхідна точка, канал nixos-unstable
hosts/gt72s/
  default.nix                      склейка модулів, локаль, юзер, nix-налаштування
  hardware-configuration.nix       ⚠ ШАБЛОН — замінити згенерованим
modules/
  nvidia.nix                       ядро 6.12 LTS + legacy_580 + Wayland-змінні
  performance.nix                  scx_lavd, zram, oomd, sysctl, MGLRU, TuneD
  desktop.nix                      весь стек оболонки: бар, лаунчер, портали...
  virtualisation.nix               libvirt + OVMF + machine.slice
  managed-packages.nix             ⚠ ВЛАСНІСТЬ nixmgr — руками не чіпати
  laptop/
    msi-ec.nix                     вентилятори, cooler boost, гістерезис
    rgb.nix                        3 зони клавіатури + 2 зони lightbar ← matugen
    audio-subwoofer.nix            HDA pin patch (за замовчуванням вимкнено)
    panel-75hz.nix                 EDID override (ЕКСПЕРИМЕНТАЛЬНО, вимкнено)
    wallpaper.nix                  сервіс і таймер moewall
home/
  default.nix                      щоденні програми + сервіси сесії
  mango.nix                        повний конфіг композитора з клавішами
  shell.nix                        fish, starship, git, helix, yazi, btop
  terminal.nix                     foot
  theme.nix                        matugen, waybar, swaylock, GTK, курсор
  matugen-templates/               шаблони, з яких matugen робить конфіги
pkgs/msiklm/                       derivation для MSIKLM (немає в nixpkgs)
tools/moewall/                     Rust: автошпалери (компілюється)
tools/nixmgr/                      Rust: менеджер пакетів (скелет, компілюється)
docs/shell-stack.md                чесно про те, де болітиме без DE
```

---

## ⚠ ЗРОБИТИ ПЕРЕД ПЕРШОЮ ЗБІРКОЮ

Пошукай `TODO:` по всьому репозиторію — їх небагато, і кожен важливий:

```bash
grep -rn "TODO:" --include="*.nix" --include="*.rs" .
```

Обов'язковий мінімум:

1. **`flake.nix`** — `username` і `hostname`.
2. **`hosts/gt72s/hardware-configuration.nix`** — замінити на згенерований:
   ```bash
   sudo nixos-generate-config --show-hardware-config > /tmp/hw.nix
   ```
   і перенести звідти UUID-и, лишивши мої btrfs-опції.
3. **`hosts/gt72s/default.nix`** — `time.timeZone`, `system.stateVersion`.
4. **`home/shell.nix`** — `programs.git.userName` / `userEmail`.
5. **`modules/laptop/msi-ec.nix`** — `hash` (перша збірка підкаже правильний).
6. **`pkgs/msiklm/default.nix`** — `hash` (те саме).

І перевір прошивку EC — від неї залежить, чи запрацює керування вентиляторами:

```bash
sudo dmidecode -s bios-version     # має бути 1782EMS1.109
```

---

## Перша збірка

```bash
# 1. Покласти конфіг туди, де його чекає nixos-rebuild
sudo mv /etc/nixos /etc/nixos.orig
sudo cp -r . /etc/nixos
cd /etc/nixos

# 2. Хеші, які я не міг порахувати без мережі до nixpkgs.
#    Кожна з цих команд надрукує рядок «got: sha256-...» — вставляй його
#    у відповідний файл і повторюй, доки не перестане скаржитись.
sudo nixos-rebuild build --flake .#gt72s

# 3. Коли build проходить — перевір, ЩО саме зміниться:
nvd diff /run/current-system ./result

# 4. Спочатку test (не чіпає завантажувач — це важливо!)
sudo nixos-rebuild test --flake .#gt72s

# 5. Якщо система жива і виглядає правильно — закріпити:
sudo nixos-rebuild switch --flake .#gt72s
```

**Чому саме `test` перед `switch`:** `test` активує конфігурацію, але НЕ
записує її в меню завантаження. Якщо щось піде не так — просте
перезавантаження поверне попередній стан. `switch` уже робить її типовою.

---

## Якщо система не завантажилась

### Крок 0. Не панікуй — попереднє покоління на місці

При завантаженні в меню **systemd-boot** натисни будь-яку клавішу
(у нас `boot.loader.timeout = 3`), вибери попередній пункт
`NixOS - Configuration N-1` і завантажся в нього. Диск не змінився,
дані на місці. Це працює завжди, доки ти не видалив старі покоління.

### Крок 1. Чорний екран замість графіки

Найімовірніше — NVIDIA або композитор. Переключись у текстову консоль:
**Ctrl+Alt+F2**, увійди, і дивись:

```bash
# Чи піднявся драйвер узагалі
lsmod | grep nvidia
dmesg | grep -i nvidia | tail -30

# Чи стартував гріттер
systemctl status greetd
journalctl -u greetd -b --no-pager | tail -40

# Чи не впав mango
journalctl --user -b --no-pager | grep -i mango | tail -40
```

Типові причини й що робити:

| Симптом у журналі | Причина | Дія |
|---|---|---|
| `NVRM: The NVIDIA GPU ... is not supported by this driver` | взявся не той драйвер | перевір `hardware.nvidia.package` — має бути `legacy_580` |
| `nvidia: module verification failed` / модуля немає | драйвер не зібрався під ядро | тимчасово прибери `boot.kernelPackages` (буде дефолтне ядро) |
| `mango: failed to create renderer` | wlroots не знайшов GBM | перевір, що є `nvidia-drm.modeset=1` у `/proc/cmdline` |
| greetd рестартує в циклі | regreet не запускається | тимчасово `services.displayManager.regreet.enable = false` і став `services.greetd.settings.default_session.command = "${pkgs.mango}/bin/mango"` |

### Крок 2. Не вантажиться взагалі (навіть до меню)

Завантажся з USB з NixOS ISO і зайди в систему:

```bash
sudo mount -o subvol=@ /dev/nvme0n1p2 /mnt        # ← свій розділ
sudo mount -o subvol=@nix /dev/nvme0n1p2 /mnt/nix
sudo mount /dev/nvme0n1p1 /mnt/boot
sudo nixos-enter --root /mnt

# Усередині: відкотитись на попереднє покоління
nixos-rebuild switch --rollback
# або зібрати конкретне покоління:
/nix/var/nix/profiles/system-42-link/bin/switch-to-configuration boot
```

### Крок 3. Підозра на mitigations=off

Ти вимкнув мітигації. Це не спричиняє незавантаження, але якщо хочеш
виключити варіант — у меню boot натисни `e` … **не вийде**, бо ми поставили
`boot.loader.systemd-boot.editor = false` (свідомо: редактор дозволяє
`init=/bin/sh`, тобто обхід пароля).

Тому: завантажся в попереднє покоління, прибери рядок `"mitigations=off"`
з `modules/performance.nix`, зроби `nixos-rebuild boot`.

### Крок 4. Все зламалось після зміни в managed-packages.nix

```bash
nixmgr rollback              # поверне .bak
# або
git checkout -- modules/managed-packages.nix
```

---

## Порядок увімкнення експериментальних модулів

Не вмикай усе одразу — інакше не зрозумієш, що саме зламалось.

1. Базова система → `switch` → перезавантаження → перевір, що є графіка.
2. `gt72s.msiEc.enable` (уже `true`) → перевір `ls /sys/devices/platform/msi-ec/`.
3. `gt72s.wallpaper` → `moewall next` вручну, подивись вивід.
4. `gt72s.rgb.enable = true` → `sudo msiklm test` перед цим.
5. `gt72s.audio.enableSubwooferPatch` — тільки після діагностики пінів.
6. `gt72s.panel75.enable` — останнім, і лише зі створеним EDID-файлом.

---

## Щоденні команди

```bash
rebuild          # sudo nixos-rebuild switch --flake /etc/nixos#gt72s |& nom
rebuild-test     # те саме, але без запису в завантажувач
gendiff          # що змінилось між поколіннями
generations      # список поколінь

nixmgr add gimp      # знайти → показати варіанти → додати → rebuild → відкат при провалі
nixmgr rm gimp
nixmgr search video
nixmgr modules       # які пакети потребують модуля, а не systemPackages

moewall next         # наступна шпалера (SUPER+ALT+W)
moewall refresh      # завантажити нові (SUPER+ALT+SHIFT+W)
moewall keep         # в улюблені
moewall blacklist    # у чорний список і далі
moewall status
```
