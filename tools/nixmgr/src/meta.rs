//! Визначення властивостей пакета через `nix eval`.
//!
//! ЧОМУ `nix eval`, А НЕ `nix search`:
//! search повертає лише pname/version/description. Поля meta.unfree,
//! meta.license, meta.broken там немає — а саме вони вирішують, чи
//! знадобиться дозвіл на unfree і чи взагалі пакет збереться.
//!
//! ⚠ ВАЖЛИВО: обчислення meta для unfree-пакета САМЕ ПО СОБІ вимагає
//! дозволу — інакше nix кине помилку ще до того, як віддасть атрибут.
//! Тому передаємо NIXPKGS_ALLOW_UNFREE=1 разом з --impure.
//! Це БЕЗПЕЧНО: ми лише читаємо метадані, нічого не збираємо.

use anyhow::{Context, Result};
use serde::Deserialize;
use std::process::Command;

#[derive(Debug, Clone, Deserialize)]
pub struct Meta {
    #[serde(default)]
    pub unfree: bool,
    #[serde(default)]
    pub broken: bool,
    #[serde(default)]
    pub insecure: bool,
    #[serde(default)]
    // description дублює те, що вже показав search — лишається для GUI.
    #[allow(dead_code)]
    pub description: String,
    #[serde(default)]
    pub license_names: Vec<String>,
    /// Чи є в пакета бінарники (main program). Якщо ні — це, ймовірно,
    /// бібліотека, і класти її в systemPackages немає сенсу.
    #[serde(default)]
    pub main_program: Option<String>,
}

pub fn eval_meta(flake: &str, attr: &str) -> Result<Meta> {
    // Вираз навмисно терпимий: у частини пакетів meta.license — рядок,
    // у частини — атрибут, у частини — список. Зводимо все до списку імен.
    let expr = format!(
        r#"
        let
          pkgs = (builtins.getFlake "{flake}").legacyPackages.${{builtins.currentSystem}};
          p = pkgs.{attr};
          m = p.meta or {{}};
          licenses =
            let l = m.license or [];
            in if builtins.isList l
               then map (x: x.shortName or x.spdxId or (toString x)) l
               else [ (l.shortName or l.spdxId or (toString l)) ];
        in {{
          unfree       = m.unfree or false;
          broken       = m.broken or false;
          insecure     = m.knownVulnerabilities or [] != [];
          description  = m.description or "";
          license_names = licenses;
          main_program = m.mainProgram or null;
        }}
        "#
    );

    let out = Command::new("nix")
        .args([
            "--extra-experimental-features",
            "nix-command flakes",
            "eval",
            "--impure",
            "--json",
            "--expr",
            &expr,
        ])
        // Без цього обчислення meta unfree-пакета впаде ще до нашого коду.
        .env("NIXPKGS_ALLOW_UNFREE", "1")
        .env("NIXPKGS_ALLOW_BROKEN", "1")
        .output()
        .context("не вдалось запустити `nix eval`")?;

    if !out.status.success() {
        anyhow::bail!(
            "nix eval для «{attr}» не вдався: {}",
            String::from_utf8_lossy(&out.stderr).trim()
        );
    }

    serde_json::from_slice(&out.stdout).context("не розібрався JSON від nix eval")
}
