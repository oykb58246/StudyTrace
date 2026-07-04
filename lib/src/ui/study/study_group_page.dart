import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../config/ui_review_config.dart';
import '../../controllers/app_data_controller.dart';
import '../../models/community_evidence.dart';
import '../../models/learning_moment.dart';
import '../../services/activity_service.dart';
import '../../services/api_client.dart';
import '../../services/group_service.dart';
import '../../theme/app_theme.dart';
import '../shared/app_assets.dart';
import '../shared/common_widgets.dart';

class StudyGroupPage extends StatefulWidget {
  const StudyGroupPage({
    super.key,
    required this.isDarkMode,
    required this.controller,
  });

  final bool isDarkMode;
  final AppDataController controller;

  @override
  State<StudyGroupPage> createState() => _StudyGroupPageState();
}

class _StudyGroupPageState extends State<StudyGroupPage> {
  List<GroupInfo> _groups = [];
  bool _isLoading = false;
  bool _isGeneratingChallenge = false;
  String _challengeText = '';
  List<GroupChallenge> _challenges = [];
  String? _error;

  @override
  void initState() {
    super.initState();
    if (UiReviewConfig.enabled) {
      _loadReviewGroups();
    } else {
      unawaited(_loadGroups());
    }
  }

  void _loadReviewGroups() {
    final now = DateTime.now();
    setState(() {
      _groups = [
        GroupInfo(
          id: 'review_group_math',
          name: '高数复盘小组',
          description: '围绕极限、洛必达和错题复盘推进。',
          inviteCode: 'REVIEW24',
          memberCount: 6,
          role: 'owner',
          joinedAt: now.subtract(const Duration(days: 9)),
        ),
        GroupInfo(
          id: 'review_group_algo',
          name: '算法可视化共学组',
          description: '把一周算法学习整理成清楚的图解和复盘。',
          inviteCode: 'ALGO66',
          memberCount: 4,
          role: 'member',
          joinedAt: now.subtract(const Duration(days: 5)),
        ),
      ];
      _challenges = [
        GroupChallenge(
          id: 'review_challenge_lhopital',
          groupId: 'review_group_math',
          title: '7 天洛必达条件小组回顾',
          description: '每天保存学习记录或错题复盘，最后形成可回看的条件判断表。',
          participantCount: 5,
          evidenceCount: 18,
          createdAt: now.subtract(const Duration(days: 2)),
        ),
        GroupChallenge(
          id: 'review_challenge_algo_review',
          groupId: 'review_group_algo',
          title: '算法图解小组回顾',
          description: '把本周算法学习整理成复盘、行动、专注、复习、回顾五步。',
          participantCount: 4,
          evidenceCount: 11,
          createdAt: now.subtract(const Duration(days: 1)),
        ),
      ];
      _challengeText =
          '本周小组回顾：每天留下 1 个小学习动作，优先整理复盘、错题和闪卡记录，周末一起回看路径变化。';
      _isLoading = false;
      _error = null;
    });
  }

  List<GroupMember> _reviewMembersFor(GroupInfo group) {
    final now = DateTime.now();
    final isAlgo = group.id.contains('algo');
    final names = isAlgo
        ? const ['林同学', '赵同学', '沈同学', '复盘搭子']
        : const ['王同学', '陈同学', '林同学', '周同学', '何同学', '赵同学'];
    final count = group.memberCount > 0 && group.memberCount < names.length
        ? group.memberCount
        : names.length;
    return [
      for (var index = 0; index < count; index++)
        GroupMember(
          id: '${group.id}_member_$index',
          username: names[index],
          role: index == 0
              ? (group.role == 'owner' ? 'owner' : 'admin')
              : 'member',
          joinedAt: now.subtract(Duration(days: 9 - index)),
          profile: {'nickname': names[index]},
        ),
    ];
  }

  List<StudyActivity> _reviewActivitiesFor(GroupInfo group) {
    final now = DateTime.now();
    final isAlgo = group.id.contains('algo');
    final entries = isAlgo
        ? [
            (
              type: 'studyLogCreated',
              title: '压缩算法复盘路径',
              summary: '把复盘、任务和学迹串成一条可回看的学习线。',
              user: '林同学',
              minutes: 18,
            ),
            (
              type: 'timerCompleted',
              title: '完成 40 分钟图解整理',
              summary: '补齐题目背景、推导过程和复杂度小结。',
              user: '赵同学',
              minutes: 64,
            ),
            (
              type: 'noteCreated',
              title: '整理算法错题问答清单',
              summary: '把边界条件、反例和解题步骤拆成 6 个问题。',
              user: '沈同学',
              minutes: 132,
            ),
          ]
        : [
            (
              type: 'taskCompleted',
              title: '完成洛必达条件错题复盘',
              summary: '补齐“可导、极限型、邻域条件”三个判断点。',
              user: '王同学',
              minutes: 22,
            ),
            (
              type: 'flashcardBatchCreated',
              title: '整理 12 张极限判别闪卡',
              summary: '把易混条件做成正反例，周末一起抽查。',
              user: '陈同学',
              minutes: 78,
            ),
            (
              type: 'timerCompleted',
              title: '45 分钟专注推导不定式变形',
              summary: '记录了 3 个还需要回看的难点。',
              user: '林同学',
              minutes: 156,
            ),
          ];
    return [
      for (var index = 0; index < entries.length; index++)
        StudyActivity(
          id: '${group.id}_activity_$index',
          groupId: group.id,
          type: entries[index].type,
          title: entries[index].title,
          summary: entries[index].summary,
          happenedAt: now.subtract(Duration(minutes: entries[index].minutes)),
          user: {
            'username': entries[index].user,
            'profile': {'nickname': entries[index].user},
          },
        ),
    ];
  }

