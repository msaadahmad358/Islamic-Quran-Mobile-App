import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class DigitalTasbihPage extends StatefulWidget {
  const DigitalTasbihPage({super.key});

  @override
  State<DigitalTasbihPage> createState() => _DigitalTasbihPageState();
}

class _DigitalTasbihPageState extends State<DigitalTasbihPage>
    with SingleTickerProviderStateMixin {
  // ── Dhikr presets ──────────────────────────────────────
  static const List<_Dhikr> _dhikrList = [
    _Dhikr(
      arabic: 'سُبْحَانَ ٱللَّٰهِ',
      transliteration: 'SubhanAllah',
      meaning: 'Glory be to Allah',
      target: 33,
    ),
    _Dhikr(
      arabic: 'ٱلْحَمْدُ لِلَّٰهِ',
      transliteration: 'Alhamdulillah',
      meaning: 'All praise is due to Allah',
      target: 33,
    ),
    _Dhikr(
      arabic: 'ٱللَّٰهُ أَكْبَرُ',
      transliteration: 'Allahu Akbar',
      meaning: 'Allah is the Greatest',
      target: 34,
    ),
    _Dhikr(
      arabic: 'لَا إِلَٰهَ إِلَّا ٱللَّٰهُ',
      transliteration: 'La ilaha illallah',
      meaning: 'There is no deity but Allah',
      target: 100,
    ),
    _Dhikr(
      arabic: 'أَسْتَغْفِرُ ٱللَّٰهَ',
      transliteration: 'Astaghfirullah',
      meaning: 'I seek forgiveness from Allah',
      target: 100,
    ),
    _Dhikr(
      arabic: 'لَا حَوْلَ وَلَا قُوَّةَ إِلَّا بِٱللَّٰهِ',
      transliteration: 'La hawla wa la quwwata illa billah',
      meaning: 'There is no power except with Allah',
      target: 100,
    ),
  ];

  int _currentDhikrIndex = 0;
  int _count = 0;
  int _totalCount = 0;
  int _rounds = 0;

  late AnimationController _pulseController;
  late Animation<double> _pulseScale;

  _Dhikr get _currentDhikr => _dhikrList[_currentDhikrIndex];

  bool get _isComplete => _count >= _currentDhikr.target;

  double get _progress {
    if (_currentDhikr.target == 0) return 0;
    return (_count / _currentDhikr.target).clamp(0.0, 1.0);
  }

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 180),
      lowerBound: 1.0,
      upperBound: 1.05,
    );
    _pulseScale = _pulseController;
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  void _increment() {
    HapticFeedback.lightImpact();

    // Pulse animation
    _pulseController.forward().then((_) => _pulseController.reverse());

    setState(() {
      _count++;
      _totalCount++;

      if (_count == _currentDhikr.target) {
        HapticFeedback.mediumImpact();
        _rounds++;
      }
    });
  }

  void _reset() {
    if (_count == 0 && _totalCount == 0 && _rounds == 0) return;
    HapticFeedback.mediumImpact();
    setState(() {
      _count = 0;
      _totalCount = 0;
      _rounds = 0;
    });
  }

  void _resetAll() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Theme.of(context).cardColor,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: const Text(
          'Reset all?',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        content: Text(
          'This will reset your current count, total count, and rounds back to zero.',
          style: TextStyle(
            color:
                Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
            height: 1.5,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              'Cancel',
              style: TextStyle(
                color: Theme.of(context)
                    .colorScheme
                    .onSurface
                    .withValues(alpha: 0.6),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              setState(() {
                _count = 0;
                _totalCount = 0;
                _rounds = 0;
              });
            },
            child: const Text(
              'Reset',
              style: TextStyle(
                color: Color(0xFF0D47A1),
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _selectDhikr(int index) {
    setState(() {
      _currentDhikrIndex = index;
      _count = 0;
      _totalCount = 0;
      _rounds = 0;
    });
  }

  void _openDhikrPicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => _DhikrPickerSheet(
        dhikrList: _dhikrList,
        selectedIndex: _currentDhikrIndex,
        onSelect: (index) {
          Navigator.pop(ctx);
          _selectDhikr(index);
        },
      ),
    );
  }

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
              child: Padding(
                padding: const EdgeInsets.fromLTRB(18, 0, 18, 14),
                child: Column(
                  children: [
                    _buildHeader(context),
                    const SizedBox(height: 12),
                    _buildDhikrCard(context),
                    const SizedBox(height: 12),
                    Expanded(child: _buildCounter(context)),
                    const SizedBox(height: 12),
                    _buildStatsRow(context),
                    const SizedBox(height: 10),
                    _buildResetButton(context),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Custom App Bar row (back + reset all) ─────────────
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
                'Digital Tasbih',
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
              onTap: _resetAll,
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

  // ── Header Banner ──────────────────────────────────────
  Widget _buildHeader(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isDark
              ? [const Color(0xFF0A2E5C), const Color(0xFF0D47A1)]
              : [const Color(0xFF0D47A1), const Color(0xFF42A5F5)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color:
                const Color(0xFF0D47A1).withValues(alpha: isDark ? 0.4 : 0.25),
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
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.fingerprint_rounded,
                  color: Colors.white,
                  size: 13,
                ),
              ),
              const SizedBox(width: 9),
              Expanded(
                child: Text(
                  'Digital Tasbih',
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                    letterSpacing: -0.2,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 9,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.25),
                  ),
                ),
                child: Text(
                  '${_dhikrList.length} DHIKR',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 9.5,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.2,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            'Track your daily remembrance of Allah — every dhikr brings peace to the heart.',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.85),
              fontSize: 11.5,
              height: 1.5,
              fontWeight: FontWeight.w400,
            ),
          ),
        ],
      ),
    );
  }

  // ── Dhikr selector card (compact) ──────────────────────
  Widget _buildDhikrCard(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: _openDhikrPicker,
        child: Container(
          padding: const EdgeInsets.fromLTRB(16, 14, 14, 14),
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
          child: Row(
            children: [
              // Arabic + info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _currentDhikr.arabic,
                      textDirection: TextDirection.rtl,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w600,
                        color: theme.colorScheme.onSurface,
                        fontFamily: 'serif',
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            _currentDhikr.transliteration,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: theme.colorScheme.primary,
                              letterSpacing: 0.3,
                            ),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 6),
                          child: Container(
                            width: 3,
                            height: 3,
                            decoration: BoxDecoration(
                              color: theme.colorScheme.onSurface
                                  .withValues(alpha: 0.3),
                              shape: BoxShape.circle,
                            ),
                          ),
                        ),
                        Text(
                          '×${_currentDhikr.target}',
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w700,
                            color: theme.colorScheme.onSurface
                                .withValues(alpha: 0.55),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _currentDhikr.meaning,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        color:
                            theme.colorScheme.onSurface.withValues(alpha: 0.55),
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),

              // Change chip
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: theme.colorScheme.primary.withValues(alpha: 0.15),
                  ),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.swap_horiz_rounded,
                      size: 16,
                      color: theme.colorScheme.primary,
                    ),
                    const SizedBox(height: 3),
                    Text(
                      'Change',
                      style: TextStyle(
                        fontSize: 9.5,
                        fontWeight: FontWeight.w700,
                        color: theme.colorScheme.primary,
                        letterSpacing: 0.3,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Counter (main tap target — responsive) ─────────────
  Widget _buildCounter(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return LayoutBuilder(
      builder: (context, constraints) {
        // Fit circle to available space, capped between 180 and 220
        final size = (constraints.maxHeight - 8).clamp(180.0, 220.0);

        return Center(
          child: GestureDetector(
            onTap: _increment,
            onLongPress: _reset,
            child: ScaleTransition(
              scale: _pulseScale,
              child: Container(
                width: size,
                height: size,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: isDark
                        ? [const Color(0xFF0A2E5C), const Color(0xFF0D47A1)]
                        : [const Color(0xFF0D47A1), const Color(0xFF42A5F5)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF0D47A1)
                          .withValues(alpha: isDark ? 0.5 : 0.32),
                      blurRadius: 26,
                      offset: const Offset(0, 12),
                    ),
                  ],
                ),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    // Progress ring
                    SizedBox(
                      width: size,
                      height: size,
                      child: CircularProgressIndicator(
                        value: _progress,
                        strokeWidth: 5,
                        backgroundColor: Colors.white.withValues(alpha: 0.15),
                        valueColor: const AlwaysStoppedAnimation<Color>(
                          Colors.white,
                        ),
                      ),
                    ),

                    // Center content
                    Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        if (_isComplete)
                          Container(
                            padding: const EdgeInsets.all(5),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.22),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.check_rounded,
                              color: Colors.white,
                              size: 14,
                            ),
                          )
                        else
                          Text(
                            'TAP',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.55),
                              fontSize: 9.5,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 2.0,
                            ),
                          ),
                        const SizedBox(height: 6),
                        Text(
                          '$_count',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: size * 0.28,
                            fontWeight: FontWeight.w700,
                            height: 1,
                            letterSpacing: -2,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'of ${_currentDhikr.target}',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.7),
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.3,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  // ── Stats row ──────────────────────────────────────────
  Widget _buildStatsRow(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Row(
      children: [
        Expanded(
          child: _buildStatCard(
            theme: theme,
            isDark: isDark,
            icon: Icons.repeat_rounded,
            label: 'ROUNDS',
            value: '$_rounds',
            color: const Color(0xFF00838F),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _buildStatCard(
            theme: theme,
            isDark: isDark,
            icon: Icons.functions_rounded,
            label: 'TOTAL',
            value: '$_totalCount',
            color: const Color(0xFF6A1B9A),
          ),
        ),
      ],
    );
  }

  Widget _buildStatCard({
    required ThemeData theme,
    required bool isDark,
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(14),
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
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(9),
            ),
            child: Icon(
              icon,
              size: 16,
              color: color,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                    letterSpacing: 1.0,
                  ),
                ),
                const SizedBox(height: 1),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: theme.colorScheme.onSurface,
                    letterSpacing: -0.3,
                    height: 1,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Reset button (always visible) ─────────────────────
  Widget _buildResetButton(BuildContext context) {
    final theme = Theme.of(context);
    final isEnabled = _count > 0 || _totalCount > 0 || _rounds > 0;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: isEnabled ? _reset : null,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 13),
          decoration: BoxDecoration(
            color: isEnabled
                ? theme.colorScheme.primary.withValues(alpha: 0.1)
                : theme.colorScheme.onSurface.withValues(alpha: 0.04),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isEnabled
                  ? theme.colorScheme.primary.withValues(alpha: 0.25)
                  : theme.colorScheme.onSurface.withValues(alpha: 0.06),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.restart_alt_rounded,
                size: 17,
                color: isEnabled
                    ? theme.colorScheme.primary
                    : theme.colorScheme.onSurface.withValues(alpha: 0.35),
              ),
              const SizedBox(width: 8),
              Text(
                'Reset Counter',
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  color: isEnabled
                      ? theme.colorScheme.primary
                      : theme.colorScheme.onSurface.withValues(alpha: 0.35),
                  letterSpacing: 0.2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────
// Dhikr model
// ─────────────────────────────────────────────────────────
class _Dhikr {
  final String arabic;
  final String transliteration;
  final String meaning;
  final int target;

  const _Dhikr({
    required this.arabic,
    required this.transliteration,
    required this.meaning,
    required this.target,
  });
}

// ─────────────────────────────────────────────────────────
// Dhikr picker bottom sheet
// ─────────────────────────────────────────────────────────
class _DhikrPickerSheet extends StatelessWidget {
  final List<_Dhikr> dhikrList;
  final int selectedIndex;
  final void Function(int) onSelect;

  const _DhikrPickerSheet({
    required this.dhikrList,
    required this.selectedIndex,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

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
                          ? [
                              const Color(0xFF0A2E5C),
                              const Color(0xFF0D47A1),
                            ]
                          : [
                              const Color(0xFF0D47A1),
                              const Color(0xFF42A5F5),
                            ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(10),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF0D47A1)
                            .withValues(alpha: isDark ? 0.35 : 0.25),
                        blurRadius: 8,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.fingerprint_rounded,
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
                        'Choose Dhikr',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                          fontSize: 16,
                          letterSpacing: -0.2,
                          color: theme.colorScheme.onSurface,
                        ),
                      ),
                      Text(
                        'Select a dhikr to start counting',
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
          Flexible(
            child: ListView.separated(
              shrinkWrap: true,
              padding: const EdgeInsets.fromLTRB(18, 12, 18, 24),
              physics: const BouncingScrollPhysics(),
              itemCount: dhikrList.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                final dhikr = dhikrList[index];
                final isSelected = index == selectedIndex;

                return Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(16),
                    onTap: () => onSelect(index),
                    child: Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? theme.colorScheme.primary.withValues(alpha: 0.08)
                            : theme.cardColor,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: isSelected
                              ? theme.colorScheme.primary.withValues(alpha: 0.3)
                              : theme.colorScheme.onSurface
                                  .withValues(alpha: isDark ? 0.06 : 0.04),
                          width: isSelected ? 1.5 : 1,
                        ),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  dhikr.arabic,
                                  textDirection: TextDirection.rtl,
                                  style: TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.w600,
                                    color: theme.colorScheme.onSurface,
                                    fontFamily: 'serif',
                                    height: 1.5,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  dhikr.transliteration,
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: theme.colorScheme.primary,
                                    letterSpacing: 0.3,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  dhikr.meaning,
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w500,
                                    color: theme.colorScheme.onSurface
                                        .withValues(alpha: 0.6),
                                    height: 1.35,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.primary
                                  .withValues(alpha: isSelected ? 0.15 : 0.08),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              '×${dhikr.target}',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: theme.colorScheme.primary,
                                letterSpacing: 0.3,
                              ),
                            ),
                          ),
                          if (isSelected) ...[
                            const SizedBox(width: 10),
                            Icon(
                              Icons.check_circle_rounded,
                              color: theme.colorScheme.primary,
                              size: 20,
                            ),
                          ],
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
  }
}
