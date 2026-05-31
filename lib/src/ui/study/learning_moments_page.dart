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
import '../shared/app_assets.dart';
import '../shared/common_widgets.dart';
import '../shared/local_image.dart';

class LearningMomentsPage extends StatefulWidget {
  const LearningMomentsPage({
    super.key,
    required this.isDarkMode,
    required this.controller,
  });

  final bool isDarkMode;
  final AppDataController controller;

  @override
  State<LearningMomentsPage> createState() => _LearningMomentsPageState();
}

class _LearningMomentsPageState extends State<LearningMomentsPage> {
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

  Future<void> _loadMomentFeed() async {
    if (!widget.controller.isLoggedIn || _isLoadingFeed) return;
    setState(() {
      _isLoadingFeed = true;
      _feedError = null;
    });
    try {
      final moments = await widget.controller.learningMomentService.feed();
      if (!mounted) return;
      setState(() {
        _cloudMoments
          ..clear()
          ..addAll(moments);
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _feedError = _friendlyCloudError(error, '动态加载失败，下拉可重试');
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
    final titleColor = widget.isDarkMode ? Colors.white : AppColors.ink;
    final bodyColor =
        widget.isDarkMode ? const Color(0xFFC2C8D6) : AppColors.body;
    return Scaffold(
      backgroundColor:
          widget.isDarkMode ? const Color(0xFF111827) : const Color(0xFFF5F7FF),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        foregroundColor: titleColor,
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                color: StudyUi.chipBackground(accent, widget.isDarkMode),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.dynamic_feed_rounded,
                color: StudyUi.primary,
                size: 17,
              ),
            ),
            const SizedBox(width: 10),
            const Flexible(
              child: Text(
                '学迹动态',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontWeight: FontWeight.w800),
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: '学迹工具',
            onPressed: _showMomentsTools,
            icon: const Icon(Icons.more_horiz_rounded),
          ),
        ],
      ),
      body: AnimatedBuilder(
        animation: widget.controller,
        builder: (context, _) {
          final moments = widget.controller.isLoggedIn
              ? _cloudMoments
              : widget.controller.learningMoments;
          final listView = ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(20, 10, 20, 36),
            children: [
              _PostEntryCard(
                isDarkMode: widget.isDarkMode,
                accent: accent,
                titleColor: titleColor,
                bodyColor: bodyColor,
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
                      )
              else
                ...moments.map(
                  (moment) => _MomentCard(
                    moment: moment,
                    groups: _groups,
                    isDarkMode: widget.isDarkMode,
                    accent: accent,
                    titleColor: titleColor,
                    bodyColor: bodyColor,
                    onLike: () => _toggleMomentLike(moment),
                    onComment: () => _commentMoment(moment),
                    onDelete: moment.isMine
                        ? () => _deleteMoment(moment.id)
                        : null,
                    onEditVisibility: widget.controller.isLoggedIn && moment.isMine
                        ? () => _editMomentVisibility(moment)
                        : null,
                    onDeleteComment: (comment) =>
                        _deleteMomentComment(moment, comment),
                  ),
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
    );
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
        nextStep: '再完成一次学习记录或助手整理',
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
        source: '用图片材料生成学习轨迹',
        nextStep: '发布一条带图片的学迹动态',
        iconAsset: AppAssets.aiBadgeVision,
      ),
      _CapabilityBadge(
        '智能执行',
        hasAiAction || records.isNotEmpty,
        current: records.where((record) => record.statusLabel == '已完成').length.clamp(0, 5).toInt(),
        target: 5,
        source: '让蓝心模型执行可落地学习动作',
        nextStep: '用蓝心模型创建任务、笔记或今日安排',
        iconAsset: AppAssets.aiBadgeAssistant,
      ),
      _CapabilityBadge(
        '学习记忆',
        hasMemory,
        current: records.where((record) => record.toolId.contains('memory')).length.clamp(0, 3).toInt(),
        target: 3,
        source: '从个人学习资料中召回证据',
        nextStep: '在学习对话里追问过去的任务或笔记',
        iconAsset: AppAssets.aiBadgeMemory,
      ),
      _CapabilityBadge(
        '复盘留痕',
        hasLoop || events.length >= 3,
        current: events.where((event) => event.isAiGenerated).length.clamp(0, 4).toInt(),
        target: 4,
        source: '形成可复盘的学习闭环',
        nextStep: '保存一次计划并启动专注',
        iconAsset: AppAssets.aiBadgeReview,
      ),
      _CapabilityBadge(
        '学迹分享',
        moments.isNotEmpty,
        current: moments.length.clamp(0, 3).toInt(),
        target: 3,
        source: '把学习成果发布成动态',
        nextStep: '发布或转发一条学迹动态',
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
      return '发布一条带图片的学迹动态';
    }
    if (label.contains('记忆') || label.contains('检索')) {
      return '在学习对话里追问过去的任务或笔记';
    }
    if (label.contains('复盘') || label.contains('落地')) {
      return '保存一次计划并启动专注';
    }
    if (label.contains('分享') || label.contains('动态')) {
      return '发布或转发一条学迹动态';
    }
    if (label.contains('助手') || label.contains('大模型') || label.contains('AI')) {
      return '用助手创建任务、笔记或今日安排';
    }
    return '再完成一次学习记录或助手整理';
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
                    _showTip('请先登录，再发布公开或小组动态');
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
                  final posted = await _publishMoment();
                  if (posted && mounted) Navigator.of(sheetContext).pop();
                },
              ),
            ),
          ),
        );
      },
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
        return DraggableScrollableSheet(
          initialChildSize: 0.82,
          minChildSize: 0.42,
          maxChildSize: 0.94,
          builder: (context, scrollController) => Container(
            decoration: BoxDecoration(
              color: widget.isDarkMode ? const Color(0xFF111827) : Colors.white,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: ListView(
              controller: scrollController,
              padding: const EdgeInsets.fromLTRB(18, 12, 18, 28),
              children: [
                Center(
                  child: Container(
                    width: 42,
                    height: 4,
                    decoration: BoxDecoration(
                      color: bodyColor.withValues(alpha: 0.28),
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
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
        title: '${package.courseName} 学习成果包',
        courseName: package.courseName == '未归课程' ? '' : package.courseName,
        description:
            '${package.eventCount} 条轨迹，${package.aiCount} 次助手整理，${package.shareableCount} 项可分享成果。',
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
      _showSnack('成果包已保存，可继续生成封面或分享至小组');
    } catch (_) {
      _useEvidencePackage(package);
      _showSnack('云端成果包暂不可用，已转为本地动态文案');
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
        _showSnack('成果封面已回填到成果包');
        return;
      }
      final task = await widget.controller.vivoCapabilityService.createCover(
        prompt:
            '为大学生学习成果制作清晰、积极、可展示的封面。主题：${package.title}。内容：${package.description}',
        purpose: 'evidence_cover',
      );
      if (!mounted) return;
      final updated = await widget.controller.communityEvidenceService.updatePackage(
        package.id,
        coverImageUrl: 'vivo-task:${task.taskId}',
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
              title: '学习成果封面已提交生成',
              summary: package.title,
              sourceType: 'evidence_package',
              sourceId: package.id,
              payloadJson: {'taskId': task.taskId, 'purpose': 'evidence_cover'},
            )
            .catchError((_) {}),
      );
      _showSnack('成果封面已提交生成，稍后刷新查看');
    } catch (_) {
      _showSnack('图片生成能力暂不可用，成果包内容不受影响');
    }
  }

  Future<void> _sharePackageToGroup(cloud.EvidencePackage package) async {
    if (_groups.isEmpty) {
      _showSnack('请先创建或加入学习小组');
      return;
    }
    final group = await showDialog<GroupInfo>(
      context: context,
      builder: (dialogContext) => SimpleDialog(
        title: const Text('分享到小组'),
        children: [
          for (final group in _groups)
            SimpleDialogOption(
              onPressed: () => Navigator.of(dialogContext).pop(group),
              child: Text(group.name),
            ),
        ],
      ),
    );
    if (group == null) return;
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
      _showSnack('成果包已分享到 ${group.name}');
    } catch (_) {
      _showSnack('成果包分享失败，请稍后重试');
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
      _showSnack(updated.featured ? '已加入精选成果墙' : '已取消精选');
    } catch (_) {
      _showSnack('精选状态更新失败，请稍后重试');
    }
  }

  Future<void> _createLocationCheckIn() async {
    if (_isCheckingLocation) return;
    if (!widget.controller.isLoggedIn) {
      _showTip('请先登录，再保存校园地点');
      return;
    }
    final draft = await _showLocationCheckInDialog();
    if (draft == null || draft.title.isEmpty) return;
    if (!mounted) return;
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
      _showTip(draft.shareToGroup ? '地点已分享到小组学习轨迹' : '地点已保存为私密学习记录');
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
            builder: (context, setDialogState) => AlertDialog(
              title: const Text('手动地点记录'),
              content: SizedBox(
                width: 460,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextField(
                        controller: titleController,
                        autofocus: true,
                        decoration: const InputDecoration(
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
                        decoration: const InputDecoration(
                          labelText: '校区或备注',
                          hintText: '可选，如主校区 / 靠窗座位',
                        ),
                      ),
                      if (_groups.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        SwitchListTile.adaptive(
                          contentPadding: EdgeInsets.zero,
                          value: shareToGroup,
                          title: const Text('分享到小组'),
                          onChanged: (value) => setDialogState(
                            () => shareToGroup = value,
                          ),
                        ),
                        if (shareToGroup)
                          DropdownButtonFormField<String>(
                            value: selectedGroupId,
                            items: _groups
                                .map(
                                  (group) => DropdownMenuItem(
                                    value: group.id,
                                    child: Text(group.name),
                                  ),
                                )
                                .toList(),
                            onChanged: (value) => setDialogState(
                              () => selectedGroupId = value,
                            ),
                            decoration: const InputDecoration(labelText: '小组'),
                          ),
                      ],
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  child: const Text('取消'),
                ),
                FilledButton(
                  onPressed: () => _popLocationDraft(
                    dialogContext,
                    titleController,
                    cityController,
                    shareToGroup,
                    selectedGroupId,
                  ),
                  child: Text(shareToGroup ? '保存并分享' : '保存'),
                ),
              ],
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
      _showTip('请先登录后发布公开或小组动态');
      return false;
    }
    if (_visibility == LearningMomentVisibility.includeGroups &&
        _selectedAllowedGroupIds.isEmpty) {
      _showTip('请选择允许查看的小组，或切回公开/私密');
      return false;
    }
    if (_visibility == LearningMomentVisibility.excludeGroups &&
        _selectedDeniedGroupIds.isEmpty) {
      _showTip('请选择不允许查看的小组，或切回公开/私密');
      return false;
    }
    setState(() => _isPosting = true);
    final publishedVisibility = _visibility;
    try {
      final text = content.isEmpty ? '分享了一组学习图片' : content;
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
          ? '已保存私密动态'
          : '已发布动态');
      return true;
    } catch (error) {
      _showTip(_friendlyCloudError(error, '动态发布失败，请稍后重试'));
      return false;
    } finally {
      if (mounted) setState(() => _isPosting = false);
    }
  }

  Future<void> _shareTraceEvent(LearningTraceEvent event) async {
    await widget.controller.shareTraceEvent(event);
    _showTip('已转发到私密学迹动态');
  }

  void _useEvidencePackage(_EvidencePackage package) {
    final validCourse = widget.controller.courseNames.contains(package.courseName)
        ? package.courseName
        : '';
    setState(() {
      _selectedCourse = validCourse;
      _contentController.text =
          '整理了「${package.courseName}」的学习成果包：${package.eventCount} 条轨迹、'
          '${package.aiCount} 次助手整理、${package.shareableCount} 条可分享成果。'
          '这些记录把任务执行、笔记沉淀和复盘材料串成了可追溯的学习过程。';
    });
  }

  Future<void> _deleteMoment(String momentId) async {
    try {
      if (widget.controller.isLoggedIn) {
        await widget.controller.learningMomentService.delete(momentId);
        if (!mounted) return;
        setState(
          () => _cloudMoments.removeWhere((moment) => moment.id == momentId),
        );
      } else {
        await widget.controller.deleteLearningMoment(momentId);
      }
      _showTip('已删除动态');
    } catch (error) {
      _showTip(_friendlyCloudError(error, '动态删除失败，请稍后重试'));
    }
  }

  Future<void> _toggleMomentLike(LearningMoment moment) async {
    if (!widget.controller.isLoggedIn) {
      _showTip('请先登录后点赞');
      return;
    }
    try {
      final updated = moment.likedByMe
          ? await widget.controller.learningMomentService.unlike(moment.id)
          : await widget.controller.learningMomentService.like(moment.id);
      _upsertCloudMoment(updated);
    } catch (error) {
      _showTip(_friendlyCloudError(error, '点赞失败，请稍后重试'));
    }
  }

  Future<void> _commentMoment(LearningMoment moment) async {
    if (!widget.controller.isLoggedIn) {
      _showTip('请先登录后评论');
      return;
    }
    final controller = TextEditingController();
    try {
      final text = await showDialog<String>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('写评论'),
          content: TextField(
            controller: controller,
            autofocus: true,
            maxLength: 500,
            minLines: 2,
            maxLines: 4,
            decoration: const InputDecoration(hintText: '说点什么...'),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () =>
                  Navigator.of(dialogContext).pop(controller.text.trim()),
              child: const Text('发送'),
            ),
          ],
        ),
      );
      if (text == null || text.isEmpty) return;
      final updated =
          await widget.controller.learningMomentService.comment(moment.id, text);
      _upsertCloudMoment(updated);
    } catch (error) {
      _showTip(_friendlyCloudError(error, '评论失败，请稍后重试'));
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
      _showTip(_friendlyCloudError(error, '评论删除失败，请稍后重试'));
    }
  }

  Future<void> _editMomentVisibility(LearningMoment moment) async {
    if (!widget.controller.isLoggedIn) {
      _showTip('请先登录，再修改可见范围');
      return;
    }
    final result = await _showVisibilityEditor(
      initialVisibility: moment.visibility,
      initialAllowedIds: moment.allowedGroupIds,
      initialDeniedIds: moment.deniedGroupIds,
    );
    if (result == null) return;
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
      final index = _cloudMoments.indexWhere((item) => item.id == moment.id);
      if (index >= 0) {
        _cloudMoments[index] = moment;
      } else {
        _cloudMoments.insert(0, moment);
      }
    });
  }

  Future<List<String>?> _showGroupMultiSelect({
    required String title,
    required List<String> initialIds,
  }) async {
    final selected = initialIds.toSet();
    return showModalBottomSheet<List<String>>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, setSheetState) => SafeArea(
          child: Container(
            padding: const EdgeInsets.fromLTRB(18, 18, 18, 22),
            decoration: BoxDecoration(
              color: widget.isDarkMode ? const Color(0xFF1E2533) : Colors.white,
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(22)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: widget.isDarkMode ? Colors.white : AppColors.ink,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 12),
                if (_groups.isEmpty)
                  Text(
                    '暂无可选小组',
                    style: TextStyle(
                      color: widget.isDarkMode
                          ? const Color(0xFFC2C8D6)
                          : AppColors.body,
                    ),
                  )
                else
                  ..._groups.map(
                    (group) => CheckboxListTile(
                      value: selected.contains(group.id),
                      title: Text(group.name),
                      subtitle: Text('${group.memberCount} 人'),
                      onChanged: (checked) {
                        setSheetState(() {
                          if (checked == true) {
                            selected.add(group.id);
                          } else {
                            selected.remove(group.id);
                          }
                        });
                      },
                    ),
                  ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    TextButton(
                      onPressed: () => Navigator.of(sheetContext).pop(),
                      child: const Text('取消'),
                    ),
                    const Spacer(),
                    FilledButton(
                      onPressed: () =>
                          Navigator.of(sheetContext).pop(selected.toList()),
                      child: const Text('确定'),
                    ),
                  ],
                ),
              ],
            ),
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
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, setSheetState) => SafeArea(
          child: Container(
            padding: const EdgeInsets.fromLTRB(18, 18, 18, 22),
            decoration: BoxDecoration(
              color: widget.isDarkMode ? const Color(0xFF1E2533) : Colors.white,
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(22)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _VisibilityPicker(
                  isDarkMode: widget.isDarkMode,
                  groups: _groups,
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
                    TextButton(
                      onPressed: () => Navigator.of(sheetContext).pop(),
                      child: const Text('取消'),
                    ),
                    const Spacer(),
                    FilledButton(
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
                      child: const Text('保存'),
                    ),
                  ],
                ),
              ],
            ),
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
    required this.accent,
    required this.titleColor,
    required this.bodyColor,
    required this.eventCount,
    required this.momentCount,
    required this.packageCount,
  });

  final bool isDarkMode;
  final Color accent;
  final Color titleColor;
  final Color bodyColor;
  final int eventCount;
  final int momentCount;
  final int packageCount;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: isDarkMode ? const Color(0xFF1E2533) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          if (!isDarkMode)
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 14,
              offset: const Offset(0, 8),
            ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: StudyAssetIcon(
                  asset: AppAssets.sideMomentsIcon,
                  color: accent,
                  size: 24,
                  fallbackIcon: Icons.auto_stories_rounded,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '学习轨迹社区',
                      style: TextStyle(
                        color: titleColor,
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '把学习行为、复盘和成果沉淀成清楚的学习轨迹',
                      style: TextStyle(color: bodyColor, fontSize: 12),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              _MetricPill(
                label: '轨迹事件',
                value: '$eventCount',
                accent: accent,
                isDarkMode: isDarkMode,
              ),
              _MetricPill(
                label: '主动分享',
                value: '$momentCount',
                accent: const Color(0xFF19A974),
                isDarkMode: isDarkMode,
              ),
              _MetricPill(
                label: '成果包',
                value: '$packageCount',
                accent: const Color(0xFFF59E0B),
                isDarkMode: isDarkMode,
              ),
            ],
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
    required this.onTap,
  });

  final bool isDarkMode;
  final Color accent;
  final Color titleColor;
  final Color bodyColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isDarkMode ? const Color(0xFF1E2533) : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isDarkMode
                ? Colors.white.withValues(alpha: 0.06)
                : const Color(0xFFE8ECF5),
          ),
        ),
        child: Row(
          children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: accent.withValues(alpha: 0.14),
              child: Icon(Icons.person_rounded, color: accent, size: 19),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                '分享今天的学习现场...',
                style: TextStyle(color: bodyColor, fontSize: 14),
              ),
            ),
            Icon(Icons.photo_camera_rounded, color: bodyColor, size: 20),
          ],
        ),
      ),
    );
  }
}

