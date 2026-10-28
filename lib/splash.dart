import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:quran_pak/adhan_service.dart';
import 'package:quran_pak/home.dart';
import 'package:quran_pak/location_service.dart';
import 'package:quran_pak/quran.dart';
import 'package:quran_pak/theme_controller.dart';

/// Runs all startup work safely. A failure in one step never blocks the app.
Future<void> _bootstrap() async {
  Future<void> safe(String name, Future<void> Function() task) async {
    try {
      await task().timeout(const Duration(seconds: 10));
    } catch (e, st) {
      debugPrint('Startup step "$name" failed: $e\n$st');
    }
  }

  await safe('bookmarks', () => BookmarkStore.instance.load());
  // Location cache must be loaded before Adhan (it reads it when scheduling).
  await safe('location', () => LocationService.instance.init());
  await safe('adhan', () => AdhanService.instance.init());
}

class SplashPage extends StatefulWidget {
  final ThemeController themeController;

  const SplashPage({super.key, required this.themeController});

  @override
  State<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends State<SplashPage>
    with SingleTickerProviderStateMixin {
  late AnimationController _lineController;
  late Animation<double> _lineProgress;

  @override
  void initState() {
    super.initState();

    _lineController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3500),
    );

    _lineProgress = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _lineController,
        curve: Curves.easeInOut,
      ),
    );

    _lineController.forward();
    _start();
  }

  @override
  void dispose() {
    _lineController.dispose();
    super.dispose();
  }

  Future<void> _start() async {
    try {
      await Future.wait([
        // Never wait more than 8s for startup work
        _bootstrap().timeout(const Duration(seconds: 8), onTimeout: () {}),
        // Minimum splash time
        Future.delayed(const Duration(milliseconds: 3500)),
      ]);
    } catch (e) {
      debugPrint('Splash start error: $e');
    }
    _goHome();
  }

  void _goHome() {
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 500),
        pageBuilder: (_, __, ___) =>
            HomePage(themeController: widget.themeController),
        transitionsBuilder: (_, animation, __, child) {
          return FadeTransition(opacity: animation, child: child);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final textPrimary = isDark ? Colors.white : const Color(0xFF0F3D1A);
    final textSecondary = isDark
        ? Colors.white.withValues(alpha: 0.6)
        : const Color(0xFF0F3D1A).withValues(alpha: 0.55);

    final bgColor = isDark ? const Color(0xFF0F3D1A) : Colors.white;

    final trackColor = isDark
        ? Colors.white.withValues(alpha: 0.15)
        : const Color(0xFF0F3D1A).withValues(alpha: 0.08);

    return Scaffold(
      backgroundColor: bgColor,
      body: SafeArea(
        child: Column(
          children: [
            const Spacer(flex: 3),

            // ── Logo (static) ─────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 40),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(70),
                child: Image.asset(
                  'assets/image.png',
                  width: 220,
                  height: 220,
                  fit: BoxFit.contain,
                  errorBuilder: (_, __, ___) =>
                      const SizedBox(width: 220, height: 220),
                ),
              ),
            ),

            const SizedBox(height: 28),

            // ── App name (static) ─────────────────────
            Text(
              'Quran Pak',
              style: TextStyle(
                color: textPrimary,
                fontSize: 32,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.5,
                height: 1,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'ISLAMIC MOBILE APP',
              style: TextStyle(
                color: textSecondary,
                fontSize: 11,
                fontWeight: FontWeight.w600,
                letterSpacing: 3.0,
              ),
            ),

            const Spacer(flex: 2),

            // ── Loading line (only animated element) ──
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 80),
              child: Column(
                children: [
                  Container(
                    height: 4,
                    decoration: BoxDecoration(
                      color: trackColor,
                      borderRadius: BorderRadius.circular(2),
                    ),
                    child: AnimatedBuilder(
                      animation: _lineProgress,
                      builder: (context, _) {
                        return Align(
                          alignment: Alignment.centerLeft,
                          child: FractionallySizedBox(
                            widthFactor: _lineProgress.value,
                            child: Container(
                              height: 4,
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  colors: [
                                    Color(0xFF1B5E20),
                                    Color(0xFF43A047),
                                    Color(0xFF69F0AE),
                                  ],
                                ),
                                borderRadius: BorderRadius.circular(2),
                                boxShadow: [
                                  BoxShadow(
                                    color: const Color(0xFF43A047)
                                        .withValues(alpha: 0.45),
                                    blurRadius: 10,
                                    spreadRadius: 1,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'LOADING',
                    style: TextStyle(
                      color: textSecondary,
                      fontSize: 10.5,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 4.0,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 60),
          ],
        ),
      ),
    );
  }
}
