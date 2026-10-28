import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'
    show rootBundle, Clipboard, ClipboardData, HapticFeedback;
import 'package:just_audio/just_audio.dart';
import 'package:just_audio_background/just_audio_background.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ─────────────────────────────────────────────────────────
// Global audio service — one player shared across the app
// ─────────────────────────────────────────────────────────
class AudioService {
  AudioService._();
  static final AudioService instance = AudioService._();

  static const String _cdnBase =
      'https://cdn.islamic.network/quran/audio-surah';
  static const String _edition = 'ar.alafasy';
  static const String _bitrate = '128';

  final AudioPlayer player = AudioPlayer();
  final Dio dio = Dio();

  final ValueNotifier<int?> currentSurah = ValueNotifier<int?>(null);
  final ValueNotifier<Map<int, double?>> downloads =
      ValueNotifier<Map<int, double?>>({});

  String remoteUrl(int surahNumber) {
    return '$_cdnBase/$_bitrate/$_edition/$surahNumber.mp3';
  }

  Future<File> _localFile(int surahNumber) async {
    final dir = await getApplicationDocumentsDirectory();
    return File(
        '${dir.path}/surah_${surahNumber.toString().padLeft(3, '0')}.mp3');
  }

  Future<bool> isDownloaded(int surahNumber) async {
    if (kIsWeb) return false;
    final file = await _localFile(surahNumber);
    return file.exists();
  }

  /// Loads the audio source into the player but does NOT play it.
  /// Returns true if the source loaded successfully.
  Future<bool> loadAudio({
    required int surahNumber,
    required String surahNameEn,
    required String surahNameAr,
    required int totalAyahs,
  }) async {
    final mediaItem = MediaItem(
      id: 'surah_$surahNumber',
      title: '$surahNameEn · $surahNameAr',
      album: 'Holy Quran',
      artist: 'Mishary Alafasy',
      displayTitle: surahNameEn,
      displaySubtitle: '$totalAyahs ayahs · Mishary Alafasy',
      artUri: Uri.parse('asset:///assets/image.png'),
    );

    AudioSource source;

    if (kIsWeb) {
      source =
          AudioSource.uri(Uri.parse(remoteUrl(surahNumber)), tag: mediaItem);
    } else {
      final local = await _localFile(surahNumber);
      final isLocal = await local.exists();

      if (isLocal) {
        source = AudioSource.file(local.path, tag: mediaItem);
      } else {
        source =
            AudioSource.uri(Uri.parse(remoteUrl(surahNumber)), tag: mediaItem);
      }
    }

    try {
      currentSurah.value = surahNumber;
      await player.setAudioSource(source);
      return true;
    } catch (e) {
      debugPrint('Error loading audio: $e');
      currentSurah.value = null;
      return false;
    }
  }

  Future<void> togglePlayPause() async {
    if (player.playing) {
      await player.pause();
    } else {
      await player.play();
    }
  }

  Future<void> stop() async {
    await player.stop();
    currentSurah.value = null;
  }

  Future<void> download(int surahNumber) async {
    if (kIsWeb) return;

    final file = await _localFile(surahNumber);
    if (await file.exists()) {
      downloads.value = {...downloads.value, surahNumber: 1.0};
      return;
    }

    final map = {...downloads.value};
    map[surahNumber] = 0.0;
    downloads.value = map;

    try {
      await dio.download(
        remoteUrl(surahNumber),
        file.path,
        onReceiveProgress: (received, total) {
          if (total > 0) {
            final p = received / total;
            downloads.value = {...downloads.value, surahNumber: p};
          }
        },
      );
      downloads.value = {...downloads.value, surahNumber: 1.0};
    } catch (_) {
      downloads.value = {...downloads.value, surahNumber: null};
      if (await file.exists()) {
        await file.delete();
      }
      rethrow;
    }
  }
}

// ─────────────────────────────────────────────────────────
// Quran Page
// ─────────────────────────────────────────────────────────
class QuranPage extends StatefulWidget {
  const QuranPage({super.key});

  @override
  State<QuranPage> createState() => _QuranPageState();
}

