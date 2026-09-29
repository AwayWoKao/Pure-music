use std::path::Path;

pub(super) static SUPPORTED_FORMATS: phf::Set<&'static str> = phf::phf_set! {
    "mp3", "mp2", "mp1", "mpa",
    "ogg", "oga", "opus", "spx",
    "wav", "wave",
    "aif", "aiff", "aifc", "afc",
    "asf", "wma",
    "aac", "adts",
    "m4a", "mp4", "m4b", "m4p", "m4r", "m4v", "3gp", "3g2",
    "mka", "mkv", "webm", "weba",
    "caf",
    "ac3", "a52",
    "amr", "3ga",
    "flac",
    "mpc", "mp+", "mpp",
    "mid", "midi", "kar", "rmi",
    "wv",
    "dsf", "dff",
    "ape",
};

pub(super) fn is_dsf_path(path: &Path) -> bool {
    path.extension()
        .is_some_and(|ext| ext.eq_ignore_ascii_case("dsf"))
}

pub(super) fn is_dff_path(path: &Path) -> bool {
    path.extension()
        .is_some_and(|ext| ext.eq_ignore_ascii_case("dff"))
}

pub(super) fn is_asf_path(path: &Path) -> bool {
    path.extension()
        .is_some_and(|ext| ext.eq_ignore_ascii_case("asf") || ext.eq_ignore_ascii_case("wma"))
}

pub(super) fn is_midi_path(path: &Path) -> bool {
    path.extension().is_some_and(|ext| {
        ext.eq_ignore_ascii_case("mid")
            || ext.eq_ignore_ascii_case("midi")
            || ext.eq_ignore_ascii_case("kar")
            || ext.eq_ignore_ascii_case("rmi")
    })
}

pub(super) fn is_generic_id3_path(path: &Path) -> bool {
    path.extension()
        .and_then(|ext| ext.to_str())
        .map(|ext| ext.to_ascii_lowercase())
        .is_some_and(|ext| matches!(ext.as_str(), "ac3" | "a52" | "amr" | "3ga"))
}

pub(super) fn is_symphonia_path(path: &Path) -> bool {
    matches!(
        path.extension()
            .and_then(|ext| ext.to_str())
            .map(|ext| ext.to_ascii_lowercase())
            .as_deref(),
        Some("mp1")
            | Some("mp2")
            | Some("mpa")
            | Some("ogg")
            | Some("oga")
            | Some("opus")
            | Some("spx")
            | Some("mka")
            | Some("mkv")
            | Some("webm")
            | Some("weba")
            | Some("caf")
            | Some("mp4")
            | Some("m4a")
            | Some("m4b")
            | Some("m4p")
            | Some("m4r")
            | Some("m4v")
            | Some("3gp")
            | Some("3g2")
            | Some("flac")
            | Some("wav")
            | Some("wave")
            | Some("aif")
            | Some("aiff")
            | Some("aifc")
    )
}

pub(super) fn is_supported_audio_path(path: &Path) -> bool {
    let Some(extension) = path.extension() else {
        return false;
    };
    let extension = extension.to_string_lossy().to_ascii_lowercase();
    SUPPORTED_FORMATS.contains(extension.as_str())
}
