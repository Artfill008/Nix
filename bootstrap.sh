#!/usr/bin/env bash
#
# GT72S OS — bootstrap першого розгортання.
#
# ЦЕ ЄДИНИЙ ВИНЯТОК із правила «жодних shell-скриптів».
# Він потрібен рівно один раз: щоб довести щойно встановлений мінімальний
# NixOS до нашої декларативної конфігурації. Після цього системою керує Nix,
# а не цей файл.
#
# ЧОГО ЦЕЙ СКРИПТ НЕ РОБИТЬ:
#   • не встановлює пакети повз Nix (жодних nix-env -i, curl|sh, npm -g);
#   • не видаляє /etc/nixos;
#   • не робить switch, якщо збірка не пройшла;
#   • не вмикає experimental-функції.
#
# ВИКОРИСТАННЯ:
#   sudo ./bootstrap.sh              звичайний запуск
#   sudo ./bootstrap.sh --dry-run    усе, крім switch
#   sudo ./bootstrap.sh --help

set -euo pipefail

readonly REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly HOST="gt72s"
readonly FLAKE_ATTR="fennec"
readonly LOG="/var/log/gt72s-bootstrap-$(date +%Y%m%d-%H%M%S).log"
readonly BACKUP_ROOT="/var/backups/gt72s-bootstrap"

DRY_RUN=0
FAILED_CMD=""

# ── Вивід ────────────────────────────────────────────────────────────────────
c_ok=$'\033[32m'; c_warn=$'\033[33m'; c_fail=$'\033[31m'
c_skip=$'\033[2m'; c_bold=$'\033[1m'; c_off=$'\033[0m'

ok()   { printf '%s[OK]%s   %s\n'   "$c_ok"   "$c_off" "$*"; }
warn() { printf '%s[WARN]%s %s\n'   "$c_warn" "$c_off" "$*"; }
skip() { printf '%s[SKIP]%s %s\n'   "$c_skip" "$c_off" "$*"; }
info() { printf '       %s\n' "$*"; }
die() {
    printf '%s[FAIL]%s %s\n' "$c_fail" "$c_off" "$*" >&2
    if [[ -n "$FAILED_CMD" ]]; then
        printf '       команда: %s\n' "$FAILED_CMD" >&2
    fi
    printf '       повний лог: %s\n' "$LOG" >&2
    printf '\n'
    printf '       Існуюча система НЕ змінена.\n' >&2
    if [[ -d "$BACKUP_ROOT" ]]; then
        printf '       Резервні копії: %s\n' "$BACKUP_ROOT" >&2
    fi
    exit 1
}

section() { printf '\n%s── %s %s\n' "$c_bold" "$*" "$c_off"; }

# Запускає команду, пише і в лог, і на екран, зберігає її текст для die().
run() {
    FAILED_CMD="$*"
    printf '\n$ %s\n' "$*" >>"$LOG"
    if "$@" 2>&1 | tee -a "$LOG"; then
        FAILED_CMD=""
        return 0
    fi
    return 1
}

usage() {
    sed -n '3,20p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'
    exit 0
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --dry-run) DRY_RUN=1; shift ;;
        -h|--help) usage ;;
        *) die "невідомий аргумент: $1" ;;
    esac
done

printf '%sGT72S OS bootstrap%s\n' "$c_bold" "$c_off"
printf 'репозиторій: %s\n' "$REPO_DIR"
printf 'лог:         %s\n' "$LOG"

mkdir -p "$(dirname "$LOG")"
: >"$LOG"

# ═════════════════════════════════════════════════════════════════════════════
# 1. PRE-FLIGHT: чи ми взагалі там, де думаємо
# ═════════════════════════════════════════════════════════════════════════════
section "Перевірка середовища"

[[ "$(id -u)" -eq 0 ]] || die "потрібен root: sudo ./bootstrap.sh"
ok "запущено від root"

[[ -e /etc/NIXOS ]] || die "це не NixOS (немає /etc/NIXOS)"
ok "NixOS виявлено"

command -v nix >/dev/null 2>&1 || die "команда nix недоступна"
command -v nixos-rebuild >/dev/null 2>&1 || die "nixos-rebuild недоступний"
ok "nix $(nix --version | awk '{print $3}')"

