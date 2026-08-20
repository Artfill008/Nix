# Матриця простежуваності вимог

Кожна вимога — окремий рядок. Групувати кілька вимог в один PASS заборонено:
«desktop integration працює» не є доказом, тому MIME, мініатюри, Trash,
OpenURI, MTP, автомонтування, буфер, захоплення екрана, polkit і keyring
мають власні рядки.

**Дата:** 2026-08-20 · **Комміт:** `38aa174`

**Статуси:** PASS · PARTIAL · FAIL · MISSING · SUPERSEDED · OPEN · ON-DEVICE · NOT-APPLICABLE

**Метод валідації** — що саме доводить статус. `статика` = перевірка балансу
дужок / дублів / існування імпортів / звірка імен із сирцями nixos-unstable.
`збірка` ніде не вказано, бо `nix` у середовищі агента немає.

---

## A. Платформа і структура

| ID | Вимога | Рішення | Файли | Валідація | Статус |
|---|---|---|---|---|---|
| REQ-001 | Канал nixos-unstable | D-001 | `flake.nix:9` | статика | PASS |
| REQ-002 | flake.lock як source of truth | D-002 | — | немає файлу | MISSING |
| REQ-003 | Flakes + home-manager як NixOS-модуль | D-003 | `flake.nix:60-75` | статика | PASS |
| REQ-004 | HM input pinned і follows nixpkgs | D-003 | `flake.nix:12-16` | статика | PASS |
| REQ-005 | Модульна структура, не один файл | R2.1 | `modules/` 15 файлів | статика | PASS |
| REQ-006 | Hardware-специфіка ізольована | R2.2 | `hosts/gt72s/`, `modules/laptop/` | статика | PASS |
| REQ-007 | Desktop-компоненти не в hardware-модулі | R2.3 | `modules/desktop.nix` окремо | статика | PASS |
| REQ-008 | Можна додати hosts/other-machine | R2.4 | простори `fennec.*` / `gt72s.*` | статика | PASS |
| REQ-009 | Можна додати themes/other-theme | R2.4 | — | каталогу `themes/` немає | PARTIAL |
| REQ-010 | Можна додати desktop/other-compositor | R2.4 | — | каталогу `desktop/` немає | PARTIAL |
| REQ-011 | Розділення hardware/system/perf/desktop/apps/theme/user | R2.5 | `docs/ARCHITECTURE.md` | статика | PASS |
| REQ-012 | Українські коментарі | R2.6 | усі 33 `.nix` | статика | PASS |
| REQ-013 | Пояснення «чому переможець» | R3.2 | коментарі в `apps.nix`, `home/default.nix` | статика | PASS |
| REQ-014 | Явне «що програло» | R3.2 | там само | статика | PASS |
| REQ-015 | Чесна позначка паритету | R3.3 | `performance.nix:21`, `home/default.nix` | статика | PASS |
| REQ-016 | Не вигадувати імена пакетів | R4.1 | звірка з by-name/all-packages | статика | PASS |
| REQ-017 | Не називати неперевірене перевіреним | R4.2 | `docs/AUDIT.md` розділ «що запускалось» | — | PASS |

## B. Ядро і завантаження

| ID | Вимога | Рішення | Файли | Валідація | Статус |
|---|---|---|---|---|---|
| REQ-020 | systemd-boot, UEFI | R5.1 | `hosts/gt72s/default.nix:51` | статика | PASS |
| REQ-021 | Обмеження поколінь | R5.1 | `default.nix:55` | статика | PASS |
| REQ-022 | Boot timeout ненульовий | R5.1 | `default.nix:63` | статика | PASS |
| REQ-023 | initrd: nvme/xhci/rtsx | R5.2 | `hardware-configuration.nix` | статика | PASS |
| REQ-024 | Intel microcode | R5.3 | `hardware-configuration.nix` | статика | PASS |
| REQ-025 | Firmware redistributable | R5.4 | `hardware-configuration.nix` | статика | PASS |
| REQ-026 | Ядро 6.18 default | D-015 | `kernel.nix:38`, `default.nix:75` | статика | PASS |
| REQ-027 | 7.2 окремим opt-in | D-015 | `kernel.nix:56-80` | статика | PASS |
| REQ-028 | latest не ламає default | D-016 | assertion `kernel.nix:95` | статика | PASS |
| REQ-029 | Канонічні імена, не аліаси | R4.1 | `kernel.nix:29-48` | звірка з aliases.nix | PASS |

## C. Продуктивність (кожен параметр окремо)

