import 'package:pure_music/library/audio_library.dart';
import 'package:pure_music/native/rust/api/tag_reader.dart'
    as rust_tag_reader;

typedef AudioDetailMetadataLoader =
    Future<rust_tag_reader.AudioExtraMetadata> Function(Audio audio);

class AudioDetailMetadataCache {
  AudioDetailMetadataCache({required this.loader, this.maxEntries = 64})
    : assert(maxEntries > 0);

  final AudioDetailMetadataLoader loader;
  final int maxEntries;

  final _completed = <String, rust_tag_reader.AudioExtraMetadata>{};
  final _inFlight = <String, Future<rust_tag_reader.AudioExtraMetadata>>{};
  final _keyVersions = <String, int>{};
  int _epoch = 0;

  Future<rust_tag_reader.AudioExtraMetadata> get(Audio audio) {
    final key = cacheKey(audio);
    final completed = _completed.remove(key);
    if (completed != null) {
      _completed[key] = completed;
      return Future<rust_tag_reader.AudioExtraMetadata>.value(completed);
    }

    final existing = _inFlight[key];
    if (existing != null) return existing;

    final epoch = _epoch;
    final keyVersion = _keyVersions[key] ?? 0;
    late final Future<rust_tag_reader.AudioExtraMetadata> future;
    future = loader(audio).then(
      (metadata) {
        if (identical(_inFlight[key], future)) {
          _inFlight.remove(key);
          if (epoch == _epoch && keyVersion == (_keyVersions[key] ?? 0)) {
            _completed[key] = metadata;
            _trimCompleted();
          }
        }
        return metadata;
      },
      onError: (Object error, StackTrace stackTrace) {
        if (identical(_inFlight[key], future)) {
          _inFlight.remove(key);
        }
        Error.throwWithStackTrace(error, stackTrace);
      },
    );
    _inFlight[key] = future;
    return future;
  }

  void evict(Audio audio) {
    final key = cacheKey(audio);
    _keyVersions[key] = (_keyVersions[key] ?? 0) + 1;
    _completed.remove(key);
    _inFlight.remove(key);
  }

  void clear() {
    _epoch++;
    _completed.clear();
    _inFlight.clear();
  }

  int get entryCount => _completed.length;

  static String cacheKey(Audio audio) => '${audio.path}|${audio.modified}';

  void _trimCompleted() {
    while (_completed.length > maxEntries) {
      _completed.remove(_completed.keys.first);
    }
  }
}

Future<bool> applyAudioDetailMetadataIfMounted({
  required Future<rust_tag_reader.AudioExtraMetadata> future,
  required bool Function() isMounted,
  required void Function(rust_tag_reader.AudioExtraMetadata metadata) apply,
}) async {
  final metadata = await future;
  if (!isMounted()) return false;
  apply(metadata);
  return true;
}
