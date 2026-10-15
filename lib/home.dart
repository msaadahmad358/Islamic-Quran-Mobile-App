import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'
    show rootBundle, Clipboard, ClipboardData;
import 'package:http/http.dart' as http;
import 'package:quran_pak/digitaltasbih.dart';
import 'package:quran_pak/location_service.dart';
import 'package:quran_pak/qibla.dart';
import 'package:quran_pak/quran.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:quran_pak/asmaulhusna.dart';
import 'package:quran_pak/duas.dart';
import 'package:quran_pak/prayertimes.dart';
import 'package:quran_pak/settings.dart';
import 'package:quran_pak/theme_controller.dart';
import 'package:quran_pak/adhan_service.dart';

class HomePage extends StatefulWidget {
  final ThemeController themeController;

  const HomePage({super.key, required this.themeController});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  // ── Prayer banner state ────────────────────────────────
  String _nextPrayer = 'Prayer';
  String _nextPrayerTime = '--:--';
  String _locationLabel = 'Set location';
  String _countdown = 'in --h --m';
  Timer? _countdownTimer;
  Map<String, String>? _prayerTimes; // name → "H:MM AM/PM"

  // ── Daily Dua state ────────────────────────────────────
  _DailyDua? _dailyDua;
  bool _isDuaLoading = true;

  // Prefs keys (must match prayertimes.dart)
  static const _prefsMode = 'pt_mode';
  static const _prefsCity = 'pt_city';
  static const _prefsMethod = 'pt_method';
  static const _prefsSchool = 'pt_school';