| ID | Вимога | Файли | Валідація | Статус |
|---|---|---|---|---|
| REQ-030 | `services.scx` = scx_lavd | `performance.nix:23-25` | статика | PASS |
| REQ-031 | systemd-oomd | `performance.nix:50` | статика | PASS |
| REQ-032 | zram рівно 16 ГБ | `performance.nix:41` (`memoryMax`) | статика | PASS |
| REQ-033 | zram algorithm=zstd | `performance.nix:38` | статика | PASS |
| REQ-034 | zram priority | `performance.nix:43` | статика | PASS |
| REQ-035 | `vm.swappiness=180` | `performance.nix:122` | статика | PASS |
| REQ-036 | `vm.page-cluster=0` | `performance.nix:127` | статика | PASS |
| REQ-037 | `vm.max_map_count` | `performance.nix:144` | статика | PASS |
| REQ-038 | `vm.dirty_bytes` | `performance.nix:133` | статика | PASS |
| REQ-039 | `vm.vfs_cache_pressure` | `performance.nix:139` | статика | PASS |
| REQ-040 | NVMe scheduler=none | `performance.nix:190` udev | статика | PASS |
| REQ-041 | MGLRU увімкнено | `performance.nix:166` tmpfiles | статика | PASS |
| REQ-042 | THP=madvise | `performance.nix:93` | статика | PASS |
| REQ-043 | `preempt=full` | `performance.nix:61` | статика | PASS |
| REQ-044 | `split_lock_detect=off` | `performance.nix:66` | статика | PASS |
| REQ-045 | `nowatchdog` | `performance.nix:70` | статика | PASS |
| REQ-046 | `nvme_core.default_ps_max_latency_us=0` | `performance.nix:75` | статика | PASS |
| REQ-047 | `mem_sleep_default=deep` | `performance.nix:79` | статика | PASS |
| REQ-048 | `nvidia-drm.modeset=1` | `performance.nix:83` | статика | PASS |
| REQ-049 | `NVreg_PreserveVideoMemoryAllocations=1` | `performance.nix:88` | статика | PASS |
| REQ-050 | `mitigations=off` | `performance.nix:114` | статика | PASS |
| REQ-051 | Усе декларативно, без імперативних скриптів | tmpfiles + udev | grep на activationScripts — чисто | PASS |

## D. Матриця власників політик живлення

| ID | Політика | Власник | Конфліктів немає бо | Статус |
|---|---|---|---|---|
| REQ-052 | CPU governor | TuneD | PPD явно `enable = false`; TLP/auto-cpufreq відсутні | PASS |
| REQ-053 | Energy performance policy | TuneD | той самий власник | PASS |
| REQ-054 | Turbo / RAPL | thermald | TuneD не чіпає RAPL | PASS |
| REQ-055 | Thermal throttling | thermald | єдиний | PASS |
| REQ-056 | Fan policy / Cooler Boost | `gt72s.msiEc.coolerGuard` | **не доведено**, що не бореться з thermald | OPEN |
| REQ-057 | Idle / suspend | logind | єдиний | PASS |
| REQ-058 | Lid behaviour | logind | `desktop.nix:164` | PASS |
| REQ-059 | Backlight | brightnessctl + swayosd | правила з пакета swayosd | PASS |
| REQ-060 | I/O scheduler | udev-правило | єдине | PASS |
| REQ-061 | OOM | systemd-oomd | earlyoom відсутній | PASS |
| REQ-062 | Health-check рахує керівників живлення | `gt72.sh` | статика | PASS |

## E. NVIDIA і залізо GT72S