[[ -f "$REPO_DIR/flake.nix" ]] || die "у $REPO_DIR немає flake.nix — запусти скрипт із каталогу репозиторію"
ok "flake.nix на місці"

[[ -d "$REPO_DIR/hosts/$HOST" ]] || die "немає hosts/$HOST"
ok "профіль заліза hosts/$HOST знайдено"

if grep -q "nixosConfigurations.\${hostname}" "$REPO_DIR/flake.nix" 2>/dev/null \
   || grep -q "$FLAKE_ATTR" "$REPO_DIR/flake.nix" 2>/dev/null; then
    ok "ціль флейка: .#$FLAKE_ATTR"
else
    die "у flake.nix не знайдено конфігурацію $FLAKE_ATTR"
fi

# Flakes мають бути дозволені, інакше все далі не спрацює.
if nix flake --help >/dev/null 2>&1; then
    ok "підтримка flakes увімкнена"
else
    die "flakes вимкнені. Додай у /etc/nix/nix.conf:
       experimental-features = nix-command flakes"
fi

if [[ -d "$REPO_DIR/.git" ]]; then
    info "git: $(git -C "$REPO_DIR" rev-parse --short HEAD 2>/dev/null || echo '?') на гілці $(git -C "$REPO_DIR" branch --show-current 2>/dev/null || echo '?')"
    if [[ -n "$(git -C "$REPO_DIR" status --porcelain 2>/dev/null)" ]]; then
        warn "робоче дерево брудне — незакомічені зміни увійдуть у збірку"
    fi
fi

# ═════════════════════════════════════════════════════════════════════════════
# 2. ЗАЛІЗО: показати, що бачимо, і звірити з очікуваннями
# ═════════════════════════════════════════════════════════════════════════════
section "Виявлене залізо"

model="$(cat /sys/class/dmi/id/product_name 2>/dev/null || echo '?')"
info "модель:  $model"
case "$model" in
    *GT72*) ok "MSI GT72S розпізнано" ;;
    *)      warn "модель «$model» не схожа на GT72S — конфіг містить GT72S-специфіку" ;;
esac

info "BIOS:    $(cat /sys/class/dmi/id/bios_version 2>/dev/null || echo '?')"

cpu="$(grep -m1 'model name' /proc/cpuinfo | cut -d: -f2- | sed 's/^ *//')"
info "CPU:     $cpu"
case "$cpu" in
    *6820HK*) ok "i7-6820HK підтверджено" ;;
    *)        warn "CPU не 6820HK — параметри під Skylake можуть бути неоптимальні" ;;
esac

ram_gb=$(( $(awk '/MemTotal/{print $2}' /proc/meminfo) / 1024 / 1024 ))
info "RAM:     ~${ram_gb} ГБ"
if [[ "$ram_gb" -ge 40 ]]; then
    ok "обсяг пам'яті відповідає розрахунку (zram 16 ГБ)"
else
    warn "менше 40 ГБ — переглянь zram у modules/performance.nix"
fi

# GPU за PCI ID. GM204M (980M) = 10de:13d7.
gpu="$(lspci -nn 2>/dev/null | grep -i 'VGA\|3D controller' | head -1 || true)"
info "GPU:     ${gpu:-не визначено}"
if printf '%s' "$gpu" | grep -qi '10de:13d7'; then
    ok "GTX 980M (GM204, 10de:13d7) — гілка NVIDIA 580 правильна"
elif printf '%s' "$gpu" | grep -qi '10de'; then
    warn "NVIDIA виявлено, але не 10de:13d7 — перевір, що legacy_580 підходить"
else
    warn "дискретну NVIDIA не видно — перевір MUX у BIOS"
fi

if [[ -d /sys/firmware/efi ]]; then
    ok "завантаження в UEFI (потрібно для systemd-boot)"
else
    die "система завантажена в Legacy/BIOS. Конфіг розрахований на UEFI + systemd-boot."
fi

# ═════════════════════════════════════════════════════════════════════════════
# 3. ДИСК: btrfs, підтоми, відсутність swap
# ═════════════════════════════════════════════════════════════════════════════
section "Диск"

root_fstype="$(findmnt -no FSTYPE / )"
if [[ "$root_fstype" == "btrfs" ]]; then
    ok "корінь на btrfs"
