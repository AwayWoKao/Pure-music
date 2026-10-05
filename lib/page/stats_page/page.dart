import 'package:pure_music/component/list_locate_buttons.dart';
import 'package:pure_music/component/motion.dart';
import 'package:pure_music/component/stacked_list_view.dart';
import 'package:pure_music/core/design_tokens.dart';
import 'package:pure_music/core/settings.dart';
import 'package:pure_music/library/audio_library.dart';
import 'package:pure_music/native/rust/api/library_db.dart' as rust_library_db;
import 'package:pure_music/page/page_scaffold.dart';
import 'package:pure_music/play_service/play_service.dart';
import 'package:pure_music/core/paths.dart' as app_paths;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';

class StatsPage extends StatefulWidget {
  const StatsPage({super.key});

  @override
  State<StatsPage> createState() => _StatsPageState();
}

class _StatsPageState extends State<StatsPage> {
  static const _rankedTrackExtent = 68.0;
  static const _highlightLimit = 6;
  static const _unheardPreviewLimit = 8;

  List<rust_library_db.PlayCountEntry>? _topPlayed;
  bool _loading = true;
  bool _loadFailed = false;
  int _loadRequestToken = 0;
  late final ValueListenable<int> _playCountRevision;
  final _scrollController = SmoothScrollController();
  double _rankedLeadingExtent = 0;

  @override
  void initState() {
    super.initState();
    _playCountRevision = PlayService.instance.playbackService.playCountRevision;
    _playCountRevision.addListener(_onStatsSourceChanged);
    AudioLibrary.libraryVersion.addListener(_onStatsSourceChanged);
    _loadStats();
  }

  void _onStatsSourceChanged() {
    if (!mounted) return;
    _loadStats();
  }

  Future<void> _loadStats() async {
    final requestToken = ++_loadRequestToken;
    if (!_loading) {
      setState(() {
        _loading = true;
        _loadFailed = false;
      });
    }
    try {
      final supportPath = (await getAppDataDir()).path;
      final top = await rust_library_db.getTopPlayed(
        indexPath: supportPath,
        limit: -1,
      );
      final visibleTop = top
          .where(
            (entry) => AudioLibrary.instance.audioByPath(entry.path) != null,
          )
          .toList(growable: false);
      if (!mounted || requestToken != _loadRequestToken) return;
      setState(() {
        _topPlayed = visibleTop;
        _loading = false;
      });
    } catch (_) {
      if (!mounted || requestToken != _loadRequestToken) return;
      setState(() {
        _loading = false;
        _loadFailed = true;
      });
    }
  }

  @override
  void dispose() {
    _playCountRevision.removeListener(_onStatsSourceChanged);
    AudioLibrary.libraryVersion.removeListener(_onStatsSourceChanged);
    _scrollController.dispose();
    super.dispose();
  }

  /// 当前正在播放乐曲在"最常播放"排行中的索引；不在排行内时返回 null。
  int? _locateTargetAt() {
    final nowPlaying = PlayService.instance.playbackService.nowPlaying;
    final top = _topPlayed;
    if (nowPlaying == null || top == null || top.isEmpty) return null;
    final targetAt = top
        .take(100)
        .toList()
        .indexWhere((entry) => entry.path == nowPlaying.path);
    return targetAt < 0 ? null : targetAt;
  }

  /// 平滑滚动到指定位置。行滚出视口后 key 会被卸掉，所以按偏移定位，不依赖 item context。
  void _smoothScrollTo(double offset) {
    if (!_scrollController.hasClients) return;
    final position = _scrollController.position;
    if (position is SmoothScrollPosition) {
      position.smoothScrollTo(offset);
      return;
    }
    _scrollController.animateTo(
      offset.clamp(position.minScrollExtent, position.maxScrollExtent),
      duration: const Duration(milliseconds: 250),
      curve: Curves.fastOutSlowIn,
    );
  }

