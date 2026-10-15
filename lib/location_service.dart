import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart' show kIsWeb, debugPrint;
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class SavedLocation {
  final double lat;
  final double lng;
  final String label; // "Karachi, Pakistan"

  const SavedLocation({
    required this.lat,
    required this.lng,
    required this.label,
  });
}

enum LocationStatus {
  ok,
  serviceOff, // GPS / location services switched off
  denied, // refused (can still be asked again by an explicit user action)
  deniedForever, // must be changed from system settings
  timeout,
  error,
}

class LocationResult {
  final SavedLocation? location;
  final LocationStatus status;
  const LocationResult(this.location, this.status);

  bool get ok => location != null;
}

/// Single place that owns location permission + the cached location.
///
/// Rules:
///  * The permission is asked ONCE automatically (first run). The fact that we
///    asked is stored in prefs (`loc_prompted`) and never resets, so the user
///    is never nagged again.
///  * After a successful fix the coordinates + label are saved in prefs and
///    reused on every later launch (no GPS needed, works offline).
///  * A later denial / revocation does NOT wipe the cache; the saved location
///    keeps working. The user can re-try only through an explicit action
///    (Try Again button / Prayer Times page).
///  * The cache is silently refreshed (no prompt) when it is stale and the
///    device moved more than [_moveThresholdMeters].
class LocationService {
  LocationService._();
  static final LocationService instance = LocationService._();

  static const _kLat = 'loc_lat';
  static const _kLng = 'loc_lng';
  static const _kLabel = 'loc_label';
  static const _kSavedAt = 'loc_saved_at_ms';
  static const _kPrompted = 'loc_prompted';
  static const _kLegacyGrantedFlag = 'loc_granted_flag'; // old versions

  static const _staleAfter = Duration(hours: 6);
  static const _moveThresholdMeters = 3000.0;

  final ValueNotifier<SavedLocation?> current =
      ValueNotifier<SavedLocation?>(null);

  bool _prompted = false;
  bool _refreshing = false;

  /// True once we have asked for permission (ever).
  bool get hasPrompted => _prompted;

  // ── Startup ────────────────────────────────────────────
  /// Call once from main() before runApp.
  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();

    // Migrate from the old flag so existing users are not asked again.
    _prompted = (prefs.getBool(_kPrompted) ?? false) ||
        (prefs.getBool(_kLegacyGrantedFlag) ?? false);
    if (_prompted && !(prefs.getBool(_kPrompted) ?? false)) {
      await prefs.setBool(_kPrompted, true);
    }

