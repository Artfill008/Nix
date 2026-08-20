//! Джерело кандидатів. Наразі Safebooru (DAPI, сумісний з Gelbooru 0.2).
//!
//! ⚠ ЩО ПЕРЕВІРЕНО, А ЩО НІ:
//!   ПЕРЕВІРЕНО (за документацією сайту): endpoint
//!     index.php?page=dapi&s=post&q=index
//!   з параметрами tags / limit (стеля 1000) / pid (номер сторінки) / json=1.
//!   НЕ ПЕРЕВІРЕНО НА ЖИВОМУ API: назви полів відповіді. Мережевий доступ до
//!   safebooru.org був заблокований у середовищі, де писався цей код.
//!   Тому структура нижче ТЕРПИМА до варіантів: приймає і `file_url`,
//!   і пару `directory` + `image`.
//!
//!   Якщо запит повертає порожнечу — перевір руками:
//!     curl -s 'https://safebooru.org/index.php?page=dapi&s=post&q=index&json=1&limit=5&tags=rating:safe+wallpaper+highres'

use anyhow::{bail, Context, Result};
use serde::Deserialize;
use std::time::Duration;

use crate::config::Config;

#[derive(Debug, Clone, Deserialize)]
pub struct Post {
    // id і tags не використовуються в логіці, але лишаються для
    // діагностики: їх видно у --dry-run і в журналі.
    #[allow(dead_code)]
    pub id: Option<u64>,
    pub width: Option<u32>,
    pub height: Option<u32>,

    // Варіант А: пряме посилання.
    pub file_url: Option<String>,

    // Варіант Б: збірка з частин (класичний Gelbooru 0.2).
    pub directory: Option<String>,
    pub image: Option<String>,

    #[allow(dead_code)]
    pub tags: Option<String>,
}

impl Post {
    /// Повний URL зображення або None, якщо відповідь незрозуміла.
    pub fn url(&self, base_host: &str) -> Option<String> {
        if let Some(u) = &self.file_url {
            if u.starts_with("http") {
                return Some(u.clone());
            }
            return Some(format!("{base_host}{u}"));
        }
        match (&self.directory, &self.image) {
            (Some(d), Some(i)) => Some(format!("{base_host}/images/{d}/{i}")),
            _ => None,
        }
    }

    /// Швидкий відсів ще ДО завантаження — по метаданих із API.
    /// Економить трафік: не качаємо те, що все одно відкинемо.
    pub fn metadata_ok(&self, cfg: &Config) -> bool {
        let (Some(w), Some(h)) = (self.width, self.height) else {
            // Немає розмірів — не відкидаємо, перевіримо після завантаження.
            return true;
        };
        if w < cfg.filter.min_width || h < cfg.filter.min_height {
            return false;
        }
        let aspect = w as f32 / h as f32;
        (aspect - cfg.filter.target_aspect).abs() <= cfg.filter.aspect_tolerance
    }
}

pub fn client() -> Result<reqwest::blocking::Client> {
    reqwest::blocking::Client::builder()
        // Booru-сайти блокують запити без осмисленого UA.
        .user_agent("moewall/0.1 (+https://github.com/; personal wallpaper tool)")
        .timeout(Duration::from_secs(30))
        .connect_timeout(Duration::from_secs(10))
        .build()
        .context("не вдалось створити HTTP-клієнт")
}

/// Тягне пости посторінково, поки не набереться `want` кандидатів,
/// що пройшли відсів за метаданими.
pub fn fetch_candidates(
    cfg: &Config,
    client: &reqwest::blocking::Client,
    want: usize,
    skip: &dyn Fn(&Post) -> bool,
) -> Result<Vec<Post>> {
    if cfg.source.kind != "safebooru" {
        bail!("невідомий тип джерела: {}", cfg.source.kind);
    }

    let tags = cfg.source.tags.join(" ");
    let mut out = Vec::new();

    for pid in 0..cfg.source.max_pages {
        let resp = client
            .get(&cfg.source.base_url)
            .query(&[
                ("page", "dapi"),
                ("s", "post"),
                ("q", "index"),
                ("json", "1"),
                ("limit", &cfg.source.page_limit.to_string()),
                ("pid", &pid.to_string()),
                ("tags", &tags),
            ])
            .send()
            .context("запит до джерела провалився")?;

        if !resp.status().is_success() {
            bail!("джерело відповіло {}", resp.status());
        }

        let body = resp.text().context("не читається тіло відповіді")?;

        // Порожня відповідь = сторінок більше немає. Це не помилка.
        let trimmed = body.trim();
        if trimmed.is_empty() || trimmed == "[]" {
            break;
        }

        let posts: Vec<Post> = serde_json::from_str(trimmed).with_context(|| {
            format!(
                "не розібрався JSON відповіді (перші 200 байт: {})",
                &trimmed.chars().take(200).collect::<String>()
            )
        })?;

        if posts.is_empty() {
            break;
        }

        for p in posts {
            if skip(&p) || !p.metadata_ok(cfg) {
                continue;
            }
            out.push(p);
            if out.len() >= want {
                return Ok(out);
            }
        }
    }

    Ok(out)
}
