# ── Сабвуфер GT72S ────────────────────────────────────────────────────────────
#
# ЩО Я ПЕРЕВІРИВ У ВИХІДНИКАХ ЯДРА (Linux master, sound/hda/codecs/realtek/):
#
#  • У alc269.c для MSI (PCI subvendor 0x1462) є рівно два квірки, обидва для
#    Cubi (MS-B120/MS-B171). До GT72 стосунку не мають.
#
#  • У alc882.c (сюди належить ALC898 — HDA_CODEC_ID(0x10ec0899, "ALC898"))
#    для 0x1462 є квірки для GE63/GP63/GP73/GL63/GL73/GP65 і материнок,
#    а також загальний вендорний перехоплювач:
#        SND_PCI_QUIRK_VENDOR(0x1462, "MSI", ALC882_FIXUP_GPIO3)
#    Тобто твій GT72 отримує ALC882_FIXUP_GPIO3 (він смикає GPIO3 — вмикає
#    підсилювач), і БІЛЬШЕ НІЧОГО. Квірка саме під сабвуфер для GT72 в ядрі НЕМАЄ.
#
#  ВИСНОВОК (гіпотеза, не підтверджений факт):
#  Пін сабвуфера у кодеку швидше за все ФІЗИЧНО ПІДКЛЮЧЕНИЙ, але має
#  default pin config, який ядро інтерпретує як «не підключено» або як
#  звичайний Speaker без ролі LFE. Через це PipeWire бачить стерео і
#  на саб нічого не подає.
#
#  ЦЕ САМЕ ТОЙ КЛАС ПРОБЛЕМ, ЩО ЛІКУЄТЬСЯ ПЕРЕВИЗНАЧЕННЯМ ПІНІВ.
#  «PipeWire вже працює» тут не відповідь: PipeWire не може створити канал,
#  якого йому не показав ALSA.
#
# ─────────────────────────────────────────────────────────────────────────────
# ЯК З'ЯСУВАТИ ПРАВДУ НА МАШИНІ (роби це ПЕРЕД тим, як вмикати модуль):
#
#  1. Який кодек і які піни:
#       cat /proc/asound/card*/codec#* | less
#     Шукай рядок «Codec: Realtek ALC...» і далі блоки «Node 0x__ [Pin Complex]».
#     Для кожного піна дивись «Pin Default 0x________».
#
#  2. Розшифруй Pin Default. Нас цікавлять піни, у яких:
#       • Connectivity = Fixed / Internal (тобто вбудований динамік),
#       • Location вказує на низ/шасі,
#       • але Default Device = Speaker без LFE-ролі, АБО
#       • Connection = Not Connected (0x4...) при тому, що фізично він є.
#     Найчастіший підозрюваний на Realtek — Node 0x17.
#
#  3. Порахуй кількість DAC-ів:
#       cat /proc/asound/card*/codec#* | grep -c "Audio Output"
#     Якщо їх 3+, то є куди підключити третій канал.
#
#  4. Швидкий тест БЕЗ перезавантаження (hda-verb з pkgs.alsa-tools):
#       sudo hda-verb /dev/snd/hwC0D0 0x17 SET_PIN_WIDGET_CONTROL 0x40
#     і послухай, чи з'явився низ. Це runtime-експеримент, він скидається
#     після перезавантаження — тобто безпечний.
#
#  5. Або через GUI: `hdajackretask` (теж у pkgs.alsa-tools). Він уміє
#     «Install boot override» — але на NixOS це запише в /lib/firmware,
#     чого робити НЕ можна (файлова система тільки для читання).
#     Тому нижче — декларативний еквівалент того самого.
#
# ─────────────────────────────────────────────────────────────────────────────
{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.gt72s.audio;

  # Файл патча пінів у форматі, який розуміє snd-hda-intel (опція patch=).
  # Формат описаний у Documentation/sound/hd-audio/notes.rst ядра.
  pinPatch = pkgs.writeTextDir "lib/firmware/hda-jack-retask-gt72s.fw" ''
    [codec]
    ${toString cfg.codecVendorId} ${toString cfg.codecAddress} 0

    [pincfg]
    ${lib.concatStringsSep "\n" (lib.mapAttrsToList (pin: val: "${pin} ${val}") cfg.pinConfig)}
  '';
in
{
  options.gt72s.audio = {
    enableSubwooferPatch = lib.mkEnableOption ''
      перевизначення пінів HDA для сабвуфера.

      ⚠ НЕ ВМИКАЙ, поки не пройшов діагностику з коментаря вгорі файлу.
      Неправильні піни = німі динаміки (лікується поверненням enable = false
      і перезавантаженням, тому це не смертельно, але дратує).
    '';

    codecVendorId = lib.mkOption {
      type = lib.types.str;
      default = "0x10ec0899";
      description = ''
        Vendor Id кодека з `cat /proc/asound/card0/codec#0 | head -3`.
        0x10ec0899 = ALC898 (це найімовірніший варіант для GT72S,
        але ПЕРЕВІР — я не можу прочитати твій кодек звідси).
      '';
    };

    codecAddress = lib.mkOption {
      type = lib.types.str;
      default = "0";
      description = "Address з того ж виводу (зазвичай 0).";
    };

    pinConfig = lib.mkOption {
      type = lib.types.attrsOf lib.types.str;
      default = {
        # ПЛЕЙСХОЛДЕР. Ці значення НЕ підібрані під твою машину.
        # 0x17 — типовий пін «bass speaker» у Realtek.
        # 0x90170132: Fixed / Internal / Speaker / LFE-асоціація 3, послідовність 2.
        # TODO: заміни на реальні значення, отримані з кроків 1-4 вгорі.
        "0x17" = "0x90170132";
      };
      description = "Мапа «пін → нове значення Pin Default».";
    };
  };

  config = lib.mkMerge [
    # ── Те, що робимо ЗАВЖДИ: інструменти для діагностики ────────────────────
    {
      environment.systemPackages = with pkgs; [
        alsa-utils # aplay -l, speaker-test, alsamixer
        alsa-tools # hda-verb, hdajackretask, hda-analyzer
        pwvucontrol
      ];

      # speaker-test -c 3 -t wav дозволить перевірити LFE окремо.
      # Корисна команда після патча:
      #   speaker-test -D default -c 6 -t wav -l 1
    }

    # ── Патч пінів: тільки за явним увімкненням ──────────────────────────────
    (lib.mkIf cfg.enableSubwooferPatch {
      # Кладемо файл патча у /run/current-system/firmware, звідки ядро його
      # прочитає. Це і є декларативний аналог «Install boot override».
      hardware.firmware = [ pinPatch ];

      boot.extraModprobeConfig = ''
        options snd-hda-intel patch=hda-jack-retask-gt72s.fw
      '';

      # ЯКЩО ПІСЛЯ ЦЬОГО ЗВУК ЗНИК ПОВНІСТЮ:
      #   1. Перезавантажся в попереднє покоління (меню systemd-boot).
      #   2. Постав enableSubwooferPatch = false.
      #   3. Повернись до кроку 4 діагностики і підбирай пін через hda-verb —
      #      він не переживає перезавантаження і тому безпечніший для експериментів.
    })
  ];

  # ── ЩО САМЕ Є ГІПОТЕЗОЮ, А ЩО ФАКТОМ ────────────────────────────────────────
  # ФАКТ:      у ядрі немає GT72-специфічної квірки для сабвуфера.
  # ФАКТ:      GT72 отримує лише ALC882_FIXUP_GPIO3 через вендорний перехоплювач.
  # ФАКТ:      механізм patch= для snd-hda-intel існує і працює на NixOS
  #            через hardware.firmware.
  # ГІПОТЕЗА:  пін 0x17 і значення 0x90170132 — я їх НЕ перевіряв на твоєму
  #            залізі і перевірити звідси не можу.
  # ГІПОТЕЗА:  що сабвуфер взагалі є окремим каналом кодека, а не пасивним
  #            резонатором, підключеним паралельно основним динамікам.
  #            На частині ноутбуків «сабвуфер» — саме друге, і тоді
  #            перевизначати нічого не треба, бо низ уже йде туди.
  #            Крок 3 діагностики (кількість DAC-ів) відповість на це.
}
