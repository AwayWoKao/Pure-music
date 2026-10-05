import 'package:pure_music/core/preference.dart';
import 'package:pure_music/core/list_action_state.dart';
import 'package:pure_music/core/utils.dart';
import 'package:pure_music/core/enums.dart';
import 'package:pure_music/core/design_tokens.dart';
import 'package:pure_music/library/audio_library.dart';
import 'package:pure_music/library/audio_sort.dart';
import 'package:pure_music/component/artist_tile.dart';
import 'package:pure_music/component/audio_tile.dart';
import 'package:pure_music/component/quiet_empty_state.dart';
import 'package:pure_music/page/uni_detail_page.dart';
import 'package:pure_music/page/uni_page.dart';
import 'package:pure_music/page/uni_page_components.dart';
import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

int _discNumber(Audio audio) {
  final disc = audio.disc;
  return disc != null && disc > 0 ? disc : 1;
}

String _trackNumber(Audio audio, {bool includeDisc = false}) {
  final track = audio.track < 10 ? '0${audio.track}' : '${audio.track}';
  return includeDisc ? '${_discNumber(audio)}-$track' : track;
}

int _compareWithinDisc(
  Audio first,
  Audio second,
  int Function(Audio first, Audio second) compare,
) {
  final disc = _discNumber(first).compareTo(_discNumber(second));
  return disc != 0 ? disc : compare(first, second);
}

void _sortWithinDisc(
  List<Audio> list,
  SortOrder order,
  int Function(Audio first, Audio second) compare,
) {
  list.sort((a, b) {
    final left = order == SortOrder.ascending ? a : b;
    final right = order == SortOrder.ascending ? b : a;
    final cmp = _compareWithinDisc(left, right, compare);
    if (cmp != 0) return cmp;
    return a.title.naturalCompareTo(b.title);
  });
}

List<SortMethodDesc<Audio>> _albumSortMethods() {
  return [
    _albumTextSort(
      Symbols.title,
      '标题',
      (audio) => audio.title,
      audioTitleSortValue,
    ),
    _albumTextSort(
      Symbols.artist,
      '艺术家',
      (audio) => audio.artist,
      audioArtistSortValue,
    ),
    SortMethodDesc(
      icon: Symbols.art_track,
      name: '音轨',
      method: (list, order) => _sortWithinDisc(
        list,
        order,
        (first, second) => first.track.compareTo(second.track),
      ),
    ),
    SortMethodDesc(
      icon: Symbols.add,
      name: '创建时间',
      method: (list, order) => _sortWithinDisc(
        list,
        order,
        (first, second) => first.created.compareTo(second.created),
      ),
    ),
    SortMethodDesc(
      icon: Symbols.edit,
      name: '修改时间',
      method: (list, order) => _sortWithinDisc(
        list,
        order,
        (first, second) => first.modified.compareTo(second.modified),
      ),
    ),
    SortMethodDesc(
      icon: Symbols.timer,
      name: '时长',
      method: (list, order) {
        sortByIntegerThenNatural(
          list,
          valueOf: (audio) => audio.duration,
          tieBreakOf: audioTitleSortValue,
          descending: order == SortOrder.decending,
        );
      },
    ),
    SortMethodDesc(
      icon: Symbols.bar_chart,
      name: '播放次数',
      method: (list, order) {
        sortByIntegerThenNatural(
          list,
          valueOf: (audio) => audio.playCount,
          tieBreakOf: audioTitleSortValue,
          descending: order == SortOrder.decending,
        );
      },
    ),
  ];
}

SortMethodDesc<Audio> _albumTextSort(
  IconData icon,
  String name,
  String Function(Audio audio) valueOf,
  String Function(Audio audio) sortValueOf,
) {
  return SortMethodDesc(
    icon: icon,
    name: name,
    alphabetValueOf: valueOf,
    method: (list, order) {
      sortNaturallyBy(
        list,
        sortValueOf,
        descending: order == SortOrder.decending,
      );
    },
  );
}

class AlbumDetailPage extends StatelessWidget {
  const AlbumDetailPage({super.key, required this.album});

  final Album album;

  @override
  Widget build(BuildContext context) {
    return _AlbumDetailScaffold(album: album);
  }
}

