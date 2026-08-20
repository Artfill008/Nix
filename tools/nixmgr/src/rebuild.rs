//! Запуск nixos-rebuild і відкат при невдачі.

use anyhow::{Context, Result};
use std::path::Path;
use std::process::Command;

pub struct Rebuild<'a> {
    pub flake: &'a str,
    pub host: &'a str,
    /// switch — застосувати зараз; test — застосувати без запису в bootloader;
    /// boot — застосувати з наступного завантаження.
    pub action: &'a str,
}

impl Rebuild<'_> {
    pub fn run(&self) -> Result<bool> {
        let target = format!("{}#{}", self.flake, self.host);
        eprintln!("→ nixos-rebuild {} --flake {target}", self.action);

        let status = Command::new("sudo")
            .args(["nixos-rebuild", self.action, "--flake", &target])
            .status()
            .context("не вдалось запустити nixos-rebuild")?;

        Ok(status.success())
    }
}

/// Повний цикл із безпечним відкатом.
///
/// ВАЖЛИВО ПРО СЕМАНТИКУ ВІДКАТУ:
/// ми відкочуємо ФАЙЛ, а не систему. Це навмисно.
/// Якщо `nixos-rebuild switch` провалився на етапі збірки — система взагалі
/// не змінилась, відкочувати нічого. Якщо він провалився на етапі активації —
/// NixOS сам лишається на попередньому поколінні.
/// Єдине, що лишається зіпсованим, — наш файл. Його ми і повертаємо.
pub fn apply_or_revert(managed: &Path, rb: &Rebuild) -> Result<()> {
    if rb.run()? {
        println!("✓ система оновлена");
        // Успіх — знімаємо резервну копію, щоб наступний rollback
        // не повернув застарілий стан.
        let bak = managed.with_extension("nix.bak");
        let _ = std::fs::remove_file(bak);
        Ok(())
    } else {
        eprintln!("✗ збірка провалилась — повертаю {}", managed.display());
        crate::edit::ManagedFile::restore(managed)?;
        eprintln!("  файл відкочено. Система лишилась на попередньому поколінні.");
        anyhow::bail!("rebuild не вдався")
    }
}
