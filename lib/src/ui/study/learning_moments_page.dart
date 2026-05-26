import 'dart:async';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../controllers/app_data_controller.dart';
import '../../models/ai_capability_trace.dart';
import '../../models/community_evidence.dart' as cloud;
import '../../models/learning_moment.dart';
import '../../services/group_service.dart';
import '../../services/picked_image_store.dart';
import '../../theme/app_theme.dart';
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

  String _selectedCourse = '';
  String? _selectedGroupId;
  LearningMomentVisibility _visibility = LearningMomentVisibility.private;
  LearningTraceEventType? _typeFilter;
  bool _isPosting = false;
  bool _isGeneratingDraft = false;
  bool _isLoadingGroups = false;
  bool _isTranslating = false;
  bool _isSavingPackage = false;
  bool _isCheckingLocation = false;
  final List<cloud.EvidencePackage> _cloudPackages = [];
  final List<cloud.LocationCheckIn> _locationCheckIns = [];
  List<_CapabilityBadge> _cloudCapabilityBadges = const [];
  List<AiCapabilityTrace> _lastCapabilityTraces = const [];

  @override
  void initState() {
    super.initState();
    unawaited(_loadGroups());
    unawaited(_loadCloudPackages());
    unawaited(_loadLocationCheckIns());
    unawaited(_loadCapabilityBadges());
  }

  @override
  void dispose() {
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
          _visibility = LearningMomentVisibility.private;
        }
      });
    } catch (_) {
      if (mounted) {
        setState(() {
          _groups.clear();
          _selectedGroupId = null;
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
        title: const Text(
          '学迹动态',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
        actions: [
          IconButton(
            tooltip: '刷新小组',
            onPressed: widget.controller.isLoggedIn ? _loadGroups : null,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: AnimatedBuilder(
        animation: widget.controller,
        builder: (context, _) {
          final allEvents = widget.controller.learningTraceEvents;
          final events = _filteredEvents(allEvents);
          final packages = _buildEvidencePackages(allEvents);
          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 10, 20, 36),
            children: [
              _HeaderPanel(
                isDarkMode: widget.isDarkMode,
                accent: accent,
                titleColor: titleColor,
                bodyColor: bodyColor,
                eventCount: allEvents.length,
                momentCount: widget.controller.learningMoments.length,
                packageCount: packages.length,
              ),
              const SizedBox(height: 14),
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
              _ComposerCard(
                isDarkMode: widget.isDarkMode,
                accent: accent,
                titleColor: titleColor,
                bodyColor: bodyColor,
                controller: _contentController,
                courses: widget.controller.courseNames,
                groups: _groups,
                selectedCourse: _selectedCourse,
                selectedGroupId: _selectedGroupId,
                imagePaths: _imagePaths,
                isPosting: _isPosting,
                isGeneratingDraft: _isGeneratingDraft,
                isTranslating: _isTranslating,
                isCheckingLocation: _isCheckingLocation,
                onCourseChanged: (value) {
                  setState(() => _selectedCourse = value ?? '');
                },
                onGroupChanged: (value) {
                  setState(() {
                    _selectedGroupId =
                        value == null || value.isEmpty ? null : value;
                    _visibility = _selectedGroupId == null
                        ? LearningMomentVisibility.private
                        : LearningMomentVisibility.group;
                  });
                },
                onPickImages: _pickImages,
                onRemoveImage: (path) {
                  setState(() => _imagePaths.remove(path));
                },
                onGenerateDraft: _generateMomentDraft,
                onTranslate: _translateMomentDraft,
                onLocationCheckIn: _createLocationCheckIn,
                onPost: _publishMoment,
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
                onUsePackage: _useEvidencePackage,
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
              const SizedBox(height: 18),
              _TraceToolbar(
                accent: accent,
                titleColor: titleColor,
                bodyColor: bodyColor,
                filter: _typeFilter,
                onFilterChanged: (value) => setState(() => _typeFilter = value),
              ),
              const SizedBox(height: 10),
              if (events.isEmpty)
                _EmptyTimeline(
                  isDarkMode: widget.isDarkMode,
                  accent: accent,
                  bodyColor: bodyColor,
                )
              else
                ...events.map(
                  (event) => _TraceEventCard(
                    event: event,
                    isDarkMode: widget.isDarkMode,
                    accent: accent,
                    titleColor: titleColor,
                    bodyColor: bodyColor,
                    onShare: event.isShareable
                        ? () => _shareTraceEvent(event)
                        : null,
                    onDelete: event.type == LearningTraceEventType.moment &&
                            event.sourceId != null
                        ? () => _deleteMoment(event.sourceId!)
                        : null,
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  List<LearningTraceEvent> _filteredEvents(List<LearningTraceEvent> events) {
    final filter = _typeFilter;
    if (filter == null) return events;
    return events.where((event) => event.type == filter).toList();
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
      _CapabilityBadge('大模型', events.isNotEmpty || records.isNotEmpty),
      _CapabilityBadge('通用 OCR', hasImageMoment || _imagePaths.isNotEmpty),
      _CapabilityBadge('AI Actions', hasAiAction || records.isNotEmpty),
      _CapabilityBadge('学习记忆', hasMemory),
      _CapabilityBadge('闭环留痕', hasLoop || events.length >= 3),
      _CapabilityBadge('学迹分享', moments.isNotEmpty),
    ];
  }

  Future<void> _pickImages() async {
    if (_imagePaths.length >= 3) return;
    try {
      final picked = await _picker.pickMultiImage(imageQuality: 82);
      if (picked.isEmpty) return;
      final remain = 3 - _imagePaths.length;
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

  Future<void> _generateMomentDraft() async {
    if (_isGeneratingDraft) return;
    setState(() => _isGeneratingDraft = true);
    final recentEvents = widget.controller.learningTraceEvents.take(8).map(
          (event) => '${event.typeLabel}｜${event.courseName}｜${event.title}'
              '${event.summary.trim().isEmpty ? '' : '｜${event.summary.trim()}'}',
        );
    final prompt = [
      '请为 StudyTrace 学迹动态生成一条可发布的学习证据动态。',
      '要求：突出真实学习过程、AI 辅助行动、可追溯证据链；不要写成 AI 导学、错题或题库广告。',
      if (_selectedCourse.isNotEmpty) '关联课程：$_selectedCourse',
      if (_imagePaths.isNotEmpty) '用户已添加 ${_imagePaths.length} 张学习现场图片。',
      '最近学习轨迹：',
      ...recentEvents,
      '输出 80-140 字中文正文，可带 2-4 个短标签。',
    ].join('\n');
    try {
      final text = await widget.controller.aiStudyService.generateAssistantReply(
        input: prompt,
        purpose: 'note',
      );
      if (!mounted) return;
      setState(() => _contentController.text = text.trim());
    } catch (_) {
      final fallback = _localMomentDraft();
      if (mounted) {
        setState(() => _contentController.text = fallback);
        _showSnack('AI 动态草稿暂不可用，已生成本地草稿');
      }
    } finally {
      if (mounted) setState(() => _isGeneratingDraft = false);
    }
  }

  String _localMomentDraft() {
    final events = widget.controller.learningTraceEvents;
    final course =
        _selectedCourse.isNotEmpty ? _selectedCourse : '今天的学习任务';
    final aiCount = events.where((event) => event.isAiGenerated).length;
    return '完成了 $course 的阶段性整理：任务、记录、笔记和闪卡都沉淀进学迹时间线，'
        '其中 $aiCount 条轨迹带有 AI 辅助痕迹。#学习证据链 #AI学习操作层';
  }

  Future<void> _translateMomentDraft() async {
    final content = _contentController.text.trim();
    if (content.isEmpty || _isTranslating) return;
    setState(() => _isTranslating = true);
    try {
      final result =
          await widget.controller.vivoCapabilityService.translate(content);
      if (!mounted) return;
      setState(() {
        _contentController.text = '$content\n\n${result.text}';
        _lastCapabilityTraces = result.capabilityTraces;
      });
      unawaited(
        widget.controller.activityService
            .create(
              type: 'translatedMoment',
              title: '双语学迹动态已生成',
              summary: content,
              sourceType: 'learning_moment_draft',
              sourceId: 'translation_${DateTime.now().microsecondsSinceEpoch}',
            )
            .catchError((_) {}),
      );
      _showSnack('已生成双语学习动态');
    } catch (_) {
      _showSnack('翻译能力暂不可用，已保留原文');
    } finally {
      if (mounted) setState(() => _isTranslating = false);
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
        title: '${package.courseName} 学习证据包',
        courseName: package.courseName == '未归课程' ? '' : package.courseName,
        description:
            '${package.eventCount} 条轨迹，${package.aiCount} 次 AI 辅助，${package.shareableCount} 项可分享成果。',
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
      _showSnack('证据包已保存，可继续生成封面或分享至小组');
    } catch (_) {
      _useEvidencePackage(package);
      _showSnack('云端证据包暂不可用，已转为本地动态文案');
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
          _showSnack('封面任务仍在处理中：$taskId');
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
        _showSnack('成果封面已回填到证据包');
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
      _showSnack('成果封面任务已提交：${task.taskId}');
    } catch (_) {
      _showSnack('图片生成能力暂不可用，证据包内容不受影响');
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
      _showSnack('证据包已分享到 ${group.name}');
    } catch (_) {
      _showSnack('证据包分享失败，请稍后重试');
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
      _showSnack('请先登录，再保存校园地点证据');
      return;
    }
    final draft = await _showLocationCheckInDialog();
    if (draft == null || draft.title.isEmpty) return;
    final coordinates = _parseCoordinates(draft.coordinates);
    if (!mounted) return;
    setState(() => _isCheckingLocation = true);
    try {
      final result = coordinates == null
          ? await widget.controller.vivoCapabilityService.searchPoi(
              draft.title,
              city: draft.city,
            )
          : await widget.controller.vivoCapabilityService.reverseGeocode(
              '${coordinates.latitude},${coordinates.longitude}',
            );
      final payload = _payloadMap(result['result']);
      final address = _poiAddress(result['result']);
      final checkIn =
          await widget.controller.communityEvidenceService.createLocationCheckIn(
        title: draft.title,
        address: _trimAddress(address.isEmpty ? draft.city : address),
        latitude: coordinates?.latitude,
        longitude: coordinates?.longitude,
        groupId: draft.shareToGroup ? draft.groupId : null,
        visibility: draft.shareToGroup ? 'group' : 'private',
        poiPayloadJson: payload,
      );
      if (!mounted) return;
      setState(() {
        _lastCapabilityTraces = parseCapabilityTraces(result['capabilityTraces']);
        _locationCheckIns.insert(0, checkIn);
      });
      unawaited(_loadCapabilityBadges());
      _showSnack(draft.shareToGroup ? '地点已分享到小组证据链' : '地点已保存为私密学习证据');
    } catch (_) {
      await _saveManualLocationCheckIn(draft, coordinates);
    } finally {
      if (mounted) setState(() => _isCheckingLocation = false);
    }
  }

  Future<_LocationCheckInDraft?> _showLocationCheckInDialog() async {
    final titleController = TextEditingController(
      text: _selectedCourse.trim().isEmpty ? '' : '${_selectedCourse.trim()} 自习',
    );
    final cityController = TextEditingController();
    final coordinateController = TextEditingController();
    var shareToGroup = false;
    var selectedGroupId = _selectedGroupId ??
        (_groups.isNotEmpty ? _groups.first.id : null);
    try {
      return await showDialog<_LocationCheckInDraft>(
        context: context,
        builder: (dialogContext) {
          return StatefulBuilder(
            builder: (context, setDialogState) => AlertDialog(
              title: const Text('校园学习地图'),
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
                          labelText: '地点',
                          hintText: '图书馆三楼 / 信息楼自习室',
                        ),
                        onSubmitted: (_) => _popLocationDraft(
                          dialogContext,
                          titleController,
                          cityController,
                          coordinateController,
                          shareToGroup,
                          selectedGroupId,
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: cityController,
                        decoration: const InputDecoration(
                          labelText: '城市或校区',
                          hintText: '可选',
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: coordinateController,
                        keyboardType: TextInputType.text,
                        decoration: const InputDecoration(
                          labelText: '坐标',
                          hintText: '可选，如 39.9,116.3',
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
                    coordinateController,
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
      coordinateController.dispose();
    }
  }

  void _popLocationDraft(
    BuildContext dialogContext,
    TextEditingController titleController,
    TextEditingController cityController,
    TextEditingController coordinateController,
    bool shareToGroup,
    String? selectedGroupId,
  ) {
    final title = titleController.text.trim();
    if (title.isEmpty) return;
    Navigator.of(dialogContext).pop(
      _LocationCheckInDraft(
        title: title,
        city: cityController.text.trim(),
        coordinates: coordinateController.text.trim(),
        shareToGroup: shareToGroup && selectedGroupId != null,
        groupId: selectedGroupId,
      ),
    );
  }

  Future<void> _saveManualLocationCheckIn(
    _LocationCheckInDraft draft,
    _CoordinatePair? coordinates,
  ) async {
    try {
      final checkIn =
          await widget.controller.communityEvidenceService.createLocationCheckIn(
        title: draft.title,
        address: _trimAddress(draft.city),
        latitude: coordinates?.latitude,
        longitude: coordinates?.longitude,
        groupId: draft.shareToGroup ? draft.groupId : null,
        visibility: draft.shareToGroup ? 'group' : 'private',
        poiPayloadJson: {
          'fallback': true,
          'source': 'manual',
          'query': draft.title,
          if (draft.city.isNotEmpty) 'city': draft.city,
          if (draft.coordinates.isNotEmpty) 'coordinates': draft.coordinates,
        },
      );
      if (!mounted) return;
      setState(() => _locationCheckIns.insert(0, checkIn));
      unawaited(_loadCapabilityBadges());
      _showSnack('POI/地理编码不可用，已按手动地点保存证据');
    } catch (_) {
      _showSnack('地点保存失败，请稍后重试');
    }
  }

  Map<String, dynamic> _payloadMap(dynamic raw) {
    if (raw is Map) return raw.cast<String, dynamic>();
    if (raw is List) return {'items': raw};
    return {'raw': raw?.toString() ?? ''};
  }

  String _poiAddress(dynamic raw) {
    if (raw is List && raw.isNotEmpty) return _poiAddress(raw.first);
    if (raw is Map) {
      final result = raw['result'];
      final candidates = [
        raw['address'],
        raw['formatted_address'],
        raw['formattedAddress'],
        raw['name'],
        if (result is Map) result['address'],
        if (result is Map) result['formatted_address'],
        if (result is Map) result['name'],
      ];
      return candidates
          .map((item) => item?.toString().trim() ?? '')
          .firstWhere((item) => item.isNotEmpty, orElse: () => '');
    }
    return '';
  }

  String _trimAddress(String value) {
    final normalized = value.trim();
    if (normalized.length <= 240) return normalized;
    return normalized.substring(0, 240);
  }

  _CoordinatePair? _parseCoordinates(String value) {
    final normalized = value.trim();
    if (normalized.isEmpty) return null;
    final parts = normalized.split(RegExp(r'[,，\s]+'));
    if (parts.length < 2) return null;
    final latitude = double.tryParse(parts[0]);
    final longitude = double.tryParse(parts[1]);
    if (latitude == null || longitude == null) return null;
    if (latitude < -90 || latitude > 90 || longitude < -180 || longitude > 180) {
      return null;
    }
    return _CoordinatePair(latitude, longitude);
  }


  Future<void> _publishMoment() async {
    final content = _contentController.text.trim();
    if (content.isEmpty && _imagePaths.isEmpty) {
      _showSnack('写点学习收获，或至少添加一张图片');
      return;
    }
    if (_visibility == LearningMomentVisibility.group &&
        (_selectedGroupId == null || _selectedGroupId!.isEmpty)) {
      _showSnack('请选择要发布的小组，或切回私密证据链');
      return;
    }
    setState(() => _isPosting = true);
    final isGroupPost = _visibility == LearningMomentVisibility.group;
    try {
      await widget.controller.publishLearningMoment(
        content: content.isEmpty ? '分享了一组学习图片' : content,
        courseName: _selectedCourse,
        imagePaths: List<String>.from(_imagePaths),
        visibility: _visibility,
        groupId: _visibility == LearningMomentVisibility.group
            ? _selectedGroupId
            : null,
      );
      if (!mounted) return;
      setState(() {
        _contentController.clear();
        _imagePaths.clear();
        _selectedCourse = '';
        _selectedGroupId = null;
        _visibility = LearningMomentVisibility.private;
      });
      _showSnack(isGroupPost ? '已发布到小组动态' : '已保存为私密学习证据');
    } finally {
      if (mounted) setState(() => _isPosting = false);
    }
  }

  Future<void> _shareTraceEvent(LearningTraceEvent event) async {
    await widget.controller.shareTraceEvent(event);
    _showSnack('已转发到私密学迹动态');
  }

  void _useEvidencePackage(_EvidencePackage package) {
    final validCourse = widget.controller.courseNames.contains(package.courseName)
        ? package.courseName
        : '';
    setState(() {
      _selectedCourse = validCourse;
      _contentController.text =
          '整理了「${package.courseName}」的学习证据包：${package.eventCount} 条轨迹、'
          '${package.aiCount} 次 AI 辅助、${package.shareableCount} 条可分享成果。'
          '这些记录把任务执行、笔记沉淀和复盘材料串成了可追溯的学习过程。';
    });
  }

  Future<void> _deleteMoment(String momentId) async {
    await widget.controller.deleteLearningMoment(momentId);
    _showSnack('已删除动态');
  }

  void _showSnack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
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
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(Icons.auto_stories_rounded, color: accent),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'AI 学习证据链社区',
                      style: TextStyle(
                        color: titleColor,
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '把学习行为、AI 干预和成果沉淀成可追溯证据',
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
              _MetricPill(
                label: '轨迹事件',
                value: '$eventCount',
                accent: accent,
                isDarkMode: isDarkMode,
              ),
              const SizedBox(width: 10),
              _MetricPill(
                label: '主动分享',
                value: '$momentCount',
                accent: const Color(0xFF19A974),
                isDarkMode: isDarkMode,
              ),
              const SizedBox(width: 10),
              _MetricPill(
                label: '证据包',
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
    return Expanded(
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
              style: TextStyle(
                color: accent,
                fontSize: 20,
                fontWeight: FontWeight.w900,
              ),
            ),
            Text(label, style: TextStyle(color: accent, fontSize: 11)),
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
              Icon(Icons.verified_rounded, color: accent, size: 20),
              const SizedBox(width: 8),
              Text(
                'vivo AI 能力徽章',
                style: TextStyle(
                  color: titleColor,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            '每次能力使用都会回到学习证据链，而不是停留在生成结果。',
            style: TextStyle(color: bodyColor, fontSize: 12),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: badges
                .map(
                  (badge) => Chip(
                    avatar: Icon(
                      badge.unlocked
                          ? Icons.check_circle_rounded
                          : Icons.radio_button_unchecked_rounded,
                      size: 16,
                      color: badge.unlocked ? accent : bodyColor,
                    ),
                    label: Text(
                      badge.current > 0
                          ? '${badge.label} ${badge.current}/${badge.target}'
                          : badge.label,
                    ),
                    labelStyle: TextStyle(
                      color: badge.unlocked ? titleColor : bodyColor,
                      fontWeight:
                          badge.unlocked ? FontWeight.w700 : FontWeight.w500,
                    ),
                    visualDensity: VisualDensity.compact,
                    backgroundColor: badge.unlocked
                        ? accent.withValues(alpha: 0.1)
                        : (isDarkMode
                            ? Colors.white.withValues(alpha: 0.05)
                            : const Color(0xFFF2F5FC)),
                  ),
                )
                .toList(),
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
              Icon(Icons.map_rounded, color: accent, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '校园学习地图',
                  style: TextStyle(
                    color: titleColor,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              Text(
                '${locations.length} 个地点',
                style: TextStyle(color: bodyColor, fontSize: 12),
              ),
              const SizedBox(width: 8),
              IconButton.filledTonal(
                tooltip: '地点打卡',
                onPressed: isCheckingLocation ? null : () => onCheckIn(),
                icon: isCheckingLocation
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.add_location_alt_rounded, size: 18),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (recent.isEmpty)
            Text(
              '还没有地点证据',
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
    if (location.latitude != null && location.longitude != null) {
      return '${location.latitude!.toStringAsFixed(4)}, ${location.longitude!.toStringAsFixed(4)}';
    }
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

class _ComposerCard extends StatelessWidget {
  const _ComposerCard({
    required this.isDarkMode,
    required this.accent,
    required this.titleColor,
    required this.bodyColor,
    required this.controller,
    required this.courses,
    required this.groups,
    required this.selectedCourse,
    required this.selectedGroupId,
    required this.imagePaths,
    required this.isPosting,
    required this.isGeneratingDraft,
    required this.isTranslating,
    required this.isCheckingLocation,
    required this.onCourseChanged,
    required this.onGroupChanged,
    required this.onPickImages,
    required this.onRemoveImage,
    required this.onGenerateDraft,
    required this.onTranslate,
    required this.onLocationCheckIn,
    required this.onPost,
  });

  final bool isDarkMode;
  final Color accent;
  final Color titleColor;
  final Color bodyColor;
  final TextEditingController controller;
  final List<String> courses;
  final List<GroupInfo> groups;
  final String selectedCourse;
  final String? selectedGroupId;
  final List<String> imagePaths;
  final bool isPosting;
  final bool isGeneratingDraft;
  final bool isTranslating;
  final bool isCheckingLocation;
  final ValueChanged<String?> onCourseChanged;
  final ValueChanged<String?> onGroupChanged;
  final FutureOr<void> Function() onPickImages;
  final ValueChanged<String> onRemoveImage;
  final FutureOr<void> Function() onGenerateDraft;
  final FutureOr<void> Function() onTranslate;
  final FutureOr<void> Function() onLocationCheckIn;
  final FutureOr<void> Function() onPost;

  @override
  Widget build(BuildContext context) {
    final currentCourse =
        selectedCourse.isNotEmpty && courses.contains(selectedCourse)
            ? selectedCourse
            : '';
    final groupValue = selectedGroupId != null &&
            groups.any((group) => group.id == selectedGroupId)
        ? selectedGroupId!
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
      child: Column(
        children: [
          TextField(
            controller: controller,
            minLines: 3,
            maxLines: 5,
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
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<String>(
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
              ),
              const SizedBox(width: 10),
              Expanded(
                child: DropdownButtonFormField<String>(
                  value: groupValue,
                  isExpanded: true,
                  dropdownColor:
                      isDarkMode ? const Color(0xFF1E2533) : Colors.white,
                  decoration: _fieldDecoration(
                    isDarkMode,
                    accent,
                    Icons.lock_rounded,
                  ),
                  items: [
                    const DropdownMenuItem(value: '', child: Text('私密证据链')),
                    ...groups.map(
                      (group) => DropdownMenuItem(
                        value: group.id,
                        child: Text('发到 ${group.name}',
                            overflow: TextOverflow.ellipsis),
                      ),
                    ),
                  ],
                  onChanged: onGroupChanged,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              IconButton.filledTonal(
                tooltip: '添加图片',
                onPressed: imagePaths.length >= 3 ? null : () => onPickImages(),
                icon: const Icon(Icons.add_photo_alternate_rounded),
              ),
              const SizedBox(width: 8),
              OutlinedButton.icon(
                onPressed: isGeneratingDraft ? null : () => onGenerateDraft(),
                icon: isGeneratingDraft
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.auto_awesome_rounded, size: 18),
                label: Text(isGeneratingDraft ? '生成中' : 'AI 草稿'),
              ),
              const SizedBox(width: 6),
              IconButton.filledTonal(
                tooltip: '生成双语动态',
                onPressed: isTranslating ? null : () => onTranslate(),
                icon: isTranslating
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.translate_rounded, size: 18),
              ),
              const SizedBox(width: 6),
              IconButton.filledTonal(
                tooltip: '校园地点打卡',
                onPressed: isCheckingLocation ? null : () => onLocationCheckIn(),
                icon: isCheckingLocation
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.location_on_rounded, size: 18),
              ),
              const Spacer(),
              FilledButton.icon(
                onPressed: isPosting ? null : () => onPost(),
                icon: isPosting
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.send_rounded),
                label: const Text('发布'),
                style: FilledButton.styleFrom(
                  backgroundColor: accent,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
            ],
          ),
        ],
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
              Icon(Icons.inventory_2_rounded, color: accent, size: 20),
              const SizedBox(width: 8),
              Text(
                '作品证据包',
                style: TextStyle(
                  color: titleColor,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            '按课程聚合学习记录、任务、笔记、闪卡和 AI 操作。',
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
                              '${package.eventCount} 条轨迹 · ${package.aiCount} 次 AI · ${package.shareableCount} 条成果',
                              style: TextStyle(color: bodyColor, fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        tooltip: '保存证据包',
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
                      package.visibility == 'private' ? '私密证据包' : '已分享到小组',
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
              Icon(Icons.workspace_premium_rounded, color: accent, size: 20),
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
                  package.description.isEmpty ? '云端精选证据包' : package.description,
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
        Icon(Icons.timeline_rounded, color: accent, size: 20),
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
        PopupMenuButton<LearningTraceEventType?>(
          tooltip: '筛选轨迹',
          initialValue: filter,
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
      LearningTraceEventType.aiAction => 'AI 操作',
    };
  }
}

class _TraceEventCard extends StatelessWidget {
  const _TraceEventCard({
    required this.event,
    required this.isDarkMode,
    required this.accent,
    required this.titleColor,
    required this.bodyColor,
    this.onShare,
    this.onDelete,
  });

  final LearningTraceEvent event;
  final bool isDarkMode;
  final Color accent;
  final Color titleColor;
  final Color bodyColor;
  final VoidCallback? onShare;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final eventAccent = _accentFor(event.type, accent);
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDarkMode ? const Color(0xFF1E2533) : Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: eventAccent.withValues(alpha: isDarkMode ? 0.22 : 0.14),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: eventAccent.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Icon(_iconFor(event.type), color: eventAccent, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text(
                          event.typeLabel,
                          style: TextStyle(
                            color: eventAccent,
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        Text(
                          _formatTime(event.happenedAt),
                          style: TextStyle(color: bodyColor, fontSize: 12),
                        ),
                        if (event.courseName.isNotEmpty)
                          Text(
                            event.courseName,
                            style: TextStyle(color: bodyColor, fontSize: 12),
                          ),
                        if (event.isAiGenerated)
                          Text(
                            'AI 参与',
                            style: TextStyle(
                              color: eventAccent,
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      event.title,
                      style: TextStyle(
                        color: titleColor,
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (event.summary.trim().isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              event.summary,
              maxLines: 4,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: bodyColor, fontSize: 13, height: 1.45),
            ),
          ],
          if (event.imagePaths.isNotEmpty) ...[
            const SizedBox(height: 12),
            _ImageGrid(
              paths: event.imagePaths,
              isDarkMode: isDarkMode,
            ),
          ],
          if (onShare != null || onDelete != null) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                if (onShare != null)
                  TextButton.icon(
                    onPressed: onShare,
                    icon: const Icon(Icons.ios_share_rounded, size: 18),
                    label: const Text('转为证据动态'),
                  ),
                const Spacer(),
                if (onDelete != null)
                  IconButton(
                    tooltip: '删除动态',
                    onPressed: onDelete,
                    icon: Icon(Icons.delete_outline_rounded, color: bodyColor),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Color _accentFor(LearningTraceEventType type, Color fallback) {
    switch (type) {
      case LearningTraceEventType.moment:
        return fallback;
      case LearningTraceEventType.studyLog:
        return const Color(0xFF19A974);
      case LearningTraceEventType.taskCompleted:
        return const Color(0xFFF59E0B);
      case LearningTraceEventType.noteCreated:
        return const Color(0xFF7C3AED);
      case LearningTraceEventType.flashcardCreated:
        return const Color(0xFFE11D48);
      case LearningTraceEventType.aiAction:
        return const Color(0xFF0EA5E9);
    }
  }

  IconData _iconFor(LearningTraceEventType type) {
    switch (type) {
      case LearningTraceEventType.moment:
        return Icons.dynamic_feed_rounded;
      case LearningTraceEventType.studyLog:
        return Icons.edit_note_rounded;
      case LearningTraceEventType.taskCompleted:
        return Icons.task_alt_rounded;
      case LearningTraceEventType.noteCreated:
        return Icons.menu_book_rounded;
      case LearningTraceEventType.flashcardCreated:
        return Icons.style_rounded;
      case LearningTraceEventType.aiAction:
        return Icons.auto_awesome_rounded;
    }
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
  });

  final bool isDarkMode;
  final Color accent;
  final Color bodyColor;

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
          Icon(Icons.timeline_rounded, color: accent, size: 42),
          const SizedBox(height: 12),
          Text(
            '开始记录后，这里会自动生成学习时间线',
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
  });

  final String label;
  final bool unlocked;
  final int current;
  final int target;
  final String source;
}

class _LocationCheckInDraft {
  const _LocationCheckInDraft({
    required this.title,
    required this.city,
    required this.coordinates,
    required this.shareToGroup,
    this.groupId,
  });

  final String title;
  final String city;
  final String coordinates;
  final bool shareToGroup;
  final String? groupId;
}

class _CoordinatePair {
  const _CoordinatePair(this.latitude, this.longitude);

  final double latitude;
  final double longitude;
}
