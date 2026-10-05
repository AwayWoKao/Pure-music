import 'package:pure_music/core/preference.dart';
import 'package:pure_music/core/list_action_state.dart';
import 'package:pure_music/core/enums.dart';
import 'package:pure_music/core/utils.dart';
import 'package:pure_music/library/audio_library.dart';
import 'package:pure_music/library/audio_sort.dart';
import 'package:pure_music/component/album_tile.dart';
import 'package:pure_music/component/audio_tile.dart';
import 'package:pure_music/component/quiet_empty_state.dart';
import 'package:pure_music/page/uni_detail_page.dart';
import 'package:pure_music/page/uni_page.dart';
import 'package:pure_music/page/uni_page_components.dart';
import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

class ArtistDetailPage extends StatelessWidget {
  const ArtistDetailPage({super.key, required this.artist});

  final Artist artist;

  @override
  Widget build(BuildContext context) {
    final secondaryContent = List<Audio>.from(artist.works);
    final multiSelectController = MultiSelectController<Audio>();

    final canSortSongs = hasEnoughItemsToSort(secondaryContent.length);

    return UniDetailPage<Artist, Audio, Album>(
      pref: AppPreference.instance.artistDetailPagePref,
      primaryContent: artist,
      primaryPic: artist.picture,
      picShape: PicShape.oval,
      title: artist.name,
      subtitle: '${artist.works.length} 首作品',
      secondaryContent: secondaryContent,
      secondaryContentBuilder: (context, audio, i, multiSelectController, _) =>
          AudioTile(
            audioIndex: i,
            playlist: secondaryContent,
            multiSelectController: multiSelectController,
          ),
      tertiaryContentTitle: '专辑',
      tertiaryContent: artist.albumsMap.values.toList(),
      tertiaryContentBuilder:
          (context, album, i, multiSelectController, view) =>
              AlbumTile(album: album, view: view),
      enablePlayAll: secondaryContent.isNotEmpty,
      enableShufflePlay: secondaryContent.isNotEmpty,
      enableSortMethod: canSortSongs,
      enableSortOrder: canSortSongs,
      enableSecondaryContentViewSwitch: secondaryContent.isNotEmpty,
      enableTabs: true,
      secondaryContentTitle: '歌曲',
      tertiaryTabIcon: Symbols.album,
      bodyOverride: secondaryContent.isEmpty ? const _EmptyArtistBody() : null,
      multiSelectController: multiSelectController,
      multiSelectViewActions: [
        AddAllToPlaylist(multiSelectController: multiSelectController),
        MultiSelectSelectOrClearAll(
          multiSelectController: multiSelectController,
          contentList: secondaryContent,
        ),
        MultiSelectExit(multiSelectController: multiSelectController),
      ],
      sortMethods: _artistSortMethods(),
    );
  }
}

SortMethodDesc<Audio> _artistStringSort({
  required IconData icon,
  required String name,
  required String Function(Audio) keyOf,
  required String Function(Audio) sortValueOf,
}) {
  return SortMethodDesc(
    icon: icon,
    name: name,
    alphabetValueOf: keyOf,
    method: (list, order) {
      sortNaturallyBy(
        list,
        sortValueOf,
        descending: order == SortOrder.decending,
      );
    },
  );
}

SortMethodDesc<Audio> _artistIntSort({
  required IconData icon,
  required String name,
  required int Function(Audio) valueOf,
}) {
  return SortMethodDesc(
    icon: icon,
    name: name,
    method: (list, order) {
      sortByIntegerThenNatural(
        list,
        valueOf: valueOf,
        tieBreakOf: audioTitleSortValue,
        descending: order == SortOrder.decending,
      );
    },
  );
}

List<SortMethodDesc<Audio>> _artistSortMethods() {
  return [
    _artistStringSort(
      icon: Symbols.title,
      name: '标题',
      keyOf: (audio) => audio.title,
      sortValueOf: audioTitleSortValue,
    ),
    _artistStringSort(
      icon: Symbols.album,
      name: '专辑',
      keyOf: (audio) => audio.album,
      sortValueOf: audioAlbumSortValue,
    ),
    _artistIntSort(
      icon: Symbols.add,
      name: '创建时间',
      valueOf: (audio) => audio.created,
    ),
    _artistIntSort(
      icon: Symbols.edit,
      name: '修改时间',
      valueOf: (audio) => audio.modified,
    ),
    _artistIntSort(
      icon: Symbols.timer,
      name: '时长',
      valueOf: (audio) => audio.duration,
    ),
    _artistIntSort(
      icon: Symbols.bar_chart,
      name: '播放次数',
      valueOf: (audio) => audio.playCount,
    ),
  ];
}

class _EmptyArtistBody extends StatelessWidget {
  const _EmptyArtistBody();

  @override
  Widget build(BuildContext context) {
    return const QuietEmptyState(
      icon: Symbols.artist,
      title: '这个艺术家还没有歌曲',
      message: '等扫描或索引更新后，这里会显示可播放内容。',
    );
  }
}
