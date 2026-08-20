//! Стан: що вже бачили, що в чорному списку, що в улюблених, що зараз стоїть.
//!
//! Один JSON-файл. Записується АТОМАРНО (у тимчасовий файл + rename),
//! інакше перерваний запис залишить порожній індекс і інструмент
//! почне качати все спочатку.

use anyhow::{Context, Result};
use serde::{Deserialize, Serialize};
use std::collections::BTreeSet;
use std::path::{Path, PathBuf};

#[derive(Debug, Default, Serialize, Deserialize)]
pub struct State {
    /// sha256 усіх зображень, які ми колись завантажували —
    /// щоб не качати те саме вдруге навіть після видалення з кешу.
    pub seen: BTreeSet<String>,
    /// Хеші, які юзер відхилив явно.
    pub blacklist: BTreeSet<String>,
    /// Улюблені — не видаляються при очищенні кешу.
    pub favourites: BTreeSet<String>,
    /// Файли в кеші, у порядку від найстарішого — для LRU-витіснення.
    pub cache_order: Vec<String>,
    /// Хеш поточної шпалери.
    pub current: Option<String>,
}

impl State {
    pub fn load(path: &Path) -> Self {
        std::fs::read_to_string(path)
            .ok()
            .and_then(|t| serde_json::from_str(&t).ok())
            .unwrap_or_default()
    }

    pub fn save(&self, path: &Path) -> Result<()> {
        if let Some(dir) = path.parent() {
            std::fs::create_dir_all(dir).ok();
        }
        let tmp = path.with_extension("json.tmp");
        std::fs::write(&tmp, serde_json::to_vec_pretty(self)?)
            .with_context(|| format!("не пишеться {}", tmp.display()))?;
        std::fs::rename(&tmp, path).context("атомарна заміна індексу провалилась")?;
        Ok(())
    }

    pub fn is_rejected(&self, hash: &str) -> bool {
        self.blacklist.contains(hash) || self.seen.contains(hash)
    }

    /// Витісняє найстаріші файли понад ліміт. Улюблені й поточну не чіпає.
    pub fn evict(&mut self, cache_dir: &Path, limit: usize) {
        while self.cache_order.len() > limit {
            // Знаходимо перший кандидат, який можна видалити.
            let Some(pos) = self.cache_order.iter().position(|h| {
                !self.favourites.contains(h) && self.current.as_deref() != Some(h.as_str())
            }) else {
                break; // усе, що лишилось, — недоторкане
            };
            let hash = self.cache_order.remove(pos);
            for ext in ["png", "jpg", "jpeg", "webp"] {
                let p = cache_dir.join(format!("{hash}.{ext}"));
                if p.exists() {
                    let _ = std::fs::remove_file(p);
                }
            }
        }
    }

    pub fn cached_path(&self, cache_dir: &Path, hash: &str) -> Option<PathBuf> {
        for ext in ["png", "jpg", "jpeg", "webp"] {
            let p = cache_dir.join(format!("{hash}.{ext}"));
            if p.exists() {
                return Some(p);
            }
        }
        None
    }
}
