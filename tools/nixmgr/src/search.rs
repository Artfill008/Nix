//! Резолвінг «приблизна назва → точний атрибут nixpkgs».
//!
//! Механіка: `nix search nixpkgs <запит> --json` повертає об'єкт, де ключ —
//! повний шлях атрибута виду
//!     legacyPackages.x86_64-linux.firefox
//! а значення містить pname / version / description.
//!
//! Далі ми переранжовуємо результати нечітким збігом, бо `nix search`
//! сортує за релевантністю свого власного (доволі грубого) алгоритму
//! і часто ставить `foo-unwrapped` вище за `foo`.

use anyhow::{bail, Context, Result};
use nucleo_matcher::pattern::{CaseMatching, Normalization, Pattern};
use nucleo_matcher::{Config, Matcher};
use serde::Deserialize;
use std::collections::BTreeMap;
use std::process::Command;

#[derive(Debug, Deserialize)]
struct RawHit {
    pname: String,
    version: String,
    description: String,
}

#[derive(Debug, Clone)]
pub struct Candidate {
    /// Атрибут, придатний для запису в конфіг: "firefox", "gnome.geary".
    pub attr: String,
    pub pname: String,
    pub version: String,
    pub description: String,
    pub score: u32,
}

/// Відрізає префікс `legacyPackages.<system>.` від ключа `nix search`.
fn strip_prefix(key: &str) -> String {
    let parts: Vec<&str> = key.split('.').collect();
    if parts.len() > 2 && parts[0] == "legacyPackages" {
        parts[2..].join(".")
    } else {
        key.to_string()
    }
}

pub fn search(flake: &str, query: &str, limit: usize) -> Result<Vec<Candidate>> {
    let out = Command::new("nix")
        .args([
            "--extra-experimental-features",
            "nix-command flakes",
            "search",
            flake,
            query,
            "--json",
        ])
        .output()
        .context("не вдалось запустити `nix search` (nix у PATH?)")?;

    if !out.status.success() {
        bail!(
            "nix search завершився помилкою: {}",
            String::from_utf8_lossy(&out.stderr).trim()
        );
    }

    let raw: BTreeMap<String, RawHit> =
        serde_json::from_slice(&out.stdout).context("не розібрався JSON від nix search")?;

    // Нечітке переранжування.
    let mut matcher = Matcher::new(Config::DEFAULT);
    let pattern = Pattern::parse(query, CaseMatching::Ignore, Normalization::Smart);

    let mut cands: Vec<Candidate> = raw
        .into_iter()
        .map(|(key, hit)| {
            let attr = strip_prefix(&key);
            // Оцінюємо збіг і за атрибутом, і за pname — беремо кращий.
            let s1 = pattern.score(
                nucleo_matcher::Utf32Str::Ascii(attr.as_bytes()),
                &mut matcher,
            );
            let s2 = pattern.score(
                nucleo_matcher::Utf32Str::Ascii(hit.pname.as_bytes()),
                &mut matcher,
            );
            let mut score = s1.max(s2).unwrap_or(0);

            // Ручні поправки, які помітно покращують видачу:
            // точний збіг має вигравати завжди.
            if attr == query || hit.pname == query {
                score += 10_000;
            }
            // `-unwrapped`, `-bin`, `-git` майже ніколи не є тим, чого хоче юзер.
            if attr.ends_with("-unwrapped") || attr.contains(".unwrapped") {
                score = score.saturating_sub(500);
            }
            // Вкладені набори (python3Packages.*, xfce.*) зазвичай не те,
            // що шукають за коротким ім'ям.
            if attr.contains('.') {
                score = score.saturating_sub(200);
            }

            Candidate {
                attr,
                pname: hit.pname,
                version: hit.version,
                description: hit.description,
                score,
            }
        })
        .filter(|c| c.score > 0)
        .collect();

    cands.sort_by(|a, b| b.score.cmp(&a.score));
    cands.truncate(limit);

    if cands.is_empty() {
        bail!("нічого не знайдено за запитом «{query}»");
    }
    Ok(cands)
}
