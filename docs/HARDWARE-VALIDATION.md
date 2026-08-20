# Валідація на залізі

Усе тут **не може** бути перевірене без фізичного MSI GT72S 6QE.
Жоден пункт не має вважатися працюючим, доки не виконано команду і не отримано
очікуваний результат.

Формат: **КОМАНДА** → **ОЧІКУВАНО** → **ПРОВАЛ ОЗНАЧАЄ** → **НАСТУПНИЙ КРОК**.

---

## 1. BIOS і модель

```
sudo dmidecode -s bios-version
sudo dmidecode -s system-product-name
```
**Очікувано:** версія виду `E1782IMS.xxx` або `1782EMS1.109`; продукт `GT72S 6QE`.
**Провал означає:** інша ревізія EC → `msi-ec` не завантажиться.
**Наступний крок:** звірити рядок із `msi-ec.c` обраної ревізії; якщо немає —
підняти `gt72s.msiEc.rev` або лишити модуль вимкненим.

## 2. msi-ec

```
lsmod | grep msi_ec
modinfo msi-ec | head -3
dmesg | grep -i msi-ec
ls /sys/devices/platform/msi-ec/
```
**Очікувано:** `filename` веде в `/extra/` (не `/kernel/`); у dmesg «Firmware allowed»;
у sysfs є `cooler_boost`, `fan_mode`, `shift_mode`.
**Провал означає:** прошивка не в whitelist — це **безпечна** відмова, не поломка.
**Наступний крок:** `gt72s.msiEc.enable = false` і жити без керування вентиляторами,
або дописати підтримку в апстрім.

## 3. Вентилятори і Cooler Boost

```
cat /sys/devices/platform/msi-ec/cooler_boost
echo 1 | sudo tee /sys/devices/platform/msi-ec/cooler_boost   # слухай вентилятори
echo 0 | sudo tee /sys/devices/platform/msi-ec/cooler_boost
```
**Очікувано:** чутна зміна обертів протягом 2-3 с.
**Провал означає:** sysfs є, але EC не реагує.
**Наступний крок:** не переходити до автоматики (`coolerGuard`), доки ручне не працює.

## 4. Температури

```
sensors
cat /sys/class/thermal/thermal_zone*/temp
nvidia-smi --query-gpu=temperature.gpu --format=csv
```
**Очікувано:** `coretemp` присутній; GPU віддає температуру.
**Провал означає:** `coolerGuard` не матиме джерела даних.
**Наступний крок:** вимкнути `gt72s.msiEc.coolerGuard.enable`.

## 5. Конфлікт thermald × coolerGuard (**A-184**)

```
systemctl status thermald
systemctl status msi-ec-cooler-guard   # назва може відрізнятись, звір з модулем
watch -n1 'cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_cur_freq; \
           cat /sys/devices/platform/msi-ec/cooler_boost'
```
**Очікувано:** cooler_boost не «блимає» 1↔0 щосекунди.
**Провал означає:** два регулятори борються.
**Наступний крок:** вимкнути один. Пріоритет — thermald (він знає RAPL і має гістерезис).

## 6. RGB / MSIKLM (**A-181**)

```
lsusb | grep -i steelseries
sudo msiklm test
sudo msiklm "[255;0;0],[0;255;0],[0;0;255]" high normal          # 3 зони
sudo msiklm "[255;0;0],[0;255;0],[0;0;255],[0;0;0],[255;0;255],[0;255;255]" high normal   # 6 арг
```
**Очікувано:** `msiklm test` бачить клавіатуру; зони змінюють колір.
**Провал означає:** інший VID/PID або інша ревізія клавіатури.
**Наступний крок:** записати реальний `lsusb -v` VID/PID; без цього `gt72s.rgb.enable`
лишати `false` — RGB не має ламати завантаження.

## 7. Аудіо і сабвуфер (**A-182**)

Це головна діагностика. Виконати **по порядку**, нічого не міняючи.

```
gt72 audio probe                       # робить кроки 1-5 нижче автоматично
```
Або вручну:
```
# 1. Чи є вже готовий контрол?
amixer -c0 scontrols | grep -i 'bass\|woofer\|lfe\|speaker'

# 2. Скільки DAC-ів у кодека?
grep -c 'Audio Output' /proc/asound/card0/codec#0

# 3. Піни з конфігурацією динаміка
grep -A2 'Pin Complex' /proc/asound/card0/codec#0 | grep -B1 'Speaker'

# 4. GPIO (для MSI у ядрі є лише ALC882_FIXUP_GPIO3)
grep -A4 'GPIO:' /proc/asound/card0/codec#0

# 5. Повний дамп
cat /proc/asound/card0/codec#0 > ~/gt72s-codec.txt

# 6. Тест каналів
speaker-test -D default -c 2 -t wav -l 1
```
**Очікувано (варіант 1):** є контрол `Bass Speaker` → фікс = розм'ютити і
`sudo alsactl store`. Найдешевший шлях.
**Очікувано (варіант 2):** контролу немає, але є непризначений пін-динамік →
pin retask (`0x17` → `0x90170132`).
**Очікувано (варіант 3):** DAC-ів лише 2 → воофер ділить DAC із фронтом,
і це задача GPIO/підсилювача, а не третього каналу.
**Провал означає:** жоден із трьох сценаріїв — потрібен UCM-профіль.
**Наступний крок:** `gt72s.audio.enableSubwooferPatch` вмикати **лише** після
того, як дамп підтвердив конкретний пін. Наосліп — ні.

> Факт, від якого відштовхуємось: MSI специфікує GT72S 6QE як
> «Sound by Dynaudio with Woofer», 2.1 з фізичним сабвуфером.
> Окремого GT72-квірка в ядрі немає — для MSI є лише `ALC882_FIXUP_GPIO3`.

