import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'
    show rootBundle, Clipboard, ClipboardData;

class AsmaUlHusnaPage extends StatefulWidget {
  const AsmaUlHusnaPage({super.key});

  @override
  State<AsmaUlHusnaPage> createState() => _AsmaUlHusnaPageState();
}

class _AsmaUlHusnaPageState extends State<AsmaUlHusnaPage> {
  List<_NameItem> _names = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadNames();
  }

  Future<void> _loadNames() async {
    try {
      final raw = await rootBundle.loadString('assets/asmaulhusna.json');
      final data = json.decode(raw) as Map<String, dynamic>;

      final sections = data['sections'] as List<dynamic>;
      final points =
          (sections.first as Map<String, dynamic>)['points'] as List<dynamic>;

      final parsed = points
          .map((p) => _NameItem.fromJson(p as Map<String, dynamic>))
          .toList();

      if (!mounted) return;
      setState(() {
        _names = parsed;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  void _copyName(_NameItem item, int index) {
    final text =
        '${item.arabic}\n${item.transliteration} — ${item.meaningEnglish}\n(Asma ul Husna #$index)';
    Clipboard.setData(ClipboardData(text: text));
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
                'Copied ${item.transliteration}',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
        backgroundColor: const Color(0xFF006064),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: _buildAppBar(theme),
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            _buildHeader(context),
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _error != null
                      ? _buildError(theme)
                      : _buildList(context),
            ),
          ],
        ),
      ),
    );
  }

  // ── Top App Bar (back arrow only) ─────────────────────
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
        'Asma ul Husna',
        style: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w700,
          color: theme.colorScheme.onSurface,
          letterSpacing: -0.2,
        ),
      ),
    );
  }

  // ── Header Banner ──────────────────────────────────────
  Widget _buildHeader(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 4, 18, 6),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: isDark
                ? [const Color(0xFF00363A), const Color(0xFF006064)]
                : [const Color(0xFF006064), const Color(0xFF26C6DA)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF006064)
                  .withValues(alpha: isDark ? 0.4 : 0.28),
              blurRadius: 22,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top row: title + badge
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Asma ul Husna',
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 16,
                      letterSpacing: -0.2,
                    ),
                  ),
                ),
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
                  child: const Text(
                    '99 NAMES',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.2,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // English intro
            Text(
              'The 99 Beautiful Names of Allah',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.98),
                fontSize: 15,
                fontWeight: FontWeight.w600,
                height: 1.4,
                letterSpacing: -0.1,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Each name carries a unique attribute of Allah — recite, reflect and memorize them to deepen your connection.',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.78),
                fontSize: 12,
                height: 1.55,
                fontWeight: FontWeight.w400,
              ),
            ),
            const SizedBox(height: 16),

            // Two info chips
            Row(
              children: [
                _buildInfoChip(
                  icon: Icons.format_list_numbered_rounded,
                  label: '99 Names',
                ),
                const SizedBox(width: 8),
                _buildInfoChip(
                  icon: Icons.translate_rounded,
                  label: 'English',
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoChip({required IconData icon, required String label}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.2),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white, size: 13),
          const SizedBox(width: 5),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.2,
            ),
          ),
        ],
      ),
    );
  }

  // ── Grid of 99 Names ───────────────────────────────────
  Widget _buildList(BuildContext context) {
    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(18, 12, 18, 28),
      physics: const BouncingScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 1.0,
      ),
      itemCount: _names.length,
      itemBuilder: (context, index) => _NameCard(
        item: _names[index],
        index: index + 1,
        onCopy: () => _copyName(_names[index], index + 1),
      ),
    );
  }

  // ── Error State ────────────────────────────────────────
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
              'Could not load names',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _error ?? 'Unknown error',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────
// Individual name card — clean square grid tile
// ─────────────────────────────────────────────────────────
class _NameCard extends StatelessWidget {
  final _NameItem item;
  final int index;
  final VoidCallback onCopy;

  const _NameCard({
    required this.item,
    required this.index,
    required this.onCopy,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.05),
            blurRadius: 14,
            offset: const Offset(0, 5),
          ),
        ],
        border: Border.all(
          color: theme.colorScheme.onSurface
              .withValues(alpha: isDark ? 0.06 : 0.04),
        ),
      ),
      child: Stack(
        children: [
          Positioned(
            right: -16,
            bottom: -22,
            child: Text(
              'ﷲ',
              style: TextStyle(
                fontSize: 100,
                fontFamily: 'serif',
                color: theme.colorScheme.primary
                    .withValues(alpha: isDark ? 0.06 : 0.05),
                height: 1,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: isDark
                              ? [
                                  const Color(0xFF00363A),
                                  const Color(0xFF006064),
                                ]
                              : [
                                  const Color(0xFF006064),
                                  const Color(0xFF26C6DA),
                                ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(9),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF006064)
                                .withValues(alpha: isDark ? 0.35 : 0.25),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Center(
                        child: Text(
                          '$index',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            letterSpacing: -0.2,
                          ),
                        ),
                      ),
                    ),
                    Material(
                      color: theme.colorScheme.primary.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(9),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(9),
                        onTap: onCopy,
                        child: Padding(
                          padding: const EdgeInsets.all(6),
                          child: Icon(
                            Icons.copy_rounded,
                            size: 13,
                            color: theme.colorScheme.primary,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                Expanded(
                  child: Center(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: Text(
                          item.arabic,
                          textDirection: TextDirection.rtl,
                          textAlign: TextAlign.center,
                          maxLines: 1,
                          style: TextStyle(
                            fontSize: 26,
                            fontWeight: FontWeight.w600,
                            color: theme.colorScheme.onSurface,
                            fontFamily: 'serif',
                            height: 1.3,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    SizedBox(
                      width: double.infinity,
                      child: Text(
                        item.transliteration,
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: theme.colorScheme.primary,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    SizedBox(
                      width: double.infinity,
                      child: Text(
                        item.meaningEnglish,
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w500,
                          color: theme.colorScheme.onSurface
                              .withValues(alpha: 0.65),
                          height: 1.35,
                          letterSpacing: -0.1,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────
// Data model
// ─────────────────────────────────────────────────────────
class _NameItem {
  final int id;
  final String arabic;
  final String transliteration;
  final String meaningEnglish;

  _NameItem({
    required this.id,
    required this.arabic,
    required this.transliteration,
    required this.meaningEnglish,
  });

  factory _NameItem.fromJson(Map<String, dynamic> json) {
    return _NameItem(
      id: json['point_id'] as int? ?? 0,
      arabic: json['arabic_text'] as String? ?? '',
      transliteration: json['transliteration_english'] as String? ?? '',
      meaningEnglish: json['meaning_english'] as String? ?? '',
    );
  }
}
