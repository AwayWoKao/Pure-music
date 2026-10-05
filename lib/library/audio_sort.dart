import 'package:pure_music/core/utils.dart';
import 'package:pure_music/library/audio_library.dart';

/// 与音乐页排序菜单顺序一致：标题 / 艺术家 / 专辑 / 创建时间 / 修改时间 / 时长 / 播放次数。
const int audiosPageSortMethodMax = 6;

String audioDiscTrackSortValue(Audio audio) {
  final disc = audio.disc != null && audio.disc! > 0 ? audio.disc! : 1;
  final track = audio.track > 0 ? audio.track : 9999;
  return '${disc.toString().padLeft(4, '0')}-${track.toString().padLeft(4, '0')}';
}

String audioTitleSortValue(Audio audio) => joinNaturalSortKeys([
  audio.title,
  audio.artist,
  audio.album,
  audioDiscTrackSortValue(audio),
]);

String audioArtistSortValue(Audio audio) => joinNaturalSortKeys([
  audio.artist,
  audio.album,
  audioDiscTrackSortValue(audio),
  audio.title,
]);

String audioAlbumSortValue(Audio audio) => joinNaturalSortKeys([
  audio.album,
  audioDiscTrackSortValue(audio),
  audio.title,
]);