| ID | Вимога | Файли | Валідація | Статус |
|---|---|---|---|---|
| REQ-070 | Тільки legacy_580 | `nvidia.nix:67` | статика | PASS |
| REQ-071 | `open = false` | `nvidia.nix:70` | статика + bootstrap перевіряє | PASS |
| REQ-072 | Немає PRIME/Optimus/hybrid | grep `prime` — порожньо | статика | PASS |
| REQ-073 | Немає nouveau/NVK fallback | grep `nouveau` — порожньо | статика | PASS |
| REQ-074 | Версія драйвера з піна | — | немає flake.lock | UNVERIFIED |
| REQ-075 | 32-бітний стек лише при gaming | `nvidia.nix:63` безумовний | статика | PARTIAL |
| REQ-076 | Vulkan | `nvidia.nix` | — | ON-DEVICE |
| REQ-077 | suspend/resume інтеграція | `nvidia.nix` | — | ON-DEVICE |
| REQ-078 | msi-ec проти BIOS whitelist | `msi-ec.nix` | — | ON-DEVICE |
| REQ-079 | Cooler Boost | `msi-ec.nix` | — | ON-DEVICE |
| REQ-080 | RGB 3 зони клавіатури | `rgb.nix:70-79` | — | ON-DEVICE |
| REQ-081 | RGB 2 фронтальні зони | `rgb.nix:72` | — | ON-DEVICE |
| REQ-082 | Matugen → RGB у рантаймі | `rgb.nix` + `theme.nix` | статика | PASS |
| REQ-083 | RGB не ламає boot | assertion `rgb.nix:126` | статика | PASS |
| REQ-084 | Фізичний woofer, не «можливо пасивний» | `audio-subwoofer.nix`, `HARDWARE-VALIDATION.md §7` | — | ON-DEVICE |
| REQ-085 | 75 Гц experimental, не потрібне для boot | `panel-75hz.nix:86` default false | статика | PASS |
| REQ-086 | Рівні зрілості STABLE/QUIRK/EXPERIMENTAL/UNSUPPORTED | `gt72.sh`, `HARDWARE-VALIDATION.md` | статика | PASS |
| REQ-087 | Жодних raw EC writes наосліп | `gt72.sh` — лише tuned-adm і читання | статика | PASS |

## F. Диск

| ID | Вимога | Файли | Валідація | Статус |
|---|---|---|---|---|
| REQ-090 | Btrfs | `hardware-configuration.nix` | bootstrap перевіряє | PASS |
| REQ-091 | Підтоми @ @home @nix @log @snapshots | `hardware-configuration.nix` + bootstrap | статика | PASS |
| REQ-092 | @snapshots змонтований і досяжний | `/.btrfs` subvolid=5 | статика | PASS |
| REQ-093 | Снапшоти = btrbk, не Snapper | `storage.nix` | статика | PASS |
| REQ-094 | /nix не снапшотиться | `storage.nix` — @nix відсутній | статика | PASS |
| REQ-095 | Retention розумний | `snapshot_preserve = "48h 14d 8w 6m"` | статика | PASS |
| REQ-096 | Без шифрування | немає LUKS | статика | PASS |
| REQ-097 | Без дискового swap | `swapDevices = [ ]` + bootstrap перевіряє | статика | PASS |
| REQ-098 | TRIM | `discard=async` | статика | PASS |
| REQ-099 | Btrfs scrub | `autoScrub` monthly | статика | PASS |
| REQ-100 | SMART/NVMe моніторинг | `storage.nix` smartd | статика | PASS |

## G. Сесія і оболонка (кожен компонент окремо)