else
    die "корінь на $root_fstype, а конфіг розрахований на btrfs.
       Переустанови з btrfs і підтомами @ @home @nix @log @snapshots."
fi

root_uuid="$(findmnt -no UUID /)"
esp_uuid="$(findmnt -no UUID /boot 2>/dev/null || true)"
[[ -n "$root_uuid" ]] || die "не вдалося визначити UUID кореня"
[[ -n "$esp_uuid" ]] || die "не вдалося визначити UUID /boot — чи змонтований ESP?"
ok "UUID btrfs: $root_uuid"
ok "UUID ESP:   $esp_uuid"

# Підтоми
missing_sv=""
for sv in @ @home @nix @log @snapshots; do
    if btrfs subvolume list / 2>/dev/null | awk '{print $NF}' | grep -qx "$sv"; then
        ok "підтом $sv"
    else
        warn "підтом $sv не знайдено"
        missing_sv="$missing_sv $sv"
    fi
done
if [[ -n "$missing_sv" ]]; then
    warn "відсутні підтоми:$missing_sv"
    info "створити:  btrfs subvolume create /.btrfs/<назва>"
    info "Без @snapshots не працюватиме btrbk (снапшоти)."
fi

# Swap: конфіг розрахований на його ВІДСУТНІСТЬ (лише zram).
if [[ -s /proc/swaps ]] && [[ "$(wc -l </proc/swaps)" -gt 1 ]]; then
    if grep -q zram /proc/swaps; then
        ok "swap лише в zram"
    else
        warn "виявлено дисковий swap:"
        sed -n '2,$p' /proc/swaps | while read -r line; do info "  $line"; done
        info "Конфіг задає swapDevices = [ ] і zram 16 ГБ."
        info "Дисковий swap лишиться в fstab установника — прибери його вручну."
    fi
else
    ok "дискового swap немає (як і задумано)"
fi

# ═════════════════════════════════════════════════════════════════════════════
# 4. РЕЗЕРВНІ КОПІЇ
# ═════════════════════════════════════════════════════════════════════════════
section "Резервні копії"

stamp="$(date +%Y%m%d-%H%M%S)"
backup_dir="$BACKUP_ROOT/$stamp"
mkdir -p "$backup_dir"

# Конфіг, згенерований установником — найцінніше, що є на машині.
if [[ -f /etc/nixos/hardware-configuration.nix ]]; then
    cp -a /etc/nixos/hardware-configuration.nix "$backup_dir/"
    ok "збережено hardware-configuration.nix установника"
fi
if [[ -f /etc/nixos/configuration.nix ]]; then
    cp -a /etc/nixos/configuration.nix "$backup_dir/"
    ok "збережено configuration.nix установника"
fi
if [[ -f "$REPO_DIR/hosts/$HOST/disk-ids.nix" ]]; then
    cp -a "$REPO_DIR/hosts/$HOST/disk-ids.nix" "$backup_dir/"
    ok "збережено попередній disk-ids.nix"
fi
info "каталог: $backup_dir"

# Свіжий hardware-config у temp — НЕ для підстановки, а для звірки.
tmp_hw="$(mktemp -d)"
if nixos-generate-config --no-filesystems --dir "$tmp_hw" >>"$LOG" 2>&1; then
    cp -a "$tmp_hw/hardware-configuration.nix" "$backup_dir/generated-hardware-configuration.nix"
    ok "згенеровано свіжий hardware-config для звірки"
    info "порівняй колись: diff $backup_dir/generated-hardware-configuration.nix $REPO_DIR/hosts/$HOST/hardware-configuration.nix"
else
    warn "nixos-generate-config не спрацював — не критично, ми його не підставляємо"
fi
rm -rf "$tmp_hw"

# ═════════════════════════════════════════════════════════════════════════════
# 5. ДЕТЕКЦІЯ → disk-ids.nix
# ═════════════════════════════════════════════════════════════════════════════
section "Ідентифікатори розділів"

