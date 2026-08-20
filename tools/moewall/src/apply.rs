//! Застосування шпалери: swaybg, matugen, перезавантаження споживачів.

use anyhow::{Context, Result};
use std::path::Path;
use std::process::Command;

use crate::config::Config;

/// Атомарно робить `path` поточною шпалерою.
/// Копіюємо, а не символьне посилання: swaybg і regreet читають файл
/// у різний час, і посилання на файл, який може зникнути з кешу, —
/// це гарантований чорний екран на логіні.
pub fn set_current(cfg: &Config, path: &Path) -> Result<()> {
    let target = &cfg.apply.current_link;
    if let Some(dir) = target.parent() {
        std::fs::create_dir_all(dir).ok();
    }
    let tmp = target.with_extension("tmp");
    std::fs::copy(path, &tmp)
        .with_context(|| format!("не копіюється {} → {}", path.display(), tmp.display()))?;
    std::fs::rename(&tmp, target).context("атомарна заміна поточної шпалери провалилась")?;
    Ok(())
}

/// Перезапускає swaybg на новий файл.
/// swaybg не вміє перечитувати файл — його треба перезапустити.
pub fn restart_swaybg(cfg: &Config) -> Result<()> {
    // Старий процес прибираємо м'яко; якщо його немає — це не помилка.
    let _ = Command::new("pkill").args(["-x", "swaybg"]).status();

    Command::new("swaybg")
        .arg("-i")
        .arg(&cfg.apply.current_link)
        .arg("-m")
        .arg("fill")
        .spawn()
        .context("не запустився swaybg")?;
    Ok(())
}

/// Запускає matugen на зображенні. Саме він генерує всі конфіги з шаблонів.
pub fn run_matugen(cfg: &Config, path: &Path) -> Result<()> {
    let status = Command::new("matugen")
        .arg("image")
        .arg(path)
        .arg("--mode")
        .arg(&cfg.apply.matugen_mode)
        .status()
        .context("matugen не запустився (він у PATH?)")?;

    if !status.success() {
        anyhow::bail!("matugen завершився з кодом {status}");
    }
    Ok(())
}

/// Повідомляє споживачів, що кольори змінились.
/// Кожен крок — best-effort: якщо якогось споживача немає, це не привід падати.
pub fn reload_consumers() {
    // mango: гаряче перечитує конфіг разом із source=colors.conf.
    let _ = Command::new("mmsg")
        .args(["dispatch", "reload_config"])
        .status();

    // waybar: SIGUSR2 = повне перезавантаження зі стилями.
    let _ = Command::new("pkill")
        .args(["-SIGUSR2", "-x", "waybar"])
        .status();

    // mako перечитує конфіг за командою.
    let _ = Command::new("makoctl").arg("reload").status();

    // RGB-підсвітка: системний сервіс читає /var/lib/moewall/rgb-colors.sh.
    // Через systemctl, бо сам сервіс має право на USB, а ми — ні.
    let _ = Command::new("systemctl")
        .args(["restart", "--no-block", "gt72s-rgb.service"])
        .status();
}

pub fn notify(summary: &str, body: &str) {
    let _ = Command::new("notify-send")
        .args([
            "-a",
            "moewall",
            "-i",
            "preferences-desktop-wallpaper",
            summary,
            body,
        ])
        .status();
}
