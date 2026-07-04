import 'dart:async';

import 'package:flutter/material.dart';

import '../../config/ui_review_config.dart';
import '../../controllers/app_data_controller.dart';
import '../../services/api_client.dart';
import '../../services/group_service.dart';
import '../../services/leaderboard_service.dart';
import '../../theme/app_theme.dart';
import '../shared/app_assets.dart';
import '../shared/common_widgets.dart';

class LeaderboardPage extends StatefulWidget {
  const LeaderboardPage({
    super.key,
    required this.isDarkMode,
    required this.controller,
    this.onOpenStudyGroup,
    this.onOpenLearningMoments,
  });

  final bool isDarkMode;
  final AppDataController controller;
  final VoidCallback? onOpenStudyGroup;
  final VoidCallback? onOpenLearningMoments;

  @override
  State<LeaderboardPage> createState() => _LeaderboardPageState();
}

class _LeaderboardPageState extends State<LeaderboardPage> {
  MyScore? _myScore;
  List<GroupInfo> _groups = [];
  String? _selectedGroupId;
  List<LeaderboardEntry> _leaderboard = [];
  String _range = 'week';
  String _metric = 'points';
  bool _isLoadingScore = false;
  bool _isLoadingBoard = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    if (UiReviewConfig.enabled) {
      _loadReviewData();
    } else {
      unawaited(_loadData());
    }
  }

  void _loadReviewData() {
    final now = DateTime.now();
    setState(() {
      _myScore = const MyScore(
        totalPoints: 236,
        todayPoints: 25,
        weekPoints: 82,
        monthPoints: 164,
      );
      _groups = [
        GroupInfo(
          id: 'review_group_math',
          name: '高数复盘小组',
          memberCount: 6,
          role: 'owner',
          joinedAt: now.subtract(const Duration(days: 9)),
        ),
        GroupInfo(
          id: 'review_group_algo',
          name: '算法可视化共学组',
          memberCount: 4,
          role: 'member',
          joinedAt: now.subtract(const Duration(days: 5)),
        ),
      ];
      _selectedGroupId ??= _groups.first.id;
      _leaderboard = _reviewLeaderboardEntries(metric: _metric);
      _isLoadingScore = false;
      _isLoadingBoard = false;
      _error = null;
    });
  }

  List<LeaderboardEntry> _reviewLeaderboardEntries({required String metric}) {
    final base = switch (metric) {
      'loops' => 18,
      'review' => 14,
      'evidencePackages' => 9,
      'challengeEvidence' => 11,
      'streak' => 7,
      _ => 236,
    };
    return [
      LeaderboardEntry(
        rank: 1,
        userId: 'review_user_me',
        username: '我',
        points: base,
      ),
      LeaderboardEntry(
        rank: 2,
        userId: 'review_user_lin',
        username: '林同学',
        points: (base * 0.86).round(),
      ),
      LeaderboardEntry(
        rank: 3,
        userId: 'review_user_chen',
        username: '陈同学',
        points: (base * 0.72).round(),
      ),
      LeaderboardEntry(
        rank: 4,
        userId: 'review_user_wu',
        username: '吴同学',
        points: (base * 0.58).round(),
      ),
    ];
  }

  Future<void> _loadData() async {
    if (!widget.controller.isLoggedIn) return;
    setState(() {
      _isLoadingScore = true;
      _error = null;
    });

    try {
      final lbSvc = widget.controller.leaderboardService;
      final grpSvc = widget.controller.groupService;

      final results = await Future.wait([
        lbSvc.getMine(),
        grpSvc.listMine(),
      ]);

      if (!mounted) return;
      final score = results[0] as MyScore;
      final groups = results[1] as List<GroupInfo>;

      setState(() {
        _myScore = score;
        _groups = groups;
        if (groups.isNotEmpty && _selectedGroupId == null) {
          _selectedGroupId = groups.first.id;
        }
      });

      if (_selectedGroupId != null) {
        await _loadLeaderboard();
      }
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _error = e.message);
    } catch (_) {
      if (!mounted) return;
      setState(() => _error = '加载失败，请稍后重试');
    } finally {
      if (mounted) setState(() => _isLoadingScore = false);
    }
  }

  Future<void> _loadLeaderboard() async {
    if (_selectedGroupId == null) return;
    if (UiReviewConfig.enabled) {
      setState(() => _leaderboard = _reviewLeaderboardEntries(metric: _metric));
      return;
    }
    setState(() => _isLoadingBoard = true);
    try {
      final svc = widget.controller.leaderboardService;
      final entries = await svc.getGroupLeaderboard(
        _selectedGroupId!,
        range: _range,
        metric: _metric,
      );
      if (!mounted) return;
      setState(() => _leaderboard = entries);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _error = e.message);
    } catch (_) {
      // silently fail
    } finally {
      if (mounted) setState(() => _isLoadingBoard = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final titleColor = StudyUi.title(widget.isDarkMode);
    final bodyColor = StudyUi.body(widget.isDarkMode);
    final accent = widget.controller.primaryColor;
    final hasLeaderboardAccess =
        widget.controller.isLoggedIn || UiReviewConfig.enabled;

    return RefreshIndicator(
      onRefresh:
          UiReviewConfig.enabled ? () async => _loadReviewData() : _loadData,
      child: StudyScreenBackground(
        isDarkMode: widget.isDarkMode,
        accent: StudyUi.pathWarm,
        child: ListView(
          key: const Key('page_leaderboard'),
          padding: const EdgeInsets.fromLTRB(22, 18, 22, 124),
          children: [
            StudyPathHero(
              isDarkMode: widget.isDarkMode,
              accent: StudyUi.pathWarm,
              badge: '共学反馈',
              title: '学习进度',
              subtitle: hasLeaderboardAccess
                  ? '每一次专注，都是进步的足迹；这里帮你回看学习节奏。'
                  : '登录后可查看个人学习记录、小组进度和学习记录趋势。',
              icon: Icons.auto_graph_rounded,
              steps: const ['专注', '复盘', '共学', '鼓励'],
              child: Row(
                children: [
                  Expanded(
                    child: StudyPathMetricPill(
                      label: '记录量',
                      value: '${_myScore?.totalPoints ?? 0}',
                      icon: Icons.edit_note_rounded,
                      color: StudyUi.pathWarm,
                      isDarkMode: widget.isDarkMode,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: StudyPathMetricPill(
                      label: '学习记录',
                      value: '${widget.controller.learningTraceEvents.length}',
                      icon: Icons.timeline_rounded,
                      color: StudyUi.secondary,
                      isDarkMode: widget.isDarkMode,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            if (!hasLeaderboardAccess)
              _buildLoginPrompt(bodyColor, titleColor, accent)
            else if (_isLoadingScore)
              const Padding(
                padding: EdgeInsets.only(top: 60),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_error != null)
              _buildErrorState(bodyColor, accent)
            else ...[
              if (_leaderboard.isNotEmpty) ...[
                _buildTopThreeCard(titleColor, bodyColor, accent),
                const SizedBox(height: 18),
              ],
              _buildScoreCard(titleColor, bodyColor, accent),
              const SizedBox(height: 20),
              _buildEvidenceRankCard(titleColor, bodyColor, accent),
              const SizedBox(height: 20),
              if (_groups.isNotEmpty) ...[
                _buildGroupSelector(titleColor, bodyColor, accent),
                const SizedBox(height: 14),
                _buildMetricSelector(accent),
                const SizedBox(height: 14),
                _buildLeaderboard(titleColor, bodyColor, accent),
              ] else
                _buildNoGroupHint(bodyColor, titleColor, accent),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildTopThreeCard(
    Color titleColor,
    Color bodyColor,
    Color accent,
  ) {
    final top = [..._leaderboard]..sort((a, b) => a.rank.compareTo(b.rank));
    final entries = top.take(3).toList();
    return StudyCard(
      padding: const EdgeInsets.all(18),
      borderColor: StudyUi.pathWarm.withValues(
        alpha: widget.isDarkMode ? 0.20 : 0.14,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              StudyGlassIconNode(
                icon: Icons.groups_rounded,
                accent: StudyUi.pathWarm,
                size: 38,
                iconSize: 18,
                isDarkMode: widget.isDarkMode,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  '同伴近况',
                  style: TextStyle(
                    color: titleColor,
                    fontSize: 18,
                    fontWeight: AppTypography.hero,
                  ),
                ),
              ),
              _LeaderboardActionPill(
                label: '刷新近况',
                icon: Icons.refresh_rounded,
                accent: accent,
                isDarkMode: widget.isDarkMode,
                onTap: () => unawaited(_loadLeaderboard()),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              for (var i = 0; i < entries.length; i++) ...[
                Expanded(
                  child: _podiumTile(
                    entries[i],
                    titleColor,
                    bodyColor,
                    false,
                  ),
                ),
                if (i != entries.length - 1) const SizedBox(width: 10),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _podiumTile(
    LeaderboardEntry entry,
    Color titleColor,
    Color bodyColor,
    bool highlighted,
  ) {
    const rankColor = StudyUi.pathWarm;
    return Container(
      padding: EdgeInsets.fromLTRB(10, highlighted ? 16 : 12, 10, 12),
      decoration: BoxDecoration(
        color: StudyUi.chipBackground(rankColor, widget.isDarkMode),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: rankColor.withValues(alpha: 0.18)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          StudyGlassIconNode(
            icon: Icons.person_rounded,
            accent: rankColor,
            size: highlighted ? 46 : 40,
            iconSize: highlighted ? 21 : 18,
            isDarkMode: widget.isDarkMode,
          ),
          const SizedBox(height: 10),
          Text(
            entry.username ?? '同学',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: titleColor,
              fontSize: highlighted ? 15 : 13,
              fontWeight: AppTypography.hero,
            ),
          ),
          const SizedBox(height: 6),
          BadgePill(
            label: '${entry.points}${_metric == 'points' ? '条' : '项'}',
            background: StudyUi.surface(widget.isDarkMode),
            foreground: rankColor,
          ),
        ],
      ),
    );
  }

  Widget _buildEvidenceRankCard(
    Color titleColor,
    Color bodyColor,
    Color accent,
  ) {
    final events = widget.controller.learningTraceEvents;
    final aiEvents = events.where((event) => event.isAiGenerated).length;
    final evidencePackages = events
        .map((event) =>
            event.courseName.trim().isEmpty ? '未归课程' : event.courseName.trim())
        .toSet()
        .length;
    final reviewEvents = events
        .where((event) =>
            event.typeLabel.contains('记录') ||
            event.typeLabel.contains('笔记') ||
            event.typeLabel.contains('闪卡'))
        .length;
    return StudyCard(
      padding: const EdgeInsets.all(18),
      borderColor: accent.withValues(alpha: widget.isDarkMode ? 0.22 : 0.12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              StudyGlassIconNode(
                asset: AppAssets.featureGroupRankIcon,
                accent: accent,
                size: 42,
                iconSize: 22,
                isDarkMode: widget.isDarkMode,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '学习节奏维度',
                      style: TextStyle(
                        color: titleColor,
                        fontWeight: AppTypography.title,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '不只看数量，也看哪些学习过程可以回看。',
                      style: TextStyle(color: bodyColor, fontSize: 12),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              _EvidenceMetric(
                label: '学习记录',
                value: '${events.length}',
                accent: accent,
                isDarkMode: widget.isDarkMode,
              ),
              const SizedBox(width: 8),
              _EvidenceMetric(
                label: '整理次数',
                value: '$aiEvents',
                accent: const Color(0xFF0EA5E9),
                isDarkMode: widget.isDarkMode,
              ),
              const SizedBox(width: 8),
              _EvidenceMetric(
                label: '学习回顾',
                value: '$evidencePackages',
                accent: const Color(0xFFF59E0B),
                isDarkMode: widget.isDarkMode,
              ),
              const SizedBox(width: 8),
              _EvidenceMetric(
                label: '复盘沉淀',
                value: '$reviewEvents',
                accent: const Color(0xFF19A974),
                isDarkMode: widget.isDarkMode,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLoginPrompt(Color bodyColor, Color titleColor, Color accent) {
    return const StudyEmptyState(
      asset: AppAssets.uiRefreshFeatureRank,
      title: '本机进度会先保留',
      message: '登录后可以同步多端学习记录，并查看小组复盘空间里的学习近况。',
    );
  }

  Widget _buildErrorState(Color bodyColor, Color accent) {
    return StudyCard(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 32),
      child: Column(
        children: [
          StudyGlassIconNode(
            icon: Icons.cloud_off_rounded,
            accent: accent,
            size: 54,
            iconSize: 26,
            isDarkMode: widget.isDarkMode,
          ),
          const SizedBox(height: 16),
          Text(
            _error!,
            textAlign: TextAlign.center,
            style: TextStyle(color: bodyColor, fontSize: 14, height: 1.5),
          ),
          const SizedBox(height: 16),
          _LeaderboardActionPill(
            label: '重新加载',
            icon: Icons.refresh_rounded,
            accent: accent,
            isDarkMode: widget.isDarkMode,
            onTap: _loadData,
          ),
        ],
      ),
    );
  }

  Widget _buildScoreCard(Color titleColor, Color bodyColor, Color accent) {
    final score = _myScore;
    return StudyCard(
      padding: const EdgeInsets.all(20),
      borderColor: accent.withValues(alpha: widget.isDarkMode ? 0.24 : 0.18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '我的学习记录量',
            style: TextStyle(
              color: bodyColor,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '${score?.totalPoints ?? 0}',
            style: TextStyle(
              color: titleColor,
              fontSize: 36,
              fontWeight: AppTypography.hero,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              _scoreChip('今日', score?.todayPoints ?? 0, accent),
              const SizedBox(width: 10),
              _scoreChip('本周', score?.weekPoints ?? 0, accent),
              const SizedBox(width: 10),
              _scoreChip('本月', score?.monthPoints ?? 0, accent),
            ],
          ),
        ],
      ),
    );
  }

  Widget _scoreChip(String label, int value, Color accent) {
    return Expanded(
      child: StudyPathMetricPill(
        label: label,
        value: '$value',
        color: accent,
        isDarkMode: widget.isDarkMode,
      ),
    );
  }

  Widget _buildGroupSelector(
      Color titleColor, Color bodyColor, Color accent) {
    var selectedGroupName = '选择学习小组';
    for (final group in _groups) {
      if (group.id == _selectedGroupId) {
        selectedGroupName = group.name;
        break;
      }
    }
    return Row(
      children: [
        Expanded(
          child: Container(
            decoration: BoxDecoration(
              color: widget.isDarkMode
                  ? Colors.white.withValues(alpha: 0.07)
                  : Colors.white.withValues(alpha: 0.74),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: accent.withValues(alpha: widget.isDarkMode ? 0.18 : 0.14),
              ),
              boxShadow: widget.isDarkMode
                  ? null
                  : [
                      BoxShadow(
                        color: accent.withValues(alpha: 0.08),
                        blurRadius: 18,
                        offset: const Offset(0, 8),
                      ),
                    ],
            ),
            child: StudyPopupMenuButton<String>(
              tooltip: '选择小组',
              onSelected: (value) {
                if (_selectedGroupId == value) return;
                setState(() {
                  _selectedGroupId = value;
                  _leaderboard = [];
                });
                unawaited(_loadLeaderboard());
              },
              itemBuilder: (context) => _groups
                  .map((group) => PopupMenuItem<String>(
                        value: group.id,
                        child: Text(
                          group.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ))
                  .toList(),
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                child: Row(
                  children: [
                    StudyGlassIconNode(
                      icon: Icons.groups_rounded,
                      accent: accent,
                      size: 28,
                      iconSize: 15,
                      isDarkMode: widget.isDarkMode,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        selectedGroupName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: titleColor,
                          fontSize: 14,
                          fontWeight: AppTypography.title,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Icon(
                      Icons.keyboard_arrow_down_rounded,
                      color: accent,
                      size: 20,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),
        _rangeToggle(accent),
      ],
    );
  }

  Widget _rangeToggle(Color accent) {
    return Container(
      decoration: BoxDecoration(
        color: widget.isDarkMode
            ? Colors.white.withValues(alpha: 0.07)
            : Colors.white.withValues(alpha: 0.74),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: accent.withValues(alpha: widget.isDarkMode ? 0.18 : 0.14),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _rangeBtn('周', 'week', accent),
          _rangeBtn('月', 'month', accent),
        ],
      ),
    );
  }

  Widget _buildMetricSelector(Color accent) {
    const metrics = <String, String>{
      'points': '记录量',
      'loops': '整理次数',
      'review': '复习回看',
      'evidencePackages': '学习回顾',
      'challengeEvidence': '共学记录',
      'streak': '连续学习',
    };
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: metrics.entries
          .map((entry) => _metricChip(entry.key, entry.value, accent))
          .toList(),
    );
  }

  Widget _metricChip(String value, String label, Color accent) {
    final selected = _metric == value;
    return GestureDetector(
      onTap: () {
        if (_metric == value) return;
        setState(() {
          _metric = value;
          _leaderboard = [];
        });
        unawaited(_loadLeaderboard());
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        decoration: BoxDecoration(
          color: selected
              ? StudyUi.chipBackground(accent, widget.isDarkMode)
              : (widget.isDarkMode
                  ? Colors.white.withValues(alpha: 0.06)
                  : Colors.white.withValues(alpha: 0.76)),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: selected
                ? accent.withValues(alpha: widget.isDarkMode ? 0.36 : 0.24)
                : (widget.isDarkMode
                    ? Colors.white.withValues(alpha: 0.10)
                    : StudyUi.border(widget.isDarkMode)),
          ),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: accent.withValues(alpha: 0.20),
                    blurRadius: 16,
                    offset: const Offset(0, 8),
                  ),
                ]
              : null,
        ),
        child: Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: selected ? accent : StudyUi.body(widget.isDarkMode),
            fontSize: 13,
            fontWeight: AppTypography.title,
          ),
        ),
      ),
    );
  }

  Widget _rangeBtn(String label, String value, Color accent) {
    final selected = _range == value;
    return GestureDetector(
      onTap: () {
        if (_range == value) return;
        setState(() {
          _range = value;
          _leaderboard = [];
        });
        unawaited(_loadLeaderboard());
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: selected
              ? StudyUi.chipBackground(accent, widget.isDarkMode)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected
                ? accent.withValues(alpha: widget.isDarkMode ? 0.34 : 0.22)
                : Colors.transparent,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? accent : StudyUi.body(widget.isDarkMode),
            fontSize: 13,
            fontWeight: AppTypography.title,
          ),
        ),
      ),
    );
  }

  Widget _buildLeaderboard(
      Color titleColor, Color bodyColor, Color accent) {
    if (_isLoadingBoard) {
      return const Padding(
        padding: EdgeInsets.all(24),
        child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
      );
    }
    if (_leaderboard.isEmpty) {
      return _LeaderboardEmptyActionCard(
        isDarkMode: widget.isDarkMode,
        accent: accent,
        title: '还没有学习近况',
        message: '选择同伴小组和学习节奏后，学习记录会在这里形成可回看的近况。',
        primaryLabel: '留下学习记录',
        primaryIcon: Icons.edit_note_rounded,
        onPrimaryPressed: widget.onOpenLearningMoments,
        secondaryLabel: '打开同伴学习',
        secondaryIcon: Icons.groups_rounded,
        onSecondaryPressed: widget.onOpenStudyGroup,
      );
    }

    return Column(
      children: _leaderboard.map((entry) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: StudyCard(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            borderColor: StudyUi.border(widget.isDarkMode),
            child: Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: StudyUi.chipBackground(
                      StudyUi.pathWarm,
                      widget.isDarkMode,
                    ),
                  ),
                  child: Icon(
                    Icons.auto_stories_rounded,
                    color: StudyUi.pathWarm,
                    size: 17,
                  ),
                ),
                const SizedBox(width: 12),
                Container(
                  width: 38,
                  height: 38,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: StudyUi.chipBackground(accent, widget.isDarkMode),
                    border: Border.all(
                      color: accent.withValues(
                        alpha: widget.isDarkMode ? 0.28 : 0.18,
                      ),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: accent.withValues(alpha: 0.12),
                        blurRadius: 14,
                        offset: const Offset(0, 7),
                      ),
                    ],
                  ),
                  child: Text(
                    (entry.username ?? '?').isNotEmpty
                        ? (entry.username ?? '?')[0].toUpperCase()
                        : '?',
                    style: TextStyle(
                      color: accent,
                      fontWeight: AppTypography.hero,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    entry.username ?? '学习伙伴',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: titleColor,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                SizedBox(
                  width: 56,
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerRight,
                    child: Text(
                      '${entry.points}',
                      style: TextStyle(
                        color: accent,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                Text(
                  _metric == 'points'
                      ? '条'
                      : _metric == 'streak'
                          ? '天'
                          : '项',
                  style: TextStyle(color: bodyColor, fontSize: 12),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildNoGroupHint(Color bodyColor, Color titleColor, Color accent) {
    return _LeaderboardEmptyActionCard(
      isDarkMode: widget.isDarkMode,
      accent: accent,
      title: '加入同伴小组后可查看近况',
      message: '创建或加入同伴小组后，就能在这里回看组内学习节奏。',
      primaryLabel: '打开同伴学习',
      primaryIcon: Icons.groups_rounded,
      onPrimaryPressed: widget.onOpenStudyGroup,
      secondaryLabel: '留下学习记录',
      secondaryIcon: Icons.edit_note_rounded,
      onSecondaryPressed: widget.onOpenLearningMoments,
    );
  }
}

class _LeaderboardEmptyActionCard extends StatelessWidget {
  const _LeaderboardEmptyActionCard({
    required this.isDarkMode,
    required this.accent,
    required this.title,
    required this.message,
    required this.primaryLabel,
    required this.primaryIcon,
    required this.onPrimaryPressed,
    this.secondaryLabel,
    this.secondaryIcon,
    this.onSecondaryPressed,
  });

  final bool isDarkMode;
  final Color accent;
  final String title;
  final String message;
  final String primaryLabel;
  final IconData primaryIcon;
  final VoidCallback? onPrimaryPressed;
  final String? secondaryLabel;
  final IconData? secondaryIcon;
  final VoidCallback? onSecondaryPressed;

  @override
  Widget build(BuildContext context) {
    final hasPrimaryAction = onPrimaryPressed != null;
    final hasSecondaryAction = secondaryLabel != null &&
        secondaryIcon != null &&
        onSecondaryPressed != null;
    return StudyCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          StudyEmptyState(
            asset: AppAssets.uiRefreshFeatureRank,
            title: title,
            message: message,
          ),
          if (hasPrimaryAction || hasSecondaryAction) ...[
            const SizedBox(height: 14),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                if (hasPrimaryAction)
                  _LeaderboardActionPill(
                    label: primaryLabel,
                    icon: primaryIcon,
                    accent: accent,
                    isDarkMode: isDarkMode,
                    onTap: onPrimaryPressed,
                  ),
                if (hasSecondaryAction)
                  _LeaderboardActionPill(
                    label: secondaryLabel!,
                    icon: secondaryIcon!,
                    accent: StudyUi.pathCyan,
                    isDarkMode: isDarkMode,
                    onTap: onSecondaryPressed,
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _EvidenceMetric extends StatelessWidget {
  const _EvidenceMetric({
    required this.label,
    required this.value,
    required this.accent,
    required this.isDarkMode,
  });

  final String label;
  final String value;
  final Color accent;
  final bool isDarkMode;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: StudyPathMetricPill(
        label: label,
        value: value,
        color: accent,
        isDarkMode: isDarkMode,
      ),
    );
  }
}

class _LeaderboardActionPill extends StatelessWidget {
  const _LeaderboardActionPill({
    required this.label,
    required this.icon,
    required this.accent,
    required this.isDarkMode,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final Color accent;
  final bool isDarkMode;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final disabled = onTap == null;
    final foreground = disabled ? StudyUi.muted(isDarkMode) : accent;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: onTap,
        child: Ink(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
          decoration: BoxDecoration(
            color: disabled
                ? StudyUi.surfaceAlt(isDarkMode)
                : StudyUi.chipBackground(accent, isDarkMode),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: disabled
                  ? StudyUi.border(isDarkMode)
                  : accent.withValues(alpha: isDarkMode ? 0.34 : 0.22),
            ),
            boxShadow: disabled || isDarkMode
                ? null
                : [
                    BoxShadow(
                      color: accent.withValues(alpha: 0.12),
                      blurRadius: 18,
                      offset: const Offset(0, 9),
                    ),
                  ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 16, color: foreground),
              const SizedBox(width: 7),
              Text(
                label,
                style: TextStyle(
                  color: foreground,
                  fontSize: 13,
                  fontWeight: AppTypography.title,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
