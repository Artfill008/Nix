//! Редагування modules/managed-packages.nix.
//!
//! ── ЧОМУ НЕ rnix/AST, ЯК У nix-editor ────────────────────────────────────────
//!
//! nix-editor (snowfallorg, він же vlinkz/nix-editor) розбирає файл у AST
//! через rnix і вставляє вузол у потрібне місце. Це правильний підхід, КОЛИ
//! ти редагуєш ЧУЖИЙ файл довільної структури — саме тому nix-software-center
//! ним і користується: він мусить лізти в configuration.nix, який писала людина.
//!
//! У нас ситуація інша: файл managed-packages.nix створюємо МИ, його формат
//! ми контролюємо, і в ньому стоять явні маркери
//!     # ── nixmgr:systemPackages:begin ──
//!     # ── nixmgr:systemPackages:end ──
//! Редагування між маркерами:
//!   • не залежить від версії rnix і від змін граматики Nix;
//!   • не може випадково зачепити нічого поза своїм блоком;
//!   • дає передбачуване форматування без nixpkgs-fmt.
//!
//! ЩО ВАРТО ВЗЯТИ З nix-editor, ЯКЩО КОЛИСЬ ЗНАДОБИТЬСЯ:
//!   • сам крейт `nix-editor` (0.3, MIT) — якщо захочеш редагувати
//!     ще й основний конфіг. Тоді бери його як бібліотеку, а не переписуй.
//!   • ідею `-f` (форматування через nixpkgs-fmt після правки).
//! ЩО БРАТИ НЕ ВАРТО:
//!   • його CLI-інтерфейс: він оперує «шляхом атрибута», а нам потрібні
//!     операції рівня «додай пакет» / «увімкни модуль».
//!
//! ЩО ВАРТО ВЗЯТИ З nix-software-center:
//!   • архітектуру привілеїв: у нього є окремий helper-бінарник (`nsc-helper`),
//!     який виконує запис у /etc і rebuild під polkit. GUI-процес при цьому
//!     лишається непривілейованим. Для GTK4-версії це саме те, що потрібно.
//!   • кеш метаданих у SQLite (він тягне nix-data) — щоб пошук не чекав
//!     на `nix search` щоразу.
//! ЧОГО НЕ ВАРТО:
//!   • його прив'язки до `nix-data` і завантаження індексів з мережі —
//!     для нашої задачі `nix search --json` достатньо і завжди актуальний.

use anyhow::{bail, Context, Result};
use std::path::{Path, PathBuf};

pub struct ManagedFile {
    pub path: PathBuf,
    text: String,
}

const PKG_BEGIN: &str = "# ── nixmgr:systemPackages:begin";
const PKG_END: &str = "# ── nixmgr:systemPackages:end";
const PROG_BEGIN: &str = "# ── nixmgr:programs:begin";
const PROG_END: &str = "# ── nixmgr:programs:end";

impl ManagedFile {
    pub fn open(path: &Path) -> Result<Self> {
        let text = std::fs::read_to_string(path)
            .with_context(|| format!("не читається {}", path.display()))?;
        for marker in [PKG_BEGIN, PKG_END, PROG_BEGIN, PROG_END] {
            if !text.contains(marker) {
                bail!(
                    "у {} немає маркера «{marker}» — файл зіпсований або це не той файл",
                    path.display()
                );
            }
        }
        Ok(Self {
            path: path.to_path_buf(),
            text,
        })
    }

    /// Резервна копія поруч із файлом. Саме її використовує `rollback`.
    pub fn backup(&self) -> Result<PathBuf> {
        let bak = self.path.with_extension("nix.bak");
        std::fs::write(&bak, &self.text)?;
        Ok(bak)
    }

    /// Список пакетів, які зараз у блоці systemPackages.
    pub fn packages(&self) -> Vec<String> {
        let Some(body) = between(&self.text, PKG_BEGIN, PKG_END) else {
            return Vec::new();
        };
        body.lines()
            .map(str::trim)
            .filter(|l| {
                !l.is_empty()
                    && !l.starts_with('#')
                    && !l.starts_with("environment.systemPackages")
                    && *l != "];"
            })
            .map(|s| s.to_string())
            .collect()
    }

    pub fn has_package(&self, attr: &str) -> bool {
        self.packages().iter().any(|p| p == attr)
    }

    pub fn add_package(&mut self, attr: &str) -> Result<()> {
        if self.has_package(attr) {
            bail!("{attr} вже є у списку");
        }
        let mut pkgs = self.packages();
        pkgs.push(attr.to_string());
        pkgs.sort();
        pkgs.dedup();
        self.rewrite_packages(&pkgs)
    }

    pub fn remove_package(&mut self, attr: &str) -> Result<()> {
        let mut pkgs = self.packages();
        let before = pkgs.len();
        pkgs.retain(|p| p != attr);
        if pkgs.len() == before {
            bail!("{attr} немає у списку");
        }
        self.rewrite_packages(&pkgs)
    }

    fn rewrite_packages(&mut self, pkgs: &[String]) -> Result<()> {
        let body = format!(
            "\n  environment.systemPackages = with pkgs; [\n{}\n  ];\n  ",
            pkgs.iter()
                .map(|p| format!("    {p}"))
                .collect::<Vec<_>>()
                .join("\n")
        );
        self.text = replace_between(&self.text, PKG_BEGIN, PKG_END, &body)
            .context("не знайшов блок systemPackages")?;
        Ok(())
    }

    /// Вмикає опцію модуля виду `programs.steam.enable`.
    pub fn enable_option(&mut self, option: &str) -> Result<()> {
        let Some(body) = between(&self.text, PROG_BEGIN, PROG_END) else {
            bail!("не знайшов блок programs");
        };
        // Опція записується як повний шлях — Nix це дозволяє,
        // і так набагато простіше редагувати, ніж вкладені атрибути.
        let line = format!("  {option} = true;");
        if body.contains(&line) {
            bail!("{option} вже увімкнено");
        }

        let mut lines: Vec<String> = body
            .lines()
            .map(str::to_string)
            .filter(|l| {
                let t = l.trim();
                !t.is_empty() && t != "programs = {" && t != "};"
            })
            .collect();
        lines.push(line);
        lines.sort();
        lines.dedup();

        let new_body = format!("\n{}\n  ", lines.join("\n"));
        self.text = replace_between(&self.text, PROG_BEGIN, PROG_END, &new_body).unwrap();
        Ok(())
    }

    pub fn save(&self) -> Result<()> {
        // Атомарний запис: інакше перерваний rebuild залишить обрубаний конфіг,
        // і система не зібереться взагалі.
        let tmp = self.path.with_extension("nix.tmp");
        std::fs::write(&tmp, &self.text)?;
        std::fs::rename(&tmp, &self.path)?;
        Ok(())
    }

    pub fn restore(path: &Path) -> Result<()> {
        let bak = path.with_extension("nix.bak");
        if !bak.exists() {
            bail!("резервної копії {} немає", bak.display());
        }
        std::fs::copy(&bak, path)?;
        Ok(())
    }
}

fn between<'a>(text: &'a str, begin: &str, end: &str) -> Option<&'a str> {
    let b = text.find(begin)?;
    let bl = text[b..].find('\n')? + b + 1;
    let e = text[bl..].find(end)? + bl;
    Some(&text[bl..e])
}

fn replace_between(text: &str, begin: &str, end: &str, body: &str) -> Option<String> {
    let b = text.find(begin)?;
    let bl = text[b..].find('\n')? + b + 1;
    let e = text[bl..].find(end)? + bl;
    Some(format!("{}{}{}", &text[..bl], body, &text[e..]))
}