  Future<void> _loadGroups() async {
    if (!widget.controller.isLoggedIn) return;
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final svc = widget.controller.groupService;
      final groups = await svc.listMine();
      if (!mounted) return;
      setState(() => _groups = groups);
      if (groups.isNotEmpty) {
        List<GroupChallenge> challenges = const [];
        try {
          challenges =
              await widget.controller.communityEvidenceService.listChallenges(groups.first.id);
        } catch (_) {
          challenges = const [];
        }
        if (!mounted) return;
        setState(() => _challenges = challenges);
      } else {
        setState(() => _challenges = []);
      }
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _error = e.message);
    } catch (_) {
      if (!mounted) return;
      setState(() => _error = '加载失败，请稍后重试');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final titleColor = StudyUi.title(widget.isDarkMode);
    final bodyColor = StudyUi.body(widget.isDarkMode);
    final accent = widget.controller.primaryColor;
    final hasGroupAccess =
        widget.controller.isLoggedIn || UiReviewConfig.enabled;

    return RefreshIndicator(
      onRefresh:
          UiReviewConfig.enabled ? () async => _loadReviewGroups() : _loadGroups,
      child: StudyScreenBackground(
        isDarkMode: widget.isDarkMode,
        accent: StudyUi.pathMint,
        child: ListView(
          key: const Key('page_study_group'),
          padding: const EdgeInsets.fromLTRB(22, 18, 22, 124),
          children: [
            StudyPathHero(
              isDarkMode: widget.isDarkMode,
              accent: StudyUi.pathMint,
              badge: '同伴路径',
              title: '同伴学习',
              subtitle: hasGroupAccess
                  ? '一起学，更有动力；用计划、记录和同伴学迹看见彼此进步。'
                  : '登录后可以创建或加入学习小组，和同伴一起推进任务。',
              icon: Icons.groups_rounded,
              steps: const ['同伴', '计划', '记录', '回看'],
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: StudyPathMetricPill(
                          label: '我的小组',
                          value: '${_groups.length}',
                          icon: Icons.group_rounded,
                          color: StudyUi.pathMint,
                          isDarkMode: widget.isDarkMode,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: StudyPathMetricPill(
                          label: '小组回顾',
                          value: '${_challenges.length}',
                          icon: Icons.flag_rounded,
                          color: StudyUi.secondary,
                          isDarkMode: widget.isDarkMode,
                        ),
                      ),
                    ],
                  ),
                  if (hasGroupAccess) ...[
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: StudyStatusChip(
                            label: '创建小组',
                            color: StudyUi.pathMint,
                            selected: true,
                            icon: Icons.add_rounded,
                            onTap: _showCreateGroupSheet,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: StudyStatusChip(
                            label: '加入小组',
                            color: StudyUi.secondary,
                            selected: true,
                            icon: Icons.group_add_rounded,
                            onTap: _showJoinGroupSheet,
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 18),
            if (hasGroupAccess) ...[
              _buildChallengePanel(titleColor, bodyColor, accent),
              const SizedBox(height: 18),
            ],
            if (!hasGroupAccess)
              _buildLoginPrompt(bodyColor, titleColor, accent)
            else if (_isLoading)
              const Padding(
                padding: EdgeInsets.only(top: 60),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_error != null)
              _buildErrorState(bodyColor, accent)
            else if (_groups.isEmpty) ...[
              _buildEmptyState(),
              const SizedBox(height: 12),
              Center(
                child: _GroupActionPill(
                  label: '加入小组',
                  icon: Icons.group_add_rounded,
                  accent: accent,
                  isDarkMode: widget.isDarkMode,
                  onPressed: _showJoinGroupSheet,
                ),
              ),
            ]
            else
              ..._groups.map((g) => _buildGroupCard(g, titleColor, bodyColor, accent)),
          ],
        ),
      ),
    );
  }

  Widget _buildChallengePanel(
    Color titleColor,
    Color bodyColor,
    Color accent,
  ) {
    return StudyCard(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              StudyGlassIconNode(
                icon: Icons.flag_rounded,
                accent: accent,
                size: 42,
                iconSize: 20,
                isDarkMode: widget.isDarkMode,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '小组回顾',
                      style: TextStyle(
                        color: titleColor,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '把小组目标整理成每天能跟上的学习动作。',
                      style: TextStyle(color: bodyColor, fontSize: 12),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (_challengeText.trim().isNotEmpty)
            SizedBox(
              width: double.infinity,
              child: StudyCard(
                padding: const EdgeInsets.all(12),
                color: StudyUi.chipBackground(accent, widget.isDarkMode),
                borderColor: accent.withValues(alpha: 0.16),
                child: Text(
                  _challengeText,
                  style: TextStyle(color: titleColor, height: 1.45),
                ),
              ),
            )
          else
            Text(
              '会基于当前课程、任务和学习记录整理出 3-7 天计划；成员完成任务、番茄钟或学迹后进入组内近况与学习进度。',
              style: TextStyle(color: bodyColor, fontSize: 13, height: 1.45),
            ),
          if (_challenges.isNotEmpty) ...[
            const SizedBox(height: 12),
            LayoutBuilder(
              builder: (context, constraints) {
                const spacing = 10.0;
                final useTwoColumns = constraints.maxWidth >= 500;
                final itemWidth = useTwoColumns
                    ? (constraints.maxWidth - spacing) / 2
                    : constraints.maxWidth;
                return Wrap(
                  spacing: spacing,
                  runSpacing: 10,
                  children: [
                    ..._challenges.take(2).map(
                          (challenge) => SizedBox(
                            width: itemWidth,
                            child: _buildChallengeCard(
                              challenge,
                              titleColor,
                              bodyColor,
                              accent,
                            ),
                          ),
                        ),
                  ],
                );
              },
            ),
          ],
          const SizedBox(height: 12),
          _GroupActionPill(
            label: _groups.isEmpty
                ? '先创建或加入小组'
                : (_isGeneratingChallenge ? '整理中...' : '创建小组回顾'),
            icon: _groups.isEmpty ? Icons.group_add_rounded : Icons.flag_rounded,
            accent: accent,
            isDarkMode: widget.isDarkMode,
            busy: _isGeneratingChallenge,
            fullWidth: true,
            onPressed: _isGeneratingChallenge
                ? null
                : (_groups.isEmpty ? _showJoinGroupSheet : _generateChallenge),
          ),
        ],
      ),
    );
  }

  Widget _buildChallengeCard(
    GroupChallenge challenge,
    Color titleColor,
    Color bodyColor,
    Color accent,
  ) {
    return StudyCard(
      padding: const EdgeInsets.all(12),
      borderColor: accent.withValues(alpha: 0.16),
      color: StudyUi.surfaceAlt(widget.isDarkMode),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            challenge.title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: titleColor,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '${challenge.participantCount} 人共学 · ${challenge.evidenceCount} 条学习记录',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(color: bodyColor, fontSize: 12),
          ),
          if ((challenge.coverImageUrl ?? '').startsWith('vivo-task:')) ...[
            const SizedBox(height: 4),
            Text(
              '封面整理中，稍后刷新查看',
              style: TextStyle(color: bodyColor, fontSize: 11),
            ),
          ],
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _GroupActionPill(
                label: '跟进计划',
                icon: Icons.add_rounded,
                accent: accent,
                isDarkMode: widget.isDarkMode,
                filled: false,
                onPressed: () => _joinChallenge(challenge),
              ),
              _GroupActionPill(
                label: '保存到回顾',
                icon: Icons.upload_rounded,
                accent: accent,
                isDarkMode: widget.isDarkMode,
                onPressed: () => _submitLatestEvidence(challenge),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _generateChallenge() async {
    if (_isGeneratingChallenge) return;
    if (_groups.isEmpty) {
      StudyToast.show(context, '请先创建或加入一个学习小组');
      return;
    }
    setState(() => _isGeneratingChallenge = true);
    final courses = widget.controller.courseNames.take(6).join('、');
    final pending = widget.controller.studyTasks
        .where((task) => task.effectiveStatus.name != 'completed')
        .take(8)
        .map((task) => '${task.title}（${task.courseName}）')
        .join('；');
    final evidenceCount = widget.controller.learningTraceEvents.length;
    try {
      final group = _groups.first;
      final text = await widget.controller.communityEvidenceService.draftChallenge(
        group.id,
        context: [
          '课程：$courses',
          '待办：$pending',
          '已有学习记录：$evidenceCount 条',
        ],
      );
      String? coverImageUrl;
      try {
        final cover = await widget.controller.vivoCapabilityService.createCover(
          prompt: '为学习小组回顾制作清晰、积极、适合回看的封面。回顾内容：${text.trim()}',
          purpose: 'challenge_cover',
        );
        coverImageUrl = cover.imagesUrl.isNotEmpty
            ? cover.imagesUrl.first
            : 'vivo-task:${cover.taskId}';
        unawaited(
          widget.controller.activityService
              .create(
                type: 'imageGenerated',
                title: cover.imagesUrl.isNotEmpty ? '小组计划封面已生成' : '小组计划封面整理中',
                summary: group.name,
                groupId: group.id,
                sourceType: 'group_challenge_cover',
                sourceId: cover.taskId,
                payloadJson: {
                  'taskId': cover.taskId,
                  'imageUrl': cover.imagesUrl.isNotEmpty ? cover.imagesUrl.first : '',
                  'purpose': 'challenge_cover',
                },
              )
              .catchError((_) {}),
        );
      } catch (_) {
        coverImageUrl = null;
      }
      final saved = await widget.controller.communityEvidenceService.createChallenge(
        groupId: group.id,
        title: '${group.name} 小组回顾',
        description: text.trim(),
        planJson: {'draftText': text.trim(), 'durationDays': 7},
        scoringJson: const {
          'task': 10,
          'focus': 5,
          'review': 5,
          'learningTrace': 8,
        },
        coverImageUrl: coverImageUrl,
      );
      if (!mounted) return;
      setState(() {
        _challengeText = text.trim();
        _challenges.insert(0, saved);
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _challengeText = '7 天小组回顾：每天完成 1 个可完成行动，'
            '如保存学习日志、完成番茄钟、沉淀笔记或留下学迹；'
            '周末一起回看哪些方法有帮助、下一步从哪里继续。';
      });
    } finally {
      if (mounted) setState(() => _isGeneratingChallenge = false);
    }
  }

  Future<void> _joinChallenge(GroupChallenge challenge) async {
    try {
      await widget.controller.communityEvidenceService
          .joinChallenge(challenge.groupId, challenge.id);
      if (!mounted) return;
      StudyToast.show(context, '已加入小组回顾');
      await _loadGroups();
    } catch (_) {
      if (!mounted) return;
      await StudyToast.dialog(
        context,
        title: '加入小组回顾失败',
        message: '请稍后重试。',
      );
    }
  }

  Future<void> _submitLatestEvidence(GroupChallenge challenge) async {
    final events = widget.controller.learningTraceEvents
        .where((event) => event.isShareable)
        .toList();
    if (events.isEmpty) {
      StudyToast.show(context, '请先保存一次复盘、专注或闪卡复习，再加入小组回顾');
      return;
    }
    final event = events.first;
    final group = _groupFor(challenge.groupId);
    final groupName = group?.name.trim().isNotEmpty == true
        ? group!.name.trim()
        : '当前学习小组';
    final confirmed = await _confirmChallengeSubmission(
      event: event,
      challenge: challenge,
      groupName: groupName,
    );
    if (!confirmed || !mounted) return;
    try {
      await widget.controller.communityEvidenceService.submitEvidence(
        groupId: challenge.groupId,
        challengeId: challenge.id,
        evidenceType: event.type.name,
        title: event.title,
        summary: event.summary,
        sourceType: event.type.name,
        sourceId: event.sourceId,
        payloadJson: {
          'visibility': 'groupChallenge',
          'groupName': groupName,
          'challengeTitle': challenge.title,
          'eventId': event.id,
        },
      );
      if (!mounted) return;
      StudyToast.show(context, '学习记录已保存到小组回顾');
      await _loadGroups();
    } catch (_) {
      if (!mounted) return;
      await StudyToast.dialog(
        context,
        title: '保存到回顾失败',
        message: '请稍后重试。',
      );
    }
  }

  GroupInfo? _groupFor(String groupId) {
    for (final group in _groups) {
      if (group.id == groupId) return group;
    }
    return null;
  }

  Future<bool> _confirmChallengeSubmission({
    required LearningTraceEvent event,
    required GroupChallenge challenge,
    required String groupName,
  }) async {
    final titleColor = widget.isDarkMode ? Colors.white : AppColors.ink;
    final bodyColor =
        widget.isDarkMode ? const Color(0xFFC2C8D6) : AppColors.body;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => _GroupDialogSurface(
        isDarkMode: widget.isDarkMode,
        icon: Icons.upload_rounded,
        accent: widget.controller.primaryColor,
        title: '把记录保存到小组回顾？',
        subtitle: '这条学习记录会进入小组一起回看的学习线。',
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '这条记录会保存到「$groupName」的「${challenge.title}」，小组成员可以看到。',
              style: TextStyle(color: bodyColor, height: 1.45),
            ),
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: StudyUi.surfaceAlt(widget.isDarkMode),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: StudyUi.border(widget.isDarkMode)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    event.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: titleColor,
                      fontWeight: AppTypography.title,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    [
                      event.typeLabel,
                      _relativeTime(event.happenedAt),
                      if (event.summary.trim().isNotEmpty)
                        _clip(event.summary.trim(), 72),
                    ].join(' · '),
                    style: TextStyle(color: bodyColor, height: 1.35),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _GroupActionPill(
                    label: '取消',
                    icon: Icons.close_rounded,
                    accent: StudyUi.muted(widget.isDarkMode),
                    isDarkMode: widget.isDarkMode,
                    filled: false,
                    fullWidth: true,
                    onPressed: () => Navigator.of(ctx).pop(false),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _GroupActionPill(
                    label: '保存到共学回看',
                    icon: Icons.upload_rounded,
                    accent: widget.controller.primaryColor,
                    isDarkMode: widget.isDarkMode,
                    fullWidth: true,
                    onPressed: () => Navigator.of(ctx).pop(true),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
    return confirmed == true;
  }

  String _clip(String value, int maxLength) {
    final trimmed = value.trim();
    if (trimmed.length <= maxLength) return trimmed;
    return '${trimmed.substring(0, maxLength)}...';
  }

  Widget _buildLoginPrompt(Color bodyColor, Color titleColor, Color accent) {
    return StudyCard(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 32),
      child: Column(
        children: [
          StudyAssetIcon(
            asset: AppAssets.uiRefreshEmptyGroup,
            size: 96,
            fallbackIcon: Icons.lock_rounded,
          ),
          const SizedBox(height: 16),
          Text(
            '登录后加入同学小组',
            style: TextStyle(
              color: titleColor,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '本机学习记录可以继续保存，登录后再同步到小组复盘空间。',
            style: TextStyle(color: bodyColor, fontSize: 13),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState(Color bodyColor, Color accent) {
    return StudyCard(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 32),
      child: Column(
        children: [
          StudyAssetIcon(
            asset: AppAssets.uiRefreshEmptyGroup,
            size: 96,
            fallbackIcon: Icons.cloud_off_rounded,
          ),
          const SizedBox(height: 16),
          Text(_error!, style: TextStyle(color: bodyColor, fontSize: 14)),
          const SizedBox(height: 16),
          _GroupActionPill(
            label: '重试',
            icon: Icons.refresh_rounded,
            accent: accent,
            isDarkMode: widget.isDarkMode,
            filled: false,
            onPressed: _loadGroups,
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return StudyEmptyState.group(
      actionLabel: '创建小组',
      onAction: _showCreateGroupSheet,
    );
  }

  Widget _buildGroupCard(
    GroupInfo group,
    Color titleColor,
    Color bodyColor,
    Color accent,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: StudyCard(
        padding: const EdgeInsets.all(18),
        onTap: () => _showGroupDetail(group),
        child: Row(
          children: [
            StudyGlassIconNode(
              asset: AppAssets.featureGroupRankIcon,
              icon: Icons.groups_rounded,
              accent: accent,
              size: 48,
              iconSize: 24,
              isDarkMode: widget.isDarkMode,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    group.name,
                    style: TextStyle(
                      color: titleColor,
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 3),
                  Text(
                    '${group.memberCount} 位成员${group.role != null ? ' · ${_roleName(group.role!)}' : ''}',
                    style: TextStyle(color: bodyColor, fontSize: 12),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: bodyColor, size: 22),
          ],
        ),
      ),
    );
  }

  String _roleName(String role) {
    switch (role) {
      case 'owner':
        return '创建者';
      case 'admin':
        return '管理员';
      default:
        return '成员';
    }
  }

  BoxDecoration _groupSheetDecoration() {
    final accent = widget.controller.primaryColor;
    final sheetBase = widget.isDarkMode
        ? const Color(0xFF17222C)
        : const Color(0xFFF9FCFF);
    final sheetGlow = widget.isDarkMode
        ? const Color(0xFF1F2F3A)
        : Color.alphaBlend(
            accent.withValues(alpha: 0.08),
            const Color(0xFFF8FBFF),
          );
    return BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          sheetBase,
          sheetGlow,
          sheetBase,
        ],
      ),
      borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
      border: Border(
        top: BorderSide(
          color: widget.isDarkMode
              ? Colors.white.withValues(alpha: 0.10)
              : Colors.white.withValues(alpha: 0.82),
        ),
      ),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: widget.isDarkMode ? 0.30 : 0.14),
          blurRadius: 30,
          offset: const Offset(0, -14),
        ),
      ],
    );
  }

  Widget _groupSheetSurface({required Widget child}) {
    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: Container(
          decoration: _groupSheetDecoration(),
          child: StudyFontScope(child: child),
        ),
      ),
    );
  }

  Widget _groupSheetHandle() {
    return Center(
      child: Container(
        width: 42,
        height: 4,
        decoration: BoxDecoration(
          color: widget.isDarkMode
              ? Colors.white.withValues(alpha: 0.20)
              : widget.controller.primaryColor.withValues(alpha: 0.22),
          borderRadius: BorderRadius.circular(999),
        ),
      ),
    );
  }

  Widget _groupSheetTitle({
    required String title,
    required String subtitle,
    required IconData icon,
  }) {
    final accent = widget.controller.primaryColor;
    return Row(
      children: [
        StudyGlassIconNode(
          icon: icon,
          accent: accent,
          size: 42,
          iconSize: 20,
          isDarkMode: widget.isDarkMode,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  color: StudyUi.title(widget.isDarkMode),
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                subtitle,
                style: TextStyle(
                  color: StudyUi.body(widget.isDarkMode),
                  fontSize: 12,
                  height: 1.35,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  InputDecoration _groupInputDecoration(String hintText) {
    return InputDecoration(
      hintText: hintText,
      hintStyle: TextStyle(
        color: StudyUi.body(widget.isDarkMode).withValues(alpha: 0.66),
      ),
      filled: true,
      fillColor: StudyUi.surface(widget.isDarkMode),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: StudyUi.border(widget.isDarkMode)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(
          color: widget.controller.primaryColor.withValues(alpha: 0.42),
          width: 1.2,
        ),
      ),
    );
  }

  // --- Bottom sheets ---

  void _showCreateGroupSheet() {
    final nameCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    bool isCreating = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) => Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom,
          ),
          child: _groupSheetSurface(
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(ctx).size.height * 0.82,
              ),
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(22, 18, 22, 34),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                _groupSheetHandle(),
                const SizedBox(height: 18),
                _groupSheetTitle(
                  title: '创建小组',
                  subtitle: '把同伴、任务和学习记录放进同一条共学路径。',
                  icon: Icons.group_add_rounded,
                ),
                const SizedBox(height: 18),
                TextField(
                  controller: nameCtrl,
                  style: TextStyle(
                      color: widget.isDarkMode ? Colors.white : AppColors.ink),
                  decoration: _groupInputDecoration('小组名称（必填）'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: descCtrl,
                  maxLines: 2,
                  style: TextStyle(
                      color: widget.isDarkMode ? Colors.white : AppColors.ink),
                  decoration: _groupInputDecoration('小组简介（选填）'),
                ),
                const SizedBox(height: 20),
                _GroupActionPill(
                  label: isCreating ? '创建中...' : '创建小组',
                  icon: Icons.add_rounded,
                  accent: widget.controller.primaryColor,
                  isDarkMode: widget.isDarkMode,
                  busy: isCreating,
                  fullWidth: true,
                  onPressed: isCreating
                      ? null
                      : () async {
                            final name = nameCtrl.text.trim();
                            if (name.isEmpty) return;
                            setSheetState(() => isCreating = true);
                            var shouldResetLoading = true;
                            try {
                              final svc = widget.controller.groupService;
                              final group = await svc.create(
                                name: name,
                                description: descCtrl.text.trim(),
                              );
                              if (mounted && ctx.mounted) {
                                shouldResetLoading = false;
                                Navigator.of(ctx).pop();
                                _loadGroups();
                                _showInviteCodeDialog(group);
                              }
                            } on ApiException catch (e) {
                              if (mounted) {
                                await StudyToast.dialog(
                                  context,
                                  title: '创建小组失败',
                                  message: e.message,
                                );
                              }
                            } finally {
                              if (shouldResetLoading && ctx.mounted) {
                                setSheetState(() => isCreating = false);
                              }
                            }
                          },
                ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _showJoinGroupSheet() {
    final codeCtrl = TextEditingController();
    bool isJoining = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) => Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom,
          ),
          child: _groupSheetSurface(
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(ctx).size.height * 0.82,
              ),
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(22, 18, 22, 34),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                _groupSheetHandle(),
                const SizedBox(height: 18),
                _groupSheetTitle(
                  title: '加入小组',
                  subtitle: '输入同伴的邀请码，把自己的学习轨迹接入小组。',
                  icon: Icons.groups_rounded,
                ),
                const SizedBox(height: 18),
                TextField(
                  controller: codeCtrl,
                  textCapitalization: TextCapitalization.characters,
                  style: TextStyle(
                      color: widget.isDarkMode ? Colors.white : AppColors.ink,
                      letterSpacing: 2,
                      fontSize: 18,
                      fontWeight: FontWeight.w600),
                  decoration: _groupInputDecoration('输入邀请码').copyWith(
                    hintStyle: TextStyle(
                      color:
                          StudyUi.body(widget.isDarkMode).withValues(alpha: 0.66),
                      letterSpacing: 0,
                      fontSize: 15,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                _GroupActionPill(
                  label: isJoining ? '加入中...' : '加入小组',
                  icon: Icons.login_rounded,
                  accent: widget.controller.primaryColor,
                  isDarkMode: widget.isDarkMode,
                  busy: isJoining,
                  fullWidth: true,
                  onPressed: isJoining
                      ? null
                      : () async {
                            final code = codeCtrl.text.trim();
                            if (code.isEmpty) return;
                            setSheetState(() => isJoining = true);
                            var shouldResetLoading = true;
                            try {
                              final svc = widget.controller.groupService;
                              await svc.join(inviteCode: code);
                              if (mounted && ctx.mounted) {
                                shouldResetLoading = false;
                                Navigator.of(ctx).pop();
                                _loadGroups();
                                StudyToast.show(context, '已成功加入小组');
                              }
                            } on ApiException catch (e) {
                              if (mounted) {
                                await StudyToast.dialog(
                                  context,
                                  title: '加入小组失败',
                                  message: e.message,
                                );
                              }
                            } finally {
                              if (shouldResetLoading && ctx.mounted) {
                                setSheetState(() => isJoining = false);
                              }
                            }
                          },
                ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _showInviteCodeDialog(GroupInfo group) {
    showDialog(
      context: context,
      builder: (ctx) => _GroupDialogSurface(
        isDarkMode: widget.isDarkMode,
        icon: Icons.verified_rounded,
        accent: widget.controller.primaryColor,
        title: '小组已创建',
        subtitle: '分享邀请码，让同伴加入这条共学路径。',
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            GestureDetector(
              onTap: () {
                if (group.inviteCode != null) {
                  Clipboard.setData(ClipboardData(text: group.inviteCode!));
                  StudyToast.show(context, '已复制到剪贴板');
                }
              },
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                decoration: BoxDecoration(
                  color: widget.controller.primaryColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  group.inviteCode ?? '无',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 3,
                    color: widget.controller.primaryColor,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '点击复制',
              style: TextStyle(
                  color: widget.isDarkMode ? Colors.white54 : Colors.black38,
                  fontSize: 12),
            ),
            const SizedBox(height: 16),
            Align(
              alignment: Alignment.centerRight,
              child: SizedBox(
                width: 128,
                child: _GroupActionPill(
                  label: '完成',
                  icon: Icons.check_rounded,
                  accent: widget.controller.primaryColor,
                  isDarkMode: widget.isDarkMode,
                  fullWidth: true,
                  onPressed: () => Navigator.of(ctx).pop(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActivityTile(
    StudyActivity activity,
    Color titleColor,
    Color bodyColor,
  ) {
    final profile = activity.user?['profile'];
    final username = activity.user?['username']?.toString() ?? '成员';
    final nickname = profile is Map && profile['nickname'] is String
        ? profile['nickname'] as String
        : username;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: widget.isDarkMode
            ? Colors.white.withValues(alpha: 0.05)
            : Colors.white,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: widget.controller.primaryColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              _activityIcon(activity.type),
              size: 18,
              color: widget.controller.primaryColor,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$nickname · ${_activityLabel(activity.type)}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: bodyColor,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  activity.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: titleColor,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if ((activity.summary ?? '').isNotEmpty) ...[
                  const SizedBox(height: 3),
                  Text(
                    activity.summary!,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: bodyColor, fontSize: 12),
                  ),
                ],
                if (activity.happenedAt != null) ...[
                  const SizedBox(height: 5),
                  Text(
                    _relativeTime(activity.happenedAt!),
                    style: TextStyle(
                      color: bodyColor.withValues(alpha: 0.8),
                      fontSize: 11,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  IconData _activityIcon(String type) {
    switch (type) {
      case 'taskCompleted':
        return Icons.task_alt_rounded;
      case 'subTaskCompleted':
        return Icons.checklist_rounded;
      case 'timerCompleted':
        return Icons.timer_rounded;
      case 'noteCreated':
        return Icons.note_alt_rounded;
      case 'flashcardBatchCreated':
        return Icons.style_rounded;
      default:
        return Icons.auto_stories_rounded;
    }
  }

  String _activityLabel(String type) {
    switch (type) {
      case 'taskCompleted':
        return '完成任务';
      case 'subTaskCompleted':
        return '完成子任务';
      case 'studyLogCreated':
        return '新增学习记录';
      case 'timerCompleted':
        return '完成番茄钟';
      case 'noteCreated':
        return '新增笔记';
      case 'flashcardBatchCreated':
        return '整理闪卡';
      default:
        return '学习学迹';
    }
  }

  String _relativeTime(DateTime time) {
    final diff = DateTime.now().difference(time.toLocal());
    if (diff.inMinutes < 1) return '刚刚';
    if (diff.inHours < 1) return '${diff.inMinutes} 分钟前';
    if (diff.inDays < 1) return '${diff.inHours} 小时前';
    if (diff.inDays < 7) return '${diff.inDays} 天前';
    return '${time.year}-${time.month.toString().padLeft(2, '0')}-${time.day.toString().padLeft(2, '0')}';
  }

  void _showGroupDetail(GroupInfo group) {
    List<GroupMember> members =
        UiReviewConfig.enabled ? _reviewMembersFor(group) : [];
    List<StudyActivity> activities =
        UiReviewConfig.enabled ? _reviewActivitiesFor(group) : [];
    bool isLoading = !UiReviewConfig.enabled;
    bool didStartLoad = UiReviewConfig.enabled;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) {
          if (!didStartLoad) {
            didStartLoad = true;
            Future.wait([
              widget.controller.groupService.listMembers(group.id),
              widget.controller.groupService.listActivities(group.id),
            ]).then((results) {
              if (ctx.mounted) {
                setSheetState(() {
                  members = results[0] as List<GroupMember>;
                  activities = results[1] as List<StudyActivity>;
                  isLoading = false;
                });
              }
            }).catchError((_) {
              if (ctx.mounted) setSheetState(() => isLoading = false);
            });
          }

          final titleColor =
              widget.isDarkMode ? Colors.white : AppColors.ink;
          final bodyColor = widget.isDarkMode
              ? const Color(0xFFC2C8D6)
              : AppColors.body;

          return DraggableScrollableSheet(
            initialChildSize: 0.6,
            maxChildSize: 0.85,
            minChildSize: 0.3,
            builder: (_, scrollCtrl) => _groupSheetSurface(
              child: ListView(
                controller: scrollCtrl,
                padding: const EdgeInsets.fromLTRB(22, 18, 22, 40),
                children: [
                  _groupSheetHandle(),
                  const SizedBox(height: 18),
                  _groupSheetTitle(
                    title: group.name,
                    subtitle: group.description?.trim().isNotEmpty == true
                        ? group.description!.trim()
                        : '查看成员、邀请码和最近的共学近况。',
                    icon: Icons.groups_rounded,
                  ),
                  const SizedBox(height: 14),
                  if (group.inviteCode != null)
                    Align(
                      alignment: Alignment.centerLeft,
                      child: _GroupActionPill(
                        label: '邀请码 ${group.inviteCode}',
                        icon: Icons.copy_rounded,
                        accent: widget.controller.primaryColor,
                        isDarkMode: widget.isDarkMode,
                        filled: false,
                        onPressed: () {
                          Clipboard.setData(
                              ClipboardData(text: group.inviteCode!));
                          StudyToast.show(context, '邀请码已复制');
                        },
                      ),
                    ),
                  const SizedBox(height: 20),
                  Text(
                    '成员（${members.length}）',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: titleColor,
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (isLoading)
                    const Center(
                        child: Padding(
                      padding: EdgeInsets.all(24),
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ))
                  else if (members.isEmpty)
                    Text('暂无成员', style: TextStyle(color: bodyColor))
                  else
                    ...members.map((m) => Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: Row(
                            children: [
                              CircleAvatar(
                                radius: 18,
                                backgroundColor: widget
                                    .controller.primaryColor
                                    .withValues(alpha: 0.15),
                                child: Text(
                                  m.username.isNotEmpty
                                      ? m.username[0].toUpperCase()
                                      : '?',
                                  style: TextStyle(
                                    color: widget.controller.primaryColor,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  m.username,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: titleColor,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                              if (m.role != 'member')
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: widget.controller.primaryColor
                                        .withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    _roleName(m.role),
                                    style: TextStyle(
                                      color: widget.controller.primaryColor,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        )),
                  const SizedBox(height: 24),
                  Text(
                    '组内近况',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: titleColor,
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (isLoading)
                    const Center(
                        child: Padding(
                      padding: EdgeInsets.all(20),
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ))
                  else if (activities.isEmpty)
                    Text('暂无近况，完成任务或番茄钟后会出现在这里',
                        style: TextStyle(color: bodyColor, fontSize: 13))
                  else
                    ...activities.map(
                      (activity) => _buildActivityTile(
                        activity,
                        titleColor,
                        bodyColor,
                      ),
                    ),
                  if (group.role != 'owner') ...[
                    const SizedBox(height: 24),
                    _GroupActionPill(
                      label: '退出小组',
                      icon: Icons.logout_rounded,
                      accent: StudyUi.danger,
                      isDarkMode: widget.isDarkMode,
                      filled: false,
                      fullWidth: true,
                      onPressed: () async {
                        try {
                          final navigator = Navigator.of(ctx);
                          await widget.controller.groupService.leave(group.id);
                          if (mounted) {
                            navigator.pop();
                            _loadGroups();
                          }
                        } on ApiException catch (e) {
                          if (mounted) {
                            await StudyToast.dialog(
                              context,
                              title: '退出小组失败',
                              message: e.message,
                            );
                          }
                        }
                      },
                    ),
                  ],
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _GroupDialogSurface extends StatelessWidget {
  const _GroupDialogSurface({
    required this.isDarkMode,
    required this.icon,
    required this.accent,
    required this.title,
    required this.subtitle,
    required this.child,
  });

  final bool isDarkMode;
  final IconData icon;
  final Color accent;
  final String title;
  final String subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: StudyFontScope(
        child: ClipRRect(
          borderRadius: BorderRadius.circular(28),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
            child: Container(
              constraints: const BoxConstraints(maxWidth: 390),
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: isDarkMode
                      ? const [
                          Color(0xEE17222C),
                          Color(0xEE1D2A35),
                        ]
                      : [
                          Colors.white.withValues(alpha: 0.94),
                          const Color(0xFFF4FCF8).withValues(alpha: 0.90),
                        ],
                ),
                borderRadius: BorderRadius.circular(28),
                border: Border.all(
                  color: Colors.white.withValues(alpha: isDarkMode ? 0.12 : 0.84),
                ),
                boxShadow: [
                  if (!isDarkMode)
                    BoxShadow(
                      color: accent.withValues(alpha: 0.15),
                      blurRadius: 32,
                      offset: const Offset(0, 18),
                    ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      StudyGlassIconNode(
                        icon: icon,
                        accent: accent,
                        isDarkMode: isDarkMode,
                        size: 46,
                        iconSize: 21,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: StudyUi.title(isDarkMode),
                                fontSize: 21,
                                fontWeight: AppTypography.hero,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              subtitle,
                              style: TextStyle(
                                color: StudyUi.body(isDarkMode),
                                fontSize: 12,
                                height: 1.35,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  child,
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _GroupActionPill extends StatelessWidget {
  const _GroupActionPill({
    required this.label,
    required this.icon,
    required this.accent,
    required this.isDarkMode,
    required this.onPressed,
    this.filled = true,
    this.busy = false,
    this.fullWidth = false,
  });

  final String label;
  final IconData icon;
  final Color accent;
  final bool isDarkMode;
  final VoidCallback? onPressed;
  final bool filled;
  final bool busy;
  final bool fullWidth;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null && !busy;
    final foreground = filled ? Colors.white : accent;
    final background = filled
        ? accent
        : StudyUi.chipBackground(accent, isDarkMode);
    final borderColor = filled
        ? Colors.white.withValues(alpha: isDarkMode ? 0.12 : 0.42)
        : accent.withValues(alpha: isDarkMode ? 0.34 : 0.22);
    final content = AnimatedOpacity(
      opacity: enabled || busy ? 1 : 0.55,
      duration: const Duration(milliseconds: 160),
      child: Container(
        width: fullWidth ? double.infinity : null,
        constraints:
            fullWidth ? const BoxConstraints() : const BoxConstraints(maxWidth: 220),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: borderColor),
          boxShadow: [
            if (filled)
              BoxShadow(
                color: accent.withValues(alpha: isDarkMode ? 0.18 : 0.20),
                blurRadius: 16,
                offset: const Offset(0, 8),
              ),
          ],
        ),
        child: Row(
          mainAxisSize: fullWidth ? MainAxisSize.max : MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (busy)
              SizedBox(
                width: 15,
                height: 15,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(foreground),
                ),
              )
            else
              Icon(icon, size: 16, color: foreground),
            const SizedBox(width: 7),
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: foreground,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
    );

    if (!enabled) return content;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onPressed,
      child: content,
    );
  }
}
