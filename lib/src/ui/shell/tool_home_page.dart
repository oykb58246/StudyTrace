import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:image_picker/image_picker.dart';
import 'package:lordicon/lordicon.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

import '../../controllers/app_data_controller.dart';
import '../../models/study_sub_task_item.dart';
import '../../models/study_task_item.dart';
import '../../services/ai_study_service.dart';
import '../../theme/app_theme.dart';
import '../shared/app_assets.dart';
import '../shared/common_widgets.dart';
import '../shared/rive_safe_widget.dart';

class HomePage extends StatelessWidget {
  const HomePage({
    super.key,
    required this.isDarkMode,
    required this.controller,
    required this.onGenerateReport,
    this.onOpenAiAssistant,
    this.onOpenAiChat,
    this.onOpenLogs,
    this.onOpenCalendar,
    this.onOpenTasks,
    this.onOpenNotes,
    this.onOpenTimer,
    this.onOpenFlashCards,
    this.onOpenDashboard,
    this.onOpenStudyGroup,
    this.onOpenLeaderboard,
    this.onOpenSyncSettings,
    this.onOpenTaskPlanning,
  });

  final bool isDarkMode;
  final AppDataController controller;
  final VoidCallback onGenerateReport;
  final VoidCallback? onOpenAiAssistant;
  final VoidCallback? onOpenAiChat;
  final VoidCallback? onOpenLogs;
  final VoidCallback? onOpenCalendar;
  final VoidCallback? onOpenTasks;
  final VoidCallback? onOpenNotes;
  final VoidCallback? onOpenTimer;
  final VoidCallback? onOpenFlashCards;
  final VoidCallback? onOpenDashboard;
  final VoidCallback? onOpenStudyGroup;
  final VoidCallback? onOpenLeaderboard;
  final VoidCallback? onOpenSyncSettings;
  final VoidCallback? onOpenTaskPlanning;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final accent = controller.primaryColor;
        final logs = controller.studyLogs;
        final tasks = controller.studyTasks;

        final now = DateTime.now();
        final weekAgo = now.subtract(const Duration(days: 7));
        final recentLogs =
            logs.where((l) => !l.date.isBefore(weekAgo)).toList();

        final completedTasks =
            tasks.where((t) => t.status == StudyTaskStatus.completed).length;
        final totalTasks = tasks.length;
        final progress = totalTasks > 0 ? completedTasks / totalTasks : 0.0;

        final recentCourseNames = recentLogs
            .map((l) => l.courseName)
            .where((n) => n.isNotEmpty)
            .toSet()
            .toList();
        final textColor = isDarkMode ? Colors.white : AppColors.ink;
        final bodyColor =
            isDarkMode ? const Color(0xFFC2C8D6) : AppColors.body;