## 8. Панель і 75 Гц (**A-183**)

```
wlr-randr                                  # з-під сесії Mango
cat /sys/class/drm/card*-eDP-1/edid | edid-decode
```
**Очікувано:** видно `eDP-1` і перелік режимів; чи є 75 Гц серед них.
**Провал означає:** панель віддає лише 60 Гц в EDID → потрібен override.
**Наступний крок:** `gt72s.panel75.enable` — **лише** маючи резервний план:
попереднє покоління в systemd-boot завантажується без EDID-override.
Ніколи не лишати систему без способу відкату.

## 9. Suspend / resume

```
systemctl suspend      # потім прокинути
journalctl -b -1 | grep -i 'nvidia\|suspend\|resume' | tail -30
cat /sys/power/mem_sleep
```
**Очікувано:** `[deep]` у `mem_sleep`; після прокидання екран повертається,
текстури не пошкоджені.
**Провал означає:** проблема з `PreserveVideoMemoryAllocations` або з S3.
**Наступний крок:** `gt72 health nvidia`; перевірити `nvidia-suspend.service`.

## 10. Кришка, яскравість, медіаклавіші

```
# кришка
journalctl -f | grep -i lid     # і закрити кришку
# яскравість
ls /sys/class/backlight/         # intel_backlight чи nvidia_0?
brightnessctl set 50%
# клавіші
wev                              # натиснути Fn-комбінації, записати назви
```
**Очікувано:** каталог backlight існує і піддається запису групі `video`;
`wev` показує `XF86MonBrightnessUp` тощо.
**Провал означає:** при MUX бекліт може бути на `nvidia_0`, а не `intel_backlight`.
**Наступний крок:** якщо назви клавіш інші — виправити бінди в `home/mango.nix`.

## 11. OSD (**A-042**)

```
systemctl --user status swayosd
swayosd-client --output-volume raise    # має з'явитись індикатор
```
**Очікувано:** індикатор на екрані.
**Провал означає:** підтверджує A-042 — джерела подій немає.
**Наступний крок:** або `swayosd-libinput-backend` як системна служба,
або замінити `wpctl`/`brightnessctl` у біндах на `swayosd-client`.

## 12. Bluetooth-аудіо

```
bluetoothctl scan on
bluetoothctl pair <MAC> && bluetoothctl connect <MAC>
wpctl status | grep -A5 Sinks
```
**Очікувано:** пристрій з'являється як sink; A2DP-профіль активний.
**Провал означає:** відсутня прошивка або конфлікт профілів.
**Наступний крок:** `dmesg | grep -i bluetooth`; перевірити ath10k/BT coexistence.

## 13. Webcam, мікрофон, картрідер

```
v4l2-ctl --list-devices
arecord -l
lsmod | grep rtsx        # вставити SD-картку
```
**Очікувано:** UVC-камера, аналоговий вхід, `rtsx_pci_sdmmc` вантажиться.
**Провал означає:** відсутній модуль у initrd.
**Наступний крок:** дописати в `boot.initrd.availableKernelModules`.

## 14. Android через USB (**A-101**)

```
adb devices                      # підтвердити діалог на телефоні
lsusb -v 2>/dev/null | grep -i 'bInterfaceClass.*255' -A2
gio mount -li | grep -i mtp      # MTP через GVfs
```
**Очікувано:** пристрій у `adb devices` як `device`, не `unauthorized`;
у Nautilus видно файли телефона.
**Провал означає:** udev-правило по класу інтерфейсу не спрацювало.
**Наступний крок:** `udevadm info -a -n /dev/bus/usb/XXX/YYY` і звірити
`ID_USB_INTERFACES` із шаблонами `ff4201`/`ff4203`.

## 15. GeForce NOW і Vulkan Video (**A-112**, **A-111**)

```
flatpak search geforcenow
flatpak list --runtime | grep -i nvidia
cat /proc/driver/nvidia/version
vainfo
vulkaninfo --summary | grep -i 'deviceName\|apiVersion'
```
**Очікувано:** GL-розширення Flatpak збігається версією з драйвером хоста;
`vainfo` показує **H264** профілі і **не** показує робочий HEVC.
**Провал означає:** невідповідність версій GL-рантайму — найчастіша причина,
коли GFN не стартує.
**Наступний крок:** у клієнті GFN примусово обрати **H.264**.

> Апаратний факт: GM204 має фіксований декодер лише для H.264.
> HEVC отримали GM206/GM200. AV1 не декодує жоден Maxwell.
> Це **не** перевірено на твоїй машині — перевірено за документацією.

## 16. Парсер конфігу Mango (**A-048**)

```
mango --help                 # чи є прапорець перевірки конфігу
journalctl --user -b | grep -i mango | grep -i 'parse\|error\|unknown'
```
**Очікувано:** жодних «unknown option» при старті.
**Провал означає:** синтаксис розійшовся з версією 0.16.0.
**Наступний крок:** звірити з `assets/config.conf` тега, що зібраний у системі.

## 17. SafeBooru API (**A-133**)

```
curl -s 'https://safebooru.org/index.php?page=dapi&s=post&q=index&json=1&limit=5&tags=rating:safe+wallpaper+highres' | head -c 2000
moewall next --verbose
```
**Очікувано:** валідний JSON-масив із `file_url` або `directory`+`image`.
**Провал означає:** структура відповіді змінилась.
**Наступний крок:** підправити `Post` у `tools/moewall/src/source.rs`.

> Ендпоінт **не перевірявся** ні на етапі написання коду, ні під час аудиту:
> `safebooru.org` заблокований egress-проксі середовища (HTTP 000).
> Статус: **UNVERIFIED EXTERNAL API**.