| ID | Функція | Реалізація | Служба/автозапуск | Статус |
|---|---|---|---|---|
| REQ-110 | Session startup | uwsm + autostart.sh | `programs.uwsm` | PASS |
| REQ-111 | DBus session environment | `dbus-update-activation-environment` | autostart.sh | PASS |
| REQ-112 | systemd user integration | graphical-session.target | autostart.sh | PASS |
| REQ-113 | XDG environment | HM `xdg.enable` | — | PASS |
| REQ-114 | XWayland | `programs.xwayland.enable` | — | PASS |
| REQ-115 | Бар | Waybar | autostart.sh | PASS |
| REQ-116 | Лаунчер | fuzzel | бінд SUPER+d | PASS |
| REQ-117 | Сповіщення | mako | user-сервіс | PASS |
| REQ-118 | Локер | swaylock | бінд SUPER+Escape | PASS |
| REQ-119 | Idle-демон | swayidle | user-сервіс | PASS |
| REQ-120 | Шпалери | swaybg + moewall | autostart.sh | PASS |
| REQ-121 | Portals: wlr | `programs.mango` | — | PASS |
| REQ-122 | Portals: gtk | `flatpak.nix` + mango | — | PASS |
| REQ-123 | Portal preference/order | `config.mango` у модулі nixpkgs | — | PASS |
| REQ-124 | Polkit-агент | polkit_gnome | user-сервіс | PASS |
| REQ-125 | Keyring / Secret Service | gnome-keyring + PAM | `desktop.nix:142-146` | PASS |
| REQ-126 | Clipboard | wl-clipboard | — | PASS |
| REQ-127 | Clipboard history | cliphist ×2 + wl-clip-persist | user-сервіси | PASS |
| REQ-128 | Screenshot | grim+slurp+satty | бінди Print/SUPER+s | PASS |
| REQ-129 | Screen recording | gpu-screen-recorder (NVENC) | — | PASS |
| REQ-130 | Screen capture portal | xdg-desktop-portal-wlr | — | PASS |
| REQ-131 | Вибір **вікна** для шаринга | апстрім не вміє | — | NOT-APPLICABLE |
| REQ-132 | Brightness | swayosd-client | бінди + libinput backend | PASS |
| REQ-133 | Volume | swayosd-client | бінди + libinput backend | PASS |
| REQ-134 | Media keys | playerctl | бінди | PASS |
| REQ-135 | **OSD** для volume/brightness | swayosd-server + client + backend | системна служба | PASS |
| REQ-136 | NetworkManager UI | nm-applet | user-сервіс | PASS |
| REQ-137 | Bluetooth UI | blueman-applet | user-сервіс | PASS |
| REQ-138 | Автомонтування USB | udisks2 + udiskie | user-сервіс | PASS |
| REQ-139 | Display configuration | kanshi конфіг | `xdg.configFile` | PASS |
| REQ-140 | Display hotplug | kanshi | user-сервіс | PASS |
| REQ-141 | Power menu | wlogout | бінд SUPER+SHIFT+e | PASS |
| REQ-142 | Logout/reboot/shutdown/suspend | wlogout + logind | — | PASS |
| REQ-143 | Lid close | logind | `desktop.nix:166` | PASS |
| REQ-144 | Tray / status notifier | Waybar tray | — | PASS |
| REQ-145 | Cursor | HM `home.pointerCursor` | `theme.nix` | PASS |
| REQ-146 | Розкладки клавіатури ua,us | `services.xserver.xkb` + mango | статика | PASS |
| REQ-147 | Синхронність розкладок система↔mango | два місця | не звірено | OPEN |
| REQ-148 | Дисплей-менеджер ReGreet | `desktop.nix:50` | — | PASS |
| REQ-149 | Drag-and-drop | wlroots + портали | — | ON-DEVICE |

## H. Desktop integration (кожен окремо)

| ID | Функція | Реалізація | Статус |
|---|---|---|---|
| REQ-150 | MIME associations | `apps.nix` `xdg.mime.defaultApplications` | PASS |
| REQ-151 | MIME — єдине джерело істини | home `mimeApps` очищено | PASS |
| REQ-152 | Default applications | `apps.nix` | PASS |
| REQ-153 | OpenURI / xdg-open | `xdg-utils` + `xdgOpenUsePortal` | PASS |
| REQ-154 | Trash | GVfs + trash-cli | PASS |
| REQ-155 | Thumbnailers | tumbler + ffmpegthumbnailer + webp-pixbuf-loader | PASS |
| REQ-156 | GVfs | `services.gvfs.enable` | PASS |
| REQ-157 | MTP (Android) | gvfs + libmtp udev із модуля | PASS |
| REQ-158 | Removable drives | udisks2 | PASS |
| REQ-159 | Network shares SMB/SFTP | gvfs-бекенди | PARTIAL |
| REQ-160 | XDG user dirs | HM `xdg.userDirs` | PASS |
| REQ-161 | Кодеки | gst-plugins base/good/bad/ugly/libav + ffmpeg | PASS |
| REQ-162 | Spellchecking | hunspell + uk-ua + en-us | PASS |
| REQ-163 | magnet-посилання | немає торент-клієнта | MISSING |
| REQ-164 | Browser file picker | портал GTK | PASS |
| REQ-165 | File manager network integration | Nautilus + GVfs | PASS |

## I. Аудіо, мережа, живлення

| ID | Вимога | Реалізація | Статус |
|---|---|---|---|
| REQ-170 | PipeWire | `desktop.nix:107` | PASS |
| REQ-171 | WirePlumber | той самий модуль | PASS |
| REQ-172 | PulseAudio вимкнено | `services.pulseaudio.enable = false` | PASS |
| REQ-173 | Мікрофон | PipeWire | ON-DEVICE |
| REQ-174 | Bluetooth audio | bluez + wireplumber | ON-DEVICE |
| REQ-175 | Аудіоконтролі | pwvucontrol + wiremix | PASS |
| REQ-176 | NetworkManager | `default.nix:85` + iwd | PASS |
| REQ-177 | Firewall | nftables-бекенд | PASS |
| REQ-178 | DNS | systemd-resolved | PARTIAL |
| REQ-179 | NTP | systemd-timesyncd (дефолт NixOS) | PASS |
| REQ-180 | Локаль і часовий пояс | `default.nix:97-109` | OPEN |
| REQ-181 | Battery reporting | upower | ON-DEVICE |
| REQ-182 | Wi-Fi firmware | `enableRedistributableFirmware` | ON-DEVICE |
| REQ-183 | Webcam | uvcvideo + v4l-utils | ON-DEVICE |
| REQ-184 | Card reader | `rtsx_pci_sdmmc` в initrd | ON-DEVICE |
| REQ-185 | Hardware sensors | lm_sensors | ON-DEVICE |

