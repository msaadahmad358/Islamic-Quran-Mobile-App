import 'package:flutter/foundation.dart' show kIsWeb, debugPrint;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'
    show HapticFeedback, TextInputFormatter, TextEditingValue, TextSelection;
import 'package:quran_pak/adhan_service.dart';
import 'package:quran_pak/theme_controller.dart';

class SettingsPage extends StatefulWidget {
  final ThemeController themeController;

  const SettingsPage({super.key, required this.themeController});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final TextEditingController _offsetController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _offsetController.text =
        AdhanService.instance.offsetMinutes.value.toString();
    AdhanService.instance.offsetMinutes.addListener(_syncController);
  }

  void _syncController() {
    final value = AdhanService.instance.offsetMinutes.value.toString();
    if (_offsetController.text != value && mounted) {
      _offsetController.text = value;
    }
  }

  @override
  void dispose() {
    AdhanService.instance.offsetMinutes.removeListener(_syncController);
    _offsetController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AnimatedBuilder(
      animation: widget.themeController,
      builder: (context, _) {
        final isDark = theme.brightness == Brightness.dark;

        return Scaffold(
          backgroundColor: theme.scaffoldBackgroundColor,
          appBar: AppBar(
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
              'Settings',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: theme.colorScheme.onSurface,
                letterSpacing: -0.2,
              ),
            ),
          ),
          body: ListView(
            padding: const EdgeInsets.fromLTRB(18, 8, 18, 24),
            children: [
              _buildAppBranding(theme, isDark),
              const SizedBox(height: 28),
              _buildSectionHeader(theme, 'Appearance', Icons.palette_rounded),
              const SizedBox(height: 10),
              _buildSectionCard(
                theme: theme,
                isDark: isDark,
                children: [
                  SwitchListTile.adaptive(
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 6,
                    ),
                    title: Text(
                      'Dark Mode',
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: theme.colorScheme.onSurface,
                        fontSize: 14.5,
                        letterSpacing: -0.1,
                      ),
                    ),
                    subtitle: Padding(
                      padding: const EdgeInsets.only(top: 3),
                      child: Text(
                        isDark
                            ? 'Dark theme is enabled'
                            : 'Light theme is enabled',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurface
                              .withValues(alpha: 0.55),
                          fontSize: 12,
                        ),
                      ),
                    ),
                    secondary: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: isDark
                              ? [
                                  const Color(0xFF4A148C),
                                  const Color(0xFF7B1FA2),
                                ]
                              : [
                                  const Color(0xFFFFA000),
                                  const Color(0xFFFFD54F),
                                ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: (isDark
                                    ? const Color(0xFF4A148C)
                                    : const Color(0xFFFFA000))
                                .withValues(alpha: 0.3),
                            blurRadius: 8,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: Icon(
                        isDark
                            ? Icons.dark_mode_rounded
                            : Icons.light_mode_rounded,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                    activeColor: theme.colorScheme.primary,
                    value: isDark,
                    onChanged: (value) {
                      widget.themeController.toggleDarkMode(value);
                    },
                  ),
                ],
              ),
              const SizedBox(height: 28),
              _buildSectionHeader(
                theme,
                'Adhan Notifications',
                Icons.notifications_active_rounded,
              ),
              const SizedBox(height: 10),
              _buildSectionCard(
                theme: theme,
                isDark: isDark,
                children: [
                  ValueListenableBuilder<bool>(
                    valueListenable: AdhanService.instance.isEnabled,
                    builder: (context, enabled, _) {
                      return SwitchListTile.adaptive(
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 6,
                        ),
                        title: Text(
                          'Enable Adhan',
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: theme.colorScheme.onSurface,
                            fontSize: 14.5,
                            letterSpacing: -0.1,
                          ),
                        ),
                        subtitle: Padding(
                          padding: const EdgeInsets.only(top: 3),
                          child: Text(
                            enabled
                                ? 'Adhan plays at each prayer time'
                                : 'Adhan is currently disabled',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurface
                                  .withValues(alpha: 0.55),
                              fontSize: 12,
                            ),
                          ),
                        ),
                        secondary: Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color:
                                const Color(0xFF6A1B9A).withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(
                            Icons.notifications_active_rounded,
                            color: Color(0xFF6A1B9A),
                            size: 20,
                          ),
                        ),
                        activeColor: theme.colorScheme.primary,
                        value: enabled,
                        onChanged: (value) async {
                          HapticFeedback.selectionClick();
                          final result =
                              await AdhanService.instance.setEnabled(value);
                          if (!context.mounted) return;

                          // Diagnostic dump
                          _logDiagnostics();

                          if (result == AdhanEnableResult.notificationsDenied) {
                            _showNotificationsBlockedDialog(context);
                          } else if (value) {
                            // After successful enable, show a helper hint
                            _showBatteryHintIfNeeded(context);
                          }
                        },
                      );
                    },
                  ),
                  ValueListenableBuilder<bool>(
                    valueListenable: AdhanService.instance.notificationsBlocked,
                    builder: (context, blocked, _) {
                      if (!blocked) return const SizedBox.shrink();
                      return Padding(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                        child: Row(
                          children: [
                            Icon(
                              Icons.warning_amber_rounded,
                              size: 18,
                              color: theme.colorScheme.error,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Notifications are blocked, so Adhan can only play while the app is open.',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: theme.colorScheme.error,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                            TextButton(
                              onPressed:
                                  AdhanService.instance.openSystemSettings,
                              child: const Text('Fix'),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                  ValueListenableBuilder<bool>(
                    valueListenable: AdhanService.instance.isEnabled,
                    builder: (context, enabled, _) {
                      if (!enabled) return const SizedBox.shrink();

                      return Column(
                        children: [
                          _buildDivider(theme),
                          ValueListenableBuilder<int>(
                            valueListenable:
                                AdhanService.instance.offsetMinutes,
                            builder: (context, offset, _) {
                              return Padding(
                                padding: const EdgeInsets.fromLTRB(
                                  16,
                                  12,
                                  16,
                                  16,
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Text(
                                          'Notify before adhan',
                                          style: theme.textTheme.titleSmall
                                              ?.copyWith(
                                            fontWeight: FontWeight.w700,
                                            color: theme.colorScheme.onSurface,
                                            fontSize: 14.5,
                                            letterSpacing: -0.1,
                                          ),
                                        ),
                                        const Spacer(),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 10,
                                            vertical: 4,
                                          ),
                                          decoration: BoxDecoration(
                                            color: theme.colorScheme.primary
                                                .withValues(alpha: 0.12),
                                            borderRadius:
                                                BorderRadius.circular(20),
                                          ),
                                          child: Text(
                                            offset == 0
                                                ? 'At adhan time'
                                                : '$offset min early',
                                            style: TextStyle(
                                              color: theme.colorScheme.primary,
                                              fontSize: 11,
                                              fontWeight: FontWeight.w700,
                                              letterSpacing: 0.3,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'Get notified a few minutes before each prayer so you can prepare.',
                                      style:
                                          theme.textTheme.bodySmall?.copyWith(
                                        color: theme.colorScheme.onSurface
                                            .withValues(alpha: 0.55),
                                        fontSize: 12,
                                        height: 1.4,
                                      ),
                                    ),
                                    const SizedBox(height: 14),
                                    Row(
                                      children: [
                                        Expanded(
                                          child: _buildManualMinutesField(
                                            theme: theme,
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        _buildSetButton(
                                          theme: theme,
                                          onPressed: () =>
                                              _applyManualOffset(context),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 12),
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        for (final preset in [0, 5, 10, 15, 30])
                                          _buildOffsetChip(
                                            theme: theme,
                                            value: preset,
                                            current: offset,
                                            onTap: () async {
                                              HapticFeedback.selectionClick();
                                              await AdhanService.instance
                                                  .setOffset(preset);
                                              debugPrint(
                                                  '[Settings] offset set to $preset');
                                            },
                                          ),
                                      ],
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                        ],
                      );
                    },
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  // ── Diagnostics (prints to console) ────────────────────
  Future<void> _logDiagnostics() async {
    if (kIsWeb) return;
    try {
      final a = AdhanService.instance.androidPlugin;
      if (a == null) {
        debugPrint('[Diag] not android');
        return;
      }
      final notif = await a.areNotificationsEnabled() ?? false;
      final exact = await a.canScheduleExactNotifications() ?? false;
      final pending = await AdhanService.instance.debugPendingNotifications();
      debugPrint('════════ ADHAN DIAGNOSTICS ════════');
      debugPrint('Enabled:     ${AdhanService.instance.isEnabled.value}');
      debugPrint(
          'Offset:      ${AdhanService.instance.offsetMinutes.value} min');
      debugPrint('Notif perm:  $notif');
      debugPrint('Exact alarm: $exact');
      debugPrint(
          'Blocked:     ${AdhanService.instance.notificationsBlocked.value}');
      debugPrint('Pending:     $pending');
      debugPrint('════════════════════════════════════');
    } catch (e) {
      debugPrint('[Diag] error: $e');
    }
  }

  // ── Battery optimization hint (Xiaomi / Oppo / Vivo) ───
  Future<void> _showBatteryHintIfNeeded(BuildContext context) async {
    // Only show once per install
    // (simple approach: rely on the user reading the dialog)
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          'For reliable background Adhan',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        content: const Text(
          'On some phones (Xiaomi, Oppo, Vivo, Samsung) you should also:\n\n'
          '• Set Battery to "Unrestricted" for this app\n'
          '• Enable "Autostart" for this app\n\n'
          'Otherwise the system may block the Adhan at prayer time.',
          style: TextStyle(height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('OK, got it'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              AdhanService.instance.openSystemSettings();
            },
            child: const Text('Open Settings'),
          ),
        ],
      ),
    );
  }

  // ── App Branding ───────────────────────────────────────
  Widget _buildAppBranding(ThemeData theme, bool isDark) {
    return Column(
      children: [
        Container(
          width: 100,
          height: 100,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF2E7D32)
                    .withValues(alpha: isDark ? 0.4 : 0.25),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: Image.asset(
              'assets/image.png',
              width: 100,
              height: 100,
              fit: BoxFit.cover,
            ),
          ),
        ),
        const SizedBox(height: 14),
        Text(
          'Quran Pak',
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w700,
            color: theme.colorScheme.onSurface,
            fontSize: 22,
            letterSpacing: -0.3,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Islamic Mobile App',
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
            fontSize: 11,
            fontWeight: FontWeight.w600,
            letterSpacing: 1.5,
          ),
        ),
      ],
    );
  }

  Widget _buildManualMinutesField({required ThemeData theme}) {
    return TextField(
      controller: _offsetController,
      keyboardType: TextInputType.number,
      inputFormatters: [_DigitsOnlyFormatter()],
      textAlign: TextAlign.center,
      style: TextStyle(
        fontSize: 15,
        fontWeight: FontWeight.w700,
        color: theme.colorScheme.onSurface,
        letterSpacing: 0.3,
      ),
      decoration: InputDecoration(
        hintText: '0',
        hintStyle: TextStyle(
          color: theme.colorScheme.onSurface.withValues(alpha: 0.3),
          fontWeight: FontWeight.w600,
        ),
        suffixText: 'min',
        suffixStyle: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
        ),
        filled: true,
        fillColor: theme.colorScheme.onSurface.withValues(alpha: 0.04),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 14,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: theme.colorScheme.onSurface.withValues(alpha: 0.08),
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: theme.colorScheme.onSurface.withValues(alpha: 0.08),
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: theme.colorScheme.primary.withValues(alpha: 0.5),
            width: 1.5,
          ),
        ),
      ),
    );
  }

  Widget _buildSetButton({
    required ThemeData theme,
    required VoidCallback onPressed,
  }) {
    return Material(
      color: theme.colorScheme.primary,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onPressed,
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: 18,
            vertical: 14,
          ),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: theme.colorScheme.primary.withValues(alpha: 0.3),
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: const Text(
            'Set',
            style: TextStyle(
              color: Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.3,
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _showNotificationsBlockedDialog(BuildContext context) {
    return showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          'Notifications are off',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        content: const Text(
          'To hear the Adhan at prayer time, allow notifications for this app in your phone settings.',
          style: TextStyle(height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Not Now'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              AdhanService.instance.openSystemSettings();
            },
            child: const Text('Open Settings'),
          ),
        ],
      ),
    );
  }

  Future<void> _applyManualOffset(BuildContext context) async {
    FocusManager.instance.primaryFocus?.unfocus();

    final raw = _offsetController.text.trim();
    if (raw.isEmpty) {
      _showSnack(context, 'Enter a number');
      _offsetController.text =
          AdhanService.instance.offsetMinutes.value.toString();
      return;
    }

    final parsed = int.tryParse(raw);
    if (parsed == null || parsed < 0 || parsed > 120) {
      _showSnack(context, 'Enter a value between 0 and 120');
      _offsetController.text =
          AdhanService.instance.offsetMinutes.value.toString();
      return;
    }

    HapticFeedback.selectionClick();
    await AdhanService.instance.setOffset(parsed);

    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(
              Icons.check_circle_rounded,
              color: Colors.white,
              size: 18,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                parsed == 0
                    ? 'Notification set at adhan time'
                    : 'Notification set $parsed min before adhan',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
        backgroundColor: const Color(0xFF6A1B9A),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  void _showSnack(BuildContext context, String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          msg,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
        backgroundColor: const Color(0xFF880E4F),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  Widget _buildOffsetChip({
    required ThemeData theme,
    required int value,
    required int current,
    required VoidCallback onTap,
  }) {
    final isActive = current == value;
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 2),
        child: Material(
          color: isActive
              ? theme.colorScheme.primary.withValues(alpha: 0.12)
              : theme.colorScheme.onSurface.withValues(alpha: 0.04),
          borderRadius: BorderRadius.circular(10),
          child: InkWell(
            borderRadius: BorderRadius.circular(10),
            onTap: onTap,
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 8),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: isActive
                      ? theme.colorScheme.primary.withValues(alpha: 0.3)
                      : theme.colorScheme.onSurface.withValues(alpha: 0.06),
                ),
              ),
              child: Center(
                child: Text(
                  value == 0 ? 'At time' : '$value',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: isActive
                        ? theme.colorScheme.primary
                        : theme.colorScheme.onSurface.withValues(alpha: 0.6),
                    letterSpacing: 0.1,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(ThemeData theme, String title, IconData icon) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(7),
          decoration: BoxDecoration(
            color: theme.colorScheme.primary.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(9),
          ),
          child: Icon(icon, size: 14, color: theme.colorScheme.primary),
        ),
        const SizedBox(width: 10),
        Text(
          title,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w700,
            color: theme.colorScheme.onSurface,
            fontSize: 15,
            letterSpacing: -0.2,
          ),
        ),
      ],
    );
  }

  Widget _buildSectionCard({
    required ThemeData theme,
    required bool isDark,
    required List<Widget> children,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.05),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
        border: Border.all(
          color: theme.colorScheme.onSurface
              .withValues(alpha: isDark ? 0.06 : 0.04),
        ),
      ),
      child: Column(children: children),
    );
  }

  Widget _buildDivider(ThemeData theme) {
    return Divider(
      height: 1,
      thickness: 1,
      indent: 66,
      endIndent: 16,
      color: theme.colorScheme.onSurface.withValues(alpha: 0.06),
    );
  }
}

class _DigitsOnlyFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final digitsOnly = newValue.text.replaceAll(RegExp(r'[^0-9]'), '');
    if (digitsOnly.length > 3) return oldValue;
    return TextEditingValue(
      text: digitsOnly,
      selection: TextSelection.collapsed(offset: digitsOnly.length),
    );
  }
}
