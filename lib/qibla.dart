import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_compass/flutter_compass.dart';
import 'package:geolocator/geolocator.dart';
import 'package:quran_pak/location_service.dart';

class QiblaPage extends StatefulWidget {
  const QiblaPage({super.key});

  @override
  State<QiblaPage> createState() => _QiblaPageState();
}

class _QiblaPageState extends State<QiblaPage> {
  // ── Kaaba coordinates ──────────────────────────────────
  static const double _kaabaLat = 21.4225;
  static const double _kaabaLng = 39.8262;

  // ── State ──────────────────────────────────────────────
  double? _qiblaBearing; // degrees from North (0-360)
  double? _deviceHeading; // degrees from North (0-360)
  double? _distanceKm; // km to Kaaba
  bool _isLoading = true;
  String? _error;
  bool _needsSettings = false;

  StreamSubscription<Position>? _positionSub;
  StreamSubscription<CompassEvent>? _compassSub;

  // Tolerance for "facing qibla" (±5 degrees)
  static const double _tolerance = 5.0;

  double get _alignmentDelta {
    if (_qiblaBearing == null || _deviceHeading == null) return 180;
    final diff = (_qiblaBearing! - _deviceHeading!).abs() % 360;
    return diff > 180 ? 360 - diff : diff;
  }

  bool get _isFacingQibla =>
      _alignmentDelta <= _tolerance && _qiblaBearing != null;

  @override
  void initState() {
    super.initState();
    _init();
  }

  @override
  void dispose() {
    _positionSub?.cancel();
    _compassSub?.cancel();
    super.dispose();
  }

  Future<void> _init({bool userInitiated = false}) async {
    _positionSub?.cancel();
    _compassSub?.cancel();

    // Saved location first; only asks the OS if nothing is saved (and, by the
    // single-prompt rule, only when the user explicitly retries).
    var cached = LocationService.instance.current.value;
    if (cached == null) {
      final result =
          await LocationService.instance.ensure(userInitiated: userInitiated);
      cached = result.location;
      if (cached == null) {
        switch (result.status) {
          case LocationStatus.deniedForever:
            _setError(
              'Location is blocked. Enable it in app settings to find the Qibla direction.',
              needsSettings: true,
            );
            break;
          case LocationStatus.serviceOff:
            _setError('Location services are off. Turn on GPS and try again.');
            break;
          default:
            _setError(
              'Location is needed for the Qibla direction. Tap Try Again to allow it, or set a city in Prayer Times.',
            );
        }
        return;
      }
    }
    if (!mounted) return;
    _applyPositionRaw(cached.lat, cached.lng);

    // Live position updates only if the OS currently allows it
    if (await LocationService.instance.isPermissionGranted()) {
      _positionSub = Geolocator.getPositionStream(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.medium,
          distanceFilter: 200,
        ),
      ).listen(
        (p) {
          if (mounted) _applyPositionRaw(p.latitude, p.longitude);
        },
        onError: (_) {}, // permission revoked mid-session → keep saved fix
      );
    }

