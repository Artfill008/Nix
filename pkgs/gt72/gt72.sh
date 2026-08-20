# gt72 — єдина точка керування апаратними функціями GT72S і перевірки того,
# що декларований конфіг збігається з реальним рантаймом.
#
# АРХІТЕКТУРНИЙ ПРИНЦИП:
#   Nix встановлює МЕХАНІЗМ. Цей CLI керує ПОТОЧНИМ СТАНОМ.
#   Зміна шпалер, RGB чи профілю продуктивності НЕ запускає nixos-rebuild.
#
#   Набір підкоманд — це стабільний контракт. Майбутній GTK4/libadwaita
#   фронтенд має викликати рівно їх (у режимі --json), а не лізти в sysfs.
#   Реалізація всередині може змінитись; контракт — ні.

VERSION="0.1.0"

# ── Рівні зрілості (як ти й просив) ──────────────────────────────────────────
#   OK            — працює як задумано
#   WARNING       — працює, але не оптимально / варте уваги
#   FAIL          — задекларовано, але в рантаймі не працює
#   NOT SUPPORTED — Linux/залізо цього не дозволяють
#   EXPERIMENTAL  — потребує перевірки саме на цій машині

JSON=0
FAILS=0
WARNS=0

c_ok=$'\033[32m'; c_warn=$'\033[33m'; c_fail=$'\033[31m'
c_dim=$'\033[2m';  c_exp=$'\033[35m';  c_off=$'\033[0m'

# Виводить один рядок результату.
# $1 = статус, $2 = назва перевірки, $3 = деталі
report() {
    local status="$1" name="$2" detail="${3:-}"

    case "$status" in
        FAIL) FAILS=$((FAILS + 1)) ;;
        WARNING) WARNS=$((WARNS + 1)) ;;
    esac

    if [[ "$JSON" -eq 1 ]]; then
        printf '{"check":"%s","status":"%s","detail":"%s"}\n' \
            "$name" "$status" "${detail//\"/\\\"}"
        return
    fi

    local colour="$c_dim"
    case "$status" in
        OK)             colour="$c_ok" ;;
        WARNING)        colour="$c_warn" ;;
        FAIL)           colour="$c_fail" ;;
        EXPERIMENTAL)   colour="$c_exp" ;;
    esac

    printf '%s%-14s%s %-34s %s%s%s\n' \
        "$colour" "$status" "$c_off" "$name" "$c_dim" "$detail" "$c_off"
}

section() {
    [[ "$JSON" -eq 1 ]] && return 0
    printf '\n\033[1m── %s ─────────────────────────────\033[0m\n' "$1"
}

# Прочитати файл, якщо існує; інакше порожньо. Ніколи не падає.
slurp() {
    [[ -r "$1" ]] && cat "$1" 2>/dev/null || true
}

# ═════════════════════════════════════════════════════════════════════════════
# ЯДРО ТА ЗАВАНТАЖЕННЯ
# ═════════════════════════════════════════════════════════════════════════════
check_kernel() {
    section "Ядро"

    local running declared_channel declared_version
    running="$(uname -r)"

    # Порівнюємо з тим, що задекларовано в Nix (kernel.nix кладе це в /etc).
    declared_channel="$(grep -oP '(?<=^channel=).*' /etc/fennec/kernel-channel 2>/dev/null || echo '?')"
    declared_version="$(grep -oP '(?<=^version=).*' /etc/fennec/kernel-channel 2>/dev/null || echo '?')"

    if [[ "$running" == "$declared_version"* ]]; then
        report OK "kernel: версія" "$running (канал: $declared_channel)"
    else
        report WARNING "kernel: версія" \
            "запущено $running, задекларовано $declared_version — потрібен reboot?"
    fi

    # Чи задекларована пара «ядро × NVIDIA» перевірена апстрімом.
    local tested
    tested="$(grep -oP '(?<=^nvidia_tested=).*' /etc/fennec/kernel-channel 2>/dev/null || echo '?')"
    if [[ "$tested" == "no" ]]; then
        report EXPERIMENTAL "kernel: пара з NVIDIA 580" \
            "nixpkgs не збирає legacy_580 проти цієї гілки — стеж за оновленнями"
    fi

    # Параметри командного рядка, які ми задекларували.
    local cmdline
    cmdline="$(slurp /proc/cmdline)"
    local param
    for param in preempt=full split_lock_detect=off nowatchdog \
                 nvme_core.default_ps_max_latency_us=0 mem_sleep_default=deep \
                 nvidia-drm.modeset=1 transparent_hugepage=madvise mitigations=off; do
        if [[ "$cmdline" == *"$param"* ]]; then
            report OK "cmdline: $param" "присутній"
        else
            report FAIL "cmdline: $param" "ВІДСУТНІЙ у /proc/cmdline"
        fi
    done
}

