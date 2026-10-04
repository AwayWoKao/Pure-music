import 'dart:async';

import 'package:pure_music/component/danger_confirm_dialog.dart';
import 'package:pure_music/component/motion.dart';
import 'package:pure_music/component/scroll_aware_future_builder.dart';
import 'package:pure_music/core/cache.dart';
import 'package:pure_music/core/list_action_state.dart';
import 'package:pure_music/core/utils.dart';
import 'package:pure_music/core/design_tokens.dart';
import 'package:pure_music/core/menu_styles.dart';
import 'package:pure_music/library/audio_library.dart';
import 'package:pure_music/page/uni_page.dart';
import 'package:pure_music/library/playlist.dart';
import 'package:pure_music/core/paths.dart' as app_paths;
import 'package:pure_music/play_service/play_service.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';

/// Fixed-width slot for [AudioTile.leading] so index labels of different
/// glyph widths (`03` vs `13`) keep covers and titles on one vertical line.
class AudioTileLeadingSlot extends StatelessWidget {
  const AudioTileLeadingSlot({
    super.key,
    required this.child,
    this.width = AudioTile.defaultLeadingWidth,
  });

  final Widget child;
  final double width;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 16.0),
      child: SizedBox(
        width: width,
        child: Align(
          alignment: Alignment.centerRight,
          child: DefaultTextStyle.merge(
            style: const TextStyle(
              fontFeatures: [FontFeature.tabularFigures()],
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}

/// 由[playlist]和[audioIndex]确定audio，而不是直接传入audio，
/// 这是为了实现点击列表项播放乐曲时指定该列表为播放列表。
/// 同时，播放乐曲时也是需要index和playlist来定位audio和设置播放列表。
class AudioTile extends StatefulWidget {
  const AudioTile({
    super.key,
    required this.audioIndex,
    required this.playlist,
    this.focus = false,
    this.leading,
    this.leadingWidth = defaultLeadingWidth,
    this.action,
    this.multiSelectController,
    this.onRemoveFromPlaylist,
  });

  static const double defaultLeadingWidth = 32;
  static const double discLeadingWidth = 40;

  final int audioIndex;
  final List<Audio> playlist;
  final bool focus;
  final Widget? leading;
  final double leadingWidth;
  final Widget? action;
  final MultiSelectController? multiSelectController;
  final FutureOr<void> Function(Audio audio)? onRemoveFromPlaylist;

  @override
  State<AudioTile> createState() => _AudioTileState();
}

class _AudioTileState extends State<AudioTile> {
  bool _isRemovingFromPlaylist = false;
  Playlist? _addingToPlaylist;
  bool _menuRequested = false;
  double? _rangeScrollOrigin;

  Audio get _audio => widget.playlist[widget.audioIndex];

  @override
  Widget build(BuildContext context) {
    final audio = _audio;
    final playbackService = PlayService.instance.playbackService;
    return ListenableBuilder(
      listenable: playbackService,
      builder: (context, _) {
        final isNowPlaying = playbackService.nowPlaying?.path == audio.path;
        final effectiveFocus = widget.focus || isNowPlaying;
        final isSelected =
            widget.multiSelectController?.selected.contains(audio) == true;
        return MenuTheme(
          data: MenuThemeData(style: appMenuStyle),
          child: MenuAnchor(
            consumeOutsideTap: true,
            style: appMenuStyle,
            onClose: _onMenuClose,
            menuChildren: _menuRequested
                ? _buildMenuChildren(context, audio)
                : const <Widget>[],
            builder: (context, controller, _) => _buildTile(
              context,
              controller,
              audio,
              effectiveFocus: effectiveFocus,
              isSelected: isSelected,
            ),
          ),
        );
      },
    );
  }

  void _onMenuClose() {
    if (mounted && _menuRequested) {
      setState(() => _menuRequested = false);
    }
  }

  Future<void> _removeFromPlaylist(
    BuildContext context,
    Audio audio,
    ColorScheme scheme,
  ) async {
    if (!canStartSinglePlaylistRemoval(
      hasRemoveAction: widget.onRemoveFromPlaylist != null,
      isRemoving: _isRemovingFromPlaylist,
      isAddingToPlaylist: _addingToPlaylist != null,
    )) {
      return;
    }
    final confirmed = await showDangerConfirmDialog(
      context: context,
      title: '从歌单移除歌曲？',
      message: '只会从当前歌单移除这首歌曲，不会删除本地音乐文件。',
      confirmLabel: '移除',
      details: Text(
        audio.title,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: scheme.onSurfaceVariant,
          fontSize: AppType.caption,
        ),
      ),
    );
    if (!confirmed || !mounted) return;
    setState(() => _isRemovingFromPlaylist = true);
    try {
      await Future<void>.sync(() => widget.onRemoveFromPlaylist!(audio));
    } finally {
      if (mounted) {
        setState(() => _isRemovingFromPlaylist = false);
      }
    }
  }

  Future<void> _addToPlaylist(Audio audio, Playlist target) async {
    if (_addingToPlaylist != null || _isRemovingFromPlaylist) {
      return;
    }
    final added = target.containsPath(audio.path);
    if (added) {
      showTextOnSnackBar('歌曲已在歌单中');
      return;
    }

    setState(() => _addingToPlaylist = target);
    try {
      target.addPath(audio.path);
      final saved = await savePlaylists();
      if (!mounted) return;
      if (!saved) {
        target.removeByPath(audio.path);
        showTextOnSnackBar('保存歌单失败', variant: ToastVariant.error);
        return;
      }
      showTextOnSnackBar('已添加到歌单', variant: ToastVariant.success);
    } finally {
      _addingToPlaylist = null;
      if (mounted) setState(() {});
    }
  }

  List<Widget> _buildMenuChildren(BuildContext context, Audio audio) {
    final scheme = Theme.of(context).colorScheme;
    final menuItemStyle = appMenuItemStyle;
    return [
      ..._artistMenuItems(context, audio, menuItemStyle),
      _albumMenuItem(context, audio, menuItemStyle),
      _playNextMenuItem(audio, menuItemStyle),
      if (widget.multiSelectController != null)
        _multiSelectMenuItem(audio, menuItemStyle),
      _addToPlaylistMenuItem(audio, menuItemStyle),
      if (widget.onRemoveFromPlaylist != null)
        _removeFromPlaylistMenuItem(context, audio, scheme, menuItemStyle),
      _detailMenuItem(context, audio, menuItemStyle),
    ];
  }

  List<Widget> _artistMenuItems(
    BuildContext context,
    Audio audio,
    ButtonStyle menuItemStyle,
  ) {
    return List.generate(audio.splitedArtists.length, (i) {
      final name = audio.splitedArtists[i];
      final artist = AudioLibrary.instance.artistCollection[name];
      return MenuItemButton(
        style: menuItemStyle,
        onPressed: artist == null
            ? null
            : () {
                context.push(app_paths.ARTIST_DETAIL_PAGE, extra: artist);
              },
        leadingIcon: const Icon(Symbols.artist),
        child: Text(name),
      );
    });
  }

  Widget _albumMenuItem(
    BuildContext context,
    Audio audio,
    ButtonStyle menuItemStyle,
  ) {
    final album = AudioLibrary.instance.albumCollection[audio.album];
    return MenuItemButton(
      style: menuItemStyle,
      onPressed: album == null
          ? null
          : () {
              context.push(app_paths.ALBUM_DETAIL_PAGE, extra: album);
            },
      leadingIcon: const Icon(Symbols.album),
      child: Text(audio.album),
    );
  }

  Widget _playNextMenuItem(Audio audio, ButtonStyle menuItemStyle) {
    return MenuItemButton(
      style: menuItemStyle,
      onPressed:
          canAddAudioToNext(
            hasNowPlaying:
                PlayService.instance.playbackService.nowPlaying != null,
            isPendingFeedback: false,
          )
          ? () {
              PlayService.instance.playbackService.addToNext(audio);
              showTextOnSnackBar('已加入下一首', variant: ToastVariant.success);
            }
          : null,
      leadingIcon: const Icon(Symbols.plus_one),
      child: const Text('下一首播放'),
    );
  }

  Widget _multiSelectMenuItem(Audio audio, ButtonStyle menuItemStyle) {
    return MenuItemButton(
      style: menuItemStyle,
      onPressed: () {
        widget.multiSelectController!.useMultiSelectView(true);
        widget.multiSelectController!.select(audio);
      },
      leadingIcon: const Icon(Symbols.select),
      child: const Text('多选'),
    );
  }

  Widget _addToPlaylistMenuItem(Audio audio, ButtonStyle menuItemStyle) {
    if (playlists.isEmpty) {
      return MenuItemButton(
        style: menuItemStyle,
        onPressed: null,
        leadingIcon: const Icon(Symbols.queue_music),
        child: const Text('添加到歌单'),
      );
    }
    return _addToPlaylistSubmenu(audio, menuItemStyle);
  }

  Widget _addToPlaylistSubmenu(Audio audio, ButtonStyle menuItemStyle) {
    return Builder(
      builder: (_) {
        final playlistMemberships = playlists
            .map((playlist) => playlist.containsPath(audio.path))
            .toList(growable: false);
        final isBusy = _addingToPlaylist != null || _isRemovingFromPlaylist;
        final canOpenAddMenu = canOpenSingleAudioAddToPlaylistMenu(
          hasAudio: true,
          isBusy: isBusy,
          alreadyInPlaylists: playlistMemberships,
        );
        if (!canOpenAddMenu) {
          return _closedAddToPlaylistButton(menuItemStyle, playlistMemberships);
        }
        return SubmenuButton(
          style: menuItemStyle,
          menuChildren: _playlistMenuEntries(
            audio,
            menuItemStyle,
            playlistMemberships,
            isBusy,
          ),
          child: const Text('添加到歌单'),
        );
      },
    );
  }

  Widget _closedAddToPlaylistButton(
    ButtonStyle menuItemStyle,
    List<bool> playlistMemberships,
  ) {
    return MenuItemButton(
      style: menuItemStyle,
      onPressed: null,
      leadingIcon: _addingToPlaylist != null
          ? const SizedBox(
              width: 18.0,
              height: 18.0,
              child: CircularProgressIndicator(strokeWidth: 2.0),
            )
          : Icon(
              playlistMemberships.every((alreadyIn) => alreadyIn)
                  ? Symbols.check
                  : Symbols.queue_music,
            ),
      child: const Text('添加到歌单'),
    );
  }

  List<Widget> _playlistMenuEntries(
    Audio audio,
    ButtonStyle menuItemStyle,
    List<bool> playlistMemberships,
    bool isBusy,
  ) {
    return List.generate(playlists.length, (i) {
      final playlist = playlists[i];
      final isAdding = identical(_addingToPlaylist, playlist);
      final alreadyInPlaylist = playlistMemberships[i];
      return MenuItemButton(
        style: menuItemStyle,
        onPressed: isBusy || alreadyInPlaylist
            ? null
            : () => _addToPlaylist(audio, playlist),
        leadingIcon: isAdding
            ? const SizedBox(
                width: 18.0,
                height: 18.0,
                child: CircularProgressIndicator(strokeWidth: 2.0),
              )
            : Icon(alreadyInPlaylist ? Symbols.check : Symbols.queue_music),
        child: Text(playlist.name),
      );
    });
  }

  Widget _removeFromPlaylistMenuItem(
    BuildContext context,
    Audio audio,
    ColorScheme scheme,
    ButtonStyle menuItemStyle,
  ) {
    return MenuItemButton(
      style: menuItemStyle,
      onPressed:
          canStartSinglePlaylistRemoval(
            hasRemoveAction: widget.onRemoveFromPlaylist != null,
            isRemoving: _isRemovingFromPlaylist,
            isAddingToPlaylist: _addingToPlaylist != null,
          )
          ? () => _removeFromPlaylist(context, audio, scheme)
          : null,
      leadingIcon: _isRemovingFromPlaylist
          ? const SizedBox(
              width: 18.0,
              height: 18.0,
              child: CircularProgressIndicator(strokeWidth: 2.0),
            )
          : Icon(Symbols.remove_circle, color: scheme.error),
      child: Text(_isRemovingFromPlaylist ? '移除中' : '从歌单移除'),
    );
  }

  Widget _detailMenuItem(
    BuildContext context,
    Audio audio,
    ButtonStyle menuItemStyle,
  ) {
    return MenuItemButton(
      style: menuItemStyle,
      onPressed: () {
        context.push(app_paths.AUDIO_DETAIL_PAGE, extra: audio);
      },
      leadingIcon: const Icon(Symbols.info),
      child: const Text('详细信息'),
    );
  }

  Widget _buildTile(
    BuildContext context,
    MenuController controller,
    Audio audio, {
    required bool effectiveFocus,
    required bool isSelected,
  }) {
    final scheme = Theme.of(context).colorScheme;
    final titleColor = effectiveFocus ? scheme.primary : scheme.onSurface;
    final metadataColor = effectiveFocus
        ? scheme.primary.withValues(alpha: 0.78)
        : scheme.onSurfaceVariant;
    final backgroundColor = isSelected
        ? scheme.secondaryContainer
        : effectiveFocus
        ? scheme.primary.withAlpha(20)
        : Colors.transparent;
    return DirectionalListItemEntrance(
      identity: audio,
      child: AnimatedContainer(
        duration: MotionDuration.base,
        curve: MotionCurve.standard,
        height: 64.0,
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: AppRadius.smCircular,
          border: effectiveFocus && !isSelected
              ? Border.all(color: scheme.primary.withAlpha(89))
              : null,
        ),
        child: Material(
          type: MaterialType.transparency,
          child: _tileHitTarget(
            context,
            controller,
            audio,
            scheme: scheme,
            titleColor: titleColor,
            metadataColor: metadataColor,
            isSelected: isSelected,
          ),
        ),
      ),
    );
  }

  Widget _tileHitTarget(
    BuildContext context,
    MenuController controller,
    Audio audio, {
    required ColorScheme scheme,
    required Color titleColor,
    required Color metadataColor,
    required bool isSelected,
  }) {
    return GestureDetector(
      onLongPressStart: (details) => _onLongPressStart(context),
      onLongPressMoveUpdate: (details) =>
          _onLongPressMoveUpdate(context, details),
      onLongPressEnd: (_) => _onLongPressEnd(),
      onLongPressCancel: _onLongPressEnd,
      onSecondaryTapDown: (details) => _onSecondaryTapDown(controller, details),
      child: InkWell(
        focusColor: Colors.transparent,
        hoverColor: scheme.onSurface.withAlpha(10),
        onHover: (hovering) => _onTileHover(hovering),
        borderRadius: AppRadius.smCircular,
        onTap: () => _onTileTap(controller, audio),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8.0),
          child: _buildRow(
            audio,
            titleColor: titleColor,
            metadataColor: metadataColor,
            isSelected: isSelected,
          ),
        ),
      ),
    );
  }

  void _onLongPressStart(BuildContext context) {
    _rangeScrollOrigin = Scrollable.maybeOf(context)?.position.pixels;
    widget.multiSelectController?.beginRangeSelection(
      widget.playlist,
      widget.audioIndex,
    );
  }

  void _onLongPressMoveUpdate(
    BuildContext context,
    LongPressMoveUpdateDetails details,
  ) {
    final scrollPosition = Scrollable.maybeOf(context)?.position.pixels;
    final scrollDelta = scrollPosition == null || _rangeScrollOrigin == null
        ? 0.0
        : scrollPosition - _rangeScrollOrigin!;
    final targetIndex =
        widget.audioIndex +
        ((details.localOffsetFromOrigin.dy + scrollDelta) / 64).round();
    widget.multiSelectController?.updateRangeSelection(targetIndex);
  }

  void _onLongPressEnd() {
    _rangeScrollOrigin = null;
    widget.multiSelectController?.endRangeSelection();
  }

  void _onSecondaryTapDown(MenuController controller, TapDownDetails details) {
    if (widget.multiSelectController?.enableMultiSelectView == true) {
      return;
    }
    final position = details.localPosition.translate(0, -240);
    if (_menuRequested) {
      controller.open(position: position);
      return;
    }
    setState(() => _menuRequested = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_menuRequested) return;
      controller.open(position: position);
    });
  }

  void _onTileHover(bool hovering) {
    final multiSelectController = widget.multiSelectController;
    if (hovering && multiSelectController?.isRangeSelecting == true) {
      multiSelectController!.updateRangeSelection(widget.audioIndex);
    }
  }

  void _onTileTap(MenuController controller, Audio audio) {
    if (controller.isOpen) {
      controller.close();
      return;
    }
    if (widget.multiSelectController == null ||
        !widget.multiSelectController!.enableMultiSelectView) {
      PlayService.instance.playbackService.play(
        widget.audioIndex,
        widget.playlist,
      );
      return;
    }
    if (widget.multiSelectController!.selected.contains(audio)) {
      widget.multiSelectController!.unselect(audio);
    } else {
      widget.multiSelectController!.select(audio);
    }
  }

  Widget _buildRow(
    Audio audio, {
    required Color titleColor,
    required Color metadataColor,
    required bool isSelected,
  }) {
    return Row(
      children: [
        if (widget.leading != null)
          AudioTileLeadingSlot(
            width: widget.leadingWidth,
            child: widget.leading!,
          ),
        _SmallCoverWidget(audio: audio),
        const SizedBox(width: 16.0),
        Expanded(child: _metadataColumn(audio, titleColor, metadataColor)),
        const SizedBox(width: 8.0),
        _durationLabel(audio, metadataColor),
        if (widget.multiSelectController != null &&
            widget.multiSelectController!.enableMultiSelectView)
          _selectionCheckbox(audio, isSelected),
        if (widget.action != null)
          Padding(
            padding: const EdgeInsets.only(left: 8.0),
            child: widget.action!,
          ),
      ],
    );
  }

  Widget _metadataColumn(Audio audio, Color titleColor, Color metadataColor) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          audio.title,
          style: TextStyle(
            color: titleColor,
            fontSize: AppType.subtitle,
            fontWeight: AppType.weightMedium,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(width: 4.0),
        Text(
          '${audio.artist} - ${audio.album}',
          style: TextStyle(color: metadataColor),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }

  Widget _durationLabel(Audio audio, Color metadataColor) {
    return Text(
      Duration(seconds: audio.duration).toStringHMMSS(),
      style: TextStyle(
        color: metadataColor,
        fontFeatures: const [FontFeature.tabularFigures()],
      ),
    );
  }

  Widget _selectionCheckbox(Audio audio, bool isSelected) {
    return Padding(
      padding: const EdgeInsets.only(left: 8.0),
      child: Checkbox(
        value: isSelected,
        onChanged: (v) {
          if (v == true) {
            widget.multiSelectController!.select(audio);
          } else {
            widget.multiSelectController!.unselect(audio);
          }
        },
      ),
    );
  }
}