## J. Програми (роль → переможець)

| ID | Роль | Обрано | Найсильніший відхилений | Причина | Статус |
|---|---|---|---|---|---|
| REQ-190 | Браузер | Firefox | Chromium | VA-API без прапорців, декларативні policies | PASS |
| REQ-191 | Dev-браузер | Chromium | — | chrome://inspect для WebView | PASS |
| REQ-192 | Термінал | foot | alacritty | нативний Wayland, найменший старт | PASS |
| REQ-193 | GUI файловий менеджер | Nautilus | Nemo | інтеграція GVfs/портали/мініатюри; втрачено type-ahead і split view | PASS |
| REQ-194 | TUI файловий менеджер | yazi | ranger | асинхронний, прев'ю в терміналі | PASS |
| REQ-195 | Архіватор | File Roller | xarchiver | UTF-8/паролі, інтеграція | PASS |
| REQ-196 | Зображення | Loupe | imv | ізольований декодер glycin | PASS |
| REQ-197 | Відео | Celluloid | Showtime | рушій mpv, керування hwdec (критично для GM204) | PASS |
| REQ-198 | Аудіо | Decibels | — | «клацнув — заграло»; не бібліотека | PASS |
| REQ-199 | PDF | Papers | zathura | той самий poppler + sandbox + рідний вигляд | PASS |
| REQ-200 | Текстовий редактор GUI | GNOME Text Editor | — | легкий, libadwaita | PASS |
| REQ-201 | Текстовий редактор TUI | helix | neovim | LSP без конфігу; neovim свідомо НЕ основний | PASS |
| REQ-202 | Калькулятор | Qalculate | gnome-calculator | одиниці, валюти, символьні | PASS |
| REQ-203 | Системний монітор GUI | Resources | mission-center | точніший по GPU | PASS |
| REQ-204 | Системний монітор TUI | btop | htop | не лише процеси | PASS |
| REQ-205 | Дискові утиліти | gnome-disk-utility + baobab | gparted | GUI над udisks2 | PASS |
| REQ-206 | Менеджер шрифтів | gnome-font-viewer | font-manager | візуальна цілісність | PASS |
| REQ-207 | Emoji-пікер | GNOME Characters | smile | цілісність, без wtype | PASS |
| REQ-208 | Немає дублювання ролей | — | — | home/default.nix очищено | PASS |
| REQ-209 | Seahorse умовно | — | — | ставиться безумовно | OPEN |
| REQ-210 | Mail/calendar | — | — | винесено в TODO | OPEN |
| REQ-211 | Office | — | — | винесено в TODO | OPEN |
| REQ-212 | Torrent | — | — | винесено в TODO | OPEN |
| REQ-213 | Password manager | немає | — | D-031: користувач не хоче | PASS |

## K. Тема

| ID | Вимога | Реалізація | Статус |
|---|---|---|---|
| REQ-220 | Matugen як рушій палітри | `theme.nix:60` | PASS |
| REQ-221 | colorful brutalism / sharp geometry / slight rounding | `mango.nix` borderpx=3, gaps=6 | PASS |
| REQ-222 | Палітра змінюється runtime без rebuild | matugen пише в `~/.config` | PASS |
| REQ-223 | Matugen не пише в store symlink | цілі — mutable файли | PASS |
| REQ-224 | Статичний fallback | `swaybg -c '#0d0d10'` | PASS |
| REQ-225 | Без постійного blur | `blur=0` | PASS |
| REQ-226 | Без важких шейдерів | scenefx-ефекти вимкнені | PASS |
| REQ-227 | Анімації вимкнені | `animations=0` | PASS |
| REQ-228 | Тінь вимкнена | `shadows=0` | PASS |
| REQ-229 | GTK3 тема | HM `gtk` | PASS |
| REQ-230 | GTK4/libadwaita | adw-gtk3 + gsettings | PARTIAL |
| REQ-231 | Qt-програми | Qt у базі майже немає | NOT-APPLICABLE |
| REQ-232 | Іконки | papirus/tela | PASS |
| REQ-233 | Курсор | bibata | PASS |
| REQ-234 | UI-шрифт | Inter | PASS |
| REQ-235 | Моноширинний | JetBrainsMono Nerd Font | PASS |
| REQ-236 | Кирилиця | DejaVu + Noto | PASS |
| REQ-237 | CJK fallback | noto-fonts-cjk-sans/serif | PASS |
| REQ-238 | Emoji | noto-fonts-color-emoji | PASS |
| REQ-239 | Термінал у темі | шаблон foot-colors | PASS |
| REQ-240 | Бар у темі | шаблон waybar-colors | PASS |
| REQ-241 | Лаунчер у темі | шаблон fuzzel | PASS |
| REQ-242 | Сповіщення у темі | шаблон mako | PASS |
| REQ-243 | Рамки Mango у темі | шаблон mango-colors | PASS |
| REQ-244 | OSD у темі | шаблону для swayosd немає | MISSING |
| REQ-245 | Локскрін у темі | шаблону для swaylock немає | MISSING |
| REQ-246 | ReGreet у темі | шаблону немає | MISSING |
| REQ-247 | Оцінити Stylix і обґрунтувати | `DECISIONS.md` D-055 | PASS |

