import 'dart:async';
import 'package:flutter/material.dart';
import 'package:quran_pak/home.dart';
import 'package:quran_pak/theme_controller.dart';

class SplashPage extends StatefulWidget {
  final ThemeController themeController;

  const SplashPage({super.key, required this.themeController});

  @override
  State<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends State<SplashPage>
    with SingleTickerProviderStateMixin {
  // Only the loading line animates
  late AnimationController _lineController;
  late Animation<double> _lineProgress;

  Timer? _navTimer;

  @override
  void initState() {
    super.initState();

    // Loading line runs over 3.5s to fill fully
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

    // Navigate after 3.5s
    _navTimer = Timer(const Duration(milliseconds: 3500), _goHome);
  }

  @override
  void dispose() {
    _navTimer?.cancel();
    _lineController.dispose();
    super.dispose();
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

    // Foreground tints adapt to theme
    final textPrimary = isDark ? Colors.white : const Color(0xFF0F3D1A);
    final textSecondary = isDark
        ? Colors.white.withValues(alpha: 0.6)
        : const Color(0xFF0F3D1A).withValues(alpha: 0.55);

    // Background: pure white (light mode) / deep green (dark mode)
    final bgColor = isDark ? const Color(0xFF0F3D1A) : Colors.white;

    // Line track + fill colors
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
                  ),
                )),

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
                  // Track with animated gradient fill
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

                  // Loading label
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