# Пишемо ЛИШЕ машинозалежне. Політика монтування лишається недоторканою
# в hardware-configuration.nix — саме тому вони й розділені.
cat >"$REPO_DIR/hosts/$HOST/disk-ids.nix" <<EOF
# ╔═══════════════════════════════════════════════════════════════════════════╗
# ║  ЗГЕНЕРОВАНО bootstrap.sh — $(date '+%Y-%m-%d %H:%M:%S')                  ║
# ║  Тут ЛИШЕ ідентифікатори цієї машини. Політика монтування, підтоми,       ║
# ║  стиснення і TRIM живуть у hardware-configuration.nix і не чіпаються.     ║
# ╚═══════════════════════════════════════════════════════════════════════════╝
{
  gt72s.disk.rootUuid = "$root_uuid";
  gt72s.disk.espUuid = "$esp_uuid";
}
EOF
ok "disk-ids.nix записано з реальними UUID"

# ═════════════════════════════════════════════════════════════════════════════
# 6. ХЕШ msiklm (потрібен лише для RGB)
# ═════════════════════════════════════════════════════════════════════════════
section "Джерела, які потребують хешу"

msiklm_nix="$REPO_DIR/pkgs/msiklm/default.nix"
if grep -q "lib.fakeHash" "$msiklm_nix" 2>/dev/null; then
    info "msiklm ще з fakeHash — рахую справжній…"
    msiklm_rev="$(grep -oP 'rev = "\K[0-9a-f]{40}' "$msiklm_nix" || true)"
    if [[ -n "$msiklm_rev" ]] && real_hash="$(nix-prefetch-url --unpack --type sha256 \
            "https://github.com/Gibtnix/MSIKLM/archive/${msiklm_rev}.tar.gz" 2>>"$LOG")"; then
        sri="$(nix hash to-sri --type sha256 "$real_hash" 2>>"$LOG" || true)"
        if [[ -n "$sri" ]]; then
            sed -i "s|hash = lib.fakeHash;|hash = \"$sri\";|" "$msiklm_nix"
            ok "хеш msiklm пораховано і вписано: $sri"
            info "закоміть цю зміну: git add pkgs/msiklm/default.nix"
        else
            warn "не вдалося перетворити хеш у SRI — RGB лишиться вимкненим"
        fi
    else
        warn "не вдалося завантажити джерело msiklm — RGB лишиться вимкненим"
        info "це не блокує встановлення: gt72s.rgb.enable за замовчуванням false"
    fi
else
    ok "msiklm уже має справжній хеш"
fi

# ═════════════════════════════════════════════════════════════════════════════
# 7. FLAKE LOCK
# ═════════════════════════════════════════════════════════════════════════════
section "flake.lock"

if [[ -f "$REPO_DIR/flake.lock" ]]; then
    ok "flake.lock існує — версії зафіксовані"
    info "оновлювати лише свідомо: nix flake update"
else
    warn "flake.lock відсутній — створюю"
    info "Це нормально для першого розгортання: у середовищі, де писався"
    info "конфіг, не було nix, тому lock не міг бути згенерований."
    run nix flake lock "$REPO_DIR" || die "не вдалося створити flake.lock"
    ok "flake.lock створено"
    info "ОБОВ'ЯЗКОВО закоміть його: git add flake.lock"
fi

# ═════════════════════════════════════════════════════════════════════════════
# 8. ВАЛІДАЦІЯ ПЕРЕД ЗБІРКОЮ
# ═════════════════════════════════════════════════════════════════════════════
section "Перевірка конфігурації"

run nix flake check "$REPO_DIR" --no-build || die "nix flake check не пройшов"
ok "nix flake check"

# Точкові eval: краще дізнатися про проблему тут, ніж на 40-й хвилині збірки.
eval_attr() {
    local what="$1" expr="$2" val
    if val="$(nix eval --raw "$REPO_DIR#nixosConfigurations.$FLAKE_ATTR.config.$expr" 2>>"$LOG")"; then
        ok "$what: $val"
        return 0
    fi
    warn "$what: не вдалося обчислити (див. лог)"
    return 1
}

eval_attr "версія ядра"   "boot.kernelPackages.kernel.version" || true
eval_attr "драйвер NVIDIA" "hardware.nvidia.package.version"   || true

if nix eval "$REPO_DIR#nixosConfigurations.$FLAKE_ATTR.config.hardware.nvidia.open" 2>>"$LOG" | grep -q false; then
    ok "hardware.nvidia.open = false (обов'язково для Maxwell)"