## L. Розробка

| ID | Компонент | Файл | Статус |
|---|---|---|---|
| REQ-250 | git | `dev.nix` | PASS |
| REQ-251 | git-lfs | `dev.nix` | PASS |
| REQ-252 | curl | `dev.nix` | PASS |
| REQ-253 | wget | `dev.nix` | PASS |
| REQ-254 | jq | `dev.nix` | PASS |
| REQ-255 | ripgrep | `dev.nix` | PASS |
| REQ-256 | fd | `dev.nix` | PASS |
| REQ-257 | tree | `dev.nix` | PASS |
| REQ-258 | patch | `dev.nix` | PASS |
| REQ-259 | diffutils | `dev.nix` | PASS |
| REQ-260 | file | `dev.nix` | PASS |
| REQ-261 | zip/unzip | `dev.nix` | PASS |
| REQ-262 | tar | `dev.nix` | PASS |
| REQ-263 | gzip | `dev.nix` | PASS |
| REQ-264 | xz | `dev.nix` | PASS |
| REQ-265 | zstd | `dev.nix` | PASS |
| REQ-266 | make | `dev.nix` | PASS |
| REQ-267 | cmake | `dev.nix` | PASS |
| REQ-268 | ninja | `dev.nix` | PASS |
| REQ-269 | pkg-config | `dev.nix` | PASS |
| REQ-270 | gcc/clang | `dev.nix` | PASS |
| REQ-271 | direnv | `programs.direnv` | PASS |
| REQ-272 | nix-direnv | `nix-direnv.enable` | PASS |
| REQ-273 | nix-output-monitor | `dev.nix` | PASS |
| REQ-274 | GitHub CLI | `dev.nix` | PASS |
| REQ-275 | uv як основний Python-workflow | `dev.nix` | PASS |
| REQ-276 | Python-залежності не глобальні | глобального python немає | PASS |
| REQ-277 | Rust toolchain у devShell, не в системі | `flake.nix:92` | PASS |
| REQ-278 | GTK4/libadwaita/Relm4 deps у devShell | devShell має лише openssl/pkg-config | PARTIAL |
| REQ-279 | Node/Go/Java не глобальні | відсутні | PASS |
| REQ-280 | Podman | `dev.nix` | PASS |
| REQ-281 | Distrobox | `dev.nix` | PASS |
| REQ-282 | Claude Code first-class | `dev.nix`, пакет nixpkgs | PASS |
| REQ-283 | Codex first-class | `dev.nix`, пакет nixpkgs | PASS |
| REQ-284 | Без curl\|sh / npm -g для агентів | з nixpkgs | PASS |
| REQ-285 | Neovim не нав'язаний | helix як fallback | PASS |

## M. Android workstation

| ID | Вимога | Реалізація | Статус |
|---|---|---|---|
| REQ-290 | Android Studio | `android.nix` | PASS |
| REQ-291 | adb | android-tools | PASS |
| REQ-292 | fastboot | android-tools | PASS |
| REQ-293 | Android udev rules | по класу інтерфейсу ff4201/ff4203 | PASS |
| REQ-294 | Група adbusers | створюється вручну (модуля programs.adb більше немає) | PASS |
| REQ-295 | KVM для емулятора | kvm-intel + група kvm | PASS |
| REQ-296 | nix-ld для бінарників SDK | `android.nix:70-105` | PASS |
| REQ-297 | JDK стратегія | jdk17 для gradle CLI | PASS |
| REQ-298 | SDK стратегія (mutable, керує Studio) | задокументовано | PASS |
| REQ-299 | Фізичні пристрої | udev | ON-DEVICE |
| REQ-300 | chrome://inspect workflow | Chromium | ON-DEVICE |

