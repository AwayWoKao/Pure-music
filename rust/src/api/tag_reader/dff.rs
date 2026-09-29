use std::path::Path;

use id3::TagLike;
use ndsd_read::{dff_reader::DFFReader, DSDFormat, DSDReader};

use super::{estimated_bitrate, optional_nonempty, read_id3_from_bytes};

#[derive(Clone)]
pub(super) struct DffMetadata {
    pub(super) title: Option<String>,
    pub(super) artist: Option<String>,
    pub(super) album: Option<String>,
    pub(super) album_artist: Option<String>,
    pub(super) track: Option<u32>,
    pub(super) disc: Option<u32>,
    pub(super) duration: u64,
    pub(super) bitrate: Option<u32>,
    pub(super) sample_rate: Option<u32>,
    pub(super) channels: Option<u8>,
    pub(super) picture: Option<Vec<u8>>,
    pub(super) items: Vec<(String, String)>,
}

pub(super) fn read_dff_metadata(path: &Path) -> Option<DffMetadata> {
    let path_string = path.to_string_lossy();
    let mut reader = DFFReader::new(&path_string).ok()?;
    let mut format = DSDFormat::default();
    reader.open(&mut format).ok()?;
    let dsd_metadata = reader.get_metadata();
    let id3_tag = dsd_metadata
        .and_then(|metadata| metadata.id3_raw.as_deref())
        .and_then(read_id3_from_bytes);
    let id3_tag = id3_tag.as_ref();
    let duration = if format.sampling_rate == 0 {
        0
    } else {
        format.total_samples.saturating_mul(8) / u64::from(format.sampling_rate)
    };
    let title = id3_tag
        .and_then(|tag| tag.title().map(str::to_string))
        .or_else(|| dsd_metadata.and_then(|metadata| metadata.title.clone()));
    let artist = id3_tag
        .and_then(|tag| tag.artist().map(str::to_string))
        .or_else(|| dsd_metadata.and_then(|metadata| metadata.artist.clone()));
    let album = id3_tag
        .and_then(|tag| tag.album().map(str::to_string))
        .or_else(|| dsd_metadata.and_then(|metadata| metadata.album.clone()));
    let album_artist = id3_tag.and_then(|tag| tag.album_artist().map(str::to_string));
    let picture = id3_tag
        .and_then(|tag| tag.pictures().next().map(|picture| picture.data.clone()))
        .or_else(|| {
            dsd_metadata.and_then(|metadata| {
                metadata
                    .cover_art
                    .first()
                    .map(|picture| picture.data.clone())
            })
        });
    let mut items = Vec::new();
    let mut push_item = |key: &str, value: Option<String>| {
        if let Some(value) = optional_nonempty(value) {
            items.push((key.to_string(), value));
        }
    };
    push_item(
        "year",
        id3_tag
            .and_then(|tag| tag.year())
            .or_else(|| dsd_metadata.and_then(|metadata| metadata.year.map(|year| year as i32)))
            .map(|value| value.to_string()),
    );
    push_item(
        "genre",
        id3_tag
            .and_then(|tag| tag.genre().map(str::to_string))
            .or_else(|| dsd_metadata.and_then(|metadata| metadata.genre.clone())),
    );
    push_item("artist", artist.clone());
    push_item("album_artist", album_artist.clone());
    push_item(
        "track",
        id3_tag
            .and_then(|tag| tag.track())
            .map(|value| value.to_string()),
    );
    push_item(
        "disc",
        id3_tag
            .and_then(|tag| tag.disc())
            .map(|value| value.to_string()),
    );

    Some(DffMetadata {
        title,
        artist,
        album,
        album_artist,
        track: id3_tag.and_then(|tag| tag.track()),
        disc: id3_tag.and_then(|tag| tag.disc()),
        duration,
        bitrate: estimated_bitrate(path, duration),
        sample_rate: (format.sampling_rate > 0).then_some(format.sampling_rate),
        channels: u8::try_from(format.num_channels).ok(),
        picture,
        items,
    })
}

#[cfg(test)]
mod tests {
    use super::read_dff_metadata;

    #[test]
    fn invalid_dff_input_returns_none() {
        let path = std::env::temp_dir().join(format!(
            "pure_music_invalid_dff_{}_{}.dff",
            std::process::id(),
            std::time::SystemTime::now()
                .duration_since(std::time::UNIX_EPOCH)
                .unwrap()
                .as_nanos()
        ));
        std::fs::write(&path, b"not a dff").unwrap();

        assert!(read_dff_metadata(&path).is_none());

        std::fs::remove_file(path).unwrap();
    }
}
