import 'package:pure_music/library/audio_library.dart';
import 'package:pure_music/component/cover_pointer_sheen.dart';
import 'package:pure_music/component/motion.dart';
import 'package:pure_music/component/scroll_aware_future_builder.dart';
import 'package:pure_music/page/uni_page.dart';
import 'package:pure_music/core/design_tokens.dart';
import 'package:pure_music/core/enums.dart';
import 'package:pure_music/core/cache.dart';
import 'package:pure_music/core/menu_styles.dart';
import 'package:pure_music/core/settings.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:pure_music/core/paths.dart' as app_paths;

class AlbumTile extends StatefulWidget {
  const AlbumTile({
    super.key,
    required this.album,
    this.multiSelectController,
    this.view = ContentView.list,
  });

  final Album album;
  final MultiSelectController<Album>? multiSelectController;
  final ContentView view;

  @override
  State<AlbumTile> createState() => _AlbumTileState();
}

class _AlbumTileState extends State<AlbumTile> {
  int get _coverSize => widget.view == ContentView.list ? 48 : 160;
  String get _currentCoverIdentity => '${widget.album.primaryPath}|$_coverSize';

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isSelected =
        widget.multiSelectController?.selected.contains(widget.album) == true;
    final isMultiSelectView =
        widget.multiSelectController?.enableMultiSelectView == true;
    return MenuTheme(
      data: MenuThemeData(style: appMenuStyle),
      child: MenuAnchor(
        consumeOutsideTap: true,
        style: appMenuStyle,
        menuChildren: _menuChildren(context),
        builder: (context, controller, _) => DirectionalListItemEntrance(
          identity: widget.album,
          child: InteractiveSurfaceMotion(
            enabled:
                widget.view == ContentView.table &&
                AppSettings.instance.enableInteractiveSurfaceMotion,
            child: _tileSurface(
              context,
              controller,
              scheme: scheme,
              isSelected: isSelected,
              isMultiSelectView: isMultiSelectView,
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _menuChildren(BuildContext context) {
    final menuItemStyle = appMenuItemStyle;
    final hasWorks = widget.album.works.isNotEmpty;
    return [
      MenuItemButton(
        style: menuItemStyle,
        onPressed: hasWorks
            ? () =>
                  context.push(app_paths.ALBUM_DETAIL_PAGE, extra: widget.album)
            : null,
        leadingIcon: const Icon(Symbols.open_in_new),
        child: const Text('打开'),
      ),
      if (widget.multiSelectController != null)
        MenuItemButton(
          style: menuItemStyle,
          onPressed: () {
            widget.multiSelectController!.useMultiSelectView(true);
            widget.multiSelectController!.select(widget.album);
          },
          leadingIcon: const Icon(Symbols.select),
          child: const Text('多选'),
        ),
    ];
  }

  Widget _tileSurface(
    BuildContext context,
    MenuController controller, {
    required ColorScheme scheme,
    required bool isSelected,
    required bool isMultiSelectView,
  }) {
    return AnimatedContainer(
      duration: MotionDuration.fast,
      curve: MotionCurve.standard,
      decoration: BoxDecoration(
        color: isSelected ? scheme.secondaryContainer : Colors.transparent,
        borderRadius: AppRadius.smCircular,
      ),
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          hoverColor: widget.view == ContentView.list
              ? scheme.onSurface.withValues(alpha: Alpha.hover)
              : Colors.transparent,
          onTap: () =>
              _onTap(context, controller, isMultiSelectView, isSelected),
          onLongPress: () => _onLongPress(isMultiSelectView),
          onSecondaryTapDown: (details) =>
              _onSecondaryTap(controller, details, isMultiSelectView),
          borderRadius: AppRadius.smCircular,
          child: Stack(
            children: [
              widget.view == ContentView.list
                  ? _listBody(scheme, isSelected, isMultiSelectView)
                  : _gridBody(scheme),
              if (isMultiSelectView && widget.view != ContentView.list)
                _gridCheckbox(isSelected),
            ],
          ),
        ),
      ),
    );
  }

  void _onTap(
    BuildContext context,
    MenuController controller,
    bool isMultiSelectView,
    bool isSelected,
  ) {
    if (controller.isOpen) {
      controller.close();
      return;
    }
    if (!isMultiSelectView) {
      if (widget.album.works.isNotEmpty) {
        context.push(app_paths.ALBUM_DETAIL_PAGE, extra: widget.album);
      }
      return;
    }
    if (isSelected) {
      widget.multiSelectController?.unselect(widget.album);
    } else {
      widget.multiSelectController?.select(widget.album);
    }
  }

  void _onLongPress(bool isMultiSelectView) {
    if (widget.multiSelectController == null) return;
    if (isMultiSelectView) return;
    widget.multiSelectController!.useMultiSelectView(true);
    widget.multiSelectController!.select(widget.album);
  }

  void _onSecondaryTap(
    MenuController controller,
    TapDownDetails details,
    bool isMultiSelectView,
  ) {
    if (isMultiSelectView) return;
    controller.open(position: details.localPosition.translate(0, -140));
  }

  Widget _coverWidget(ColorScheme scheme) {
    final placeholder = Icon(
      Symbols.queue_music,
      size: 48,
      color: scheme.onSurface,
    );
    final hasWorks = widget.album.works.isNotEmpty;
    final cachedCover = hasWorks
        ? widget.album.cachedThumbnailCover(size: _coverSize)
        : null;
    return ScrollAwareFutureBuilder<ImageProvider?>(
      identity: _currentCoverIdentity,
      initialData: cachedCover,
      future: () => hasWorks
          ? widget.album.thumbnailCover(size: _coverSize)
          : Future<ImageProvider?>.value(null),
      builder: (context, snapshot) =>
          _coverSnapshot(snapshot, scheme, placeholder),
    );
  }

  Widget _coverSnapshot(
    AsyncSnapshot<ImageProvider?> snapshot,
    ColorScheme scheme,
    Widget placeholder,
  ) {
    final borderRadius = widget.view == ContentView.list
        ? AppRadius.smCircular
        : const BorderRadius.vertical(top: Radius.circular(8.0));
    if (snapshot.data == null) {
      return snapshot.connectionState == ConnectionState.done
          ? placeholder
          : ClipRRect(
              borderRadius: borderRadius,
              child: Container(
                color: scheme.surfaceContainerHighest.withValues(alpha: 0.22),
              ),
            );
    }
    Widget image = Image(
      image: snapshot.data!,
      width: widget.view == ContentView.list ? 48.0 : null,
      height: widget.view == ContentView.list ? 48.0 : null,
      errorBuilder: (_, _, _) => placeholder,
      fit: BoxFit.cover,
      gaplessPlayback: true,
    );
    if (widget.view != ContentView.list) {
      image = CoverPointerSheen(
        enabled: AppSettings.instance.enableCoverPointerSheen,
        child: image,
      );
    }
    return ClipRRect(borderRadius: borderRadius, child: image);
  }

  Widget _listBody(
    ColorScheme scheme,
    bool isSelected,
    bool isMultiSelectView,
  ) {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Row(
        children: [
          _coverWidget(scheme),
          Flexible(
            child: Padding(
              padding: const EdgeInsets.only(left: 12.0),
              child: Text(
                widget.album.name,
                softWrap: false,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: scheme.onSurface),
              ),
            ),
          ),
          if (isMultiSelectView)
            Checkbox(
              value: isSelected,
              onChanged: (v) => _onCheckbox(v == true),
            ),
        ],
      ),
    );
  }

  Widget _gridBody(ColorScheme scheme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: SizedBox(width: double.infinity, child: _coverWidget(scheme)),
        ),
        _gridTitle(scheme),
      ],
    );
  }

  Widget _gridTitle(ColorScheme scheme) {
    final hasWorks = widget.album.works.isNotEmpty;
    return ScrollAwareFutureBuilder<AlbumColor?>(
      identity: '$_currentCoverIdentity|color',
      future: () => hasWorks
          ? AlbumColorCache.instance.getAlbumColor(widget.album)
          : Future<AlbumColor?>.value(null),
      builder: (context, snapshot) {
        if (snapshot.data == null) {
          return Padding(
            padding: const EdgeInsets.fromLTRB(4.0, 8.0, 4.0, 4.0),
            child: Text(
              widget.album.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: scheme.onSurface,
                fontWeight: AppType.weightBold,
              ),
            ),
          );
        }
        return Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
          decoration: BoxDecoration(
            color: snapshot.data!.primary,
            borderRadius: const BorderRadius.vertical(
              bottom: Radius.circular(8.0),
            ),
          ),
          child: Text(
            widget.album.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: snapshot.data!.onPrimary,
              fontWeight: AppType.weightBold,
            ),
          ),
        );
      },
    );
  }

  Widget _gridCheckbox(bool isSelected) {
    return Positioned(
      top: 6,
      right: 6,
      child: Material(
        type: MaterialType.transparency,
        child: Checkbox(
          value: isSelected,
          onChanged: (v) => _onCheckbox(v == true),
        ),
      ),
    );
  }

  void _onCheckbox(bool selected) {
    if (selected) {
      widget.multiSelectController?.select(widget.album);
    } else {
      widget.multiSelectController?.unselect(widget.album);
    }
  }
}
