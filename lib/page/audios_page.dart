import 'package:pure_music/core/preference.dart';
import 'package:pure_music/core/enums.dart';
import 'package:pure_music/core/list_action_state.dart';
import 'package:pure_music/core/page_sort.dart';
import 'package:pure_music/component/audio_tile.dart';
import 'package:pure_music/core/utils.dart';
import 'package:pure_music/library/audio_library.dart';
import 'package:pure_music/library/audio_sort.dart';
import 'package:pure_music/page/uni_page.dart';
import 'package:pure_music/page/uni_page_components.dart';
import 'package:pure_music/page/page_scaffold.dart';
import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

SortMethodDesc<Audio> _naturalAudioSort({
  required IconData icon,
  required String name,
  required String Function(Audio) keyOf,
  String Function(Audio)? alphabetValueOf,
  bool reuseEqualKeys = false,
}) {
  return SortMethodDesc(
    icon: icon,
    name: name,
    alphabetValueOf: alphabetValueOf ?? keyOf,
    method: (list, order) {
      sortNaturallyBy(
        list,
        keyOf,
        descending: order == SortOrder.decending,
        reuseEqualKeys: reuseEqualKeys,
      );
    },
    backgroundMethod: (list, order, control) => sortPageNaturallyInBackground(
      list,
      keyOf,
      descending: order == SortOrder.decending,
      reuseEqualKeys: reuseEqualKeys,
      control: control,
    ),
  );
}

SortMethodDesc<Audio> _timeAudioSort({
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
    backgroundMethod: (list, order, control) => sortPageByIntegerInBackground(
      list,
      valueOf,
      descending: order == SortOrder.decending,
      tieBreakOf: audioTitleSortValue,
      control: control,
    ),
  );
}

List<SortMethodDesc<Audio>> _audiosSortMethods() {
  return [
    _naturalAudioSort(
      icon: Symbols.title,
      name: '标题',
      keyOf: audioTitleSortValue,
      alphabetValueOf: (audio) => audio.title,
    ),
    _naturalAudioSort(
      icon: Symbols.artist,
      name: '艺术家',
      keyOf: audioArtistSortValue,
      alphabetValueOf: (audio) => audio.artist,
    ),
    _naturalAudioSort(
      icon: Symbols.album,
      name: '专辑',
      keyOf: audioAlbumSortValue,
      alphabetValueOf: (audio) => audio.album,
    ),
    _timeAudioSort(
      icon: Symbols.add,
      name: '创建时间',
      valueOf: (audio) => audio.created,
    ),
    _timeAudioSort(
      icon: Symbols.edit,
      name: '修改时间',
      valueOf: (audio) => audio.modified,
    ),
    _timeAudioSort(
      icon: Symbols.timer,
      name: '时长',
      valueOf: (audio) => audio.duration,
    ),
    _timeAudioSort(
      icon: Symbols.bar_chart,
      name: '播放次数',
      valueOf: (audio) => audio.playCount,
    ),
  ];
}

class AudiosPage extends StatefulWidget {
  final Audio? locateTo;
  const AudiosPage({super.key, this.locateTo});

  @override
  State<AudiosPage> createState() => _AudiosPageState();
}

class _AudiosPageState extends State<AudiosPage> {
  final MultiSelectController<Audio> _multiSelectController =
      MultiSelectController<Audio>();
  int _contentVersion = -1;
  List<Audio> _contentList = [];
  bool _contentIsPrepared = false;

  List<Audio> _resolveContentList(int version) {
    if (_contentVersion == version) return _contentList;
    _contentVersion = version;
    final library = AudioLibrary.instance;
    final prepared = library.preparedAudiosPage;
    _contentIsPrepared = prepared != null;
    _contentList = prepared?.items ?? List<Audio>.from(library.audioCollection);
    _multiSelectController.selected.clear();
    _multiSelectController.enableMultiSelectView = false;
    return _contentList;
  }

  @override
  void dispose() {
    _multiSelectController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<int>(
      valueListenable: AudioLibrary.libraryVersion,
      builder: (context, version, _) {
        final contentList = _resolveContentList(version);
        final hasSongs = contentList.isNotEmpty;
        final canSortSongs = hasEnoughItemsToSort(contentList.length);
        return UniPage<Audio>(
          pref: AppPreference.instance.audiosPagePref,
          title: '音乐',
          subtitle: '${contentList.length} 首乐曲',
          contentList: contentList,
          contentRevision: version,
          contentIsPrepared: _contentIsPrepared,
          contentBuilder: (context, item, i, multiSelectController, _) =>
              AudioTile(
                audioIndex: i,
                playlist: contentList,
                focus: item == widget.locateTo,
                multiSelectController: _multiSelectController,
              ),
          enableShufflePlay: hasSongs,
          enableSortMethod: canSortSongs,
          enableSortOrder: canSortSongs,
          enableContentViewSwitch: hasSongs,
          actionPlacement: PageActionPlacement.belowSubtitle,
          locateTo: widget.locateTo,
          multiSelectController: _multiSelectController,
          multiSelectViewActions: [
            AddAllToPlaylist(multiSelectController: _multiSelectController),
            MultiSelectSelectOrClearAll(
              multiSelectController: _multiSelectController,
              contentList: contentList,
            ),
            MultiSelectExit(multiSelectController: _multiSelectController),
          ],
          sortMethods: _audiosSortMethods(),
        );
      },
    );
  }
}
