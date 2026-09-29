use std::collections::HashMap;
use std::path::PathBuf;

use rusqlite::{params, TransactionBehavior};

use super::PlayCountEntry;
use super::{init_schema, normalize_identity_part, open_connection, path_lookup_key};

pub fn increment_play_count(index_path: String, path: String) -> Result<(), String> {
    let index_dir = PathBuf::from(index_path);
    let conn = open_connection(&index_dir).map_err(|e| e.to_string())?;
    init_schema(&conn).map_err(|e| e.to_string())?;
    let affected = conn
        .execute(
            "UPDATE audios SET play_count = play_count + 1 WHERE path = ?1",
            params![path],
        )
        .map_err(|e| e.to_string())?;
    if affected == 0 {
        return Err("audio not found in library".to_string());
    }
    Ok(())
}

pub fn get_top_played(index_path: String, limit: i32) -> Result<Vec<PlayCountEntry>, String> {
    let index_dir = PathBuf::from(index_path);
    let conn = open_connection(&index_dir).map_err(|e| e.to_string())?;
    init_schema(&conn).map_err(|e| e.to_string())?;
    let mut stmt = conn
        .prepare(
            "SELECT path, title, artist, album, play_count FROM audios WHERE play_count > 0 ORDER BY play_count DESC, path ASC LIMIT ?1",
        )
        .map_err(|e| e.to_string())?;
    let rows = stmt
        .query_map(params![limit], |row| {
            Ok(PlayCountEntry {
                path: row.get(0)?,
                title: row.get(1)?,
                artist: row.get(2)?,
                album: row.get(3)?,
                play_count: row.get(4)?,
            })
        })
        .map_err(|e| e.to_string())?;
    let mut result = Vec::new();
    for row in rows {
        result.push(row.map_err(|e| e.to_string())?);
    }
    Ok(result)
}

pub fn get_play_count(index_path: String, path: String) -> Result<i64, String> {
    let index_dir = PathBuf::from(index_path);
    let conn = open_connection(&index_dir).map_err(|e| e.to_string())?;
    init_schema(&conn).map_err(|e| e.to_string())?;
    let count: i64 = conn
        .query_row(
            "SELECT COALESCE(play_count, 0) FROM audios WHERE path = ?1",
            params![path],
            |row| row.get(0),
        )
        .map_err(|e| e.to_string())?;
    Ok(count)
}

pub fn export_play_counts(index_path: String) -> Result<Vec<PlayCountEntry>, String> {
    let index_dir = PathBuf::from(index_path);
    let conn = open_connection(&index_dir).map_err(|e| e.to_string())?;
    init_schema(&conn).map_err(|e| e.to_string())?;
    let mut stmt = conn
        .prepare("SELECT path, title, artist, album, play_count FROM audios WHERE play_count > 0")
        .map_err(|e| e.to_string())?;
    let rows = stmt
        .query_map(params![], |row| {
            Ok(PlayCountEntry {
                path: row.get(0)?,
                title: row.get(1)?,
                artist: row.get(2)?,
                album: row.get(3)?,
                play_count: row.get(4)?,
            })
        })
        .map_err(|e| e.to_string())?;
    let mut result = Vec::new();
    for row in rows {
        result.push(row.map_err(|e| e.to_string())?);
    }
    Ok(result)
}

fn play_count_metadata_key(title: &str, artist: &str, album: &str) -> Option<String> {
    let title = normalize_identity_part(title);
    let artist = normalize_identity_part(artist);
    let album = normalize_identity_part(album);
    if title.is_empty() && artist.is_empty() && album.is_empty() {
        return None;
    }
    Some(format!("{title}\u{1f}{artist}\u{1f}{album}"))
}

/// 按路径或唯一的标题、艺术家、专辑组合写回播放次数；不新建曲库行。
/// `overwrite` 为 false 时取本机与传入值的较大值，为 true 时直接使用传入值。
pub fn import_play_counts(
    index_path: String,
    entries: Vec<PlayCountEntry>,
    overwrite: bool,
) -> Result<u32, String> {
    let index_dir = PathBuf::from(index_path);
    let mut conn = open_connection(&index_dir).map_err(|e| e.to_string())?;
    init_schema(&conn).map_err(|e| e.to_string())?;
    let tx = conn
        .transaction_with_behavior(TransactionBehavior::Immediate)
        .map_err(|e| e.to_string())?;
    if overwrite {
        tx.execute("UPDATE audios SET play_count = 0", [])
            .map_err(|e| e.to_string())?;
    }

    let mut paths_by_key = HashMap::<String, Vec<String>>::new();
    let mut paths_by_metadata = HashMap::<String, Vec<String>>::new();
    {
        let mut stmt = tx
            .prepare("SELECT path, title, artist, album FROM audios")
            .map_err(|e| e.to_string())?;
        let rows = stmt
            .query_map([], |row| {
                Ok((
                    row.get::<_, String>(0)?,
                    row.get::<_, String>(1)?,
                    row.get::<_, String>(2)?,
                    row.get::<_, String>(3)?,
                ))
            })
            .map_err(|e| e.to_string())?;
        for row in rows {
            let (path, title, artist, album) = row.map_err(|e| e.to_string())?;
            paths_by_key
                .entry(path_lookup_key(&path))
                .or_default()
                .push(path.clone());
            if let Some(key) = play_count_metadata_key(&title, &artist, &album) {
                paths_by_metadata.entry(key).or_default().push(path);
            }
        }
    }

    let mut imported = 0u32;
    for entry in entries {
        let play_count = entry.play_count.max(0);
        let target_path = paths_by_key
            .get(&path_lookup_key(&entry.path))
            .filter(|paths| paths.len() == 1)
            .and_then(|paths| paths.first())
            .cloned()
            .or_else(|| {
                play_count_metadata_key(&entry.title, &entry.artist, &entry.album)
                    .and_then(|key| paths_by_metadata.get(&key))
                    .filter(|paths| paths.len() == 1)
                    .and_then(|paths| paths.first())
                    .cloned()
            });
        let Some(target_path) = target_path else {
            continue;
        };
        let sql = if overwrite {
            "UPDATE audios SET play_count = ?1 WHERE path = ?2"
        } else {
            "UPDATE audios SET play_count = MAX(play_count, ?1) WHERE path = ?2"
        };
        let affected = tx
            .execute(sql, params![play_count, target_path])
            .map_err(|e| e.to_string())?;
        if affected > 0 {
            imported += 1;
        }
    }
    tx.commit().map_err(|e| e.to_string())?;
    Ok(imported)
}
