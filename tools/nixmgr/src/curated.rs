//! Курована таблиця «пакет → опція модуля».
//! Вбудовується в бінарник на етапі компіляції: інструмент має працювати
//! навіть якщо конфіг ще не зібрався.

use anyhow::Result;
use serde::Deserialize;

#[derive(Debug, Deserialize)]
struct Table {
    entry: Vec<Entry>,
}

#[derive(Debug, Clone, Deserialize)]
pub struct Entry {
    pub attr: String,
    pub option: String,
    pub why: String,
}

const TABLE_SRC: &str = include_str!("../data/module-packages.toml");

pub fn lookup(attr: &str) -> Result<Option<Entry>> {
    let t: Table = toml::from_str(TABLE_SRC)?;
    Ok(t.entry.into_iter().find(|e| e.attr == attr))
}

pub fn all() -> Result<Vec<Entry>> {
    Ok(toml::from_str::<Table>(TABLE_SRC)?.entry)
}
