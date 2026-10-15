import 'dart:async';
import 'dart:convert';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart' show kIsWeb, ValueNotifier, debugPrint;
import 'package:flutter/material.dart'
    show
        AppLifecycleState,
        BorderRadius,
        BoxDecoration,
        Color,
        Colors,
        Column,
        Container,
        CrossAxisAlignment,
        EdgeInsets,
        Expanded,
        FontWeight,
        Icon,
        Icons,
        MainAxisSize,
        RoundedRectangleBorder,
        Row,
        SizedBox,
        SnackBar,
        SnackBarBehavior,
        Text,
        TextStyle,
        WidgetsBinding,
        WidgetsBindingObserver;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

import 'package:quran_pak/global_keys.dart';
import 'package:quran_pak/location_service.dart';

/// Result of trying to switch Adhan on.
enum AdhanEnableResult {
  enabled,
  notificationsDenied,
}

/// Where prayer times come from.
class _Source {
  final double? lat;
  final double? lng;
  final String? city;
  final String? country;
  final int method;
  final int school;

  const _Source.coords(this.lat, this.lng, this.method, this.school)
      : city = null,
        country = null;
  const _Source.city(this.city, this.country, this.method, this.school)
      : lat = null,
        lng = null;

  bool get isCity => city != null;

  String get signature => isCity
      ? 'c:$city,$country|m$method|s$school'
      : 'g:${lat!.toStringAsFixed(2)},${lng!.toStringAsFixed(2)}|m$method|s$school';
}

class _Calendar {
  final Map<DateTime, Map<String, int>> days;
  final String? timezoneName;
  const _Calendar(this.days, this.timezoneName);
}

class AdhanService with WidgetsBindingObserver {
  AdhanService._();
  static final AdhanService instance = AdhanService._();

  // ── Prefs keys ─────────────────────────────────────────
  static const _prefsEnabled = 'settings_adhan';
  static const _prefsOffset = 'settings_adhan_offset_min';
  static const _prefsSound = 'settings_adhan_sound';
  static const _prefsSignature = 'settings_adhan_signature';
  static const _prefsLastScheduledAt = 'settings_adhan_last_scheduled_ms';

  static const _ptMode = 'pt_mode';
  static const _ptCity = 'pt_city';
  static const _ptMethod = 'pt_method';
  static const _ptSchool = 'pt_school';

  static const int _daysAhead = 10;
  static const Duration _minRefreshGap = Duration(hours: 12);
  static const String _iosSound = 'adhan.mp3';

  /// Asset path used by audioplayers for foreground playback.
  /// MUST be relative to the assets folder declared in pubspec.yaml.
  static const String _defaultAsset = 'assets/adhan.mp3';

  // ── Public notifiers ───────────────────────────────────
  final ValueNotifier<bool> isEnabled = ValueNotifier<bool>(false);
  final ValueNotifier<int> offsetMinutes = ValueNotifier<int>(0);
  final ValueNotifier<bool> isPlaying = ValueNotifier<bool>(false);
  final ValueNotifier<bool> notificationsBlocked = ValueNotifier<bool>(false);

  // ── In-app player ──────────────────────────────────────
  final AudioPlayer _player = AudioPlayer();

  // ── Notifications plugin ───────────────────────────────
  final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();

  // ── Internal state ─────────────────────────────────────
  Timer? _checkTimer;
  String? _lastPlayedKey;
  String _soundAsset = _defaultAsset;

  Map<String, String>? _currentTimes;

  bool _notifPermitted = true;
  bool _exactAllowed = true;

  Future<void> _queue = Future<void>.value();

  static const List<String> _prayerNames = [
    'Fajr',
    'Dhuhr',
    'Asr',
    'Maghrib',
    'Isha',
  ];

  AndroidFlutterLocalNotificationsPlugin? get _android =>
      _notifications.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();

  IOSFlutterLocalNotificationsPlugin? get _ios =>
      _notifications.resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin>();

  /// Public accessor used by the Settings page for debug/diagnostics.
  AndroidFlutterLocalNotificationsPlugin? get androidPlugin => _android;

