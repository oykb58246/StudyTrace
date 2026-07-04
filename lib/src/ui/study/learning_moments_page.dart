import 'dart:async';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../controllers/app_data_controller.dart';
import '../../models/ai_capability_trace.dart';
import '../../models/community_evidence.dart' as cloud;
import '../../models/learning_moment.dart';
import '../../services/api_client.dart';
import '../../services/group_service.dart';
import '../../services/picked_image_store.dart';
import '../../theme/app_theme.dart';
import '../../config/ui_review_config.dart';
import '../shared/app_assets.dart';
import '../shared/common_widgets.dart';
import '../shared/local_image.dart';

class LearningMomentsPage extends StatefulWidget {
  const LearningMomentsPage({
    super.key,
    required this.isDarkMode,
    required this.controller,
    this.onOpenStudyGroup,
  });

  final bool isDarkMode;
  final AppDataController controller;
  final VoidCallback? onOpenStudyGroup;

  @override
  State<LearningMomentsPage> createState() => _LearningMomentsPageState();
}

class _LearningMomentsPageState extends State<LearningMomentsPage> {
  static const String _localPrivateMomentSourceType = 'local_private_moment';

  final _contentController = TextEditingController();
  final _picker = ImagePicker();
  final List<String> _imagePaths = [];
  final List<GroupInfo> _groups = [];
  final List<LearningMoment> _cloudMoments = [];

  String _selectedCourse = '';
  String? _selectedGroupId;
  final List<String> _selectedAllowedGroupIds = [];
  final List<String> _selectedDeniedGroupIds = [];
  LearningMomentVisibility _visibility = LearningMomentVisibility.private;
  bool _isPosting = false;
  bool _isLoadingFeed = false;
  String? _feedError;
  late bool _lastLoggedIn;
  bool _isLoadingGroups = false;
  bool _isSavingPackage = false;
  bool _isCheckingLocation = false;
  final List<cloud.EvidencePackage> _cloudPackages = [];
  final List<cloud.LocationCheckIn> _locationCheckIns = [];
  List<_CapabilityBadge> _cloudCapabilityBadges = const [];
  List<AiCapabilityTrace> _lastCapabilityTraces = const [];
  bool _didOpenReviewSurface = false;

  @override
  void initState() {
    super.initState();
    _lastLoggedIn = widget.controller.isLoggedIn;
    widget.controller.addListener(_handleControllerChanged);
    unawaited(_loadMomentFeed());
    unawaited(_loadGroups());
    unawaited(_loadCloudPackages());
    unawaited(_loadLocationCheckIns());
    unawaited(_loadCapabilityBadges());
    _scheduleUiReviewSurface();
  }

