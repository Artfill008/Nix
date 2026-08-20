//! nixmgr — декларативний менеджер пакетів для цієї конфігурації.
//!
//! ЦЕ СКЕЛЕТ, а не завершений застосунок: логіка резолвінгу, детекту unfree,
//! редагування файлу і відкату вже робоча, а от TUI/GTK-шар навмисно
//! мінімальний — його ти писатимеш сам.
//!
//! ── АРХІТЕКТУРА (шари, кожен замінюється незалежно) ──────────────────────────
//!
//!   search.rs   резолвінг «приблизна назва» → атрибут   (nix search --json
//!               + нечітке переранжування через nucleo)
//!   meta.rs     властивості пакета                       (nix eval --json)
//!   curated.rs  таблиця «пакет потребує модуля»          (вбудований TOML)
//!   edit.rs     правка managed-packages.nix              (маркери, не AST)
//!   rebuild.rs  nixos-rebuild + відкат файлу
//!   main.rs     CLI поверх усього цього
//!
//! Коли дійде до GTK4/libadwaita/Relm4: міняється ЛИШЕ main.rs.
//! Решта — чиста бібліотека без вводу-виводу з користувачем.
//! Заведи lib.rs, винеси туди модулі, і GUI підключить їх як крейт.
//!
//! ── ЩО ВЗЯТИ У SNOWFALLORG ───────────────────────────────────────────────────
//!   з nix-editor:          крейт як бібліотеку, якщо колись знадобиться
//!                          редагувати чужі .nix (див. коментар в edit.rs)
//!   з nix-software-center: модель привілеїв (окремий helper під polkit)
//!                          і кеш метаданих, щоб пошук був миттєвим
//!   НЕ брати:              їхні CLI-інтерфейси і залежність від nix-data

mod curated;
mod edit;
mod meta;
mod rebuild;
mod search;

use anyhow::{bail, Result};
use clap::{Parser, Subcommand};
use dialoguer::Select;
use std::path::PathBuf;

#[derive(Parser)]
#[command(
    name = "nixmgr",
    version,
    about = "Декларативне встановлення пакетів NixOS"
)]
struct Cli {
    /// Шлях до файлу, яким володіє інструмент.
    #[arg(long, default_value = "/etc/nixos/modules/managed-packages.nix")]
    managed: PathBuf,

    /// Корінь флейка.
    #[arg(long, default_value = "/etc/nixos")]
    flake: String,

    /// Ім'я nixosConfiguration.
    #[arg(long, default_value = "gt72s")]
    host: String,

    /// Не викликати nixos-rebuild — лише змінити файл.
    #[arg(long)]
    no_rebuild: bool,

    /// switch / test / boot
    #[arg(long, default_value = "switch")]
    action: String,

    #[command(subcommand)]
    cmd: Cmd,
}

#[derive(Subcommand)]
enum Cmd {
    /// Знайти і додати пакет за приблизною назвою.
    Add { query: String },
    /// Прибрати пакет.
    Rm { attr: String },
    /// Лише пошук, без змін.
    Search { query: String },
    /// Що зараз керується інструментом.
    List,
    /// Повернути попередню версію файлу з .bak.
    Rollback,
    /// Показати куровану таблицю модульних пакетів.
    Modules,
}

fn choose(cands: &[search::Candidate]) -> Result<usize> {
    let items: Vec<String> = cands
        .iter()
        .map(|c| {
            format!(
                "{:<28} {:<12} {}",
                c.attr,
                c.version.chars().take(12).collect::<String>(),
                c.description.chars().take(60).collect::<String>()
            )
        })
        .collect();

    Ok(Select::new()
        .with_prompt("Який саме пакет")
        .items(&items)
        .default(0)
        .interact()?)
}