/// 不使用 FutureBuilder，避免任何闪烁。
class _SmallCoverWidget extends StatelessWidget {
  final Audio audio;
  const _SmallCoverWidget({required this.audio});

  @override
  Widget build(BuildContext context) {
    final initialProvider = CoverImageCache.instance.getCached(
      path: audio.path,
      modified: audio.modified,
      width: 48,
      height: 48,
    );
    return ScrollAwareFutureBuilder<ImageProvider?>(
      identity: '${audio.path}|${audio.modified}',
      initialData: initialProvider,
      future: () => audio.cover,
      builder: (context, snapshot) {
        final provider = snapshot.data;
        if (provider == null) {
          return snapshot.connectionState == ConnectionState.done
              ? _placeholder(context)
              : _loadingPlaceholder(context);
        }
        return ClipRRect(
          borderRadius: AppRadius.smCircular,
          child: Image(
            image: provider,
            width: 48.0,
            height: 48.0,
            fit: BoxFit.cover,
            gaplessPlayback: true,
            errorBuilder: (_, _, _) => _placeholder(context),
          ),
        );
      },
    );
  }

  Widget _loadingPlaceholder(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: 48.0,
      height: 48.0,
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.22),
        borderRadius: AppRadius.smCircular,
      ),
    );
  }

  Widget _placeholder(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: 48.0,
      height: 48.0,
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: AppRadius.smCircular,
      ),
      child: Icon(
        Symbols.music_note,
        size: 22,
        color: scheme.onSurfaceVariant.withValues(alpha: 0.65),
      ),
    );
  }
}
