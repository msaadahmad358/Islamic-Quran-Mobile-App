Quran Pak

Quran Pak is a Flutter app for daily Islamic practice. You can read the Quran, check prayer times, get Adhan notifications, find the Qibla direction, count dhikr, and browse duas and the 99 Names of Allah.

FEATURES

- Quran: browse all surahs, read ayah by ayah, and bookmark ayahs (saved on the device).
- Prayer Times: daily timings by GPS location or a chosen city, with your choice of calculation method and school (Hanafi or Shafi).
- Adhan Notifications: the Adhan plays at prayer time, or a set number of minutes before.
- Qibla: compass showing the Qibla direction.
- Digital Tasbih: tap counter with different dhikr to choose from.
- Asma ul Husna: the 99 Names of Allah.
- Duas: supplications grouped by category, plus a daily dua on the home screen.
- Settings: dark or light theme, Adhan on/off, and notification timing.

PRAYER TIMES

Timings come from the AlAdhan API (aladhan.com). The app supports many calculation methods, such as Karachi, ISNA, Muslim World League, Umm Al-Qura, Egyptian, Gulf, Turkey (Diyanet), Moonsighting Committee and JAKIM. The default school is Hanafi.

PROJECT FILES (inside the lib folder)

- main.dart: app entry point and theme setup
- splash.dart: splash screen
- home.dart: home screen with feature tiles
- quran.dart: surah list, reader and bookmarks
- prayertimes.dart: prayer times page and pickers
- adhan_service.dart: Adhan scheduling and notifications
- location_service.dart: GPS, saved location and city lookup
- qibla.dart: Qibla compass
- digitaltasbih.dart: tasbih counter
- asmaulhusna.dart: the 99 Names
- duas.dart: duas by category
- settings.dart: settings page
- theme_controller.dart: light/dark theme state
- global_keys.dart: shared keys

HOW TO RUN

1. Install the Flutter SDK.
2. Open the project folder in a terminal.
3. Run "flutter pub get" to install packages.
4. Connect a device or emulator and run "flutter run".

PACKAGES USED

http, shared_preferences, geolocator, flutter_compass, flutter_local_notifications, flutter_timezone, timezone, audioplayers, and device_preview.

ASSETS NEEDED

Add these files to the assets folder and list them in pubspec.yaml: quran_data.json, asmaulhusna.json, dua.json, adhan.mp3, compass.webp and image.png. On Android, also put adhan.mp3 in android/app/src/main/res/raw so notifications can play it.

PERMISSIONS

- Location: for prayer times and Qibla.
- Notifications: for Adhan alerts.
- Exact alarms (Android 12 and above): so the Adhan fires on time.

BEFORE RELEASING

In main.dart, DevicePreview is set to enabled: true. Turn it off before building a release version.

CREDITS

Prayer times: AlAdhan API. City lookup: BigDataCloud.