class _QuranPageState extends State<QuranPage> {
  List<_Surah> _surahs = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadQuran();
  }

  Future<void> _loadQuran() async {
    try {
      final raw = await rootBundle.loadString('assets/quran_data.json');
      final data = json.decode(raw) as Map<String, dynamic>;
      final surahsMap = data['surahs'] as Map<String, dynamic>;

      final parsed = surahsMap.values
          .map((s) => _Surah.fromJson(s as Map<String, dynamic>))
          .toList()
        ..sort((a, b) => a.number.compareTo(b.number));

      if (!mounted) return;
      setState(() {
        _surahs = parsed;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  void _openSurah(_Surah surah) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => SurahReaderPage(surah: surah),
      ),
    );
  }

  void _openBookmarks() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => BookmarksPage(surahs: _surahs),
      ),
    );
  }

  void _showAudioSheet(_Surah surah) {
    HapticFeedback.selectionClick();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => AudioPlayerSheet(surah: surah),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: _buildAppBar(theme),
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            _buildHeader(context),
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _error != null
                      ? _buildError(theme)
                      : _buildSurahList(context),
            ),
          ],
        ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(ThemeData theme) {
    return AppBar(
      backgroundColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      automaticallyImplyLeading: false,
      centerTitle: true,
      leadingWidth: 64,
      leading: Padding(
        padding: const EdgeInsets.only(left: 18, top: 8, bottom: 8),
        child: Material(
          color: theme.colorScheme.primary.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () => Navigator.pop(context),
            child: Icon(
              Icons.arrow_back_rounded,
              color: theme.colorScheme.primary,
              size: 20,
            ),
          ),
        ),
      ),
      title: Text(
        'Holy Quran',
        style: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w700,
          color: theme.colorScheme.onSurface,
          letterSpacing: -0.2,
        ),
      ),
      actions: [
        Padding(
          padding: const EdgeInsets.only(right: 18, top: 8, bottom: 8),
          child: Material(
            color: theme.colorScheme.primary.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: _openBookmarks,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                child: Row(
                  children: [
                    Icon(
                      Icons.bookmarks_rounded,
                      color: theme.colorScheme.primary,
                      size: 18,
                    ),
                    const SizedBox(width: 6),
                    ValueListenableBuilder<int>(
                      valueListenable: BookmarkStore.instance.count,
                      builder: (context, count, _) {
                        return Text(
                          '$count',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: theme.colorScheme.primary,
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildHeader(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 4, 18, 6),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: isDark
                ? [const Color(0xFF0F3D14), const Color(0xFF1B5E20)]
                : [const Color(0xFF1B5E20), const Color(0xFF43A047)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF2E7D32)
                  .withValues(alpha: isDark ? 0.35 : 0.25),
              blurRadius: 22,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'The Holy Quran',
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 16,
                      letterSpacing: -0.2,
                    ),
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.25),
                    ),
                  ),
                  child: const Text(
                    'KJV · ENGLISH',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.2,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              'Read, Reflect, Remember',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.98),
                fontSize: 15,
                fontWeight: FontWeight.w600,
                height: 1.4,
                letterSpacing: -0.1,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'The complete Quran with English translation — bookmark your favorite verses and dive deep into the words of Allah.',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.78),
                fontSize: 12,
                height: 1.55,
                fontWeight: FontWeight.w400,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSurahList(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(18, 12, 18, 28),
      physics: const BouncingScrollPhysics(),
      itemCount: _surahs.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final surah = _surahs[index];
        return _SurahTile(
          surah: surah,
          onTap: () => _openSurah(surah),
          onPlay: () => _showAudioSheet(surah),
        );
      },
    );
  }

  Widget _buildError(ThemeData theme) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline_rounded,
              size: 48,
              color: theme.colorScheme.error,
            ),
            const SizedBox(height: 16),
            Text(
              'Could not load the Quran',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _error ?? 'Unknown error',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────
// Surah list tile
// ─────────────────────────────────────────────────────────
class _SurahTile extends StatefulWidget {
  final _Surah surah;
  final VoidCallback onTap;
  final VoidCallback onPlay;

  const _SurahTile({
    required this.surah,
    required this.onTap,
    required this.onPlay,
  });

  @override
  State<_SurahTile> createState() => _SurahTileState();
}

class _SurahTileState extends State<_SurahTile>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 120),
    );
    _scale = Tween<double>(begin: 1.0, end: 0.97).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return AnimatedBuilder(
      animation: _scale,
      builder: (context, child) => Transform.scale(
        scale: _scale.value,
        child: child,
      ),
      child: GestureDetector(
        onTapDown: (_) => _controller.forward(),
        onTapUp: (_) => _controller.reverse(),
        onTapCancel: () => _controller.reverse(),
        onTap: widget.onTap,
        child: Container(
          decoration: BoxDecoration(
            color: theme.cardColor,
            borderRadius: BorderRadius.circular(18),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.05),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
            border: Border.all(
              color: theme.colorScheme.onSurface
                  .withValues(alpha: isDark ? 0.06 : 0.04),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: isDark
                          ? [const Color(0xFF0F3D14), const Color(0xFF1B5E20)]
                          : [const Color(0xFF1B5E20), const Color(0xFF43A047)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF2E7D32)
                            .withValues(alpha: isDark ? 0.35 : 0.25),
                        blurRadius: 8,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Center(
                    child: Text(
                      '${widget.surah.number}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.2,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.surah.nameEn,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: theme.colorScheme.onSurface,
                          letterSpacing: -0.1,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Row(
                        children: [
                          Text(
                            '${widget.surah.totalAyahs} ayahs',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: theme.colorScheme.primary,
                              letterSpacing: 0.2,
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 6),
                            child: Container(
                              width: 3,
                              height: 3,
                              decoration: BoxDecoration(
                                color: theme.colorScheme.onSurface
                                    .withValues(alpha: 0.3),
                                shape: BoxShape.circle,
                              ),
                            ),
                          ),
                          Flexible(
                            child: Text(
                              widget.surah.nameAr,
                              textDirection: TextDirection.rtl,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: theme.colorScheme.onSurface
                                    .withValues(alpha: 0.6),
                                fontFamily: 'serif',
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Material(
                  color: theme.colorScheme.primary.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(10),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(10),
                    onTap: widget.onPlay,
                    child: Padding(
                      padding: const EdgeInsets.all(8),
                      child: Icon(
                        Icons.play_arrow_rounded,
                        size: 20,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────
// Audio Player Bottom Sheet
// ─────────────────────────────────────────────────────────
class AudioPlayerSheet extends StatefulWidget {
  final _Surah surah;

  const AudioPlayerSheet({super.key, required this.surah});

  @override
  State<AudioPlayerSheet> createState() => _AudioPlayerSheetState();
}

class _AudioPlayerSheetState extends State<AudioPlayerSheet> {
  final AudioService _audio = AudioService.instance;
  bool _isLoading = false;
  bool _hasError = false;
  String? _errorMessage;

  bool _isDownloading = false;
  double _downloadProgress = 0.0;
  bool _isDownloaded = false;

  StreamSubscription<PlayerState>? _stateSub;

  @override
  void initState() {
    super.initState();
    if (!kIsWeb) {
      _checkDownloaded();
    }
    _loadAudio();
    _stateSub = _audio.player.playerStateStream.listen((state) {
      if (mounted) setState(() {});
      // Catch errors from the stream during playback
      if (state.processingState == ProcessingState.idle &&
          _audio.currentSurah.value != null) {
        // Sometimes idle triggers on error. We can check for specific errors if needed.
      }
    });
  }

  @override
  void dispose() {
    _stateSub?.cancel();
    super.dispose();
  }

  Future<void> _checkDownloaded() async {
    final done = await _audio.isDownloaded(widget.surah.number);
    if (mounted) setState(() => _isDownloaded = done);
  }

  Future<void> _loadAudio() async {
    // If this surah is already loaded, don't reload it.
    if (_audio.currentSurah.value == widget.surah.number) return;

    setState(() {
      _isLoading = true;
      _hasError = false;
      _errorMessage = null;
    });

    final success = await _audio.loadAudio(
      surahNumber: widget.surah.number,
      surahNameEn: widget.surah.nameEn,
      surahNameAr: widget.surah.nameAr,
      totalAyahs: widget.surah.totalAyahs,
    );

    if (mounted) {
      setState(() {
        _isLoading = false;
        if (!success) {
          _hasError = true;
          _errorMessage =
              'Could not load audio. Please check your internet connection.';
        }
      });
    }
  }

  Future<void> _download() async {
    if (_isDownloading || _isDownloaded || kIsWeb) return;
    setState(() {
      _isDownloading = true;
      _downloadProgress = 0.0;
      _hasError = false;
    });
    try {
      await _audio.download(widget.surah.number);
      if (mounted) {
        setState(() {
          _isDownloaded = true;
          _isDownloading = false;
          _downloadProgress = 1.0;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${widget.surah.nameEn} downloaded for offline use'),
            behavior: SnackBarBehavior.floating,
            backgroundColor: const Color(0xFF1B5E20),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isDownloading = false;
          _hasError = true;
          _errorMessage = 'Download failed. Please check your connection.';
        });
      }
    }
  }

  String _fmtDuration(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Handle bar
              Container(
                width: 42,
                height: 4,
                decoration: BoxDecoration(
                  color: theme.dividerColor,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 18),

              // Artwork / title
              Container(
                width: 84,
                height: 84,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: isDark
                        ? [const Color(0xFF0F3D14), const Color(0xFF1B5E20)]
                        : [const Color(0xFF1B5E20), const Color(0xFF43A047)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(22),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF2E7D32)
                          .withValues(alpha: isDark ? 0.4 : 0.3),
                      blurRadius: 18,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.menu_book_rounded,
                  color: Colors.white,
                  size: 36,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                widget.surah.nameEn,
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                  fontSize: 20,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                widget.surah.nameAr,
                textDirection: TextDirection.rtl,
                style: TextStyle(
                  fontFamily: 'serif',
                  fontSize: 16,
                  color: theme.colorScheme.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Mishary Alafasy · ${widget.surah.totalAyahs} ayahs',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                ),
              ),
              const SizedBox(height: 18),

              // ── Player State Logic ──

              if (_isLoading)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 32),
                  child: CircularProgressIndicator(),
                )
              else if (_hasError)
                _buildErrorState(theme)
              else
                _buildPlayerControls(theme),

              const SizedBox(height: 18),

              // Download button (Only on Mobile/Desktop)
              if (!kIsWeb && !_hasError) _buildDownloadButton(theme, isDark),

              // Web note
              if (kIsWeb && !_hasError)
                Text(
                  'Streaming online',
                  style: TextStyle(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Beautiful Error State ──
  Widget _buildErrorState(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: theme.colorScheme.error.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: theme.colorScheme.error.withValues(alpha: 0.2),
        ),
      ),
      child: Column(
        children: [
          Icon(
            Icons.wifi_off_rounded,
            color: theme.colorScheme.error,
            size: 32,
          ),
          const SizedBox(height: 12),
          Text(
            'Playback Failed',
            style: TextStyle(
              color: theme.colorScheme.error,
              fontWeight: FontWeight.w700,
              fontSize: 15,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            _errorMessage ?? 'An unknown error occurred.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
              fontSize: 12,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 16),
          FilledButton.tonalIcon(
            onPressed: () {
              setState(() {
                _hasError = false;
                _isLoading = true;
              });
              _loadAudio();
            },
            icon: const Icon(Icons.refresh_rounded, size: 18),
            label: const Text('Try Again'),
            style: FilledButton.styleFrom(
              backgroundColor: theme.colorScheme.errorContainer,
              foregroundColor: theme.colorScheme.onErrorContainer,
            ),
          ),
        ],
      ),
    );
  }

  // ── Standard Player Controls ──
  Widget _buildPlayerControls(ThemeData theme) {
    return Column(
      children: [
        StreamBuilder<Duration>(
          stream: _audio.player.positionStream,
          builder: (context, snapshot) {
            final position = snapshot.data ?? Duration.zero;
            final duration = _audio.player.duration ?? Duration.zero;
            final max = duration.inMilliseconds.toDouble();
            final value =
                position.inMilliseconds.clamp(0, max.toInt()).toDouble();

            return Column(
              children: [
                SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    trackHeight: 3,
                    thumbShape: const RoundSliderThumbShape(
                      enabledThumbRadius: 6,
                    ),
                    overlayShape: const RoundSliderOverlayShape(
                      overlayRadius: 14,
                    ),
                  ),
                  child: Slider(
                    value: value,
                    max: max <= 0 ? 1 : max,
                    onChanged: (v) {
                      _audio.player.seek(
                        Duration(milliseconds: v.toInt()),
                      );
                    },
                    activeColor: theme.colorScheme.primary,
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        _fmtDuration(position),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurface
                              .withValues(alpha: 0.6),
                          fontSize: 11,
                        ),
                      ),
                      Text(
                        _fmtDuration(duration),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurface
                              .withValues(alpha: 0.6),
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            IconButton(
              iconSize: 28,
              icon: const Icon(Icons.replay_10_rounded),
              onPressed: () {
                final p = _audio.player.position - const Duration(seconds: 10);
                _audio.player.seek(
                  p < Duration.zero ? Duration.zero : p,
                );
              },
            ),
            const SizedBox(width: 16),
            Material(
              color: theme.colorScheme.primary,
              shape: const CircleBorder(),
              child: InkWell(
                customBorder: const CircleBorder(),
                onTap: () async {
                  // Play/Pause is handled here, allowing user gesture for Web Autoplay policy
                  if (_audio.player.processingState ==
                      ProcessingState.completed) {
                    await _audio.player.seek(Duration.zero);
                    await _audio.player.play();
                  } else {
                    await _audio.togglePlayPause();
                  }
                },
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Icon(
                    _audio.player.playing
                        ? Icons.pause_rounded
                        : Icons.play_arrow_rounded,
                    color: Colors.white,
                    size: 34,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 16),
            IconButton(
              iconSize: 28,
              icon: const Icon(Icons.forward_10_rounded),
              onPressed: () {
                final p = _audio.player.position + const Duration(seconds: 10);
                final d = _audio.player.duration ?? const Duration(days: 1);
                _audio.player.seek(p > d ? d : p);
              },
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildDownloadButton(ThemeData theme, bool isDark) {
    if (_isDownloaded) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: theme.colorScheme.primary.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.check_circle_rounded,
              color: theme.colorScheme.primary,
              size: 18,
            ),
            const SizedBox(width: 8),
            Text(
              'Available offline',
              style: TextStyle(
                color: theme.colorScheme.primary,
                fontWeight: FontWeight.w700,
                fontSize: 13,
              ),
            ),
          ],
        ),
      );
    }

    if (_isDownloading) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: theme.colorScheme.primary.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          children: [
            LinearProgressIndicator(
              value: _downloadProgress > 0 ? _downloadProgress : null,
              minHeight: 4,
              backgroundColor:
                  theme.colorScheme.primary.withValues(alpha: 0.15),
              color: theme.colorScheme.primary,
              borderRadius: BorderRadius.circular(2),
            ),
            const SizedBox(height: 8),
            Text(
              _downloadProgress > 0
                  ? 'Downloading… ${(_downloadProgress * 100).toStringAsFixed(0)}%'
                  : 'Starting download…',
              style: TextStyle(
                color: theme.colorScheme.primary,
                fontWeight: FontWeight.w600,
                fontSize: 12,
              ),
            ),
          ],
        ),
      );
    }

    return SizedBox(
      width: double.infinity,
      child: FilledButton.tonalIcon(
        onPressed: _download,
        icon: const Icon(Icons.download_rounded, size: 18),
        label: const Text('Download for offline listening'),
        style: FilledButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────
// Surah reader page
// ─────────────────────────────────────────────────────────
class SurahReaderPage extends StatefulWidget {
  final _Surah surah;

  const SurahReaderPage({super.key, required this.surah});

  @override
  State<SurahReaderPage> createState() => _SurahReaderPageState();
}

class _SurahReaderPageState extends State<SurahReaderPage> {
  bool _showTranslation = true;

  void _toggleTranslation() {
    HapticFeedback.selectionClick();
    setState(() => _showTranslation = !_showTranslation);
  }

  void _copyAyah(_Ayah ayah, int index) {
    final text =
        '${ayah.arabic}\n\n${ayah.english}\n\n— ${widget.surah.nameEn} ${widget.surah.number}:$index';
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Row(
          children: [
            Icon(Icons.check_circle_rounded, color: Colors.white, size: 18),
            SizedBox(width: 10),
            Expanded(
              child: Text(
                'Ayah copied to clipboard',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
        backgroundColor: const Color(0xFF1B5E20),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  void _toggleBookmark(_Ayah ayah, int index) {
    HapticFeedback.selectionClick();
    final id = '${widget.surah.number}:$index';
    BookmarkStore.instance.toggle(
      _Bookmark(
        id: id,
        surahNumber: widget.surah.number,
        surahName: widget.surah.nameEn,
        ayahNumber: index,
        arabic: ayah.arabic,
        english: ayah.english,
      ),
    );
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: _buildAppBar(theme),
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            _buildSurahBanner(context),
            _buildToggleRow(context),
            Expanded(child: _buildAyahList(context)),
          ],
        ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(ThemeData theme) {
    return AppBar(
      backgroundColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      automaticallyImplyLeading: false,
      centerTitle: true,
      leadingWidth: 64,
      leading: Padding(
        padding: const EdgeInsets.only(left: 18, top: 8, bottom: 8),
        child: Material(
          color: theme.colorScheme.primary.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () => Navigator.pop(context),
            child: Icon(
              Icons.arrow_back_rounded,
              color: theme.colorScheme.primary,
              size: 20,
            ),
          ),
        ),
      ),
      title: Text(
        widget.surah.nameEn,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w700,
          color: theme.colorScheme.onSurface,
          letterSpacing: -0.2,
        ),
      ),
      actions: [
        Padding(
          padding: const EdgeInsets.only(right: 18, top: 8, bottom: 8),
          child: Material(
            color: theme.colorScheme.primary.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () => showModalBottomSheet(
                context: context,
                isScrollControlled: true,
                backgroundColor: Colors.transparent,
                builder: (_) => AudioPlayerSheet(surah: widget.surah),
              ),
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: Icon(
                  Icons.play_arrow_rounded,
                  color: theme.colorScheme.primary,
                  size: 20,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSurahBanner(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final showBismillah = widget.surah.number != 9;

    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 4, 18, 6),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: isDark
                ? [const Color(0xFF0F3D14), const Color(0xFF1B5E20)]
                : [const Color(0xFF1B5E20), const Color(0xFF43A047)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF2E7D32)
                  .withValues(alpha: isDark ? 0.35 : 0.25),
              blurRadius: 22,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            if (showBismillah) ...[
              const Text(
                'بِسْمِ ٱللَّٰهِ ٱلرَّحْمَٰنِ ٱلرَّحِيمِ',
                textAlign: TextAlign.center,
                textDirection: TextDirection.rtl,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w500,
                  fontFamily: 'serif',
                  height: 1.8,
                  letterSpacing: 0.3,
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: Container(
                      height: 1,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            Colors.white.withValues(alpha: 0.0),
                            Colors.white.withValues(alpha: 0.3),
                          ],
                        ),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    child: Icon(
                      Icons.circle,
                      size: 4,
                      color: Colors.white.withValues(alpha: 0.5),
                    ),
                  ),
                  Expanded(
                    child: Container(
                      height: 1,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            Colors.white.withValues(alpha: 0.3),
                            Colors.white.withValues(alpha: 0.0),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
            ],
            Text(
              widget.surah.nameAr,
              textAlign: TextAlign.center,
              textDirection: TextDirection.rtl,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 26,
                fontWeight: FontWeight.w600,
                fontFamily: 'serif',
                height: 1.5,
                letterSpacing: 0.3,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              widget.surah.nameEn,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 15,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.3,
              ),
            ),
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.25),
                ),
              ),
              child: Text(
                'SURAH ${widget.surah.number} · ${widget.surah.totalAyahs} AYAHS',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.2,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildToggleRow(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 6, 18, 6),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: _toggleTranslation,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: theme.cardColor,
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
              border: Border.all(
                color: theme.colorScheme.onSurface
                    .withValues(alpha: isDark ? 0.06 : 0.04),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.translate_rounded,
                  size: 16,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Show English Translation',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: theme.colorScheme.onSurface,
                      letterSpacing: -0.1,
                    ),
                  ),
                ),
                Transform.scale(
                  scale: 0.8,
                  child: Switch.adaptive(
                    value: _showTranslation,
                    onChanged: (_) => _toggleTranslation(),
                    activeThumbColor: theme.colorScheme.primary,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAyahList(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(18, 6, 18, 28),
      physics: const BouncingScrollPhysics(),
      itemCount: widget.surah.ayahs.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final ayah = widget.surah.ayahs[index];
        final ayahNumber = index + 1;
        final isBookmarked = BookmarkStore.instance
            .contains('${widget.surah.number}:$ayahNumber');

        return _AyahCard(
          ayah: ayah,
          ayahNumber: ayahNumber,
          showTranslation: _showTranslation,
          isBookmarked: isBookmarked,
          onCopy: () => _copyAyah(ayah, ayahNumber),
          onBookmark: () => _toggleBookmark(ayah, ayahNumber),
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────
// Ayah card
// ─────────────────────────────────────────────────────────
class _AyahCard extends StatelessWidget {
  final _Ayah ayah;
  final int ayahNumber;
  final bool showTranslation;
  final bool isBookmarked;
  final VoidCallback onCopy;
  final VoidCallback onBookmark;

  const _AyahCard({
    required this.ayah,
    required this.ayahNumber,
    required this.showTranslation,
    required this.isBookmarked,
    required this.onCopy,
    required this.onBookmark,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.05),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(
          color: theme.colorScheme.onSurface
              .withValues(alpha: isDark ? 0.06 : 0.04),
        ),
      ),
      child: Stack(
        children: [
          Positioned(
            right: -18,
            bottom: -22,
            child: Text(
              '☪',
              style: TextStyle(
                fontSize: 110,
                color: theme.colorScheme.primary
                    .withValues(alpha: isDark ? 0.06 : 0.04),
                height: 1,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 30,
                      height: 30,
                      decoration: BoxDecoration(
                        color:
                            theme.colorScheme.primary.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(9),
                      ),
                      child: Center(
                        child: Text(
                          '$ayahNumber',
                          style: TextStyle(
                            color: theme.colorScheme.primary,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            letterSpacing: -0.2,
                          ),
                        ),
                      ),
                    ),
                    const Spacer(),
                    _ActionIcon(
                      icon: Icons.copy_rounded,
                      onTap: onCopy,
                      theme: theme,
                    ),
                    const SizedBox(width: 6),
                    _ActionIcon(
                      icon: isBookmarked
                          ? Icons.bookmark_rounded
                          : Icons.bookmark_border_rounded,
                      onTap: onBookmark,
                      theme: theme,
                      highlighted: isBookmarked,
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 14,
                  ),
                  decoration: BoxDecoration(
                    color: isDark
                        ? theme.colorScheme.primary.withValues(alpha: 0.06)
                        : theme.colorScheme.primary.withValues(alpha: 0.04),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: theme.colorScheme.primary.withValues(alpha: 0.15),
                    ),
                  ),
                  child: Text(
                    ayah.arabic,
                    textAlign: TextAlign.right,
                    textDirection: TextDirection.rtl,
                    style: TextStyle(
                      fontSize: 20,
                      height: 2.1,
                      fontWeight: FontWeight.w500,
                      color: theme.colorScheme.onSurface,
                      fontFamily: 'serif',
                      letterSpacing: 0.2,
                    ),
                  ),
                ),
                AnimatedSize(
                  duration: const Duration(milliseconds: 220),
                  curve: Curves.easeOutCubic,
                  alignment: Alignment.topCenter,
                  child: showTranslation
                      ? Padding(
                          padding: const EdgeInsets.only(top: 12),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Padding(
                                padding: const EdgeInsets.only(top: 3),
                                child: Icon(
                                  Icons.translate_rounded,
                                  size: 13,
                                  color: theme.colorScheme.primary
                                      .withValues(alpha: 0.7),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  ayah.english,
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    color: theme.colorScheme.onSurface
                                        .withValues(alpha: 0.78),
                                    fontSize: 13,
                                    height: 1.6,
                                    fontWeight: FontWeight.w400,
                                    letterSpacing: 0.05,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        )
                      : const SizedBox(width: double.infinity),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionIcon extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final ThemeData theme;
  final bool highlighted;

  const _ActionIcon({
    required this.icon,
    required this.onTap,
    required this.theme,
    this.highlighted = false,
  });

  @override
  Widget build(BuildContext context) {
    final bg = highlighted
        ? theme.colorScheme.primary.withValues(alpha: 0.15)
        : theme.colorScheme.primary.withValues(alpha: 0.08);
    final fg = theme.colorScheme.primary;

    return Material(
      color: bg,
      borderRadius: BorderRadius.circular(9),
      child: InkWell(
        borderRadius: BorderRadius.circular(9),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(7),
          child: Icon(icon, size: 14, color: fg),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────
// Bookmarks page
// ─────────────────────────────────────────────────────────
class BookmarksPage extends StatefulWidget {
  final List<_Surah> surahs;

  const BookmarksPage({super.key, required this.surahs});

  @override
  State<BookmarksPage> createState() => _BookmarksPageState();
}

class _BookmarksPageState extends State<BookmarksPage> {
  void _copyBookmark(_Bookmark b) {
    final text =
        '${b.arabic}\n\n${b.english}\n\n— ${b.surahName} ${b.surahNumber}:${b.ayahNumber}';
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Row(
          children: [
            Icon(Icons.check_circle_rounded, color: Colors.white, size: 18),
            SizedBox(width: 10),
            Expanded(
              child: Text(
                'Bookmark copied',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
        backgroundColor: const Color(0xFF1B5E20),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  void _removeBookmark(_Bookmark b) {
    HapticFeedback.selectionClick();
    BookmarkStore.instance.remove(b.id);
    setState(() {});
  }

  void _openInReader(_Bookmark b) {
    final surah = widget.surahs.firstWhere(
      (s) => s.number == b.surahNumber,
      orElse: () => widget.surahs.first,
    );
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => SurahReaderPage(surah: surah),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: _buildAppBar(theme),
      body: SafeArea(
        top: false,
        child: ValueListenableBuilder<List<_Bookmark>>(
          valueListenable: BookmarkStore.instance.list,
          builder: (context, bookmarks, _) {
            if (bookmarks.isEmpty) return _buildEmpty(theme);
            return _buildList(bookmarks);
          },
        ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(ThemeData theme) {
    return AppBar(
      backgroundColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      automaticallyImplyLeading: false,
      centerTitle: true,
      leadingWidth: 64,
      leading: Padding(
        padding: const EdgeInsets.only(left: 18, top: 8, bottom: 8),
        child: Material(
          color: theme.colorScheme.primary.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () => Navigator.pop(context),
            child: Icon(
              Icons.arrow_back_rounded,
              color: theme.colorScheme.primary,
              size: 20,
            ),
          ),
        ),
      ),
      title: Text(
        'Bookmarks',
        style: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w700,
          color: theme.colorScheme.onSurface,
          letterSpacing: -0.2,
        ),
      ),
    );
  }

  Widget _buildEmpty(ThemeData theme) {
    final isDark = theme.brightness == Brightness.dark;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: isDark
                      ? [const Color(0xFF0F3D14), const Color(0xFF1B5E20)]
                      : [const Color(0xFF1B5E20), const Color(0xFF43A047)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF2E7D32)
                        .withValues(alpha: isDark ? 0.4 : 0.28),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: const Icon(
                Icons.bookmark_border_rounded,
                color: Colors.white,
                size: 32,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'No bookmarks yet',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
                fontSize: 17,
                color: theme.colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Tap the bookmark icon on any ayah\nto save it here for later.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.55),
                height: 1.6,
                fontSize: 12.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildList(List<_Bookmark> bookmarks) {
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(18, 12, 18, 28),
      physics: const BouncingScrollPhysics(),
      itemCount: bookmarks.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final b = bookmarks[index];
        return _BookmarkCard(
          bookmark: b,
          onCopy: () => _copyBookmark(b),
          onRemove: () => _removeBookmark(b),
          onOpen: () => _openInReader(b),
        );
      },
    );
  }
}

class _BookmarkCard extends StatelessWidget {
  final _Bookmark bookmark;
  final VoidCallback onCopy;
  final VoidCallback onRemove;
  final VoidCallback onOpen;

  const _BookmarkCard({
    required this.bookmark,
    required this.onCopy,
    required this.onRemove,
    required this.onOpen,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.05),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(
          color: theme.colorScheme.onSurface
              .withValues(alpha: isDark ? 0.06 : 0.04),
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onOpen,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primary.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '${bookmark.surahName} ${bookmark.surahNumber}:${bookmark.ayahNumber}',
                      style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w700,
                        color: theme.colorScheme.primary,
                        letterSpacing: 0.3,
                      ),
                    ),
                  ),
                  const Spacer(),
                  _ActionIcon(
                    icon: Icons.copy_rounded,
                    onTap: onCopy,
                    theme: theme,
                  ),
                  const SizedBox(width: 6),
                  _ActionIcon(
                    icon: Icons.bookmark_remove_rounded,
                    onTap: onRemove,
                    theme: theme,
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                bookmark.arabic,
                textAlign: TextAlign.right,
                textDirection: TextDirection.rtl,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 17,
                  height: 1.9,
                  fontWeight: FontWeight.w500,
                  color: theme.colorScheme.onSurface,
                  fontFamily: 'serif',
                ),
              ),
              const SizedBox(height: 8),
              Text(
                bookmark.english,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12.5,
                  height: 1.55,
                  fontWeight: FontWeight.w400,
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.72),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────
// Data models
// ─────────────────────────────────────────────────────────
class _Surah {
  final int number;
  final String nameEn;
  final String nameAr;
  final int totalAyahs;
  final List<_Ayah> ayahs;

  _Surah({
    required this.number,
    required this.nameEn,
    required this.nameAr,
    required this.totalAyahs,
    required this.ayahs,
  });

  factory _Surah.fromJson(Map<String, dynamic> json) {
    final ayahsJson = (json['ayahs'] as List<dynamic>? ?? []);
    final ayahs = ayahsJson
        .map((a) => _Ayah.fromJson(a as Map<String, dynamic>))
        .toList();

    return _Surah(
      number: json['surah_number'] as int? ?? 0,
      nameEn: json['surah_name_en'] as String? ?? '',
      nameAr: json['surah_name_ur'] as String? ?? '',
      totalAyahs: json['total_ayahs'] as int? ?? ayahs.length,
      ayahs: ayahs,
    );
  }
}

class _Ayah {
  final String arabic;
  final String english;

  _Ayah({required this.arabic, required this.english});

  factory _Ayah.fromJson(Map<String, dynamic> json) {
    final english = json['english_abdullah_yusuf_ali_translation'] as String? ??
        json['english_mohammad_habib_shakir_translation'] as String? ??
        '';

    return _Ayah(
      arabic: json['arabic_text'] as String? ?? '',
      english: english,
    );
  }
}

class _Bookmark {
  final String id;
  final int surahNumber;
  final String surahName;
  final int ayahNumber;
  final String arabic;
  final String english;

  _Bookmark({
    required this.id,
    required this.surahNumber,
    required this.surahName,
    required this.ayahNumber,
    required this.arabic,
    required this.english,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'surahNumber': surahNumber,
        'surahName': surahName,
        'ayahNumber': ayahNumber,
        'arabic': arabic,
        'english': english,
      };

  factory _Bookmark.fromJson(Map<String, dynamic> json) => _Bookmark(
        id: json['id'] as String? ?? '',
        surahNumber: json['surahNumber'] as int? ?? 0,
        surahName: json['surahName'] as String? ?? '',
        ayahNumber: json['ayahNumber'] as int? ?? 0,
        arabic: json['arabic'] as String? ?? '',
        english: json['english'] as String? ?? '',
      );
}

// ─────────────────────────────────────────────────────────
// Persistent bookmark store (singleton)
// ─────────────────────────────────────────────────────────
class BookmarkStore {
  BookmarkStore._();
  static final BookmarkStore instance = BookmarkStore._();

  static const String _prefsKey = 'quran_bookmarks_v1';

  final ValueNotifier<List<_Bookmark>> list =
      ValueNotifier<List<_Bookmark>>([]);

  final ValueNotifier<int> count = ValueNotifier<int>(0);

  bool _loaded = false;

  Future<void> load() async {
    if (_loaded) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_prefsKey);
      if (raw != null && raw.isNotEmpty) {
        final decoded = json.decode(raw) as List<dynamic>;
        final parsed = decoded
            .map((e) => _Bookmark.fromJson(e as Map<String, dynamic>))
            .toList();
        list.value = parsed;
        count.value = parsed.length;
      }
    } catch (_) {
      list.value = [];
      count.value = 0;
    }
    _loaded = true;
  }

  bool contains(String id) => list.value.any((b) => b.id == id);

  void toggle(_Bookmark bookmark) {
    final current = List<_Bookmark>.from(list.value);
    final index = current.indexWhere((b) => b.id == bookmark.id);
    if (index >= 0) {
      current.removeAt(index);
    } else {
      current.insert(0, bookmark);
    }
    list.value = current;
    count.value = current.length;
    _persist();
  }

  void remove(String id) {
    final current = List<_Bookmark>.from(list.value)
      ..removeWhere((b) => b.id == id);
    list.value = current;
    count.value = current.length;
    _persist();
  }

  Future<void> _persist() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final encoded = json.encode(list.value.map((b) => b.toJson()).toList());
      await prefs.setString(_prefsKey, encoded);
    } catch (_) {}
  }
}
