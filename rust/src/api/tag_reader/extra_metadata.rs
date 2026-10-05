#[derive(Clone)]
pub struct AudioExtraItem {
    pub key: String,
    pub value: String,
}

#[derive(Clone)]
pub struct AudioExtraMetadata {
    pub extension: String,
    pub file_size: u64,
    pub channels: Option<u8>,
    pub bit_depth: Option<u8>,
    pub items: Vec<AudioExtraItem>,
    pub replaygain_track_gain: Option<String>,
    pub replaygain_track_peak: Option<String>,
    pub replaygain_album_gain: Option<String>,
    pub replaygain_album_peak: Option<String>,
}

pub(super) fn should_show_recording_date(recording_date: Option<&str>, year: Option<&str>) -> bool {
    match (recording_date, year) {
        (Some(date), Some(year)) => date.trim() != year.trim(),
        (Some(_), None) => true,
        _ => false,
    }
}
