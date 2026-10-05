use std::sync::{Once, RwLock};

use flutter_rust_bridge::frb;
use log::{LevelFilter, Log, Metadata, Record};

use crate::frb_generated::StreamSink;

static LOGGER: RwLock<Option<StreamSink<String>>> = RwLock::new(None);
static INSTALL: Once = Once::new();

const ALLOWED_TARGETS: &[&str] = &[
    "smtc", "tag", "library", "font", "theme", "color", "util", "ne",
];

struct DartLogger;

impl Log for DartLogger {
    fn enabled(&self, metadata: &Metadata) -> bool {
        ALLOWED_TARGETS.contains(&metadata.target())
    }

    fn log(&self, record: &Record) {
        if !self.enabled(record.metadata()) {
            return;
        }
        let line = format!(
            "{}|{}|{}",
            record.level(),
            record.target(),
            record.args()
        );
        log_to_dart(line);
    }

    fn flush(&self) {}
}

/// initialize a stream to pass log events to dart/flutter
pub fn init_rust_logger(sink: StreamSink<String>) {
    let mut logger = match LOGGER.write() {
        Ok(val) => val,
        Err(val) => val.into_inner(),
    };
    *logger = Some(sink);
    INSTALL.call_once(|| {
        let _ = log::set_logger(&DartLogger);
        log::set_max_level(LevelFilter::Debug);
    });
}

#[frb(ignore)]
pub fn log_to_dart(msg: String) {
    let logger = match LOGGER.read() {
        Ok(val) => val,
        Err(val) => val.into_inner(),
    };
    if let Some(logger) = logger.as_ref() {
        let _ = logger.add(msg);
    }
}