        return Column(
          children: [
            Expanded(
              child: Stack(
                children: [
                  _HomeRiveBackground(isDarkMode: isDarkMode),
                  RefreshIndicator(
                    onRefresh: () async => controller.notifyListeners(),
                    child: ListView(
                    key: const Key('page_home'),
                    padding: const EdgeInsets.fromLTRB(20, 76, 20, 124),
              children: [
              Center(
                child: Column(
                  children: [
                    Image.asset(
                      isDarkMode
                          ? 'logo/logo白透明.png'
                          : 'logo/logo黑透明.png',
                      height: 36,
                      fit: BoxFit.fitHeight,
                    ),
                    const SizedBox(height: 7),
                    Image.asset(
                      'logo/文字logo.png',
                      height: 28,
                      fit: BoxFit.fitHeight,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              _HomeAiChatEntry(
                isDarkMode: isDarkMode,
                onTap: onOpenAiChat ?? onOpenAiAssistant,
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  Expanded(
                    child: _HomeFeatureCard(
                      title: '语音创建',
                      subtitle: '说出记录或任务',
                      asset: 'assets/icons/home_voice.png',
                      colors: const [Color(0xFF0E8CFF), Color(0xFF5A7BFF)],
                      onTap: () => _openAiCreate(
                        context,
                        source: _AiCreateSource.voice,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _HomeFeatureCard(
                      title: '拍照创建',
                      subtitle: '识图生成记录',
                      asset: 'assets/icons/home_camera.png',
                      colors: const [Color(0xFFFF5A3D), Color(0xFFFF9F50)],
                      onTap: () => _openAiCreate(
                        context,
                        source: _AiCreateSource.photo,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: _HomeToolCard(
                      label: '任务编排',
                      asset: 'assets/icons/home_plan.png',
                      isDarkMode: isDarkMode,
                      onTap: onOpenTaskPlanning,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _HomeToolCard(
                      label: '学习笔记',
                      asset: 'assets/icons/home_notes.png',
                      isDarkMode: isDarkMode,
                      onTap: onOpenNotes,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                clipBehavior: Clip.none,
                child: Row(
                  children: [
                    _HomeShortcut(
                      label: '知识闪卡',
                      asset: 'assets/icons/home_flashcard.png',
                      isDarkMode: isDarkMode,
                      onTap: onOpenFlashCards,
                    ),
                    _HomeShortcut(
                      label: '数据看板',
                      asset: 'assets/icons/home_dashboard.png',
                      isDarkMode: isDarkMode,
                      onTap: onOpenDashboard,
                    ),
                    _HomeShortcut(
                      label: '专注计时',
                      asset: 'assets/icons/home_timer.png',
                      isDarkMode: isDarkMode,
                      onTap: onOpenTimer,
                    ),
                    _HomeShortcut(
                      label: '学习小组',
                      asset: 'assets/icons/home_group.png',
                      isDarkMode: isDarkMode,
                      onTap: onOpenStudyGroup,
                    ),
                    _HomeShortcut(
                      label: '排行榜',
                      asset: 'assets/icons/home_rank.png',
                      isDarkMode: isDarkMode,
                      onTap: onOpenLeaderboard,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              _ProgressPanel(
                isDarkMode: isDarkMode,
                accent: accent,
                completedTasks: completedTasks,
                totalTasks: totalTasks,
                progress: progress,
                streak: controller.studyStreak,
              ),
              const SizedBox(height: 24),
              Text(
                '最近记录',
                style: TextStyle(
                  color: textColor,
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 12),
              if (recentCourseNames.isNotEmpty)
                Text(
                  '本周课程：${recentCourseNames.join('、')}',
                  style: TextStyle(color: bodyColor, fontSize: 13),
                ),
              if (recentCourseNames.isNotEmpty) const SizedBox(height: 12),
              if (recentLogs.isEmpty)
                _EmptyRecentCard(isDarkMode: isDarkMode)
              else
                for (final log in recentLogs.take(4)) ...[
                  _RecentLogCard(
                    courseName:
                        log.courseName.isNotEmpty ? log.courseName : '未归课程',
                    content: log.content.isNotEmpty ? log.content : '无内容摘要',
                    date: _fmtDate(log.date),
                    isDarkMode: isDarkMode,
                  ),
                  if (log != recentLogs.take(4).last)
                    const SizedBox(height: 10),
                ],
              ],
                    ), // RefreshIndicator
            ),
          ],
        ),
      ),
    ],
  );
      },
    );
  }

  void _openAiCreate(
    BuildContext context, {
    required _AiCreateSource source,
  }) {
    Navigator.of(context).push(
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 340),
        reverseTransitionDuration: const Duration(milliseconds: 240),
        pageBuilder: (_, __, ___) => _AiCreateInput(
          source: source,
          isDarkMode: isDarkMode,
          controller: controller,
        ),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          final curved = CurvedAnimation(
            parent: animation,
            curve: Curves.easeOutCubic,
          );
          return FadeTransition(
            opacity: curved,
            child: ScaleTransition(
              scale: Tween<double>(begin: 0.96, end: 1).animate(curved),
              child: child,
            ),
          );
        },
      ),
    );
  }
}

class _HomeRiveBackground extends StatelessWidget {
  const _HomeRiveBackground({required this.isDarkMode});

  final bool isDarkMode;

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.sizeOf(context);

    return Stack(
      fit: StackFit.expand,
      children: [
        DecoratedBox(
          decoration: BoxDecoration(
            color:
                isDarkMode ? const Color(0xFF101625) : const Color(0xFFEAF2FF),
          ),
        ),
        Positioned(
          width: screenSize.width * 2.28,
          left: -screenSize.width * 0.58,
          top: -screenSize.height * 0.12,
          child: IgnorePointer(
            child: Image.asset(
              AppAssets.spline,
              fit: BoxFit.fitWidth,
              filterQuality: FilterQuality.high,
            ),
          ),
        ),
        Positioned.fill(
          child: IgnorePointer(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 3.5, sigmaY: 3.5),
              child: const SizedBox.expand(),
            ),
          ),
        ),
        Positioned.fill(
          child: IgnorePointer(
            child: ExcludeSemantics(
              child: Opacity(
                opacity: isDarkMode ? 0.54 : 0.82,
                child: const SafeRiveAsset(
                  asset: AppAssets.shapes,
                  fit: BoxFit.cover,
                ),
              ),
            ),
          ),
        ),
        Positioned.fill(
          child: IgnorePointer(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 4, sigmaY: 4),
              child: const SizedBox.expand(),
            ),
          ),
        ),
        Positioned.fill(
          child: IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: isDarkMode
                      ? [
                          const Color(0xFF101625).withValues(alpha: 0.16),
                          const Color(0xFF0A0F1C).withValues(alpha: 0.36),
                        ]
                      : [
                          Colors.white.withValues(alpha: 0.02),
                          const Color(0xFFDDEBFF).withValues(alpha: 0.08),
                        ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _GlassCard extends StatelessWidget {
  const _GlassCard({
    required this.isDarkMode,
    required this.child,
    this.height,
    this.padding,
    this.radius = 26,
  });

  final bool isDarkMode;
  final Widget child;
  final double? height;
  final EdgeInsetsGeometry? padding;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          height: height,
          padding: padding,
          decoration: _softCardDecoration(isDarkMode, radius: radius),
          child: child,
        ),
      ),
    );
  }
}

class _HomeAiChatEntry extends StatelessWidget {
  const _HomeAiChatEntry({
    required this.isDarkMode,
    this.onTap,
  });

  final bool isDarkMode;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(28),
        onTap: onTap,
        child: _GlassCard(
          isDarkMode: isDarkMode,
          height: 76,
          padding: const EdgeInsets.fromLTRB(14, 9, 14, 9),
          radius: 28,
          child: Row(
            children: [
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFF1EA7FF), Color(0xFF5B6DFF)],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF1EA7FF).withValues(alpha: 0.26),
                      blurRadius: 18,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: ColorFiltered(
                  colorFilter: const ColorFilter.mode(
                    Colors.white,
                    BlendMode.srcIn,
                  ),
                  child: _HomeAnimatedIcon(
                    asset: 'assets/icons/lordicon/vimeo.json',
                    size: 25,
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'AI 对话',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: isDarkMode ? Colors.white : AppColors.ink,
                        fontSize: 19,
                        height: 1.08,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '问计划、记学习、做复盘',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: isDarkMode
                            ? Colors.white.withValues(alpha: 0.5)
                            : AppColors.muted,
                        fontSize: 12,
                        height: 1.1,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: isDarkMode
                      ? Colors.white.withValues(alpha: 0.06)
                      : Colors.white.withValues(alpha: 0.36),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(
                  Icons.arrow_forward_rounded,
                  color: Color(0xFF2D8CFF),
                  size: 22,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HomeFeatureCard extends StatelessWidget {
  const _HomeFeatureCard({
    required this.title,
    required this.subtitle,
    required this.asset,
    required this.colors,
    this.onTap,
  });

  final String title;
  final String subtitle;
  final String asset;
  final List<Color> colors;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(26),
        onTap: onTap,
        child: Container(
          height: 118,
          padding: const EdgeInsets.fromLTRB(16, 16, 10, 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(26),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: colors.map((color) => color.withValues(alpha: 0.9)).toList(),
            ),
            border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
            boxShadow: [
              BoxShadow(
                color: colors.first.withValues(alpha: 0.22),
                blurRadius: 22,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Stack(
            children: [
              Positioned(
                top: -36,
                right: -24,
                child: Container(
                  width: 90,
                  height: 90,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withValues(alpha: 0.18),
                  ),
                ),
              ),
              Positioned(
                right: -10,
                bottom: -12,
                child: Container(
                  width: 76,
                  height: 76,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.32),
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: Center(
                    child: ColorFiltered(
                      colorFilter: const ColorFilter.mode(
                        Colors.white,
                        BlendMode.srcIn,
                      ),
                      child: _HomeAnimatedIcon(asset: asset, size: 66),
                    ),
                  ),
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 21,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.78),
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
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

class _HomeAnimatedIcon extends StatefulWidget {
  const _HomeAnimatedIcon({
    required this.asset,
    required this.size,
  });

  final String asset;
  final double size;

  @override
  State<_HomeAnimatedIcon> createState() => _HomeAnimatedIconState();
}

class _HomeAnimatedIconState extends State<_HomeAnimatedIcon> {
  IconController? _controller;

  @override
  void initState() {
    super.initState();
    _setupController();
  }

  @override
  void didUpdateWidget(covariant _HomeAnimatedIcon oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.asset != widget.asset) {
      _controller?.dispose();
      _setupController();
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  void _setupController() {
    final path = _lordiconAssetFor(widget.asset);
    if (path == null) {
      _controller = null;
      return;
    }
    final controller = IconController.assets(path);
    controller.addStatusListener((status) {
      if (status == ControllerStatus.ready) {
        controller.playFromBeginning();
      }
    });
    _controller = controller;
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    if (controller == null) {
      return Image.asset(widget.asset, width: widget.size, height: widget.size);
    }
    return IconViewer(
      key: ValueKey(widget.asset),
      controller: controller,
      width: widget.size,
      height: widget.size,
    );
  }
}

String? _lordiconAssetFor(String asset) {
  return switch (asset) {
    'assets/icons/home_voice.png' => 'assets/icons/lordicon/voice.json',
    'assets/icons/home_camera.png' => 'assets/icons/lordicon/camera.json',
    'assets/icons/home_plan.png' => 'assets/icons/lordicon/route.json',
    'assets/icons/home_notes.png' => 'assets/icons/lordicon/notes.json',
    'assets/icons/home_flashcard.png' => 'assets/icons/lordicon/cards.json',
    'assets/icons/home_dashboard.png' => 'assets/icons/lordicon/chart.json',
    'assets/icons/home_timer.png' => 'assets/icons/lordicon/timer.json',
    'assets/icons/home_group.png' => 'assets/icons/lordicon/group.json',
    'assets/icons/home_rank.png' => 'assets/icons/lordicon/rank.json',
    'assets/icons/home_report.png' => 'assets/icons/lordicon/report.json',
    'assets/icons/home_sync.png' => 'assets/icons/lordicon/sync.json',
    'assets/icons/home_continue.png' => 'assets/icons/lordicon/play.json',
    'assets/icons/lordicon/bonfire.json' => 'assets/icons/lordicon/bonfire.json',
    'assets/icons/lordicon/vimeo.json' => 'assets/icons/lordicon/vimeo.json',
    _ => null,
  };
}

class _HomeToolCard extends StatelessWidget {
  const _HomeToolCard({
    required this.label,
    required this.asset,
    required this.isDarkMode,
    this.onTap,
  });

  final String label;
  final String asset;
  final bool isDarkMode;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: onTap,
        child: _GlassCard(
          isDarkMode: isDarkMode,
          height: 112,
          padding: const EdgeInsets.symmetric(vertical: 10),
          radius: 24,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: isDarkMode
                      ? Colors.white.withValues(alpha: 0.05)
                      : Colors.white.withValues(alpha: 0.36),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Center(
                  child: _HomeAnimatedIcon(asset: asset, size: 50),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                label,
                style: TextStyle(
                  color: isDarkMode ? Colors.white70 : AppColors.ink,
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HomeShortcut extends StatelessWidget {
  const _HomeShortcut({
    required this.label,
    required this.asset,
    required this.isDarkMode,
    this.onTap,
  });

  final String label;
  final String asset;
  final bool isDarkMode;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 12),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(22),
          onTap: onTap,
          child: SizedBox(
            width: 72,
            child: _GlassCard(
              isDarkMode: isDarkMode,
              height: 92,
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
              radius: 22,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
                      color: isDarkMode
                          ? Colors.white.withValues(alpha: 0.05)
                          : Colors.white.withValues(alpha: 0.36),
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: Center(
                      child: _HomeAnimatedIcon(asset: asset, size: 44),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    label,
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: isDarkMode ? Colors.white70 : AppColors.ink,
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _HomeTabs extends StatelessWidget {
  const _HomeTabs({required this.isDarkMode});

  final bool isDarkMode;

  @override
  Widget build(BuildContext context) {
    final inactive = isDarkMode ? Colors.white54 : AppColors.muted;
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      clipBehavior: Clip.none,
      child: Row(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '推荐',
                style: TextStyle(
                  color: isDarkMode ? Colors.white : AppColors.ink,
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 5),
              Container(
                width: 22,
                height: 4,
                decoration: BoxDecoration(
                  color: const Color(0xFF238BFF),
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
            ],
          ),
          const SizedBox(width: 28),
          Text(
            '本周复盘',
            style: TextStyle(
              color: inactive,
              fontSize: 17,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(width: 24),
          Text(
            '小组学习',
            style: TextStyle(
              color: inactive,
              fontSize: 17,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _RecommendationCard extends StatelessWidget {
  const _RecommendationCard({
    required this.title,
    required this.subtitle,
    required this.asset,
    required this.isDarkMode,
    this.buttonLabel,
    this.onTap,
  });

  final String title;
  final String subtitle;
  final String asset;
  final String? buttonLabel;
  final bool isDarkMode;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(24),
      onTap: onTap,
      child: _GlassCard(
        isDarkMode: isDarkMode,
        height: 176,
        padding: const EdgeInsets.all(16),
        radius: 24,
        child: Stack(
          children: [
            Positioned(
              right: -12,
              bottom: -12,
              child: _HomeAnimatedIcon(asset: asset, size: 92),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: isDarkMode ? Colors.white : AppColors.ink,
                    fontSize: 17,
                    height: 1.15,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 7),
                Text(
                  subtitle,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: isDarkMode ? Colors.white54 : AppColors.muted,
                    fontSize: 12,
                    height: 1.3,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Spacer(),
                if (buttonLabel != null)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 13, vertical: 8),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF1687FF), Color(0xFF296DFF)],
                      ),
                      borderRadius: BorderRadius.circular(999),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x221687FF),
                          blurRadius: 14,
                          offset: Offset(0, 7),
                        ),
                      ],
                    ),
                    child: Text(
                      buttonLabel!,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ProgressPanel extends StatelessWidget {
  const _ProgressPanel({
    required this.isDarkMode,
    required this.accent,
    required this.completedTasks,
    required this.totalTasks,
    required this.progress,
    required this.streak,
  });

  final bool isDarkMode;
  final Color accent;
  final int completedTasks;
  final int totalTasks;
  final double progress;
  final int streak;

  @override
  Widget build(BuildContext context) {
    return _GlassCard(
      isDarkMode: isDarkMode,
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 58,
                height: 58,
                decoration: BoxDecoration(
                  color: isDarkMode
                      ? Colors.white.withValues(alpha: 0.05)
                      : Colors.white.withValues(alpha: 0.34),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Center(
                  child: _HomeAnimatedIcon(
                    asset: 'assets/icons/lordicon/bonfire.json',
                    size: 50,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '连续学习 $streak 天',
                      style: TextStyle(
                        color: isDarkMode ? Colors.white : AppColors.ink,
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      totalTasks > 0
                          ? '任务进度 $completedTasks / $totalTasks'
                          : '还没有学习任务',
                      style: TextStyle(
                        color: isDarkMode ? Colors.white54 : AppColors.muted,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                totalTasks > 0 ? '${(progress * 100).toInt()}%' : '0%',
                style: TextStyle(
                  color: accent,
                  fontSize: 23,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: progress,
              backgroundColor: isDarkMode
                  ? Colors.white.withValues(alpha: 0.1)
                  : const Color(0xFFE8EBF5),
              color: accent,
              minHeight: 8,
            ),
          ),
        ],
      ),
    );
  }
}

class _RecentLogCard extends StatelessWidget {
  const _RecentLogCard({
    required this.courseName,
    required this.content,
    required this.date,
    required this.isDarkMode,
  });

  final String courseName;
  final String content;
  final String date;
  final bool isDarkMode;

  @override
  Widget build(BuildContext context) {
    return _GlassCard(
      isDarkMode: isDarkMode,
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: isDarkMode
                  ? Colors.white.withValues(alpha: 0.05)
                  : Colors.white.withValues(alpha: 0.34),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Center(
              child: _HomeAnimatedIcon(
                asset: 'assets/icons/home_notes.png',
                size: 42,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  courseName,
                  style: TextStyle(
                    color: isDarkMode ? Colors.white : AppColors.ink,
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  content,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: isDarkMode ? Colors.white54 : AppColors.body,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          Text(
            date,
            style: TextStyle(
              color: isDarkMode ? Colors.white38 : AppColors.muted,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyRecentCard extends StatelessWidget {
  const _EmptyRecentCard({required this.isDarkMode});

  final bool isDarkMode;

  @override
  Widget build(BuildContext context) {
    return _GlassCard(
      isDarkMode: isDarkMode,
      padding: const EdgeInsets.all(18),
      child: Text(
        '近 7 天没有学习记录。可以从「AI 对话」开始整理计划或复盘。',
        style: TextStyle(
          color: isDarkMode ? const Color(0xFFC2C8D6) : AppColors.body,
          height: 1.55,
        ),
      ),
    );
  }
}

BoxDecoration _softCardDecoration(bool isDarkMode, {double radius = 26}) {
  return BoxDecoration(
    color: isDarkMode
        ? const Color(0xFF242B37).withValues(alpha: 0.72)
        : Colors.white.withValues(alpha: 0.26),
    borderRadius: BorderRadius.circular(radius),
    border: Border.all(
      color: isDarkMode
          ? Colors.white.withValues(alpha: 0.08)
          : Colors.white.withValues(alpha: 0.36),
    ),
    boxShadow: isDarkMode
        ? null
        : const [
            BoxShadow(
              color: Color(0x0F123C78),
              blurRadius: 24,
              offset: Offset(0, 12),
            ),
            BoxShadow(
              color: Color(0xFFFFFFFF),
              blurRadius: 1,
              offset: Offset(0, -1),
            ),
          ],
  );
}

String _fmtDate(DateTime date) {
  return '${date.month}/${date.day}';
}

enum _AiCreateSource { voice, photo }

enum _AiCreateMode { log, task }

class _AiCreateInput extends StatefulWidget {
  const _AiCreateInput({
    required this.source,
    required this.isDarkMode,
    required this.controller,
  });

  final _AiCreateSource source;
  final bool isDarkMode;
  final AppDataController controller;

  @override
  State<_AiCreateInput> createState() => _AiCreateInputState();
}

class _AiCreateInputState extends State<_AiCreateInput> {
  final _aiService = AiStudyService();
  final _inputController = TextEditingController();
  final _speech = stt.SpeechToText();
  final _imagePicker = ImagePicker();

  _AiCreateMode _mode = _AiCreateMode.log;
  bool _isListening = false;
  bool _isProcessing = false;
  bool _didAutoPick = false;
  String _statusText = '';

  bool get _isPhoto => widget.source == _AiCreateSource.photo;

  @override
  void initState() {
    super.initState();
    if (_isPhoto) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _pickPhoto());
    } else {
      _initSpeech();
    }
  }

  Future<void> _initSpeech() async {
    try {
      await _speech.initialize(
        onStatus: (status) {
          if (!mounted) return;
          if (status == 'done' || status == 'notListening') {
            setState(() => _isListening = false);
          }
        },
        onError: (error) {
          if (!mounted) return;
          setState(() {
            _isListening = false;
            _statusText = '语音识别失败，可手动输入内容';
          });
        },
      );
    } catch (_) {
      if (mounted) {
        setState(() => _statusText = '语音不可用，可手动输入内容');
      }
    }
  }

  Future<void> _toggleSpeech() async {
    if (_isListening) {
      await _speech.stop();
      if (mounted) setState(() => _isListening = false);
      return;
    }
    try {
      final available = await _speech.initialize();
      if (!available) {
        if (mounted) setState(() => _statusText = '语音不可用，可手动输入内容');
        return;
      }
      setState(() {
        _isListening = true;
        _statusText = '正在听写...';
      });
      await _speech.listen(
        localeId: 'zh_CN',
        listenFor: const Duration(minutes: 1),
        pauseFor: const Duration(seconds: 4),
        listenOptions: stt.SpeechListenOptions(partialResults: true),
        onResult: (result) {
          _inputController.text = result.recognizedWords;
          _inputController.selection = TextSelection.collapsed(
            offset: _inputController.text.length,
          );
          if (result.finalResult && mounted) {
            setState(() {
              _isListening = false;
              _statusText = '语音已填入，可继续编辑';
            });
          }
        },
      );
    } catch (_) {
      if (mounted) {
        setState(() {
          _isListening = false;
          _statusText = '语音识别失败，可手动输入内容';
        });
      }
    }
  }

  Future<void> _pickPhoto() async {
    if (_didAutoPick && _inputController.text.trim().isNotEmpty) return;
    _didAutoPick = true;
    try {
      setState(() => _statusText = '正在读取图片...');
      final picked = await _imagePicker.pickImage(
        source: ImageSource.camera,
        imageQuality: 92,
      );
      if (picked == null) {
        if (mounted) setState(() => _statusText = '可重新拍照或手动输入内容');
        return;
      }
      final inputImage = InputImage.fromFilePath(picked.path);
      final recognizer = TextRecognizer(
        script: TextRecognitionScript.chinese,
      );
      final result = await recognizer.processImage(inputImage);
      await recognizer.close();
      final text = result.text.trim();
      if (!mounted) return;
      setState(() {
        _inputController.text = text;
        _inputController.selection = TextSelection.collapsed(
          offset: _inputController.text.length,
        );
        _statusText = text.isEmpty ? '未识别到文字，可手动输入描述' : '已识别图片文字';
      });
    } on PlatformException catch (error) {
      if (mounted) {
        setState(() => _statusText = '图片识别失败：${error.message ?? error.code}');
      }
    } catch (_) {
      if (mounted) setState(() => _statusText = '图片识别失败，可手动输入描述');
    }
  }

  Future<void> _submit() async {
    final input = _inputController.text.trim();
    if (input.isEmpty || _isProcessing) return;
    setState(() => _isProcessing = true);
    try {
      if (_mode == _AiCreateMode.log) {
        final log = await _aiService.generateStudyLog(input);
        await widget.controller.addStudyLog(
          date: DateTime.now(),
          courseName: log.courseName,
          content: log.content.isNotEmpty ? log.content : input,
          problems: log.problems,
          thoughts: log.thoughts,
          nextPlan: log.nextPlan,
        );
      } else {
        final plan = await _aiService.generateTaskPlan(input);
        final now = DateTime.now();
        final planned = plan.plannedSubTasks.isNotEmpty
            ? plan.plannedSubTasks
                .map((p) => StudySubTaskItem(
                      id: 'sub_ai_${now.microsecondsSinceEpoch}_${plan.plannedSubTasks.indexOf(p)}',
                      title: p.title,
                      startAt: p.startAt,
                      deadline: p.deadline,
                      note: p.note,
                      createdAt: now,
                      updatedAt: now,
                    ))
                .toList()
            : plan.subTasks
                .map((s) => StudySubTaskItem(
                      id: 'sub_ai_${now.microsecondsSinceEpoch}_${plan.subTasks.indexOf(s)}',
                      title: s,
                      deadline: plan.deadline,
                      createdAt: now,
                      updatedAt: now,
                    ))
                .toList();
        await widget.controller.addStudyTask(
          title: plan.mainTitle.isNotEmpty ? plan.mainTitle : input,
          type: plan.taskType,
          courseName: plan.courseName,
          deadline: plan.deadline,
          subTasks: planned,
          note: _isPhoto ? '已通过拍照创建' : '已通过语音创建',
        );
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_mode == _AiCreateMode.log ? '学习记录已保存' : '学习任务已创建'),
        ),
      );
      Navigator.of(context).pop();
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _isProcessing = false;
        _statusText = 'AI 创建失败：$error';
      });
    }
  }

  @override
  void dispose() {
    _speech.stop();
    _inputController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final accent = widget.controller.primaryColor;
    final textColor = widget.isDarkMode ? Colors.white : AppColors.ink;
    final bodyColor =
        widget.isDarkMode ? const Color(0xFFC2C8D6) : AppColors.body;
    final title = _isPhoto ? '拍照创建' : '语音创建';
    final actionLabel = _mode == _AiCreateMode.log ? '生成学习记录' : '生成学习任务';

    return Scaffold(
      backgroundColor:
          widget.isDarkMode ? const Color(0xFF141923) : const Color(0xFFF5F7FF),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        foregroundColor: textColor,
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(22, 18, 22, 36),
        children: [
          _CreateModeToggle(
            isDarkMode: widget.isDarkMode,
            mode: _mode,
            onChanged: (mode) => setState(() => _mode = mode),
          ),
          const SizedBox(height: 18),
          TextField(
            controller: _inputController,
            minLines: 6,
            maxLines: 9,
            style: TextStyle(color: textColor, fontSize: 15, height: 1.45),
            decoration: InputDecoration(
              hintText: _isPhoto
                  ? '拍照识别后会填入这里，也可以手动描述图片内容...'
                  : '点击麦克风说出学习记录或任务，也可以手动输入...',
              hintStyle: TextStyle(color: bodyColor.withValues(alpha: 0.62)),
              filled: true,
              fillColor: widget.isDarkMode
                  ? Colors.white.withValues(alpha: 0.06)
                  : Colors.white,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(24),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.all(18),
            ),
          ),
          if (_statusText.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(_statusText, style: TextStyle(color: bodyColor, fontSize: 12)),
          ],
          const SizedBox(height: 18),
          Row(
            children: [
              if (_isPhoto)
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _isProcessing ? null : _pickPhoto,
                    icon: const Icon(Icons.photo_camera_rounded),
                    label: const Text('重新拍照'),
                  ),
                )
              else
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _isProcessing ? null : _toggleSpeech,
                    icon: Icon(_isListening
                        ? Icons.stop_rounded
                        : Icons.mic_rounded),
                    label: Text(_isListening ? '停止听写' : '开始语音'),
                  ),
                ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: accent,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                    ),
                  ),
                  onPressed: _isProcessing ? null : _submit,
                  icon: _isProcessing
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.auto_awesome_rounded),
                  label: Text(actionLabel),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _CreateModeToggle extends StatelessWidget {
  const _CreateModeToggle({
    required this.isDarkMode,
    required this.mode,
    required this.onChanged,
  });

  final bool isDarkMode;
  final _AiCreateMode mode;
  final ValueChanged<_AiCreateMode> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(5),
      decoration: BoxDecoration(
        color: isDarkMode ? Colors.white.withValues(alpha: 0.06) : Colors.white,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          _modeButton('学习记录', _AiCreateMode.log),
          _modeButton('学习任务', _AiCreateMode.task),
        ],
      ),
    );
  }

  Widget _modeButton(String label, _AiCreateMode value) {
    final selected = mode == value;
    return Expanded(
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => onChanged(value),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          height: 44,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: selected ? const Color(0xFF238BFF) : Colors.transparent,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: selected
                  ? Colors.white
                  : (isDarkMode ? Colors.white70 : AppColors.ink),
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ),
    );
  }
}

class _VoiceTaskInput extends StatefulWidget {
  const _VoiceTaskInput({
    required this.isDarkMode,
    required this.controller,
  });

  final bool isDarkMode;
  final AppDataController controller;

  @override
  State<_VoiceTaskInput> createState() => _VoiceTaskInputState();
}

class _VoiceTaskInputState extends State<_VoiceTaskInput> {
  final _speech = stt.SpeechToText();
  bool _isListening = false;
  String _recognizedText = '';
  bool _isProcessing = false;
  bool _isInitialized = false;
  bool _isCheckingSpeech = true;
  String _speechError = '';
  final _aiService = AiStudyService();
  final _manualController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _initSpeech();
  }

  Future<void> _initSpeech() async {
    try {
      final available = await _speech.initialize(
        onError: (err) {
          if (mounted) {
            setState(() {
              _isInitialized = false;
              _speechError =
                  '语音功能需要 Google Play 服务支持，当前设备暂不支持';
              _isCheckingSpeech = false;
            });
          }
        },
      );
      if (mounted) {
        setState(() {
          _isInitialized = available;
          _isCheckingSpeech = false;
          if (!available) {
            _speechError =
                '语音功能需要 Google Play 服务支持，当前设备暂不支持';
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isInitialized = false;
          _speechError = '语音功能需要 Google Play 服务支持，当前设备暂不支持';
          _isCheckingSpeech = false;
        });
      }
    }
  }

  Future<String?> _bestLocale() async {
    try {
      final locales = await _speech.locales();
      if (locales.isEmpty) return null;
      for (final localeId in ['zh_CN', 'zh_Hans_CN', 'zh_TW', 'zh_HK', 'zh']) {
        if (locales.any((l) => l.localeId == localeId)) return localeId;
      }
      return locales.first.localeId;
    } catch (_) {
      return 'zh_CN';
    }
  }

  Future<void> _startListening() async {
    if (!_isInitialized) return;
    final locale = await _bestLocale();
    if (locale == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('未找到可用的语音语言包')),
        );
      }
      return;
    }
    setState(() {
      _isListening = true;
      _recognizedText = '';
    });
    _speech.listen(
      onResult: (result) {
        if (mounted) {
          setState(() => _recognizedText = result.recognizedWords);
        }
      },
      localeId: locale,
      listenFor: const Duration(seconds: 15),
      pauseFor: const Duration(seconds: 3),
    );
  }

  void _stopListening() {
    _speech.stop();
    setState(() => _isListening = false);
  }

  Future<void> _createTaskFromInput(String text) async {
    if (text.trim().isEmpty) return;
    setState(() => _isProcessing = true);

    try {
      final plan = await _aiService.generateTaskPlan(text);
      final now = DateTime.now();
      final subTasks = plan.plannedSubTasks.isNotEmpty
          ? plan.plannedSubTasks.map((p) => StudySubTaskItem(
                id: 'sub_v_${now.microsecondsSinceEpoch}_${plan.plannedSubTasks.indexOf(p)}',
                title: p.title, startAt: p.startAt,
                deadline: p.deadline, note: p.note,
                createdAt: now, updatedAt: now,
              )).toList()
          : plan.subTasks.map((s) => StudySubTaskItem(
                id: 'sub_v_${now.microsecondsSinceEpoch}_${plan.subTasks.indexOf(s)}',
                title: s, deadline: plan.deadline,
                createdAt: now, updatedAt: now,
              )).toList();
      await widget.controller.addStudyTask(
        title: plan.mainTitle,
        type: plan.taskType,
        courseName: plan.courseName,
        deadline: plan.deadline,
        subTasks: subTasks,
        note: '已通过语音创建',
      );
    } catch (_) {
      await widget.controller.addStudyTask(
        title: text,
        type: StudyTaskType.other,
        courseName: '',
        deadline: DateTime.now().add(const Duration(days: 7)),
        note: '已通过语音创建',
      );
    }
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('✅ 任务已创建')),
      );
      Navigator.of(context).pop();
    }
  }

  @override
  void dispose() {
    _speech.stop();
    _manualController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final accent = widget.controller.primaryColor;
    final textColor = widget.isDarkMode ? Colors.white : AppColors.ink;
    final bodyColor =
        widget.isDarkMode ? const Color(0xFFC2C8D6) : AppColors.body;

    return Scaffold(
      resizeToAvoidBottomInset: false,
      backgroundColor:
          widget.isDarkMode ? const Color(0xFF141923) : const Color(0xFFF5F7FF),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        foregroundColor: textColor,
        title: const Text('快速创建任务',
            style: TextStyle(fontWeight: FontWeight.w800)),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(22, 20, 22, 40),
        children: [
          // Manual text input (always available)
          TextField(
            controller: _manualController,
            style: TextStyle(color: textColor, fontSize: 15),
            maxLines: 3,
            decoration: InputDecoration(
              hintText: '输入任务描述，AI 自动拆解...',
              hintStyle: TextStyle(
                color: widget.isDarkMode
                    ? Colors.white.withValues(alpha: 0.35)
                    : Colors.black26,
              ),
              filled: true,
              fillColor: widget.isDarkMode
                  ? Colors.white.withValues(alpha: 0.06)
                  : const Color(0xFFF2F5FC),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          const SizedBox(height: 12),
          if (_manualController.text.isNotEmpty)
            SizedBox(
              height: 48,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: accent,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  elevation: 0,
                ),
                onPressed: _isProcessing
                    ? null
                    : () =>
                        _createTaskFromInput(_manualController.text),
                icon: _isProcessing
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.auto_awesome_rounded, size: 18),
                label: Text(
                  _isProcessing ? '创建中...' : 'AI 创建任务',
                  style: const TextStyle(
                      fontWeight: FontWeight.w800, fontSize: 14),
                ),
              ),
            ),
          const SizedBox(height: 24),

          // Voice section (secondary — requires Google Play Services)
          if (_isCheckingSpeech)
            const SizedBox.shrink()
          else if (_speechError.isNotEmpty) ...[
            const SizedBox(height: 8),
            Center(
              child: Text(
                '语音输入需要 Google Play 服务',
                style: TextStyle(
                  color: widget.isDarkMode ? Colors.white30 : AppColors.muted,
                  fontSize: 12,
                ),
              ),
            ),
          ] else ...[
            // Mic button
            Center(
              child: GestureDetector(
                onTap: _isListening ? _stopListening : () => _startListening(),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  width: _isListening ? 120 : 100,
                  height: _isListening ? 120 : 100,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: _isListening
                        ? LinearGradient(colors: [
                            const Color(0xFFFF6B35),
                            accent,
                          ])
                        : LinearGradient(colors: [
                            accent,
                            const Color(0xFF8D5EFF),
                          ]),
                    boxShadow: _isListening
                        ? [
                            BoxShadow(
                              color: accent.withValues(alpha: 0.4),
                              blurRadius: 24,
                              offset: const Offset(0, 8),
                            ),
                          ]
                        : null,
                  ),
                  child: Center(
                    child: Icon(
                      _isListening
                          ? Icons.mic_rounded
                          : Icons.mic_none_rounded,
                      color: Colors.white,
                      size: _isListening ? 44 : 36,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Center(
              child: Text(
                _isListening ? '正在聆听...' : '或点击麦克风说话',
                style: TextStyle(color: bodyColor, fontSize: 13),
              ),
            ),
            if (_recognizedText.isNotEmpty) ...[
              const SizedBox(height: 16),
              GlassCard(
                color: widget.isDarkMode
                    ? const Color(0xFF242B37).withValues(alpha: 0.9)
                    : null,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('识别结果',
                        style: TextStyle(
                            color: textColor,
                            fontSize: 14,
                            fontWeight: FontWeight.w700)),
                    const SizedBox(height: 8),
                    Text(_recognizedText,
                        style: TextStyle(
                            color: bodyColor, fontSize: 16, height: 1.5)),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                height: 48,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: accent,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16)),
                    elevation: 0,
                  ),
                  onPressed: _isProcessing
                      ? null
                      : () =>
                          _createTaskFromInput(_recognizedText),
                  icon: _isProcessing
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white),
                        )
                      : const Icon(Icons.task_alt_rounded, size: 18),
                  label: Text(
                    _isProcessing ? '创建中...' : 'AI 创建任务',
                    style: const TextStyle(
                        fontWeight: FontWeight.w800, fontSize: 14),
                  ),
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }
}
