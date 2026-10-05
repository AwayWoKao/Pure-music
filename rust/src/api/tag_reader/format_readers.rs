use std::path::Path;

use dsf_meta::DsfFile;
use id3::TagLike;
use ratag::tag::Basic as RatagBasic;

use super::{
    estimated_bitrate, file_name, join_deduped, read_dff_metadata, read_dsf_audio_properties,
    read_midi_metadata, read_symphonia_metadata, unknown_if_empty, Audio,
};

pub(super) fn read_by_dsf(path: &Path, modified: u64, created: u64) -> Option<Audio> {
    let file = DsfFile::open(path).ok()?;
    let tag = file.id3_tag().as_ref();
    let properties = read_dsf_audio_properties(&file);
    let title = tag
        .and_then(|tag| tag.title().map(str::to_string))
        .or_else(|| file_name(path))?;

    Some(Audio {
        title,
        artist: unknown_if_empty(tag.and_then(|tag| tag.artist().map(str::to_string))),
        album: unknown_if_empty(tag.and_then(|tag| tag.album().map(str::to_string))),
        album_artist: tag.and_then(|tag| tag.album_artist().map(str::to_string)),
        track: tag.and_then(|tag| tag.track()),
        disc: tag.and_then(|tag| tag.disc()),
        duration: properties.duration,
        bitrate: properties.bitrate,
        sample_rate: properties.sample_rate,
        path: path.to_string_lossy().to_string(),
        modified,
        created,
        by: Some("DSF".to_string()),
        size: 0,
        valid: true,
        media_id: None,
    })
}

pub(super) fn read_by_midi(path: &Path, modified: u64, created: u64) -> Option<Audio> {
    let metadata = read_midi_metadata(path)?;
    Some(Audio {
        title: metadata.title.or_else(|| file_name(path))?,
        artist: "UNKNOWN".to_string(),
        album: "UNKNOWN".to_string(),
        album_artist: None,
        track: None,
        disc: None,
        duration: metadata.duration,
        bitrate: estimated_bitrate(path, metadata.duration),
        sample_rate: None,
        path: path.to_string_lossy().to_string(),
        modified,
        created,
        by: Some("midly".to_string()),
        size: 0,
        valid: true,
        media_id: None,
    })
}

pub(super) fn read_by_dff(path: &Path, modified: u64, created: u64) -> Option<Audio> {
    let metadata = read_dff_metadata(path)?;
    Some(Audio {
        title: metadata.title.or_else(|| file_name(path))?,
        artist: unknown_if_empty(metadata.artist),
        album: unknown_if_empty(metadata.album),
        album_artist: metadata.album_artist,
        track: metadata.track,
        disc: metadata.disc,
        duration: metadata.duration,
        bitrate: metadata.bitrate,
        sample_rate: metadata.sample_rate,
        path: path.to_string_lossy().to_string(),
        modified,
        created,
        by: Some("DFF".to_string()),
        size: 0,
        valid: true,
        media_id: None,
    })
}

pub(super) fn read_by_symphonia(path: &Path, modified: u64, created: u64) -> Option<Audio> {
    let metadata = read_symphonia_metadata(path)?;
    let title = metadata.title.or_else(|| file_name(path))?;

    Some(Audio {
        title,
        artist: metadata.artist.unwrap_or_else(|| "UNKNOWN".to_string()),
        album: metadata.album.unwrap_or_else(|| "UNKNOWN".to_string()),
        album_artist: metadata.album_artist,
        track: metadata.track,
        disc: metadata.disc,
        duration: metadata.duration,
        bitrate: metadata.bitrate,
        sample_rate: metadata.sample_rate,
        path: path.to_string_lossy().to_string(),
        modified,
        created,
        by: Some("Symphonia".to_string()),
        size: 0,
        valid: true,
        media_id: None,
    })
}

pub(super) fn read_by_id3(path: &Path, modified: u64, created: u64) -> Option<Audio> {
    let tag = id3::Tag::read_from_path(path).ok()?;
    let windows = Audio::read_by_win_music_properties(path, modified, created).ok();
    Some(Audio {
        title: tag
            .title()
            .map(str::to_string)
            .or_else(|| windows.as_ref().map(|value| value.title.clone()))
            .or_else(|| file_name(path))?,
        artist: unknown_if_empty(
            tag.artist()
                .map(str::to_string)
                .or_else(|| windows.as_ref().map(|value| value.artist.clone())),
        ),
        album: unknown_if_empty(
            tag.album()
                .map(str::to_string)
                .or_else(|| windows.as_ref().map(|value| value.album.clone())),
        ),
        album_artist: tag.album_artist().map(str::to_string),
        track: tag.track(),
        disc: tag.disc(),
        duration: windows.as_ref().map(|value| value.duration).unwrap_or(0),
        bitrate: windows.as_ref().and_then(|value| value.bitrate),
        sample_rate: windows.as_ref().and_then(|value| value.sample_rate),
        path: path.to_string_lossy().to_string(),
        modified,
        created,
        by: Some("ID3".to_string()),
        size: 0,
        valid: true,
        media_id: None,
    })
}

