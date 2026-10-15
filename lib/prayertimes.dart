import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show HapticFeedback;
import 'package:http/http.dart' as http;
import 'package:quran_pak/adhan_service.dart';
import 'package:quran_pak/location_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ─────────────────────────────────────────────────────────
// Calculation methods (Aladhan API codes)
// ─────────────────────────────────────────────────────────
class _Method {
  final int id;
  final String name;
  const _Method(this.id, this.name);
}

const List<_Method> _methods = [
  _Method(1, 'University of Islamic Sciences, Karachi'),
  _Method(2, 'Islamic Society of North America (ISNA)'),
  _Method(3, 'Muslim World League'),
  _Method(4, 'Umm Al-Qura University, Makkah'),
  _Method(5, 'Egyptian General Authority of Survey'),
  _Method(7, 'Institute of Geophysics, University of Tehran'),
  _Method(8, 'Gulf Region'),
  _Method(9, 'Kuwait'),
  _Method(10, 'Qatar'),
  _Method(11, 'Majlis Ugama Islam Singapura, Singapore'),
  _Method(12, 'Union Organization Islamic de France'),
  _Method(13, 'Diyanet İşleri Başkanlığı, Turkey'),
  _Method(14, 'Spiritual Administration of Muslims of Russia'),
  _Method(15, 'Moonsighting Committee Worldwide'),
  _Method(16, 'Dubai (unofficial)'),
  _Method(17, 'JAKIM, Malaysia'),
  _Method(18, 'Tunisia'),
  _Method(19, 'Algeria'),
  _Method(20, 'KEMENAG, Indonesia'),
  _Method(21, 'Morocco'),
  _Method(22, 'Comunidade Islamica de Lisboa'),
  _Method(23, 'Ministry of Awqaf, Jordan'),
];

// ─────────────────────────────────────────────────────────
// Cities (curated worldwide list)
// ─────────────────────────────────────────────────────────
class _City {
  final String name;
  final String country;
  const _City(this.name, this.country);
}

const List<_City> _cities = [
  // Middle East
  _City('Makkah', 'Saudi Arabia'),
  _City('Madinah', 'Saudi Arabia'),
  _City('Riyadh', 'Saudi Arabia'),
  _City('Jeddah', 'Saudi Arabia'),
  _City('Dubai', 'UAE'),
  _City('Abu Dhabi', 'UAE'),
  _City('Doha', 'Qatar'),
  _City('Kuwait City', 'Kuwait'),
  _City('Manama', 'Bahrain'),
  _City('Muscat', 'Oman'),
  _City('Amman', 'Jordan'),
  _City('Beirut', 'Lebanon'),
  _City('Damascus', 'Syria'),
  _City('Baghdad', 'Iraq'),
  _City('Jerusalem', 'Palestine'),
  _City('Gaza', 'Palestine'),
  _City('Tehran', 'Iran'),
  _City('Istanbul', 'Turkey'),
  _City('Ankara', 'Turkey'),
  // South Asia
  _City('Karachi', 'Pakistan'),
  _City('Lahore', 'Pakistan'),
  _City('Islamabad', 'Pakistan'),
  _City('Peshawar', 'Pakistan'),
  _City('Quetta', 'Pakistan'),
  _City('Multan', 'Pakistan'),
  _City('Faisalabad', 'Pakistan'),
  _City('Rawalpindi', 'Pakistan'),
  _City('Delhi', 'India'),
  _City('Mumbai', 'India'),
  _City('Hyderabad', 'India'),
  _City('Bangalore', 'India'),
  _City('Kolkata', 'India'),
  _City('Lucknow', 'India'),
  _City('Dhaka', 'Bangladesh'),
  _City('Chattogram', 'Bangladesh'),
  _City('Colombo', 'Sri Lanka'),
  _City('Kabul', 'Afghanistan'),
  _City('Kathmandu', 'Nepal'),
  _City('Male', 'Maldives'),
  // Southeast Asia
  _City('Jakarta', 'Indonesia'),
  _City('Surabaya', 'Indonesia'),
  _City('Bandung', 'Indonesia'),
  _City('Kuala Lumpur', 'Malaysia'),
  _City('Singapore', 'Singapore'),
  _City('Bangkok', 'Thailand'),
  _City('Manila', 'Philippines'),
  _City('Hanoi', 'Vietnam'),
  // Africa
  _City('Cairo', 'Egypt'),
  _City('Alexandria', 'Egypt'),
  _City('Casablanca', 'Morocco'),
  _City('Rabat', 'Morocco'),
  _City('Tunis', 'Tunisia'),
  _City('Algiers', 'Algeria'),
  _City('Tripoli', 'Libya'),
  _City('Khartoum', 'Sudan'),
  _City('Lagos', 'Nigeria'),
  _City('Kano', 'Nigeria'),
  _City('Nairobi', 'Kenya'),
  _City('Mombasa', 'Kenya'),
  _City('Addis Ababa', 'Ethiopia'),
  _City('Dakar', 'Senegal'),
  _City('Cape Town', 'South Africa'),
  _City('Johannesburg', 'South Africa'),
  // Europe
  _City('London', 'UK'),
  _City('Birmingham', 'UK'),
  _City('Manchester', 'UK'),
  _City('Paris', 'France'),
  _City('Marseille', 'France'),
  _City('Berlin', 'Germany'),
  _City('Frankfurt', 'Germany'),
  _City('Amsterdam', 'Netherlands'),
  _City('Brussels', 'Belgium'),
  _City('Madrid', 'Spain'),
  _City('Barcelona', 'Spain'),
  _City('Rome', 'Italy'),
  _City('Milan', 'Italy'),
  _City('Vienna', 'Austria'),
  _City('Stockholm', 'Sweden'),
  _City('Oslo', 'Norway'),
  _City('Copenhagen', 'Denmark'),
  _City('Moscow', 'Russia'),
  _City('Sarajevo', 'Bosnia'),
  _City('Tirana', 'Albania'),
  // Americas
  _City('New York', 'USA'),
  _City('Chicago', 'USA'),
  _City('Houston', 'USA'),
  _City('Los Angeles', 'USA'),
  _City('Detroit', 'USA'),
  _City('Toronto', 'Canada'),
  _City('Vancouver', 'Canada'),
  _City('Montreal', 'Canada'),
  _City('Mexico City', 'Mexico'),
  _City('São Paulo', 'Brazil'),
  _City('Buenos Aires', 'Argentina'),
  // Oceania
  _City('Sydney', 'Australia'),
  _City('Melbourne', 'Australia'),
  _City('Auckland', 'New Zealand'),
];

