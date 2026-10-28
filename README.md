# Quran Pak

Quran Pak is a Flutter mobile app for daily Islamic practice. It brings together Quran reading, prayer times, Adhan alerts, Qibla direction, Dhikr counting, and daily duas in one clean application. The project is designed for Muslim users who want an easy and modern way to stay connected to worship and spiritual learning.

## Features

- Read Quran verses and browse surahs in a user-friendly layout.
- Save bookmarked verses locally on the device.
- View prayer timings using GPS or a selected city.
- Choose calculation methods and school settings for prayer times.
- Get Adhan notifications before or at prayer time.
- Use the Qibla compass to find the correct direction of prayer.
- Count Dhikr with a digital tasbih counter.
- Explore the 99 names of Allah in Asma ul Husna.
- Read categorized duas for daily worship and remembrance.
- Switch between light and dark themes for comfortable reading.

## Tech Stack

- Flutter
- Dart
- HTTP
- Shared Preferences
- Geolocator
- Flutter Compass
- Audioplayers
- Flutter Local Notifications
- Timezone
- JSON assets for local Islamic content

## Project Structure

- `lib/main.dart` - application entry point and setup
- `lib/home.dart` - main dashboard and feature navigation
- `lib/quran.dart` - Quran reading and bookmarks
- `lib/prayertimes.dart` - prayer timing screens and settings
- `lib/adhan_service.dart` - Adhan scheduling and reminders
- `lib/location_service.dart` - GPS and city lookup logic
- `lib/qibla.dart` - compass-based Qibla direction
- `lib/digitaltasbih.dart` - digital Dhikr counter
- `lib/asmaulhusna.dart` - 99 names interface
- `lib/duas.dart` - dua categories and contents
- `lib/settings.dart` - user preferences and toggles

## How to Run

1. Install the Flutter SDK.
2. Clone this repository.
3. Open the project folder in a terminal.
4. Run `flutter pub get`.
5. Connect a device or emulator.
6. Run `flutter run`.

## Permissions

- Location access for prayer time and Qibla direction.
- Notification permission for Adhan alerts.
- Exact alarm permission on Android 12+ for timed reminders.

## Notes

- Prayer timings are powered by the AlAdhan API.
- City-based lookup is supported for convenience.
- Local JSON files are used for Quran, dua, and Asma ul Husna content.
- Device preview is intended for development and should be disabled before release builds.

## Purpose

This app aims to make Islamic daily practices easier, more organized, and more accessible for users on mobile devices. It combines modern app design with practical religious tools in a compact and useful package.
