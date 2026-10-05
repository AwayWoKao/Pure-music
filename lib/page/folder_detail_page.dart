import 'package:pure_music/core/preference.dart';
import 'package:pure_music/core/enums.dart';
import 'package:pure_music/core/list_action_state.dart';
import 'package:pure_music/core/mouse_back_exit.dart';
import 'package:pure_music/core/utils.dart';
import 'package:pure_music/library/audio_library.dart';
import 'package:pure_music/component/audio_tile.dart';
import 'package:pure_music/component/quiet_empty_state.dart';
import 'package:pure_music/page/uni_detail_page.dart';
import 'package:pure_music/page/uni_page.dart';
import 'package:pure_music/page/uni_page_components.dart';
import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

void _sortFolderAudios(
  List<Audio> list,
  SortOrder order,
  int Function(Audio a, Audio b) compare,
) {
  switch (order) {
    case SortOrder.ascending:
      list.sort(compare);
    case SortOrder.decending:
      list.sort((a, b) => compare(b, a));
  }
}

List<SortMethodDesc<Audio>> _folderSortMethods() {
  return [
    ..._folderTextSorts(),
    ..._folderTimeSorts(),
    SortMethodDesc(
      icon: Symbols.timer,
      name: '时长',
      method: (list, order) => _sortFolderAudios(
        list,
        order,
        (a, b) => a.duration.compareTo(b.duration),
      ),
    ),
    SortMethodDesc(
      icon: Symbols.bar_chart,
      name: '播放次数',
      method: (list, order) => _sortFolderAudios(
        list,
        order,
        (a, b) => a.playCount.compareTo(b.playCount),
      ),
    ),
  ];
}

List<SortMethodDesc<Audio>> _folderTextSorts() {
  return [
    SortMethodDesc(
      icon: Symbols.title,
      name: '标题',
      alphabetValueOf: (audio) => audio.title,
      method: (list, order) => _sortFolderAudios(
        list,
        order,
        (a, b) => a.title.naturalCompareTo(b.title),
      ),
    ),
    SortMethodDesc(
      icon: Symbols.artist,
      name: '艺术家',
      alphabetValueOf: (audio) => audio.artist,
      method: (list, order) => _sortFolderAudios(
        list,
        order,
        (a, b) => a.artist.naturalCompareTo(b.artist),
      ),
    ),
    SortMethodDesc(
      icon: Symbols.album,
      name: '专辑',
      alphabetValueOf: (audio) => audio.album,
      method: (list, order) => _sortFolderAudios(
        list,
        order,
        (a, b) => a.album.naturalCompareTo(b.album),
      ),
    ),
  ];
}

List<SortMethodDesc<Audio>> _folderTimeSorts() {
  return [
    SortMethodDesc(
      icon: Symbols.add,
      name: '创建时间',
      method: (list, order) => _sortFolderAudios(
        list,
        order,
        (a, b) => a.created.compareTo(b.created),
      ),
    ),
    SortMethodDesc(
      icon: Symbols.edit,
      name: '修改时间',
      method: (list, order) => _sortFolderAudios(
        list,
        order,
        (a, b) => a.modified.compareTo(b.modified),
      ),
    ),
  ];
}

class FolderDetailPage extends StatefulWidget {
  final AudioFolder folder;
  const FolderDetailPage({super.key, required this.folder});

  @override
  State<FolderDetailPage> createState() => _FolderDetailPageState();
}

class _FolderDetailPageState extends State<FolderDetailPage> {
  final multiSelectController = MultiSelectController<Audio>();
  late final List<Audio> _contentList;
  late final Future<ImageProvider?> _primaryPicFuture;
  String _searchQuery = '';

  Future<ImageProvider?> _loadPrimaryPic() {
    return widget.folder.audios.firstOrNull?.mediumCover ??
        Future<ImageProvider?>.value(null);
  }

  @override
  void initState() {
    super.initState();
    _contentList = List<Audio>.from(widget.folder.audios);
    _primaryPicFuture = _loadPrimaryPic();
  }

  @override
  void dispose() {
    MouseBackExit.unregister(_clearSearchOnBack);
    super.dispose();
  }

  void _setSearchQuery(String value) {
    setState(() => _searchQuery = value);
    if (_searchQuery.isEmpty) {
      MouseBackExit.unregister(_clearSearchOnBack);
    } else {
      MouseBackExit.register(_clearSearchOnBack);
    }
  }

  bool _clearSearchOnBack() {
    if (!mounted || _searchQuery.isEmpty) return false;
    _setSearchQuery('');
    return true;
  }

  @override
  Widget build(BuildContext context) {
    final allAudios = _contentList;
    final contentList = _filteredAudios(allAudios);
    final canSortSongs = hasEnoughItemsToSort(contentList.length);
    final canPlaySongs = canShowPlayAllAction(contentList.length);
    final canSwitchContentView = canShowContentViewSwitch(contentList.length);
    return UniDetailPage<AudioFolder, Audio, Object>(
      pref: AppPreference.instance.folderDetailPagePref,
      primaryContent: widget.folder,
      primaryPic: _primaryPicFuture,
      picShape: PicShape.rrect,
      title: widget.folder.displayName,
      subtitle: _searchQuery.isEmpty
          ? '${_contentList.length} 首乐曲'
          : '${contentList.length} / ${_contentList.length} 首乐曲',
      secondaryContent: contentList,
      secondaryContentBuilder: (context, item, i, msc, _) => AudioTile(
        audioIndex: i,
        playlist: contentList,
        multiSelectController: msc,
      ),
      enablePlayAll: canPlaySongs,
      enableShufflePlay: canPlaySongs,
      enableSortMethod: canSortSongs,
      enableSortOrder: canSortSongs,
      enableSecondaryContentViewSwitch: canSwitchContentView,
      enableSearch: true,
      searchQuery: _searchQuery,
      onSearchChanged: _setSearchQuery,
      bodyOverride: contentList.isEmpty
          ? (_searchQuery.isEmpty
                ? const _EmptyFolderBody()
                : const _NoSearchResultBody())
          : null,
      multiSelectController: multiSelectController,
      multiSelectViewActions: [
        AddAllToPlaylist(multiSelectController: multiSelectController),
        MultiSelectSelectOrClearAll(
          multiSelectController: multiSelectController,
          contentList: contentList,
        ),
        MultiSelectExit(multiSelectController: multiSelectController),
      ],
      sortMethods: _folderSortMethods(),
    );
  }

  List<Audio> _filteredAudios(List<Audio> allAudios) {
    if (_searchQuery.isEmpty) return List<Audio>.from(allAudios);
    final q = _searchQuery.toLowerCase();
    return allAudios
        .where(
          (audio) =>
              audio.title.toLowerCase().contains(q) ||
              audio.artist.toLowerCase().contains(q) ||
              audio.album.toLowerCase().contains(q),
        )
        .toList();
  }
}

class _EmptyFolderBody extends StatelessWidget {
  const _EmptyFolderBody();

  @override
  Widget build(BuildContext context) {
    return const QuietEmptyState(
      icon: Symbols.folder,
      title: '这个文件夹还没有歌曲',
      message: '等扫描或索引更新后，这里会显示可播放内容。',
    );
  }
}

class _NoSearchResultBody extends StatelessWidget {
  const _NoSearchResultBody();

  @override
  Widget build(BuildContext context) {
    return const QuietEmptyState(
      icon: Symbols.search_off,
      title: '没有找到匹配的歌曲',
      message: '换个关键词试试吧。',
    );
  }
}
