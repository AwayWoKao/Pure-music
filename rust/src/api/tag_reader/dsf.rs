#[derive(Clone, Copy)]
pub(super) struct DsfAudioProperties {
    pub(super) duration: u64,
    pub(super) bitrate: Option<u32>,
    pub(super) sample_rate: Option<u32>,
    pub(super) channels: Option<u8>,
    pub(super) bit_depth: Option<u8>,
}