// ─────────────────────────────────────────────────────────
// Prayer times page
// ─────────────────────────────────────────────────────────
class PrayerTimesPage extends StatefulWidget {
  const PrayerTimesPage({super.key});

  @override
  State<PrayerTimesPage> createState() => _PrayerTimesPageState();
}

class _PrayerTimesPageState extends State<PrayerTimesPage> {
  Map<String, String>? _prayerTimes;

  String? _locationName;
  bool _isLoading = true;
  String? _error;
  bool _canOpenSettings = false;
  bool _serviceOff = false; // GPS off → open location settings instead

  // Location mode: 'auto' or 'manual'
  String _mode = 'auto';
  _City? _selectedCity;

  // Calculation method
  int _methodId = 1;
  int _schoolId = 1; // 0 = Shafi, 1 = Hanafi

  // Storage keys
  static const _prefsMode = 'pt_mode';
  static const _prefsCity = 'pt_city';
  static const _prefsMethod = 'pt_method';
  static const _prefsSchool = 'pt_school';

  @override
  void initState() {
    super.initState();
    _restoreAndLoad();
  }

  Future<void> _restoreAndLoad() async {
    // Restore saved preferences
    try {
      final prefs = await SharedPreferences.getInstance();
      _mode = prefs.getString(_prefsMode) ?? 'auto';
      _methodId = prefs.getInt(_prefsMethod) ?? 1;
      _schoolId = prefs.getInt(_prefsSchool) ?? 1;

      final cityJson = prefs.getString(_prefsCity);
      if (cityJson != null && cityJson.isNotEmpty) {
        final decoded = json.decode(cityJson) as Map<String, dynamic>;
        _selectedCity = _City(
          decoded['name'] as String? ?? '',
          decoded['country'] as String? ?? '',
        );
      }
    } catch (_) {}

    if (!mounted) return;

    if (_mode == 'manual' && _selectedCity != null) {
      // Load immediately, no permission prompt
      _fetchByCity(_selectedCity!);
    } else {
      // Auto mode → show intro dialog
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => _startLocationFlow(showIntro: true),
      );
    }
  }

  void _fail(String message,
      {bool openSettings = false, bool serviceOff = false}) {
    if (!mounted) return;
    setState(() {
      _isLoading = false;
      _error = message;
      _canOpenSettings = openSettings;
      _serviceOff = serviceOff;
    });
  }

  /// [permissionRetry] = the user tapped "Try Again" on a location error, so
  /// we may ask for permission again. Method/school changes pass false and
  /// simply reuse the saved location.
  void _retry({bool permissionRetry = false}) {
    setState(() {
      _isLoading = true;
      _error = null;
      _canOpenSettings = false;
      _serviceOff = false;
    });
    if (_mode == 'manual' && _selectedCity != null) {
      _fetchByCity(_selectedCity!);
    } else {
      _startLocationFlow(showIntro: false, userInitiated: permissionRetry);
    }
  }

  // ── Auto (GPS) flow ─────────────────────────────────────
  // Uses the saved location first; only talks to the OS when nothing is saved
  // (or the user explicitly asked for a fresh fix).
  Future<void> _startLocationFlow({
    required bool showIntro,
    bool userInitiated = false,
    bool forceFresh = false,
  }) async {
    await _getLocationAndLoad(
      userInitiated: userInitiated,
      forceFresh: forceFresh,
    );
  }

  Future<void> _getLocationAndLoad({
    bool userInitiated = false,
    bool forceFresh = false,
  }) async {
    final svc = LocationService.instance;
    final result = forceFresh
        ? await svc.request(userInitiated: true)
        : await svc.ensure(userInitiated: userInitiated);

    final loc = result.location;
    if (loc != null) {
      await _fetchByCoords(loc.lat, loc.lng, label: loc.label);
      return;
    }

    // GPS hiccup but we still know where the user is → keep working.
    if (result.status == LocationStatus.timeout ||
        result.status == LocationStatus.error) {
      final cached = svc.current.value;
      if (cached != null) {
        await _fetchByCoords(cached.lat, cached.lng, label: cached.label);
        return;
      }
    }

    switch (result.status) {
      case LocationStatus.serviceOff:
        _fail(
          'Location services are turned off. Turn on GPS, or choose a city instead.',
          openSettings: !kIsWeb,
          serviceOff: true,
        );
        break;
      case LocationStatus.deniedForever:
        _fail(
          kIsWeb
              ? 'Location is blocked in your browser. Click the lock icon in the address bar, allow Location, then try again.'
              : 'Location permission is blocked. Enable it in app settings, or choose a city instead.',
          openSettings: !kIsWeb,
        );
        break;
      case LocationStatus.denied:
        _fail(
          'Location permission was not granted. Tap Try Again to allow it, or choose a city instead.',
        );
        break;
      case LocationStatus.timeout:
        _fail('Timed out while getting your location. Please try again.');
        break;
      default:
        _fail('Could not get your location. Try again or choose a city.');
    }
  }

  // ── Fetch by coordinates ────────────────────────────────
  Future<void> _fetchByCoords(double lat, double lng, {String? label}) async {
    try {
      final now = DateTime.now();
      final url = Uri.parse(
        'https://api.aladhan.com/v1/timings/${now.day}-${now.month}-${now.year}'
        '?latitude=$lat&longitude=$lng&method=$_methodId&school=$_schoolId',
      );

      final response = await http.get(url).timeout(const Duration(seconds: 15));
      if (response.statusCode != 200) {
        _fail('Failed to load times from server (${response.statusCode}).');
        return;
      }

      final data = json.decode(response.body);
      if (data['code'] != 200) {
        _fail('Failed to load times from server.');
        return;
      }

      final timings = data['data']['timings'] as Map<String, dynamic>;
      final timezone = (data['data']['meta']['timezone'] ?? '') as String;
      final cityName = label ?? await _reverseGeocode(lat, lng);

      if (!mounted) return;
      setState(() {
        _prayerTimes = _buildTimingsMap(timings);

        _locationName =
            cityName ?? (timezone.isNotEmpty ? timezone : 'Current Location');
        _isLoading = false;
        _error = null;
      });
      AdhanService.instance.updateSchedule(_prayerTimes);
    } on TimeoutException {
      _fail('Request timed out. Please check your connection.');
    } catch (e) {
      _fail('Network error. Please check your connection.');
    }
  }

  // ── Fetch by city name ──────────────────────────────────
  Future<void> _fetchByCity(_City city) async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final now = DateTime.now();
      final url = Uri.parse(
        'https://api.aladhan.com/v1/timingsByCity/${now.day}-${now.month}-${now.year}'
        '?city=${Uri.encodeComponent(city.name)}'
        '&country=${Uri.encodeComponent(city.country)}'
        '&method=$_methodId&school=$_schoolId',
      );

      final response = await http.get(url).timeout(const Duration(seconds: 15));
      if (response.statusCode != 200) {
        _fail('Failed to load times from server (${response.statusCode}).');
        return;
      }

      final data = json.decode(response.body);
      if (data['code'] != 200) {
        _fail('Failed to load times for ${city.name}.');
        return;
      }

      final timings = data['data']['timings'] as Map<String, dynamic>;

      if (!mounted) return;
      setState(() {
        _prayerTimes = _buildTimingsMap(timings);

        _locationName = '${city.name}, ${city.country}';
        _isLoading = false;
        _error = null;
      });
      AdhanService.instance.updateSchedule(_prayerTimes);
    } on TimeoutException {
      _fail('Request timed out. Please check your connection.');
    } catch (e) {
      _fail('Network error. Please check your connection.');
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

  Future<String?> _reverseGeocode(double lat, double lng) async {
    try {
      final url = Uri.parse(
        'https://api.bigdatacloud.net/data/reverse-geocode-client'
        '?latitude=$lat&longitude=$lng&localityLanguage=en',
      );
      final res = await http.get(url).timeout(const Duration(seconds: 8));
      if (res.statusCode != 200) return null;
      final d = json.decode(res.body) as Map<String, dynamic>;
      final parts = <String>[
        (d['city'] ?? d['locality'] ?? '') as String,
        (d['principalSubdivision'] ?? '') as String,
        (d['countryName'] ?? '') as String,
      ].where((s) => s.trim().isNotEmpty).toList();
      return parts.isEmpty ? null : parts.join(', ');
    } catch (_) {
      return null;
    }
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

  // ── Persist prefs ───────────────────────────────────────
  Future<void> _savePrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefsMode, _mode);
      await prefs.setInt(_prefsMethod, _methodId);
      await prefs.setInt(_prefsSchool, _schoolId);
      if (_selectedCity != null) {
        await prefs.setString(
          _prefsCity,
          json.encode({
            'name': _selectedCity!.name,
            'country': _selectedCity!.country,
          }),
        );
      } else {
        await prefs.remove(_prefsCity);
      }
    } catch (_) {}
  }

  // ── Actions ─────────────────────────────────────────────
  void _pickModeAuto() {
    HapticFeedback.selectionClick();
    setState(() {
      _mode = 'auto';
      _selectedCity = null;
      _isLoading = true;
      _error = null;
    });
    _savePrefs();
    _startLocationFlow(showIntro: false, userInitiated: true, forceFresh: true);
  }

  Future<void> _pickModeManual() async {
    HapticFeedback.selectionClick();
    final picked = await _showCityPicker();
    if (picked == null) return;
    setState(() {
      _mode = 'manual';
      _selectedCity = picked;
      _isLoading = true;
      _error = null;
    });
    _savePrefs();
    _fetchByCity(picked);
  }

  Future<void> _changeCity() async {
    final picked = await _showCityPicker();
    if (picked == null) return;
    setState(() {
      _selectedCity = picked;
      _isLoading = true;
      _error = null;
    });
    _savePrefs();
    _fetchByCity(picked);
  }

  Future<void> _changeMethod() async {
    final picked = await _showMethodPicker();
    if (picked == null) return;
    setState(() {
      _methodId = picked.id;
      _isLoading = true;
      _error = null;
    });
    _savePrefs();
    _retry();
  }

  Future<void> _changeSchool() async {
    final picked = await showModalBottomSheet<int>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _SchoolPickerSheet(current: _schoolId),
    );
    if (picked == null) return;
    setState(() {
      _schoolId = picked;
      _isLoading = true;
      _error = null;
    });
    _savePrefs();
    _retry();
  }

  Future<_City?> _showCityPicker() async {
    return showModalBottomSheet<_City>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _CityPickerSheet(
        cities: _cities,
        selected: _selectedCity,
      ),
    );
  }

  Future<_Method?> _showMethodPicker() async {
    return showModalBottomSheet<_Method>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _MethodPickerSheet(
        methods: _methods,
        selectedId: _methodId,
      ),
    );
  }

  // ── Build ───────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: SafeArea(
        child: Column(
          children: [
            _buildAppBarRow(theme),
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _error != null
                      ? _buildError(theme)
                      : _buildList(context),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAppBarRow(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 10, 18, 4),
      child: Row(
        children: [
          Material(
            color: theme.colorScheme.primary.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () => Navigator.pop(context),
              child: Padding(
                padding: const EdgeInsets.all(9),
                child: Icon(
                  Icons.arrow_back_rounded,
                  color: theme.colorScheme.primary,
                  size: 20,
                ),
              ),
            ),
          ),
          Expanded(
            child: Center(
              child: Text(
                'Prayer Times',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: theme.colorScheme.onSurface,
                  letterSpacing: -0.2,
                ),
              ),
            ),
          ),
          Material(
            color: theme.colorScheme.primary.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () => _retry(permissionRetry: true),
              child: Padding(
                padding: const EdgeInsets.all(9),
                child: Icon(
                  Icons.refresh_rounded,
                  color: theme.colorScheme.primary,
                  size: 20,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildList(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(18, 8, 18, 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── Location banner ──────────────────────────────
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: isDark
                    ? [const Color(0xFF1B5E20), const Color(0xFF2E7D32)]
                    : [const Color(0xFF2E7D32), const Color(0xFF43A047)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF2E7D32).withValues(alpha: 0.3),
                  blurRadius: 18,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      _mode == 'auto'
                          ? Icons.my_location_rounded
                          : Icons.location_city_rounded,
                      color: Colors.white,
                      size: 16,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      _mode == 'auto' ? 'Auto Location' : 'Selected City',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.85),
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  _locationName ?? 'Fetching...',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.3,
                  ),
                ),
                const SizedBox(height: 14),
                // ── Location action buttons ─────────────────
                Row(
                  children: [
                    Expanded(
                      child: _buildBannerAction(
                        icon: Icons.my_location_rounded,
                        label: 'Auto',
                        selected: _mode == 'auto',
                        onTap: _pickModeAuto,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _buildBannerAction(
                        icon: Icons.location_city_rounded,
                        label: 'Choose City',
                        selected: _mode == 'manual',
                        onTap: _pickModeManual,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // ── Next prayer card ─────────────────────────────
          if (_prayerTimes != null && _prayerTimes!.isNotEmpty)
            _buildNextPrayerCard(theme, isDark),

          const SizedBox(height: 16),

          // ── Prayer time cards ────────────────────────────
          ...(_prayerTimes ?? {}).entries.map((entry) {
            final isSunrise = entry.key == 'Sunrise';
            final isNext = _nextPrayerName == entry.key;
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
                decoration: BoxDecoration(
                  color: theme.cardColor,
                  borderRadius: BorderRadius.circular(18),
                  boxShadow: [
                    BoxShadow(
                      color:
                          Colors.black.withValues(alpha: isDark ? 0.25 : 0.05),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                  border: Border.all(
                    color: isNext
                        ? theme.colorScheme.primary.withValues(alpha: 0.45)
                        : theme.colorScheme.onSurface
                            .withValues(alpha: isDark ? 0.06 : 0.04),
                    width: isNext ? 1.5 : 1,
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: (isSunrise
                                ? Colors.orange
                                : const Color(0xFF2E7D32))
                            .withValues(alpha: isNext ? 0.2 : 0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        isSunrise
                            ? Icons.wb_twilight_rounded
                            : Icons.access_time_filled_rounded,
                        size: 18,
                        color:
                            isSunrise ? Colors.orange : const Color(0xFF2E7D32),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            entry.key,
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: theme.colorScheme.onSurface,
                            ),
                          ),
                          if (isNext)
                            Padding(
                              padding: const EdgeInsets.only(top: 2),
                              child: Text(
                                'NEXT PRAYER',
                                style: TextStyle(
                                  fontSize: 9,
                                  fontWeight: FontWeight.w700,
                                  color: theme.colorScheme.primary,
                                  letterSpacing: 1.2,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                    Text(
                      entry.value,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: theme.colorScheme.primary,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),

          const SizedBox(height: 8),

          // ── Calculation settings ─────────────────────────
          _buildSettingsCard(theme, isDark),
        ],
      ),
    );
  }

  Widget _buildBannerAction({
    required IconData icon,
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return Material(
      color: selected
          ? Colors.white.withValues(alpha: 0.28)
          : Colors.white.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: Colors.white, size: 15),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.2,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Next prayer hero card ───────────────────────────────
  Widget _buildNextPrayerCard(ThemeData theme, bool isDark) {
    final next = _nextPrayerName;
    if (next == null) return const SizedBox.shrink();

    final time = _prayerTimes?[next] ?? '--:--';
    final remaining = _remainingTimeTo(next);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: isDark
            ? theme.colorScheme.primary.withValues(alpha: 0.08)
            : theme.colorScheme.primary.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: theme.colorScheme.primary.withValues(alpha: 0.2),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: isDark
                    ? [const Color(0xFF1B5E20), const Color(0xFF2E7D32)]
                    : [const Color(0xFF2E7D32), const Color(0xFF43A047)],
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
            child: const Icon(
              Icons.access_time_filled_rounded,
              color: Colors.white,
              size: 20,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Next: $next',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: theme.colorScheme.onSurface,
                    letterSpacing: -0.1,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  remaining,
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.55),
                    letterSpacing: 0.1,
                  ),
                ),
              ],
            ),
          ),
          Text(
            time,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: theme.colorScheme.primary,
              letterSpacing: 0.3,
            ),
          ),
        ],
      ),
    );
  }

  String? get _nextPrayerName {
    if (_prayerTimes == null) return null;
    final now = DateTime.now();
    final minutesNow = now.hour * 60 + now.minute;

    for (final name in ['Fajr', 'Dhuhr', 'Asr', 'Maghrib', 'Isha']) {
      final t = _prayerTimes![name];
      if (t == null) continue;
      final parts = t.split(' ');
      if (parts.length < 2) continue;
      final hm = parts[0].split(':');
      if (hm.length < 2) continue;
      int h = int.tryParse(hm[0]) ?? 0;
      final m = int.tryParse(hm[1]) ?? 0;
      final isPm = parts[1].toUpperCase() == 'PM';
      if (isPm && h != 12) h += 12;
      if (!isPm && h == 12) h = 0;
      final mins = h * 60 + m;
      if (mins > minutesNow) return name;
    }
    // After Isha → next is Fajr (tomorrow)
    return 'Fajr';
  }

  String _remainingTimeTo(String name) {
    final t = _prayerTimes?[name];
    if (t == null) return '';
    final parts = t.split(' ');
    if (parts.length < 2) return '';
    final hm = parts[0].split(':');
    if (hm.length < 2) return '';
    int h = int.tryParse(hm[0]) ?? 0;
    final m = int.tryParse(hm[1]) ?? 0;
    final isPm = parts[1].toUpperCase() == 'PM';
    if (isPm && h != 12) h += 12;
    if (!isPm && h == 12) h = 0;

    final now = DateTime.now();
    var target = DateTime(now.year, now.month, now.day, h, m);
    if (target.isBefore(now)) {
      target = target.add(const Duration(days: 1));
    }
    final diff = target.difference(now);
    final hrs = diff.inHours;
    final mins = diff.inMinutes % 60;
    if (hrs > 0) return 'in ${hrs}h ${mins}m';
    return 'in ${mins}m';
  }

  // ── Calculation settings card ───────────────────────────
  Widget _buildSettingsCard(ThemeData theme, bool isDark) {
    final methodName = _methods
        .firstWhere(
          (m) => m.id == _methodId,
          orElse: () => _methods.first,
        )
        .name;

    return Container(
      padding: const EdgeInsets.all(16),
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.tune_rounded,
                size: 16,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(width: 8),
              Text(
                'Calculation Settings',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: theme.colorScheme.onSurface,
                  letterSpacing: -0.1,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildSettingRow(
            theme: theme,
            icon: Icons.public_rounded,
            label: 'Method',
            value: methodName,
            onTap: _changeMethod,
          ),
          const SizedBox(height: 8),
          _buildSettingRow(
            theme: theme,
            icon: Icons.gavel_rounded,
            label: 'Asr Calculation',
            value: _schoolId == 1 ? 'Hanafi' : 'Shafi\'i / Standard',
            onTap: _changeSchool,
          ),
          if (_mode == 'manual' && _selectedCity != null) ...[
            const SizedBox(height: 8),
            _buildSettingRow(
              theme: theme,
              icon: Icons.location_city_rounded,
              label: 'City',
              value: '${_selectedCity!.name}, ${_selectedCity!.country}',
              onTap: _changeCity,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSettingRow({
    required ThemeData theme,
    required IconData icon,
    required String label,
    required String value,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
          child: Row(
            children: [
              Icon(icon, size: 14, color: theme.colorScheme.primary),
              const SizedBox(width: 10),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.75),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.right,
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Icon(
                Icons.arrow_forward_ios_rounded,
                size: 11,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.35),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildError(ThemeData theme) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline_rounded,
                size: 48, color: theme.colorScheme.error),
            const SizedBox(height: 16),
            Text(_error ?? 'Something went wrong',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.7))),
            const SizedBox(height: 20),
            ElevatedButton(
                onPressed: () => _retry(permissionRetry: true),
                child: const Text('Try Again')),
            const SizedBox(height: 10),
            TextButton(
              onPressed: _pickModeManual,
              child: const Text('Choose a City Instead'),
            ),
            if (_canOpenSettings) ...[
              const SizedBox(height: 6),
              TextButton(
                onPressed: () => _serviceOff
                    ? LocationService.instance.openLocationSettings()
                    : LocationService.instance.openSettings(),
                child: Text(
                    _serviceOff ? 'Open Location Settings' : 'Open App Settings'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────
// City picker bottom sheet
// ─────────────────────────────────────────────────────────
class _CityPickerSheet extends StatefulWidget {
  final List<_City> cities;
  final _City? selected;

  const _CityPickerSheet({required this.cities, required this.selected});

  @override
  State<_CityPickerSheet> createState() => _CityPickerSheetState();
}

class _CityPickerSheetState extends State<_CityPickerSheet> {
  late TextEditingController _searchController;
  late List<_City> _filtered;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
    _filtered = widget.cities;
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _filter(String query) {
    final q = query.toLowerCase().trim();
    if (q.isEmpty) {
      setState(() => _filtered = widget.cities);
      return;
    }
    setState(() {
      _filtered = widget.cities.where((c) {
        return c.name.toLowerCase().contains(q) ||
            c.country.toLowerCase().contains(q);
      }).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: theme.scaffoldBackgroundColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: Column(
            children: [
              Container(
                margin: const EdgeInsets.only(top: 10, bottom: 6),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 10, 12, 12),
                child: Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: isDark
                              ? [
                                  const Color(0xFF1B5E20),
                                  const Color(0xFF2E7D32),
                                ]
                              : [
                                  const Color(0xFF2E7D32),
                                  const Color(0xFF43A047),
                                ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(10),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF2E7D32)
                                .withValues(alpha: isDark ? 0.35 : 0.25),
                            blurRadius: 8,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.location_city_rounded,
                        color: Colors.white,
                        size: 18,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Choose a City',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                              fontSize: 16,
                              letterSpacing: -0.2,
                              color: theme.colorScheme.onSurface,
                            ),
                          ),
                          Text(
                            'Prayer times are calculated for your city',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurface
                                  .withValues(alpha: 0.55),
                              fontSize: 11.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Material(
                      color:
                          theme.colorScheme.onSurface.withValues(alpha: 0.06),
                      borderRadius: BorderRadius.circular(10),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(10),
                        onTap: () => Navigator.pop(context),
                        child: Padding(
                          padding: const EdgeInsets.all(8),
                          child: Icon(
                            Icons.close_rounded,
                            size: 18,
                            color: theme.colorScheme.onSurface,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              // Search bar
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 4, 18, 8),
                child: Container(
                  decoration: BoxDecoration(
                    color: theme.cardColor,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: theme.colorScheme.onSurface
                          .withValues(alpha: isDark ? 0.08 : 0.06),
                    ),
                  ),
                  child: TextField(
                    controller: _searchController,
                    onChanged: _filter,
                    style: TextStyle(
                      fontSize: 14,
                      color: theme.colorScheme.onSurface,
                    ),
                    decoration: InputDecoration(
                      hintText: 'Search city or country…',
                      hintStyle: TextStyle(
                        fontSize: 13,
                        color:
                            theme.colorScheme.onSurface.withValues(alpha: 0.4),
                      ),
                      prefixIcon: Icon(
                        Icons.search_rounded,
                        size: 18,
                        color: theme.colorScheme.primary,
                      ),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 14,
                      ),
                    ),
                  ),
                ),
              ),
              Divider(
                height: 1,
                thickness: 1,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.06),
              ),
              Expanded(
                child: _filtered.isEmpty
                    ? Center(
                        child: Text(
                          'No cities found',
                          style: TextStyle(
                            color: theme.colorScheme.onSurface
                                .withValues(alpha: 0.5),
                          ),
                        ),
                      )
                    : ListView.separated(
                        controller: scrollController,
                        padding: const EdgeInsets.fromLTRB(18, 12, 18, 24),
                        physics: const BouncingScrollPhysics(),
                        itemCount: _filtered.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 8),
                        itemBuilder: (context, index) {
                          final c = _filtered[index];
                          final isSel = widget.selected?.name == c.name &&
                              widget.selected?.country == c.country;
                          return Material(
                            color: Colors.transparent,
                            child: InkWell(
                              borderRadius: BorderRadius.circular(14),
                              onTap: () => Navigator.pop(context, c),
                              child: Container(
                                padding: const EdgeInsets.all(14),
                                decoration: BoxDecoration(
                                  color: isSel
                                      ? theme.colorScheme.primary
                                          .withValues(alpha: 0.08)
                                      : theme.cardColor,
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(
                                    color: isSel
                                        ? theme.colorScheme.primary
                                            .withValues(alpha: 0.3)
                                        : theme.colorScheme.onSurface
                                            .withValues(
                                                alpha: isDark ? 0.06 : 0.04),
                                    width: isSel ? 1.5 : 1,
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.location_on_rounded,
                                      size: 16,
                                      color: theme.colorScheme.primary,
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            c.name,
                                            style: TextStyle(
                                              fontSize: 14,
                                              fontWeight: FontWeight.w700,
                                              color:
                                                  theme.colorScheme.onSurface,
                                            ),
                                          ),
                                          Text(
                                            c.country,
                                            style: TextStyle(
                                              fontSize: 11.5,
                                              fontWeight: FontWeight.w500,
                                              color: theme.colorScheme.onSurface
                                                  .withValues(alpha: 0.55),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    if (isSel)
                                      Icon(
                                        Icons.check_circle_rounded,
                                        size: 18,
                                        color: theme.colorScheme.primary,
                                      ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────
// Method picker bottom sheet
// ─────────────────────────────────────────────────────────
class _MethodPickerSheet extends StatelessWidget {
  final List<_Method> methods;
  final int selectedId;

  const _MethodPickerSheet({
    required this.methods,
    required this.selectedId,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return DraggableScrollableSheet(
      initialChildSize: 0.75,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: theme.scaffoldBackgroundColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: Column(
            children: [
              Container(
                margin: const EdgeInsets.only(top: 10, bottom: 6),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 10, 12, 12),
                child: Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: isDark
                              ? [
                                  const Color(0xFF1B5E20),
                                  const Color(0xFF2E7D32),
                                ]
                              : [
                                  const Color(0xFF2E7D32),
                                  const Color(0xFF43A047),
                                ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        Icons.public_rounded,
                        color: Colors.white,
                        size: 18,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Calculation Method',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                              fontSize: 16,
                              letterSpacing: -0.2,
                              color: theme.colorScheme.onSurface,
                            ),
                          ),
                          Text(
                            'Choose the convention for your region',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurface
                                  .withValues(alpha: 0.55),
                              fontSize: 11.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Material(
                      color:
                          theme.colorScheme.onSurface.withValues(alpha: 0.06),
                      borderRadius: BorderRadius.circular(10),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(10),
                        onTap: () => Navigator.pop(context),
                        child: Padding(
                          padding: const EdgeInsets.all(8),
                          child: Icon(
                            Icons.close_rounded,
                            size: 18,
                            color: theme.colorScheme.onSurface,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Divider(
                height: 1,
                thickness: 1,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.06),
              ),
              Expanded(
                child: ListView.separated(
                  controller: scrollController,
                  padding: const EdgeInsets.fromLTRB(18, 12, 18, 24),
                  physics: const BouncingScrollPhysics(),
                  itemCount: methods.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final m = methods[index];
                    final isSel = m.id == selectedId;
                    return Material(
                      color: Colors.transparent,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(14),
                        onTap: () => Navigator.pop(context, m),
                        child: Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: isSel
                                ? theme.colorScheme.primary
                                    .withValues(alpha: 0.08)
                                : theme.cardColor,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: isSel
                                  ? theme.colorScheme.primary
                                      .withValues(alpha: 0.3)
                                  : theme.colorScheme.onSurface
                                      .withValues(alpha: isDark ? 0.06 : 0.04),
                              width: isSel ? 1.5 : 1,
                            ),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  m.name,
                                  style: TextStyle(
                                    fontSize: 13.5,
                                    fontWeight: isSel
                                        ? FontWeight.w700
                                        : FontWeight.w600,
                                    color: theme.colorScheme.onSurface,
                                    height: 1.4,
                                  ),
                                ),
                              ),
                              if (isSel)
                                Padding(
                                  padding: const EdgeInsets.only(left: 8),
                                  child: Icon(
                                    Icons.check_circle_rounded,
                                    size: 18,
                                    color: theme.colorScheme.primary,
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────
// School picker bottom sheet
// ─────────────────────────────────────────────────────────
class _SchoolPickerSheet extends StatelessWidget {
  final int current;

  const _SchoolPickerSheet({required this.current});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final schools = [
      {'id': 1, 'name': 'Hanafi', 'desc': 'Asr shadow length = 2×'},
      {
        'id': 0,
        'name': 'Shafi\'i / Standard',
        'desc': 'Asr shadow length = 1×'
      },
    ];

    return Container(
      decoration: BoxDecoration(
        color: theme.scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            margin: const EdgeInsets.only(top: 10, bottom: 6),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 10, 12, 12),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: isDark
                          ? [const Color(0xFF1B5E20), const Color(0xFF2E7D32)]
                          : [const Color(0xFF2E7D32), const Color(0xFF43A047)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.gavel_rounded,
                    color: Colors.white,
                    size: 18,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Asr Calculation',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      fontSize: 16,
                      letterSpacing: -0.2,
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                ),
                Material(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(10),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(10),
                    onTap: () => Navigator.pop(context),
                    child: Padding(
                      padding: const EdgeInsets.all(8),
                      child: Icon(
                        Icons.close_rounded,
                        size: 18,
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Divider(
            height: 1,
            thickness: 1,
            color: theme.colorScheme.onSurface.withValues(alpha: 0.06),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 12, 18, 24),
            child: Column(
              children: schools.map((s) {
                final id = s['id'] as int;
                final isSel = id == current;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(14),
                      onTap: () => Navigator.pop(context, id),
                      child: Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: isSel
                              ? theme.colorScheme.primary
                                  .withValues(alpha: 0.08)
                              : theme.cardColor,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: isSel
                                ? theme.colorScheme.primary
                                    .withValues(alpha: 0.3)
                                : theme.colorScheme.onSurface
                                    .withValues(alpha: isDark ? 0.06 : 0.04),
                            width: isSel ? 1.5 : 1,
                          ),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    s['name'] as String,
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w700,
                                      color: theme.colorScheme.onSurface,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    s['desc'] as String,
                                    style: TextStyle(
                                      fontSize: 11.5,
                                      color: theme.colorScheme.onSurface
                                          .withValues(alpha: 0.55),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            if (isSel)
                              Icon(
                                Icons.check_circle_rounded,
                                size: 18,
                                color: theme.colorScheme.primary,
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }
}