    // Subscribe to compass heading
    _compassSub = FlutterCompass.events?.listen((event) {
      if (event.heading != null && mounted) {
        setState(() => _deviceHeading = event.heading);
      }
    });
  }

  void _applyPositionRaw(double lat, double lng) {
    final bearing = _bearingToKaaba(lat, lng);
    final distance = _haversineKm(lat, lng, _kaabaLat, _kaabaLng);
    setState(() {
      _qiblaBearing = bearing;
      _distanceKm = distance;
      _isLoading = false;
      _error = null;
    });
  }

  void _setError(String message, {bool needsSettings = false}) {
    if (!mounted) return;
    setState(() {
      _error = message;
      _needsSettings = needsSettings;
      _isLoading = false;
    });
  }

  // ── Bearing from current position to Kaaba ────────────
  double _bearingToKaaba(double lat, double lng) {
    final phi1 = _toRadians(lat);
    final phi2 = _toRadians(_kaabaLat);
    final deltaLambda = _toRadians(_kaabaLng - lng);

    final y = math.sin(deltaLambda) * math.cos(phi2);
    final x = math.cos(phi1) * math.sin(phi2) -
        math.sin(phi1) * math.cos(phi2) * math.cos(deltaLambda);

    final theta = math.atan2(y, x);
    return (_toDegrees(theta) + 360) % 360;
  }

  // ── Haversine distance in km ──────────────────────────
  double _haversineKm(double lat1, double lng1, double lat2, double lng2) {
    const earthRadius = 6371.0;
    final dLat = _toRadians(lat2 - lat1);
    final dLng = _toRadians(lng2 - lng1);
    final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_toRadians(lat1)) *
            math.cos(_toRadians(lat2)) *
            math.sin(dLng / 2) *
            math.sin(dLng / 2);
    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return earthRadius * c;
  }

  double _toRadians(double deg) => deg * math.pi / 180.0;
  double _toDegrees(double rad) => rad * 180.0 / math.pi;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: _buildAppBar(theme),
      body: SafeArea(
        top: false,
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
                ? _buildError(theme)
                : _buildContent(context),
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
        'Qibla Finder',
        style: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w700,
          color: theme.colorScheme.onSurface,
          letterSpacing: -0.2,
        ),
      ),
    );
  }

  Widget _buildContent(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(18, 4, 18, 28),
      child: Column(
        children: [
          _buildHeader(theme, isDark),
          const SizedBox(height: 16),
          _buildStatusBanner(theme),
          const SizedBox(height: 20),
          _buildCompass(theme, isDark),
          const SizedBox(height: 24),
          _buildInfoCards(theme, isDark),
        ],
      ),
    );
  }

  // ── Header banner (orange gradient like the tile) ────
  Widget _buildHeader(ThemeData theme, bool isDark) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isDark
              ? [const Color(0xFF7F1D00), const Color(0xFFBF360C)]
              : [const Color(0xFFBF360C), const Color(0xFFFF7043)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color:
                const Color(0xFFBF360C).withValues(alpha: isDark ? 0.4 : 0.28),
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
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.explore_rounded,
                  color: Colors.white,
                  size: 14,
                ),
              ),
              const SizedBox(width: 9),
              const Text(
                'Qibla Direction',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.4,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
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
                    const Icon(
                      Icons.my_location_rounded,
                      color: Colors.white,
                      size: 12,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      _distanceKm != null ? _formatDistance(_distanceKm!) : '—',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.3,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            '${_qiblaBearing?.toStringAsFixed(1) ?? "—"}°',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 34,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.5,
              height: 1,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'from North · towards Makkah',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.85),
              fontSize: 12,
              fontWeight: FontWeight.w500,
              letterSpacing: 0.2,
            ),
          ),
        ],
      ),
    );
  }

  // ── Status banner — TEXT ONLY ─────────────────────────
  Widget _buildStatusBanner(ThemeData theme) {
    final isFacing = _isFacingQibla;
    final isDark = theme.brightness == Brightness.dark;

    final Color bg = isFacing
        ? (isDark
            ? const Color(0xFF1B5E20).withValues(alpha: 0.18)
            : const Color(0xFF1B5E20).withValues(alpha: 0.08))
        : (isDark
            ? const Color(0xFF7F1D00).withValues(alpha: 0.18)
            : const Color(0xFFBF360C).withValues(alpha: 0.08));

    final Color border = isFacing
        ? (isDark
            ? const Color(0xFF2E7D32).withValues(alpha: 0.5)
            : const Color(0xFF2E7D32).withValues(alpha: 0.35))
        : (isDark
            ? const Color(0xFFBF360C).withValues(alpha: 0.5)
            : const Color(0xFFBF360C).withValues(alpha: 0.35));

    final Color fg =
        isFacing ? const Color(0xFF2E7D32) : const Color(0xFFBF360C);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 240),
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: border, width: 1.5),
      ),
      child: Row(
        children: [
          Icon(
            isFacing ? Icons.check_circle_rounded : Icons.explore_off_rounded,
            color: fg,
            size: 20,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              isFacing ? 'Facing Qibla' : 'Not Facing Qibla',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: fg,
                letterSpacing: 0.2,
              ),
            ),
          ),
          if (_alignmentDelta <= 90)
            Text(
              '${_alignmentDelta.toStringAsFixed(0)}°',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: fg.withValues(alpha: 0.7),
              ),
            ),
        ],
      ),
    );
  }

  // ── Compass ───────────────────────────────────────────
  Widget _buildCompass(ThemeData theme, bool isDark) {
    // Rotate compass relative to device heading so the Kaaba marker
    // points up when the phone is aimed at the Qibla.
    final bearing = _qiblaBearing ?? 0;
    final heading = _deviceHeading ?? 0;
    final rotation = ((bearing - heading) % 360) / 360;

    return SizedBox(
      width: 280,
      height: 280,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            width: 280,
            height: 280,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: isDark
                    ? [const Color(0xFF2A2A2A), const Color(0xFF1A1A1A)]
                    : [Colors.white, const Color(0xFFF0F0F0)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: isDark ? 0.4 : 0.08),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
          ),

          // Cardinal direction labels
          _cardinalLabel('W', Alignment.topCenter, theme, isActive: true),
          _cardinalLabel('E', Alignment.bottomCenter, theme),
          _cardinalLabel('N', Alignment.centerRight, theme),
          _cardinalLabel('S', Alignment.centerLeft, theme),

          // Rotating compass image
          AnimatedRotation(
            turns: rotation,
            duration: const Duration(milliseconds: 400),
            curve: Curves.easeOutCubic,
            child: Image.asset(
              'assets/compass.webp',
              width: 220,
              height: 220,
              fit: BoxFit.contain,
            ),
          ),

          // Center needle dot
          Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: theme.colorScheme.primary,
              boxShadow: [
                BoxShadow(
                  color: theme.colorScheme.primary.withValues(alpha: 0.4),
                  blurRadius: 8,
                  spreadRadius: 1,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _cardinalLabel(
    String text,
    Alignment alignment,
    ThemeData theme, {
    bool isActive = false,
  }) {
    return Align(
      alignment: alignment,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Text(
          text,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.0,
            color: isActive
                ? theme.colorScheme.primary
                : theme.colorScheme.onSurface.withValues(alpha: 0.4),
          ),
        ),
      ),
    );
  }

  // ── Info cards ────────────────────────────────────────
  Widget _buildInfoCards(ThemeData theme, bool isDark) {
    return Column(
      children: [
        _buildInfoCard(
          theme: theme,
          isDark: isDark,
          icon: Icons.straighten_rounded,
          iconColor: const Color(0xFF00838F),
          label: 'Distance to Kaaba',
          value: _distanceKm != null ? _formatDistance(_distanceKm!) : '—',
        ),
        const SizedBox(height: 12),
        _buildInfoCard(
          theme: theme,
          isDark: isDark,
          icon: Icons.explore_rounded,
          iconColor: const Color(0xFFBF360C),
          label: 'Qibla Bearing',
          value: _qiblaBearing != null
              ? '${_qiblaBearing!.toStringAsFixed(1)}°'
              : '—',
        ),
      ],
    );
  }

  Widget _buildInfoCard({
    required ThemeData theme,
    required bool isDark,
    required IconData icon,
    required Color iconColor,
    required String label,
    required String value,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(16),
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
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 18, color: iconColor),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.75),
                letterSpacing: -0.1,
              ),
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: theme.colorScheme.onSurface,
              letterSpacing: -0.2,
            ),
          ),
        ],
      ),
    );
  }

  String _formatDistance(double km) {
    if (km < 1) {
      // Meters for very close distances (e.g. 850 m)
      return '${(km * 1000).toStringAsFixed(0)} m';
    }
    if (km < 100) {
      // One decimal for under 100 km
      return '${km.toStringAsFixed(1)} km';
    }
    // 100+ km → full number with thousands separator
    return '${_formatThousands(km.toStringAsFixed(0))} km';
  }

  /// Formats "3389" → "3,389"
  String _formatThousands(String digits) {
    final buffer = StringBuffer();
    final len = digits.length;
    for (int i = 0; i < len; i++) {
      if (i > 0 && (len - i) % 3 == 0) buffer.write(',');
      buffer.write(digits[i]);
    }
    return buffer.toString();
  }

  // ── Error state ───────────────────────────────────────
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
              _error ?? 'Something went wrong',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                height: 1.5,
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () {
                setState(() {
                  _isLoading = true;
                  _error = null;
                  _needsSettings = false;
                });
                _init(userInitiated: true);
              },
              child: const Text('Try Again'),
            ),
            if (_needsSettings) ...[
              const SizedBox(height: 8),
              TextButton(
                onPressed: LocationService.instance.openSettings,
                child: const Text('Open App Settings'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