## N. Flatpak, ігри, віртуалізація

| ID | Вимога | Реалізація | Статус |
|---|---|---|---|
| REQ-310 | Flatpak увімкнено | `flatpak.nix` | PASS |
| REQ-311 | Flathub remote | ідемпотентний oneshot | PASS |
| REQ-312 | Повна portal-інтеграція | gtk+wlr | PASS |
| REQ-313 | Тематизація Flatpak | override oneshot | PASS |
| REQ-314 | Flatpak apps як imperative state | задокументовано | PASS |
| REQ-315 | GeForce NOW first-class | `flatpak.nix` app ID | PARTIAL |
| REQ-316 | GFN: репозиторій підтверджено | не підтверджено | UNVERIFIED |
| REQ-317 | GFN: Vulkan Video на 980M | — | ON-DEVICE |
| REQ-318 | Локальні ігри готові, вимкнені | `gaming.nix` enable=false | PASS |
| REQ-319 | Steam+Proton+32bit+GameMode при enable | `gaming.nix` | PASS |
| REQ-320 | Gamescope окремим toggle | `gaming.gamescope` | PASS |
| REQ-321 | libvirt | `virtualisation.nix` | PASS |
| REQ-322 | virt-manager | `virtualisation.nix` | PASS |
| REQ-323 | OVMF | `virtualisation.nix:21` | PASS |
| REQ-324 | ВМ у machine.slice | `virtualisation.nix:49-60` | ON-DEVICE |
| REQ-325 | Друк/скан вимкнений модуль | `printing.nix` enable=false | PASS |

## O. nixmgr і control plane

| ID | Вимога | Доказ | Статус |
|---|---|---|---|
| REQ-330 | managed-packages.nix належить лише nixmgr | маркери `edit.rs:45-48` | PASS |
| REQ-331 | Інструмент не парсить основний конфіг | `edit.rs` працює з одним шляхом | PASS |
| REQ-332 | Fuzzy пошук | nucleo-matcher, `search.rs` | PASS |
| REQ-333 | Точний атрибут | `search.rs` | PASS |
| REQ-334 | Unfree detection | `meta.rs:37-74` | PASS |
| REQ-335 | Курована таблиця модулів | `data/module-packages.toml` | PASS |
| REQ-336 | Безпечне додавання | між маркерами | PASS |
| REQ-337 | Безпечне видалення | `remove_package` | PASS |
| REQ-338 | Уникнення дублікатів | `has_package` | PASS |
| REQ-339 | Rollback файлу при провалі | `.bak` + `restore` | PASS |
| REQ-340 | nix eval перед rebuild | `rebuild.rs` | PASS |
| REQ-341 | Rust-скелет компілюється | `cargo check` exit 0 | PASS |
| REQ-342 | Захист від двох процесів | локу немає | MISSING |
| REQ-343 | Тести | 0 тестів | MISSING |
| REQ-344 | Аналіз snowfallorg | `edit.rs:3-30`, `main.rs:21-25` | PASS |
| REQ-345 | GUI не root, мінімальні привілеї | спроєктовано в коментарях | PARTIAL |
| REQ-346 | gt72 CLI | `pkgs/gt72` | PASS |
| REQ-347 | gt72 --json як API для GUI | `gt72.sh` | PASS |
| REQ-348 | gt72 health категорії і рівні | `gt72.sh` | PASS |
| REQ-349 | gt72 wallpaper/rgb/fan/display | підкоманд немає | MISSING |

## P. moewall / шпалери