pub(super) fn read_by_asf(path: &Path, modified: u64, created: u64) -> Option<Audio> {
    let metadata = RatagBasic::from_file(path).ok()?;
    let windows = Audio::read_by_win_music_properties(path, modified, created).ok();
    let artist = join_deduped(metadata.artists.iter().map(String::as_str));
    Some(Audio {
        title: metadata
            .title
            .or_else(|| windows.as_ref().map(|value| value.title.clone()))
            .or_else(|| file_name(path))?,
        artist: unknown_if_empty((!artist.is_empty()).then_some(artist)),
        album: unknown_if_empty(
            metadata
                .album
                .or_else(|| windows.as_ref().map(|value| value.album.clone())),
        ),
        album_artist: metadata.album_artist,
        track: metadata.track,
        disc: metadata.disc,
        duration: metadata
            .length
            .map(|value| value.as_secs())
            .or_else(|| windows.as_ref().map(|value| value.duration))
            .unwrap_or(0),
        bitrate: windows.as_ref().and_then(|value| value.bitrate),
        sample_rate: windows.as_ref().and_then(|value| value.sample_rate),
        path: path.to_string_lossy().to_string(),
        modified,
        created,
        by: Some("ratag".to_string()),
        size: 0,
        valid: true,
        media_id: None,
    })
}

#[cfg(test)]
mod tests {
    use id3::TagLike;

    use super::{read_by_dff, read_by_dsf, read_by_id3, read_by_midi, read_by_symphonia};

    #[test]
    fn invalid_dsf_input_returns_none() {
        let path = std::env::temp_dir().join(format!(
            "pure_music_invalid_dsf_{}_{}.dsf",
            std::process::id(),
            std::time::SystemTime::now()
                .duration_since(std::time::UNIX_EPOCH)
                .unwrap()
                .as_nanos()
        ));
        std::fs::write(&path, b"not a dsf").unwrap();

        assert!(read_by_dsf(&path, 0, 0).is_none());

        std::fs::remove_file(path).unwrap();
    }

    #[test]
    fn valid_midi_input_builds_audio_metadata() {
        let path = std::env::temp_dir().join(format!(
            "pure_music_valid_midi_{}_{}.mid",
            std::process::id(),
            std::time::SystemTime::now()
                .duration_since(std::time::UNIX_EPOCH)
                .unwrap()
                .as_nanos()
        ));
        let bytes = [
            0x4d, 0x54, 0x68, 0x64, 0x00, 0x00, 0x00, 0x06, 0x00, 0x02, 0x00, 0x02, 0x01, 0xe0,
            0x4d, 0x54, 0x72, 0x6b, 0x00, 0x00, 0x00, 0x0c, 0x00, 0xff, 0x03, 0x03, 0x4f, 0x6e,
            0x65, 0x83, 0x60, 0xff, 0x2f, 0x00, 0x4d, 0x54, 0x72, 0x6b, 0x00, 0x00, 0x00, 0x0c,
            0x00, 0xff, 0x03, 0x03, 0x54, 0x77, 0x6f, 0x83, 0x60, 0xff, 0x2f, 0x00,
        ];
        std::fs::write(&path, bytes).unwrap();

        let audio = read_by_midi(&path, 11, 22).expect("valid MIDI metadata");

        assert_eq!(audio.title, "One");
        assert_eq!(audio.duration, 1);
        assert_eq!(audio.modified, 11);
        assert_eq!(audio.created, 22);
        assert_eq!(audio.by.as_deref(), Some("midly"));

        std::fs::remove_file(path).unwrap();
    }

    #[test]
    fn invalid_dff_input_returns_none_from_audio_reader() {
        let path = std::env::temp_dir().join(format!(
            "pure_music_invalid_dff_audio_{}_{}.dff",
            std::process::id(),
            std::time::SystemTime::now()
                .duration_since(std::time::UNIX_EPOCH)
                .unwrap()
                .as_nanos()
        ));
        std::fs::write(&path, b"not a dff").unwrap();

        assert!(read_by_dff(&path, 0, 0).is_none());

        std::fs::remove_file(path).unwrap();
    }

    #[test]
    fn invalid_symphonia_input_returns_none_from_audio_reader() {
        let path = std::env::temp_dir().join(format!(
            "pure_music_invalid_symphonia_audio_{}_{}.flac",
            std::process::id(),
            std::time::SystemTime::now()
                .duration_since(std::time::UNIX_EPOCH)
                .unwrap()
                .as_nanos()
        ));
        std::fs::write(&path, b"not an audio stream").unwrap();

        assert!(read_by_symphonia(&path, 0, 0).is_none());

        std::fs::remove_file(path).unwrap();
    }

    #[test]
    fn valid_id3_input_builds_audio_metadata() {
        let path = std::env::temp_dir().join(format!(
            "pure_music_valid_id3_{}_{}.mp3",
            std::process::id(),
            std::time::SystemTime::now()
                .duration_since(std::time::UNIX_EPOCH)
                .unwrap()
                .as_nanos()
        ));
        let mut tag = id3::Tag::new();
        tag.set_title("ID3 title");
        tag.set_artist("ID3 artist");
        tag.set_album("ID3 album");
        tag.set_track(4);
        std::fs::write(&path, []).unwrap();
        tag.write_to_path(&path, id3::Version::Id3v24).unwrap();

        let audio = read_by_id3(&path, 33, 44).expect("valid ID3 metadata");

        assert_eq!(audio.title, "ID3 title");
        assert_eq!(audio.artist, "ID3 artist");
        assert_eq!(audio.album, "ID3 album");
        assert_eq!(audio.track, Some(4));
        assert_eq!(audio.modified, 33);
        assert_eq!(audio.created, 44);
        assert_eq!(audio.by.as_deref(), Some("ID3"));

        std::fs::remove_file(path).unwrap();
    }
}
