import 'dart:async';
import 'dart:math' as math;
import 'dart:io';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../controllers/app_data_controller.dart';
import '../../models/weekly_report_item.dart';
import '../../services/report_export_service.dart';
import '../../theme/app_theme.dart';
import '../study/calendar_page.dart';
import '../study/ai_chat_page.dart';
import '../study/flash_card_page.dart';
import '../study/study_notes_page.dart';
import '../study/user_profile_page.dart';
import 'admin_section_page.dart';
import 'create_page.dart';
import 'extension_page.dart';
import 'navigation_models.dart';
import 'tool_home_page.dart';
import 'user_page.dart';

class AppShell extends StatefulWidget {
  const AppShell({
    super.key,
    this.debugMenuInitiallyOpen = false,
    this.debugInitialPrimaryTab,
    this.debugInitialAdminSection,
    this.shouldLoadSampleData = false,
  });

  final bool debugMenuInitiallyOpen;
  final PrimaryTab? debugInitialPrimaryTab;
  final AdminSection? debugInitialAdminSection;
  final bool shouldLoadSampleData;

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell>
    with SingleTickerProviderStateMixin {
  late final AnimationController _menuController;
  late final AppDataController _appDataController;

  late PrimaryTab _primaryTab;
  AdminSection? _activeAdminSection;
  bool _isDarkMode = false;
  bool _allowDrag = false;
  double _menuWidth = 300;

  @override
  void initState() {
    super.initState();
    _appDataController = AppDataController();
    _primaryTab = widget.debugInitialPrimaryTab ?? PrimaryTab.assistant;
    _activeAdminSection = widget.debugInitialAdminSection;
    _menuController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 380),
      reverseDuration: const Duration(milliseconds: 280),
      animationBehavior: AnimationBehavior.preserve,
      value: widget.debugMenuInitiallyOpen ? 1 : 0,
    );
    unawaited(_loadData());
  }

  Future<void> _loadData() async {
    if (widget.shouldLoadSampleData) {
      await _appDataController.loadSampleData();
    } else {
      await _appDataController.load();
    }
    if (mounted) {
      setState(() => _isDarkMode = _appDataController.darkMode);
    }
  }

  @override
  void dispose() {
    _menuController.dispose();
    _appDataController.dispose();
    super.dispose();
  }

  void _openMenu() => _menuController.forward();

  void _closeMenu() {
    _menuController.reverse();
  }

  void _toggleMenu() {
    if (_menuController.value > 0.5) {
      _closeMenu();
    } else {
      _openMenu();
    }
  }

  void _openAiChat() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => AiChatPage(
          isDarkMode: _isDarkMode,
          controller: _appDataController,
        ),
      ),
    );
  }

  void _handleDragStart(DragStartDetails details) {
    _allowDrag = _menuController.value > 0 || details.globalPosition.dx < 28;
  }

  void _handleDragUpdate(DragUpdateDetails details) {
    if (!_allowDrag) return;
    _menuController.value = (_menuController.value +
            (details.primaryDelta ?? 0) / math.max(_menuWidth, 1))
        .clamp(0.0, 1.0);
  }

  void _handleDragEnd(DragEndDetails details) {
    if (!_allowDrag) return;
    _allowDrag = false;
    final velocity = details.primaryVelocity ?? 0;
    if (velocity > 240) {
      _openMenu();
    } else if (velocity < -240) {
      _closeMenu();
    } else if (_menuController.value > 0.5) {
      _openMenu();
    } else {
      _closeMenu();
    }
  }

  void _selectPrimaryTab(PrimaryTab tab) {
    setState(() {
      _primaryTab = tab;
      _activeAdminSection = null;
    });
    _closeMenu();
  }

  void _selectAdminSection(AdminSection section) {
    if (section == AdminSection.overview) {
      setState(() {
        _activeAdminSection = null;
        _primaryTab = PrimaryTab.assistant;
      });
    } else if (section == AdminSection.notes) {
      _closeMenu();
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => StudyNotesPage(
            isDarkMode: _isDarkMode,
            controller: _appDataController,
          ),
        ),
      );
      return;
    } else if (section == AdminSection.flashCard) {
      _closeMenu();
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => FlashCardPage(
            isDarkMode: _isDarkMode,
            controller: _appDataController,
          ),
        ),
      );
      return;
    } else {
      setState(() => _activeAdminSection = section);
    }
    _closeMenu();
  }

  Future<void> _setDarkMode(bool value) async {
    setState(() => _isDarkMode = value);
    await _appDataController.setDarkMode(value);
  }

  void _openWeeklyReport() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => _WeeklyReportPage(
          controller: _appDataController,
          isDarkMode: _isDarkMode,
        ),
      ),
    );
  }

  void _openCourseDetail(String courseName) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => CourseDetailPage(
          courseName: courseName,
          isDarkMode: _isDarkMode,
          controller: _appDataController,
        ),
      ),
    );
  }

  void _openUserProfile(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => UserProfilePage(
          isDarkMode: _isDarkMode,
          controller: _appDataController,
        ),
      ),
    );
  }

  Widget _primaryPageFor(PrimaryTab tab) {
    switch (tab) {
      case PrimaryTab.assistant:
        return HomePage(
          isDarkMode: _isDarkMode,
          controller: _appDataController,
          onGenerateReport: _openWeeklyReport,
          onOpenAiAssistant: () =>
              _selectAdminSection(AdminSection.aiAssistant),
          onOpenAiChat: _openAiChat,
        );
      case PrimaryTab.scenarios:
        return StudyLogsPage(
          isDarkMode: _isDarkMode,
          controller: _appDataController,
        );
      case PrimaryTab.calendar:
        return CalendarPage(
          isDarkMode: _isDarkMode,
          controller: _appDataController,
        );
      case PrimaryTab.create:
        return StudyTasksPage(
          isDarkMode: _isDarkMode,
          controller: _appDataController,
        );
      case PrimaryTab.profile:
        return CourseArchivePage(
          isDarkMode: _isDarkMode,
          controller: _appDataController,
          onViewCourse: _openCourseDetail,
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final safeBottom = mediaQuery.padding.bottom;
    final screenWidth = mediaQuery.size.width;
    _menuWidth = math.min(screenWidth * 0.82, 320);

    return Scaffold(
      resizeToAvoidBottomInset: false,
      backgroundColor:
          _isDarkMode ? const Color(0xFF05070D) : const Color(0xFF182146),
      body: AnimatedBuilder(
        animation: _menuController,
        builder: (context, _) {
          final progress = Curves.easeOutCubic.transform(_menuController.value);
          final page = _activeAdminSection != null
              ? AdminSectionPage(
                  section: _activeAdminSection!,
                  isDarkMode: _isDarkMode,
                  controller: _appDataController,
                  onOpenSettings: () =>
                      _selectAdminSection(AdminSection.aiSettings),
                )
              : _primaryPageFor(_primaryTab);

          return Stack(
            children: [
              Positioned.fill(
                child: _SideMenu(
                  currentSection: _activeAdminSection ?? AdminSection.overview,
                  progress: progress,
                  isDarkMode: _isDarkMode,
                  controller: _appDataController,
                  onDarkModeChanged: _setDarkMode,
                  onSelected: _selectAdminSection,
                  onOpenProfile: () => _openUserProfile(context),
                ),
              ),
              _ForegroundSurface(
                isDarkMode: _isDarkMode,
                isMenuOpen: _menuController.value > 0.5,
                useHomeBackground: _activeAdminSection == null &&
                    _primaryTab == PrimaryTab.assistant,
                progress: progress,
                safeBottom: safeBottom,
                pageKey: ValueKey<String>(
                  _activeAdminSection?.name ?? _primaryTab.name,
                ),
                currentTab: _primaryTab,
                onMenuTap: _toggleMenu,
                onTabSelected: _selectPrimaryTab,
                onHorizontalDragStart: _handleDragStart,
                onHorizontalDragUpdate: _handleDragUpdate,
                onHorizontalDragEnd: _handleDragEnd,
                child: page,
              ),
            ],
          );
        },
      ),
    );
  }
}

class _WeeklyReportPage extends StatefulWidget {
  const _WeeklyReportPage({
    required this.controller,
    required this.isDarkMode,
  });

  final AppDataController controller;
  final bool isDarkMode;

  @override
  State<_WeeklyReportPage> createState() => _WeeklyReportPageState();
}

class _WeeklyReportPageState extends State<_WeeklyReportPage> {
  final ReportExportService _exportService = const ReportExportService();
  late DateTime _startDate;
  late DateTime _endDate;
  String? _reportContent;
  bool _isGenerating = false;
  bool _isExporting = false;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _endDate = now;
    _startDate = now.subtract(const Duration(days: 7));
  }

  void _generate() {
    setState(() => _isGenerating = true);
    final content = widget.controller.generateWeeklyReportContent(
      startDate: _startDate,
      endDate: _endDate,
    );
    setState(() {
      _reportContent = content;
      _isGenerating = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final accent = widget.controller.primaryColor;
    final textColor = widget.isDarkMode ? Colors.white : AppColors.ink;
    final bodyColor =
        widget.isDarkMode ? const Color(0xFFC2C8D6) : AppColors.body;

    return Scaffold(
      backgroundColor:
          widget.isDarkMode ? const Color(0xFF141923) : const Color(0xFFF5F7FF),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        foregroundColor: textColor,
        title: const Text(
          '生成学习周报',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
        actions: [
          if (_reportContent != null)
            IconButton(
              icon: const Icon(Icons.copy_rounded),
              tooltip: '复制到剪贴板',
              onPressed: () {
                Clipboard.setData(ClipboardData(text: _reportContent!));
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('已复制到剪贴板')),
                );
              },
            ),
          if (_reportContent != null)
            IconButton(
              icon: const Icon(Icons.description_rounded),
              tooltip: '导出 Markdown',
              onPressed:
                  _isExporting ? null : () => _exportReport(asPdf: false),
            ),
          if (_reportContent != null)
            IconButton(
              icon: const Icon(Icons.picture_as_pdf_rounded),
              tooltip: '导出 PDF',
              onPressed: _isExporting ? null : () => _exportReport(asPdf: true),
            ),
          if (_reportContent != null)
            IconButton(
              icon: const Icon(Icons.save_rounded),
              tooltip: '保存为历史周报',
              onPressed: () async {
                await widget.controller.saveWeeklyReport(
                  _reportContent!,
                  startDate: _startDate,
                  endDate: _endDate,
                );
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('周报已保存')),
                  );
                }
              },
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(22, 12, 22, 40),
        children: [
          // Date range selector
          Row(
            children: [
              Expanded(
                child: _DateButton(
                  label: '开始日期',
                  date: _startDate,
                  isDarkMode: widget.isDarkMode,
                  onPick: (picked) => setState(() => _startDate = picked),
                  accentColor: accent,
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Icon(Icons.arrow_forward_rounded,
                    color:
                        widget.isDarkMode ? Colors.white54 : AppColors.muted),
              ),
              Expanded(
                child: _DateButton(
                  label: '结束日期',
                  date: _endDate,
                  isDarkMode: widget.isDarkMode,
                  onPick: (picked) => setState(() => _endDate = picked),
                  accentColor: accent,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 50,
            child: ElevatedButton(
              key: const Key('do_generate_report_button'),
              style: ElevatedButton.styleFrom(
                backgroundColor: accent,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                ),
                elevation: 0,
              ),
              onPressed: _isGenerating ? null : _generate,
              child: Text(
                _isGenerating ? '生成中...' : '生成周报',
                style:
                    const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
              ),
            ),
          ),
          if (_reportContent != null) ...[
            const SizedBox(height: 20),
            Text(
              '周报内容',
              style: TextStyle(
                color: widget.isDarkMode ? Colors.white : Colors.black,
                fontSize: 20,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(22),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(24),
                color: widget.isDarkMode
                    ? const Color(0xFF242B37).withValues(alpha: 0.92)
                    : Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: widget.isDarkMode
                        ? Colors.black.withValues(alpha: 0.2)
                        : const Color(0x10121A36),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Text(
                _reportContent!,
                style: TextStyle(
                  color: bodyColor,
                  height: 1.65,
                  fontSize: 14,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  WeeklyReportItem _previewReportItem() {
    final now = DateTime.now();
    return WeeklyReportItem(
      id: 'preview_${now.microsecondsSinceEpoch}',
      startDate: _startDate,
      endDate: _endDate,
      content: _reportContent ?? '',
      sourceLogIds: const [],
      createdAt: now,
    );
  }

  Future<void> _exportReport({required bool asPdf}) async {
    if (_reportContent == null) return;
    setState(() => _isExporting = true);
    try {
      final report = _previewReportItem();
      final file = asPdf
          ? await _exportService.exportWeeklyReportPdf(report)
          : await _exportService.exportWeeklyReportMarkdown(report);
      await Clipboard.setData(ClipboardData(text: file.path));
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '已导出${asPdf ? ' PDF' : ' Markdown'}，文件路径已复制：${file.path}',
          ),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('导出失败：$error')),
      );
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
  }
}

class _DateButton extends StatelessWidget {
  const _DateButton({
    required this.label,
    required this.date,
    required this.isDarkMode,
    required this.onPick,
    required this.accentColor,
  });

  final String label;
  final DateTime date;
  final bool isDarkMode;
  final ValueChanged<DateTime> onPick;
  final Color accentColor;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      style: OutlinedButton.styleFrom(
        foregroundColor: isDarkMode ? Colors.white : accentColor,
        side: BorderSide(
          color:
              isDarkMode ? Colors.white24 : accentColor.withValues(alpha: 0.2),
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      ),
      onPressed: () async {
        final picked = await showDatePicker(
          context: context,
          initialDate: date,
          firstDate: DateTime(2024),
          lastDate: DateTime(2030),
        );
        if (picked != null) onPick(picked);
      },
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label, style: const TextStyle(fontSize: 11)),
          const SizedBox(height: 2),
          Text(
            '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}',
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}

// --- Below: all existing private widgets (unchanged) ---

class _ForegroundSurface extends StatelessWidget {
  const _ForegroundSurface({
    required this.isDarkMode,
    required this.isMenuOpen,
    required this.useHomeBackground,
    required this.progress,
    required this.safeBottom,
    required this.pageKey,
    required this.currentTab,
    required this.onMenuTap,
    required this.onTabSelected,
    required this.onHorizontalDragStart,
    required this.onHorizontalDragUpdate,
    required this.onHorizontalDragEnd,
    required this.child,
  });

  final bool isDarkMode;
  final bool isMenuOpen;
  final bool useHomeBackground;
  final double progress;
  final double safeBottom;
  final Key pageKey;
  final PrimaryTab currentTab;
  final VoidCallback onMenuTap;
  final ValueChanged<PrimaryTab> onTabSelected;
  final GestureDragStartCallback onHorizontalDragStart;
  final GestureDragUpdateCallback onHorizontalDragUpdate;
  final GestureDragEndCallback onHorizontalDragEnd;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final translateX = lerpDouble(0, 272, progress)!;
    final translateY = lerpDouble(0, 10, progress)!;
    final scale = lerpDouble(1, 0.86, progress)!;
    final rotateY = lerpDouble(0, 0.5, progress)!;
    final radius = lerpDouble(0, 36, progress)!;

    final transform = Matrix4.identity()
      ..setEntry(3, 2, 0.0012)
      ..translateByDouble(translateX, translateY, 0, 1)
      ..rotateY(rotateY)
      ..scaleByDouble(scale, scale, 1, 1);

    return Transform(
      key: const Key('shell_front_transform'),
      alignment: Alignment.centerLeft,
      transform: transform,
      child: GestureDetector(
        onHorizontalDragStart: onHorizontalDragStart,
        onHorizontalDragUpdate: onHorizontalDragUpdate,
        onHorizontalDragEnd: onHorizontalDragEnd,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(radius),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: isDarkMode
                  ? const Color(0xFF151A24)
                  : const Color(0xFFF5F7FF),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.08 + progress * 0.16),
                  blurRadius: 26,
                  offset: const Offset(-6, 10),
                ),
              ],
            ),
            child: Stack(
              children: [
                Positioned.fill(
                  child: isDarkMode
                      ? const DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                Color(0xFF1E2430),
                                Color(0xFF141923),
                              ],
                            ),
                          ),
                        )
                      : useHomeBackground
                          ? const _LightShellBackground()
                          : DecoratedBox(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                  colors: [
                                    Colors.white70,
                                    Color(0xFFF2F5FC),
                                  ],
                                ),
                              ),
                            ),
                ),
                Positioned.fill(
                  child: KeyedSubtree(
                    key: pageKey,
                    child: child,
                  ),
                ),
                Positioned(
                  left: 16,
                  top: 38,
                  child: _MenuButton(
                    isDarkMode: isDarkMode,
                    isMenuOpen: isMenuOpen,
                    progress: progress,
                    onTap: onMenuTap,
                  ),
                ),
                Positioned(
                  left: 22,
                  right: 22,
                  bottom: safeBottom + 18,
                  child: RepaintBoundary(
                    child: _BottomNav(
                      isDarkMode: isDarkMode,
                      currentTab: currentTab,
                      onSelected: onTabSelected,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _LightShellBackground extends StatelessWidget {
  const _LightShellBackground();

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        const DecoratedBox(
          decoration: BoxDecoration(color: Color(0xFFF6F7FB)),
        ),
        Positioned(
          top: 110,
          left: -120,
          child: _BlurBlob(
            size: 300,
            color: const Color(0xFF46B6FF).withValues(alpha: 0.78),
          ),
        ),
        Positioned(
          top: 120,
          right: -96,
          child: _BlurBlob(
            size: 280,
            color: const Color(0xFF2FE1DF).withValues(alpha: 0.62),
          ),
        ),
        Positioned(
          bottom: 60,
          right: -40,
          child: _BlurBlob(
            size: 360,
            color: const Color(0xFFFF4B83).withValues(alpha: 0.74),
          ),
        ),
        Positioned(
          bottom: 210,
          left: 110,
          child: _BlurBlob(
            size: 240,
            color: const Color(0xFF9A57FF).withValues(alpha: 0.58),
          ),
        ),
        Positioned(
          bottom: 120,
          left: 140,
          child: _BlurBlob(
            size: 220,
            color: const Color(0xFFFFB16B).withValues(alpha: 0.5),
          ),
        ),
      ],
    );
  }
}

class _BlurBlob extends StatelessWidget {
  const _BlurBlob({required this.size, required this.color});
  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return ImageFiltered(
      imageFilter: ImageFilter.blur(sigmaX: 46, sigmaY: 46),
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      ),
    );
  }
}

class _MenuButton extends StatefulWidget {
  const _MenuButton({
    required this.isDarkMode,
    required this.isMenuOpen,
    required this.progress,
    required this.onTap,
  });
  final bool isDarkMode;
  final bool isMenuOpen;
  final double progress;
  final VoidCallback onTap;

  @override
  State<_MenuButton> createState() => _MenuButtonState();
}

class _MenuButtonState extends State<_MenuButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _iconController;

  @override
  void initState() {
    super.initState();
    _iconController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 320),
      animationBehavior: AnimationBehavior.preserve,
      value: widget.isMenuOpen ? 1 : 0,
    );
  }

  @override
  void didUpdateWidget(covariant _MenuButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    _iconController.animateTo(
      widget.progress,
      duration: const Duration(milliseconds: 120),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  void dispose() {
    _iconController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: widget.isDarkMode
          ? const Color(0xFF242B37).withValues(alpha: 0.96)
          : Colors.white.withValues(alpha: 0.92),
      borderRadius: BorderRadius.circular(18),
      elevation: 4,
      shadowColor:
          widget.isDarkMode ? const Color(0x66000000) : const Color(0x2217203A),
      child: InkWell(
        key: const Key('app_shell_menu_button'),
        borderRadius: BorderRadius.circular(18),
        onTap: widget.onTap,
        child: SizedBox(
          width: 40,
          height: 40,
          child: Center(
            child: AnimatedIcon(
              icon: AnimatedIcons.menu_close,
              progress: _iconController,
              color: widget.isDarkMode ? Colors.white : AppColors.ink,
              size: 30,
            ),
          ),
        ),
      ),
    );
  }
}

class _BottomNav extends StatelessWidget {
  const _BottomNav({
    required this.isDarkMode,
    required this.currentTab,
    required this.onSelected,
  });
  final bool isDarkMode;
  final PrimaryTab currentTab;
  final ValueChanged<PrimaryTab> onSelected;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(26),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color:
                (isDarkMode ? const Color(0xFF202734) : const Color(0xFF1E274C))
                    .withValues(alpha: isDarkMode ? 0.72 : 0.42),
            borderRadius: BorderRadius.circular(26),
            border: Border.all(
              color: Colors.white.withValues(alpha: isDarkMode ? 0.08 : 0.12),
            ),
            boxShadow: [
              BoxShadow(
                color: isDarkMode
                    ? const Color(0x22000000)
                    : const Color(0x24121A36),
                blurRadius: 20,
                offset: Offset(0, 10),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            child: Row(
              children: [
                for (final tab in PrimaryTab.values)
                  Expanded(
                    child: InkWell(
                      key: Key('bottom_nav_${tab.name}'),
                      borderRadius: BorderRadius.circular(18),
                      onTap: () => onSelected(tab),
                      child: SizedBox(
                        height: 52,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            _BottomNavIcon(
                              tab: tab,
                              isActive: currentTab == tab,
                              isDarkMode: isDarkMode,
                            ),
                            const SizedBox(height: 2),
                            Text(
                              tab.label,
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: currentTab == tab
                                    ? FontWeight.w700
                                    : FontWeight.w500,
                                color: currentTab == tab
                                    ? Colors.white
                                    : isDarkMode
                                        ? Colors.white54
                                        : Colors.white70,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _BottomNavIcon extends StatefulWidget {
  const _BottomNavIcon({
    required this.tab,
    required this.isActive,
    required this.isDarkMode,
  });
  final PrimaryTab tab;
  final bool isActive;
  final bool isDarkMode;

  @override
  State<_BottomNavIcon> createState() => _BottomNavIconState();
}

class _BottomNavIconState extends State<_BottomNavIcon> {
  @override
  Widget build(BuildContext context) {
    final tint = widget.isDarkMode
        ? Color.lerp(
            const Color(0xFF8B93A7),
            Colors.white,
            widget.isActive ? 1 : 0,
          )!
        : Colors.white.withValues(
            alpha: widget.isActive ? 0.98 : 0.66,
          );

    return Icon(
      widget.isActive ? widget.tab.activeIcon : widget.tab.icon,
      color: tint,
      size: 22,
    );
  }
}

class _SideMenu extends StatefulWidget {
  const _SideMenu({
    required this.currentSection,
    required this.progress,
    required this.isDarkMode,
    required this.controller,
    required this.onDarkModeChanged,
    required this.onSelected,
    required this.onOpenProfile,
  });
  final AdminSection currentSection;
  final double progress;
  final bool isDarkMode;
  final AppDataController controller;
  final ValueChanged<bool> onDarkModeChanged;
  final ValueChanged<AdminSection> onSelected;
  final VoidCallback onOpenProfile;

  @override
  State<_SideMenu> createState() => _SideMenuState();
}

class _SideMenuState extends State<_SideMenu> {
  bool _learningAppsExpanded = false;

  static const _learningApps = [
    AdminSection.notes,
    AdminSection.timer,
    AdminSection.flashCard,
    AdminSection.studyGroup,
    AdminSection.leaderboard,
  ];

  @override
  Widget build(BuildContext context) {
    final accent = widget.controller.primaryColor;
    final offset = lerpDouble(-36, 0, widget.progress)!;
    final learningAppsExpanded =
        _learningAppsExpanded || _learningApps.contains(widget.currentSection);
    const overview = [
      AdminSection.overview,
    ];
    const aiManage = [
      AdminSection.aiAssistant,
      AdminSection.aiSettings,
    ];
    const dataAndAutomation = [
      AdminSection.analytics,
      AdminSection.automations,
    ];
    const systemArea = [
      AdminSection.settings,
    ];

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 14, 56, 14),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: (widget.isDarkMode
                    ? const Color(0xFF070A11)
                    : const Color(0xFF1C2442))
                .withValues(alpha: 0.96),
            borderRadius: BorderRadius.circular(28),
          ),
          child: Transform.translate(
            offset: Offset(offset, 0),
            child: Opacity(
              opacity: lerpDouble(0.15, 1, widget.progress)!,
              child: SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(bottom: 14),
                        child: Image.asset(
                          'logo/logo白透明.png',
                          height: 32,
                          fit: BoxFit.fitHeight,
                        ),
                      ),
                      InkWell(
                        borderRadius: BorderRadius.circular(18),
                        onTap: widget.onOpenProfile,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                              vertical: 4, horizontal: 4),
                          child: Row(
                            children: [
                              Container(
                                width: 42,
                                height: 42,
                                decoration: BoxDecoration(
                                  gradient: widget.controller.userProfile
                                              .avatarImagePath ==
                                          null
                                      ? LinearGradient(
                                          colors: [
                                            accent,
                                            const Color(0xFF8D5EFF)
                                          ],
                                        )
                                      : null,
                                  shape: BoxShape.circle,
                                ),
                                clipBehavior: Clip.antiAlias,
                                child: widget.controller.userProfile
                                            .avatarImagePath !=
                                        null
                                    ? Image.file(
                                        File(widget.controller.userProfile
                                            .avatarImagePath!),
                                        fit: BoxFit.cover,
                                        errorBuilder: (_, __, ___) => Center(
                                          child: Text(
                                              widget.controller.userProfile
                                                  .avatarEmoji,
                                              style: const TextStyle(
                                                  fontSize: 22)),
                                        ),
                                      )
                                    : Center(
                                        child: Text(
                                          widget.controller.userProfile
                                              .avatarEmoji,
                                          style: const TextStyle(fontSize: 22),
                                        ),
                                      ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      widget.controller.userProfile.nickname,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 17,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      widget.controller.userProfile.bio,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        color: Color(0xB3FFFFFF),
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Icon(
                                Icons.chevron_right_rounded,
                                color: Colors.white.withValues(alpha: 0.4),
                                size: 18,
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      _SideMenuGroup(
                        title: '总览',
                        sections: overview,
                        currentSection: widget.currentSection,
                        onSelected: widget.onSelected,
                      ),
                      _SideMenuGroup(
                        title: 'AI 管理',
                        sections: aiManage,
                        currentSection: widget.currentSection,
                        onSelected: widget.onSelected,
                      ),
                      _SideMenuGroup(
                        title: '学习应用',
                        sections: _learningApps,
                        currentSection: widget.currentSection,
                        onSelected: widget.onSelected,
                        collapsible: true,
                        expanded: learningAppsExpanded,
                        onHeaderTap: () {
                          setState(() {
                            _learningAppsExpanded = !learningAppsExpanded;
                          });
                        },
                      ),
                      _SideMenuGroup(
                        title: '数据与编排',
                        sections: dataAndAutomation,
                        currentSection: widget.currentSection,
                        onSelected: widget.onSelected,
                      ),
                      _SideMenuGroup(
                        title: '系统',
                        sections: systemArea,
                        currentSection: widget.currentSection,
                        onSelected: widget.onSelected,
                      ),
                      const SizedBox(height: 16),
                      _ThemeModeButton(
                        value: widget.isDarkMode,
                        onChanged: widget.onDarkModeChanged,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SideMenuItem extends StatelessWidget {
  const _SideMenuItem({
    required this.section,
    required this.selected,
    required this.onTap,
  });
  final AdminSection section;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      key: Key('drawer_admin_${section.name}'),
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        height: 44,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          color: selected
              ? const Color(0xFF7394F9)
              : Colors.white.withValues(alpha: 0.04),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            Icon(
              section.icon,
              color: Colors.white.withValues(alpha: selected ? 1 : 0.88),
              size: 20,
            ),
            const SizedBox(width: 14),
            Text(
              section.label,
              style: TextStyle(
                color: Colors.white.withValues(alpha: selected ? 1 : 0.86),
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SideMenuGroup extends StatelessWidget {
  const _SideMenuGroup({
    required this.title,
    required this.sections,
    required this.currentSection,
    required this.onSelected,
    this.collapsible = false,
    this.expanded = true,
    this.onHeaderTap,
  });

  final String title;
  final List<AdminSection> sections;
  final AdminSection currentSection;
  final ValueChanged<AdminSection> onSelected;
  final bool collapsible;
  final bool expanded;
  final VoidCallback? onHeaderTap;

  @override
  Widget build(BuildContext context) {
    final titleText = Text(
      title,
      style: const TextStyle(
        color: Color(0x99FFFFFF),
        fontSize: 12,
        fontWeight: FontWeight.w600,
        letterSpacing: 1.2,
      ),
    );

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (collapsible)
            InkWell(
              borderRadius: BorderRadius.circular(4),
              onTap: onHeaderTap,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    titleText,
                    const SizedBox(width: 4),
                    AnimatedRotation(
                      turns: expanded ? 0 : 0.5,
                      duration: const Duration(milliseconds: 250),
                      curve: Curves.fastOutSlowIn,
                      child: const Icon(
                        Icons.keyboard_arrow_up_rounded,
                        color: Color(0x99FFFFFF),
                        size: 16,
                      ),
                    ),
                  ],
                ),
              ),
            )
          else
            titleText,
          AnimatedSize(
            duration: const Duration(milliseconds: 250),
            curve: Curves.fastOutSlowIn,
            alignment: Alignment.topCenter,
            child: expanded
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const SizedBox(height: 8),
                      for (var i = 0; i < sections.length; i++) ...[
                        _SideMenuItem(
                          section: sections[i],
                          selected: currentSection == sections[i],
                          onTap: () => onSelected(sections[i]),
                        ),
                        if (i != sections.length - 1)
                          const SizedBox(height: 4),
                      ],
                    ],
                  )
                : const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }
}

class _ThemeModeButton extends StatelessWidget {
  const _ThemeModeButton({
    required this.value,
    required this.onChanged,
  });
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final label = value ? '夜间' : '日间';
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => onChanged(!value),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: value ? 0.12 : 0.08),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.08),
                ),
              ),
              child: Icon(
                value ? Icons.dark_mode_rounded : Icons.light_mode_rounded,
                color: Colors.white,
                size: 22,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              label,
              style: const TextStyle(
                color: Color(0xCCFFFFFF),
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