  @override
  void didUpdateWidget(covariant LearningMomentsPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller == widget.controller) return;
    oldWidget.controller.removeListener(_handleControllerChanged);
    _lastLoggedIn = widget.controller.isLoggedIn;
    widget.controller.addListener(_handleControllerChanged);
    unawaited(_loadMomentFeed());
    unawaited(_loadGroups());
  }

  void _handleControllerChanged() {
    final loggedIn = widget.controller.isLoggedIn;
    if (loggedIn == _lastLoggedIn) return;
    _lastLoggedIn = loggedIn;
    if (loggedIn) {
      unawaited(_loadMomentFeed());
      unawaited(_loadGroups());
      unawaited(_loadCloudPackages());
      unawaited(_loadLocationCheckIns());
      unawaited(_loadCapabilityBadges());
    } else if (mounted) {
      setState(() {
        _cloudMoments.clear();
        _groups.clear();
        _feedError = null;
      });
    }
  }

  void _scheduleUiReviewSurface() {
    if (!UiReviewConfig.enabled || _didOpenReviewSurface) return;
    final target = UiReviewConfig.target.trim();
    if (target != 'learning-moments-tools' &&
        target != 'learning-moments-composer' &&
        target != 'learning-moments-course-selector') {
      return;
    }
    _didOpenReviewSurface = true;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await Future<void>.delayed(const Duration(milliseconds: 450));
      if (!mounted) return;
      switch (target) {
        case 'learning-moments-tools':
          await _showMomentsTools();
          break;
        case 'learning-moments-composer':
          await _openComposerSheet();
          break;
        case 'learning-moments-course-selector':
          await _showCourseSelectorReviewSheet();
          break;
      }
    });
  }

  Future<void> _loadMomentFeed() async {
    if (!widget.controller.isLoggedIn || _isLoadingFeed) return;
    setState(() {
      _isLoadingFeed = true;
      _feedError = null;
    });
    try {
      final moments = await widget.controller.learningMomentService.feed();
      final syncedMoments = await _syncLocalPrivateMomentsToCloud(moments);
      if (!mounted) return;
      setState(() {
        _cloudMoments
          ..clear()
          ..addAll(syncedMoments);
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _feedError = _friendlyCloudError(error, '学迹加载失败，下拉可重试');
      });
    } finally {
      if (mounted) setState(() => _isLoadingFeed = false);
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_handleControllerChanged);
    _contentController.dispose();
    super.dispose();
  }

  Future<void> _loadGroups() async {
    if (!widget.controller.isLoggedIn || _isLoadingGroups) return;
    setState(() => _isLoadingGroups = true);
    try {
      final groups = await widget.controller.groupService.listMine();
      if (!mounted) return;
      setState(() {
        _groups
          ..clear()
          ..addAll(groups);
        if (_selectedGroupId != null &&
            !_groups.any((group) => group.id == _selectedGroupId)) {
          _selectedGroupId = null;
        }
        _selectedAllowedGroupIds
            .removeWhere((id) => !_groups.any((group) => group.id == id));
        _selectedDeniedGroupIds
            .removeWhere((id) => !_groups.any((group) => group.id == id));
      });
    } catch (_) {
      if (mounted) {
        setState(() {
          _groups.clear();
          _selectedGroupId = null;
          _selectedAllowedGroupIds.clear();
          _selectedDeniedGroupIds.clear();
          _visibility = LearningMomentVisibility.private;
        });
      }
    } finally {
      if (mounted) setState(() => _isLoadingGroups = false);
    }
  }

  Future<void> _loadCloudPackages() async {
    if (!widget.controller.isLoggedIn) return;
    try {
      final packages =
          await widget.controller.communityEvidenceService.listMyPackages();
      if (!mounted) return;
      setState(() {
        _cloudPackages
          ..clear()
          ..addAll(packages);
      });
    } catch (_) {
      // The local evidence timeline remains available while offline.
    }
  }

  Future<void> _loadLocationCheckIns() async {
    if (!widget.controller.isLoggedIn) return;
    try {
      final checkIns =
          await widget.controller.communityEvidenceService.listMyLocationCheckIns();
      if (!mounted) return;
      setState(() {
        _locationCheckIns
          ..clear()
          ..addAll(checkIns);
      });
    } catch (_) {
      // Location evidence is additive; the timeline still works offline.
    }
  }

  Future<void> _loadCapabilityBadges() async {
    if (!widget.controller.isLoggedIn) return;
    try {
      final badges = await widget.controller.vivoCapabilityService.capabilityBadges();
      if (!mounted) return;
      setState(() {
        _cloudCapabilityBadges = badges
            .map(
              (item) => _CapabilityBadge(
                item['label']?.toString() ?? '',
                item['unlocked'] == true,
                current: (item['current'] as num?)?.toInt() ?? 0,
                target: (item['target'] as num?)?.toInt() ?? 1,
                source: item['source']?.toString() ?? '',
                nextStep: _badgeNextStepForLabel(
                  item['label']?.toString() ?? '',
                ),
                iconAsset: _badgeAssetForLabel(item['label']?.toString() ?? ''),
              ),
            )
            .where((badge) => badge.label.isNotEmpty)
            .toList(growable: false);
      });
    } catch (_) {
      // The local badge estimate remains available while offline.
    }
  }

  @override
  Widget build(BuildContext context) {
    final accent = widget.controller.primaryColor;
    final titleColor = StudyUi.title(widget.isDarkMode);
    final bodyColor = StudyUi.body(widget.isDarkMode);
    return Scaffold(
      backgroundColor: StudyUi.background(widget.isDarkMode),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        foregroundColor: titleColor,
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            StudyGlassIconNode(
              icon: Icons.dynamic_feed_rounded,
              accent: StudyUi.pathViolet,
              size: 32,
              iconSize: 16,
              isDarkMode: widget.isDarkMode,
            ),
            const SizedBox(width: 10),
            const Flexible(
              child: Text(
                '学迹动态',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontWeight: AppTypography.title),
              ),
            ),
          ],
        ),
        actions: [
          _MomentToolbarAction(
            tooltip: '学迹整理',
            icon: Icons.more_horiz_rounded,
            accent: StudyUi.pathViolet,
            isDarkMode: widget.isDarkMode,
            onPressed: _showMomentsTools,
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: StudyScreenBackground(
        isDarkMode: widget.isDarkMode,
        accent: StudyUi.pathViolet,
        child: AnimatedBuilder(
          animation: widget.controller,
          builder: (context, _) {
            final moments = _displayMoments();
            final learningLoopMoments = moments
                .where((moment) => (moment.sourceType ?? '').trim() == 'learning_loop')
                .toList(growable: false);
            final latestLearningLoopMoment =
                learningLoopMoments.isEmpty ? null : learningLoopMoments.first;
            final listView = ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 36),
              children: [
                _HeaderPanel(
                  isDarkMode: widget.isDarkMode,
                  eventCount: widget.controller.studyLogs.length,
                  momentCount: moments.length,
                  packageCount: widget.controller.weeklyReports.length,
                  learningLoopCount: learningLoopMoments.length,
                  latestLearningLoopLabel: latestLearningLoopMoment == null
                      ? null
                      : _formatLearningLoopTime(latestLearningLoopMoment.createdAt),
                  onRecord: _openComposerSheet,
                  onReview: _showMomentsTools,
                  onRefresh: widget.controller.isLoggedIn
                      ? () => unawaited(_loadMomentFeed())
                      : null,
                ),
                const SizedBox(height: 10),
                _PostEntryCard(
                  isDarkMode: widget.isDarkMode,
                  accent: accent,
                  titleColor: titleColor,
                  bodyColor: bodyColor,
                  avatarImagePath:
                      widget.controller.userProfile.avatarImagePath,
                  avatarEmoji: widget.controller.userProfile.avatarEmoji,
                  onTap: _openComposerSheet,
                ),
                const SizedBox(height: 10),
                if (moments.isEmpty)
                  _isLoadingFeed
                    ? const Center(
                        child: Padding(
                          padding: EdgeInsets.all(28),
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      )
                    : _EmptyTimeline(
                        isDarkMode: widget.isDarkMode,
                        accent: accent,
                        bodyColor: bodyColor,
                        message: widget.controller.isLoggedIn ? _feedError : null,
                        onRecord: _openComposerSheet,
                        onReview: _showMomentsTools,
                      )
                else
                  ...moments.map(
                  (moment) {
                    final isLocalOnly = _isLocalOnlyMoment(moment);
                    return _MomentCard(
                      moment: moment,
                      groups: _groups,
                      isDarkMode: widget.isDarkMode,
                      accent: accent,
                      titleColor: titleColor,
                      bodyColor: bodyColor,
                      onLike: isLocalOnly
                          ? () => _showTip('这条私密记录保存在本机，暂不能标记有帮助')
                          : () => _toggleMomentLike(moment),
                      onComment: isLocalOnly
                          ? () => _showTip('这条私密记录保存在本机，暂不能留下回看备注')
                          : () => _commentMoment(moment),
                      onDelete: moment.isMine || isLocalOnly
                          ? () => _deleteMoment(moment.id)
                          : null,
                      onEditVisibility:
                          widget.controller.isLoggedIn && moment.isMine && !isLocalOnly
                              ? () => _editMomentVisibility(moment)
                              : null,
                      onDeleteComment: (comment) =>
                          _deleteMomentComment(moment, comment),
                    );
                  },
                ),
              ],
            );
            if (!widget.controller.isLoggedIn) return listView;
            return RefreshIndicator(
              onRefresh: _loadMomentFeed,
              child: listView,
            );
          },
        ),
      ),
    );
  }

  List<LearningMoment> _displayMoments() {
    if (!widget.controller.isLoggedIn) return widget.controller.learningMoments;
    final byId = <String, LearningMoment>{};
    final syncedLocalMomentIds = <String>{};
    for (final moment in _cloudMoments) {
      byId[moment.id] = moment;
      final localSourceId = _localPrivateMomentSourceId(moment);
      if (localSourceId != null) syncedLocalMomentIds.add(localSourceId);
    }
    for (final moment in widget.controller.learningMoments) {
      if (moment.visibility != LearningMomentVisibility.private) continue;
      if (syncedLocalMomentIds.contains(moment.id)) continue;
      byId.putIfAbsent(moment.id, () => moment);
    }
    final moments = byId.values.toList(growable: false)
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return moments;
  }

  String _formatLearningLoopTime(DateTime time) {
    final now = DateTime.now();
    final diff = now.difference(time);
    if (diff.inMinutes < 1) return '刚刚整理';
    if (diff.inHours < 1) return '${diff.inMinutes} 分钟前整理';
    if (diff.inDays < 1) return '${diff.inHours} 小时前整理';
    if (diff.inDays < 7) return '${diff.inDays} 天前整理';
    return '${time.month}/${time.day} 整理';
  }

  bool _isLocalOnlyMoment(LearningMoment moment) =>
      _isLocalOnlyMomentId(moment.id);

  bool _isLocalOnlyMomentId(String momentId) {
    final existsLocally =
        widget.controller.learningMoments.any((moment) => moment.id == momentId);
    if (!existsLocally) return false;
    return !_cloudMoments.any(
      (moment) =>
          moment.id == momentId ||
          _localPrivateMomentSourceId(moment) == momentId,
    );
  }

  Future<List<LearningMoment>> _syncLocalPrivateMomentsToCloud(
    List<LearningMoment> cloudMoments,
  ) async {
    if (!widget.controller.isLoggedIn) return cloudMoments;
    final merged = List<LearningMoment>.of(cloudMoments);
    final cloudIds = merged.map((moment) => moment.id).toSet();
    final syncedLocalMomentIds = <String>{};
    for (final moment in merged) {
      final sourceId = _localPrivateMomentSourceId(moment);
      if (sourceId != null) syncedLocalMomentIds.add(sourceId);
    }
    final localPrivateMoments = widget.controller.learningMoments
        .where((moment) => moment.visibility == LearningMomentVisibility.private)
        .toList(growable: false);

    for (final localMoment in localPrivateMoments) {
      final localId = localMoment.id.trim();
      if (localId.isEmpty) continue;
      if (cloudIds.contains(localId) ||
          syncedLocalMomentIds.contains(localId)) {
        continue;
      }
      if (!widget.controller.isLoggedIn) break;
      try {
        final uploaded = await widget.controller.learningMomentService.create(
          content: localMoment.content,
          courseName: localMoment.courseName,
          imagePaths: localMoment.imagePaths,
          visibility: LearningMomentVisibility.private,
          sourceType: _syncedLocalSourceType(localMoment),
          sourceId: localId,
        );
        final uploadedSourceId = _localPrivateMomentSourceId(uploaded);
        final index = merged.indexWhere(
          (moment) =>
              moment.id == uploaded.id ||
              (uploadedSourceId != null &&
                  _localPrivateMomentSourceId(moment) == uploadedSourceId),
        );
        if (index >= 0) {
          merged[index] = uploaded;
        } else {
          merged.add(uploaded);
        }
        cloudIds.add(uploaded.id);
        if (uploadedSourceId != null) {
          syncedLocalMomentIds.add(uploadedSourceId);
        }
      } catch (_) {
        // Keep the local private record visible; try again on the next refresh.
      }
    }
    return merged;
  }

  String? _localPrivateMomentSourceId(LearningMoment moment) {
    if (!_isSyncedLocalPrivateMoment(moment)) return null;
    final sourceId = moment.sourceId?.trim();
    return sourceId == null || sourceId.isEmpty ? null : sourceId;
  }

  bool _isSyncedLocalPrivateMoment(LearningMoment moment) {
    final sourceType = (moment.sourceType ?? '').trim();
    return sourceType == _localPrivateMomentSourceType ||
        sourceType == 'synced_learning_loop' ||
        sourceType == 'synced_task_progress';
  }

  String _syncedLocalSourceType(LearningMoment moment) {
    return switch ((moment.sourceType ?? '').trim()) {
      'learning_loop' => 'synced_learning_loop',
      'task_progress' => 'synced_task_progress',
      _ => _localPrivateMomentSourceType,
    };
  }

  List<_EvidencePackage> _buildEvidencePackages(
    List<LearningTraceEvent> events,
  ) {
    final byCourse = <String, List<LearningTraceEvent>>{};
    for (final event in events) {
      final course =
          event.courseName.trim().isEmpty ? '未归课程' : event.courseName.trim();
      byCourse.putIfAbsent(course, () => []).add(event);
    }
    final packages = byCourse.entries.map((entry) {
      final items = entry.value;
      final aiCount = items.where((event) => event.isAiGenerated).length;
      final latest = items.map((event) => event.happenedAt).reduce(
            (a, b) => a.isAfter(b) ? a : b,
          );
      return _EvidencePackage(
        courseName: entry.key,
        eventCount: items.length,
        aiCount: aiCount,
        shareableCount: items.where((event) => event.isShareable).length,
        latestAt: latest,
        types: items.map((event) => event.typeLabel).toSet().toList(),
      );
    }).toList()
      ..sort((a, b) => b.eventCount.compareTo(a.eventCount));
    return packages;
  }

  List<_CapabilityBadge> _buildCapabilityBadges(
    List<LearningTraceEvent> events,
  ) {
    final records = widget.controller.recentActionRecords;
    final moments = widget.controller.learningMoments;
    final hasImageMoment = moments.any((moment) => moment.imagePaths.isNotEmpty);
    final hasAiAction = records.any((record) => record.statusLabel == '已完成');
    final hasMemory = records.any((record) => record.toolId.contains('memory'));
    final hasLoop = records.any((record) => record.toolId.contains('loop')) ||
        events.any((event) => event.type == LearningTraceEventType.aiAction);
    return [
      _CapabilityBadge(
        '资料整理',
        events.isNotEmpty || records.isNotEmpty,
        current: (events.length + records.length).clamp(0, 6).toInt(),
        target: 6,
        source: '把记录、任务、笔记沉淀进学迹',
        nextStep: '再完成一次学习记录或学习整理',
        iconAsset: AppAssets.aiBadgeOrganize,
      ),
      _CapabilityBadge(
        '图片识读',
        hasImageMoment || _imagePaths.isNotEmpty,
        current: (moments.where((moment) => moment.imagePaths.isNotEmpty).length +
                _imagePaths.length)
            .clamp(0, 3)
            .toInt(),
        target: 3,
        source: '用图片材料整理学习记录',
        nextStep: '保存一条带图片的学迹',
        iconAsset: AppAssets.aiBadgeVision,
      ),
      _CapabilityBadge(
        '智能执行',
        hasAiAction || records.isNotEmpty,
        current: records.where((record) => record.statusLabel == '已完成').length.clamp(0, 5).toInt(),
        target: 5,
        source: '用学习整理台梳理可落地的下一步',
        nextStep: '用学习整理台创建任务、笔记或今日安排',
        iconAsset: AppAssets.aiBadgeAssistant,
      ),
      _CapabilityBadge(
        '学习记忆',
        hasMemory,
        current: records.where((record) => record.toolId.contains('memory')).length.clamp(0, 3).toInt(),
        target: 3,
        source: '从个人学习资料中找回线索',
        nextStep: '在学习对话里追问过去的任务或笔记',
        iconAsset: AppAssets.aiBadgeMemory,
      ),
      _CapabilityBadge(
        '复盘留痕',
        hasLoop || events.length >= 3,
        current: events.where((event) => event.isAiGenerated).length.clamp(0, 4).toInt(),
        target: 4,
        source: '形成可回看的学习过程',
        nextStep: '保存一次计划并启动专注',
        iconAsset: AppAssets.aiBadgeReview,
      ),
      _CapabilityBadge(
        '学迹沉淀',
        moments.isNotEmpty,
        current: moments.length.clamp(0, 3).toInt(),
        target: 3,
        source: '把学习记录保存到学迹',
        nextStep: '保存或同步一条学迹记录',
        iconAsset: AppAssets.aiBadgeShare,
      ),
    ];
  }

  static String _badgeAssetForLabel(String label) {
    if (label.contains('OCR') || label.contains('图片')) {
      return AppAssets.aiBadgeVision;
    }
    if (label.contains('记忆') || label.contains('检索')) {
      return AppAssets.aiBadgeMemory;
    }
    if (label.contains('复盘') || label.contains('落地')) {
      return AppAssets.aiBadgeReview;
    }
    if (label.contains('分享') || label.contains('动态')) {
      return AppAssets.aiBadgeShare;
    }
    if (label.contains('助手') || label.contains('大模型') || label.contains('AI')) {
      return AppAssets.aiBadgeAssistant;
    }
    return AppAssets.aiBadgeOrganize;
  }

  static String _badgeNextStepForLabel(String label) {
    if (label.contains('OCR') || label.contains('图片')) {
      return '保存一条带图片的学迹';
    }
    if (label.contains('记忆') || label.contains('检索')) {
      return '在学习对话里追问过去的任务或笔记';
    }
    if (label.contains('复盘') || label.contains('落地')) {
      return '保存一次计划并启动专注';
    }
    if (label.contains('分享') || label.contains('动态')) {
      return '保存或同步一条学迹';
    }
    if (label.contains('助手') || label.contains('大模型') || label.contains('AI')) {
      return '用助手创建任务、笔记或今日安排';
    }
    return '再完成一次学习记录或学习整理';
  }

  InputDecoration _momentInputDecoration({
    String? labelText,
    String? hintText,
  }) {
    return InputDecoration(
      labelText: labelText,
      hintText: hintText,
      filled: true,
      fillColor: StudyUi.surfaceAlt(widget.isDarkMode),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide.none,
      ),
    );
  }

  Future<void> _openComposerSheet() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        final accent = widget.controller.primaryColor;
        final titleColor = widget.isDarkMode ? Colors.white : AppColors.ink;
        final bodyColor =
            widget.isDarkMode ? const Color(0xFFC2C8D6) : AppColors.body;
        return DraggableScrollableSheet(
          initialChildSize: 0.82,
          minChildSize: 0.55,
          maxChildSize: 0.94,
          expand: false,
          builder: (context, scrollController) => StatefulBuilder(
            builder: (context, setSheetState) => Padding(
              padding: EdgeInsets.only(
                left: 14,
                right: 14,
                bottom: MediaQuery.of(context).viewInsets.bottom + 14,
              ),
              child: _ComposerCard(
                scrollController: scrollController,
                isDarkMode: widget.isDarkMode,
                accent: accent,
                titleColor: titleColor,
                bodyColor: bodyColor,
                controller: _contentController,
                courses: widget.controller.courseNames,
                groups: _groups,
                onOpenStudyGroup: widget.onOpenStudyGroup,
                selectedCourse: _selectedCourse,
                visibility: _visibility,
                selectedAllowedGroupIds: _selectedAllowedGroupIds,
                selectedDeniedGroupIds: _selectedDeniedGroupIds,
                imagePaths: _imagePaths,
                isPosting: _isPosting,
                onCourseChanged: (value) {
                  setState(() => _selectedCourse = value ?? '');
                  setSheetState(() {});
                },
                onVisibilityChanged: (value) {
                  if (!widget.controller.isLoggedIn &&
                      value != LearningMomentVisibility.private) {
                    _showTip('登录后可同步到小组，当前可先保存给自己');
                    return;
                  }
                  if (_groups.isEmpty &&
                      value != LearningMomentVisibility.private) {
                    unawaited(_showNoGroupNextStep());
                    return;
                  }
                  setState(() {
                    _visibility = value;
                    if (value != LearningMomentVisibility.includeGroups) {
                      _selectedAllowedGroupIds.clear();
                    }
                    if (value != LearningMomentVisibility.excludeGroups) {
                      _selectedDeniedGroupIds.clear();
                    }
                  });
                  setSheetState(() {});
                },
                onChooseGroups: (visibility) async {
                  final current = visibility == LearningMomentVisibility.includeGroups
                      ? _selectedAllowedGroupIds
                      : _selectedDeniedGroupIds;
                  final selected = await _showGroupMultiSelect(
                    title: visibility == LearningMomentVisibility.includeGroups
                        ? '指定小组可以看'
                        : '指定小组不可看',
                    initialIds: current,
                  );
                  if (selected == null) return;
                  setState(() {
                    if (visibility == LearningMomentVisibility.includeGroups) {
                      _selectedAllowedGroupIds
                        ..clear()
                        ..addAll(selected);
                    } else {
                      _selectedDeniedGroupIds
                        ..clear()
                        ..addAll(selected);
                    }
                  });
                  setSheetState(() {});
                },
                onPickImages: () async {
                  await _pickImages();
                  if (mounted) setSheetState(() {});
                },
                onRemoveImage: (path) {
                  setState(() => _imagePaths.remove(path));
                  setSheetState(() {});
                },
                onPost: () async {
                  final navigator = Navigator.of(sheetContext);
                  final posted = await _publishMoment();
                  if (posted && mounted) navigator.pop();
                },
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _showCourseSelectorReviewSheet() {
    final options = {
      for (final course in widget.controller.courseNames)
        if (course.trim().isNotEmpty) course.trim(),
    }.toList(growable: false);
    final accent = widget.controller.primaryColor;
    final currentCourse = _selectedCourse.trim();
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => _MomentsSheetSurface(
        isDarkMode: widget.isDarkMode,
        accent: accent,
        icon: Icons.school_rounded,
        title: '关联课程',
              subtitle: '选择这条学迹属于哪门课，或保持不关联。',
        child: Column(
          children: [
            _MomentGroupCheckTile(
              title: '不关联课程',
              subtitle: '保存为通用学习现场，之后仍可整理进回顾。',
              selected: currentCourse.isEmpty,
              accent: accent,
              isDarkMode: widget.isDarkMode,
              onTap: () => Navigator.of(sheetContext).pop(),
            ),
            for (final course in options)
              _MomentGroupCheckTile(
                title: course,
                subtitle: '归入「$course」的学习路径和学习回顾。',
                selected: currentCourse == course,
                accent: accent,
                isDarkMode: widget.isDarkMode,
                onTap: () => Navigator.of(sheetContext).pop(),
              ),
            if (options.isEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  '还没有课程记录，先保存为通用学迹也没问题。',
                  style: TextStyle(
                    color: StudyUi.body(widget.isDarkMode),
                    fontSize: 12,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _showMomentsTools() async {
    final allEvents = widget.controller.learningTraceEvents;
    final packages = _buildEvidencePackages(allEvents);
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        final accent = widget.controller.primaryColor;
        final titleColor = widget.isDarkMode ? Colors.white : AppColors.ink;
        final bodyColor =
            widget.isDarkMode ? const Color(0xFFC2C8D6) : AppColors.body;
        return _MomentsSheetSurface(
          isDarkMode: widget.isDarkMode,
          accent: accent,
          icon: Icons.auto_awesome_rounded,
          title: '学迹整理',
          subtitle: '整理能力线索、校园足迹、学习回顾和常看记录。',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
                _CapabilityBadgePanel(
                  isDarkMode: widget.isDarkMode,
                  accent: accent,
                  titleColor: titleColor,
                  bodyColor: bodyColor,
                  badges: _cloudCapabilityBadges.isNotEmpty
                      ? _cloudCapabilityBadges
                      : _buildCapabilityBadges(allEvents),
                  traces: _lastCapabilityTraces,
                ),
                const SizedBox(height: 14),
                _CampusMapPanel(
                  isDarkMode: widget.isDarkMode,
                  accent: accent,
                  titleColor: titleColor,
                  bodyColor: bodyColor,
                  locations: _locationCheckIns,
                  isCheckingLocation: _isCheckingLocation,
                  onCheckIn: _createLocationCheckIn,
                ),
                const SizedBox(height: 14),
                _EvidencePackagePanel(
                  isDarkMode: widget.isDarkMode,
                  accent: accent,
                  titleColor: titleColor,
                  bodyColor: bodyColor,
                  packages: packages,
                  cloudPackages: _cloudPackages,
                  onUsePackage: (package) {
                    _useEvidencePackage(package);
                    Navigator.of(context).pop();
                    unawaited(_openComposerSheet());
                  },
                  onSavePackage: _saveEvidencePackage,
                  onGenerateCover: _generateEvidenceCover,
                  onToggleFeatured: _togglePackageFeatured,
                  onSharePackage: _sharePackageToGroup,
                ),
                const SizedBox(height: 14),
                _FeaturedWallPanel(
                  isDarkMode: widget.isDarkMode,
                  accent: accent,
                  titleColor: titleColor,
                  bodyColor: bodyColor,
                  packages: _cloudPackages.where((package) => package.featured),
                  events: allEvents.where((event) => event.isShareable).take(4),
                  onShare: _shareTraceEvent,
                ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _pickImages() async {
    if (_imagePaths.length >= 9) return;
    try {
      final picked = await _picker.pickMultiImage(imageQuality: 82);
      if (picked.isEmpty) return;
      final remain = 9 - _imagePaths.length;
      final saved = <String>[];
      for (final image in picked.take(remain)) {
        saved.add(await persistPickedImage(image, prefix: 'learning_moment'));
      }
      if (!mounted) return;
      setState(() => _imagePaths.addAll(saved));
    } catch (_) {
      _showSnack('图片选择失败，请稍后重试');
    }
  }

  Future<void> _saveEvidencePackage(_EvidencePackage package) async {
    if (!widget.controller.isLoggedIn || _isSavingPackage) {
      _useEvidencePackage(package);
      return;
    }
    setState(() => _isSavingPackage = true);
    final events = widget.controller.learningTraceEvents
        .where((event) =>
            (event.courseName.trim().isEmpty ? '未归课程' : event.courseName.trim()) ==
            package.courseName)
        .toList();
    try {
      final saved = await widget.controller.communityEvidenceService.createPackage(
        title: '${package.courseName} 学习回顾',
        courseName: package.courseName == '未归课程' ? '' : package.courseName,
        description:
            '${package.eventCount} 条记录，${package.aiCount} 次学习整理，${package.shareableCount} 条可回看记录。',
        sourceRefs: events
            .map((event) => {
                  'type': event.type.name,
                  'sourceId': event.sourceId,
                  'title': event.title,
                })
            .toList(),
        metrics: {
          'eventCount': package.eventCount,
          'aiCount': package.aiCount,
          'shareableCount': package.shareableCount,
        },
      );
      if (!mounted) return;
      setState(() => _cloudPackages.insert(0, saved));
      _showSnack('学习回顾已保存，可在已保存回顾里继续查看或同步到小组');
    } catch (_) {
      _useEvidencePackage(package);
      _showSnack('学习回顾暂时无法同步，已先保存为本地学迹文案');
    } finally {
      if (mounted) setState(() => _isSavingPackage = false);
    }
  }

  Future<void> _generateEvidenceCover(cloud.EvidencePackage package) async {
    try {
      final currentCover = package.coverImageUrl ?? '';
      if (currentCover.startsWith('vivo-task:')) {
        final taskId = currentCover.replaceFirst('vivo-task:', '');
        final task = await widget.controller.vivoCapabilityService.refreshImageTask(taskId);
        if (!mounted) return;
        setState(() => _lastCapabilityTraces = task.capabilityTraces);
        if (task.imagesUrl.isEmpty) {
          _showSnack('封面生成中，稍后刷新查看');
          return;
        }
        final updated = await widget.controller.communityEvidenceService.updatePackage(
          package.id,
          coverImageUrl: task.imagesUrl.first,
        );
        if (!mounted) return;
        final index = _cloudPackages.indexWhere((item) => item.id == package.id);
        setState(() {
          if (index >= 0) _cloudPackages[index] = updated;
        });
        _showSnack('回顾封面已保存');
        return;
      }
      final task = await widget.controller.vivoCapabilityService.createCover(
        prompt:
            '为大学生学习回顾制作清晰、积极、方便回看的封面。主题：${package.title}。内容：${package.description}',
        purpose: 'learning_review_cover',
      );
      if (!mounted) return;
      final coverImageUrl = task.imagesUrl.isNotEmpty
          ? task.imagesUrl.first
          : 'vivo-task:${task.taskId}';
      final updated = await widget.controller.communityEvidenceService.updatePackage(
        package.id,
        coverImageUrl: coverImageUrl,
      );
      if (!mounted) return;
      final index = _cloudPackages.indexWhere((item) => item.id == package.id);
      setState(() {
        _lastCapabilityTraces = task.capabilityTraces;
        if (index >= 0) _cloudPackages[index] = updated;
      });
      unawaited(
        widget.controller.activityService
            .create(
              type: 'imageGenerated',
              title: task.imagesUrl.isNotEmpty ? '学习回顾封面已生成' : '学习回顾封面生成中',
              summary: package.title,
              sourceType: 'evidence_package',
              sourceId: package.id,
              payloadJson: {
                'taskId': task.taskId,
                'imageUrl': task.imagesUrl.isNotEmpty ? task.imagesUrl.first : '',
                'purpose': 'learning_review_cover',
              },
            )
            .catchError((_) {}),
      );
      _showSnack('回顾封面生成中，稍后刷新查看');
    } catch (_) {
      _showSnack('图片生成能力暂不可用，学习回顾内容不受影响');
    }
  }

  Future<void> _showNoGroupNextStep() async {
    final openStudyGroup = widget.onOpenStudyGroup;
    if (openStudyGroup == null) {
      _showSnack('先创建或加入学习小组，再同步给同伴');
      return;
    }
    final shouldOpen = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => _MomentsDialogSurface(
        isDarkMode: widget.isDarkMode,
        accent: widget.controller.primaryColor,
        icon: Icons.group_add_rounded,
        title: '还没有学习小组',
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '先创建或加入小组，再把学习回顾放进小组复盘空间。',
              style: TextStyle(
                color: StudyUi.body(widget.isDarkMode),
                fontSize: 13,
                height: 1.45,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                _MomentActionPill(
                  icon: Icons.lock_rounded,
                  label: '先留在这里',
                  accent: StudyUi.muted(widget.isDarkMode),
                  isDarkMode: widget.isDarkMode,
                  onPressed: () => Navigator.of(dialogContext).pop(false),
                ),
                const Spacer(),
                _MomentActionPill(
                  icon: Icons.group_add_rounded,
                  label: '去创建或加入',
                  accent: widget.controller.primaryColor,
                  isDarkMode: widget.isDarkMode,
                  isFilled: true,
                  onPressed: () => Navigator.of(dialogContext).pop(true),
                ),
              ],
            ),
          ],
        ),
      ),
    );
    if (shouldOpen == true && mounted) {
      openStudyGroup();
    }
  }

  Future<void> _sharePackageToGroup(cloud.EvidencePackage package) async {
    if (_groups.isEmpty) {
      await _showNoGroupNextStep();
      return;
    }
    final accent = widget.controller.primaryColor;
    final group = await showDialog<GroupInfo>(
      context: context,
      builder: (dialogContext) => _MomentsDialogSurface(
        isDarkMode: widget.isDarkMode,
        accent: accent,
        icon: Icons.groups_rounded,
        title: '同步到小组',
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '选择一个小组一起回看这份学习回顾，稍后仍会确认可见范围。',
              style: TextStyle(
                color: StudyUi.body(widget.isDarkMode),
                fontSize: 13,
                height: 1.45,
              ),
            ),
            const SizedBox(height: 12),
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 320),
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    for (final group in _groups)
                      _MomentGroupCheckTile(
                        title: group.name,
                        subtitle: group.memberCount > 0
                            ? '${group.memberCount} 位成员 · 小组复盘空间'
                            : '小组复盘空间',
                        selected: false,
                        accent: accent,
                        isDarkMode: widget.isDarkMode,
                        onTap: () => Navigator.of(dialogContext).pop(group),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 4),
            Align(
              alignment: Alignment.centerRight,
              child: _MomentActionPill(
                icon: Icons.close_rounded,
                label: '取消',
                accent: accent,
                isDarkMode: widget.isDarkMode,
                onPressed: () => Navigator.of(dialogContext).pop(),
              ),
            ),
          ],
        ),
      ),
    );
    if (group == null) return;
    final confirmed = await _confirmShareScope(
      title: '确认同步到小组',
      targetLabel: _trimConfirmText(package.title),
      visibility: LearningMomentVisibility.includeGroups,
      allowedGroupIds: [group.id],
      confirmText: '确认同步',
    );
    if (!confirmed) return;
    try {
      final updated = await widget.controller.communityEvidenceService.updatePackage(
        package.id,
        visibility: 'group',
        groupId: group.id,
      );
      if (!mounted) return;
      final index = _cloudPackages.indexWhere((item) => item.id == package.id);
      setState(() {
        if (index >= 0) _cloudPackages[index] = updated;
      });
      _showSnack('学习回顾已同步到 ${group.name}');
    } catch (_) {
      _showSnack('学习回顾同步失败，请稍后重试');
    }
  }

  Future<void> _togglePackageFeatured(cloud.EvidencePackage package) async {
    try {
      final updated = await widget.controller.communityEvidenceService.updatePackage(
        package.id,
        featured: !package.featured,
      );
      if (!mounted) return;
      final index = _cloudPackages.indexWhere((item) => item.id == package.id);
      setState(() {
        if (index >= 0) _cloudPackages[index] = updated;
      });
      _showSnack(updated.featured ? '已放到常看回顾' : '已移出常看回顾');
    } catch (_) {
      _showSnack('常看状态更新失败，请稍后重试');
    }
  }

  Future<void> _createLocationCheckIn() async {
    if (_isCheckingLocation) return;
    if (!widget.controller.isLoggedIn) {
      _showTip('登录后可保存校园地点，当前可先记录文字学迹');
      return;
    }
    final draft = await _showLocationCheckInDialog();
    if (draft == null || draft.title.isEmpty) return;
    if (!mounted) return;
    final confirmed = await _confirmShareScope(
      title: '确认地点记录范围',
      targetLabel: _trimConfirmText(draft.title),
      visibility: draft.shareToGroup
          ? LearningMomentVisibility.includeGroups
          : LearningMomentVisibility.private,
      allowedGroupIds:
          draft.shareToGroup && draft.groupId != null ? [draft.groupId!] : const [],
      confirmText: draft.shareToGroup ? '保存并同步' : '保存',
    );
    if (!confirmed || !mounted) return;
    setState(() => _isCheckingLocation = true);
    try {
      final checkIn =
          await widget.controller.communityEvidenceService.createLocationCheckIn(
        title: draft.title,
        address: _trimAddress(draft.city),
        groupId: draft.shareToGroup ? draft.groupId : null,
        visibility: draft.shareToGroup ? 'group' : 'private',
        poiPayloadJson: {
          'source': 'manual',
          'query': draft.title,
          if (draft.city.isNotEmpty) 'campusOrCity': draft.city,
        },
      );
      if (!mounted) return;
      setState(() => _locationCheckIns.insert(0, checkIn));
      unawaited(_loadCapabilityBadges());
      _showTip(draft.shareToGroup ? '地点已同步到小组学习记录' : '地点已保存为私密学习记录');
    } catch (_) {
      await _showDialogNotice(
        title: '地点保存失败',
        message: '这次没有保存成功，请稍后再试。',
      );
    } finally {
      if (mounted) setState(() => _isCheckingLocation = false);
    }
  }

  Future<_LocationCheckInDraft?> _showLocationCheckInDialog() async {
    final titleController = TextEditingController(
      text: _selectedCourse.trim().isEmpty ? '' : '${_selectedCourse.trim()} 自习',
    );
    final cityController = TextEditingController();
    var shareToGroup = false;
    var selectedGroupId = _selectedGroupId ??
        (_groups.isNotEmpty ? _groups.first.id : null);
    try {
	      return await showDialog<_LocationCheckInDraft>(
	        context: context,
	        builder: (dialogContext) {
	          return StatefulBuilder(
	            builder: (context, setDialogState) => _MomentsDialogSurface(
	              isDarkMode: widget.isDarkMode,
	              accent: StudyUi.pathCyan,
	              icon: Icons.location_on_rounded,
	              title: '手动地点记录',
	              child: Column(
	                mainAxisSize: MainAxisSize.min,
	                children: [
	                  TextField(
	                    controller: titleController,
	                    autofocus: true,
	                    style: TextStyle(color: StudyUi.title(widget.isDarkMode)),
	                    decoration: _momentInputDecoration(
	                      labelText: '学习地点',
	                      hintText: '图书馆三楼 / 信息楼自习室',
	                    ),
	                    onSubmitted: (_) => _popLocationDraft(
	                      dialogContext,
	                      titleController,
	                      cityController,
	                      shareToGroup,
	                      selectedGroupId,
	                    ),
	                  ),
	                  const SizedBox(height: 12),
	                  TextField(
	                    controller: cityController,
	                    style: TextStyle(color: StudyUi.title(widget.isDarkMode)),
	                    decoration: _momentInputDecoration(
	                      labelText: '校区或备注',
	                      hintText: '可选，如主校区 / 靠窗座位',
	                    ),
	                  ),
	                  if (_groups.isNotEmpty) ...[
	                    const SizedBox(height: 12),
	                    _MomentGroupCheckTile(
                      title: '同步到小组',
	                      subtitle: shareToGroup
	                          ? '这条地点记录会进入小组学迹'
	                          : '默认保存为私密学习记录',
	                      selected: shareToGroup,
	                      accent: StudyUi.pathCyan,
	                      isDarkMode: widget.isDarkMode,
	                      onTap: () => setDialogState(
	                        () => shareToGroup = !shareToGroup,
	                      ),
	                    ),
                    if (shareToGroup) ...[
                      const SizedBox(height: 8),
                      ..._groups.map(
                        (group) => _MomentGroupCheckTile(
                          title: group.name,
                          subtitle: '${group.memberCount} 人一起学习',
                          selected: selectedGroupId == group.id,
                          accent: StudyUi.pathCyan,
                          isDarkMode: widget.isDarkMode,
                          onTap: () => setDialogState(
                            () => selectedGroupId = group.id,
                          ),
                        ),
                      ),
                    ],
	                  ],
	                  const SizedBox(height: 16),
	                  Row(
	                    children: [
	                      _MomentActionPill(
	                        icon: Icons.close_rounded,
	                        label: '取消',
	                        accent: StudyUi.muted(widget.isDarkMode),
	                        isDarkMode: widget.isDarkMode,
	                        onPressed: () => Navigator.of(dialogContext).pop(),
	                      ),
	                      const Spacer(),
	                      _MomentActionPill(
	                        icon: Icons.check_rounded,
                        label: shareToGroup ? '保存并同步' : '保存',
	                        accent: StudyUi.pathCyan,
	                        isDarkMode: widget.isDarkMode,
	                        isFilled: true,
	                        onPressed: () => _popLocationDraft(
	                          dialogContext,
	                          titleController,
	                          cityController,
	                          shareToGroup,
	                          selectedGroupId,
	                        ),
	                      ),
	                    ],
	                  ),
	                ],
	              ),
	            ),
	          );
	        },
      );
    } finally {
      titleController.dispose();
      cityController.dispose();
    }
  }

  void _popLocationDraft(
    BuildContext dialogContext,
    TextEditingController titleController,
    TextEditingController cityController,
    bool shareToGroup,
    String? selectedGroupId,
  ) {
    final title = titleController.text.trim();
    if (title.isEmpty) return;
    Navigator.of(dialogContext).pop(
      _LocationCheckInDraft(
        title: title,
        city: cityController.text.trim(),
        shareToGroup: shareToGroup && selectedGroupId != null,
        groupId: selectedGroupId,
      ),
    );
  }

  String _trimAddress(String value) {
    final normalized = value.trim();
    if (normalized.length <= 240) return normalized;
    return normalized.substring(0, 240);
  }

  Future<bool> _publishMoment() async {
    final content = _contentController.text.trim();
    if (content.isEmpty && _imagePaths.isEmpty) {
      _showTip('写点学习收获，或至少添加一张图片');
      return false;
    }
    if (_visibility != LearningMomentVisibility.private &&
        !widget.controller.isLoggedIn) {
      _showTip('登录后可同步到小组，当前可先保存给自己');
      return false;
    }
    if (_visibility != LearningMomentVisibility.private && _groups.isEmpty) {
      await _showNoGroupNextStep();
      return false;
    }
    if (_visibility == LearningMomentVisibility.includeGroups &&
        _selectedAllowedGroupIds.isEmpty) {
      _showTip('请选择允许查看的小组，或切回私密');
      return false;
    }
    if (_visibility == LearningMomentVisibility.excludeGroups &&
        _selectedDeniedGroupIds.isEmpty) {
      _showTip('请选择不允许查看的小组，或切回私密');
      return false;
    }
    final confirmed = await _confirmShareScope(
      title: '确认可见范围',
      targetLabel: content.isEmpty ? '学习图片记录' : _trimConfirmText(content),
      visibility: _visibility,
      allowedGroupIds: _selectedAllowedGroupIds,
      deniedGroupIds: _selectedDeniedGroupIds,
      confirmText:
          _visibility == LearningMomentVisibility.private ? '保存' : '保存到小组',
    );
    if (!confirmed || !mounted) return false;
    setState(() => _isPosting = true);
    final publishedVisibility = _visibility;
    try {
      final text = content.isEmpty ? '记录了一组学习图片' : content;
      if (widget.controller.isLoggedIn) {
        final moment = await widget.controller.learningMomentService.create(
          content: text,
          courseName: _selectedCourse,
          imagePaths: List<String>.from(_imagePaths),
          visibility: _visibility,
          allowedGroupIds: List<String>.from(_selectedAllowedGroupIds),
          deniedGroupIds: List<String>.from(_selectedDeniedGroupIds),
        );
        _upsertCloudMoment(moment);
      } else {
        await widget.controller.publishLearningMoment(
          content: text,
          courseName: _selectedCourse,
          imagePaths: List<String>.from(_imagePaths),
          visibility: LearningMomentVisibility.private,
        );
      }
      if (!mounted) return false;
      setState(() {
        _contentController.clear();
        _imagePaths.clear();
        _selectedCourse = '';
        _selectedGroupId = null;
        _selectedAllowedGroupIds.clear();
        _selectedDeniedGroupIds.clear();
        _visibility = LearningMomentVisibility.private;
      });
      _showTip(publishedVisibility == LearningMomentVisibility.private
          ? '已保存私密学迹，可在时间线回看，也可整理成学习回顾'
          : '已保存到小组学迹，可一起回看，也可整理成学习回顾');
      return true;
    } catch (error) {
      _showTip(_friendlyCloudError(error, '学习记录保存失败，请稍后重试'));
      return false;
    } finally {
      if (mounted) setState(() => _isPosting = false);
    }
  }

  Future<void> _shareTraceEvent(LearningTraceEvent event) async {
    final confirmed = await _confirmShareScope(
      title: '确认保存范围',
      targetLabel: _trimConfirmText(event.title),
      visibility: LearningMomentVisibility.private,
      confirmText: '保存',
    );
    if (!confirmed) return;
    await widget.controller.shareTraceEvent(event);
    if (widget.controller.isLoggedIn) {
      unawaited(_loadMomentFeed());
    }
    _showTip('已保存到私密学迹，可在时间线回看，也可整理成学习回顾');
  }

  void _useEvidencePackage(_EvidencePackage package) {
    final validCourse = widget.controller.courseNames.contains(package.courseName)
        ? package.courseName
        : '';
    setState(() {
      _selectedCourse = validCourse;
      _contentController.text =
          '整理了「${package.courseName}」的学习回顾：${package.eventCount} 条记录、'
          '${package.aiCount} 次学习整理、${package.shareableCount} 条可回看记录。'
          '这些内容放在一起，方便回看最近怎么学、下一步做什么。';
    });
  }

  Future<void> _deleteMoment(String momentId) async {
    try {
      if (widget.controller.isLoggedIn && !_isLocalOnlyMomentId(momentId)) {
        LearningMoment? cloudMoment;
        for (final moment in _cloudMoments) {
          if (moment.id == momentId) {
            cloudMoment = moment;
            break;
          }
        }
        final syncedLocalId = cloudMoment == null
            ? null
            : _localPrivateMomentSourceId(cloudMoment);
        await widget.controller.learningMomentService.delete(momentId);
        if (syncedLocalId != null) {
          await widget.controller.deleteLearningMoment(syncedLocalId);
        }
        if (!mounted) return;
        setState(() {
          _cloudMoments.removeWhere(
            (moment) =>
                moment.id == momentId ||
                (syncedLocalId != null &&
                    _localPrivateMomentSourceId(moment) == syncedLocalId),
          );
        });
      } else {
        await widget.controller.deleteLearningMoment(momentId);
      }
      _showTip('已删除学迹');
    } catch (error) {
      _showTip(_friendlyCloudError(error, '学迹删除失败，请稍后重试'));
    }
  }

  Future<void> _toggleMomentLike(LearningMoment moment) async {
    if (!widget.controller.isLoggedIn) {
      _showTip('登录后可标记有帮助');
      return;
    }
    try {
      final updated = moment.likedByMe
          ? await widget.controller.learningMomentService.unlike(moment.id)
          : await widget.controller.learningMomentService.like(moment.id);
      _upsertCloudMoment(updated);
    } catch (error) {
      _showTip(_friendlyCloudError(error, '这次没有标记成功，请稍后重试'));
    }
  }

  Future<void> _commentMoment(LearningMoment moment) async {
    if (!widget.controller.isLoggedIn) {
      _showTip('登录后可留下回看备注');
      return;
    }
    final controller = TextEditingController();
	    try {
	      final text = await showDialog<String>(
	        context: context,
	        builder: (dialogContext) => _MomentsDialogSurface(
	          isDarkMode: widget.isDarkMode,
	          accent: widget.controller.primaryColor,
	          icon: Icons.mode_comment_rounded,
	          title: '写回看备注',
	          child: Column(
	            mainAxisSize: MainAxisSize.min,
	            children: [
	              TextField(
	                controller: controller,
	                autofocus: true,
	                maxLength: 500,
	                minLines: 2,
	                maxLines: 4,
	                style: TextStyle(color: StudyUi.title(widget.isDarkMode)),
	                decoration: _momentInputDecoration(hintText: '留下这次回看的想法...'),
	              ),
	              const SizedBox(height: 8),
	              Row(
	                children: [
	                  _MomentActionPill(
	                    icon: Icons.close_rounded,
	                    label: '取消',
	                    accent: StudyUi.muted(widget.isDarkMode),
	                    isDarkMode: widget.isDarkMode,
	                    onPressed: () => Navigator.of(dialogContext).pop(),
	                  ),
	                  const Spacer(),
	                  _MomentActionPill(
	                    icon: Icons.send_rounded,
	                    label: '发送',
	                    accent: widget.controller.primaryColor,
	                    isDarkMode: widget.isDarkMode,
	                    isFilled: true,
	                    onPressed: () => Navigator.of(dialogContext)
	                        .pop(controller.text.trim()),
	                  ),
	                ],
	              ),
	            ],
	          ),
	        ),
	      );
      if (text == null || text.isEmpty) return;
      final updated =
          await widget.controller.learningMomentService.comment(moment.id, text);
      _upsertCloudMoment(updated);
    } catch (error) {
      _showTip(_friendlyCloudError(error, '回看备注暂时没有保存成功，请稍后重试'));
    } finally {
      controller.dispose();
    }
  }

  Future<void> _deleteMomentComment(
    LearningMoment moment,
    LearningMomentComment comment,
  ) async {
    if (!comment.isMine && !moment.isMine) return;
    try {
      final updated = await widget.controller.learningMomentService
          .deleteComment(moment.id, comment.id);
      _upsertCloudMoment(updated);
    } catch (error) {
      _showTip(_friendlyCloudError(error, '回看备注暂时没有删除成功，请稍后重试'));
    }
  }

  Future<void> _editMomentVisibility(LearningMoment moment) async {
    if (!widget.controller.isLoggedIn) {
      _showTip('登录后可修改小组可见范围');
      return;
    }
    final result = await _showVisibilityEditor(
      initialVisibility: moment.visibility,
      initialAllowedIds: moment.allowedGroupIds,
      initialDeniedIds: moment.deniedGroupIds,
    );
    if (result == null) return;
    final confirmed = await _confirmShareScope(
      title: '确认新的可见范围',
      targetLabel: _trimConfirmText(moment.content),
      visibility: result.visibility,
      allowedGroupIds: result.allowedGroupIds,
      deniedGroupIds: result.deniedGroupIds,
      confirmText: '保存',
    );
    if (!confirmed) return;
    try {
      final updated = await widget.controller.learningMomentService.updateVisibility(
        momentId: moment.id,
        visibility: result.visibility,
        allowedGroupIds: result.allowedGroupIds,
        deniedGroupIds: result.deniedGroupIds,
      );
      _upsertCloudMoment(updated);
      _showTip('可见范围已更新');
    } catch (error) {
      _showTip(_friendlyCloudError(error, '可见范围更新失败，请稍后重试'));
    }
  }

  void _upsertCloudMoment(LearningMoment moment) {
    if (!mounted) return;
    setState(() {
      final sourceId = _localPrivateMomentSourceId(moment);
      final index = _cloudMoments.indexWhere(
        (item) =>
            item.id == moment.id ||
            (sourceId != null && _localPrivateMomentSourceId(item) == sourceId),
      );
      if (index >= 0) {
        _cloudMoments[index] = moment;
      } else {
        _cloudMoments.insert(0, moment);
      }
    });
  }

  Future<bool> _confirmShareScope({
    required String title,
    required String targetLabel,
    required LearningMomentVisibility visibility,
    List<String> allowedGroupIds = const [],
    List<String> deniedGroupIds = const [],
    required String confirmText,
  }) async {
    if (!mounted) return false;
    final scopeText = _visibilityScopeText(
      visibility,
      allowedGroupIds: allowedGroupIds,
      deniedGroupIds: deniedGroupIds,
    );
    final note = _visibilityScopeNote(visibility);
    final icon = _visibilityScopeIcon(visibility);
	    final confirmed = await showDialog<bool>(
	      context: context,
	      builder: (dialogContext) => _MomentsDialogSurface(
	        isDarkMode: widget.isDarkMode,
	        accent: widget.controller.primaryColor,
	        icon: icon,
	        title: title,
	        child: Column(
	          mainAxisSize: MainAxisSize.min,
	          crossAxisAlignment: CrossAxisAlignment.start,
	          children: [
	            Text(
	              targetLabel.isEmpty ? '这条学习内容' : targetLabel,
	              maxLines: 2,
	              overflow: TextOverflow.ellipsis,
	              style: TextStyle(color: StudyUi.title(widget.isDarkMode)),
	            ),
	            const SizedBox(height: 14),
	            Container(
	              padding: const EdgeInsets.all(12),
	              decoration: BoxDecoration(
	                color: StudyUi.surfaceAlt(widget.isDarkMode),
	                borderRadius: BorderRadius.circular(16),
	                border: Border.all(color: StudyUi.border(widget.isDarkMode)),
	              ),
	              child: Row(
	                crossAxisAlignment: CrossAxisAlignment.start,
	                children: [
	                  StudyGlassIconNode(
	                    icon: icon,
	                    accent: widget.controller.primaryColor,
	                    size: 34,
	                    iconSize: 16,
	                    isDarkMode: widget.isDarkMode,
	                  ),
	                  const SizedBox(width: 10),
	                  Expanded(
	                    child: Column(
	                      crossAxisAlignment: CrossAxisAlignment.start,
	                      children: [
	                        Text(
	                          scopeText,
	                          style: TextStyle(
	                            color: StudyUi.title(widget.isDarkMode),
	                            fontWeight: AppTypography.title,
	                          ),
	                        ),
	                        const SizedBox(height: 4),
	                        Text(
	                          note,
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
	              ),
	            ),
	            const SizedBox(height: 16),
	            Row(
	              children: [
	                _MomentActionPill(
	                  icon: Icons.close_rounded,
	                  label: '取消',
	                  accent: StudyUi.muted(widget.isDarkMode),
	                  isDarkMode: widget.isDarkMode,
	                  onPressed: () => Navigator.of(dialogContext).pop(false),
	                ),
	                const Spacer(),
	                _MomentActionPill(
	                  icon: Icons.check_rounded,
	                  label: confirmText,
	                  accent: widget.controller.primaryColor,
	                  isDarkMode: widget.isDarkMode,
	                  isFilled: true,
	                  onPressed: () => Navigator.of(dialogContext).pop(true),
	                ),
	              ],
	            ),
	          ],
	        ),
	      ),
	    );
    return confirmed == true;
  }

  String _visibilityScopeText(
    LearningMomentVisibility visibility, {
    List<String> allowedGroupIds = const [],
    List<String> deniedGroupIds = const [],
  }) {
    return switch (visibility) {
      LearningMomentVisibility.private => '仅自己可见',
      LearningMomentVisibility.public => '我的小组成员可见',
      LearningMomentVisibility.includeGroups =>
        '仅 ${_groupNames(allowedGroupIds)} 可见',
      LearningMomentVisibility.excludeGroups =>
        '除 ${_groupNames(deniedGroupIds)} 外的小组成员可见',
    };
  }

  String _visibilityScopeNote(LearningMomentVisibility visibility) {
    return switch (visibility) {
      LearningMomentVisibility.private => '默认留在自己的学习记录里。',
      LearningMomentVisibility.public => '保存后，可在小组复盘空间共同回看。',
      LearningMomentVisibility.includeGroups => '只有选中的小组成员能看到。',
      LearningMomentVisibility.excludeGroups => '选中的小组不会看到这条内容。',
    };
  }

  IconData _visibilityScopeIcon(LearningMomentVisibility visibility) {
    return switch (visibility) {
      LearningMomentVisibility.private => Icons.lock_rounded,
      LearningMomentVisibility.public => Icons.groups_rounded,
      LearningMomentVisibility.includeGroups => Icons.visibility_rounded,
      LearningMomentVisibility.excludeGroups => Icons.visibility_off_rounded,
    };
  }

  String _groupNames(List<String> ids) {
    if (ids.isEmpty) return '未选择小组';
    return ids.map((id) => _VisibilityPicker._groupName(_groups, id)).join('、');
  }

  String _trimConfirmText(String value) {
    final normalized = value.trim().replaceAll('\n', ' ');
    if (normalized.length <= 36) return normalized;
    return '${normalized.substring(0, 36)}...';
  }

  Future<List<String>?> _showGroupMultiSelect({
    required String title,
    required List<String> initialIds,
  }) async {
    final selected = initialIds.toSet();
    return showModalBottomSheet<List<String>>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, setSheetState) => _MomentsSheetSurface(
          isDarkMode: widget.isDarkMode,
          accent: widget.controller.primaryColor,
          icon: Icons.groups_rounded,
          title: title,
          subtitle: '选择后，这条学迹会放入对应小组的复盘空间。',
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (_groups.isEmpty)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: StudyUi.surfaceAlt(widget.isDarkMode),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: StudyUi.border(widget.isDarkMode)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '还没有学习小组',
                        style: TextStyle(
                          color: StudyUi.title(widget.isDarkMode),
                          fontWeight: AppTypography.title,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '先创建或加入小组，再把这条学迹放进小组复盘空间。',
                        style: TextStyle(
                          color: StudyUi.body(widget.isDarkMode),
                          fontSize: 12,
                          height: 1.35,
                        ),
                      ),
                      if (widget.onOpenStudyGroup != null) ...[
                        const SizedBox(height: 12),
                        _MomentActionPill(
                          icon: Icons.group_add_rounded,
                          label: '去创建或加入',
                          accent: widget.controller.primaryColor,
                          isDarkMode: widget.isDarkMode,
                          isFilled: true,
                          onPressed: () {
                            Navigator.of(sheetContext).pop();
                            widget.onOpenStudyGroup?.call();
                          },
                        ),
                      ],
                    ],
                  ),
                )
              else
                ..._groups.map(
                  (group) => _MomentGroupCheckTile(
                    title: group.name,
                    subtitle: '${group.memberCount} 人一起学习',
                    selected: selected.contains(group.id),
                    accent: widget.controller.primaryColor,
                    isDarkMode: widget.isDarkMode,
                    onTap: () {
                      setSheetState(() {
                        if (selected.contains(group.id)) {
                          selected.remove(group.id);
                        } else {
                          selected.add(group.id);
                        }
                      });
                    },
                  ),
                ),
              const SizedBox(height: 8),
              Row(
                children: [
                  _MomentActionPill(
                    icon: Icons.close_rounded,
                    label: '取消',
                    accent: StudyUi.muted(widget.isDarkMode),
                    isDarkMode: widget.isDarkMode,
                    onPressed: () => Navigator.of(sheetContext).pop(),
                  ),
                  const Spacer(),
                  _MomentActionPill(
                    icon: Icons.check_rounded,
                    label: '确定',
                    accent: widget.controller.primaryColor,
                    isDarkMode: widget.isDarkMode,
                    isFilled: true,
                    onPressed: _groups.isEmpty
                        ? null
                        : () =>
                            Navigator.of(sheetContext).pop(selected.toList()),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<_VisibilityDraft?> _showVisibilityEditor({
    required LearningMomentVisibility initialVisibility,
    required List<String> initialAllowedIds,
    required List<String> initialDeniedIds,
  }) async {
    var visibility = initialVisibility;
    final allowed = initialAllowedIds.toList();
    final denied = initialDeniedIds.toList();
    return showModalBottomSheet<_VisibilityDraft>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, setSheetState) => _MomentsSheetSurface(
          isDarkMode: widget.isDarkMode,
          accent: widget.controller.primaryColor,
          icon: Icons.visibility_rounded,
          title: '可见范围',
          subtitle: '决定这条学迹是私密记录，还是进入指定小组学迹。',
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _VisibilityPicker(
                isDarkMode: widget.isDarkMode,
                accent: widget.controller.primaryColor,
                groups: _groups,
                onOpenStudyGroup: widget.onOpenStudyGroup,
                visibility: visibility,
                allowedGroupIds: allowed,
                deniedGroupIds: denied,
                onVisibilityChanged: (value) {
                  setSheetState(() {
                    visibility = value;
                    if (value != LearningMomentVisibility.includeGroups) {
                      allowed.clear();
                    }
                    if (value != LearningMomentVisibility.excludeGroups) {
                      denied.clear();
                    }
                  });
                },
                onChooseGroups: (mode) async {
                  final selected = await _showGroupMultiSelect(
                    title: mode == LearningMomentVisibility.includeGroups
                        ? '指定小组可以看'
                        : '指定小组不可看',
                    initialIds: mode == LearningMomentVisibility.includeGroups
                        ? allowed
                        : denied,
                  );
                  if (selected == null) return;
                  setSheetState(() {
                    if (mode == LearningMomentVisibility.includeGroups) {
                      allowed
                        ..clear()
                        ..addAll(selected);
                    } else {
                      denied
                        ..clear()
                        ..addAll(selected);
                    }
                  });
                },
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  _MomentActionPill(
                    icon: Icons.close_rounded,
                    label: '取消',
                    accent: StudyUi.muted(widget.isDarkMode),
                    isDarkMode: widget.isDarkMode,
                    onPressed: () => Navigator.of(sheetContext).pop(),
                  ),
                  const Spacer(),
                  _MomentActionPill(
                    icon: Icons.check_rounded,
                    label: '保存',
                    accent: widget.controller.primaryColor,
                    isDarkMode: widget.isDarkMode,
                    isFilled: true,
                    onPressed: () {
                      if (visibility == LearningMomentVisibility.includeGroups &&
                          allowed.isEmpty) {
                        _showTip('请选择允许查看的小组');
                        return;
                      }
                      if (visibility == LearningMomentVisibility.excludeGroups &&
                          denied.isEmpty) {
                        _showTip('请选择不允许查看的小组');
                        return;
                      }
                      Navigator.of(sheetContext).pop(_VisibilityDraft(
                        visibility,
                        allowed,
                        denied,
                      ));
                    },
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showSnack(String message) {
    _showTip(message);
  }

  String _friendlyCloudError(Object error, String fallback) {
    if (error is ApiException) {
      final message = error.displayMessage.trim();
      if (message.isNotEmpty) return message;
    }
    return fallback;
  }

  void _showTip(String message) {
    if (!mounted) return;
    StudyToast.show(context, message);
  }

  Future<void> _showDialogNotice({
    required String title,
    required String message,
  }) async {
    if (!mounted) return;
    await StudyToast.dialog(context, title: title, message: message);
  }
}

class _HeaderPanel extends StatelessWidget {
  const _HeaderPanel({
    required this.isDarkMode,
    required this.eventCount,
    required this.momentCount,
    required this.packageCount,
    required this.learningLoopCount,
    required this.latestLearningLoopLabel,
    required this.onRecord,
    required this.onReview,
    required this.onRefresh,
  });

  final bool isDarkMode;
  final int eventCount;
  final int momentCount;
  final int packageCount;
  final int learningLoopCount;
  final String? latestLearningLoopLabel;
  final VoidCallback onRecord;
  final VoidCallback onReview;
  final VoidCallback? onRefresh;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(2, 2, 2, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              StudyGlassIconNode(
                icon: Icons.dynamic_feed_rounded,
                accent: StudyUi.pathViolet,
                size: 42,
                iconSize: 20,
                isDarkMode: isDarkMode,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '学迹',
                      style: TextStyle(
                        color: StudyUi.title(isDarkMode),
                        fontSize: 24,
                        fontWeight: AppTypography.hero,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _summaryText,
                      style: TextStyle(
                        color: StudyUi.body(isDarkMode),
                        fontSize: 13,
                        height: 1.42,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _MomentHeaderChip(
                label: '记录 $eventCount',
                icon: Icons.edit_note_rounded,
                color: StudyUi.pathBlue,
                isDarkMode: isDarkMode,
              ),
              _MomentHeaderChip(
                label: '学迹 $momentCount',
                icon: Icons.dynamic_feed_rounded,
                color: StudyUi.pathMint,
                isDarkMode: isDarkMode,
              ),
              _MomentHeaderChip(
                label: '回顾 $packageCount',
                icon: Icons.auto_stories_rounded,
                color: StudyUi.pathViolet,
                isDarkMode: isDarkMode,
              ),
              if (learningLoopCount > 0)
                _MomentHeaderChip(
                  label: '整理 $learningLoopCount',
                  icon: Icons.auto_awesome_rounded,
                  color: StudyUi.secondary,
                  isDarkMode: isDarkMode,
                ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _MomentActionPill(
                icon: Icons.add_rounded,
                label: '记录学迹',
                accent: StudyUi.pathViolet,
                isDarkMode: isDarkMode,
                onPressed: onRecord,
              ),
              _MomentActionPill(
                icon: Icons.auto_stories_rounded,
                label: '整理回顾',
                accent: StudyUi.pathBlue,
                isDarkMode: isDarkMode,
                onPressed: onReview,
              ),
              _MomentActionPill(
                icon: Icons.refresh_rounded,
                label: '刷新',
                accent: StudyUi.pathMint,
                isDarkMode: isDarkMode,
                onPressed: onRefresh,
              ),
            ],
          ),
        ],
      ),
    );
  }

  String get _summaryText {
    if (learningLoopCount > 0) {
      final latest = latestLearningLoopLabel;
      if (latest != null && latest.isNotEmpty) {
        return '最近已有 $learningLoopCount 条学习整理沉淀进学迹，$latest，适合顺着下一步继续学。';
      }
      return '最近已有 $learningLoopCount 条学习整理沉淀进学迹，适合顺着下一步继续学。';
    }
    if (momentCount == 0 && eventCount == 0) {
      return '先记录一条学习瞬间，后面再慢慢整理回顾。';
    }
    if (momentCount == 0) {
      return '已有学习记录，可以挑一条写成学迹。';
    }
    return '最近有 $momentCount 条学迹，适合回看学习过程。';
  }
}

class _MomentHeaderChip extends StatelessWidget {
  const _MomentHeaderChip({
    required this.label,
    required this.icon,
    required this.color,
    required this.isDarkMode,
  });

  final String label;
  final IconData icon;
  final Color color;
  final bool isDarkMode;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: isDarkMode ? 0.05 : 0.54),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.16)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 14),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              color: StudyUi.body(isDarkMode),
              fontSize: 12,
              fontWeight: AppTypography.emphasis,
            ),
          ),
        ],
      ),
    );
  }
}

class _PostEntryCard extends StatelessWidget {
  const _PostEntryCard({
    required this.isDarkMode,
    required this.accent,
    required this.titleColor,
    required this.bodyColor,
    required this.avatarImagePath,
    required this.avatarEmoji,
    required this.onTap,
  });

  final bool isDarkMode;
  final Color accent;
  final Color titleColor;
  final Color bodyColor;
  final String? avatarImagePath;
  final String avatarEmoji;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        decoration: BoxDecoration(
          color: StudyUi.surface(isDarkMode),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: StudyUi.border(isDarkMode),
          ),
          boxShadow: [
            BoxShadow(
              color: accent.withValues(alpha: isDarkMode ? 0.08 : 0.12),
              blurRadius: 22,
              offset: const Offset(0, 12),
            ),
          ],
        ),
        child: Column(
          children: [
            Row(
              children: [
                StudyUserAvatar(
                  avatarImagePath: avatarImagePath,
                  avatarEmoji: avatarEmoji,
                  accent: accent,
                  size: 44,
                  isDarkMode: isDarkMode,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '记录这次学习...',
                        style: TextStyle(
                          color: titleColor,
                          fontSize: 14,
                          fontWeight: AppTypography.emphasis,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '现场、错题、板书或阶段整理都可以留下',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: bodyColor, fontSize: 12),
                      ),
                    ],
                  ),
                ),
                _MomentActionPill(
                  icon: Icons.edit_rounded,
                  label: '保存记录',
                  accent: accent,
                  isDarkMode: isDarkMode,
                  onPressed: onTap,
                ),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              children: const [
                _MomentToolChip(icon: Icons.menu_book_rounded),
                SizedBox(width: 10),
                _MomentToolChip(icon: Icons.image_rounded),
                SizedBox(width: 10),
                _MomentToolChip(icon: Icons.edit_note_rounded),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _MomentToolChip extends StatelessWidget {
  const _MomentToolChip({required this.icon});

  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Expanded(
      child: Container(
        height: 42,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: StudyUi.surfaceAlt(dark).withValues(alpha: dark ? 0.72 : 0.86),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: StudyUi.border(dark)),
        ),
        child: Icon(icon, color: StudyUi.muted(dark), size: 20),
      ),
    );
  }
}

class _CapabilityBadgePanel extends StatelessWidget {
  const _CapabilityBadgePanel({
    required this.isDarkMode,
    required this.accent,
    required this.titleColor,
    required this.bodyColor,
    required this.badges,
    required this.traces,
  });

  final bool isDarkMode;
  final Color accent;
  final Color titleColor;
  final Color bodyColor;
  final List<_CapabilityBadge> badges;
  final List<AiCapabilityTrace> traces;

  @override
  Widget build(BuildContext context) {
    final unlockedCount = badges.where((badge) => badge.unlocked).length;
    final totalProgress = badges.isEmpty ? 0.0 : unlockedCount / badges.length;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDarkMode ? const Color(0xFF1E2533) : Colors.white,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              StudyAssetIcon(
                asset: AppAssets.sideAchievementsIcon,
                color: accent,
                size: 22,
                fallbackIcon: Icons.verified_rounded,
              ),
              const SizedBox(width: 8),
              Text(
                '学习能力线索',
                style: TextStyle(
                  color: titleColor,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Expanded(
                child: Text(
                  '根据最近记录整理你用过的学习方式，方便下次接着尝试。',
                  style: TextStyle(color: bodyColor, fontSize: 12, height: 1.35),
                ),
              ),
              BadgePill(
                label: '$unlockedCount/${badges.length} 有记录',
                background: accent.withValues(alpha: 0.12),
                foreground: accent,
              ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: totalProgress,
              minHeight: 6,
              backgroundColor: bodyColor.withValues(alpha: 0.12),
              valueColor: AlwaysStoppedAnimation<Color>(accent),
            ),
          ),
          const SizedBox(height: 12),
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: badges.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (context, index) => _CapabilityBadgeTile(
              badge: badges[index],
              isDarkMode: isDarkMode,
              accent: accent,
              titleColor: titleColor,
              bodyColor: bodyColor,
            ),
          ),
          if (traces.isNotEmpty) ...[
            const SizedBox(height: 8),
            ...traces.take(2).map(
                  (trace) => Text(
                    '${trace.abilityName} · ${trace.success ? '已调用' : '失败'} · ${trace.durationMs} ms',
                    style: TextStyle(color: bodyColor, fontSize: 11),
                  ),
                ),
          ],
        ],
      ),
    );
  }
}

