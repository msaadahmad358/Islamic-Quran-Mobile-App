import 'package:flutter/foundation.dart' show kReleaseMode;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:device_preview/device_preview.dart';
import 'package:quran_pak/adhan_service.dart';
import 'package:quran_pak/global_keys.dart';
import 'package:quran_pak/location_service.dart';
import 'package:quran_pak/quran.dart';
import 'package:quran_pak/splash.dart';
import 'package:quran_pak/theme_controller.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);

  await BookmarkStore.instance.load();
  // Location cache must be loaded before Adhan (it reads it when scheduling).
  await LocationService.instance.init();
  await AdhanService.instance.init();

  runApp(
    DevicePreview(
      enabled: true, // never ship the device-frame wrapper
      builder: (context) => const QuranPakApp(),
    ),
  );
}

class QuranPakApp extends StatefulWidget {
  const QuranPakApp({super.key});

  @override
  State<QuranPakApp> createState() => _QuranPakAppState();
}

class _QuranPakAppState extends State<QuranPakApp> {
  final ThemeController _themeController = ThemeController();

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _themeController,
      builder: (context, _) {
        return MaterialApp(
          title: 'Quran Pak',
          debugShowCheckedModeBanner: false,
          scaffoldMessengerKey: scaffoldMessengerKey,
          themeMode: _themeController.themeMode,
          theme: ThemeData(
            useMaterial3: true,
            brightness: Brightness.light,
            colorScheme: ColorScheme.fromSeed(
              seedColor: const Color(0xFF2E7D32),
              brightness: Brightness.light,
            ),
            scaffoldBackgroundColor: const Color(0xFFF7F8FA),
            cardColor: Colors.white,
            appBarTheme: const AppBarTheme(
              backgroundColor: Colors.transparent,
              elevation: 0,
              iconTheme: IconThemeData(color: Colors.black87),
              titleTextStyle: TextStyle(
                color: Colors.black87,
                fontSize: 20,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          darkTheme: ThemeData(
            useMaterial3: true,
            brightness: Brightness.dark,
            colorScheme: ColorScheme.fromSeed(
              seedColor: const Color(0xFF2E7D32),
              brightness: Brightness.dark,
            ),
            scaffoldBackgroundColor: const Color(0xFF121212),
            cardColor: const Color(0xFF1E1E1E),
            appBarTheme: const AppBarTheme(
              backgroundColor: Colors.transparent,
              elevation: 0,
              iconTheme: IconThemeData(color: Colors.white),
              titleTextStyle: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),

          // ── DevicePreview hooks ─────────────────────────────────
          locale: DevicePreview.locale(context),
          builder: (context, child) {
            child = DevicePreview.appBuilder(context, child);

            final mq = MediaQuery.of(context);
            return MediaQuery(
              data: mq.copyWith(
                textScaler: mq.textScaler.clamp(
                  minScaleFactor: 0.9,
                  maxScaleFactor: 1.25,
                ),
              ),
              child: child,
            );
          },
          // ────────────────────────────────────────────────────────

          home: SplashPage(themeController: _themeController),
        );
      },
    );
  }
}
