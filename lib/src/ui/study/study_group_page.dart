import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../controllers/app_data_controller.dart';
import '../../models/community_evidence.dart';
import '../../services/activity_service.dart';
import '../../services/api_client.dart';
import '../../services/group_service.dart';
import '../../theme/app_theme.dart';

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
    unawaited(_loadGroups());
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
    final titleColor = widget.isDarkMode ? Colors.white : Colors.black;
    final bodyColor =
        widget.isDarkMode ? const Color(0xFFC2C8D6) : AppColors.body;
    final accent = widget.controller.primaryColor;

    return RefreshIndicator(
      onRefresh: _loadGroups,
      child: ListView(
        key: const Key('page_study_group'),
        padding: const EdgeInsets.fromLTRB(22, 94, 22, 124),
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '学习小组',
                      style: TextStyle(
                        color: titleColor,
                        fontSize: 24,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      widget.controller.isLoggedIn
                          ? '与同伴一起学习，互相督促'
                          : '登录后可使用小组功能',
                      style:
                          TextStyle(color: bodyColor, fontSize: 14, height: 1.4),
                    ),
                  ],
                ),
              ),
              if (widget.controller.isLoggedIn) ...[
                _circleBtn(
                  icon: Icons.add_rounded,
                  onTap: _showCreateGroupSheet,
                  accent: accent,
                ),
                const SizedBox(width: 10),
                _circleBtn(
                  icon: Icons.group_add_rounded,
                  onTap: _showJoinGroupSheet,
                  accent: accent,
                ),
              ],
            ],
          ),
          const SizedBox(height: 24),
          if (widget.controller.isLoggedIn) ...[
            _buildChallengePanel(titleColor, bodyColor, accent),
            const SizedBox(height: 18),
          ],
          if (!widget.controller.isLoggedIn)
            _buildLoginPrompt(bodyColor, titleColor, accent)
          else if (_isLoading)
            const Padding(
              padding: EdgeInsets.only(top: 60),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_error != null)
            _buildErrorState(bodyColor, accent)
          else if (_groups.isEmpty)
            _buildEmptyState(bodyColor, titleColor, accent)
          else
            ..._groups.map((g) => _buildGroupCard(g, titleColor, bodyColor, accent)),
        ],
      ),
    );
  }

  Widget _buildChallengePanel(
    Color titleColor,
    Color bodyColor,
    Color accent,
  ) {
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
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Icon(Icons.flag_rounded, color: accent, size: 20),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'AI 共学挑战',
                      style: TextStyle(
                        color: titleColor,
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '把小组从排名升级成可执行的共同学习行动。',
                      style: TextStyle(color: bodyColor, fontSize: 12),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (_challengeText.trim().isNotEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: accent.withValues(alpha: widget.isDarkMode ? 0.14 : 0.08),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Text(
                _challengeText,
                style: TextStyle(color: titleColor, height: 1.45),
              ),
            )
          else
            Text(
              'AI 会基于当前课程、任务和学迹证据生成 3-7 天挑战；成员完成任务、番茄钟或动态后进入组内动态与排行榜。',
              style: TextStyle(color: bodyColor, fontSize: 13, height: 1.45),
            ),
          if (_challenges.isNotEmpty) ...[
            const SizedBox(height: 12),
            ..._challenges.take(2).map(
                  (challenge) => Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      border: Border.all(color: accent.withValues(alpha: 0.18)),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          challenge.title,
                          style: TextStyle(color: titleColor, fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${challenge.participantCount} 人参与 · ${challenge.evidenceCount} 条证据',
                          style: TextStyle(color: bodyColor, fontSize: 12),
                        ),
                        if ((challenge.coverImageUrl ?? '').startsWith('vivo-task:')) ...[
                          const SizedBox(height: 4),
                          Text(
                            "封面任务：${challenge.coverImageUrl!.replaceFirst('vivo-task:', '')}",
                            style: TextStyle(color: bodyColor, fontSize: 11),
                          ),
                        ],
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            OutlinedButton(
                              onPressed: () => _joinChallenge(challenge),
                              child: const Text('加入'),
                            ),
                            const SizedBox(width: 8),
                            FilledButton.tonal(
                              onPressed: () => _submitLatestEvidence(challenge),
                              child: const Text('提交最新证据'),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
          ],
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _isGeneratingChallenge ? null : _generateChallenge,
              icon: _isGeneratingChallenge
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.auto_awesome_rounded),
              label: Text(_isGeneratingChallenge ? '生成中...' : '生成共学挑战'),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _generateChallenge() async {
    if (_isGeneratingChallenge) return;
    if (_groups.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请先创建或加入一个学习小组')),
      );
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
          '已有学迹证据数：$evidenceCount',
        ],
      );
      String? coverImageUrl;
      try {
        final cover = await widget.controller.vivoCapabilityService.createCover(
          prompt: '为学习小组共学挑战生成清晰、积极、适合展示的封面。挑战内容：${text.trim()}',
          purpose: 'challenge_cover',
        );
        coverImageUrl = 'vivo-task:${cover.taskId}';
        unawaited(
          widget.controller.activityService
              .create(
                type: 'imageGenerated',
                title: '小组挑战封面已提交生成',
                summary: group.name,
                groupId: group.id,
                sourceType: 'group_challenge_cover',
                sourceId: cover.taskId,
                payloadJson: {'taskId': cover.taskId, 'purpose': 'challenge_cover'},
              )
              .catchError((_) {}),
        );
      } catch (_) {
        coverImageUrl = null;
      }
      final saved = await widget.controller.communityEvidenceService.createChallenge(
        groupId: group.id,
        title: '${group.name} 证据链挑战',
        description: text.trim(),
        planJson: {'draftText': text.trim(), 'durationDays': 7},
        scoringJson: const {
          'task': 10,
          'focus': 5,
          'review': 5,
          'evidencePackage': 8,
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
        _challengeText = '7 天学习证据链挑战：每天完成 1 个可验证行动，'
            '如提交学习日志、完成番茄钟、沉淀笔记或发布学迹动态；'
            '最终按连续天数、AI 闭环次数和证据包完整度进行组内展示。';
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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('已加入共学挑战')),
      );
      await _loadGroups();
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('加入挑战失败，请稍后重试')),
      );
    }
  }

  Future<void> _submitLatestEvidence(GroupChallenge challenge) async {
    final events = widget.controller.learningTraceEvents;
    if (events.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请先完成一次学习行动，生成可提交证据')),
      );
      return;
    }
    final event = events.first;
    try {
      await widget.controller.communityEvidenceService.submitEvidence(
        groupId: challenge.groupId,
        challengeId: challenge.id,
        evidenceType: event.type.name,
        title: event.title,
        summary: event.summary,
        sourceType: event.type.name,
        sourceId: event.sourceId,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('学习证据已提交到挑战')),
      );
      await _loadGroups();
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('提交证据失败，请稍后重试')),
      );
    }
  }

  Widget _buildLoginPrompt(Color bodyColor, Color titleColor, Color accent) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 32),
      decoration: BoxDecoration(
        color: widget.isDarkMode ? const Color(0xFF1E2128) : Colors.white,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          Icon(Icons.lock_rounded, size: 48, color: accent.withValues(alpha: 0.5)),
          const SizedBox(height: 16),
          Text(
            '请先登录',
            style: TextStyle(
              color: titleColor,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '登录后可以创建或加入学习小组',
            style: TextStyle(color: bodyColor, fontSize: 13),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState(Color bodyColor, Color accent) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 32),
      decoration: BoxDecoration(
        color: widget.isDarkMode ? const Color(0xFF1E2128) : Colors.white,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          Icon(Icons.cloud_off_rounded, size: 48, color: accent.withValues(alpha: 0.5)),
          const SizedBox(height: 16),
          Text(_error!, style: TextStyle(color: bodyColor, fontSize: 14)),
          const SizedBox(height: 16),
          TextButton(
            onPressed: _loadGroups,
            child: const Text('重试'),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(Color bodyColor, Color titleColor, Color accent) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 32),
      decoration: BoxDecoration(
        color: widget.isDarkMode ? const Color(0xFF1E2128) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          if (!widget.isDarkMode)
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
        ],
      ),
      child: Column(
        children: [
          Icon(Icons.groups_rounded, size: 48, color: accent.withValues(alpha: 0.5)),
          const SizedBox(height: 16),
          Text(
            '还没有加入任何小组',
            style: TextStyle(
              color: titleColor,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '创建一个小组或通过邀请码加入',
            style: TextStyle(color: bodyColor, fontSize: 13),
          ),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ElevatedButton.icon(
                onPressed: _showCreateGroupSheet,
                icon: const Icon(Icons.add_rounded),
                label: const Text('创建小组'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: accent,
                  foregroundColor: Colors.white,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(width: 12),
              OutlinedButton.icon(
                onPressed: _showJoinGroupSheet,
                icon: const Icon(Icons.group_add_rounded),
                label: const Text('加入小组'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: accent,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  side: BorderSide(color: accent.withValues(alpha: 0.4)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildGroupCard(
    GroupInfo group,
    Color titleColor,
    Color bodyColor,
    Color accent,
  ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: widget.isDarkMode ? const Color(0xFF1E2128) : Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          if (!widget.isDarkMode)
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
        ],
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () => _showGroupDetail(group),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: accent.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(Icons.groups_rounded, color: accent, size: 26),
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
                      fontWeight: FontWeight.w600,
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

  Widget _circleBtn({
    required IconData icon,
    required VoidCallback onTap,
    required Color accent,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: accent.withValues(alpha: 0.12),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: accent, size: 22),
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
          child: Container(
            padding: const EdgeInsets.fromLTRB(22, 18, 22, 34),
            decoration: BoxDecoration(
              color: widget.isDarkMode
                  ? const Color(0xFF1A1F2E)
                  : const Color(0xFFF5F7FF),
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(30)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: widget.isDarkMode ? Colors.white24 : Colors.black26,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                const Text('创建小组',
                    style:
                        TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                const SizedBox(height: 18),
                TextField(
                  controller: nameCtrl,
                  style: TextStyle(
                      color: widget.isDarkMode ? Colors.white : AppColors.ink),
                  decoration: InputDecoration(
                    hintText: '小组名称（必填）',
                    hintStyle: TextStyle(
                        color: widget.isDarkMode
                            ? Colors.white38
                            : Colors.black38),
                    filled: true,
                    fillColor: widget.isDarkMode
                        ? Colors.white.withValues(alpha: 0.06)
                        : const Color(0xFFF2F5FC),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: descCtrl,
                  maxLines: 2,
                  style: TextStyle(
                      color: widget.isDarkMode ? Colors.white : AppColors.ink),
                  decoration: InputDecoration(
                    hintText: '小组简介（选填）',
                    hintStyle: TextStyle(
                        color: widget.isDarkMode
                            ? Colors.white38
                            : Colors.black38),
                    filled: true,
                    fillColor: widget.isDarkMode
                        ? Colors.white.withValues(alpha: 0.06)
                        : const Color(0xFFF2F5FC),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: isCreating
                        ? null
                        : () async {
                            final name = nameCtrl.text.trim();
                            if (name.isEmpty) return;
                            setSheetState(() => isCreating = true);
                            try {
                              final svc = widget.controller.groupService;
                              final group = await svc.create(
                                name: name,
                                description: descCtrl.text.trim(),
                              );
                              if (mounted) {
                                Navigator.of(ctx).pop();
                                _loadGroups();
                                _showInviteCodeDialog(group);
                              }
                            } on ApiException catch (e) {
                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text(e.message)),
                                );
                              }
                            } finally {
                              setSheetState(() => isCreating = false);
                            }
                          },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: widget.controller.primaryColor,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                    ),
                    child: Text(isCreating ? '创建中...' : '创建'),
                  ),
                ),
              ],
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
          child: Container(
            padding: const EdgeInsets.fromLTRB(22, 18, 22, 34),
            decoration: BoxDecoration(
              color: widget.isDarkMode
                  ? const Color(0xFF1A1F2E)
                  : const Color(0xFFF5F7FF),
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(30)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: widget.isDarkMode ? Colors.white24 : Colors.black26,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                const Text('加入小组',
                    style:
                        TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                const SizedBox(height: 18),
                TextField(
                  controller: codeCtrl,
                  textCapitalization: TextCapitalization.characters,
                  style: TextStyle(
                      color: widget.isDarkMode ? Colors.white : AppColors.ink,
                      letterSpacing: 2,
                      fontSize: 18,
                      fontWeight: FontWeight.w600),
                  decoration: InputDecoration(
                    hintText: '输入邀请码',
                    hintStyle: TextStyle(
                        color: widget.isDarkMode
                            ? Colors.white38
                            : Colors.black38,
                        letterSpacing: 0,
                        fontSize: 15,
                        fontWeight: FontWeight.w400),
                    filled: true,
                    fillColor: widget.isDarkMode
                        ? Colors.white.withValues(alpha: 0.06)
                        : const Color(0xFFF2F5FC),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: isJoining
                        ? null
                        : () async {
                            final code = codeCtrl.text.trim();
                            if (code.isEmpty) return;
                            setSheetState(() => isJoining = true);
                            try {
                              final svc = widget.controller.groupService;
                              await svc.join(inviteCode: code);
                              if (mounted) {
                                Navigator.of(ctx).pop();
                                _loadGroups();
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('已成功加入小组')),
                                );
                              }
                            } on ApiException catch (e) {
                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text(e.message)),
                                );
                              }
                            } finally {
                              setSheetState(() => isJoining = false);
                            }
                          },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: widget.controller.primaryColor,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                    ),
                    child: Text(isJoining ? '加入中...' : '加入'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showInviteCodeDialog(GroupInfo group) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('小组已创建'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('分享以下邀请码给同伴：'),
            const SizedBox(height: 16),
            GestureDetector(
              onTap: () {
                if (group.inviteCode != null) {
                  Clipboard.setData(ClipboardData(text: group.inviteCode!));
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('已复制到剪贴板')),
                  );
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
                    fontWeight: FontWeight.w800,
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
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('完成'),
          ),
        ],
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
                  style: TextStyle(
                    color: bodyColor,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  activity.title,
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
        return '生成闪卡';
      default:
        return '学习动态';
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
    List<GroupMember> members = [];
    List<StudyActivity> activities = [];
    bool isLoading = true;
    bool didStartLoad = false;

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
            builder: (_, scrollCtrl) => Container(
              decoration: BoxDecoration(
                color: widget.isDarkMode
                    ? const Color(0xFF1A1F2E)
                    : const Color(0xFFF5F7FF),
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(30)),
              ),
              child: ListView(
                controller: scrollCtrl,
                padding: const EdgeInsets.fromLTRB(22, 18, 22, 40),
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: widget.isDarkMode
                            ? Colors.white24
                            : Colors.black26,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  Text(
                    group.name,
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: titleColor,
                    ),
                  ),
                  if (group.description != null &&
                      group.description!.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(group.description!,
                        style: TextStyle(color: bodyColor, fontSize: 14)),
                  ],
                  const SizedBox(height: 8),
                  if (group.inviteCode != null)
                    GestureDetector(
                      onTap: () {
                        Clipboard.setData(
                            ClipboardData(text: group.inviteCode!));
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('邀请码已复制')),
                        );
                      },
                      child: Row(
                        children: [
                          Text('邀请码：${group.inviteCode}',
                              style: TextStyle(
                                  color: bodyColor, fontSize: 13)),
                          const SizedBox(width: 6),
                          Icon(Icons.copy_rounded, size: 14, color: bodyColor),
                        ],
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
                    '组内动态',
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
                    Text('暂无动态，完成任务或番茄钟后会出现在这里',
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
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton(
                        onPressed: () async {
                          try {
                            await widget.controller.groupService
                                .leave(group.id);
                            if (mounted) {
                              Navigator.of(ctx).pop();
                              _loadGroups();
                            }
                          } on ApiException catch (e) {
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text(e.message)),
                              );
                            }
                          }
                        },
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFFEF6850),
                          side: const BorderSide(
                              color: Color(0xFFEF6850), width: 1.2),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                        ),
                        child: const Text('退出小组'),
                      ),
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