class _CapabilityBadgeTile extends StatelessWidget {
  const _CapabilityBadgeTile({
    required this.badge,
    required this.isDarkMode,
    required this.accent,
    required this.titleColor,
    required this.bodyColor,
  });

  final _CapabilityBadge badge;
  final bool isDarkMode;
  final Color accent;
  final Color titleColor;
  final Color bodyColor;

  @override
  Widget build(BuildContext context) {
    final progress = badge.target <= 0
        ? 0.0
        : (badge.current / badge.target).clamp(0.0, 1.0).toDouble();
    final statusText = badge.unlocked ? '已有记录' : '待尝试';
    final levelText = progress >= 1
        ? '进度 3'
        : progress >= 0.66
            ? '进度 2'
            : progress > 0
                ? '进度 1'
                : '进度 0';
    return Opacity(
      opacity: badge.unlocked ? 1 : 0.58,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: badge.unlocked
              ? accent.withValues(alpha: isDarkMode ? 0.18 : 0.1)
              : (isDarkMode
                  ? Colors.white.withValues(alpha: 0.05)
                  : StudyUi.surfaceAlt(isDarkMode)),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: badge.unlocked
                ? accent.withValues(alpha: 0.22)
                : bodyColor.withValues(alpha: 0.12),
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              alignment: Alignment.bottomRight,
              children: [
                Container(
                  width: 58,
                  height: 58,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: isDarkMode ? 0.08 : 0.72),
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(6),
                    child: StudyAssetIcon(
                      asset: badge.iconAsset,
                      size: 46,
                      color: accent,
                      fallbackIcon: Icons.auto_awesome_rounded,
                      preserveColor: true,
                    ),
                  ),
                ),
                Icon(
                  badge.unlocked
                      ? Icons.check_circle_rounded
                      : Icons.lock_outline_rounded,
                  color: badge.unlocked ? accent : bodyColor,
                  size: 18,
                ),
              ],
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          badge.label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: badge.unlocked ? titleColor : bodyColor,
                            fontWeight: FontWeight.w900,
                            fontSize: 14,
                          ),
                        ),
                      ),
                      BadgePill(
                        label: '$levelText · $statusText',
                        background: badge.unlocked
                            ? accent.withValues(alpha: 0.12)
                            : bodyColor.withValues(alpha: 0.1),
                        foreground: badge.unlocked ? accent : bodyColor,
                      ),
                    ],
                  ),
                  const SizedBox(height: 5),
                  Text(
                    badge.source.isEmpty ? badge.nextStep : badge.source,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: bodyColor, fontSize: 12, height: 1.3),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(999),
                          child: LinearProgressIndicator(
                            value: progress,
                            minHeight: 5,
                            backgroundColor: bodyColor.withValues(alpha: 0.14),
                            valueColor: AlwaysStoppedAnimation<Color>(accent),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '${badge.current.clamp(0, badge.target)}/${badge.target}',
                        style: TextStyle(
                          color: bodyColor,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                  if (!badge.unlocked && badge.nextStep.isNotEmpty) ...[
                    const SizedBox(height: 5),
                    Text(
                      '下一步：${badge.nextStep}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: bodyColor, fontSize: 11),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CampusMapPanel extends StatelessWidget {
  const _CampusMapPanel({
    required this.isDarkMode,
    required this.accent,
    required this.titleColor,
    required this.bodyColor,
    required this.locations,
    required this.isCheckingLocation,
    required this.onCheckIn,
  });

  final bool isDarkMode;
  final Color accent;
  final Color titleColor;
  final Color bodyColor;
  final List<cloud.LocationCheckIn> locations;
  final bool isCheckingLocation;
  final FutureOr<void> Function() onCheckIn;

  @override
  Widget build(BuildContext context) {
    final recent = locations.take(6).toList();
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDarkMode ? const Color(0xFF1E2533) : Colors.white,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.edit_location_alt_rounded, color: accent, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '手动地点记录',
                  style: TextStyle(
                    color: titleColor,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              Text(
                '${locations.length} 条记录',
                style: TextStyle(color: bodyColor, fontSize: 12),
              ),
              const SizedBox(width: 8),
              _MomentToolbarAction(
                tooltip: '手动记录地点',
                icon: Icons.edit_location_alt_rounded,
                accent: accent,
                isDarkMode: isDarkMode,
                onPressed: isCheckingLocation ? null : () => onCheckIn(),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (recent.isEmpty)
            Text(
              '还没有手动地点记录',
              style: TextStyle(color: bodyColor, fontSize: 13),
            )
          else
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: recent
                  .map(
                    (location) => Container(
                      width: 220,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: accent.withValues(alpha: isDarkMode ? 0.14 : 0.08),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: accent.withValues(alpha: 0.14),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.place_rounded,
                                color: accent,
                                size: 16,
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  location.title,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: titleColor,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(
                            _locationMeta(location),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(color: bodyColor, fontSize: 12),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              _MiniTag(
                                label: location.visibility == 'group'
                                    ? '小组'
                                    : '私密',
                                accent: accent,
                                isDarkMode: isDarkMode,
                              ),
                              const Spacer(),
                              Text(
                                _dateLabel(location.createdAt),
                                style: TextStyle(color: bodyColor, fontSize: 11),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  )
                  .toList(),
            ),
        ],
      ),
    );
  }

  String _locationMeta(cloud.LocationCheckIn location) {
    if (location.address.trim().isNotEmpty) return location.address.trim();
    return '手动地点';
  }

  String _dateLabel(DateTime? value) {
    if (value == null) return '';
    return '${value.month}/${value.day}';
  }
}

class _MiniTag extends StatelessWidget {
  const _MiniTag({
    required this.label,
    required this.accent,
    required this.isDarkMode,
  });

  final String label;
  final Color accent;
  final bool isDarkMode;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: isDarkMode
            ? Colors.white.withValues(alpha: 0.06)
            : Colors.white.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: accent,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _VisibilityDraft {
  const _VisibilityDraft(
    this.visibility,
    this.allowedGroupIds,
    this.deniedGroupIds,
  );

  final LearningMomentVisibility visibility;
  final List<String> allowedGroupIds;
  final List<String> deniedGroupIds;
}

class _VisibilityOption {
  const _VisibilityOption(
    this.visibility,
    this.icon,
    this.title,
    this.subtitle,
  );

  final LearningMomentVisibility visibility;
  final IconData icon;
  final String title;
  final String subtitle;
}

class _VisibilityOptionTile extends StatelessWidget {
  const _VisibilityOptionTile({
    required this.option,
    required this.selected,
    required this.isDarkMode,
    required this.accent,
    required this.titleColor,
    required this.bodyColor,
    required this.onTap,
  });

  final _VisibilityOption option;
  final bool selected;
  final bool isDarkMode;
  final Color accent;
  final Color titleColor;
  final Color bodyColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
          decoration: BoxDecoration(
            color: selected
                ? StudyUi.chipBackground(accent, isDarkMode)
                : StudyUi.surface(isDarkMode).withValues(alpha: 0.78),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: selected
                  ? accent.withValues(alpha: isDarkMode ? 0.36 : 0.26)
                  : StudyUi.border(isDarkMode),
            ),
          ),
          child: Row(
            children: [
              StudyGlassIconNode(
                icon: option.icon,
                accent: selected ? accent : StudyUi.muted(isDarkMode),
                size: 34,
                iconSize: 17,
                isDarkMode: isDarkMode,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      option.title,
                      style: TextStyle(
                        color: selected ? accent : titleColor,
                        fontWeight: AppTypography.emphasis,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      option.subtitle,
                      style: TextStyle(color: bodyColor, fontSize: 12),
                    ),
                  ],
                ),
              ),
              Icon(
                selected
                    ? Icons.check_circle_rounded
                    : Icons.radio_button_unchecked_rounded,
                color: selected ? accent : StudyUi.muted(isDarkMode),
                size: 19,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MomentSelectionChip extends StatelessWidget {
  const _MomentSelectionChip({
    required this.label,
    required this.accent,
    required this.isDarkMode,
  });

  final String label;
  final Color accent;
  final bool isDarkMode;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
      decoration: BoxDecoration(
        color: StudyUi.chipBackground(accent, isDarkMode),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: accent.withValues(alpha: 0.20)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.check_rounded, size: 15, color: accent),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              color: StudyUi.title(isDarkMode),
              fontSize: 12,
              fontWeight: AppTypography.emphasis,
            ),
          ),
        ],
      ),
    );
  }
}

