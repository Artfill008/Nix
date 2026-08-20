//! Валідація й кольоровий аналіз завантаженого зображення.
//!
//! Робимо це на ДЕКОДОВАНИХ пікселях, а не на метаданих, бо booru регулярно
//! віддає файли, у яких заявлений розмір не збігається з реальним, і
//! перестиснуті JPEG, які формально 1920x1080, а виглядають як каша.

use anyhow::{bail, Result};
use image::imageops::FilterType;
use image::GenericImageView;
use std::path::Path;

use crate::config::Config;

#[derive(Debug, Clone)]
#[allow(dead_code)] // частина полів існує для діагностичного виводу
pub struct Analysis {
    pub width: u32,
    pub height: u32,
    /// Середня яскравість 0..255 (Rec. 709).
    pub mean_luma: f32,
    /// Середня насиченість HSV 0..255.
    pub mean_saturation: f32,
    /// Частка пікселів, яскравіших за 200 — «засвіченість».
    pub bright_fraction: f32,
    /// Домінантний відтінок у градусах 0..360.
    pub dominant_hue: f32,
    /// Підсумкова оцінка: чим більше, тим бажаніше.
    pub score: f32,
}

/// Переводить RGB у (hue 0..360, sat 0..1, val 0..1).
fn rgb_to_hsv(r: u8, g: u8, b: u8) -> (f32, f32, f32) {
    let (r, g, b) = (r as f32 / 255.0, g as f32 / 255.0, b as f32 / 255.0);
    let max = r.max(g).max(b);
    let min = r.min(g).min(b);
    let d = max - min;

    let h = if d == 0.0 {
        0.0
    } else if max == r {
        60.0 * (((g - b) / d) % 6.0)
    } else if max == g {
        60.0 * (((b - r) / d) + 2.0)
    } else {
        60.0 * (((r - g) / d) + 4.0)
    };
    let h = if h < 0.0 { h + 360.0 } else { h };
    let s = if max == 0.0 { 0.0 } else { d / max };
    (h, s, max)
}

/// Чи потрапляє відтінок у названу «бажану» групу.
fn hue_matches(hue: f32, name: &str) -> bool {
    match name {
        "green" => (75.0..=165.0).contains(&hue),
        "teal" => (150.0..=190.0).contains(&hue),
        "cyan" => (170.0..=200.0).contains(&hue),
        "blue" => (195.0..=255.0).contains(&hue),
        "purple" => (250.0..=300.0).contains(&hue),
        "magenta" => (290.0..=330.0).contains(&hue),
        "red" => !(20.0..=340.0).contains(&hue),
        "orange" => (18.0..=45.0).contains(&hue),
        "yellow" => (45.0..=70.0).contains(&hue),
        _ => false,
    }
}

pub fn analyse(path: &Path, cfg: &Config) -> Result<Analysis> {
    let img = image::open(path)?;
    let (w, h) = img.dimensions();

    if w < cfg.filter.min_width || h < cfg.filter.min_height {
        bail!("замала роздільна здатність: {w}x{h}");
    }

    let aspect = w as f32 / h as f32;
    if (aspect - cfg.filter.target_aspect).abs() > cfg.filter.aspect_tolerance {
        bail!("співвідношення сторін {aspect:.3} поза допуском");
    }

    // Аналізуємо зменшену копію: 160x90 достатньо для статистики,
    // і це в ~150 разів менше роботи, ніж повний кадр.
    let small = img.resize_exact(160, 90, FilterType::Triangle).to_rgb8();

    let mut sum_luma = 0.0f32;
    let mut sum_sat = 0.0f32;
    let mut bright = 0u32;
    // Гістограма відтінків по 36 кошиках (по 10°), зважена насиченістю:
    // сірі пікселі не мають впливати на «домінантний колір».
    let mut hue_hist = [0.0f32; 36];
    let total = (small.width() * small.height()) as f32;

    for px in small.pixels() {
        let [r, g, b] = px.0;
        let luma = 0.2126 * r as f32 + 0.7152 * g as f32 + 0.0722 * b as f32;
        sum_luma += luma;
        if luma > 200.0 {
            bright += 1;
        }
        let (hue, sat, val) = rgb_to_hsv(r, g, b);
        sum_sat += sat * 255.0;
        if sat > 0.15 && val > 0.10 {
            let bin = ((hue / 10.0) as usize).min(35);
            hue_hist[bin] += sat * val;
        }
    }

    let mean_luma = sum_luma / total;
    let mean_saturation = sum_sat / total;
    let bright_fraction = bright as f32 / total;

    let dominant_bin = hue_hist
        .iter()
        .enumerate()
        .max_by(|a, b| a.1.partial_cmp(b.1).unwrap())
        .map(|(i, _)| i)
        .unwrap_or(0);
    let dominant_hue = dominant_bin as f32 * 10.0 + 5.0;

    // ── Жорсткі відсіви ────────────────────────────────────────────────────
    if mean_luma > cfg.filter.max_mean_luma as f32 {
        bail!("надто світле: середня яскравість {mean_luma:.0}");
    }
    if mean_saturation < cfg.filter.min_saturation as f32 {
        bail!("надто бліде: насиченість {mean_saturation:.0}");
    }
    // Навіть темне зображення може мати велику засвічену пляму (небо, спалах),
    // яка зіпсує палітру matugen. 25% — емпіричний поріг.
    if bright_fraction > 0.25 {
        bail!(
            "забагато засвічених ділянок: {:.0}%",
            bright_fraction * 100.0
        );
    }

    // ── М'яка оцінка (для вибору найкращого з кількох валідних) ────────────
    let mut score = 0.0f32;
    // Темніше — краще, але не чорне: оптимум близько 55.
    score += 100.0 - (mean_luma - 55.0).abs();
    // Насиченіше — краще.
    score += mean_saturation * 0.5;
    // Бонус за бажаний відтінок.
    if cfg
        .filter
        .prefer_hues
        .iter()
        .any(|n| hue_matches(dominant_hue, n))
    {
        score += 80.0;
    }
    // Штраф за засвічення.
    score -= bright_fraction * 200.0;

    Ok(Analysis {
        width: w,
        height: h,
        mean_luma,
        mean_saturation,
        bright_fraction,
        dominant_hue,
        score,
    })
}