class _MetricPill extends StatelessWidget {
  const _MetricPill({
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
    return ConstrainedBox(
      constraints: const BoxConstraints(minWidth: 96, maxWidth: 132),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        decoration: BoxDecoration(
          color: accent.withValues(alpha: isDarkMode ? 0.16 : 0.1),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: accent,
                fontSize: 20,
                fontWeight: FontWeight.w900,
              ),
            ),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: accent, fontSize: 11),
            ),
          ],
        ),
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
                '学习能力徽章',
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
                  '像成就系统一样记录能力成长，徽章图标已接入学习能力主题资产。',
                  style: TextStyle(color: bodyColor, fontSize: 12, height: 1.35),
                ),
              ),
              BadgePill(
                label: '$unlockedCount/${badges.length} 已解锁',
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
    final statusText = badge.unlocked ? '已解锁' : '未解锁';
    final levelText = progress >= 1
        ? 'Lv.3'
        : progress >= 0.66
            ? 'Lv.2'
            : progress > 0
                ? 'Lv.1'
                : 'Lv.0';
    return Opacity(
      opacity: badge.unlocked ? 1 : 0.58,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: badge.unlocked
              ? accent.withValues(alpha: isDarkMode ? 0.18 : 0.1)
              : (isDarkMode
                  ? Colors.white.withValues(alpha: 0.05)
                  : const Color(0xFFF2F5FC)),
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
              IconButton.filledTonal(
                tooltip: '手动记录地点',
                onPressed: isCheckingLocation ? null : () => onCheckIn(),
                icon: isCheckingLocation
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.edit_location_alt_rounded, size: 18),
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
    required this.titleColor,
    required this.bodyColor,
    required this.onTap,
  });

  final _VisibilityOption option;
  final bool selected;
  final bool isDarkMode;
  final Color titleColor;
  final Color bodyColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final fillColor = selected
        ? StudyUi.primary.withValues(alpha: isDarkMode ? 0.22 : 0.10)
        : isDarkMode
            ? Colors.white.withValues(alpha: 0.05)
            : const Color(0xFFF4F6FB);
    final borderColor = selected
        ? StudyUi.primary.withValues(alpha: 0.55)
        : isDarkMode
            ? Colors.white.withValues(alpha: 0.08)
            : const Color(0xFFE8ECF5);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
          decoration: BoxDecoration(
            color: fillColor,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: borderColor),
          ),
          child: Row(
            children: [
              Icon(
                option.icon,
                color: selected ? StudyUi.primary : bodyColor,
                size: 20,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      option.title,
                      style: TextStyle(
                        color: selected ? StudyUi.primary : titleColor,
                        fontWeight: FontWeight.w800,
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
                color: selected ? StudyUi.primary : bodyColor,
                size: 19,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _VisibilityPicker extends StatelessWidget {
  const _VisibilityPicker({
    required this.isDarkMode,
    required this.groups,
    required this.visibility,
    required this.allowedGroupIds,
    required this.deniedGroupIds,
    required this.onVisibilityChanged,
    required this.onChooseGroups,
  });

  final bool isDarkMode;
  final List<GroupInfo> groups;
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
    final showGroups = visibility == LearningMomentVisibility.includeGroups ||
        visibility == LearningMomentVisibility.excludeGroups;
    final titleColor = isDarkMode ? Colors.white : AppColors.ink;
    final bodyColor =
        isDarkMode ? const Color(0xFFC2C8D6) : AppColors.body;
    const options = [
      _VisibilityOption(
        LearningMomentVisibility.public,
        Icons.groups_rounded,
        '公开',
        '我的小组成员可见',
      ),
      _VisibilityOption(
        LearningMomentVisibility.private,
        Icons.lock_rounded,
        '私密',
        '仅自己可见',
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
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 8),
        ...options.map(
          (option) => Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: _VisibilityOptionTile(
              option: option,
              selected: visibility == option.visibility,
              isDarkMode: isDarkMode,
              titleColor: titleColor,
              bodyColor: bodyColor,
              onTap: () => onVisibilityChanged(option.visibility),
            ),
          ),
        ),
        if (showGroups) ...[
          const SizedBox(height: 2),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              ...activeIds.map(
                (id) => Chip(
                  label: Text(_groupName(groups, id)),
                  visualDensity: VisualDensity.compact,
                ),
              ),
              ActionChip(
                avatar: const Icon(Icons.group_add_rounded, size: 17),
                label: Text(activeIds.isEmpty ? '选择小组' : '重新选择'),
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
    return '未知小组';
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
        color: isDarkMode ? const Color(0xFF1E2533) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDarkMode
              ? Colors.white.withValues(alpha: 0.08)
              : const Color(0xFFE7EBF5),
        ),
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
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: isDarkMode ? 0.18 : 0.11),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(Icons.edit_note_rounded, color: accent, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '发布学迹动态',
                        style: TextStyle(
                          color: titleColor,
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '记录学习现场、错题、板书或阶段成果。',
                        style: TextStyle(color: bodyColor, fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            TextField(
              controller: controller,
              minLines: 5,
              maxLines: 8,
              style: TextStyle(color: titleColor, fontSize: 14),
              decoration: InputDecoration(
                hintText: '今天学了什么？拍到的板书、课件、错题也可以一起发。',
                hintStyle: TextStyle(color: bodyColor),
                border: InputBorder.none,
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
                DropdownButtonFormField<String>(
                  value: currentCourse,
                  isExpanded: true,
                  dropdownColor:
                      isDarkMode ? const Color(0xFF1E2533) : Colors.white,
                  decoration: _fieldDecoration(
                    isDarkMode,
                    accent,
                    Icons.school_rounded,
                  ),
                  items: [
                    const DropdownMenuItem(value: '', child: Text('不关联课程')),
                    ...courses.map(
                      (course) => DropdownMenuItem(
                        value: course,
                        child: Text(course, overflow: TextOverflow.ellipsis),
                      ),
                    ),
                  ],
                  onChanged: onCourseChanged,
                ),
                const SizedBox(height: 10),
                _VisibilityPicker(
                  isDarkMode: isDarkMode,
                  groups: groups,
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
                IconButton.filledTonal(
                  tooltip: '添加图片',
                  onPressed:
                      imagePaths.length >= 9 ? null : () => onPickImages(),
                  icon: const Icon(Icons.add_photo_alternate_rounded),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: isPosting ? null : () => onPost(),
                    icon: isPosting
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.send_rounded),
                    label: Text(
                      visibility == LearningMomentVisibility.private
                          ? '保存私密动态'
                          : '发布动态',
                    ),
                    style: FilledButton.styleFrom(
                      backgroundColor: accent,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
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

  InputDecoration _fieldDecoration(
    bool isDarkMode,
    Color accent,
    IconData icon,
  ) {
    return InputDecoration(
      isDense: true,
      prefixIcon: Icon(icon, color: accent),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide.none,
      ),
      filled: true,
      fillColor: isDarkMode
          ? Colors.white.withValues(alpha: 0.06)
          : const Color(0xFFF3F6FF),
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
              StudyAssetIcon(
                asset: AppAssets.featureNotesIcon,
                color: accent,
                size: 22,
                fallbackIcon: Icons.inventory_2_rounded,
              ),
              const SizedBox(width: 8),
              Text(
                '作品成果包',
                style: TextStyle(
                  color: titleColor,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            '按课程聚合学习记录、任务、笔记、闪卡和AI操作。',
            style: TextStyle(color: bodyColor, fontSize: 12),
          ),
          const SizedBox(height: 12),
          ...packages.take(3).map(
                (package) => Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: isDarkMode ? 0.12 : 0.08),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              package.courseName,
                              style: TextStyle(
                                color: titleColor,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${package.eventCount} 条轨迹 · ${package.aiCount} 次整理 · ${package.shareableCount} 条成果',
                              style: TextStyle(color: bodyColor, fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        tooltip: '保存成果包',
                        onPressed: () => onSavePackage(package),
                        icon: const Icon(Icons.save_outlined, size: 18),
                      ),
                      IconButton(
                        tooltip: '生成动态文案',
                        onPressed: () => onUsePackage(package),
                        icon: const Icon(Icons.edit_note_rounded, size: 19),
                      ),
                    ],
                  ),
                ),
              ),
          if (cloudPackages.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              '已保存成果',
              style: TextStyle(
                color: bodyColor,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            ...cloudPackages.take(3).map(
                  (package) => ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(
                      package.featured ? Icons.push_pin_rounded : Icons.inventory_2_outlined,
                      color: accent,
                    ),
                    title: Text(
                      package.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: titleColor, fontWeight: FontWeight.w700),
                    ),
                    subtitle: Text(
                      package.visibility == 'private' ? '私密成果包' : '已分享到小组',
                      style: TextStyle(color: bodyColor, fontSize: 12),
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          tooltip: '分享到小组',
                          onPressed: () => onSharePackage(package),
                          icon: const Icon(Icons.groups_rounded),
                        ),
                        IconButton(
                          tooltip: package.featured ? '取消精选' : '置顶精选',
                          onPressed: () => onToggleFeatured(package),
                          icon: Icon(
                            package.featured
                                ? Icons.push_pin_rounded
                                : Icons.push_pin_outlined,
                          ),
                        ),
                        IconButton(
                          tooltip: '生成成果封面',
                          onPressed: () => onGenerateCover(package),
                          icon: const Icon(Icons.image_outlined),
                        ),
                      ],
                    ),
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
              StudyAssetIcon(
                asset: AppAssets.sideAchievementsIcon,
                color: accent,
                size: 22,
                fallbackIcon: Icons.workspace_premium_rounded,
              ),
              const SizedBox(width: 8),
              Text(
                '精选成果墙',
                style: TextStyle(
                  color: titleColor,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (packageList.isNotEmpty)
            ...packageList.map(
              (package) => ListTile(
                contentPadding: EdgeInsets.zero,
                dense: true,
                leading: Icon(Icons.push_pin_rounded, color: accent),
                title: Text(
                  package.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: titleColor, fontWeight: FontWeight.w700),
                ),
                subtitle: Text(
                  package.description.isEmpty ? '云端精选成果包' : package.description,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: bodyColor, fontSize: 12),
                ),
              ),
            )
          else
            ...list.map(
            (event) => ListTile(
              contentPadding: EdgeInsets.zero,
              dense: true,
              title: Text(
                event.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: titleColor, fontWeight: FontWeight.w700),
              ),
              subtitle: Text(
                event.typeLabel,
                style: TextStyle(color: bodyColor, fontSize: 12),
              ),
              trailing: TextButton(
                onPressed: () => onShare(event),
                child: const Text('精选'),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TraceToolbar extends StatelessWidget {
  const _TraceToolbar({
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
        StudyAssetIcon(
          asset: AppAssets.sideMomentsIcon,
          color: accent,
          size: 22,
          fallbackIcon: Icons.timeline_rounded,
        ),
        const SizedBox(width: 8),
        Text(
          '学习轨迹',
          style: TextStyle(
            color: titleColor,
            fontSize: 17,
            fontWeight: FontWeight.w800,
          ),
        ),
        const Spacer(),
        StudyPopupMenuButton<LearningTraceEventType?>(
          tooltip: '筛选轨迹',
          onSelected: onFilterChanged,
          itemBuilder: (context) => [
            const PopupMenuItem(value: null, child: Text('全部轨迹')),
            ...LearningTraceEventType.values.map(
              (type) => PopupMenuItem(
                value: type,
                child: Text(_labelFor(type)),
              ),
            ),
          ],
          child: Chip(
            avatar: Icon(Icons.filter_list_rounded, color: accent, size: 16),
            label: Text(filter == null ? '全部' : _labelFor(filter!)),
            visualDensity: VisualDensity.compact,
          ),
        ),
      ],
    );
  }

  static String _labelFor(LearningTraceEventType type) {
    return switch (type) {
      LearningTraceEventType.moment => '动态',
      LearningTraceEventType.studyLog => '学习记录',
      LearningTraceEventType.taskCompleted => '任务完成',
      LearningTraceEventType.noteCreated => '笔记沉淀',
      LearningTraceEventType.flashcardCreated => '闪卡复习',
      LearningTraceEventType.aiAction => 'AI操作',
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
                      PopupMenuButton<String>(
                        tooltip: '动态操作',
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
                              child: Text('删除动态'),
                            ),
                        ],
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
                    TextButton.icon(
                      onPressed: onLike,
                      icon: Icon(
                        moment.likedByMe
                            ? Icons.favorite_rounded
                            : Icons.favorite_border_rounded,
                        size: 18,
                      ),
                      label: Text(moment.likeCount == 0
                          ? '点赞'
                          : '${moment.likeCount}'),
                    ),
                    TextButton.icon(
                      onPressed: onComment,
                      icon: const Icon(Icons.mode_comment_outlined, size: 18),
                      label: Text(moment.commentCount == 0
                          ? '评论'
                          : '${moment.commentCount}'),
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
}

class _MomentAvatar extends StatelessWidget {
  const _MomentAvatar({required this.author, required this.accent});

  final LearningMomentAuthor author;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final imageUrl = author.avatarImageUrl;
    return CircleAvatar(
      radius: 20,
      backgroundColor: accent.withValues(alpha: 0.14),
      backgroundImage:
          imageUrl != null && imageUrl.startsWith('http') ? NetworkImage(imageUrl) : null,
      child: imageUrl != null && imageUrl.startsWith('http')
          ? null
          : Text(
              author.avatarEmoji.isEmpty ? '🎓' : author.avatarEmoji,
              style: const TextStyle(fontSize: 18),
            ),
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
  });

  final bool isDarkMode;
  final Color accent;
  final Color bodyColor;
  final String? message;

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
            message ?? '还没有动态，点上方输入框发布第一条学习现场',
            textAlign: TextAlign.center,
            style: TextStyle(color: bodyColor, fontSize: 13),
          ),
        ],
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
