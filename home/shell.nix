# ── Оболонка і CLI-оточення ───────────────────────────────────────────────────
{
  config,
  lib,
  pkgs,
  ...
}:
{
  # ── fish ────────────────────────────────────────────────────────────────────
  # Виграв: автодоповнення з історії та man-сторінок працює з коробки,
  # підсвітка синтаксису в реальному часі, і головне — розумний дефолт
  # замість «постав 15 плагінів».
  # Програв zsh: усе те саме, але через oh-my-zsh/zinit, тобто півсекунди
  #   на старт кожного терміналу і купа стороннього коду.
  # Програв nushell: структуровані дані — це чудово, але половина
  #   інструкцій в інтернеті просто не працюватиме.
  # ЗАСТЕРЕЖЕННЯ: fish не POSIX-сумісний. Скрипти лишай на bash
  # (у нас усі системні скрипти й так генеруються через writeShellApplication).
  programs.fish = {
    enable = true;

    interactiveShellInit = ''
      # Прибрати вітання
      set -g fish_greeting

      # Кольори fish підтягуються з палітри matugen (див. home/theme.nix).
      if test -f ~/.config/fish/conf.d/matugen-colors.fish
        source ~/.config/fish/conf.d/matugen-colors.fish
      end
    '';

    shellAliases = {
      ls = "eza --icons --group-directories-first";
      ll = "eza -l --icons --group-directories-first --git";
      la = "eza -la --icons --group-directories-first --git";
      lt = "eza --tree --level=2 --icons";
      cat = "bat --style=plain";
      du = "dust";
      df = "duf";
      grep = "rg";

      # NixOS: короткі команди, які реально використовуватимеш щодня.
      # nom = nix-output-monitor, дає читабельний прогрес замість стіни тексту.
      rebuild = "sudo nixos-rebuild switch --flake /etc/nixos#gt72s |& nom";
      rebuild-test = "sudo nixos-rebuild test --flake /etc/nixos#gt72s |& nom";
      rebuild-boot = "sudo nixos-rebuild boot --flake /etc/nixos#gt72s |& nom";
      # Що саме змінилось між поточним і попереднім поколінням.
      gendiff = "nvd diff /run/current-system /nix/var/nix/profiles/system";
      generations = "sudo nix-env --list-generations --profile /nix/var/nix/profiles/system";
    };

    functions = {
      # Пошук пакета за приблизною назвою — те саме, що робитиме nixmgr,
      # але вручну. Корисно, поки інструмент не готовий.
      npkg = {
        body = ''
          nix search nixpkgs $argv --json | jq -r 'to_entries[] | "\(.key | split(".") | .[2:] | join(".")) — \(.value.description)"'
        '';
      };
    };
  };

  # ── starship ────────────────────────────────────────────────────────────────
  # Виграв: один бінарник, TOML-конфіг, ~5 мс на промпт.
  # Програв powerlevel10k: швидкий, але лише для zsh.
  # Програв oh-my-posh: та сама ідея, більший і повільніший.
  programs.starship = {
    enable = true;
    enableFishIntegration = true;
    settings = {
      add_newline = false;
      # Брутальний промпт: гострі кути, без «павер-лайн» стрілок.
      format = lib.concatStrings [
        "[](fg:#3a3a44)"
        "$directory"
        "$git_branch$git_status"
        "$nix_shell"
        "$cmd_duration"
        "$line_break"
        "$character"
      ];
      directory = {
        style = "bold";
        truncation_length = 3;
        truncate_to_repo = true;
      };
      character = {
        success_symbol = "[▍](bold green)";
        error_symbol = "[▍](bold red)";
      };
      nix_shell = {
        symbol = "❄ ";
        format = "[$symbol$state]($style) ";
      };
      cmd_duration = {
        min_time = 2000;
        format = "[$duration]($style) ";
      };
    };
  };

  # ── Дрібні, але щоденні ─────────────────────────────────────────────────────
  programs.zoxide = {
    enable = true;
    enableFishIntegration = true;
    # z <частина_шляху> — стрибок у директорію за частотою відвідувань.
  };

  programs.fzf = {
    enable = true;
    enableFishIntegration = true;
    defaultCommand = "fd --type f --hidden --exclude .git";
  };

  programs.bat = {
    enable = true;
    config.theme = "base16"; # base16 читає кольори з терміналу, тобто з matugen
  };

  programs.direnv = {
    enable = true;
    enableFishIntegration = true;
    nix-direnv.enable = true; # кешує nix-shell, інакше кожен cd — це перебудова
  };

  programs.git = {
    enable = true;
    # TODO: постав свої дані.
    userName = "TODO";
    userEmail = "TODO@example.com";
    extraConfig = {
      init.defaultBranch = "main";
      pull.rebase = true;
      push.autoSetupRemote = true;
      # На btrfs це помітно прискорює status на великих репозиторіях.
      core.untrackedCache = true;
      core.fsmonitor = true;
      diff.algorithm = "histogram";
    };
  };

  programs.btop = {
    enable = true;
    settings = {
      # Показувати GPU: btop уміє читати nvidia через nvml.
      # Якщо панель GPU порожня — перевір, що nvidia-драйвер завантажений.
      shown_boxes = "cpu mem net proc gpu0";
      update_ms = 1000; # 1 с достатньо; 100 мс — це сам btop у топі за CPU
      proc_sorting = "cpu lazy";
      theme_background = false; # прозорий фон = кольори терміналу = matugen
      vim_keys = true;
    };
  };

  programs.yazi = {
    enable = true;
    enableFishIntegration = true;
    settings = {
      mgr = {
        show_hidden = false;
        sort_by = "natural";
        sort_dir_first = true;
        # 3 колонки: батьківська / поточна / прев'ю.
        ratio = [
          1
          3
          4
        ];
      };
      preview = {
        max_width = 1000;
        max_height = 1000;
      };
    };
  };

  programs.helix = {
    enable = true;
    settings = {
      # Тема читає кольори терміналу → тобто теж matugen.
      theme = "base16_transparent";
      editor = {
        line-number = "relative";
        cursorline = true;
        bufferline = "multiple";
        color-modes = true;
        true-color = true;
        lsp.display-messages = true;
        indent-guides.render = true;
        cursor-shape = {
          insert = "bar";
          normal = "block";
          select = "underline";
        };
      };
    };
    # TODO: мовні сервери додаси через nixmgr під конкретні проєкти.
    # Приклад: nixmgr add nil (LSP для Nix), nixmgr add rust-analyzer.
    languages.language = [
      {
        name = "nix";
        auto-format = true;
        formatter.command = "nixfmt";
      }
    ];
    extraPackages = with pkgs; [
      nil # LSP для Nix
      nixfmt # форматер Nix
    ];
  };
}