  /// 定位到排行中的指定行。
  void _scrollToIndex(int targetAt) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scrollController.hasClients) return;
      _smoothScrollTo(_rankedLeadingExtent + targetAt * _rankedTrackExtent);
    });
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return PageScaffold(
      title: '统计',
      subtitle: '曲库与收听概览',
      actions: [
        IconButton.filledTonal(
          icon: const Icon(Symbols.refresh),
          tooltip: '刷新',
          onPressed: _loading ? null : _loadStats,
          style: IconButton.styleFrom(
            shape: RoundedRectangleBorder(borderRadius: AppRadius.smCircular),
          ),
        ),
      ],
      body: Stack(
        children: [
          Positioned.fill(child: _buildBody(scheme)),
          ListLocateButtons(
            controller: _scrollController,
            locateTargetAt: _locateTargetAt,
            onScrollToIndex: _scrollToIndex,
          ),
        ],
      ),
    );
  }

  Widget _buildBody(ColorScheme scheme) {
    final library = AudioLibrary.instance;
    final audios = library.audioCollection;
    final data = _topPlayed;
    final rankedTracks = (data ?? const <rust_library_db.PlayCountEntry>[])
        .take(100)
        .toList();
    final stacked =
        AppSettings.instance.enableStackedScrollEffect &&
        !MediaQuery.disableAnimationsOf(context);
    return CustomScrollView(
      controller: _scrollController,
      physics: stacked ? const SmoothScrollPhysics() : null,
      slivers: [
        _overviewSliver(scheme, library, audios, data),
        ..._artistSlivers(scheme, audios, data),
        SliverToBoxAdapter(
          child: _buildSectionTitle(
            scheme,
            title: '最常播放',
            subtitle: _rankedSubtitle(data, rankedTracks),
          ),
        ),
        _rankedSliver(scheme, rankedTracks, stacked),
        ..._unheardSlivers(scheme, audios),
        const SliverToBoxAdapter(child: SizedBox(height: Spacing.bottomNav)),
      ],
    );
  }

  Widget _overviewSliver(
    ColorScheme scheme,
    AudioLibrary library,
    List<Audio> audios,
    List<rust_library_db.PlayCountEntry>? data,
  ) {
    final totalPlays = data == null
        ? audios.fold<int>(0, (sum, audio) => sum + audio.playCount)
        : data.fold<int>(0, (sum, entry) => sum + entry.playCount);
    final playedTracks = data == null
        ? audios.where((audio) => audio.playCount > 0).length
        : data.length;
    return SliverPadding(
      padding: const EdgeInsets.fromLTRB(Spacing.sm, Spacing.sm, Spacing.sm, 0),
      sliver: SliverToBoxAdapter(
        child: _buildOverview(
          scheme,
          totalPlays: totalPlays,
          playedTracks: playedTracks,
          totalTracks: audios.length,
          artistCount: library.artistCollection.length,
          albumCount: library.albumCollection.length,
          estimatedListen: _estimatedListenSeconds(audios, data),
        ),
      ),
    );
  }

  List<Widget> _artistSlivers(
    ColorScheme scheme,
    List<Audio> audios,
    List<rust_library_db.PlayCountEntry>? data,
  ) {
    final topArtists = _buildTopArtists(audios, data);
    final topAlbums = _buildTopAlbums(audios, data);
    return [
      if (topArtists.isNotEmpty)
        SliverToBoxAdapter(
          child: _buildNamedSection(
            scheme,
            title: '常听艺术家',
            items: topArtists,
            accent: scheme.tertiary,
            onTap: _openArtist,
          ),
        ),
      if (topAlbums.isNotEmpty)
        SliverToBoxAdapter(
          child: _buildNamedSection(
            scheme,
            title: '常听专辑',
            items: topAlbums,
            accent: scheme.secondary,
            onTap: _openAlbum,
          ),
        ),
    ];
  }

  String _rankedSubtitle(
    List<rust_library_db.PlayCountEntry>? data,
    List<rust_library_db.PlayCountEntry> rankedTracks,
  ) {
    if (_loading) return '正在更新';
    if (_loadFailed && rankedTracks.isNotEmpty) return '刷新失败，显示上次结果';
    if (data != null && data.length > rankedTracks.length) {
      return '前 ${rankedTracks.length} 首曲目';
    }
    return '${rankedTracks.length} 首曲目';
  }

  Widget _rankedSliver(
    ColorScheme scheme,
    List<rust_library_db.PlayCountEntry> rankedTracks,
    bool stacked,
  ) {
    if (_loading) {
      return SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: Spacing.sm),
          child: LinearProgressIndicator(
            minHeight: 2,
            backgroundColor: scheme.surfaceContainerHighest.withValues(
              alpha: 0.35,
            ),
          ),
        ),
      );
    }
    if (_loadFailed && rankedTracks.isEmpty) {
      return SliverToBoxAdapter(
        child: _buildMessage(
          scheme,
          icon: Symbols.sync_problem,
          text: '播放记录读取失败',
        ),
      );
    }
    if (rankedTracks.isEmpty) {
      return SliverToBoxAdapter(
        child: _buildMessage(
          scheme,
          icon: Symbols.bar_chart,
          text: '播放几首歌曲后，这里会出现排行',
        ),
      );
    }
    return SliverLayoutBuilder(
      builder: (context, constraints) =>
          _rankedList(scheme, rankedTracks, stacked, constraints),
    );
  }

  Widget _rankedList(
    ColorScheme scheme,
    List<rust_library_db.PlayCountEntry> rankedTracks,
    bool stacked,
    SliverConstraints constraints,
  ) {
    _rankedLeadingExtent = constraints.precedingScrollExtent;
    return SliverFixedExtentList.builder(
      itemExtent: _rankedTrackExtent,
      itemCount: rankedTracks.length,
      itemBuilder: (context, index) => StackedSliverItem(
        controller: _scrollController,
        rowIndex: index,
        itemExtent: _rankedTrackExtent,
        leadingScrollExtent: constraints.precedingScrollExtent,
        enabled: stacked,
        child: _buildRow(
          scheme,
          rankedTracks[index],
          index: index,
          maxPlays: rankedTracks.first.playCount,
        ),
      ),
    );
  }

  Widget _buildOverview(
    ColorScheme scheme, {
    required int totalPlays,
    required int playedTracks,
    required int totalTracks,
    required int artistCount,
    required int albumCount,
    required int estimatedListen,
  }) {
    return ListenableBuilder(
      listenable: AppSettings.listMotionNotifier,
      builder: (context, _) => Container(
        padding: const EdgeInsets.all(Spacing.md),
        decoration: BoxDecoration(
          color: scheme.surfaceContainerLow,
          borderRadius: AppRadius.smCircular,
          border: Border.all(
            color: scheme.outlineVariant.withValues(alpha: 0.45),
          ),
        ),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final modeWidth = SidebarMotionScope.layoutWidthOf(
              context,
              constraints.maxWidth,
            );
            final columns = modeWidth >= 1000
                ? 4
                : modeWidth >= 520
                ? 2
                : 1;
            final width =
                (constraints.maxWidth - (columns - 1) * Spacing.sm) / columns;
            return Wrap(
              spacing: Spacing.sm,
              runSpacing: Spacing.sm,
              children: _overviewMetrics(
                scheme,
                width: width,
                totalPlays: totalPlays,
                playedTracks: playedTracks,
                totalTracks: totalTracks,
                artistCount: artistCount,
                albumCount: albumCount,
                estimatedListen: estimatedListen,
              ),
            );
          },
        ),
      ),
    );
  }

  List<Widget> _overviewMetrics(
    ColorScheme scheme, {
    required double width,
    required int totalPlays,
    required int playedTracks,
    required int totalTracks,
    required int artistCount,
    required int albumCount,
    required int estimatedListen,
  }) {
    return [
      _overviewMetric(
        scheme,
        width: width,
        icon: Symbols.play_arrow,
        color: scheme.primary,
        label: '累计播放',
        value: formatCount(totalPlays),
      ),
      _overviewMetric(
        scheme,
        width: width,
        icon: Symbols.library_music,
        color: scheme.tertiary,
        label: '听过的曲目',
        value: '$playedTracks / $totalTracks',
      ),
      _overviewMetric(
        scheme,
        width: width,
        icon: Symbols.album,
        color: scheme.secondary,
        label: '艺术家 / 专辑',
        value: '$artistCount / $albumCount',
      ),
      _overviewMetric(
        scheme,
        width: width,
        icon: Symbols.schedule,
        color: scheme.onSurfaceVariant,
        label: '预估收听',
        value: formatDuration(estimatedListen),
      ),
    ];
  }

  Widget _overviewMetric(
    ColorScheme scheme, {
    required double width,
    required IconData icon,
    required Color color,
    required String label,
    required String value,
  }) {
    return SizedBox(
      width: width,
      height: 68,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: Spacing.sm),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: AppRadius.smCircular,
              ),
              child: Icon(icon, size: 20, color: color),
            ),
            const SizedBox(width: Spacing.md),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _AnimatedMetricValue(value, color: scheme.onSurface),
                  _metricLabel(scheme, label),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _metricLabel(ColorScheme scheme, String label) {
    return Text(
      label,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(
        fontSize: AppType.caption,
        color: scheme.onSurfaceVariant,
      ),
    );
  }

  Widget _buildNamedSection(
    ColorScheme scheme, {
    required String title,
    required List<_NamedPlayStat> items,
    required Color accent,
    required void Function(String name) onTap,
  }) {
    final maxPlays = items.first.playCount;
    return Padding(
      padding: const EdgeInsets.fromLTRB(Spacing.sm, Spacing.xl, Spacing.sm, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: AppType.sectionTitle,
              fontWeight: AppType.weightSemibold,
              color: scheme.onSurface,
            ),
          ),
          const SizedBox(height: Spacing.md),
          LayoutBuilder(
            builder: (context, constraints) =>
                _namedWrap(scheme, items, maxPlays, accent, onTap, constraints),
          ),
        ],
      ),
    );
  }

  Widget _namedWrap(
    ColorScheme scheme,
    List<_NamedPlayStat> items,
    int maxPlays,
    Color accent,
    void Function(String name) onTap,
    BoxConstraints constraints,
  ) {
    final modeWidth = SidebarMotionScope.layoutWidthOf(
      context,
      constraints.maxWidth,
    );
    final columns = modeWidth >= 980
        ? 3
        : modeWidth >= 560
        ? 2
        : 1;
    final width = (constraints.maxWidth - (columns - 1) * Spacing.lg) / columns;
    return Wrap(
      spacing: Spacing.lg,
      runSpacing: Spacing.md,
      children: [
        for (var i = 0; i < items.length; i++)
          SizedBox(
            width: width,
            child: _buildNamedStat(
              scheme,
              items[i],
              rank: i + 1,
              maxPlays: maxPlays,
              accent: accent,
              onTap: onTap,
            ),
          ),
      ],
    );
  }

  Widget _buildNamedStat(
    ColorScheme scheme,
    _NamedPlayStat item, {
    required int rank,
    required int maxPlays,
    required Color accent,
    required void Function(String name) onTap,
  }) {
    final fraction = maxPlays > 0 ? item.playCount / maxPlays : 0.0;
    return Material(
      color: Colors.transparent,
      borderRadius: AppRadius.smCircular,
      child: InkWell(
        hoverColor: scheme.onSurface.withValues(alpha: Alpha.hover),
        borderRadius: AppRadius.smCircular,
        onTap: () => onTap(item.name),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            children: [
              _namedRank(scheme, rank, accent),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _namedTitleRow(scheme, item),
                    const SizedBox(height: 6),
                    _namedBar(scheme, fraction, accent),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _namedRank(ColorScheme scheme, int rank, Color accent) {
    return SizedBox(
      width: 28,
      child: Text(
        rank.toString().padLeft(2, '0'),
        style: TextStyle(
          fontSize: AppType.caption,
          fontWeight: AppType.weightSemibold,
          color: rank <= 3 ? accent : scheme.onSurfaceVariant,
        ),
      ),
    );
  }

  Widget _namedTitleRow(ColorScheme scheme, _NamedPlayStat item) {
    return Row(
      children: [
        Expanded(
          child: Text(
            item.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: AppType.body,
              fontWeight: AppType.weightMedium,
              color: scheme.onSurface,
            ),
          ),
        ),
        const SizedBox(width: Spacing.sm),
        Text(
          '${formatCount(item.playCount)} 次',
          style: TextStyle(
            fontSize: AppType.caption,
            color: scheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }

  Widget _namedBar(ColorScheme scheme, double fraction, Color accent) {
    return ClipRRect(
      borderRadius: AppRadius.xsCircular,
      child: LinearProgressIndicator(
        value: fraction,
        minHeight: 3,
        backgroundColor: scheme.surfaceContainerHighest.withValues(alpha: 0.5),
        valueColor: AlwaysStoppedAnimation<Color>(
          accent.withValues(alpha: 0.72),
        ),
      ),
    );
  }

  Widget _buildSectionTitle(
    ColorScheme scheme, {
    required String title,
    required String subtitle,
  }) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        Spacing.sm,
        Spacing.xl,
        Spacing.sm,
        Spacing.md,
      ),
      child: Row(
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: AppType.sectionTitle,
              fontWeight: AppType.weightSemibold,
              color: scheme.onSurface,
            ),
          ),
          const Spacer(),
          Text(
            subtitle,
            style: TextStyle(
              fontSize: AppType.caption,
              color: scheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessage(
    ColorScheme scheme, {
    required IconData icon,
    required String text,
  }) {
    return SizedBox(
      height: 180,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 40,
              color: scheme.onSurfaceVariant.withValues(alpha: 0.45),
            ),
            const SizedBox(height: Spacing.md),
            Text(
              text,
              style: TextStyle(
                color: scheme.onSurfaceVariant,
                fontSize: AppType.body,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRow(
    ColorScheme scheme,
    rust_library_db.PlayCountEntry entry, {
    required int index,
    required int maxPlays,
  }) {
    final fraction = maxPlays > 0 ? entry.playCount / maxPlays : 0.0;
    final library = AudioLibrary.instance;
    final audio = library.audioByPath(entry.path);
    return DirectionalListItemEntrance(
      identity: entry.path,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: Spacing.sm,
          vertical: 2,
        ),
        child: SizedBox(
          height: 64,
          child: Material(
            color: Colors.transparent,
            borderRadius: AppRadius.smCircular,
            child: InkWell(
              hoverColor: scheme.onSurface.withValues(alpha: Alpha.hover),
              borderRadius: AppRadius.smCircular,
              onTap: audio == null ? null : () => _playAudio(library, audio),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final modeWidth = SidebarMotionScope.layoutWidthOf(
                    context,
                    constraints.maxWidth,
                  );
                  return _rowContent(
                    scheme,
                    entry,
                    audio,
                    index: index,
                    fraction: fraction,
                    showAlbum: modeWidth >= 760,
                    albumWidth: modeWidth >= 1100 ? 260.0 : 180.0,
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _playAudio(AudioLibrary library, Audio audio) {
    final audioIndex = library.audioCollection.indexOf(audio);
    if (audioIndex < 0) return;
    PlayService.instance.playbackService.play(
      audioIndex,
      library.audioCollection,
    );
  }

  Widget _rowContent(
    ColorScheme scheme,
    rust_library_db.PlayCountEntry entry,
    Audio? audio, {
    required int index,
    required double fraction,
    required bool showAlbum,
    required double albumWidth,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: Spacing.sm),
      child: Row(
        children: [
          _rankLabel(scheme, index),
          _CoverWidget(audio: audio),
          const SizedBox(width: Spacing.md),
          Expanded(child: _trackTexts(scheme, entry)),
          if (showAlbum) ...[
            const SizedBox(width: Spacing.lg),
            SizedBox(
              width: albumWidth,
              child: Text(
                audio?.album ?? '',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: AppType.body,
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ),
          ],
          const SizedBox(width: Spacing.lg),
          _buildCount(scheme, entry.playCount, fraction),
        ],
      ),
    );
  }

  Widget _rankLabel(ColorScheme scheme, int index) {
    return SizedBox(
      width: 36,
      child: Text(
        '${index + 1}',
        textAlign: TextAlign.center,
        style: TextStyle(
          fontSize: AppType.caption,
          fontWeight: index < 3 ? AppType.weightBold : AppType.weightRegular,
          color: index < 3 ? scheme.primary : scheme.onSurfaceVariant,
        ),
      ),
    );
  }

  Widget _trackTexts(ColorScheme scheme, rust_library_db.PlayCountEntry entry) {
    return _titleArtistTexts(scheme, entry.title, entry.artist);
  }

  Widget _titleArtistTexts(ColorScheme scheme, String title, String artist) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: AppType.subtitle,
            color: scheme.onSurface,
            fontWeight: AppType.weightMedium,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          artist,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: AppType.body,
            color: scheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }

  Widget _buildCount(ColorScheme scheme, int count, double fraction) {
    return SizedBox(
      width: 84,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            '${formatCount(count)} 次',
            style: TextStyle(
              fontSize: AppType.body,
              fontWeight: AppType.weightSemibold,
              color: scheme.primary,
            ),
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: AppRadius.xsCircular,
            child: LinearProgressIndicator(
              value: fraction,
              minHeight: 3,
              backgroundColor: scheme.primaryContainer.withValues(alpha: 0.3),
              valueColor: AlwaysStoppedAnimation<Color>(
                scheme.primary.withValues(alpha: 0.68),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _openArtist(String name) {
    final artist = AudioLibrary.instance.artistCollection[name];
    if (artist == null) return;
    DirectionalTabView.suppressNextIndexMotion();
    context.push(app_paths.ARTIST_DETAIL_PAGE, extra: artist);
  }

  void _openAlbum(String name) {
    final album = AudioLibrary.instance.albumCollection[name];
    if (album == null) return;
    DirectionalTabView.suppressNextIndexMotion();
    context.push(app_paths.ALBUM_DETAIL_PAGE, extra: album);
  }

  int _estimatedListenSeconds(
    List<Audio> audios,
    List<rust_library_db.PlayCountEntry>? data,
  ) {
    if (data == null) {
      return audios.fold<int>(
        0,
        (sum, audio) => sum + audio.playCount * audio.duration,
      );
    }
    var total = 0;
    for (final entry in data) {
      final audio = AudioLibrary.instance.audioByPath(entry.path);
      if (audio == null) continue;
      total += entry.playCount * audio.duration;
    }
    return total;
  }

  List<Widget> _unheardSlivers(ColorScheme scheme, List<Audio> audios) {
    final unheard = [
      for (final audio in audios)
        if (audio.playCount <= 0) audio,
    ];
    if (unheard.isEmpty) return const [];
    unheard.sort((a, b) {
      final byCreated = a.created.compareTo(b.created);
      return byCreated != 0 ? byCreated : a.title.compareTo(b.title);
    });
    final preview = unheard.take(_unheardPreviewLimit).toList(growable: false);
    final subtitle = unheard.length > preview.length
        ? '共 ${unheard.length} 首，入库较早的 ${preview.length} 首'
        : '${preview.length} 首曲目';
    return [
      SliverToBoxAdapter(
        child: _buildSectionTitle(scheme, title: '从未播放', subtitle: subtitle),
      ),
      SliverToBoxAdapter(
        child: StackedEffectScope(
          child: Column(
            children: [
              for (final audio in preview) _buildUnheardRow(scheme, audio),
            ],
          ),
        ),
      ),
    ];
  }

  Widget _buildUnheardRow(ColorScheme scheme, Audio audio) {
    return DirectionalListItemEntrance(
      identity: audio.path,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: Spacing.sm,
          vertical: 2,
        ),
        child: SizedBox(
          height: 64,
          child: Material(
            color: Colors.transparent,
            borderRadius: AppRadius.smCircular,
            child: InkWell(
              hoverColor: scheme.onSurface.withValues(alpha: Alpha.hover),
              borderRadius: AppRadius.smCircular,
              onTap: () => _playAudio(AudioLibrary.instance, audio),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: Spacing.sm),
                child: Row(
                  children: [
                    _CoverWidget(audio: audio),
                    const SizedBox(width: Spacing.md),
                    Expanded(
                      child: _titleArtistTexts(
                        scheme,
                        audio.title,
                        audio.artist,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  List<_NamedPlayStat> _buildTopArtists(
    List<Audio> audios,
    List<rust_library_db.PlayCountEntry>? entries,
  ) {
    final counts = <String, int>{};
    final source = entries == null
        ? audios
              .where((audio) => audio.playCount > 0)
              .map((audio) => (audio, audio.artist, audio.playCount))
        : entries.map((entry) {
            final audio = AudioLibrary.instance.audioByPath(entry.path);
            return (audio, entry.artist, entry.playCount);
          });
    for (final item in source) {
      final audio = item.$1;
      final artists = audio != null && audio.splitedArtists.isNotEmpty
          ? audio.splitedArtists
          : <String>[item.$2];
      for (final artist in artists) {
        final name = artist.trim();
        if (name.isEmpty) continue;
        counts.update(
          name,
          (value) => value + item.$3,
          ifAbsent: () => item.$3,
        );
      }
    }
    final result =
        counts.entries
            .map((entry) => _NamedPlayStat(entry.key, entry.value))
            .toList()
          ..sort((a, b) {
            final byCount = b.playCount.compareTo(a.playCount);
            return byCount != 0 ? byCount : a.name.compareTo(b.name);
          });
    return result.take(_highlightLimit).toList(growable: false);
  }

  List<_NamedPlayStat> _buildTopAlbums(
    List<Audio> audios,
    List<rust_library_db.PlayCountEntry>? entries,
  ) {
    final counts = <String, int>{};
    final source = entries == null
        ? audios
              .where((audio) => audio.playCount > 0)
              .map((audio) => (audio.album, audio.playCount))
        : entries.map((entry) {
            final audio = AudioLibrary.instance.audioByPath(entry.path);
            return (audio?.album ?? entry.album, entry.playCount);
          });
    for (final item in source) {
      final name = item.$1;
      if (name.trim().isEmpty) continue;
      counts.update(name, (value) => value + item.$2, ifAbsent: () => item.$2);
    }
    final result =
        counts.entries
            .map((entry) => _NamedPlayStat(entry.key, entry.value))
            .toList()
          ..sort((a, b) {
            final byCount = b.playCount.compareTo(a.playCount);
            return byCount != 0 ? byCount : a.name.compareTo(b.name);
          });
    return result.take(_highlightLimit).toList(growable: false);
  }
}

class _CoverWidget extends StatefulWidget {
  final Audio? audio;

  const _CoverWidget({required this.audio});

  @override
  State<_CoverWidget> createState() => _CoverWidgetState();
}

class _CoverWidgetState extends State<_CoverWidget> {
  Uint8List? _cached;

  @override
  void initState() {
    super.initState();
    _cached = widget.audio?.smallCoverBytes;
    if (_cached == null) _load();
  }

  @override
  void didUpdateWidget(_CoverWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (identical(oldWidget.audio, widget.audio)) return;
    _cached = widget.audio?.smallCoverBytes;
    if (_cached == null) _load();
  }

  Future<void> _load() async {
    final audio = widget.audio;
    final bytes = await audio?.loadSmallCoverBytes();
    if (mounted && identical(widget.audio, audio) && bytes != null) {
      setState(() => _cached = bytes);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_cached != null) {
      return ClipRRect(
        borderRadius: AppRadius.smCircular,
        child: Image.memory(
          _cached!,
          width: 48,
          height: 48,
          fit: BoxFit.cover,
          gaplessPlayback: true,
          errorBuilder: (_, _, _) => _placeholder(context),
        ),
      );
    }
    return _placeholder(context);
  }

  Widget _placeholder(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: 48,
      height: 48,
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

class _AnimatedMetricValue extends StatelessWidget {
  const _AnimatedMetricValue(this.value, {required this.color});

  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final motionEnabled = AppSettings.instance.enableDataTransitionMotion;
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    final animate = motionEnabled;
    final duration = !animate
        ? Duration.zero
        : reduceMotion
        ? MotionDuration.fast
        : MotionDuration.xFast;
    return AnimatedSwitcher(
      duration: duration,
      switchInCurve: MotionCurve.entrance,
      switchOutCurve: MotionCurve.standard,
      layoutBuilder: (currentChild, previousChildren) => Stack(
        alignment: Alignment.centerLeft,
        children: [...previousChildren, ?currentChild],
      ),
      transitionBuilder: (child, animation) {
        if (!animate) return child;
        if (reduceMotion) {
          return FadeTransition(opacity: animation, child: child);
        }
        return FadeTransition(
          opacity: animation,
          child: SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0, 0.12),
              end: Offset.zero,
            ).animate(animation),
            child: child,
          ),
        );
      },
      child: Text(
        value,
        key: ValueKey(value),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontSize: AppType.pageTitle,
          fontWeight: AppType.weightSemibold,
          color: color,
        ),
      ),
    );
  }
}

class _NamedPlayStat {
  const _NamedPlayStat(this.name, this.playCount);

  final String name;
  final int playCount;
}

String formatCount(int value) {
  if (value >= 10000) {
    return '${_trimCompact(value / 10000)} 万';
  }
  if (value >= 1000) {
    return '${_trimCompact(value / 1000)} 千';
  }
  return value.toString();
}

String _trimCompact(double value) {
  final formatted = value.toStringAsFixed(1);
  return formatted.endsWith('.0')
      ? formatted.substring(0, formatted.length - 2)
      : formatted;
}

String formatDuration(int seconds) {
  if (seconds <= 0) return '0 分钟';
  final totalMinutes = seconds ~/ 60;
  final days = totalMinutes ~/ (24 * 60);
  final hours = totalMinutes.remainder(24 * 60) ~/ 60;
  final minutes = totalMinutes.remainder(60);
  if (days > 0) return '$days 天 $hours 小时';
  if (hours > 0) return '$hours 小时 $minutes 分钟';
  return '$minutes 分钟';
}
