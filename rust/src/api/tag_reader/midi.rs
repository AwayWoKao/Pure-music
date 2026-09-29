use std::fs;
use std::path::Path;

use midly::{Format as MidiFormat, MetaMessage, Smf, Timing, TrackEventKind};

use super::optional_nonempty;

#[derive(Clone)]
pub(super) struct MidiMetadata {
    pub(super) title: Option<String>,
    pub(super) duration: u64,
    pub(super) items: Vec<(String, String)>,
}

fn midi_text(value: &[u8]) -> Option<String> {
    optional_nonempty(Some(String::from_utf8_lossy(value).trim().to_string()))
}

fn midi_track_info(track: &[midly::TrackEvent<'_>]) -> (u64, Vec<(u64, u32)>, Vec<String>) {
    let mut ticks = 0_u64;
    let mut tempos = Vec::new();
    let mut names = Vec::new();
    for event in track {
        ticks = ticks.saturating_add(u64::from(event.delta.as_int()));
        if let TrackEventKind::Meta(meta) = event.kind {
            match meta {
                MetaMessage::Tempo(value) => tempos.push((ticks, value.as_int())),
                MetaMessage::TrackName(value) => {
                    if let Some(value) = midi_text(value) {
                        names.push(value);
                    }
                }
                _ => {}
            }
        }
    }
    (ticks, tempos, names)
}

fn midi_metrical_micros(ticks: u64, mut tempos: Vec<(u64, u32)>, ticks_per_beat: u32) -> u128 {
    if ticks == 0 || ticks_per_beat == 0 {
        return 0;
    }
    tempos.sort_unstable_by_key(|(tick, _)| *tick);
    let mut elapsed_micros = 0_u128;
    let mut previous_tick = 0_u64;
    let mut tempo = 500_000_u32;
    for (tempo_tick, next_tempo) in tempos {
        if tempo_tick > ticks {
            break;
        }
        elapsed_micros = elapsed_micros.saturating_add(
            u128::from(tempo_tick.saturating_sub(previous_tick)) * u128::from(tempo)
                / u128::from(ticks_per_beat),
        );
        previous_tick = tempo_tick;
        tempo = next_tempo.max(1);
    }
    elapsed_micros = elapsed_micros.saturating_add(
        u128::from(ticks.saturating_sub(previous_tick)) * u128::from(tempo)
            / u128::from(ticks_per_beat),
    );
    elapsed_micros
}

fn midi_track_micros(ticks: u64, tempos: Vec<(u64, u32)>, timing: Timing) -> u128 {
    match timing {
        Timing::Metrical(ticks_per_beat) => {
            midi_metrical_micros(ticks, tempos, u32::from(ticks_per_beat.as_int()))
        }
        Timing::Timecode(fps, ticks_per_frame) => {
            if ticks_per_frame == 0 {
                0
            } else {
                (ticks as f64 * 1_000_000.0
                    / (f64::from(fps.as_f32()) * f64::from(ticks_per_frame)))
                    as u128
            }
        }
    }
}

pub(super) fn read_midi_metadata(path: &Path) -> Option<MidiMetadata> {
    let bytes = fs::read(path).ok()?;
    parse_midi_metadata(&bytes)
}

fn midi_payload(bytes: &[u8]) -> Option<&[u8]> {
    if bytes.starts_with(b"MThd") {
        return Some(bytes);
    }
    if bytes.len() < 12 || !bytes.starts_with(b"RIFF") || &bytes[8..12] != b"RMID" {
        return None;
    }
    let riff_size = u32::from_le_bytes(bytes[4..8].try_into().ok()?) as usize;
    let riff_end = 8_usize.checked_add(riff_size)?.min(bytes.len());
    let mut offset = 12_usize;
    while offset.checked_add(8)? <= riff_end {
        let chunk_size =
            u32::from_le_bytes(bytes[offset + 4..offset + 8].try_into().ok()?) as usize;
        let data_start = offset + 8;
        let data_end = data_start.checked_add(chunk_size)?;
        if data_end > riff_end {
            return None;
        }
        if &bytes[offset..offset + 4] == b"data" {
            return Some(&bytes[data_start..data_end]);
        }
        offset = data_end.checked_add(chunk_size & 1)?;
    }
    None
}

pub(super) fn parse_midi_metadata(bytes: &[u8]) -> Option<MidiMetadata> {
    let smf = Smf::parse(midi_payload(bytes)?).ok()?;
    let mut track_info = Vec::with_capacity(smf.tracks.len());
    let mut title = None;
    let mut items = Vec::new();
    for track in &smf.tracks {
        let (ticks, tempos, names) = midi_track_info(track);
        if title.is_none() {
            title = names.first().cloned();
        }
        for name in names {
            items.push(("track_name".to_string(), name));
        }
        for event in track {
            if let TrackEventKind::Meta(meta) = event.kind {
                let (key, value) = match meta {
                    MetaMessage::Copyright(value) => ("copyright", midi_text(value)),
                    MetaMessage::Text(value) => ("text", midi_text(value)),
                    MetaMessage::InstrumentName(value) => ("instrument", midi_text(value)),
                    _ => continue,
                };
                if let Some(value) = value {
                    items.push((key.to_string(), value));
                }
            }
        }
        track_info.push((ticks, tempos));
    }
    let duration_micros = match smf.header.format {
        MidiFormat::Sequential => track_info
            .into_iter()
            .map(|(ticks, tempos)| midi_track_micros(ticks, tempos, smf.header.timing))
            .sum(),
        MidiFormat::SingleTrack | MidiFormat::Parallel => {
            let max_ticks = track_info
                .iter()
                .map(|(ticks, _)| *ticks)
                .max()
                .unwrap_or(0);
            let tempos = track_info
                .into_iter()
                .flat_map(|(_, tempos)| tempos)
                .collect();
            midi_track_micros(max_ticks, tempos, smf.header.timing)
        }
    };
    let duration = u64::try_from(duration_micros / 1_000_000).unwrap_or(u64::MAX);
    Some(MidiMetadata {
        title,
        duration,
        items,
    })
}
