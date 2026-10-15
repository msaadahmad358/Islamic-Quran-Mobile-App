import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'
    show rootBundle, Clipboard, ClipboardData;

class DuasPage extends StatefulWidget {
  const DuasPage({super.key});

  @override
  State<DuasPage> createState() => _DuasPageState();
}

class _DuasPageState extends State<DuasPage> {
  List<_DuaSection> _sections = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadDuas();
  }

  Future<void> _loadDuas() async {
    try {
      final raw = await rootBundle.loadString('assets/dua.json');
      final data = json.decode(raw) as Map<String, dynamic>;

      final sections = (data['sections'] as List<dynamic>)
          .map((s) => _DuaSection.fromJson(s as Map<String, dynamic>))
          .toList();

      if (!mounted) return;
      setState(() {
        _sections = sections;
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

  void _openCategory(_DuaSection section, int sectionNumber) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => _CategoryPage(
          section: section,
          sectionNumber: sectionNumber,
        ),
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
                      : _buildCategoryList(context),
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
        'Islamic Duas',
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
                ? [const Color(0xFF4A0024), const Color(0xFF880E4F)]
                : [const Color(0xFF880E4F), const Color(0xFFEC407A)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF880E4F).withValues(alpha: isDark ? 0.4 : 0.28),
              blurRadius: 22,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Islamic Duas',
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
                  child: Text(
                    '${_sections.length} CATEGORIES',
                    style: const TextStyle(
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
            Text(
              'Everyday Supplications',
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
              'Authentic duas for daily life — from waking up to sleeping, from travel to worship. Recite, memorize and live by them.',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.78),
                fontSize: 12,
                height: 1.55,
                fontWeight: FontWeight.w400,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                _buildInfoChip(
                  icon: Icons.category_rounded,
                  label: '${_sections.length} Categories',
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

  Widget _buildCategoryList(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(18, 12, 18, 28),
      physics: const BouncingScrollPhysics(),
      itemCount: _sections.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final section = _sections[index];
        return _CategoryTile(
          section: section,
          sectionNumber: index + 1,
          onTap: () => _openCategory(section, index + 1),
        );
      },
    );
  }

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
              'Could not load duas',
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
// Category tile (list item) — unchanged
// ─────────────────────────────────────────────────────────
class _CategoryTile extends StatefulWidget {
  final _DuaSection section;
  final int sectionNumber;
  final VoidCallback onTap;

  const _CategoryTile({
    required this.section,
    required this.sectionNumber,
    required this.onTap,
  });

  @override
  State<_CategoryTile> createState() => _CategoryTileState();
}

class _CategoryTileState extends State<_CategoryTile>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 120),
    );
    _scale = Tween<double>(begin: 1.0, end: 0.97).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  IconData get _icon {
    switch (widget.section.id) {
      case '1':
        return Icons.favorite_rounded;
      case '2':
        return Icons.wb_sunny_rounded;
      case '3':
        return Icons.family_restroom_rounded;
      case '4':
        return Icons.menu_book_rounded;
      case '5':
        return Icons.auto_stories_rounded;
      default:
        return Icons.volunteer_activism_rounded;
    }
  }

  String get _subtitle {
    switch (widget.section.id) {
      case '1':
        return 'Foundations of belief';
      case '2':
        return 'Waking, sleeping, eating, worship';
      case '3':
        return 'Travel, marriage, family, society';
      case '4':
        return 'Duas from Surah Al-Fatihah to At-Tawbah';
      case '5':
        return 'Duas from Surah Yunus to Nuh';
      default:
        return '${widget.section.items.length} duas';
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return AnimatedBuilder(
      animation: _scale,
      builder: (context, child) => Transform.scale(
        scale: _scale.value,
        child: child,
      ),
      child: GestureDetector(
        onTapDown: (_) => _controller.forward(),
        onTapUp: (_) => _controller.reverse(),
        onTapCancel: () => _controller.reverse(),
        onTap: widget.onTap,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: isDark
                  ? [const Color(0xFF4A0024), const Color(0xFF880E4F)]
                  : [const Color(0xFF880E4F), const Color(0xFFEC407A)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color:
                    const Color(0xFF880E4F).withValues(alpha: isDark ? 0.35 : 0.25),
                blurRadius: 14,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Stack(
            children: [
              Positioned(
                right: -12,
                bottom: -12,
                child: Icon(
                  _icon,
                  size: 90,
                  color: Colors.white.withValues(alpha: 0.1),
                ),
              ),
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: Container(
                  height: 1,
                  margin: const EdgeInsets.symmetric(horizontal: 20),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(1),
                  ),
                ),
              ),
              Row(
                children: [
                  Container(
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.22),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.3),
                        width: 1,
                      ),
                    ),
                    child: Center(
                      child: Text(
                        '${widget.sectionNumber}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          letterSpacing: -0.3,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.section.title,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            letterSpacing: -0.1,
                            height: 1.25,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _subtitle,
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.8),
                            fontSize: 11.5,
                            fontWeight: FontWeight.w500,
                            height: 1.3,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.18),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.2),
                            ),
                          ),
                          child: Text(
                            '${widget.section.items.length} DUAS',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 9.5,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 1.0,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.25),
                      ),
                    ),
                    child: const Icon(
                      Icons.arrow_forward_ios_rounded,
                      color: Colors.white,
                      size: 14,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────
// Category Page — updated with AppBar
// ─────────────────────────────────────────────────────────
class _CategoryPage extends StatelessWidget {
  final _DuaSection section;
  final int sectionNumber;

  const _CategoryPage({
    required this.section,
    required this.sectionNumber,
  });

  void _copyDua(BuildContext context, _DuaItem item) {
    final text = '${item.arabic}\n\n${item.translationEnglish}';
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Row(
          children: [
            Icon(
              Icons.check_circle_rounded,
              color: Colors.white,
              size: 18,
            ),
            SizedBox(width: 10),
            Expanded(
              child: Text(
                'Dua copied to clipboard',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
          ],
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

  PreferredSizeWidget _buildAppBar(ThemeData theme, BuildContext context) {
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
        section.title,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w700,
          color: theme.colorScheme.onSurface,
          letterSpacing: -0.2,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: _buildAppBar(theme, context),
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            // ── Header Banner ────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 4, 18, 6),
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: isDark
                        ? [const Color(0xFF4A0024), const Color(0xFF880E4F)]
                        : [const Color(0xFF880E4F), const Color(0xFFEC407A)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF880E4F)
                          .withValues(alpha: isDark ? 0.4 : 0.28),
                      blurRadius: 22,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Category $sectionNumber',
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
                          child: Text(
                            '${section.items.length} DUAS',
                            style: const TextStyle(
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
                    Text(
                      section.title,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.98),
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        height: 1.35,
                        letterSpacing: -0.3,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Recite and reflect upon these authentic supplications.',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.78),
                        fontSize: 12,
                        height: 1.55,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // ── Dua List ─────────────────────────────
            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.fromLTRB(18, 12, 18, 28),
                physics: const BouncingScrollPhysics(),
                itemCount: section.items.length,
                separatorBuilder: (_, __) => const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  final item = section.items[index];
                  return _DuaCard(
                    item: item,
                    index: index + 1,
                    onCopy: () => _copyDua(context, item),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────
// Individual dua card — unchanged
// ─────────────────────────────────────────────────────────
class _DuaCard extends StatelessWidget {
  final _DuaItem item;
  final int index;
  final VoidCallback onCopy;

  const _DuaCard({
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
          color: theme.colorScheme.onSurface.withValues(alpha: isDark ? 0.06 : 0.04),
        ),
      ),
      child: Stack(
        children: [
          Positioned(
            right: -18,
            bottom: -22,
            child: Text(
              'ﷲ',
              style: TextStyle(
                fontSize: 110,
                fontFamily: 'serif',
                color:
                    theme.colorScheme.primary.withValues(alpha: isDark ? 0.06 : 0.05),
                height: 1,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primary.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Center(
                        child: Text(
                          '$index',
                          style: TextStyle(
                            color: theme.colorScheme.primary,
                            fontSize: 11.5,
                            fontWeight: FontWeight.w700,
                            letterSpacing: -0.2,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          item.title,
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: theme.colorScheme.onSurface,
                            fontSize: 13,
                            letterSpacing: -0.1,
                            height: 1.35,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
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
                const SizedBox(height: 14),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 14,
                  ),
                  decoration: BoxDecoration(
                    color: isDark
                        ? theme.colorScheme.primary.withValues(alpha: 0.06)
                        : theme.colorScheme.primary.withValues(alpha: 0.04),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: theme.colorScheme.primary.withValues(alpha: 0.15),
                    ),
                  ),
                  child: Text(
                    item.arabic,
                    textAlign: TextAlign.right,
                    textDirection: TextDirection.rtl,
                    style: TextStyle(
                      fontSize: 18,
                      height: 2.0,
                      fontWeight: FontWeight.w500,
                      color: theme.colorScheme.onSurface,
                      fontFamily: 'serif',
                      letterSpacing: 0.2,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Icon(
                        Icons.translate_rounded,
                        size: 12,
                        color: theme.colorScheme.primary.withValues(alpha: 0.7),
                      ),
                    ),
                    const SizedBox(width: 7),
                    Expanded(
                      child: Text(
                        item.translationEnglish,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurface.withValues(alpha: 0.75),
                          fontSize: 12.5,
                          height: 1.6,
                          fontWeight: FontWeight.w400,
                          letterSpacing: 0.1,
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
// Data models — unchanged
// ─────────────────────────────────────────────────────────
class _DuaSection {
  final String id;
  final String title;
  final List<_DuaItem> items;

  _DuaSection({
    required this.id,
    required this.title,
    required this.items,
  });

  factory _DuaSection.fromJson(Map<String, dynamic> json) {
    const sectionTitles = {
      '1': 'Articles of Faith',
      '2': 'Daily Life Duas',
      '3': 'Travel, Family & Society',
      '4': 'Quranic Duas — Part 1',
      '5': 'Quranic Duas — Part 2',
    };

    final id = json['id'] as String? ?? '';
    final points = (json['points'] as List<dynamic>? ?? [])
        .map((p) => _DuaItem.fromJson(p as Map<String, dynamic>))
        .toList();

    return _DuaSection(
      id: id,
      title: sectionTitles[id] ?? 'Duas',
      items: points,
    );
  }
}

class _DuaItem {
  final String id;
  final String title;
  final String arabic;
  final String translationEnglish;

  _DuaItem({
    required this.id,
    required this.title,
    required this.arabic,
    required this.translationEnglish,
  });

  factory _DuaItem.fromJson(Map<String, dynamic> json) {
    return _DuaItem(
      id: json['point_id']?.toString() ?? '',
      title: _englishTitle(json),
      arabic: json['arabic_text'] as String? ?? '',
      translationEnglish: json['translation_english'] as String? ?? '',
    );
  }

  static String _englishTitle(Map<String, dynamic> json) {
    final urdu = json['title_urdu'] as String? ?? '';
    return _titleMap[urdu] ?? urdu;
  }

  static const Map<String, String> _titleMap = {
    'ایمان مجمل': 'Iman Mujmal (Concise Faith)',
    'ایمان مفصل': 'Iman Mufassal (Detailed Faith)',
    'نیند سے بیدار ہوتے وقت': 'When Waking Up',
    'سونے کے لئے بستر پر جاتے وقت': 'Before Sleeping',
    'بیت الخلاء میں جاتے ہوئے': 'Entering the Restroom',
    'بیت الخلاء سے نکلتے ہوئے': 'Leaving the Restroom',
    'وضو کے دوران': 'During Wudu',
    'وضو کے بعد': 'After Wudu',
    'غسل سے پہلے': 'Before Ghusl (Bath)',
    'مسجد مىں داخل ہوتے وقت': 'Entering the Mosque',
    'مسجد سے باہر نکلتے وقت': 'Leaving the Mosque',
    'اذان کى آواز سن کر': 'Hearing the Adhan',
    'اذان کے ختم پر یہ دعا پڑھے': 'After the Adhan',
    'فرض نماز سے سلام پھیرنے کے بعد': 'After Fard Prayer',
    'گھر میں داخل ہوتے وقت': 'Entering the Home',
    'افطار کے وقت': 'When Breaking the Fast',
    'کھانے کے بعد': 'After Eating',
    'اگر کھانا کسى اور نے کھلایا ہو': 'When Someone Feeds You',
    'کپڑے بدلتے وقت': 'When Changing Clothes',
    'جب کسى دشمن کا خوف ہو': 'When Fearing an Enemy',
    'جب کوئى کام مشکل معلوم ہو': 'When a Task Feels Difficult',
    'نیا کپڑا پہنتے وقت': 'Wearing New Clothes',
    'جب بازار مىں داخل ہو': 'Entering the Marketplace',
    'جب کسى سوارى پر سوار ہو': 'When Boarding a Vehicle',
    'سفر کى دعا': 'Dua for Travel',
    'جب کسى نئى بستى مىں داخل ہو': 'Entering a New Town',
    'بیمار کےلئے نبى ﷺ کى دعا': 'Dua for the Sick (Prophetic)',
    'نکاح کى مبارکباد': 'Wedding Congratulations',
    'جماع کے وقت': 'At the Time of Intimacy',
    'انزال کے وقت': 'At the Time of Emission',
    'مہینے کا پہلا چاند دیکھ کر': 'Sighting the New Moon',
    'جب غصہ آئے': 'When Angry',
    'جامع دعا': 'Comprehensive Dua',
    'ہر مجلس کے آخر میں': 'At the End of Every Gathering',
    'جب آئینہ میں اپنا چہرہ دیکھے تو یہ دعا مانگے':
        'When Looking in the Mirror',
    'عورت نکاح کر کے لائے یا خادم لائے تو پڑھے':
        'When Bringing a Bride or Servant Home',
    'بیمار یا مصیبت زدہ کو دیکھ کر یہ دعا پڑھے':
        'When Seeing the Sick or Afflicted',
    'ہدایت اور صراط مستقیم کی دعا (سورۃ الفاتحہ)':
        'Guidance — Surah Al-Fatihah',
    'جہالت سے حفاظت کی دعا (سورۃ البقرۃ - 67)': 'Protection from Ignorance',
    'اعمال کی قبولیت اور درگزر کی دعا (سورۃ البقرۃ 127-128)':
        'Acceptance of Deeds',
    'دنیا اور آخرت میں بھلائی کی دعا (سورۃ البقرۃ 201)':
        'Goodness in Both Worlds',
    'صبر، استقامت اور نصرت کی دعا (سورۃ البقرۃ 250)': 'Patience & Victory',
    'مغفرت کی دعا (سورۃ البقرۃ 285)': 'Seeking Forgiveness',
    'بھول چوک اور خطاؤں پر درگزر کی دعا (سورۃ البقرۃ 286)':
        'Pardon for Mistakes',
    'صراط مستقیم پر استقامت کی دعا (سورۃ آل عمران 8)':
        'Steadfastness on the Straight Path',
    'جہنم کی آگ سے حفاظت کی دعا (سورۃ آل عمران 16)': 'Protection from the Fire',
    'نیک اولاد کی دعا (سورۃ آل عمران 38)': 'Righteous Offspring',
    'ثابت قدمی اور اللہ کی مدد کی دعا (سورۃ آل عمران 147)':
        'Firmness & Divine Help',
    'قیامت کے دن رسوائی سے بچنے کی دعا (سورۃ آل عمران 193-194)':
        'Protection from Disgrace',
    'گواہی دینے والوں میں شمولیت کی دعا (سورۃ المائدۃ 83)':
        'Among the Witnesses',
    'نیک لوگوں میں شامل ہونے کی دعا (سورۃ المائدۃ 84)': 'Among the Righteous',
    'مغفرت اور رحمت کی دعا (سورۃ الاعراف 23)': 'Forgiveness & Mercy',
    'ظالموں کی معیت سے بچنے کی دعا (سورۃ الاعراف 47)':
        'Avoiding the Wrongdoers',
    'حق کے فیصلے کی دعا (سورۃ الاعراف 89)': 'Judgement with Truth',
    'صبر اور حسنِ خاتمہ کی دعا (سورۃ الاعراف 126)': 'Patience & a Good End',
    'معافی اور رحمت کی دعا (سورۃ الاعراف 151)': 'Pardon & Mercy',
    'دنیا اور آخرت میں بھلائی کی دعا (سورۃ الاعراف 155-156)':
        'Goodness in Both Worlds (Al-A\'raf)',
    'اللہ پر توکل کی دعا (سورۃ التوبۃ 129)': 'Trust in Allah',
    'فتنہ بننے سے بچنے کی دعا (سورۃ یونس 85-86)':
        'Protection from Being a Trial',
    'جہالت اور لاعلمی سے بچنے کی دعا (سورۃ ہود 47)':
        'Protection from Ignorance (Hud)',
    'ظاہر و باطن اللہ کو دکھانے کی دعا (سورۃ ابراہیم 38)': 'Allah Sees All',
    'اقامت نماز اور والدین کی بخشش کی دعا (سورۃ ابراہیم 40-41)':
        'Prayer & Forgiveness for Parents',
    'والدین کے لئے رحمت کی دعا (سورۃ الاسراء 24)': 'Mercy for Parents',
    'معاملات میں درستگی کی دعا (سورۃ الکھف 10)': 'Right Guidance in Affairs',
    'علم میں اضافے کی دعا (سورۃ طہٰ 114)': 'Increase in Knowledge',
    'قصور کے اعتراف کی دعا (سورۃ الانبیاء 87)': 'Admitting One\'s Faults',
    'اللہ کے ساتھ کی دعا (سورۃ الانبیاء 89)': 'Not Left Alone',
    'برکت کی جگہ کی دعا (سورۃ المومنون 29)': 'A Blessed Destination',
    'ظالم لوگوں سے حفاظت کی دعا (سورۃ المومنون 94)':
        'Protection from the Wrongdoers',
    'شیاطین سے حفاظت کی دعا (سورۃ المومنون 97-98)': 'Protection from Devils',
    'مغفرت اور رحمت کی دعا (سورۃ المومنون 109)':
        'Forgiveness & Mercy (Al-Mu\'minun)',
    'مغفرت اور رحمت کی دعا (سورۃ المومنون 118)':
        'Forgiveness & Mercy (Al-Mu\'minun 118)',
    'جہنم کے عذاب سے حفاظت کی دعا (سورۃ الفرقان 65-66)':
        'Protection from Hellfire',
    'بیوی بچوں سے آنکھوں کی ٹھنڈک کی دعا (سورۃ الفرقان 74)':
        'Comfort in Family',
    'نعمتوں بھری جنت کی دعا (سورۃ الشعراء 83-85)': 'The Garden of Bliss',
    'قیامت کی رسوائی سے حفاظت کی دعا (سورۃ الشعراء 87-88)':
        'Protection from Disgrace (Ash-Shu\'ara)',
    'ظالم قوم سے حفاظت کی دعا (سورۃ القصص 21)':
        'Protection from an Oppressive People',
    'صالح بندوں میں شمولیت کی دعا (سورۃ النمل 19)':
        'Among the Righteous Servants',
    'مفسد لوگوں کے مقابلے میں مدد کی دعا (سورۃ العنکبوت 30)':
        'Help Against the Corrupters',
    'نیک اولاد کی دعا (سورۃ الصافات 100)': 'Righteous Offspring (As-Saffat)',
    'رسولوں پر سلامتی کی دعا (سورۃ الصافات 180-182)':
        'Peace Upon the Messengers',
    'برائیوں سے حفاظت کی دعا (سورۃ غافر 7-8)': 'Protection from Evil (Ghafir)',
    'برائیوں سے حفاظت کی دعا (سورۃ غافر 9)': 'Protection from Evil (Ghafir 9)',
    'عذاب سے حفاظت کی دعا (سورۃ الدخان 12)': 'Removal of Affliction',
    'شکر کی توفیق کی دعا (سورۃ الاحقاف 15)': 'Gratitude & Righteous Offspring',
    'اللہ پر توکل کی دعا (سورۃ الممتحنۃ 4)': 'Trust & Repentance',
    'بغض سے حفاظت کی دعا (سورۃ الحشر 10)': 'Protection from Rancour',
    'قصوروں سے درگزر کی دعا (سورۃ الممتحنۃ 5)': 'Pardon for Shortcomings',
    'نور کی تکمیل کی دعا (سورۃ التحریم 8)': 'Perfection of Light',
    'تمام مسلمانوں کے لئے مغفرت کی دعا (سورۃ نوح 28)':
        'Forgiveness for All Believers',
  };
}