| ID | Вимога | Доказ | Статус |
|---|---|---|---|
| REQ-360 | Джерело SafeBooru | `source.rs` | UNVERIFIED |
| REQ-361 | rating:safe | `wallpaper.nix:62` | PASS |
| REQ-362 | Роздільність під 1080p | `analyse.rs:72` | PASS |
| REQ-363 | Близько до 16:9 | `analyse.rs:76-78` | PASS |
| REQ-364 | Уникати washed-out/білих | `bright_fraction` | PASS |
| REQ-365 | Перевага темним/кольоровим | `mean_saturation` | PASS |
| REQ-366 | Бажані відтінки green/blue/purple/cyan/teal | `hue_matches` | PASS |
| REQ-367 | Кеш | `state.rs` | PASS |
| REQ-368 | Уникнення дублікатів | `seen` | PASS |
| REQ-369 | Favourite/keep | `favourites` | PASS |
| REQ-370 | Blacklist | `blacklist` | PASS |
| REQ-371 | Manual next/refresh | `main.rs` | PASS |
| REQ-372 | Атомарний запис стану | `state.rs:42` | PASS |
| REQ-373 | Обмеження кешу | `evict` | PASS |
| REQ-374 | Аналіз кольору → Matugen | `apply.rs` | PASS |
| REQ-375 | RGB після зміни палітри | `rgb.nix` | PASS |
| REQ-376 | Runtime без rebuild | таймер + CLI | PASS |
| REQ-377 | Запис source URL | не знайдено | MISSING |
| REQ-378 | Retries на мережевих збоях | немає | MISSING |
| REQ-379 | Компілюється | `cargo check` exit 0 | PASS |
| REQ-380 | Тести | 0 тестів | MISSING |
| REQ-381 | Збій не валить сесію | сервіс окремий від сесії | PARTIAL |

## Q. Процес, документація, обслуговування

| ID | Вимога | Доказ | Статус |
|---|---|---|---|
| REQ-390 | Architecture overview | `docs/ARCHITECTURE.md` | PASS |
| REQ-391 | Coverage matrix | цей файл | PASS |
| REQ-392 | Аналіз того, чого бракувало в промпті | `docs/AUDIT.md` + аудит у чаті | PASS |
| REQ-393 | Alternatives для компонентів | коментарі + REQ-190..208 | PASS |
| REQ-394 | Known compromises | `docs/shell-stack.md` | PASS |
| REQ-395 | Що гірше за GNOME/KDE | `docs/shell-stack.md` | PASS |
| REQ-396 | TODO | README + PROGRESS | PASS |
| REQ-397 | First-build instructions | README FRESH INSTALL | PASS |
| REQ-398 | Recovery instructions | README + bootstrap вивід | PASS |
| REQ-399 | On-device validation instructions | `docs/HARDWARE-VALIDATION.md` | PASS |
| REQ-400 | Nix GC | `default.nix:173` | PASS |
| REQ-401 | Store optimisation | `auto-optimise-store` | PASS |
| REQ-402 | Оновлення лише явне | немає autoUpgrade | PASS |
| REQ-403 | Build перед switch | bootstrap крок 9 | PASS |
| REQ-404 | Health-check після switch | `fennec-health` юніт | PASS |
| REQ-405 | Попереднє покоління лишається | systemd-boot + switch | PASS |
| REQ-406 | Rollback UX | README + bootstrap вивід | PASS |
| REQ-407 | Bootstrap installer | `bootstrap.sh`, `bash -n` exit 0 | PASS |
| REQ-408 | Bootstrap ідемпотентний | `--if-not-exists`, бекапи з міткою часу | PASS |
| REQ-409 | Bootstrap не є пакетним менеджером | лише nix-команди | PASS |
| REQ-410 | Bootstrap не вмикає experimental | крок 11 виводу | PASS |
| REQ-411 | Acceptance checklist | `/etc/fennec/acceptance-test.md` | PASS |
| REQ-412 | Persistent project memory | CLAUDE.md + docs/ | PASS |

## R. Ідентичність

| ID | Вимога | Поточна реалізація | Статус |
|---|---|---|---|
| REQ-420 | Ім'я хоста | `fennec` у flake.nix; audit-промпт згадує `gt72s` | OPEN |
| REQ-421 | Ім'я користувача | `mango`, виведене з `home/mango.nix` | OPEN |
| REQ-422 | Розкладки ua,us | `services.xserver.xkb` + mango | PASS |
| REQ-423 | Часовий пояс / локаль | Europe/Kyiv, en_US+uk_UA — припущення агента | OPEN |

---

## Підсумок


Пораховано скриптом по самій таблиці, а не вручну.


**TOTAL REQUIREMENTS: 345**


| Статус | Кількість |
|---|---|
| PASS | 290 |
| PARTIAL | 10 |
| MISSING | 11 |
| OPEN | 10 |
| ON-DEVICE | 19 |
| NOT-APPLICABLE | 2 |
| UNVERIFIED | 3 |
| **Сума** | **345** |

Сума дорівнює TOTAL — матриця повна.

`UNVERIFIED` використано як окремий статус там, де перевірка неможлива
саме через середовище агента (немає `nix`, заблоковані зовнішні хости),
а не через недоробку в конфізі.