  Future<void> _checkLocationPermission() async {
    final svc = LocationService.instance;

    // Permission is asked ONCE per install (flag saved in prefs). After that
    // the saved location is used silently and only refreshed in background.
    if (!await svc.needsFirstRunPrompt()) {
      if (svc.current.value == null) {
        // Permission already granted (e.g. reinstall) but nothing cached yet.
        if (await svc.isPermissionGranted()) await svc.request();
      } else {
        unawaited(svc.refreshIfStale());
      }
      return;
    }
    if (!mounted) return;

    // Remember immediately so we never show this twice, whatever the answer.
    await svc.markPrompted();
    if (!mounted) return;

    final proceed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          'Location Access',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        content: const Text(
          'To show accurate prayer times and Qibla direction for your current city, the app needs access to your location.',
          style: TextStyle(height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Not Now'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Allow'),
          ),
        ],
      ),
    );

    if (proceed == true) {
      // On success LocationService.current changes and _onLocationChanged
      // refreshes the banner + adhan schedule.
      final result = await svc.request(userInitiated: true);
      if (!result.ok && mounted) _showLocationProblem(result.status);
    }
  }

  void _onLocationChanged() {
    if (mounted) _initPrayerBanner();
  }

  void _openPrayerTimes() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const PrayerTimesPage()),
    ).then((_) {
      if (mounted) _initPrayerBanner();
    });
  }

  void _showLocationProblem(LocationStatus status) {
    String message;
    String? actionLabel;
    VoidCallback? action;

    switch (status) {
      case LocationStatus.deniedForever:
        message = 'Location is blocked. Enable it in settings, or pick a city.';
        actionLabel = 'Settings';
        action = LocationService.instance.openSettings;
        break;
      case LocationStatus.serviceOff:
        message = 'Location services are off. Turn on GPS, or pick a city.';
        actionLabel = 'Turn on';
        action = LocationService.instance.openLocationSettings;
        break;
      case LocationStatus.timeout:
        message =
            'Could not get your location. Tap the location chip to retry.';
        break;
      default:
        message = 'No location set. Tap the location chip to choose a city.';
        actionLabel = 'Choose';
        action = _openPrayerTimes;
    }

    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 6),
        action: (actionLabel != null && action != null)
            ? SnackBarAction(label: actionLabel, onPressed: action)
            : null,
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    _loadRandomDua();
    _initPrayerBanner();
    LocationService.instance.current.addListener(_onLocationChanged);

    WidgetsBinding.instance
        .addPostFrameCallback((_) => _checkLocationPermission());

    _countdownTimer = Timer.periodic(
      const Duration(seconds: 30),
      (_) => _updateCountdown(),
    );
  }

  @override
  void dispose() {
    LocationService.instance.current.removeListener(_onLocationChanged);
    _countdownTimer?.cancel();
    super.dispose();
  }

  Future<void> _refreshAll() async {
    // Reload prayer times (respects manual city or cached location)
    await _initPrayerBanner();
    // Reload a new random daily dua
    if (mounted) {
      setState(() => _isDuaLoading = true);
    }
    await _loadRandomDua();
  }

  // ═══════════════════════════════════════════════════════
  // PRAYER BANNER
  // ═══════════════════════════════════════════════════════
  Future<void> _initPrayerBanner() async {
    String mode = 'auto';
    _City? selectedCity;
    int methodId = 1;
    int schoolId = 1;

    try {
      final prefs = await SharedPreferences.getInstance();
      mode = prefs.getString(_prefsMode) ?? 'auto';
      methodId = prefs.getInt(_prefsMethod) ?? 1;
      schoolId = prefs.getInt(_prefsSchool) ?? 1;

      final cityJson = prefs.getString(_prefsCity);
      if (cityJson != null && cityJson.isNotEmpty) {
        final decoded = json.decode(cityJson) as Map<String, dynamic>;
        selectedCity = _City(
          decoded['name'] as String? ?? '',
          decoded['country'] as String? ?? '',
        );
      }
    } catch (_) {}

    // Manual city still wins if the user explicitly chose one
    if (mode == 'manual' && selectedCity != null) {
      await _fetchByCity(selectedCity, methodId, schoolId);
      return;
    }

    // Auto mode — use cached location from LocationService if available
    final cached = LocationService.instance.current.value;
    if (cached != null) {
      await _fetchByCoords(
        cached.lat,
        cached.lng,
        methodId,
        schoolId,
        cached.label,
      );
      return;
    }

    // No cached location → banner keeps its default
  }

  Future<void> _fetchByCoords(
    double lat,
    double lng,
    int methodId,
    int schoolId,
    String? cityName,
  ) async {
    try {
      final now = DateTime.now();
      final url = Uri.parse(
        'https://api.aladhan.com/v1/timings/${now.day}-${now.month}-${now.year}'
        '?latitude=$lat&longitude=$lng&method=$methodId&school=$schoolId',
      );

      final res = await http.get(url).timeout(const Duration(seconds: 12));
      if (res.statusCode != 200) return;

      final data = json.decode(res.body);
      if (data['code'] != 200) return;

      final timings = data['data']['timings'] as Map<String, dynamic>;
      final timezone = (data['data']['meta']['timezone'] ?? '') as String;

      if (!mounted) return;
      setState(() {
        _prayerTimes = _buildTimingsMap(timings);
        _locationLabel = cityName?.isNotEmpty == true
            ? cityName!
            : (timezone.isNotEmpty ? timezone : 'Current Location');
      });
      AdhanService.instance.updateSchedule(_prayerTimes);

      _recomputeNext();
    } catch (_) {
      // Silent
    }
  }

  Future<void> _fetchByCity(
    _City city,
    int methodId,
    int schoolId,
  ) async {
    try {
      final now = DateTime.now();
      final url = Uri.parse(
        'https://api.aladhan.com/v1/timingsByCity/${now.day}-${now.month}-${now.year}'
        '?city=${Uri.encodeComponent(city.name)}'
        '&country=${Uri.encodeComponent(city.country)}'
        '&method=$methodId&school=$schoolId',
      );

      final res = await http.get(url).timeout(const Duration(seconds: 12));
      if (res.statusCode != 200) return;

      final data = json.decode(res.body);
      if (data['code'] != 200) return;

      final timings = data['data']['timings'] as Map<String, dynamic>;

      if (!mounted) return;
      setState(() {
        _prayerTimes = _buildTimingsMap(timings);
        _locationLabel = '${city.name}, ${city.country}';
      });
      AdhanService.instance.updateSchedule(_prayerTimes);

      _recomputeNext();
    } catch (_) {
      // Silent
    }
  }

  Map<String, String> _buildTimingsMap(Map<String, dynamic> timings) {
    return {
      'Fajr': _format12h(timings['Fajr']),
      'Sunrise': _format12h(timings['Sunrise']),
      'Dhuhr': _format12h(timings['Dhuhr']),
      'Asr': _format12h(timings['Asr']),
      'Maghrib': _format12h(timings['Maghrib']),
      'Isha': _format12h(timings['Isha']),
    };
  }

  String _format12h(dynamic raw) {
    if (raw == null) return '--:--';
    final cleaned = raw.toString().split(' ').first.trim();
    final p = cleaned.split(':');
    if (p.length < 2) return cleaned;
    final h = int.tryParse(p[0]);
    final m = int.tryParse(p[1]);
    if (h == null || m == null) return cleaned;
    final period = h >= 12 ? 'PM' : 'AM';
    final h12 = h % 12 == 0 ? 12 : h % 12;
    return '$h12:${m.toString().padLeft(2, '0')} $period';
  }

  void _recomputeNext() {
    if (_prayerTimes == null) return;

    final now = DateTime.now();
    final minutesNow = now.hour * 60 + now.minute;

    String next = 'Fajr';
    for (final name in ['Fajr', 'Dhuhr', 'Asr', 'Maghrib', 'Isha']) {
      final t = _prayerTimes![name];
      if (t == null) continue;
      final mins = _toMinutes(t);
      if (mins != null && mins > minutesNow) {
        next = name;
        break;
      }
    }

    final nextTime = _prayerTimes![next] ?? '--:--';
    setState(() {
      _nextPrayer = next;
      _nextPrayerTime = nextTime;
      _countdown = _remainingTo(next);
    });
  }

  void _updateCountdown() {
    if (_prayerTimes == null) return;
    // If we've passed the current "next" prayer, recompute
    final minsNow = DateTime.now().hour * 60 + DateTime.now().minute;
    final t = _prayerTimes![_nextPrayer];
    if (t != null) {
      final mins = _toMinutes(t);
      if (mins != null && mins <= minsNow) {
        _recomputeNext();
        return;
      }
    }
    if (mounted) {
      setState(() => _countdown = _remainingTo(_nextPrayer));
    }
  }

  int? _toMinutes(String time12) {
    final parts = time12.split(' ');
    if (parts.length < 2) return null;
    final hm = parts[0].split(':');
    if (hm.length < 2) return null;
    int h = int.tryParse(hm[0]) ?? 0;
    final m = int.tryParse(hm[1]) ?? 0;
    final isPm = parts[1].toUpperCase() == 'PM';
    if (isPm && h != 12) h += 12;
    if (!isPm && h == 12) h = 0;
    return h * 60 + m;
  }

  String _remainingTo(String name) {
    final t = _prayerTimes?[name];
    if (t == null) return '';
    final mins = _toMinutes(t);
    if (mins == null) return '';

    final now = DateTime.now();
    final nowMins = now.hour * 60 + now.minute;
    var diff = mins - nowMins;
    if (diff < 0) diff += 24 * 60;

    final hrs = diff ~/ 60;
    final rem = diff % 60;
    if (hrs > 0) return 'in ${hrs}h ${rem}m';
    return 'in ${rem}m';
  }

  // ═══════════════════════════════════════════════════════
  // DAILY DUA
  // ═══════════════════════════════════════════════════════
  Future<void> _loadRandomDua() async {
    try {
      final raw = await rootBundle.loadString('assets/dua.json');
      final data = json.decode(raw) as Map<String, dynamic>;
      final sections = data['sections'] as List<dynamic>;

      final allDuas = <_DailyDua>[];
      for (final section in sections) {
        final points =
            (section as Map<String, dynamic>)['points'] as List<dynamic>? ?? [];
        for (final point in points) {
          final map = point as Map<String, dynamic>;
          final arabic = map['arabic_text'] as String? ?? '';
          final english = map['translation_english'] as String? ?? '';
          final title = _englishTitle(map);

          if (arabic.isNotEmpty && english.isNotEmpty) {
            allDuas.add(_DailyDua(
              title: title,
              arabic: arabic,
              english: english,
            ));
          }
        }
      }

      if (allDuas.isEmpty) {
        if (!mounted) return;
        setState(() => _isDuaLoading = false);
        return;
      }

      final random = Random();
      final picked = allDuas[random.nextInt(allDuas.length)];

      if (!mounted) return;
      setState(() {
        _dailyDua = picked;
        _isDuaLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _isDuaLoading = false);
    }
  }

  void _copyDailyDua(_DailyDua dua) {
    final text = '${dua.arabic}\n\n${dua.english}';
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Row(
          children: [
            Icon(Icons.check_circle_rounded, color: Colors.white, size: 18),
            SizedBox(width: 10),
            Expanded(
              child: Text(
                'Dua copied to clipboard',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
        backgroundColor: const Color(0xFF00695C),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  static String _englishTitle(Map<String, dynamic> json) {
    final urdu = json['title_urdu'] as String? ?? '';
    return _titleMap[urdu] ?? 'Daily Supplication';
  }

  // ═══════════════════════════════════════════════════════
  // TILES
  // ═══════════════════════════════════════════════════════
  List<_NavTile> _buildTiles(BuildContext context) {
    return [
      _NavTile(
        icon: Icons.menu_book_rounded,
        label: 'Holy Quran',
        subtitle: 'Read & Listen',
        gradientStart: const Color(0xFF1B5E20),
        gradientEnd: const Color(0xFF43A047),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const QuranPage()),
          );
        },
      ),
      _NavTile(
        icon: Icons.fingerprint_rounded,
        label: 'Digital Tasbih',
        subtitle: 'Count Dhikr',
        gradientStart: const Color(0xFF0D47A1),
        gradientEnd: const Color(0xFF42A5F5),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const DigitalTasbihPage()),
          );
        },
      ),
      _NavTile(
        icon: Icons.explore_rounded,
        label: 'Qibla Finder',
        subtitle: 'Find Direction',
        gradientStart: const Color(0xFFBF360C),
        gradientEnd: const Color(0xFFFF7043),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const QiblaPage()),
          );
        },
      ),
      _NavTile(
        icon: Icons.access_time_filled_rounded,
        label: 'Prayer Times',
        subtitle: 'Daily Schedule',
        gradientStart: const Color(0xFF4A148C),
        gradientEnd: const Color(0xFFAB47BC),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const PrayerTimesPage()),
          );
        },
      ),
      _NavTile(
        icon: Icons.auto_awesome_rounded,
        label: 'Asma ul Husna',
        subtitle: '99 Names',
        gradientStart: const Color(0xFF006064),
        gradientEnd: const Color(0xFF26C6DA),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const AsmaUlHusnaPage()),
          );
        },
      ),
      _NavTile(
        icon: Icons.volunteer_activism_rounded,
        label: 'Islamic Duas',
        subtitle: 'Supplications',
        gradientStart: const Color(0xFF880E4F),
        gradientEnd: const Color(0xFFEC407A),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const DuasPage()),
          );
        },
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final tiles = _buildTiles(context);

    return Scaffold(
        backgroundColor: theme.scaffoldBackgroundColor,
        body: SafeArea(
          child: RefreshIndicator(
            onRefresh: _refreshAll,
            color: theme.colorScheme.primary,
            backgroundColor: theme.cardColor,
            displacement: 40,
            child: CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(
                parent: BouncingScrollPhysics(),
              ),
              slivers: [
                // ── 1. Top Banner: Current Prayer ──────────────────
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(18, 14, 18, 0),
                    child: Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: isDark
                              ? [
                                  const Color(0xFF0F3D14),
                                  const Color(0xFF1B5E20)
                                ]
                              : [
                                  const Color(0xFF1B5E20),
                                  const Color(0xFF43A047)
                                ],
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
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(6),
                                    decoration: BoxDecoration(
                                      color:
                                          Colors.white.withValues(alpha: 0.18),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: const Icon(
                                      Icons.mosque_rounded,
                                      color: Colors.white,
                                      size: 12,
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    'Current Prayer',
                                    style: TextStyle(
                                      color:
                                          Colors.white.withValues(alpha: 0.95),
                                      fontSize: 10.5,
                                      fontWeight: FontWeight.w600,
                                      letterSpacing: 0.4,
                                    ),
                                  ),
                                ],
                              ),
                              GestureDetector(
                                behavior: HitTestBehavior.opaque,
                                onTap: _openPrayerTimes,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 5,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize
                                        .min, // ← Row ko shrink-to-fit banayein
                                    children: [
                                      Icon(
                                        Icons.location_on_rounded,
                                        color: Colors.white
                                            .withValues(alpha: 0.95),
                                        size: 13,
                                      ),
                                      const SizedBox(width: 4),
                                      // ── Fixed width container ─────────────────────────
                                      SizedBox(
                                        width:
                                            120, // ← yahan jo width chahiye woh set karein
                                        child: Text(
                                          _locationLabel,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          softWrap: false, // ← extra safety
                                          style: TextStyle(
                                            color: Colors.white
                                                .withValues(alpha: 0.95),
                                            fontSize: 9.5,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Divider(color: const Color.fromARGB(255, 32, 92, 35)),
                          const SizedBox(height: 6),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                _nextPrayer,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 28,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: -0.5,
                                  height: 1,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Padding(
                                padding: const EdgeInsets.only(bottom: 0),
                                child: Text(
                                  _nextPrayerTime,
                                  style: TextStyle(
                                    color: Colors.white.withValues(alpha: 0.85),
                                    fontSize: 15,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                              const Spacer(),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.2),
                                  borderRadius: BorderRadius.circular(30),
                                  border: Border.all(
                                    color: Colors.white.withValues(alpha: 0.25),
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(
                                      Icons.access_time_rounded,
                                      color: Colors.white,
                                      size: 14,
                                    ),
                                    const SizedBox(width: 5),
                                    Text(
                                      _countdown,
                                      style: TextStyle(
                                        color: Colors.white
                                            .withValues(alpha: 0.98),
                                        fontSize: 10,
                                        fontWeight: FontWeight.w700,
                                        letterSpacing: 0.2,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                // ── 2. Greeting + Settings ─────────────────────────
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 22, 20, 6),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Assalamu Alaikum',
                                style: theme.textTheme.titleLarge?.copyWith(
                                  fontWeight: FontWeight.w700,
                                  color: theme.colorScheme.onSurface,
                                  fontSize: 20,
                                  letterSpacing: -0.3,
                                  height: 1.2,
                                ),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                'May Allah bless your day',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: theme.colorScheme.onSurface
                                      .withValues(alpha: 0.5),
                                  fontSize: 12,
                                  letterSpacing: 0.1,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        Material(
                          color:
                              theme.colorScheme.primary.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(14),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(14),
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => SettingsPage(
                                    themeController: widget.themeController,
                                  ),
                                ),
                              );
                            },
                            child: Padding(
                              padding: const EdgeInsets.all(11),
                              child: Icon(
                                Icons.settings_rounded,
                                color: theme.colorScheme.primary,
                                size: 22,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // ── 3. Grid of Navigation Tiles ────────────────────
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(18, 12, 18, 8),
                  sliver: SliverGrid(
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      mainAxisSpacing: 14,
                      crossAxisSpacing: 14,
                      childAspectRatio: 1.0,
                    ),
                    delegate: SliverChildBuilderDelegate(
                      (context, index) => _GradientNavTile(tile: tiles[index]),
                      childCount: tiles.length,
                    ),
                  ),
                ),

                // ── 4. Daily Dua ───────────────────────────────────
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(18, 22, 18, 28),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  colors: [
                                    Color(0xFF00695C),
                                    Color(0xFF26A69A)
                                  ],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                                borderRadius: BorderRadius.circular(10),
                                boxShadow: [
                                  BoxShadow(
                                    color: const Color(0xFF00695C)
                                        .withValues(alpha: 0.35),
                                    blurRadius: 10,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: const Icon(
                                Icons.auto_stories_rounded,
                                size: 15,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(width: 11),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Daily Dua',
                                    style:
                                        theme.textTheme.titleMedium?.copyWith(
                                      fontWeight: FontWeight.w700,
                                      color: theme.colorScheme.onSurface,
                                      fontSize: 16,
                                      letterSpacing: -0.2,
                                      height: 1.2,
                                    ),
                                  ),
                                  Text(
                                    'Refresh your Iman',
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      color: theme.colorScheme.onSurface
                                          .withValues(alpha: 0.5),
                                      fontSize: 11,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        if (_isDuaLoading)
                          _buildDuaLoadingCard(isDark)
                        else if (_dailyDua == null)
                          _buildDuaEmptyCard(theme)
                        else
                          _buildDuaCard(
                            theme: theme,
                            isDark: isDark,
                            dua: _dailyDua!,
                          ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ));
  }

  // ── Loading state ───────────────────────────────────────
  Widget _buildDuaLoadingCard(bool isDark) {
    return Container(
      height: 260,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isDark
              ? [const Color(0xFF0F2027), const Color(0xFF1B3A3F)]
              : [const Color(0xFF00695C), const Color(0xFF26A69A)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color:
                const Color(0xFF00695C).withValues(alpha: isDark ? 0.4 : 0.28),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: const Center(
        child: CircularProgressIndicator(
          color: Colors.white,
          strokeWidth: 2.5,
        ),
      ),
    );
  }

  Widget _buildDuaEmptyCard(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Text(
        'No dua available.',
        style: theme.textTheme.bodyMedium?.copyWith(
          color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
        ),
      ),
    );
  }

  Widget _buildDuaCard({
    required ThemeData theme,
    required bool isDark,
    required _DailyDua dua,
  }) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isDark
              ? [const Color(0xFF0F2027), const Color(0xFF1B3A3F)]
              : [const Color(0xFF00695C), const Color(0xFF26A69A)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color:
                const Color(0xFF00695C).withValues(alpha: isDark ? 0.4 : 0.28),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            right: -24,
            top: -24,
            child: Icon(
              Icons.mosque_rounded,
              size: 150,
              color: Colors.white.withValues(alpha: 0.06),
            ),
          ),
          Positioned(
            left: -30,
            bottom: -30,
            child: Icon(
              Icons.auto_awesome_rounded,
              size: 130,
              color: Colors.white.withValues(alpha: 0.05),
            ),
          ),
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Container(
              height: 1,
              margin: const EdgeInsets.symmetric(horizontal: 28),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(1),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(22),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 11,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.18),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.25),
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 6,
                            height: 6,
                            decoration: const BoxDecoration(
                              color: Color(0xFF69F0AE),
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 7),
                          const Text(
                            'TODAY',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 1.4,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.18),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.25),
                        ),
                      ),
                      child: const Icon(
                        Icons.bookmark_border_rounded,
                        color: Colors.white,
                        size: 16,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                Text(
                  dua.arabic,
                  textAlign: TextAlign.center,
                  textDirection: TextDirection.rtl,
                  style: const TextStyle(
                    fontSize: 22,
                    height: 2.0,
                    fontWeight: FontWeight.w500,
                    color: Colors.white,
                    fontFamily: 'serif',
                    letterSpacing: 0.3,
                  ),
                ),
                const SizedBox(height: 22),
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
                      padding: const EdgeInsets.symmetric(horizontal: 12),
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
                const SizedBox(height: 20),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.2),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.translate_rounded,
                            size: 13,
                            color: Colors.white.withValues(alpha: 0.9),
                          ),
                          const SizedBox(width: 7),
                          Text(
                            'TRANSLATION',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.9),
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 1.2,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Text(
                        dua.english,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.95),
                          height: 1.6,
                          fontSize: 13.5,
                          fontWeight: FontWeight.w400,
                          letterSpacing: 0.1,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(7),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(
                              Icons.menu_book_rounded,
                              size: 13,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(width: 9),
                          Expanded(
                            child: Text(
                              dua.title,
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.95),
                                fontSize: 11.5,
                                fontWeight: FontWeight.w600,
                                letterSpacing: 0.2,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Material(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(20),
                        onTap: () => _copyDailyDua(dua),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.12),
                                blurRadius: 8,
                                offset: const Offset(0, 3),
                              ),
                            ],
                          ),
                          child: const Row(
                            children: [
                              Icon(
                                Icons.copy_rounded,
                                size: 13,
                                color: Color(0xFF00695C),
                              ),
                              SizedBox(width: 6),
                              Text(
                                'Copy',
                                style: TextStyle(
                                  color: Color(0xFF00695C),
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 0.2,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Urdu → English title map ──────────────────────────
  static const Map<String, String> _titleMap = {
    'ایمان مجمل': 'Iman Mujmal (Concise Faith)',
    'ایمان مفصل': 'Iman Mufassal (Detailed Faith)',
    'نیند سے بیدار ہوتے وقت': 'When Waking Up',
    'سونے کے لئے بستر پر جاتے وقت': 'Before Sleeping',
    'بیت الخلاء میں جاتے ہوئے': 'Entering the Restroom',
    'بیت الخلاء سے نکلتے ہوئے': 'Leaving the Restroom',
    'وضو کے دوران': 'During Wudu',
    'وضو کے بعد': 'After Wudu',
    'غسل سے پہلے': 'Before Ghusl (Bath)',
    'مسجد مىں داخل ہوتے وقت': 'Entering the Mosque',
    'مسجد سے باہر نکلتے وقت': 'Leaving the Mosque',
    'اذان کى آواز سن کر': 'Hearing the Adhan',
    'اذان کے ختم پر یہ دعا پڑھے': 'After the Adhan',
    'فرض نماز سے سلام پھیرنے کے بعد': 'After Fard Prayer',
    'گھر میں داخل ہوتے وقت': 'Entering the Home',
    'افطار کے وقت': 'When Breaking the Fast',
    'کھانے کے بعد': 'After Eating',
    'اگر کھانا کسى اور نے کھلایا ہو': 'When Someone Feeds You',
    'کپڑے بدلتے وقت': 'When Changing Clothes',
    'جب کسى دشمن کا خوف ہو': 'When Fearing an Enemy',
    'جب کوئى کام مشکل معلوم ہو': 'When a Task Feels Difficult',
    'نیا کپڑا پہنتے وقت': 'Wearing New Clothes',
    'جب بازار مىں داخل ہو': 'Entering the Marketplace',
    'جب کسى سوارى پر سوار ہو': 'When Boarding a Vehicle',
    'سفر کى دعا': 'Dua for Travel',
    'جب کسى نئى بستى مىں داخل ہو': 'Entering a New Town',
    'بیمار کےلئے نبى ﷺ کى دعا': 'Dua for the Sick (Prophetic)',
    'نکاح کى مبارکباد': 'Wedding Congratulations',
    'جماع کے وقت': 'At the Time of Intimacy',
    'انزال کے وقت': 'At the Time of Emission',
    'مہینے کا پہلا چاند دیکھ کر': 'Sighting the New Moon',
    'جب غصہ آئے': 'When Angry',
    'جامع دعا': 'Comprehensive Dua',
    'ہر مجلس کے آخر میں': 'At the End of Every Gathering',
    'جب آئینہ میں اپنا چہرہ دیکھے تو یہ دعا مانگے':
        'When Looking in the Mirror',
    'عورت نکاح کر کے لائے یا خادم لائے تو پڑھے':
        'When Bringing a Bride or Servant Home',
    'بیمار یا مصیبت زدہ کو دیکھ کر یہ دعا پڑھے':
        'When Seeing the Sick or Afflicted',
    'ہدایت اور صراط مستقیم کی دعا (سورۃ الفاتحہ)':
        'Guidance — Surah Al-Fatihah',
    'جہالت سے حفاظت کی دعا (سورۃ البقرۃ - 67)': 'Protection from Ignorance',
    'اعمال کی قبولیت اور درگزر کی دعا (سورۃ البقرۃ 127-128)':
        'Acceptance of Deeds',
    'دنیا اور آخرت میں بھلائی کی دعا (سورۃ البقرۃ 201)':
        'Goodness in Both Worlds',
    'صبر، استقامت اور نصرت کی دعا (سورۃ البقرۃ 250)': 'Patience & Victory',
    'مغفرت کی دعا (سورۃ البقرۃ 285)': 'Seeking Forgiveness',
    'بھول چوک اور خطاؤں پر درگزر کی دعا (سورۃ البقرۃ 286)':
        'Pardon for Mistakes',
    'صراط مستقیم پر استقامت کی دعا (سورۃ آل عمران 8)':
        'Steadfastness on the Straight Path',
    'جہنم کی آگ سے حفاظت کی دعا (سورۃ آل عمران 16)': 'Protection from the Fire',
    'نیک اولاد کی دعا (سورۃ آل عمران 38)': 'Righteous Offspring',
    'ثابت قدمی اور اللہ کی مدد کی دعا (سورۃ آل عمران 147)':
        'Firmness & Divine Help',
    'قیامت کے دن رسوائی سے بچنے کی دعا (سورۃ آل عمران 193-194)':
        'Protection from Disgrace',
    'گواہی دینے والوں میں شمولیت کی دعا (سورۃ المائدۃ 83)':
        'Among the Witnesses',
    'نیک لوگوں میں شامل ہونے کی دعا (سورۃ المائدۃ 84)': 'Among the Righteous',
    'مغفرت اور رحمت کی دعا (سورۃ الاعراف 23)': 'Forgiveness & Mercy',
    'ظالموں کی معیت سے بچنے کی دعا (سورۃ الاعراف 47)':
        'Avoiding the Wrongdoers',
    'حق کے فیصلے کی دعا (سورۃ الاعراف 89)': 'Judgement with Truth',
    'صبر اور حسنِ خاتمہ کی دعا (سورۃ الاعراف 126)': 'Patience & a Good End',
    'معافی اور رحمت کی دعا (سورۃ الاعراف 151)': 'Pardon & Mercy',
    'دنیا اور آخرت میں بھلائی کی دعا (سورۃ الاعراف 155-156)':
        'Goodness in Both Worlds (Al-A\'raf)',
    'اللہ پر توکل کی دعا (سورۃ التوبۃ 129)': 'Trust in Allah',
    'فتنہ بننے سے بچنے کی دعا (سورۃ یونس 85-86)':
        'Protection from Being a Trial',
    'جہالت اور لاعلمی سے بچنے کی دعا (سورۃ ہود 47)':
        'Protection from Ignorance (Hud)',
    'ظاہر و باطن اللہ کو دکھانے کی دعا (سورۃ ابراہیم 38)': 'Allah Sees All',
    'اقامت نماز اور والدین کی بخشش کی دعا (سورۃ ابراہیم 40-41)':
        'Prayer & Forgiveness for Parents',
    'والدین کے لئے رحمت کی دعا (سورۃ الاسراء 24)': 'Mercy for Parents',
    'معاملات میں درستگی کی دعا (سورۃ الکھف 10)': 'Right Guidance in Affairs',
    'علم میں اضافے کی دعا (سورۃ طہٰ 114)': 'Increase in Knowledge',
    'قصور کے اعتراف کی دعا (سورۃ الانبیاء 87)': 'Admitting One\'s Faults',
    'اللہ کے ساتھ کی دعا (سورۃ الانبیاء 89)': 'Not Left Alone',
    'برکت کی جگہ کی دعا (سورۃ المومنون 29)': 'A Blessed Destination',
    'ظالم لوگوں سے حفاظت کی دعا (سورۃ المومنون 94)':
        'Protection from the Wrongdoers',
    'شیاطین سے حفاظت کی دعا (سورۃ المومنون 97-98)': 'Protection from Devils',
    'مغفرت اور رحمت کی دعا (سورۃ المومنون 109)':
        'Forgiveness & Mercy (Al-Mu\'minun)',
    'مغفرت اور رحمت کی دعا (سورۃ المومنون 118)':
        'Forgiveness & Mercy (Al-Mu\'minun 118)',
    'جہنم کے عذاب سے حفاظت کی دعا (سورۃ الفرقان 65-66)':
        'Protection from Hellfire',
    'بیوی بچوں سے آنکھوں کی ٹھنڈک کی دعا (سورۃ الفرقان 74)':
        'Comfort in Family',
    'نعمتوں بھری جنت کی دعا (سورۃ الشعراء 83-85)': 'The Garden of Bliss',
    'قیامت کی رسوائی سے حفاظت کی دعا (سورۃ الشعراء 87-88)':
        'Protection from Disgrace (Ash-Shu\'ara)',
    'ظالم قوم سے حفاظت کی دعا (سورۃ القصص 21)':
        'Protection from an Oppressive People',
    'صالح بندوں میں شمولیت کی دعا (سورۃ النمل 19)':
        'Among the Righteous Servants',
    'مفسد لوگوں کے مقابلے میں مدد کی دعا (سورۃ العنکبوت 30)':
        'Help Against the Corrupters',
    'نیک اولاد کی دعا (سورۃ الصافات 100)': 'Righteous Offspring (As-Saffat)',
    'رسولوں پر سلامتی کی دعا (سورۃ الصافات 180-182)':
        'Peace Upon the Messengers',
    'برائیوں سے حفاظت کی دعا (سورۃ غافر 7-8)': 'Protection from Evil (Ghafir)',
    'برائیوں سے حفاظت کی دعا (سورۃ غافر 9)': 'Protection from Evil (Ghafir 9)',
    'عذاب سے حفاظت کی دعا (سورۃ الدخان 12)': 'Removal of Affliction',
    'شکر کی توفیق کی دعا (سورۃ الاحقاف 15)': 'Gratitude & Righteous Offspring',
    'اللہ پر توکل کی دعا (سورۃ الممتحنۃ 4)': 'Trust & Repentance',
    'بغض سے حفاظت کی دعا (سورۃ الحشر 10)': 'Protection from Rancour',
    'قصوروں سے درگزر کی دعا (سورۃ الممتحنۃ 5)': 'Pardon for Shortcomings',
    'نور کی تکمیل کی دعا (سورۃ التحریم 8)': 'Perfection of Light',
    'تمام مسلمانوں کے لئے مغفرت کی دعا (سورۃ نوح 28)':
        'Forgiveness for All Believers',
  };
}

// ─────────────────────────────────────────────────────────
// Models
// ─────────────────────────────────────────────────────────
class _City {
  final String name;
  final String country;
  const _City(this.name, this.country);
}

class _DailyDua {
  final String title;
  final String arabic;
  final String english;

  const _DailyDua({
    required this.title,
    required this.arabic,
    required this.english,
  });
}

class _NavTile {
  final IconData icon;
  final String label;
  final String subtitle;
  final Color gradientStart;
  final Color gradientEnd;
  final VoidCallback? onTap;

  const _NavTile({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.gradientStart,
    required this.gradientEnd,
    this.onTap,
  });
}

// ─────────────────────────────────────────────────────────
// Premium gradient tile
// ─────────────────────────────────────────────────────────
class _GradientNavTile extends StatefulWidget {
  final _NavTile tile;

  const _GradientNavTile({required this.tile});

  @override
  State<_GradientNavTile> createState() => _GradientNavTileState();
}

class _GradientNavTileState extends State<_GradientNavTile>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 120),
      lowerBound: 0.0,
      upperBound: 1.0,
    );
    _scale = Tween<double>(begin: 1.0, end: 0.95).animate(
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
    final tile = widget.tile;

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
        onTap: () {
          widget.tile.onTap?.call();
        },
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [tile.gradientStart, tile.gradientEnd],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(22),
            boxShadow: [
              BoxShadow(
                color: tile.gradientStart.withValues(alpha: 0.32),
                blurRadius: 16,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Stack(
            children: [
              Positioned(
                right: -14,
                bottom: -14,
                child: Icon(
                  tile.icon,
                  size: 100,
                  color: Colors.white.withValues(alpha: 0.10),
                ),
              ),
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: Container(
                  height: 1,
                  margin: const EdgeInsets.symmetric(horizontal: 22),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.35),
                    borderRadius: BorderRadius.circular(1),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.22),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.3),
                          width: 1,
                        ),
                      ),
                      child: Icon(
                        tile.icon,
                        color: Colors.white,
                        size: 24,
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          tile.label,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 15.5,
                            fontWeight: FontWeight.w700,
                            letterSpacing: -0.1,
                            height: 1.2,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          tile.subtitle,
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.8),
                            fontSize: 11.5,
                            fontWeight: FontWeight.w500,
                            letterSpacing: 0.1,
                            height: 1.2,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