else
    die "hardware.nvidia.open не false — GM204 не має GSP, відкриті модулі не запрацюють"
fi

# ═════════════════════════════════════════════════════════════════════════════
# 9. ЗБІРКА
# ═════════════════════════════════════════════════════════════════════════════
section "Збірка системи"

info "Це найдовший крок. Перша збірка тягне ядро, NVIDIA і Rust-інструменти."
info "Нічого ще не активується."

run nixos-rebuild build --flake "$REPO_DIR#$FLAKE_ATTR" \
    || die "збірка не пройшла — активація НЕ виконується, система недоторкана"
ok "система зібрана"

if [[ -L "$REPO_DIR/result" ]]; then
    info "замикання: $(readlink -f "$REPO_DIR/result")"
fi

# ═════════════════════════════════════════════════════════════════════════════
# 10. АКТИВАЦІЯ
# ═════════════════════════════════════════════════════════════════════════════
section "Активація"

if [[ "$DRY_RUN" -eq 1 ]]; then
    skip "--dry-run: switch не виконується"
else
    # СТРАТЕГІЯ: build → switch → reboot, БЕЗ проміжного `nixos-rebuild test`.
    #
    # Чому не test: test активує конфігурацію без запису в загрузчик. Для
    # системи, де міняється драйвер NVIDIA і сесія, це означає активацію
    # драйвера без відповідного initrd — стан, у якому графіка може не
    # піднятися, а відкотитись через boot-меню вже не вийде, бо запис
    # не створено. switch безпечніший саме тому, що ЗАЛИШАЄ попереднє
    # покоління в меню.
    run nixos-rebuild switch --flake "$REPO_DIR#$FLAKE_ATTR" \
        || die "switch не пройшов. Попереднє покоління лишається в boot-меню."
    ok "конфігурацію активовано"
fi

# ═════════════════════════════════════════════════════════════════════════════
# 11. ПІДСУМОК
# ═════════════════════════════════════════════════════════════════════════════
section "Готово"

printf '\n%sЩо зроблено%s\n' "$c_bold" "$c_off"
info "• UUID розділів записано в hosts/$HOST/disk-ids.nix"
info "• конфігурацію перевірено (nix flake check) і зібрано"
[[ "$DRY_RUN" -eq 1 ]] && info "• switch пропущено (--dry-run)" || info "• конфігурацію активовано"
info "• резервні копії: $backup_dir"

printf '\n%sЩо НЕ ввімкнено (свідомо, при першій установці)%s\n' "$c_bold" "$c_off"
skip "75 Гц             — gt72s.panel75.enable  (потребує перевірки EDID)"
skip "pin-патч вуфера   — gt72s.audio.enableSubwooferPatch (спершу gt72 audio probe)"
skip "локальні ігри     — fennec.gaming.enable"
skip "друк              — fennec.printing.enable"
skip "ядро 7.2          — fennec.kernel.channel (зараз 6.18)"
if grep -q "lib.fakeHash" "$msiklm_nix" 2>/dev/null; then
    skip "RGB-підсвітка     — gt72s.rgb.enable (хеш msiklm не пораховано)"
fi

printf '\n%sДалі%s\n' "$c_bold" "$c_off"
if [[ "$DRY_RUN" -eq 0 ]]; then
    info "1. Перезавантажся:      sudo reboot"
    info "   Це потрібно через нове ядро і драйвер NVIDIA."
    info "2. Увійди через ReGreet, обери сесію «Mango (UWSM)»."
    info "3. Перевір систему:     gt72 health"
    info "4. З-під сесії:         gt72 health session"
    info "5. Чекліст приймання:   cat /etc/fennec/acceptance-test.md"
else
    info "Прибери --dry-run, щоб активувати."
fi

printf '\n%sЯкщо після перезавантаження щось не так%s\n' "$c_bold" "$c_off"
info "• Графіка не піднялась → Ctrl+Alt+F2, далі:  gt72 health nvidia"
info "• Система не вантажиться → у меню systemd-boot обери попереднє покоління"
info "• Відкат уже в системі →  sudo nixos-rebuild switch --rollback"
info "• Повний лог цього запуску: $LOG"

printf '\n'
