//! moewall — автоматичні шпалери з фільтрацією за формою і кольором.
//!
//! Конвеєр:
//!   запит → відсів за метаданими → завантаження → перевірка розміру/пропорцій
//!   → кольоровий аналіз (яскравість, насиченість, домінантний відтінок)
//!   → відкидання засвіченого → оцінка → кеш → застосування → matugen
//!   → перезавантаження споживачів (бар, сповіщення, композитор, RGB).
//!
//! Стан (бачені хеші, чорний список, улюблені) — один атомарно записуваний JSON.

mod analyse;
mod apply;
mod config;
mod source;
mod state;

use anyhow::{bail, Context, Result};
use clap::{Parser, Subcommand};
use sha2::{Digest, Sha256};
use std::path::{Path, PathBuf};

use config::Config;
use state::State;

/// Код виходу для «немає мережі» — systemd-юніт трактує його як успіх
/// (SuccessExitStatus=75), щоб не сипати помилками, коли ноут офлайн.
const EX_TEMPFAIL: i32 = 75;

#[derive(Parser)]
#[command(name = "moewall", version, about = "Автоматичні шпалери")]
struct Cli {
    /// Шлях до конфігу (генерується з Nix).
    #[arg(long, default_value = "/etc/moewall/config.toml")]
    config: PathBuf,

    /// Не застосовувати, лише показати, що було б обрано.
    #[arg(long)]
    dry_run: bool,

    #[command(subcommand)]
    cmd: Cmd,
}

#[derive(Subcommand)]
enum Cmd {
    /// Наступна шпалера: з кешу, якщо є придатна; інакше завантажити нову.
    Next,
    /// Примусово завантажити нову партію, ігноруючи кеш.
    Refresh,
    /// Залишити поточну в улюблених (не видаляється при очищенні кешу).
    Keep,
    /// Відхилити поточну назавжди і перейти до наступної.
    Blacklist,
    /// Застосувати конкретний файл.
    Apply { path: PathBuf },
    /// Показати стан.
    Status,
}

fn sha256_file(path: &Path) -> Result<String> {
    let bytes = std::fs::read(path)?;
    let mut h = Sha256::new();
    h.update(&bytes);
    Ok(format!("{:x}", h.finalize()))
}

fn ext_for(url: &str) -> &str {
    let lower = url.to_ascii_lowercase();
    if lower.ends_with(".png") {
        "png"
    } else if lower.ends_with(".webp") {
        "webp"
    } else {
        "jpg"
    }
}

/// Завантажує кандидатів, валідує і кладе найкращого в кеш.
/// Повертає (hash, path).
fn fetch_one(cfg: &Config, st: &mut State) -> Result<(String, PathBuf)> {
    let client = source::client()?;

    let posts = source::fetch_candidates(cfg, &client, 24, &|_p| false)
        .context("не вдалось отримати список постів")?;

    if posts.is_empty() {
        bail!("джерело не повернуло жодного поста — перевір теги в modules/laptop/wallpaper.nix");
    }

    std::fs::create_dir_all(cfg.cache_dir()).ok();

    // Хост для збірки відносних URL.
    let host = cfg
        .source
        .base_url
        .split("/index.php")
        .next()
        .unwrap_or("https://safebooru.org")
        .to_string();

    let mut best: Option<(f32, String, PathBuf)> = None;

    for post in posts {
        let Some(url) = post.url(&host) else { continue };

        let resp = match client.get(&url).send() {
            Ok(r) if r.status().is_success() => r,
            _ => continue,
        };

        // Перевірка розміру ДО читання тіла, якщо сервер сказав Content-Length.
        if let Some(len) = resp.content_length() {
            if len < cfg.filter.min_bytes || len > cfg.filter.max_bytes {
                continue;
            }
        }

        let Ok(bytes) = resp.bytes() else { continue };
        let len = bytes.len() as u64;
        if len < cfg.filter.min_bytes || len > cfg.filter.max_bytes {
            continue;
        }

        let mut hasher = Sha256::new();
        hasher.update(&bytes);
        let hash = format!("{:x}", hasher.finalize());

        // Дедуплікація за вмістом: той самий арт часто лежить під різними id.
        if st.is_rejected(&hash) {
            continue;
        }

        let path = cfg.cache_dir().join(format!("{hash}.{}", ext_for(&url)));
        if std::fs::write(&path, &bytes).is_err() {
            continue;
        }

        match analyse::analyse(&path, cfg) {
            Ok(a) => {
                eprintln!(
                    "  кандидат {hash:.8}: {}x{}, яскравість {:.0}, насиченість {:.0}, \
                     відтінок {:.0}°, оцінка {:.0}",
                    a.width, a.height, a.mean_luma, a.mean_saturation, a.dominant_hue, a.score
                );
                st.seen.insert(hash.clone());
                if best.as_ref().map(|(s, _, _)| a.score > *s).unwrap_or(true) {
                    // Попереднього переможця лишаємо в кеші — він валідний
                    // і згодиться для наступного `next` без мережі.
                    best = Some((a.score, hash.clone(), path.clone()));
                }
                if !st.cache_order.contains(&hash) {
                    st.cache_order.push(hash);
                }
            }
            Err(e) => {
                eprintln!("  відхилено {hash:.8}: {e}");
                // Не тримаємо непридатний файл на диску, але запам'ятовуємо,
                // щоб не качати його знову.
                let _ = std::fs::remove_file(&path);
                st.seen.insert(hash);
            }
        }

        // Достатньо одного добротного кандидата з високою оцінкою.
        if let Some((s, _, _)) = &best {
            if *s > 180.0 {
                break;
            }
        }
    }

    match best {
        Some((_, hash, path)) => Ok((hash, path)),
        None => {
            bail!("жоден кандидат не пройшов фільтри — послаб max_mean_luma або min_saturation")
        }
    }
}

