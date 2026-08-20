//! Розбір /etc/moewall/config.toml. Файл генерується з Nix
//! (modules/laptop/wallpaper.nix), тому тут — лише дзеркало його структури.

use anyhow::{Context, Result};
use serde::Deserialize;
use std::path::{Path, PathBuf};

#[derive(Debug, Deserialize)]
pub struct Config {
    pub state_dir: PathBuf,
    pub cache_size: usize,
    pub source: Source,
    pub filter: Filter,
    pub apply: Apply,
}

#[derive(Debug, Deserialize)]
pub struct Source {
    /// Наразі підтримується лише "safebooru", але поле лишаємо:
    /// додати gelbooru/danbooru — це нова гілка в source.rs, не новий інструмент.
    pub kind: String,
    pub base_url: String,
    pub tags: Vec<String>,
    pub page_limit: u32,
    pub max_pages: u32,
}

#[derive(Debug, Deserialize)]
pub struct Filter {
    pub target_aspect: f32,
    pub aspect_tolerance: f32,
    pub min_width: u32,
    pub min_height: u32,
    pub min_bytes: u64,
    pub max_bytes: u64,
    /// Середня яскравість 0..255; вище — відкидаємо як «засвічене».
    pub max_mean_luma: u8,
    /// Середня насиченість 0..255; нижче — відкидаємо як «washed out».
    pub min_saturation: u8,
    pub prefer_hues: Vec<String>,
}

#[derive(Debug, Deserialize)]
pub struct Apply {
    // rgb_palette тут для повноти дзеркала конфігу: сам файл пише matugen
    // за своїм шаблоном, moewall лише перезапускає сервіс, який його читає.
    pub matugen_mode: String,
    pub current_link: PathBuf,
    #[allow(dead_code)]
    pub rgb_palette: PathBuf,
}

impl Config {
    pub fn load(path: &Path) -> Result<Self> {
        let text = std::fs::read_to_string(path)
            .with_context(|| format!("не читається конфіг {}", path.display()))?;
        let cfg: Config = toml::from_str(&text)
            .with_context(|| format!("невалідний TOML у {}", path.display()))?;
        Ok(cfg)
    }

    pub fn cache_dir(&self) -> PathBuf {
        self.state_dir.join("cache")
    }
    pub fn index_path(&self) -> PathBuf {
        self.state_dir.join("index.json")
    }
}
