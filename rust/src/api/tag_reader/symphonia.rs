use std::fs;
use std::path::Path;

use symphonia::core::meta::{MetadataContainer, RawValue, StandardTag, Tag as SymphoniaTag};

use super::{join_deduped, optional_nonempty, parse_alternative_number};

use symphonia::{
    core::{
        codecs::CodecParameters,
        formats::{probe::Hint, Attachment, FormatOptions, TrackType},
        io::MediaSourceStream,
        meta::MetadataOptions,
        units::Timestamp,
    },
    default::get_probe,
};

use super::{estimated_bitrate, is_image_attachment};

pub(super) struct SymphoniaMetadata {
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

#[derive(Default)]
pub struct SymphoniaTagCollection {
    pub title: Option<String>,
    pub artist: Option<String>,
    pub album: Option<String>,
    pub album_artist: Option<String>,
    pub track_number: Option<u32>,
    pub disc_number: Option<u32>,
    pub items: Vec<(String, String)>,
    pub picture: Option<Vec<u8>>,
}

fn symphonia_raw_value(value: &RawValue) -> Option<String> {
    let value = match value {
        RawValue::String(value) => value.to_string(),
        RawValue::StringList(value) => join_deduped(value.iter().map(String::as_str)),
        RawValue::SignedInt(value) => value.to_string(),
        RawValue::UnsignedInt(value) => value.to_string(),
        RawValue::Float(value) => value.to_string(),
        RawValue::Boolean(value) => value.to_string(),
        RawValue::Binary(_) | RawValue::Flag => return None,
        _ => return None,
    };
    optional_nonempty(Some(value))
}

fn symphonia_standard_value(tag: &SymphoniaTag) -> Option<(String, String)> {
    let (key, value) = match tag.std.as_ref()? {
        StandardTag::Album(value) => ("album", value.to_string()),
        StandardTag::AlbumArtist(value) => ("albumartist", value.to_string()),
        StandardTag::Artist(value) => ("artist", value.to_string()),
        StandardTag::Comment(value) => ("comment", value.to_string()),
        StandardTag::Composer(value) => ("composer", value.to_string()),
        StandardTag::Conductor(value) => ("conductor", value.to_string()),
        StandardTag::Copyright(value) => ("copyright", value.to_string()),
        StandardTag::DiscNumber(value) => ("discnumber", value.to_string()),
        StandardTag::DiscTotal(value) => ("disctotal", value.to_string()),
        StandardTag::Encoder(value) => ("encoder", value.to_string()),
        StandardTag::EncoderSettings(value) => ("encodersettings", value.to_string()),
        StandardTag::Genre(value) => ("genre", value.to_string()),
        StandardTag::Label(value) => ("label", value.to_string()),
        StandardTag::Language(value) => ("language", value.to_string()),
        StandardTag::Lyrics(value) => ("lyrics", value.to_string()),
        StandardTag::RecordingDate(value) => ("recordingdate", value.to_string()),
        StandardTag::RecordingYear(value) => ("recordingyear", value.to_string()),
        StandardTag::ReplayGainAlbumGain(value) => ("replaygain_album_gain", value.to_string()),
        StandardTag::ReplayGainAlbumPeak(value) => ("replaygain_album_peak", value.to_string()),
        StandardTag::ReplayGainTrackGain(value) => ("replaygain_track_gain", value.to_string()),
        StandardTag::ReplayGainTrackPeak(value) => ("replaygain_track_peak", value.to_string()),
        StandardTag::TrackNumber(value) => ("tracknumber", value.to_string()),
        StandardTag::TrackTitle(value) => ("title", value.to_string()),
        StandardTag::TrackTotal(value) => ("tracktotal", value.to_string()),
        _ => return None,
    };
    optional_nonempty(Some(value)).map(|value| (key.to_string(), value))
}

fn merge_symphonia_field(field: &mut Option<String>, value: String) {
    if let Some(existing) = field.take() {
        *field = Some(join_deduped([existing.as_str(), value.as_str()]));
    } else {
        *field = Some(value);
    }
}

fn collect_symphonia_tags(container: &MetadataContainer, tags: &mut SymphoniaTagCollection) {
    for tag in &container.tags {
        let (key, value) = if let Some((key, value)) = symphonia_standard_value(tag) {
            (key, value)
        } else {
            let value = match symphonia_raw_value(&tag.raw.value) {
                Some(value) => value,
                None => continue,
            };
            (tag.raw.key.to_ascii_lowercase(), value)
        };
        tags.items.push((key.clone(), value.clone()));
        match key.as_str() {
            "title" | "tracktitle" | "tit2" | "title/trackname" | "©nam" => {
                merge_symphonia_field(&mut tags.title, value)
            }
            "artist" | "trackartist" | "tpe1" | "©art" => {
                merge_symphonia_field(&mut tags.artist, value)
            }
            "album" | "talb" | "©alb" => merge_symphonia_field(&mut tags.album, value),
            "albumartist" | "album artist" | "albumartistname" | "tpe2" | "aart" => {
                merge_symphonia_field(&mut tags.album_artist, value)
            }
            "track" | "tracknumber" | "trck" | "trkn" => {
                tags.track_number = parse_alternative_number(&value);
            }
            "disc" | "discnumber" | "tpos" | "disk" => {
                tags.disc_number = parse_alternative_number(&value);
            }
            _ => {}
        }
    }
    if tags.picture.is_none() {
        tags.picture = container
            .visuals
            .iter()
            .find(|visual| !visual.data.is_empty())
            .map(|visual| visual.data.to_vec());
    }
}

pub(super) fn read_symphonia_metadata(path: &Path) -> Option<SymphoniaMetadata> {
    let source = fs::File::open(path).ok()?;
    let media_source = MediaSourceStream::new(Box::new(source), Default::default());
    let mut hint = Hint::new();
    if let Some(extension) = path.extension().and_then(|ext| ext.to_str()) {
        hint.with_extension(extension);
    }
    let probed = get_probe()
        .probe(
            &hint,
            media_source,
            FormatOptions::default(),
            MetadataOptions::default(),
        )
        .ok()?;
    let mut format = probed;
    let (track_id, duration, sample_rate, channels) = {
        let track = format.default_track(TrackType::Audio)?;
        let audio_params = match track.codec_params.as_ref()? {
            CodecParameters::Audio(params) => params,
            _ => return None,
        };
        let duration = track
            .duration
            .zip(track.time_base)
            .and_then(|(duration, time_base)| {
                time_base
                    .calc_time(Timestamp::from(duration.get() as i64))
                    .map(|time| time.as_secs().max(0) as u64)
            })
            .or_else(|| {
                track
                    .num_frames
                    .zip(track.time_base)
                    .and_then(|(frames, time_base)| {
                        time_base
                            .calc_time(Timestamp::from(frames as i64))
                            .map(|time| time.as_secs().max(0) as u64)
                    })
            })
            .unwrap_or(0);
        (
            track.id,
            duration,
            audio_params.sample_rate,
            audio_params
                .channels
                .as_ref()
                .and_then(|value| u8::try_from(value.count()).ok()),
        )
    };
    let bitrate = estimated_bitrate(path, duration);
    let mut tags = SymphoniaTagCollection::default();

    if let Some(revision) = format.metadata().skip_to_latest() {
        collect_symphonia_tags(&revision.media, &mut tags);
        if let Some(track_metadata) = revision
            .per_track
            .iter()
            .find(|metadata| metadata.track_id == u64::from(track_id))
        {
            let mut track_tags = SymphoniaTagCollection::default();
            collect_symphonia_tags(&track_metadata.metadata, &mut track_tags);
            tags.title = track_tags.title.or(tags.title);
            tags.artist = track_tags.artist.or(tags.artist);
            tags.album = track_tags.album.or(tags.album);
            tags.album_artist = track_tags.album_artist.or(tags.album_artist);
            tags.track_number = track_tags.track_number.or(tags.track_number);
            tags.disc_number = track_tags.disc_number.or(tags.disc_number);
            tags.items.extend(track_tags.items);
            tags.picture = track_tags.picture.or(tags.picture);
        }
    }
    if tags.picture.is_none() {
        tags.picture = format
            .attachments()
            .iter()
            .find_map(|attachment| match attachment {
                Attachment::File(file)
                    if is_image_attachment(&file.name, file.media_type.as_deref()) =>
                {
                    Some(file.data.to_vec())
                }
                _ => None,
            });
    }

    Some(SymphoniaMetadata {
        title: tags.title,
        artist: tags.artist,
        album: tags.album,
        album_artist: tags.album_artist,
        track: tags.track_number,
        disc: tags.disc_number,
        duration,
        bitrate,
        sample_rate,
        channels,
        picture: tags.picture,
        items: tags.items,
    })
}

#[cfg(test)]
mod tests {
    use super::read_symphonia_metadata;

    #[test]
    fn invalid_audio_input_returns_none() {
        let path = std::env::temp_dir().join(format!(
            "pure_music_invalid_symphonia_{}_{}.flac",
            std::process::id(),
            std::time::SystemTime::now()
                .duration_since(std::time::UNIX_EPOCH)
                .unwrap()
                .as_nanos()
        ));
        std::fs::write(&path, b"not an audio stream").unwrap();

        assert!(read_symphonia_metadata(&path).is_none());

        std::fs::remove_file(path).unwrap();
    }
}