check_mitigations() {
    section "Мітигації ЦП"

    # Ти свідомо вимкнув мітигації. Health-check не сперечається з рішенням,
    # але зобов'язаний показувати наслідок, а не мовчати.
    local vuln_dir=/sys/devices/system/cpu/vulnerabilities
    if [[ ! -d "$vuln_dir" ]]; then
        report "NOT SUPPORTED" "мітигації" "ядро не експортує vulnerabilities"
        return
    fi

    local vulnerable=0 f
    for f in "$vuln_dir"/*; do
        [[ -r "$f" ]] || continue
        if [[ "$(slurp "$f")" == Vulnerable* ]]; then
            vulnerable=$((vulnerable + 1))
        fi
    done

    if [[ "$vulnerable" -gt 0 ]]; then
        report WARNING "мітигації: вимкнено" \
            "$vulnerable вразливостей відкрито — свідоме рішення (mitigations=off)"
    else
        report OK "мітигації: активні" "усі закриті"
    fi
}

# ═════════════════════════════════════════════════════════════════════════════
# NVIDIA
# ═════════════════════════════════════════════════════════════════════════════
check_nvidia() {
    section "NVIDIA"

    if [[ ! -r /proc/driver/nvidia/version ]]; then
        report FAIL "nvidia: драйвер" "модуль не завантажений — графіки немає"
        return
    fi

    local ver
    ver="$(grep -oP 'Kernel Module\s+\K[0-9.]+' /proc/driver/nvidia/version || echo '?')"

    # Maxwell підтримує ТІЛЬКИ гілку 580. 590+ не бачить GM204 узагалі.
    if [[ "$ver" == 580.* ]]; then
        report OK "nvidia: версія" "$ver (гілка 580 — єдина для Maxwell)"
    else
        report FAIL "nvidia: версія" \
            "$ver — Maxwell/GM204 підтримується ЛИШЕ гілкою 580"
    fi

    # KMS: без нього не буде Wayland.
    if [[ "$(slurp /sys/module/nvidia_drm/parameters/modeset)" == "Y" ]]; then
        report OK "nvidia: modeset" "увімкнено"
    else
        report FAIL "nvidia: modeset" "вимкнено — Wayland не запуститься"
    fi

    # Збереження VRAM через сон — без цього чорний екран після resume.
    local preserve
    preserve="$(slurp /proc/driver/nvidia/params | grep -oP 'PreserveVideoMemoryAllocations: \K[0-9]+' || echo '?')"
    if [[ "$preserve" == "1" ]]; then
        report OK "nvidia: VRAM через сон" "зберігається"
    else
        report WARNING "nvidia: VRAM через сон" \
            "PreserveVideoMemoryAllocations=$preserve — можливий чорний екран після resume"
    fi

    # Відкриті модулі на Maxwell неможливі: GSP у GM204 немає.
    if [[ -e /sys/module/nvidia/parameters/NVreg_OpenRmEnableUnsupportedGpus ]]; then
        report WARNING "nvidia: open-модулі" "виявлено ознаки open-гілки — на Maxwell це не працює"
    fi
}

check_video_decode() {
    section "Апаратне відео"

    # КЛЮЧОВА ПЕРЕВІРКА САМЕ ДЛЯ ЦІЄЇ МАШИНИ.
    # GM204 має фіксований декодер ТІЛЬКИ для H.264.
    # HEVC отримали GM206 і GM200; AV1 не має жоден Maxwell.
    if ! command -v vainfo >/dev/null 2>&1; then
        report WARNING "vaapi: діагностика" "vainfo не встановлено (пакет libva-utils)"
        return
    fi

    local va
    va="$(vainfo 2>/dev/null || true)"

    if [[ -z "$va" ]]; then
        report FAIL "vaapi: ініціалізація" "vainfo нічого не повернув — VA-API не працює"
        return
    fi

    if [[ "$va" == *H264* ]]; then
        report OK "vaapi: H.264" "апаратний декод доступний"
    else
        report FAIL "vaapi: H.264" "недоступний — це головний кодек цієї машини"
    fi

    if [[ "$va" == *HEVC* ]]; then
        report WARNING "vaapi: HEVC" \
            "заявлено, але GM204 не має фіксованого HEVC-декодера — перевір реально"
    else
        report "NOT SUPPORTED" "vaapi: HEVC" "GM204 не має декодера (є лише в GM206/GM200)"
    fi

    report "NOT SUPPORTED" "vaapi: AV1" "жоден Maxwell не декодує AV1"

    # Практичний наслідок для GeForce NOW і YouTube.
    report EXPERIMENTAL "GeForce NOW: кодек" \
        "у клієнті примусово обери H.264, інакше HEVC піде на CPU"
}

# ═════════════════════════════════════════════════════════════════════════════
# ПРОДУКТИВНІСТЬ
# ═════════════════════════════════════════════════════════════════════════════
check_performance() {
    section "Продуктивність"

    # sched_ext / LAVD
    if [[ -d /sys/kernel/sched_ext ]]; then
        local sched
        sched="$(slurp /sys/kernel/sched_ext/root/ops)"
        if [[ "$sched" == *lavd* ]]; then
            report OK "scx: планувальник" "scx_lavd активний"
        elif [[ -n "$sched" ]]; then
            report WARNING "scx: планувальник" "активний $sched, очікувався scx_lavd"
        else
            report FAIL "scx: планувальник" "sched_ext є, але жоден планувальник не завантажений"
        fi
    else
        report FAIL "scx: sched_ext" "ядро без підтримки sched_ext"
    fi

    # zram
    if [[ -e /sys/block/zram0/disksize ]]; then
        local size_gb algo raw
        raw="$(slurp /sys/block/zram0/disksize)"
        # Порожній або нечисловий вміст → арифметика впала б разом зі скриптом.
        [[ "$raw" =~ ^[0-9]+$ ]] || raw=0
        size_gb=$(( raw / 1024 / 1024 / 1024 ))
        algo="$(slurp /sys/block/zram0/comp_algorithm | grep -oP '\[\K[^]]+' || echo '?')"
        if [[ "$size_gb" -ge 15 && "$algo" == "zstd" ]]; then
            report OK "zram" "${size_gb} ГБ, $algo"
        else
            report WARNING "zram" "${size_gb} ГБ, $algo — очікувалось 16 ГБ / zstd"
        fi
    else
        report FAIL "zram" "не активований"
    fi

    # sysctl
    local key expected actual
    while read -r key expected; do
        [[ -z "$key" ]] && continue
        actual="$(sysctl -n "$key" 2>/dev/null || echo '?')"
        if [[ "$actual" == "$expected" ]]; then
            report OK "sysctl: $key" "$actual"
        else
            report WARNING "sysctl: $key" "$actual (очікувалось $expected)"
        fi
    done <<'SYSCTL'
vm.swappiness 180
vm.page-cluster 0
vm.vfs_cache_pressure 50
vm.max_map_count 2147483642
SYSCTL

    # MGLRU
    local mglru
    mglru="$(slurp /sys/kernel/mm/lru_gen/enabled)"
    if [[ -z "$mglru" ]]; then
        report "NOT SUPPORTED" "MGLRU" "не вкомпільований у це ядро"
    elif [[ "$mglru" == "0x0007" ]]; then
        report OK "MGLRU" "$mglru (усі можливості)"
    else
        report WARNING "MGLRU" "$mglru — очікувалось 0x0007"
    fi

    # THP
    local thp
    thp="$(slurp /sys/kernel/mm/transparent_hugepage/enabled)"
    if [[ "$thp" == *"[madvise]"* ]]; then
        report OK "THP" "madvise"
    else
        report WARNING "THP" "$thp — очікувався madvise"
    fi

    # Планувальник NVMe
    local dev sched_file
    for dev in /sys/block/nvme*n1; do
        [[ -d "$dev" ]] || continue
        sched_file="$dev/queue/scheduler"
        if [[ "$(slurp "$sched_file")" == *"[none]"* ]]; then
            report OK "nvme: планувальник" "none на $(basename "$dev")"
        else
            report WARNING "nvme: планувальник" "$(slurp "$sched_file") на $(basename "$dev")"
        fi
    done

    # Керування живленням: перевіряємо, що керівник РІВНО ОДИН.
    # УВАГА: тут НЕ можна писати `systemctl ... && managers=$((managers+1))`.
    # Під `set -e` такий рядок — це повна команда, і якщо служба не активна,
    # список повертає ненуль і скрипт мовчки завершується посеред перевірки.
    # Саме тому явний if/then.
    local managers=0 mgr
    for mgr in tuned power-profiles-daemon tlp auto-cpufreq; do
        if systemctl is-active --quiet "$mgr.service"; then
            managers=$((managers + 1))
        fi
    done

    case "$managers" in
        1) report OK "живлення: керівник" "рівно один активний демон" ;;
        0) report WARNING "живлення: керівник" "жоден не активний — governor некерований" ;;
        *) report FAIL "живлення: керівник" \
               "$managers демонів одночасно — вони конфліктують за governor" ;;
    esac
}

# ═════════════════════════════════════════════════════════════════════════════
# СЕСІЯ
# ═════════════════════════════════════════════════════════════════════════════
check_session() {
    section "Сесія"

    if [[ -n "${WAYLAND_DISPLAY:-}" ]]; then
        report OK "wayland" "$WAYLAND_DISPLAY"
    else
        report WARNING "wayland" "WAYLAND_DISPLAY не заданий (запущено не з сесії?)"
    fi

    if pgrep -x mango >/dev/null 2>&1; then
        report OK "mango" "композитор працює"
    else
        report FAIL "mango" "процес не знайдено"
    fi

    # XWayland критичний: без нього не працюють Android Studio і емулятор.
    if pgrep -x Xwayland >/dev/null 2>&1; then
        report OK "XWayland" "працює"
    else
        report WARNING "XWayland" "не запущений — Android Studio та емулятор не стартують"
    fi

    # uwsm тримає graphical-session.target. Якщо цілі немає — половина
    # user-служб не запуститься, і це виглядатиме як випадкові баги.
    if systemctl --user is-active --quiet graphical-session.target; then
        report OK "graphical-session.target" "досягнута"
    else
        report FAIL "graphical-session.target" \
            "не досягнута — user-служби (swayosd, waybar) не піднімуться"
    fi

    # Портали. Окремо перевіряємо саме ScreenCast — це те, що ламається
    # найчастіше і що потрібне для шарингу екрана в браузері.
    local portals
    portals="$(busctl --user list 2>/dev/null | grep -c 'portal' || true)"
    if [[ "${portals:-0}" -gt 0 ]]; then
        report OK "xdg-desktop-portal" "$portals служб на шині"
    else
        report FAIL "xdg-desktop-portal" "не зареєстровані — шаринг екрана і файлові діалоги зламані"
    fi

    if systemctl --user is-active --quiet xdg-desktop-portal-wlr.service; then
        report OK "портал: ScreenCast (wlr)" "активний"
    else
        report WARNING "портал: ScreenCast (wlr)" "не активний — шаринг екрана не працюватиме"
    fi

    # Відомий і незакриваний недолік зібраного стека.
    report "NOT SUPPORTED" "портал: вибір ВІКНА" \
        "xdg-desktop-portal-wlr вміє лише монітор цілком (у GNOME є вибір вікна)"

    # Аудіо
    if systemctl --user is-active --quiet pipewire.service; then
        report OK "pipewire" "активний"
    else
        report FAIL "pipewire" "не активний — звуку немає"
    fi
    if systemctl --user is-active --quiet wireplumber.service; then
        report OK "wireplumber" "активний"
    else
        report FAIL "wireplumber" "не активний — пристрої не будуть налаштовані"
    fi

    # Keyring: Secret Service потрібен NetworkManager, браузеру і git.
    if busctl --user list 2>/dev/null | grep -q 'org.freedesktop.secrets'; then
        report OK "keyring: Secret Service" "доступний"
    else
        report WARNING "keyring: Secret Service" "не на шині — паролі Wi-Fi проситимуться щоразу"
    fi

    # Polkit-агент: без нього GUI-програми не зможуть попросити права.
    if pgrep -f polkit-gnome-authentication-agent >/dev/null 2>&1; then
        report OK "polkit: агент" "працює"
    else
        report FAIL "polkit: агент" "не працює — не буде діалогів підвищення прав"
    fi
}

check_services() {
    section "Служби"

    local failed
    failed="$(systemctl --failed --no-legend --plain 2>/dev/null | wc -l | tr -d ' ')"
    if [[ "$failed" -eq 0 ]]; then
        report OK "systemd: система" "жодного зламаного юніта"
    else
        report FAIL "systemd: система" "$failed зламаних — дивись systemctl --failed"
    fi

    local ufailed
    ufailed="$(systemctl --user --failed --no-legend --plain 2>/dev/null | wc -l | tr -d ' ')"
    if [[ "$ufailed" -eq 0 ]]; then
        report OK "systemd: користувач" "жодного зламаного юніта"
    else
        report FAIL "systemd: користувач" "$ufailed зламаних — systemctl --user --failed"
    fi

    local svc
    for svc in NetworkManager bluetooth udisks2 flatpak-repo; do
        if systemctl is-active --quiet "$svc.service"; then
            report OK "служба: $svc" "активна"
        else
            report WARNING "служба: $svc" "не активна"
        fi
    done
}

check_storage() {
    section "Сховище"

    # btrfs зі стисненням
    if mount | grep -q 'on / type btrfs'; then
        if mount | grep 'on / type btrfs' | grep -q 'compress=zstd'; then
            report OK "btrfs: стиснення" "zstd активне"
        else
            report WARNING "btrfs: стиснення" "не бачу compress=zstd у опціях монтування"
        fi

        if mount | grep 'on / type btrfs' | grep -q 'discard=async'; then
            report OK "btrfs: TRIM" "discard=async (безперервний)"
        else
            report WARNING "btrfs: TRIM" "discard=async немає — увімкни services.fstrim"
        fi
    else
        report WARNING "btrfs" "корінь не на btrfs"
    fi

    # Знос NVMe
    if command -v nvme >/dev/null 2>&1 && [[ -e /dev/nvme0 ]]; then
        local used
        used="$(nvme smart-log /dev/nvme0 2>/dev/null | grep -oP 'percentage_used\s*:\s*\K[0-9]+' || echo '')"
        if [[ "$used" =~ ^[0-9]+$ ]]; then
            if [[ "$used" -lt 80 ]]; then
                report OK "nvme: знос" "${used}% ресурсу використано"
            else
                report WARNING "nvme: знос" "${used}% — час планувати заміну"
            fi
        fi
    fi

    # Снапшоти
    if command -v snapper >/dev/null 2>&1; then
        local snaps
        snaps="$(snapper -c home list --columns number 2>/dev/null | tail -n +3 | wc -l || echo 0)"
        report OK "snapper: /home" "$snaps снапшотів"
    else
        report WARNING "snapper" "не встановлений"
    fi
}

# ═════════════════════════════════════════════════════════════════════════════
# ЗАЛІЗО GT72S
# ═════════════════════════════════════════════════════════════════════════════
check_hardware() {
    section "Залізо GT72S"

    # msi-ec: модуль має whitelist прошивок EC. Якщо твоя не в списку —
    # він відмовиться вантажитись, і це нормальна, безпечна поведінка.
    if [[ -d /sys/devices/platform/msi-ec ]]; then
        report "EXPERIMENTAL" "msi-ec" "модуль завантажений — інтерфейс доступний"
    elif lsmod 2>/dev/null | grep -q msi_ec; then
        report WARNING "msi-ec" "модуль є, але sysfs не з'явився"
    else
        report "NOT SUPPORTED" "msi-ec" \
            "не завантажений — імовірно, прошивка EC не у whitelist (це безпечно)"
    fi

    # Сабвуфер Dynaudio. MSI офіційно заявляє 2.1 з фізичним woofer.
    # Окремого GT72-квірка в ядрі немає — тому це діагностика, а не факт.
    if command -v amixer >/dev/null 2>&1; then
        if amixer -c0 scontrols 2>/dev/null | grep -qi 'bass\|woofer\|lfe'; then
            local bass_state
            bass_state="$(amixer -c0 get 'Bass Speaker' 2>/dev/null | grep -oP '\[\K(on|off)' | head -1 || echo '?')"
            if [[ "$bass_state" == "on" ]]; then
                report OK "аудіо: сабвуфер" "контрол знайдено і увімкнено"
            else
                report WARNING "аудіо: сабвуфер" \
                    "контрол є, але стан '$bass_state' — розмʼютай і збережи alsactl store"
            fi
        else
            report "EXPERIMENTAL" "аудіо: сабвуфер" \
                "окремого контролу немає — потрібна діагностика (gt72 audio probe)"
        fi
    fi

    # Панель 75 Гц.
    if command -v wlr-randr >/dev/null 2>&1 && [[ -n "${WAYLAND_DISPLAY:-}" ]]; then
        local rate
        rate="$(wlr-randr 2>/dev/null | grep -oP '^\s+\K[0-9]+(?=\.[0-9]+ Hz)' | head -1 || echo '')"
        if [[ "$rate" == "75" ]]; then
            report OK "панель: частота" "75 Гц"
        elif [[ -n "$rate" ]]; then
            report "EXPERIMENTAL" "панель: частота" "${rate} Гц — 75 Гц потребує EDID-override"
        fi
    fi

    # Батарея
    if [[ -d /sys/class/power_supply/BAT0 ]]; then
        local cap
        cap="$(slurp /sys/class/power_supply/BAT0/capacity)"
        report OK "батарея" "${cap}% (BAT0)"
    else
        report WARNING "батарея" "BAT0 не знайдено"
    fi

    # Bluetooth
    if command -v bluetoothctl >/dev/null 2>&1; then
        if bluetoothctl list 2>/dev/null | grep -q Controller; then
            report OK "bluetooth: контролер" "виявлено"
        else
            report WARNING "bluetooth: контролер" "не виявлено"
        fi
    fi
}

check_android() {
    section "Android"

    if command -v adb >/dev/null 2>&1; then
        local devices
        devices="$(adb devices 2>/dev/null | tail -n +2 | grep -c device || true)"
        report OK "adb" "встановлено, підключено пристроїв: ${devices:-0}"
    else
        report WARNING "adb" "не встановлено"
    fi

    # nix-ld — без нього бінарники Android SDK просто не запускаються.
    if [[ -e /run/current-system/sw/share/nix-ld/lib/ld.so ]] || [[ -e /lib64/ld-linux-x86-64.so.2 ]]; then
        report OK "nix-ld" "динамічний лінкер підставлений (SDK запуститься)"
    else
        report FAIL "nix-ld" \
            "не налаштований — бінарники Android SDK впадуть із 'No such file or directory'"
    fi

    if [[ -e /dev/kvm ]]; then
        if [[ -r /dev/kvm && -w /dev/kvm ]]; then
            report OK "kvm: емулятор" "доступний для запису — прискорення працює"
        else
            report FAIL "kvm: емулятор" "немає прав — додай користувача в групу kvm"
        fi
    else
        report FAIL "kvm" "/dev/kvm відсутній — увімкни VT-x у BIOS"
    fi
}

# ═════════════════════════════════════════════════════════════════════════════
# КОМАНДИ
# ═════════════════════════════════════════════════════════════════════════════
cmd_health() {
    local what="${1:-all}"

    case "$what" in
        all)
            check_kernel; check_mitigations; check_nvidia; check_video_decode
            check_performance; check_session; check_services; check_storage
            check_hardware; check_android
            ;;
        kernel)       check_kernel; check_mitigations ;;
        nvidia)       check_nvidia ;;
        video)        check_video_decode ;;
        performance)  check_performance ;;
        session)      check_session ;;
        services)     check_services ;;
        storage)      check_storage ;;
        hardware)     check_hardware ;;
        android)      check_android ;;
        *)
            printf 'Невідомий розділ: %s\n' "$what" >&2
            printf 'Доступні: all kernel nvidia video performance session services storage hardware android\n' >&2
            return 2
            ;;
    esac

    if [[ "$JSON" -eq 0 ]]; then
        printf '\n'
        if [[ "$FAILS" -gt 0 ]]; then
            printf '%sПідсумок: %d FAIL, %d WARNING%s\n' "$c_fail" "$FAILS" "$WARNS" "$c_off"
        elif [[ "$WARNS" -gt 0 ]]; then
            printf '%sПідсумок: %d WARNING, критичних проблем немає%s\n' "$c_warn" "$WARNS" "$c_off"
        else
            printf '%sПідсумок: усе гаразд%s\n' "$c_ok" "$c_off"
        fi
    fi

    [[ "$FAILS" -eq 0 ]]
}

cmd_status() {
    # Коротка зведена картка для бару чи GUI.
    local gpu_temp cpu_temp profile
    gpu_temp="$(nvidia-smi --query-gpu=temperature.gpu --format=csv,noheader 2>/dev/null || echo '?')"
    cpu_temp="$(sensors 2>/dev/null | grep -oP 'Package id 0:\s+\+\K[0-9]+' | head -1 || echo '?')"
    profile="$(tuned-adm active 2>/dev/null | grep -oP 'Current active profile: \K.*' || echo '?')"

    if [[ "$JSON" -eq 1 ]]; then
        printf '{"gpu_temp":"%s","cpu_temp":"%s","profile":"%s","kernel":"%s"}\n' \
            "$gpu_temp" "$cpu_temp" "$profile" "$(uname -r)"
    else
        printf 'Профіль:  %s\n' "$profile"
        printf 'CPU:      %s°C\n' "$cpu_temp"
        printf 'GPU:      %s°C\n' "$gpu_temp"
        printf 'Ядро:     %s\n' "$(uname -r)"
    fi
}

cmd_performance() {
    local profile="${1:-}"

    # Керуємо ЧЕРЕЗ TuneD, а не записом у sysfs напряму.
    # Це і є «перевірений interface» замість raw-запису: один керівник,
    # який ми вже обрали в modules/performance.nix.
    case "$profile" in
        "")
            tuned-adm active
            ;;
        powersave|balanced|throughput-performance)
            tuned-adm profile "$profile"
            printf 'Профіль: %s\n' "$profile"
            ;;
        max)
            tuned-adm profile throughput-performance
            printf 'Профіль: throughput-performance\n'
            ;;
        *)
            printf 'Профілі: powersave | balanced | throughput-performance | max\n' >&2
            printf 'Повний список: tuned-adm list\n' >&2
            return 2
            ;;
    esac
}

cmd_audio_probe() {
    # Діагностичні сходи для сабвуфера — рівно ті, що описані в аудиті.
    # Нічого не змінює. Тільки збирає дані, за якими приймається рішення.
    printf '=== 1. Чи є вже готовий контрол? ===\n'
    amixer -c0 scontrols 2>/dev/null | grep -i 'bass\|woofer\|lfe\|speaker' || printf '(нічого не знайдено)\n'

    printf '\n=== 2. Скільки DAC-ів у кодека? ===\n'
    grep -c 'Audio Output' /proc/asound/card0/codec#0 2>/dev/null || printf '(дамп недоступний)\n'
    printf '(якщо 2 — воофер ділить DAC із фронтом, і це задача GPIO/amp, а не 3-го каналу)\n'

    printf '\n=== 3. Піни зі схожою на динамік конфігурацією ===\n'
    grep -A2 'Pin Complex' /proc/asound/card0/codec#0 2>/dev/null \
        | grep -B1 'Speaker' || printf '(нічого)\n'

    printf '\n=== 4. Стан GPIO (MSI-квірк саме тут) ===\n'
    grep -A4 'GPIO:' /proc/asound/card0/codec#0 2>/dev/null || printf '(немає GPIO-секції)\n'
    printf '(для MSI у ядрі є лише ALC882_FIXUP_GPIO3 — якщо amp воофера\n'
    printf ' сидить на іншій лінії, він просто не запитаний)\n'

    printf '\n=== 5. Повний дамп для аналізу ===\n'
    printf 'Збережи і подивись уважно:\n'
    printf '    cat /proc/asound/card0/codec#0 > ~/gt72s-codec.txt\n'
}

usage() {
    cat <<'USAGE'
gt72 — керування апаратними функціями MSI GT72S 6QE

ВИКОРИСТАННЯ
    gt72 [--json] <команда> [аргументи]

КОМАНДИ
    status                  коротка зведена картка (температури, профіль)
    health [розділ]         перевірка «конфіг vs рантайм»
                            розділи: all kernel nvidia video performance
                                     session services storage hardware android
    performance [профіль]   показати або змінити профіль живлення
                            профілі: powersave balanced throughput-performance max
    audio probe             діагностика сабвуфера Dynaudio (нічого не змінює)
    version                 версія

ПРО --json
    Машиночитаний вивід. Це контракт для майбутнього GTK4-фронтенду:
    GUI має викликати ці команди, а не читати sysfs самостійно.

ЩО ЦЕЙ ІНСТРУМЕНТ НЕ РОБИТЬ
    Не пише в EC напряму. Керування вентиляторами і turbo йде через
    перевірені інтерфейси (TuneD, thermald, msi-ec), а не наосліп у порти.
USAGE
}

main() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --json) JSON=1; shift ;;
            -h|--help) usage; return 0 ;;
            *) break ;;
        esac
    done

    local cmd="${1:-status}"
    shift || true

    case "$cmd" in
        status)       cmd_status ;;
        health)       cmd_health "${1:-all}" ;;
        performance)  cmd_performance "${1:-}" ;;
        audio)
            case "${1:-}" in
                probe) cmd_audio_probe ;;
                *) printf 'Використання: gt72 audio probe\n' >&2; return 2 ;;
            esac
            ;;
        version)      printf 'gt72 %s\n' "$VERSION" ;;
        help)         usage ;;
        *)            usage >&2; return 2 ;;
    esac
}

main "$@"