class _AlbumDetailScaffold extends StatelessWidget {
  const _AlbumDetailScaffold({required this.album});

  final Album album;

  @override
  Widget build(BuildContext context) {
    final secondaryContent = List<Audio>.from(album.works);
    final multiSelectController = MultiSelectController<Audio>();
    final discNumbers = secondaryContent
        .map(_discNumber)
        .where((disc) => disc > 0)
        .toSet();
    final showDiscSections =
        discNumbers.length > 1 || discNumbers.any((disc) => disc > 1);
    final canSortSongs = hasEnoughItemsToSort(secondaryContent.length);
    return UniDetailPage<Album, Audio, Artist>(
      pref: AppPreference.instance.albumDetailPagePref,
      primaryContent: album,
      primaryPic: album.cover,
      picShape: PicShape.rrect,
      title: album.name,
      subtitle: '${album.works.length} 首作品',
      secondaryContent: secondaryContent,
      secondaryContentBuilder: (context, audio, i, ctl, view) =>
          _songTile(audio, i, secondaryContent, ctl, view, showDiscSections),
      secondaryContentSectionBuilder: showDiscSections
          ? (context, audio, i) => _discSection(audio, i, secondaryContent)
          : null,
      tertiaryContentTitle: '艺术家',
      tertiaryContent: album.artistsMap.values.toList(),
      tertiaryContentBuilder:
          (context, artist, i, multiSelectController, view) =>
              ArtistTile(artist: artist, view: view),
      enableShufflePlay: secondaryContent.isNotEmpty,
      enablePlayAll: secondaryContent.isNotEmpty,
      enableSortMethod: canSortSongs,
      enableSortOrder: canSortSongs,
      enableSecondaryContentViewSwitch: secondaryContent.isNotEmpty,
      enableTabs: true,
      secondaryContentTitle: '歌曲',
      tertiaryTabIcon: Symbols.artist,
      bodyOverride: secondaryContent.isEmpty ? const _EmptyAlbumBody() : null,
      multiSelectController: multiSelectController,
      multiSelectViewActions: _multiSelectActions(
        multiSelectController,
        secondaryContent,
      ),
      sortMethods: _albumSortMethods(),
    );
  }

  List<Widget> _multiSelectActions(
    MultiSelectController<Audio> multiSelectController,
    List<Audio> secondaryContent,
  ) {
    return [
      AddAllToPlaylist(multiSelectController: multiSelectController),
      MultiSelectSelectOrClearAll(
        multiSelectController: multiSelectController,
        contentList: secondaryContent,
      ),
      MultiSelectExit(multiSelectController: multiSelectController),
    ];
  }

  Widget _songTile(
    Audio audio,
    int i,
    List<Audio> playlist,
    MultiSelectController<Audio>? multiSelectController,
    ContentView view,
    bool showDiscSections,
  ) {
    final includeDisc = showDiscSections && view == ContentView.table;
    return AudioTile(
      leading: Text(_trackNumber(audio, includeDisc: includeDisc)),
      leadingWidth: includeDisc
          ? AudioTile.discLeadingWidth
          : AudioTile.defaultLeadingWidth,
      audioIndex: i,
      playlist: playlist,
      multiSelectController: multiSelectController,
    );
  }

  Widget? _discSection(Audio audio, int i, List<Audio> playlist) {
    final disc = _discNumber(audio);
    if (i > 0 && _discNumber(playlist[i - 1]) == disc) return null;
    return _DiscSectionHeader(disc: disc);
  }
}

class _DiscSectionHeader extends StatelessWidget {
  const _DiscSectionHeader({required this.disc});

  final int disc;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SizedBox(
      height: 44,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
        child: Row(
          children: [
            Icon(Symbols.album, size: 18, color: scheme.onSurfaceVariant),
            const SizedBox(width: 8),
            Text(
              '唱片 $disc',
              style: TextStyle(
                color: scheme.onSurface,
                fontSize: AppType.body,
                fontWeight: AppType.weightSemibold,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyAlbumBody extends StatelessWidget {
  const _EmptyAlbumBody();

  @override
  Widget build(BuildContext context) {
    return const QuietEmptyState(
      icon: Symbols.album,
      title: '这个专辑还没有歌曲',
      message: '等扫描或索引更新后，这里会显示可播放内容。',
    );
  }
}