  // ── Initialization ─────────────────────────────────────
  Future<void> init() async {
    if (!kIsWeb) {
      tz_data.initializeTimeZones();
      await _initLocalTimezone();
    }

    final prefs = await SharedPreferences.getInstance();
    isEnabled.value = prefs.getBool(_prefsEnabled) ?? false;
    offsetMinutes.value = prefs.getInt(_prefsOffset) ?? 0;
    _soundAsset = prefs.getString(_prefsSound) ?? _defaultAsset;

    _player.onPlayerComplete.listen((_) => isPlaying.value = false);

    if (!kIsWeb) {
      await _initNotifications();
      await _refreshPermissionState();
    }

    WidgetsBinding.instance.addObserver(this);
    _startTicker();

    // Top up schedule on cold start (force = true so signature cache
    // never blocks an important re-schedule after reinstall/update).
    if (isEnabled.value) {
      unawaited(refresh(force: true));
    }
  }

  Future<void> _initLocalTimezone() async {
    try {
      final name = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(name));
      debugPrint('[Adhan] local timezone = $name');
    } catch (e) {
      debugPrint('[Adhan] could not read device timezone: $e');
    }
  }

  Future<void> _initNotifications() async {
    const androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );

    await _notifications.initialize(
      const InitializationSettings(
        android: androidSettings,
        iOS: iosSettings,
      ),
    );

    // Pre-create the notification channel so its sound settings are locked
    // in before the first scheduled notification fires.
    await _android?.createNotificationChannel(
      const AndroidNotificationChannel(
        'adhan_channel_v2',
        'Adhan Notifications',
        description: 'Plays adhan sound at each prayer time',
        importance: Importance.max,
        playSound: true,
        sound: RawResourceAndroidNotificationSound('adhan'),
        enableVibration: true,
        audioAttributesUsage: AudioAttributesUsage.alarm,
      ),
    );
  }

  /// Debug helper — returns number of pending scheduled notifications.
  Future<int> debugPendingNotifications() async {
    if (kIsWeb) return 0;
    try {
      final pending = await _notifications.pendingNotificationRequests();
      return pending.length;
    } catch (_) {
      return -1;
    }
  }

  // ── Permissions ────────────────────────────────────────
  Future<void> _refreshPermissionState() async {
    if (kIsWeb) return;
    try {
      final a = _android;
      if (a != null) {
        _notifPermitted = await a.areNotificationsEnabled() ?? true;
        _exactAllowed = await a.canScheduleExactNotifications() ?? true;
      }
      final i = _ios;
      if (i != null) {
        final options = await i.checkPermissions();
        _notifPermitted = options?.isEnabled ?? true;
      }
    } catch (e) {
      debugPrint('[Adhan] permission check failed: $e');
    }
    notificationsBlocked.value = isEnabled.value && !_notifPermitted;
    debugPrint(
        '[Adhan] perms: notif=$_notifPermitted exact=$_exactAllowed blocked=${notificationsBlocked.value}');
  }

  Future<bool> _requestNotificationPermission() async {
    if (kIsWeb) return true;
    bool granted = true;
    try {
      final a = _android;
      if (a != null) {
        granted = await a.requestNotificationsPermission() ?? true;
      }
      final i = _ios;
      if (i != null) {
        granted = await i.requestPermissions(
                alert: true, badge: false, sound: true) ??
            false;
      }
    } catch (e) {
      debugPrint('[Adhan] permission request failed: $e');
      granted = false;
    }
    _notifPermitted = granted;
    return granted;
  }

  Future<void> _ensureExactAlarm() async {
    final a = _android;
    if (a == null) return;
    try {
      final can = await a.canScheduleExactNotifications() ?? true;
      if (!can) await a.requestExactAlarmsPermission();
      _exactAllowed = await a.canScheduleExactNotifications() ?? true;
      debugPrint('[Adhan] exact allowed after ensure = $_exactAllowed');
    } catch (e) {
      debugPrint('[Adhan] exact alarm check failed: $e');
      _exactAllowed = false;
    }
  }

  Future<void> openSystemSettings() async {
    try {
      await Geolocator.openAppSettings();
    } catch (_) {}
  }

  // ── App lifecycle ──────────────────────────────────────
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(_onResume());
    } else if (state == AppLifecycleState.paused) {
      // Nothing — the OS notification handles sound while backgrounded.
    }
  }

  Future<void> _onResume() async {
    await _refreshPermissionState();
    if (isEnabled.value) await refresh();
  }

  // ── Public API ─────────────────────────────────────────
  void updateSchedule(Map<String, String>? times) {
    _currentTimes = times;
    if (isEnabled.value) unawaited(refresh());
  }

  Future<AdhanEnableResult> setEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();

    if (enabled) {
      final granted = await _requestNotificationPermission();
      if (!granted) {
        isEnabled.value = false;
        await prefs.setBool(_prefsEnabled, false);
        notificationsBlocked.value = false;
        return AdhanEnableResult.notificationsDenied;
      }
      await _ensureExactAlarm();
      isEnabled.value = true;
      await prefs.setBool(_prefsEnabled, true);
      notificationsBlocked.value = false;
      await refresh(force: true);
      return AdhanEnableResult.enabled;
    }

    isEnabled.value = false;
    notificationsBlocked.value = false;
    await prefs.setBool(_prefsEnabled, false);
    await stop();
    await _enqueue(() async {
      if (!kIsWeb) await _notifications.cancelAll();
      await prefs.remove(_prefsSignature);
      await prefs.remove(_prefsLastScheduledAt);
    });
    return AdhanEnableResult.enabled;
  }

  Future<void> setOffset(int minutes) async {
    final clamped = minutes.clamp(0, 120);
    offsetMinutes.value = clamped;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_prefsOffset, clamped);

    // force=true — offset change must always trigger a full reschedule.
    if (isEnabled.value) {
      await refresh(force: true);
    }
  }

  Future<void> setSound(String asset) async {
    _soundAsset = asset;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsSound, asset);
  }

  // ── Foreground playback ────────────────────────────────
  Future<void> play({String? prayerName}) async {
    if (kIsWeb) {
      _showWebSnack(prayerName ?? 'Prayer');
      return;
    }

    try {
      if (isPlaying.value) return;
      await _player.stop();
      await _player.play(AssetSource(_soundAsset));
      isPlaying.value = true;
      debugPrint('[Adhan] playing $_soundAsset for $prayerName');
    } catch (e) {
      debugPrint('[Adhan] play failed: $e');
      isPlaying.value = false;
    }
  }

  Future<void> stop() async {
    try {
      await _player.stop();
      isPlaying.value = false;
    } catch (_) {}
  }

  void _showWebSnack(String prayerName) {
    final messenger = scaffoldMessengerKey.currentState;
    if (messenger == null) return;

    final offset = offsetMinutes.value;
    final subtitle = offset == 0
        ? 'Adhan time for $prayerName'
        : 'Adhan for $prayerName in $offset min';

    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Icons.notifications_active_rounded,
                color: Colors.white,
                size: 16,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "It's time for $prayerName",
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.85),
                      fontWeight: FontWeight.w500,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 6),
        backgroundColor: const Color(0xFF6A1B9A),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
        ),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  // ── Foreground ticker ──────────────────────────────────
  // Runs every 20s while the app is in foreground. Fires the in-app audio
  // ONLY if:
  //   * we're on web, OR
  //   * notifications are blocked by the OS (so the notification never fires)
  // Otherwise the scheduled notification itself plays the sound — including
  // while the app is open — and we skip to avoid a double adhan.
  void _startTicker() {
    _checkTimer?.cancel();
    _checkTimer = Timer.periodic(
      const Duration(seconds: 20),
      (_) => _tick(),
    );
  }

  void _tick() {
    if (!isEnabled.value) return;
    if (!kIsWeb && !notificationsBlocked.value) return;

    final times = _currentTimes;
    if (times == null) return;

    final now = DateTime.now();
    final nowMins = now.hour * 60 + now.minute;
    final todayKey = _dateKey(now);
    final offset = offsetMinutes.value;

    for (final name in _prayerNames) {
      final t = times[name];
      if (t == null) continue;
      final mins = _toMinutes(t);
      if (mins == null) continue;

      final targetMins = mins - offset;
      if (targetMins < 0) continue;

      if (nowMins == targetMins) {
        final key = '${todayKey}_${name}_$offset';
        if (_lastPlayedKey != key) {
          _lastPlayedKey = key;
          debugPrint('[Adhan] ticker firing $name (notif blocked or web)');
          play(prayerName: name);
          break;
        }
      }
    }
  }

  // ── Background notification scheduling ─────────────────
  Future<void> _enqueue(Future<void> Function() job) {
    final next = _queue.then((_) => job()).catchError((Object e) {
      debugPrint('[Adhan] job failed: $e');
    });
    _queue = next;
    return next;
  }

  Future<void> refresh({bool force = false}) => _enqueue(() => _refresh(force));

  Future<void> _refresh(bool force) async {
    debugPrint(
        '[Adhan] _refresh start force=$force enabled=${isEnabled.value}');

    if (kIsWeb || !isEnabled.value) {
      debugPrint('[Adhan] skip: web=$kIsWeb enabled=${isEnabled.value}');
      return;
    }

    await _refreshPermissionState();
    if (!_notifPermitted) {
      debugPrint('[Adhan] skip: notifications not permitted');
      return;
    }

    final source = await _readSource();
    if (source == null) {
      debugPrint('[Adhan] skip: no location/city source');
      return;
    }

    final offset = offsetMinutes.value;
    final signature = '${source.signature}|o$offset|x${_exactAllowed ? 1 : 0}';
    debugPrint('[Adhan] signature = $signature');

    final prefs = await SharedPreferences.getInstance();
    if (!force) {
      final lastSig = prefs.getString(_prefsSignature);
      final lastMs = prefs.getInt(_prefsLastScheduledAt) ?? 0;
      final age = DateTime.now().millisecondsSinceEpoch - lastMs;
      if (lastSig == signature &&
          age >= 0 &&
          age < _minRefreshGap.inMilliseconds) {
        debugPrint('[Adhan] skip: signature unchanged & recent');
        return;
      }
    }

    final calendar = await _fetchCalendar(source);
    if (calendar == null || calendar.days.isEmpty) {
      debugPrint('[Adhan] calendar unavailable, schedule unchanged');
      return;
    }

    final count = await _scheduleCalendar(calendar, offset);

    await prefs.setString(_prefsSignature, signature);
    await prefs.setInt(
        _prefsLastScheduledAt, DateTime.now().millisecondsSinceEpoch);
    debugPrint('[Adhan] scheduled $count notifications');
  }

  Future<_Source?> _readSource() async {
    final prefs = await SharedPreferences.getInstance();
    final mode = prefs.getString(_ptMode) ?? 'auto';
    final method = prefs.getInt(_ptMethod) ?? 1;
    final school = prefs.getInt(_ptSchool) ?? 1;

    if (mode == 'manual') {
      try {
        final raw = prefs.getString(_ptCity);
        if (raw != null && raw.isNotEmpty) {
          final d = json.decode(raw) as Map<String, dynamic>;
          final name = d['name'] as String? ?? '';
          final country = d['country'] as String? ?? '';
          if (name.isNotEmpty) {
            return _Source.city(name, country, method, school);
          }
        }
      } catch (_) {}
    }

    final loc = LocationService.instance.current.value;
    if (loc == null) return null;
    return _Source.coords(loc.lat, loc.lng, method, school);
  }

  Uri _calendarUri(_Source s, int year, int month) {
    if (s.isCity) {
      return Uri.https('api.aladhan.com', '/v1/calendarByCity/$year/$month', {
        'city': s.city!,
        'country': s.country ?? '',
        'method': '${s.method}',
        'school': '${s.school}',
      });
    }
    return Uri.https('api.aladhan.com', '/v1/calendar/$year/$month', {
      'latitude': '${s.lat}',
      'longitude': '${s.lng}',
      'method': '${s.method}',
      'school': '${s.school}',
    });
  }

  Future<_Calendar?> _fetchCalendar(_Source source) async {
    final now = DateTime.now();
    final months = <String, DateTime>{};
    for (int i = 0; i < _daysAhead; i++) {
      final d = DateTime(now.year, now.month, now.day + i);
      months['${d.year}-${d.month}'] = DateTime(d.year, d.month);
    }

    final days = <DateTime, Map<String, int>>{};
    String? tzName;
    bool first = true;

    for (final m in months.values) {
      try {
        final res = await http
            .get(_calendarUri(source, m.year, m.month))
            .timeout(const Duration(seconds: 15));
        if (res.statusCode != 200) throw Exception('HTTP ${res.statusCode}');

        final body = json.decode(res.body) as Map<String, dynamic>;
        if (body['code'] != 200) throw Exception('API code ${body['code']}');

        final list = body['data'] as List<dynamic>;
        for (final item in list) {
          final map = item as Map<String, dynamic>;
          tzName ??=
              (map['meta'] as Map<String, dynamic>?)?['timezone'] as String?;

          final g = (map['date']['gregorian']['date'] as String).split('-');
          final date = DateTime(
            int.parse(g[2]),
            int.parse(g[1]),
            int.parse(g[0]),
          );

          final timings = map['timings'] as Map<String, dynamic>;
          final perDay = <String, int>{};
          for (final name in _prayerNames) {
            final mins = _parseHm(timings[name]);
            if (mins != null) perDay[name] = mins;
          }
          if (perDay.isNotEmpty) days[date] = perDay;
        }
      } catch (e) {
        debugPrint('[Adhan] calendar fetch failed: $e');
        if (first) return null;
        break;
      }
      first = false;
    }

    return _Calendar(days, tzName);
  }

  Future<int> _scheduleCalendar(_Calendar cal, int offset) async {
    tz.Location loc = tz.local;
    final name = cal.timezoneName;
    if (name != null && name.isNotEmpty) {
      try {
        loc = tz.getLocation(name);
      } catch (_) {}
    }

    final nowTz = tz.TZDateTime.now(loc);
    final today = DateTime(nowTz.year, nowTz.month, nowTz.day);

    await _notifications.cancelAll();

    final details = _notificationDetails();
    int count = 0;

    for (int dayIndex = 0; dayIndex < _daysAhead; dayIndex++) {
      final date = DateTime(today.year, today.month, today.day + dayIndex);
      final perDay = cal.days[date];
      if (perDay == null) continue;

      for (int p = 0; p < _prayerNames.length; p++) {
        final prayer = _prayerNames[p];
        final mins = perDay[prayer];
        if (mins == null) continue;

        final at = tz.TZDateTime(
          loc,
          date.year,
          date.month,
          date.day,
          mins ~/ 60,
          mins % 60,
        ).subtract(Duration(minutes: offset));

        if (!at.isAfter(nowTz.add(const Duration(seconds: 5)))) continue;

        final ok = await _scheduleOne(
          id: dayIndex * 10 + p,
          title: _notificationTitle(prayer),
          body: _notificationBody(prayer, offset),
          at: at,
          details: details,
        );
        if (ok) count++;
      }
    }
    return count;
  }

  NotificationDetails _notificationDetails() {
    return const NotificationDetails(
      android: AndroidNotificationDetails(
        'adhan_channel_v2',
        'Adhan Notifications',
        channelDescription: 'Plays adhan sound at each prayer time',
        importance: Importance.max,
        priority: Priority.high,
        playSound: true,
        sound: RawResourceAndroidNotificationSound('adhan'),
        enableVibration: true,
        category: AndroidNotificationCategory.alarm,
        visibility: NotificationVisibility.public,
        fullScreenIntent: true,
        audioAttributesUsage: AudioAttributesUsage.alarm,
        enableLights: true,
      ),
      iOS: DarwinNotificationDetails(
        presentAlert: true,
        presentSound: true,
        presentBadge: false,
        sound: _iosSound,
        interruptionLevel: InterruptionLevel.timeSensitive,
      ),
    );
  }

  Future<bool> _scheduleOne({
    required int id,
    required String title,
    required String body,
    required tz.TZDateTime at,
    required NotificationDetails details,
  }) async {
    Future<void> go(AndroidScheduleMode mode) {
      return _notifications.zonedSchedule(
        id,
        title,
        body,
        at,
        details,
        androidScheduleMode: mode,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        payload: 'adhan',
      );
    }

    try {
      await go(_exactAllowed
          ? AndroidScheduleMode.exactAllowWhileIdle
          : AndroidScheduleMode.inexactAllowWhileIdle);
      return true;
    } catch (e) {
      debugPrint('[Adhan] schedule error id=$id: $e');
      if (_exactAllowed) {
        _exactAllowed = false;
        try {
          await go(AndroidScheduleMode.inexactAllowWhileIdle);
          return true;
        } catch (e2) {
          debugPrint('[Adhan] fallback failed id=$id: $e2');
        }
      }
      return false;
    }
  }

  String _notificationTitle(String prayer) => "It's time for $prayer";

  String _notificationBody(String prayer, int offset) {
    if (offset <= 0) return 'Adhan time for $prayer prayer';
    return 'Adhan for $prayer is in $offset minute${offset == 1 ? '' : 's'}';
  }

  // ── Helpers ────────────────────────────────────────────
  String _dateKey(DateTime d) {
    return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  }

  int? _parseHm(dynamic raw) {
    if (raw == null) return null;
    final m = RegExp(r'(\d{1,2}):(\d{2})').firstMatch(raw.toString());
    if (m == null) return null;
    final h = int.tryParse(m.group(1)!);
    final min = int.tryParse(m.group(2)!);
    if (h == null || min == null) return null;
    return h * 60 + min;
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

  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _checkTimer?.cancel();
    _player.dispose();
  }
}
