import 'dart:async';

import 'package:flutter/material.dart';

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
  });

  final bool isDarkMode;
  final AppDataController controller;

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
    unawaited(_loadData());
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
    final titleColor = widget.isDarkMode ? Colors.white : Colors.black;
    final bodyColor =
        widget.isDarkMode ? const Color(0xFFC2C8D6) : AppColors.body;
    final accent = widget.controller.primaryColor;

    return RefreshIndicator(
      onRefresh: _loadData,
      child: ListView(
        key: const Key('page_leaderboard'),
        padding: const EdgeInsets.fromLTRB(22, 94, 22, 124),
        children: [
          Text(
            '排行榜',
            style: TextStyle(
              color: titleColor,
              fontSize: 24,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            widget.controller.isLoggedIn
                ? '查看积分排名，激发学习动力'
                : '登录后可查看排行榜',
            style: TextStyle(color: bodyColor, fontSize: 14, height: 1.4),
          ),
          const SizedBox(height: 24),
          if (!widget.controller.isLoggedIn)
            _buildLoginPrompt(bodyColor, titleColor, accent)
          else if (_isLoadingScore)
            const Padding(
              padding: EdgeInsets.only(top: 60),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_error != null)
            _buildErrorState(bodyColor, accent)
          else ...[
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
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: widget.isDarkMode ? const Color(0xFF1E2128) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: accent.withValues(alpha: widget.isDarkMode ? 0.22 : 0.12),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              StudyAssetIcon(
                asset: AppAssets.featureGroupRankIcon,
                color: accent,
                size: 24,
                fallbackIcon: Icons.auto_graph_rounded,
              ),
              const SizedBox(width: 8),
              Text(
                '学习排行维度',
                style: TextStyle(
                  color: titleColor,
                  fontWeight: FontWeight.w800,
                  fontSize: 16,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            '不只比较积分，也比较真实学习过程是否可追溯。',
            style: TextStyle(color: bodyColor, fontSize: 12),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              _EvidenceMetric(
                label: '学习轨迹',
                value: '${events.length}',
                accent: accent,
                bodyColor: bodyColor,
              ),
              const SizedBox(width: 8),
              _EvidenceMetric(
                label: '学习复盘',
                value: '$aiEvents',
                accent: const Color(0xFF0EA5E9),
                bodyColor: bodyColor,
              ),
              const SizedBox(width: 8),
              _EvidenceMetric(
                label: '成果包',
                value: '$evidencePackages',
                accent: const Color(0xFFF59E0B),
                bodyColor: bodyColor,
              ),
              const SizedBox(width: 8),
              _EvidenceMetric(
                label: '复盘沉淀',
                value: '$reviewEvents',
                accent: const Color(0xFF19A974),
                bodyColor: bodyColor,
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
      title: '登录后查看排名',
      message: '个人积分、小组排名和学习记录排行会显示在这里。',
    );
  }

  Widget _buildErrorState(Color bodyColor, Color accent) {
    return StudyCard(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 32),
      child: Column(
        children: [
          Icon(Icons.cloud_off_rounded,
              size: 48, color: accent.withValues(alpha: 0.5)),
          const SizedBox(height: 16),
          Text(_error!, style: TextStyle(color: bodyColor, fontSize: 14)),
          const SizedBox(height: 16),
          TextButton(onPressed: _loadData, child: const Text('重试')),
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
            '我的积分',
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
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              _scoreChip('今日', score?.todayPoints ?? 0, accent, bodyColor),
              const SizedBox(width: 10),
              _scoreChip('本周', score?.weekPoints ?? 0, accent, bodyColor),
              const SizedBox(width: 10),
              _scoreChip('本月', score?.monthPoints ?? 0, accent, bodyColor),
            ],
          ),
        ],
      ),
    );
  }

  Widget _scoreChip(String label, int value, Color accent, Color bodyColor) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: StudyUi.chipBackground(accent, widget.isDarkMode),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Text(
              '$value',
              style: TextStyle(
                color: accent,
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                color: bodyColor,
                fontSize: 11,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGroupSelector(
      Color titleColor, Color bodyColor, Color accent) {
    return Row(
      children: [
        Expanded(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            decoration: BoxDecoration(
              color: widget.isDarkMode
                  ? Colors.white.withValues(alpha: 0.06)
                  : const Color(0xFFF2F5FC),
              borderRadius: BorderRadius.circular(14),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: _selectedGroupId,
                isExpanded: true,
                dropdownColor: widget.isDarkMode
                    ? const Color(0xFF1E2128)
                    : Colors.white,
                style: TextStyle(
                  color: titleColor,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
                items: _groups
                    .map((g) => DropdownMenuItem(
                          value: g.id,
                          child: Text(
                            g.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ))
                    .toList(),
                onChanged: (v) {
                  if (v == null) return;
                  setState(() {
                    _selectedGroupId = v;
                    _leaderboard = [];
                  });
                  unawaited(_loadLeaderboard());
                },
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
            ? Colors.white.withValues(alpha: 0.06)
            : const Color(0xFFF2F5FC),
        borderRadius: BorderRadius.circular(14),
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
      'points': '积分',
      'loops': '学习复盘',
      'review': '复盘',
      'evidencePackages': '成果包',
      'challengeEvidence': '挑战记录',
      'streak': '连续学习',
    };
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: SegmentedButton<String>(
        segments: metrics.entries
            .map((entry) => ButtonSegment<String>(
                  value: entry.key,
                  label: Text(entry.value),
                ))
            .toList(),
        selected: {_metric},
        onSelectionChanged: (values) {
          final value = values.first;
          if (_metric == value) return;
          setState(() {
            _metric = value;
            _leaderboard = [];
          });
          unawaited(_loadLeaderboard());
        },
        showSelectedIcon: false,
        style: SegmentedButton.styleFrom(
          selectedBackgroundColor: accent,
          selectedForegroundColor: Colors.white,
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
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? accent : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected
                ? Colors.white
                : (widget.isDarkMode ? Colors.white70 : AppColors.ink),
            fontSize: 13,
            fontWeight: FontWeight.w600,
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
      return Container(
        padding: const EdgeInsets.symmetric(vertical: 32),
        alignment: Alignment.center,
        child: Text('暂无排名数据',
            style: TextStyle(color: bodyColor, fontSize: 14)),
      );
    }

    return Column(
      children: _leaderboard.map((entry) {
        final isMe = entry.rank <= 3;
        final medalColor = entry.rank == 1
            ? const Color(0xFFFFD700)
            : entry.rank == 2
                ? const Color(0xFFC0C0C0)
                : entry.rank == 3
                    ? const Color(0xFFCD7F32)
                    : null;

        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: widget.isDarkMode ? const Color(0xFF1E2128) : Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: medalColor != null
                ? Border.all(color: medalColor.withValues(alpha: 0.3), width: 1.5)
                : null,
          ),
          child: Row(
            children: [
              SizedBox(
                width: 32,
                child: medalColor != null
                    ? Icon(Icons.emoji_events_rounded,
                        color: medalColor, size: 22)
                    : Text(
                        '${entry.rank}',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: bodyColor,
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
              ),
              const SizedBox(width: 12),
              CircleAvatar(
                radius: 18,
                backgroundColor:
                    accent.withValues(alpha: 0.12),
                child: Text(
                  (entry.username ?? '?').isNotEmpty
                      ? (entry.username ?? '?')[0].toUpperCase()
                      : '?',
                  style: TextStyle(
                    color: accent,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  entry.username ?? '未知用户',
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
              Text(_metric == 'points' ? '分' : '项',
                  style: TextStyle(color: bodyColor, fontSize: 12)),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildNoGroupHint(Color bodyColor, Color titleColor, Color accent) {
    return const StudyEmptyState(
      asset: AppAssets.uiRefreshFeatureRank,
      title: '加入小组后可查看排名',
      message: '前往学习小组页面创建或加入小组，再回来查看组内学习排行。',
    );
  }
}

class _EvidenceMetric extends StatelessWidget {
  const _EvidenceMetric({
    required this.label,
    required this.value,
    required this.accent,
    required this.bodyColor,
  });

  final String label;
  final String value;
  final Color accent;
  final Color bodyColor;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
        decoration: BoxDecoration(
          color: accent.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: double.infinity,
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  value,
                  style: TextStyle(
                    color: accent,
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: bodyColor, fontSize: 10),
            ),
          ],
        ),
      ),
    );
  }
}