    final lat = prefs.getDouble(_kLat);
    final lng = prefs.getDouble(_kLng);
    final label = prefs.getString(_kLabel);
    if (lat != null && lng != null && label != null) {
      current.value = SavedLocation(lat: lat, lng: lng, label: label);
    }
  }

  // ── Permission helpers ─────────────────────────────────
  Future<LocationPermission> _permission() async {
    try {
      return await Geolocator.checkPermission();
    } catch (_) {
      return LocationPermission.denied;
    }
  }

  Future<bool> isPermissionGranted() async {
    final p = await _permission();
    return p == LocationPermission.whileInUse ||
        p == LocationPermission.always;
  }

  /// Should the one-time explanation dialog be shown?
  /// Only when we never asked, nothing is saved and permission isn't granted.
  Future<bool> needsFirstRunPrompt() async {
    if (_prompted) return false;
    if (current.value != null) return false;
    return !(await isPermissionGranted());
  }

  Future<void> markPrompted() async {
    if (_prompted) return;
    _prompted = true;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kPrompted, true);
  }

  Future<void> openSettings() async {
    try {
      await Geolocator.openAppSettings();
    } catch (_) {}
  }

  Future<void> openLocationSettings() async {
    try {
      await Geolocator.openLocationSettings();
    } catch (_) {}
  }

  // ── Main entry points ──────────────────────────────────
  /// Returns the cached location if there is one (and refreshes it silently
  /// in the background when stale). Otherwise asks the device.
  Future<LocationResult> ensure({bool userInitiated = false}) async {
    final cached = current.value;
    if (cached != null) {
      unawaited(refreshIfStale());
      return LocationResult(cached, LocationStatus.ok);
    }
    return request(userInitiated: userInitiated);
  }

  /// Gets a fresh fix and saves it.
  ///
  /// [userInitiated] = false → the OS permission dialog is only shown if we
  /// never asked before (single-time rule).
  /// [userInitiated] = true  → the user explicitly tapped something, so we
  /// may ask again (the OS decides whether it will actually show).
  Future<LocationResult> request({bool userInitiated = false}) async {
    try {
      if (!kIsWeb) {
        final enabled = await Geolocator.isLocationServiceEnabled();
        if (!enabled) {
          return const LocationResult(null, LocationStatus.serviceOff);
        }
      }

      var perm = await _permission();
      if (perm == LocationPermission.denied) {
        if (!userInitiated && _prompted) {
          return const LocationResult(null, LocationStatus.denied);
        }
        perm = await Geolocator.requestPermission();
        await markPrompted();
      }
      if (perm == LocationPermission.deniedForever) {
        return const LocationResult(null, LocationStatus.deniedForever);
      }
      if (perm == LocationPermission.denied) {
        return const LocationResult(null, LocationStatus.denied);
      }

      final pos = await _currentPosition();
      if (pos == null) {
        return const LocationResult(null, LocationStatus.timeout);
      }

      final label = await _reverseGeocode(pos.latitude, pos.longitude) ??
          current.value?.label ??
          'Current Location';
      final saved = await save(pos.latitude, pos.longitude, label);
      return LocationResult(saved, LocationStatus.ok);
    } catch (e) {
      debugPrint('[LocationService] request failed: $e');
      return const LocationResult(null, LocationStatus.error);
    }
  }

  Future<Position?> _currentPosition() async {
    try {
      return await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.medium,
          timeLimit: Duration(seconds: 15),
        ),
      );
    } on TimeoutException {
      if (kIsWeb) return null;
      return Geolocator.getLastKnownPosition();
    }
  }

  /// Silent background refresh: never prompts, never shows UI.
  Future<void> refreshIfStale() async {
    if (_refreshing) return;
    final cached = current.value;
    if (cached == null) return;

    _refreshing = true;
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedAt = prefs.getInt(_kSavedAt) ?? 0;
      final age = DateTime.now().millisecondsSinceEpoch - savedAt;
      if (age >= 0 && age < _staleAfter.inMilliseconds) return;

      if (!await isPermissionGranted()) return;
      if (!kIsWeb && !await Geolocator.isLocationServiceEnabled()) return;

      final pos = await _currentPosition();
      if (pos == null) return;

      final moved = Geolocator.distanceBetween(
        cached.lat,
        cached.lng,
        pos.latitude,
        pos.longitude,
      );
      if (moved < _moveThresholdMeters) {
        // Same place: just mark the cache as fresh.
        await prefs.setInt(
            _kSavedAt, DateTime.now().millisecondsSinceEpoch);
        return;
      }

      final label = await _reverseGeocode(pos.latitude, pos.longitude) ??
          cached.label;
      await save(pos.latitude, pos.longitude, label);
    } catch (e) {
      debugPrint('[LocationService] refresh skipped: $e');
    } finally {
      _refreshing = false;
    }
  }

  /// Persists a location (also used by the Prayer Times page so everything
  /// shares one source of truth).
  Future<SavedLocation> save(double lat, double lng, String label) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_kLat, lat);
    await prefs.setDouble(_kLng, lng);
    await prefs.setString(_kLabel, label);
    await prefs.setInt(_kSavedAt, DateTime.now().millisecondsSinceEpoch);
    final saved = SavedLocation(lat: lat, lng: lng, label: label);
    current.value = saved;
    return saved;
  }

  /// Forget the saved location (keeps the "already asked" flag).
  Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kLat);
    await prefs.remove(_kLng);
    await prefs.remove(_kLabel);
    await prefs.remove(_kSavedAt);
    current.value = null;
  }

  Future<String?> _reverseGeocode(double lat, double lng) async {
    try {
      final url = Uri.parse(
        'https://api.bigdatacloud.net/data/reverse-geocode-client'
        '?latitude=$lat&longitude=$lng&localityLanguage=en',
      );
      final res = await http.get(url).timeout(const Duration(seconds: 6));
      if (res.statusCode != 200) return null;
      final d = json.decode(res.body) as Map<String, dynamic>;
      final city = (d['city'] ?? d['locality'] ?? '') as String;
      final country = (d['countryName'] ?? '') as String;
      if (city.isEmpty) return null;
      return country.isEmpty ? city : '$city, $country';
    } catch (_) {
      return null;
    }
  }
}