fn cmd_add(cli: &Cli, query: &str) -> Result<()> {
    // 1. Резолвінг імені.
    let cands = search::search("nixpkgs", query, 15)?;
    let idx = if cands.len() == 1 { 0 } else { choose(&cands)? };
    let chosen = &cands[idx];
    println!("→ обрано: {} ({})", chosen.attr, chosen.version);

    // 2. Метадані: unfree / broken / бібліотека.
    let m = meta::eval_meta("nixpkgs", &chosen.attr)?;
    if m.broken {
        bail!(
            "{} позначений як broken — збірка майже напевно провалиться",
            chosen.attr
        );
    }
    if m.insecure {
        eprintln!(
            "⚠ {} має відомі вразливості; знадобиться permittedInsecurePackages",
            chosen.attr
        );
    }
    if m.unfree {
        println!(
            "⚠ {} — unfree ({}).",
            chosen.attr,
            m.license_names.join(", ")
        );
        println!("  Глобальний allowUnfree у конфігу вже увімкнено (потрібен для NVIDIA),");
        println!("  тому окремий дозвіл не потрібен. Якщо перейдеш на строгий режим —");
        println!(
            "  додай «{}» у allowUnfreePredicate у managed-packages.nix.",
            chosen.pname
        );
    }
    if m.main_program.is_none() {
        eprintln!(
            "⚠ у {} немає meta.mainProgram — можливо, це бібліотека, а не програма",
            chosen.attr
        );
    }

    // 3. Модуль чи systemPackages?
    let mut mf = edit::ManagedFile::open(&cli.managed)?;
    mf.backup()?;

    match curated::lookup(&chosen.attr)? {
        Some(entry) => {
            println!("→ це модульний пакет: вмикаю {}", entry.option);
            println!("  причина: {}", entry.why);
            mf.enable_option(&entry.option)?;
        }
        None => {
            mf.add_package(&chosen.attr)?;
            println!("→ додано в environment.systemPackages");
        }
    }

    mf.save()?;

    // 4. Перебудова з відкатом файлу при невдачі.
    if cli.no_rebuild {
        println!("(--no-rebuild) файл змінено, rebuild не запускався");
        return Ok(());
    }

    rebuild::apply_or_revert(
        &cli.managed,
        &rebuild::Rebuild {
            flake: &cli.flake,
            host: &cli.host,
            action: &cli.action,
        },
    )
}

fn main() -> Result<()> {
    let cli = Cli::parse();

    match &cli.cmd {
        Cmd::Search { query } => {
            for c in search::search("nixpkgs", query, 20)? {
                println!("{:<30} {:<14} {}", c.attr, c.version, c.description);
            }
        }

        Cmd::Add { query } => cmd_add(&cli, query)?,

        Cmd::Rm { attr } => {
            let mut mf = edit::ManagedFile::open(&cli.managed)?;
            mf.backup()?;
            mf.remove_package(attr)?;
            mf.save()?;
            if !cli.no_rebuild {
                rebuild::apply_or_revert(
                    &cli.managed,
                    &rebuild::Rebuild {
                        flake: &cli.flake,
                        host: &cli.host,
                        action: &cli.action,
                    },
                )?;
            }
        }

        Cmd::List => {
            let mf = edit::ManagedFile::open(&cli.managed)?;
            for p in mf.packages() {
                println!("{p}");
            }
        }

        Cmd::Rollback => {
            edit::ManagedFile::restore(&cli.managed)?;
            println!("файл відкочено з .bak");
        }

        Cmd::Modules => {
            for e in curated::all()? {
                println!("{:<20} → {:<38} {}", e.attr, e.option, e.why);
            }
        }
    }

    Ok(())
}

// ── ЩО ЛИШИЛОСЬ ЗРОБИТИ ТОБІ ────────────────────────────────────────────────
// TODO(1): винести модулі в lib.rs, щоб GUI підключав їх як бібліотеку.
// TODO(2): кеш результатів `nix search` (SQLite або просто JSON з TTL) —
//          зараз кожен пошук чекає на nix ~1-3 с.
// TODO(3): helper-бінарник під polkit для запису в /etc і rebuild,
//          щоб GUI не вимагав sudo (модель з nix-software-center).
// TODO(4): підтримка home-manager: другий керований файл для home.packages.
// TODO(5): `nixmgr why <attr>` — показати, хто саме тягне пакет у замикання.
// TODO(6): перевірка, що пакет уже є в системі з іншого джерела
//          (щоб не додавати дубль, який уже приходить з modules/desktop.nix).