/// Обирає наступну придатну шпалеру з кешу (не поточну, не в чорному списку).
fn pick_from_cache(cfg: &Config, st: &State) -> Option<(String, PathBuf)> {
    st.cache_order
        .iter()
        .rev()
        .filter(|h| !st.blacklist.contains(*h))
        .filter(|h| st.current.as_deref() != Some(h.as_str()))
        .find_map(|h| st.cached_path(&cfg.cache_dir(), h).map(|p| (h.clone(), p)))
}

fn apply_wallpaper(cfg: &Config, st: &mut State, hash: &str, path: &Path, dry: bool) -> Result<()> {
    if dry {
        println!("[dry-run] обрано: {}", path.display());
        return Ok(());
    }

    apply::set_current(cfg, path)?;
    apply::run_matugen(cfg, path)?;

    // swaybg і споживачі — лише якщо ми в графічній сесії.
    if std::env::var_os("WAYLAND_DISPLAY").is_some() {
        apply::restart_swaybg(cfg)?;
        apply::reload_consumers();
    } else {
        eprintln!("WAYLAND_DISPLAY немає — шпалера збережена, але сесія не оновлена");
    }

    st.current = Some(hash.to_string());
    st.evict(&cfg.cache_dir(), cfg.cache_size);
    st.save(&cfg.index_path())?;

    apply::notify(
        "Шпалеру змінено",
        &path.file_name().unwrap().to_string_lossy(),
    );
    Ok(())
}

fn run() -> Result<i32> {
    let cli = Cli::parse();
    let cfg = Config::load(&cli.config)?;
    let mut st = State::load(&cfg.index_path());

    match cli.cmd {
        Cmd::Status => {
            println!("каталог стану : {}", cfg.state_dir.display());
            println!("у кеші        : {}", st.cache_order.len());
            println!("бачених       : {}", st.seen.len());
            println!("улюблених     : {}", st.favourites.len());
            println!("у чорному спис: {}", st.blacklist.len());
            println!("поточна       : {}", st.current.as_deref().unwrap_or("—"));
        }

        Cmd::Apply { path } => {
            let hash = sha256_file(&path)?;
            apply_wallpaper(&cfg, &mut st, &hash, &path, cli.dry_run)?;
        }

        Cmd::Keep => {
            let Some(cur) = st.current.clone() else {
                bail!("поточної шпалери немає");
            };
            st.favourites.insert(cur);
            st.save(&cfg.index_path())?;
            apply::notify("Збережено", "Шпалеру додано в улюблені");
        }

        Cmd::Blacklist => {
            if let Some(cur) = st.current.clone() {
                st.blacklist.insert(cur.clone());
                st.favourites.remove(&cur);
                st.cache_order.retain(|h| h != &cur);
                if let Some(p) = st.cached_path(&cfg.cache_dir(), &cur) {
                    let _ = std::fs::remove_file(p);
                }
                st.current = None;
                st.save(&cfg.index_path())?;
                apply::notify("У чорний список", "Ця шпалера більше не з'явиться");
            }
            // І одразу ставимо наступну.
            return next_wallpaper(&cfg, &mut st, cli.dry_run, false);
        }

        Cmd::Next => return next_wallpaper(&cfg, &mut st, cli.dry_run, false),
        Cmd::Refresh => return next_wallpaper(&cfg, &mut st, cli.dry_run, true),
    }

    Ok(0)
}

fn next_wallpaper(cfg: &Config, st: &mut State, dry: bool, force_fetch: bool) -> Result<i32> {
    if !force_fetch {
        if let Some((hash, path)) = pick_from_cache(cfg, st) {
            apply_wallpaper(cfg, st, &hash, &path, dry)?;
            return Ok(0);
        }
    }

    match fetch_one(cfg, st) {
        Ok((hash, path)) => {
            apply_wallpaper(cfg, st, &hash, &path, dry)?;
            Ok(0)
        }
        Err(e) => {
            // Зберігаємо те, що встигли дізнатись про бачені хеші.
            let _ = st.save(&cfg.index_path());

            // Немає мережі — не помилка, а тимчасова обставина.
            let msg = e.to_string();
            if msg.contains("запит до джерела") || msg.contains("dns") || msg.contains("timed out")
            {
                eprintln!("моewall: мережа недоступна, пропускаю оновлення");
                return Ok(EX_TEMPFAIL);
            }

            // Мережа є, але кандидатів немає — спробуємо кеш як запасний варіант.
            if let Some((hash, path)) = pick_from_cache(cfg, st) {
                eprintln!("moewall: {msg}; беру з кешу");
                apply_wallpaper(cfg, st, &hash, &path, dry)?;
                return Ok(0);
            }
            Err(e)
        }
    }
}

fn main() {
    match run() {
        Ok(code) => std::process::exit(code),
        Err(e) => {
            eprintln!("moewall: помилка: {e:#}");
            std::process::exit(1);
        }
    }
}