class _CourseSelectorField extends StatelessWidget {
  const _CourseSelectorField({
    required this.isDarkMode,
    required this.accent,
    required this.titleColor,
    required this.bodyColor,
    required this.courses,
    required this.currentCourse,
    required this.onChanged,
  });

  final bool isDarkMode;
  final Color accent;
  final Color titleColor;
  final Color bodyColor;
  final List<String> courses;
  final String currentCourse;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    final selectedLabel =
        currentCourse.trim().isEmpty ? '不关联课程' : currentCourse.trim();
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () => _openCoursePicker(context),
        child: Container(
          padding: const EdgeInsets.fromLTRB(12, 11, 12, 11),
          decoration: BoxDecoration(
            color: StudyUi.surfaceAlt(isDarkMode),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: StudyUi.border(isDarkMode)),
          ),
          child: Row(
            children: [
              StudyGlassIconNode(
                icon: Icons.school_rounded,
                accent: accent,
                size: 38,
                iconSize: 18,
                isDarkMode: isDarkMode,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      selectedLabel,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: titleColor,
                        fontSize: 14,
                        fontWeight: AppTypography.emphasis,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '关联课程后，学习回顾会自动归档到对应学习路径。',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: bodyColor, fontSize: 12),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(
                Icons.keyboard_arrow_down_rounded,
                color: bodyColor,
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _openCoursePicker(BuildContext context) async {
    final options = {
      for (final course in courses)
        if (course.trim().isNotEmpty) course.trim(),
    }.toList(growable: false);
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => _MomentsSheetSurface(
        isDarkMode: isDarkMode,
        accent: accent,
        icon: Icons.school_rounded,
        title: '关联课程',
        subtitle: '选择这条学迹属于哪门课，或保持不关联。',
        child: Column(
          children: [
            _MomentGroupCheckTile(
              title: '不关联课程',
              subtitle: '保存为通用学习现场，之后仍可整理进回顾。',
              selected: currentCourse.trim().isEmpty,
              accent: accent,
              isDarkMode: isDarkMode,
              onTap: () {
                Navigator.of(sheetContext).pop();
                onChanged(null);
              },
            ),
            for (final course in options)
              _MomentGroupCheckTile(
                title: course,
                subtitle: '归入「$course」的学习路径和学习回顾。',
                selected: currentCourse.trim() == course,
                accent: accent,
                isDarkMode: isDarkMode,
                onTap: () {
                  Navigator.of(sheetContext).pop();
                  onChanged(course);
                },
              ),
            if (options.isEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  '还没有课程记录，先保存为通用学迹也没问题。',
                  style: TextStyle(color: bodyColor, fontSize: 12),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _VisibilityPicker extends StatelessWidget {
  const _VisibilityPicker({
    required this.isDarkMode,
    required this.accent,
    required this.groups,
    this.onOpenStudyGroup,
    required this.visibility,
    required this.allowedGroupIds,
    required this.deniedGroupIds,
    required this.onVisibilityChanged,
    required this.onChooseGroups,
  });

  final bool isDarkMode;
  final Color accent;
  final List<GroupInfo> groups;
  final VoidCallback? onOpenStudyGroup;
  final LearningMomentVisibility visibility;
  final List<String> allowedGroupIds;
  final List<String> deniedGroupIds;
  final ValueChanged<LearningMomentVisibility> onVisibilityChanged;
  final FutureOr<void> Function(LearningMomentVisibility visibility)
      onChooseGroups;

  @override
  Widget build(BuildContext context) {
    final activeIds = visibility == LearningMomentVisibility.includeGroups
        ? allowedGroupIds
        : visibility == LearningMomentVisibility.excludeGroups
            ? deniedGroupIds
            : const <String>[];
    final hasGroups = groups.isNotEmpty;
    final showGroups = hasGroups &&
        (visibility == LearningMomentVisibility.includeGroups ||
            visibility == LearningMomentVisibility.excludeGroups);
    final titleColor = StudyUi.title(isDarkMode);
    final bodyColor = StudyUi.body(isDarkMode);
    const options = [
      _VisibilityOption(
        LearningMomentVisibility.private,
        Icons.lock_rounded,
        '私密',
        '仅自己可见',
      ),
      _VisibilityOption(
        LearningMomentVisibility.public,
        Icons.groups_rounded,
        '我的所有小组可见',
        '我的小组成员可见',
      ),
      _VisibilityOption(
        LearningMomentVisibility.includeGroups,
        Icons.visibility_rounded,
        '指定小组可见',
        '只让选中的小组看',
      ),
      _VisibilityOption(
        LearningMomentVisibility.excludeGroups,
        Icons.visibility_off_rounded,
        '指定小组不可见',
        '选中的小组不允许看',
      ),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '可见范围',
          style: TextStyle(
            color: titleColor,
            fontWeight: AppTypography.title,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          '默认只有你自己能看到。',
          style: TextStyle(color: bodyColor, fontSize: 12),
        ),
        const SizedBox(height: 8),
        ...options.where((option) {
          return hasGroups ||
              option.visibility == LearningMomentVisibility.private;
        }).map(
          (option) => Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: _VisibilityOptionTile(
              option: option,
              selected: visibility == option.visibility,
              isDarkMode: isDarkMode,
              accent: accent,
              titleColor: titleColor,
              bodyColor: bodyColor,
              onTap: () => onVisibilityChanged(option.visibility),
            ),
          ),
        ),
        if (!hasGroups) ...[
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: StudyUi.surfaceAlt(isDarkMode),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: StudyUi.border(isDarkMode)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '想同步给同伴？先创建或加入学习小组。',
                  style: TextStyle(
                    color: titleColor,
                    fontSize: 12,
                    fontWeight: AppTypography.emphasis,
                  ),
                ),
                if (onOpenStudyGroup != null) ...[
                  const SizedBox(height: 10),
                  _MomentActionPill(
                    icon: Icons.group_add_rounded,
                    label: '去创建或加入',
                    accent: accent,
                    isDarkMode: isDarkMode,
                    onPressed: () {
                      Navigator.of(context).pop();
                      onOpenStudyGroup?.call();
                    },
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 8),
        ],
        if (showGroups) ...[
          const SizedBox(height: 2),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              ...activeIds.map(
                (id) => _MomentSelectionChip(
                  label: _groupName(groups, id),
                  accent: accent,
                  isDarkMode: isDarkMode,
                ),
              ),
              _MomentActionPill(
                icon: Icons.group_add_rounded,
                label: activeIds.isEmpty ? '选择小组' : '重新选择',
                accent: accent,
                isDarkMode: isDarkMode,
                onPressed: () => onChooseGroups(visibility),
              ),
            ],
          ),
        ],
      ],
    );
  }

  static String _groupName(List<GroupInfo> groups, String id) {
    for (final group in groups) {
      if (group.id == id) return group.name;
    }
    return '这个小组';
  }
}

class _ComposerCard extends StatelessWidget {
  const _ComposerCard({
    required this.scrollController,
    required this.isDarkMode,
    required this.accent,
    required this.titleColor,
    required this.bodyColor,
    required this.controller,
    required this.courses,
    required this.groups,
    this.onOpenStudyGroup,
    required this.selectedCourse,
    required this.visibility,
    required this.selectedAllowedGroupIds,
    required this.selectedDeniedGroupIds,
    required this.imagePaths,
    required this.isPosting,
    required this.onCourseChanged,
    required this.onVisibilityChanged,
    required this.onChooseGroups,
    required this.onPickImages,
    required this.onRemoveImage,
    required this.onPost,
  });

  final ScrollController scrollController;
  final bool isDarkMode;
  final Color accent;
  final Color titleColor;
  final Color bodyColor;
  final TextEditingController controller;
  final List<String> courses;
  final List<GroupInfo> groups;
  final VoidCallback? onOpenStudyGroup;
  final String selectedCourse;
  final LearningMomentVisibility visibility;
  final List<String> selectedAllowedGroupIds;
  final List<String> selectedDeniedGroupIds;
  final List<String> imagePaths;
  final bool isPosting;
  final ValueChanged<String?> onCourseChanged;
  final ValueChanged<LearningMomentVisibility> onVisibilityChanged;
  final FutureOr<void> Function(LearningMomentVisibility visibility)
      onChooseGroups;
  final FutureOr<void> Function() onPickImages;
  final ValueChanged<String> onRemoveImage;
  final FutureOr<void> Function() onPost;

  @override
  Widget build(BuildContext context) {
    final currentCourse =
        selectedCourse.isNotEmpty && courses.contains(selectedCourse)
            ? selectedCourse
            : '';
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: StudyUi.surface(isDarkMode),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: StudyUi.border(isDarkMode)),
      ),
      child: SingleChildScrollView(
        controller: scrollController,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 42,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: bodyColor.withValues(alpha: 0.24),
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
            ),
            Row(
              children: [
                StudyGlassIconNode(
                  icon: Icons.edit_note_rounded,
                  accent: accent,
                  size: 42,
                  iconSize: 20,
                  isDarkMode: isDarkMode,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '记录学迹',
                        style: TextStyle(
                          color: titleColor,
                          fontSize: 18,
                          fontWeight: AppTypography.title,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '记录学习现场、错题、板书或阶段整理。',
                        style: TextStyle(color: bodyColor, fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            Container(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
              decoration: BoxDecoration(
                color: StudyUi.surfaceAlt(isDarkMode),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: StudyUi.border(isDarkMode)),
              ),
              child: TextField(
                controller: controller,
                minLines: 5,
                maxLines: 8,
                style: TextStyle(color: titleColor, fontSize: 14),
                decoration: InputDecoration(
                  hintText: '今天学了什么？拍到的板书、课件、错题也可以一起保存。',
                  hintStyle: TextStyle(color: bodyColor),
                  border: InputBorder.none,
                  isCollapsed: true,
                ),
              ),
            ),
            if (imagePaths.isNotEmpty) ...[
              const SizedBox(height: 10),
              _ImageGrid(
                paths: imagePaths,
                isDarkMode: isDarkMode,
                onRemove: onRemoveImage,
              ),
            ],
            const SizedBox(height: 12),
            Column(
              children: [
                _CourseSelectorField(
                  isDarkMode: isDarkMode,
                  accent: accent,
                  titleColor: titleColor,
                  bodyColor: bodyColor,
                  courses: courses,
                  currentCourse: currentCourse,
                  onChanged: onCourseChanged,
                ),
                const SizedBox(height: 10),
                _VisibilityPicker(
                  isDarkMode: isDarkMode,
                  accent: accent,
                  groups: groups,
                  onOpenStudyGroup: onOpenStudyGroup,
                  visibility: visibility,
                  allowedGroupIds: selectedAllowedGroupIds,
                  deniedGroupIds: selectedDeniedGroupIds,
                  onVisibilityChanged: onVisibilityChanged,
                  onChooseGroups: onChooseGroups,
                ),
              ],
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                _MomentToolbarAction(
                  tooltip: '添加图片',
                  icon: Icons.add_photo_alternate_rounded,
                  accent: accent,
                  isDarkMode: isDarkMode,
                  onPressed:
                      imagePaths.length >= 9 ? null : () => onPickImages(),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _MomentActionPill(
                    icon: Icons.send_rounded,
                    onPressed: isPosting ? null : () => onPost(),
                    label: Text(
                      visibility == LearningMomentVisibility.private
                          ? '保存私密学迹'
                          : '保存到小组',
                    ),
                    accent: accent,
                    isDarkMode: isDarkMode,
                    isFilled: true,
                    isBusy: isPosting,
                    expand: true,
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

class _EvidencePackagePanel extends StatelessWidget {
  const _EvidencePackagePanel({
    required this.isDarkMode,
    required this.accent,
    required this.titleColor,
    required this.bodyColor,
    required this.packages,
    required this.cloudPackages,
    required this.onUsePackage,
    required this.onSavePackage,
    required this.onGenerateCover,
    required this.onToggleFeatured,
    required this.onSharePackage,
  });

  final bool isDarkMode;
  final Color accent;
  final Color titleColor;
  final Color bodyColor;
  final List<_EvidencePackage> packages;
  final List<cloud.EvidencePackage> cloudPackages;
  final ValueChanged<_EvidencePackage> onUsePackage;
  final ValueChanged<_EvidencePackage> onSavePackage;
  final ValueChanged<cloud.EvidencePackage> onGenerateCover;
  final ValueChanged<cloud.EvidencePackage> onToggleFeatured;
  final ValueChanged<cloud.EvidencePackage> onSharePackage;

  @override
  Widget build(BuildContext context) {
    if (packages.isEmpty && cloudPackages.isEmpty) return const SizedBox.shrink();
    return StudyCard(
      padding: const EdgeInsets.all(16),
      radius: 22,
      color: StudyUi.surface(isDarkMode),
      borderColor: StudyUi.border(isDarkMode),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              StudyGlassIconNode(
                asset: AppAssets.featureNotesIcon,
                icon: Icons.inventory_2_rounded,
                accent: accent,
                size: 38,
                iconSize: 20,
                isDarkMode: isDarkMode,
              ),
              const SizedBox(width: 10),
              Text(
                '学习回顾',
                style: TextStyle(
                  color: titleColor,
                  fontWeight: AppTypography.title,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            '把学习整理、任务、笔记和闪卡放在一起，保存成之后可回看的学习回顾。',
            style: TextStyle(color: bodyColor, fontSize: 12),
          ),
          const SizedBox(height: 12),
          ...packages.take(3).map(
                (package) => _MomentReviewRow(
                  isDarkMode: isDarkMode,
                  accent: accent,
                  icon: Icons.auto_stories_rounded,
                  title: package.courseName,
                  subtitle:
                      '${package.eventCount} 条记录 · ${package.aiCount} 次整理 · ${package.shareableCount} 条可回看记录',
                  actions: [
                    _MomentActionPill(
                      icon: Icons.save_outlined,
                      label: '保存回顾',
                      accent: StudyUi.pathMint,
                      isDarkMode: isDarkMode,
                      onPressed: () => onSavePackage(package),
                    ),
                    const SizedBox(width: 8),
                    _MomentActionPill(
                      icon: Icons.edit_note_rounded,
                      label: '生成文案',
                      accent: accent,
                      isDarkMode: isDarkMode,
                      onPressed: () => onUsePackage(package),
                    ),
                  ],
                ),
              ),
          if (cloudPackages.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              '已保存回顾',
              style: TextStyle(
                color: bodyColor,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            ...cloudPackages.take(3).map(
                  (package) => _MomentReviewRow(
                    isDarkMode: isDarkMode,
                    accent: accent,
                    icon: package.featured
                        ? Icons.push_pin_rounded
                        : Icons.inventory_2_outlined,
                    title: package.title,
                    subtitle:
                        package.visibility == 'private' ? '私密学习回顾' : '已同步到小组',
                    actions: [
                      _MomentToolbarAction(
                        tooltip: '同步到小组',
                        icon: Icons.groups_rounded,
                        accent: StudyUi.pathCyan,
                        isDarkMode: isDarkMode,
                        onPressed: () => onSharePackage(package),
                      ),
                      const SizedBox(width: 8),
                      _MomentToolbarAction(
                        tooltip: package.featured ? '移出常看' : '放到常看',
                        icon: package.featured
                            ? Icons.push_pin_rounded
                            : Icons.push_pin_outlined,
                        accent: StudyUi.pathWarm,
                        isDarkMode: isDarkMode,
                        onPressed: () => onToggleFeatured(package),
                      ),
                      const SizedBox(width: 8),
                      _MomentToolbarAction(
                        tooltip: '生成回顾封面',
                        icon: Icons.image_outlined,
                        accent: accent,
                        isDarkMode: isDarkMode,
                        onPressed: () => onGenerateCover(package),
                      ),
                    ],
                  ),
                ),
          ],
        ],
      ),
    );
  }
}

class _FeaturedWallPanel extends StatelessWidget {
  const _FeaturedWallPanel({
    required this.isDarkMode,
    required this.accent,
    required this.titleColor,
    required this.bodyColor,
    required this.packages,
    required this.events,
    required this.onShare,
  });

  final bool isDarkMode;
  final Color accent;
  final Color titleColor;
  final Color bodyColor;
  final Iterable<cloud.EvidencePackage> packages;
  final Iterable<LearningTraceEvent> events;
  final ValueChanged<LearningTraceEvent> onShare;

  @override
  Widget build(BuildContext context) {
    final packageList = packages.toList();
    final list = events.toList();
    if (packageList.isEmpty && list.isEmpty) return const SizedBox.shrink();
    return StudyCard(
      padding: const EdgeInsets.all(16),
      radius: 22,
      color: StudyUi.surface(isDarkMode),
      borderColor: StudyUi.border(isDarkMode),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              StudyGlassIconNode(
                asset: AppAssets.sideAchievementsIcon,
                icon: Icons.workspace_premium_rounded,
                accent: accent,
                size: 38,
                iconSize: 20,
                isDarkMode: isDarkMode,
              ),
              const SizedBox(width: 10),
              Text(
                '常看回顾',
                style: TextStyle(
                  color: titleColor,
                  fontWeight: AppTypography.title,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (packageList.isNotEmpty)
            ...packageList.map(
              (package) => _MomentReviewRow(
                isDarkMode: isDarkMode,
                accent: accent,
                icon: Icons.push_pin_rounded,
                title: package.title,
                subtitle:
                    package.description.isEmpty ? '常看学习回顾' : package.description,
              ),
            )
          else
            ...list.map(
              (event) => _MomentReviewRow(
                isDarkMode: isDarkMode,
                accent: accent,
                icon: Icons.auto_awesome_rounded,
                title: event.title,
                subtitle: event.typeLabel,
                actions: [
                  _MomentActionPill(
                    icon: Icons.workspace_premium_rounded,
                    label: '放到常看',
                    accent: accent,
                    isDarkMode: isDarkMode,
                    onPressed: () => onShare(event),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _MomentReviewRow extends StatelessWidget {
  const _MomentReviewRow({
    required this.isDarkMode,
    required this.accent,
    required this.icon,
    required this.title,
    required this.subtitle,
    this.actions = const [],
  });

  final bool isDarkMode;
  final Color accent;
  final IconData icon;
  final String title;
  final String subtitle;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.fromLTRB(12, 11, 12, 11),
      decoration: BoxDecoration(
        color: StudyUi.surfaceAlt(isDarkMode),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: StudyUi.border(isDarkMode)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          StudyGlassIconNode(
            icon: icon,
            accent: accent,
            size: 38,
            iconSize: 18,
            isDarkMode: isDarkMode,
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
                    fontSize: 14,
                    fontWeight: AppTypography.emphasis,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: StudyUi.body(isDarkMode),
                    fontSize: 12,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
          if (actions.isNotEmpty) ...[
            const SizedBox(width: 10),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 150),
              child: Wrap(
                spacing: 0,
                runSpacing: 6,
                alignment: WrapAlignment.end,
                children: actions,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class TraceToolbar extends StatelessWidget {
  const TraceToolbar({
    super.key,
    required this.accent,
    required this.titleColor,
    required this.bodyColor,
    required this.filter,
    required this.onFilterChanged,
  });

  final Color accent;
  final Color titleColor;
  final Color bodyColor;
  final LearningTraceEventType? filter;
  final ValueChanged<LearningTraceEventType?> onFilterChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        StudyGlassIconNode(
          asset: AppAssets.sideMomentsIcon,
          icon: Icons.timeline_rounded,
          accent: accent,
          size: 36,
          iconSize: 18,
          isDarkMode: Theme.of(context).brightness == Brightness.dark,
        ),
        const SizedBox(width: 8),
        Text(
          '学习记录',
          style: TextStyle(
            color: titleColor,
            fontSize: 17,
            fontWeight: AppTypography.title,
          ),
        ),
        const Spacer(),
        StudyPopupMenuButton<LearningTraceEventType?>(
          tooltip: '筛选记录',
          onSelected: onFilterChanged,
          itemBuilder: (context) => [
            const PopupMenuItem(value: null, child: Text('全部记录')),
            ...LearningTraceEventType.values.map(
              (type) => PopupMenuItem(
                value: type,
                child: Text(_labelFor(type)),
              ),
            ),
          ],
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
            decoration: BoxDecoration(
              color: StudyUi.chipBackground(
                accent,
                Theme.of(context).brightness == Brightness.dark,
              ),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: accent.withValues(alpha: 0.20)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.filter_list_rounded, color: accent, size: 15),
                const SizedBox(width: 5),
                Text(
                  filter == null ? '全部' : _labelFor(filter!),
                  style: TextStyle(
                    color: titleColor,
                    fontSize: 12,
                    fontWeight: AppTypography.emphasis,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  static String _labelFor(LearningTraceEventType type) {
    return switch (type) {
      LearningTraceEventType.moment => '学迹',
      LearningTraceEventType.studyLog => '学习记录',
      LearningTraceEventType.taskCompleted => '任务完成',
      LearningTraceEventType.noteCreated => '笔记沉淀',
      LearningTraceEventType.flashcardCreated => '闪卡复习',
      LearningTraceEventType.focusCompleted => '专注完成',
      LearningTraceEventType.aiAction => '学习整理',
    };
  }
}

class _MomentCard extends StatelessWidget {
  const _MomentCard({
    required this.moment,
    required this.groups,
    required this.isDarkMode,
    required this.accent,
    required this.titleColor,
    required this.bodyColor,
    required this.onLike,
    required this.onComment,
    required this.onDeleteComment,
    this.onEditVisibility,
    this.onDelete,
  });

  final LearningMoment moment;
  final List<GroupInfo> groups;
  final bool isDarkMode;
  final Color accent;
  final Color titleColor;
  final Color bodyColor;
  final VoidCallback onLike;
  final VoidCallback onComment;
  final ValueChanged<LearningMomentComment> onDeleteComment;
  final VoidCallback? onEditVisibility;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final sourceLabel = _momentSourceLabel(moment);
    final learningLoopContent = _LearningLoopMomentContent.tryParse(moment);
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.fromLTRB(14, 14, 10, 14),
      decoration: BoxDecoration(
        color: isDarkMode ? const Color(0xFF1E2533) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDarkMode
              ? Colors.white.withValues(alpha: 0.06)
              : const Color(0xFFE8ECF5),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _MomentAvatar(author: moment.author, accent: accent),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            moment.author.nickname,
                            style: TextStyle(
                              color: accent,
                              fontSize: 14,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Wrap(
                            spacing: 8,
                            runSpacing: 4,
                            children: [
                              Text(
                                _formatTime(moment.createdAt),
                                style: TextStyle(
                                  color: bodyColor,
                                  fontSize: 12,
                                ),
                              ),
                              Text(
                                _visibilityLabel(moment),
                                style: TextStyle(
                                  color: bodyColor,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    if (onEditVisibility != null || onDelete != null)
                      StudyPopupMenuButton<String>(
                        tooltip: '学迹操作',
                        onSelected: (value) {
                          if (value == 'visibility') onEditVisibility?.call();
                          if (value == 'delete') onDelete?.call();
                        },
                        itemBuilder: (context) => [
                          if (onEditVisibility != null)
                            const PopupMenuItem(
                              value: 'visibility',
                              child: Text('修改可见范围'),
                            ),
                          if (onDelete != null)
                            const PopupMenuItem(
                              value: 'delete',
                              child: Text('删除学迹'),
                            ),
                        ],
                        child: StudyGlassIconNode(
                          icon: Icons.more_horiz_rounded,
                          accent: accent,
                          size: 32,
                          iconSize: 16,
                          isDarkMode: isDarkMode,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                if (moment.courseName.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Text(
                      '课程：${moment.courseName}',
                      style: TextStyle(color: bodyColor, fontSize: 12),
                    ),
                  ),
                if (sourceLabel.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: _MiniTag(
                      label: sourceLabel,
                      accent: accent,
                      isDarkMode: isDarkMode,
                    ),
                  ),
                if (learningLoopContent != null)
                  _LearningLoopMomentBody(
                    content: learningLoopContent,
                    accent: accent,
                    titleColor: titleColor,
                    bodyColor: bodyColor,
                    isDarkMode: isDarkMode,
                  )
                else
                  Text(
                    moment.content,
                    style: TextStyle(
                      color: titleColor,
                      fontSize: 15,
                      height: 1.45,
                    ),
                  ),
                if (moment.imagePaths.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  _ImageGrid(paths: moment.imagePaths, isDarkMode: isDarkMode),
                ],
                const SizedBox(height: 8),
                Row(
                  children: [
                    _MomentActionPill(
                      onPressed: onLike,
                      icon: Icon(
                        moment.likedByMe
                            ? Icons.favorite_rounded
                            : Icons.favorite_border_rounded,
                        size: 18,
                      ),
                      label: moment.likeCount == 0
                          ? '有帮助'
                          : '${moment.likeCount}',
                      accent:
                          moment.likedByMe ? StudyUi.danger : StudyUi.pathViolet,
                      isDarkMode: isDarkMode,
                    ),
                    const SizedBox(width: 8),
                    _MomentActionPill(
                      onPressed: onComment,
                      icon: Icons.mode_comment_outlined,
                      label: moment.commentCount == 0
                          ? '回看备注'
                          : '${moment.commentCount}',
                      accent: StudyUi.pathCyan,
                      isDarkMode: isDarkMode,
                    ),
                  ],
                ),
                if (moment.comments.isNotEmpty)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: isDarkMode
                          ? Colors.white.withValues(alpha: 0.05)
                          : const Color(0xFFF4F6FB),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: moment.comments
                          .map(
                            (comment) => InkWell(
                              onLongPress: comment.isMine || moment.isMine
                                  ? () => onDeleteComment(comment)
                                  : null,
                              child: Padding(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 3),
                                child: RichText(
                                  text: TextSpan(
                                    style: TextStyle(
                                      color: titleColor,
                                      fontSize: 13,
                                      height: 1.35,
                                    ),
                                    children: [
                                      TextSpan(
                                        text: '${comment.author.nickname}：',
                                        style: TextStyle(
                                          color: accent,
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                      TextSpan(text: comment.content),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          )
                          .toList(growable: false),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _visibilityLabel(LearningMoment moment) {
    switch (moment.visibility) {
      case LearningMomentVisibility.private:
        return '仅自己可见';
      case LearningMomentVisibility.public:
        return '我的小组成员可见';
      case LearningMomentVisibility.includeGroups:
        return '指定可见：${_groupNames(moment.allowedGroupIds)}';
      case LearningMomentVisibility.excludeGroups:
        return '不给谁看：${_groupNames(moment.deniedGroupIds)}';
    }
  }

  String _groupNames(List<String> ids) {
    final names = ids
        .map((id) => _VisibilityPicker._groupName(groups, id))
        .where((name) => name.isNotEmpty)
        .join('、');
    return names.isEmpty ? '未选择' : names;
  }

  String _formatTime(DateTime time) {
    final now = DateTime.now();
    final diff = now.difference(time);
    if (diff.inMinutes < 1) return '刚刚';
    if (diff.inHours < 1) return '${diff.inMinutes} 分钟前';
    if (diff.inDays < 1) return '${diff.inHours} 小时前';
    if (diff.inDays < 7) return '${diff.inDays} 天前';
    return '${time.month}/${time.day} ${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
  }

  String _momentSourceLabel(LearningMoment moment) {
    switch ((moment.sourceType ?? '').trim()) {
      case 'learning_loop':
      case 'synced_learning_loop':
        return '学习整理';
      case 'evidence_package':
        return '学习回顾';
      case 'task_progress':
      case 'synced_task_progress':
        return '任务推进';
      case 'local_private_moment':
        return '私密记录';
      case 'location':
      case 'location_evidence':
        return '地点记录';
      default:
        return '';
    }
  }
}

class _LearningLoopMomentContent {
  const _LearningLoopMomentContent({
    required this.summary,
    required this.nextActions,
  });

  final String summary;
  final List<String> nextActions;

  static _LearningLoopMomentContent? tryParse(LearningMoment moment) {
    final sourceType = (moment.sourceType ?? '').trim();
    if (sourceType != 'learning_loop' && sourceType != 'synced_learning_loop') {
      return null;
    }
    final lines = moment.content
        .split(RegExp(r'[\r\n]+'))
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .toList(growable: false);
    if (lines.isEmpty) return null;

    final summaryParts = <String>[];
    final nextActions = <String>[];
    for (final line in lines) {
      if (line.startsWith('下一步：')) {
        nextActions.addAll(_splitActions(line.replaceFirst('下一步：', '')));
        continue;
      }
      if (line.startsWith('下一步怎么做：')) {
        nextActions.addAll(_splitActions(line.replaceFirst('下一步怎么做：', '')));
        continue;
      }
      summaryParts.add(line);
    }

    final summary = summaryParts.join('\n').trim();
    if (summary.isEmpty && nextActions.isEmpty) return null;
    return _LearningLoopMomentContent(
      summary: summary.isEmpty ? moment.content.trim() : summary,
      nextActions: nextActions.take(3).toList(growable: false),
    );
  }

  static List<String> _splitActions(String source) {
    return source
        .split(RegExp(r'[；;]'))
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty)
        .toList(growable: false);
  }
}

class _LearningLoopMomentBody extends StatelessWidget {
  const _LearningLoopMomentBody({
    required this.content,
    required this.accent,
    required this.titleColor,
    required this.bodyColor,
    required this.isDarkMode,
  });

  final _LearningLoopMomentContent content;
  final Color accent;
  final Color titleColor;
  final Color bodyColor;
  final bool isDarkMode;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          content.summary,
          style: TextStyle(
            color: titleColor,
            fontSize: 15,
            height: 1.45,
          ),
        ),
        if (content.nextActions.isNotEmpty) ...[
          const SizedBox(height: 10),
          Text(
            '接下来可以这样走',
            style: TextStyle(
              color: bodyColor,
              fontSize: 12,
              fontWeight: AppTypography.emphasis,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final action in content.nextActions)
                _MiniTag(
                  label: action,
                  accent: accent,
                  isDarkMode: isDarkMode,
                ),
            ],
          ),
        ],
      ],
    );
  }
}

class _MomentAvatar extends StatelessWidget {
  const _MomentAvatar({required this.author, required this.accent});

  final LearningMomentAuthor author;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return StudyUserAvatar(
      avatarImagePath: author.avatarImageUrl,
      avatarEmoji: author.avatarEmoji,
      size: 40,
      accent: accent,
    );
  }
}

class _ImageGrid extends StatelessWidget {
  const _ImageGrid({
    required this.paths,
    required this.isDarkMode,
    this.onRemove,
  });

  final List<String> paths;
  final bool isDarkMode;
  final ValueChanged<String>? onRemove;

  @override
  Widget build(BuildContext context) {
    final count = paths.length.clamp(1, 3).toInt();
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: paths.length,
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: count,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
      ),
      itemBuilder: (context, index) {
        final path = paths[index];
        return ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: Stack(
            fit: StackFit.expand,
            children: [
              localImageFromPath(
                path,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => Container(
                  color: isDarkMode
                      ? Colors.white.withValues(alpha: 0.06)
                      : const Color(0xFFEFF3FF),
                  child: const Icon(Icons.broken_image_rounded),
                ),
              ),
              if (onRemove != null)
                Positioned(
                  right: 6,
                  top: 6,
                  child: InkWell(
                    onTap: () => onRemove!(path),
                    borderRadius: BorderRadius.circular(99),
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.55),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.close_rounded,
                        color: Colors.white,
                        size: 16,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

class _EmptyTimeline extends StatelessWidget {
  const _EmptyTimeline({
    required this.isDarkMode,
    required this.accent,
    required this.bodyColor,
    this.message,
    this.onRecord,
    this.onReview,
  });

  final bool isDarkMode;
  final Color accent;
  final Color bodyColor;
  final String? message;
  final VoidCallback? onRecord;
  final VoidCallback? onReview;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 36),
      decoration: BoxDecoration(
        color: isDarkMode ? const Color(0xFF1E2533) : Colors.white,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        children: [
          StudyAssetIcon(
            asset: AppAssets.sideMomentsIcon,
            color: accent,
            size: 48,
            fallbackIcon: Icons.timeline_rounded,
          ),
          const SizedBox(height: 12),
          Text(
            message ?? '还没有学迹，先保存第一条学习现场，之后可整理成回顾和下一步',
            textAlign: TextAlign.center,
            style: TextStyle(color: bodyColor, fontSize: 13),
          ),
          const SizedBox(height: 14),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 8,
            runSpacing: 8,
            children: [
              _MomentActionPill(
                icon: Icons.edit_note_rounded,
                label: '记录一条',
                accent: accent,
                isDarkMode: isDarkMode,
                onPressed: onRecord,
              ),
              _MomentActionPill(
                icon: Icons.auto_stories_rounded,
                label: '整理回顾',
                accent: StudyUi.pathBlue,
                isDarkMode: isDarkMode,
                onPressed: onReview,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MomentsSheetSurface extends StatelessWidget {
  const _MomentsSheetSurface({
    required this.isDarkMode,
    required this.accent,
    required this.icon,
    required this.title,
    required this.child,
    this.subtitle,
  });

  final bool isDarkMode;
  final Color accent;
  final IconData icon;
  final String title;
  final String? subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final maxHeight = MediaQuery.of(context).size.height * 0.84;
    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: maxHeight),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(18, 12, 18, 22),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                StudyUi.surface(isDarkMode),
                StudyUi.surfaceAlt(isDarkMode),
              ],
            ),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
            border: Border.all(color: StudyUi.border(isDarkMode)),
            boxShadow: [
              BoxShadow(
                color: accent.withValues(alpha: isDarkMode ? 0.16 : 0.12),
                blurRadius: 28,
                offset: const Offset(0, -8),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 42,
                  height: 4,
                  decoration: BoxDecoration(
                    color: StudyUi.muted(isDarkMode).withValues(alpha: 0.34),
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  StudyGlassIconNode(
                    icon: icon,
                    accent: accent,
                    size: 42,
                    iconSize: 20,
                    isDarkMode: isDarkMode,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: TextStyle(
                            color: StudyUi.title(isDarkMode),
                            fontSize: 17,
                            fontWeight: AppTypography.title,
                          ),
                        ),
                        if (subtitle != null) ...[
                          const SizedBox(height: 4),
                          Text(
                            subtitle!,
                            style: TextStyle(
                              color: StudyUi.body(isDarkMode),
                              fontSize: 12,
                              height: 1.35,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Flexible(
                fit: FlexFit.loose,
                child: SingleChildScrollView(child: child),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MomentsDialogSurface extends StatelessWidget {
  const _MomentsDialogSurface({
    required this.isDarkMode,
    required this.accent,
    required this.icon,
    required this.title,
    required this.child,
  });

  final bool isDarkMode;
  final Color accent;
  final IconData icon;
  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      elevation: 0,
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 460),
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: StudyUi.surface(isDarkMode),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: StudyUi.border(isDarkMode)),
          boxShadow: [
            BoxShadow(
              color: accent.withValues(alpha: isDarkMode ? 0.18 : 0.14),
              blurRadius: 28,
              offset: const Offset(0, 16),
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
                  size: 40,
                  iconSize: 18,
                  isDarkMode: isDarkMode,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      color: StudyUi.title(isDarkMode),
                      fontSize: 17,
                      fontWeight: AppTypography.title,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            child,
          ],
        ),
      ),
    );
  }
}

class _MomentGroupCheckTile extends StatelessWidget {
  const _MomentGroupCheckTile({
    required this.title,
    required this.subtitle,
    required this.selected,
    required this.accent,
    required this.isDarkMode,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final bool selected;
  final Color accent;
  final bool isDarkMode;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.fromLTRB(12, 11, 12, 11),
            decoration: BoxDecoration(
              color: selected
                  ? StudyUi.chipBackground(accent, isDarkMode)
                  : StudyUi.surface(isDarkMode).withValues(alpha: 0.78),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: selected
                    ? accent.withValues(alpha: 0.28)
                    : StudyUi.border(isDarkMode),
              ),
            ),
            child: Row(
              children: [
                StudyGlassIconNode(
                  icon: selected
                      ? Icons.check_circle_rounded
                      : Icons.circle_outlined,
                  accent: selected ? accent : StudyUi.muted(isDarkMode),
                  size: 38,
                  iconSize: 18,
                  isDarkMode: isDarkMode,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          color: StudyUi.title(isDarkMode),
                          fontSize: 14,
                          fontWeight: AppTypography.emphasis,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: TextStyle(
                          color: StudyUi.body(isDarkMode),
                          fontSize: 12,
                        ),
                      ),
                    ],
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

class _MomentToolbarAction extends StatelessWidget {
  const _MomentToolbarAction({
    required this.tooltip,
    required this.icon,
    required this.accent,
    required this.isDarkMode,
    required this.onPressed,
  });

  final String tooltip;
  final IconData icon;
  final Color accent;
  final bool isDarkMode;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;
    return Tooltip(
      message: tooltip,
      child: Opacity(
        opacity: enabled ? 1 : 0.45,
        child: InkWell(
          borderRadius: BorderRadius.circular(999),
          onTap: onPressed,
          child: StudyGlassIconNode(
            icon: icon,
            accent: accent,
            size: 36,
            iconSize: 18,
            isDarkMode: isDarkMode,
          ),
        ),
      ),
    );
  }
}

class _MomentActionPill extends StatelessWidget {
  const _MomentActionPill({
    required this.icon,
    required this.label,
    required this.accent,
    required this.isDarkMode,
    required this.onPressed,
    this.isFilled = false,
    this.isBusy = false,
    this.expand = false,
  });

  final Object icon;
  final Object label;
  final Color accent;
  final bool isDarkMode;
  final VoidCallback? onPressed;
  final bool isFilled;
  final bool isBusy;
  final bool expand;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;
    final foreground = isFilled ? Colors.white : accent;
    return Opacity(
      opacity: enabled ? 1 : 0.48,
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: onPressed,
        child: Container(
          width: expand ? double.infinity : null,
          padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 9),
          decoration: BoxDecoration(
            color: isFilled
                ? accent
                : StudyUi.chipBackground(accent, isDarkMode),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: isFilled
                  ? Colors.white.withValues(alpha: isDarkMode ? 0.12 : 0.38)
                  : accent.withValues(alpha: isDarkMode ? 0.24 : 0.18),
            ),
            boxShadow: isFilled
                ? [
                    BoxShadow(
                      color: accent.withValues(alpha: isDarkMode ? 0.18 : 0.24),
                      blurRadius: 18,
                      offset: const Offset(0, 10),
                    ),
                  ]
                : null,
          ),
          child: Row(
            mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (isBusy)
                SizedBox(
                  width: 15,
                  height: 15,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(foreground),
                  ),
                )
              else
                icon is Icon
                    ? IconTheme.merge(
                        data: IconThemeData(color: foreground, size: 17),
                        child: icon as Icon,
                      )
                    : Icon(icon as IconData, color: foreground, size: 17),
              const SizedBox(width: 6),
              label is Text
                  ? DefaultTextStyle.merge(
                      style: TextStyle(
                        color: foreground,
                        fontSize: 13,
                        fontWeight: AppTypography.emphasis,
                      ),
                      child: label as Text,
                    )
                  : Text(
                      label as String,
                      style: TextStyle(
                        color: foreground,
                        fontSize: 13,
                        fontWeight: AppTypography.emphasis,
                      ),
                    ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EvidencePackage {
  const _EvidencePackage({
    required this.courseName,
    required this.eventCount,
    required this.aiCount,
    required this.shareableCount,
    required this.latestAt,
    required this.types,
  });

  final String courseName;
  final int eventCount;
  final int aiCount;
  final int shareableCount;
  final DateTime latestAt;
  final List<String> types;
}

class _CapabilityBadge {
  const _CapabilityBadge(
    this.label,
    this.unlocked, {
    this.current = 0,
    this.target = 1,
    this.source = '',
    this.nextStep = '',
    this.iconAsset = AppAssets.aiBadgeOrganize,
  });

  final String label;
  final bool unlocked;
  final int current;
  final int target;
  final String source;
  final String nextStep;
  final String iconAsset;
}

class _LocationCheckInDraft {
  const _LocationCheckInDraft({
    required this.title,
    required this.city,
    required this.shareToGroup,
    this.groupId,
  });

  final String title;
  final String city;
  final bool shareToGroup;
  final String? groupId;
}
