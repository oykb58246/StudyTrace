import 'package:flutter/material.dart';

import '../controllers/app_data_controller.dart';
import '../models/ai_action_record.dart';
import '../models/ai_app_action.dart';
import '../models/ai_flash_card.dart';
import '../models/ai_learning_loop.dart';
import '../models/note_block.dart';
import '../models/study_log_item.dart';
import '../models/study_note.dart';
import '../models/study_sub_task_item.dart';
import '../models/study_task_item.dart';
import 'ai_study_service.dart';
import 'ai_tool_registry.dart';

typedef AiNavigationActionHandler = Future<AiActionResult> Function(
  AiAppAction action,
);

class AiActionExecutor {
  AiActionExecutor({
    required this.controller,
    required this.aiService,
    this.onNavigationAction,
  });

  final AppDataController controller;
  final AiStudyService aiService;
  final AiNavigationActionHandler? onNavigationAction;

  Future<List<AiActionResult>> execute({
    required List<AiAppAction> actions,
    required String input,
    required String assistantReply,
    String? sessionId,
  }) async {
    final results = <AiActionResult>[];
    for (final action in actions.take(4)) {
      final toolId = _actionTypeToToolId(action.type) ?? action.type.name;
      final recordId = 'audit_${DateTime.now().microsecondsSinceEpoch}';
      await controller.appendActionRecord(AiActionRecord(
        id: recordId,
        sessionId: sessionId,
        toolId: toolId,
        targetId: action.targetId,
        targetTitle: action.targetTitle,
        status: AiActionStatus.pending,
        params: {
          'sourceText': action.sourceText,
          'title': action.title,
          'content': action.content,
          'status': action.status,
        },
        createdAt: DateTime.now(),
      ));

      AiActionResult result;
      if (_isNavigationAction(action.type)) {
        final handler = onNavigationAction;
        if (handler == null) {
          result = AiActionResult(
            action: action,
            success: false,
            message: '当前入口还没有接入全局导航执行器',
          );
        } else {
          result = await handler(action);
        }
      } else {
        result = await _executeDataAction(
          action,
          input: input,
          assistantReply: assistantReply,
        );
      }
      results.add(result);

      await controller.updateActionRecord(
        recordId,
        status: result.success ? AiActionStatus.executed : AiActionStatus.failed,
        resultMessage: result.message,
        errorMessage: result.success ? null : result.message,
      );
    }
    return results;
  }

  String? _actionTypeToToolId(AiAppActionType type) {
    // 将枚举映射到 toolId，供 registry 查询
    return switch (type) {
      AiAppActionType.switchTab => AiToolIds.switchTab,
      AiAppActionType.openTimer => AiToolIds.openTimer,
      AiAppActionType.openFlashcard => AiToolIds.openFlashcard,
      AiAppActionType.openNotes => AiToolIds.openNotes,
      AiAppActionType.openAiSettings => AiToolIds.openAiSettings,
      AiAppActionType.openDashboard => AiToolIds.openDashboard,
      AiAppActionType.openTaskPlanning => AiToolIds.openTaskPlanning,
      AiAppActionType.openAiAssistant => AiToolIds.openAiAssistant,
      AiAppActionType.openUserProfile => AiToolIds.openUserProfile,
      AiAppActionType.openAbout => AiToolIds.openAbout,
      AiAppActionType.openStudyGroup => AiToolIds.openStudyGroup,
      AiAppActionType.openLeaderboard => AiToolIds.openLeaderboard,
      AiAppActionType.openWeeklyReport => AiToolIds.openWeeklyReport,
      AiAppActionType.openSystemSettings => AiToolIds.openSystemSettings,
      AiAppActionType.addTask => AiToolIds.addTask,
      AiAppActionType.createLog => AiToolIds.createLog,
      AiAppActionType.markTaskStatus => AiToolIds.markTaskStatus,
      AiAppActionType.saveNote => AiToolIds.saveNote,
      AiAppActionType.summarizeStarredCards => AiToolIds.summarizeStarredCards,
      AiAppActionType.deleteTask => AiToolIds.deleteTask,
      AiAppActionType.deleteLog => AiToolIds.deleteLog,
      AiAppActionType.deleteNote => AiToolIds.deleteNote,
      AiAppActionType.deleteFlashcard => AiToolIds.deleteFlashcard,
      AiAppActionType.overwriteNote => AiToolIds.overwriteNote,
      AiAppActionType.setDarkMode => AiToolIds.setDarkMode,
      AiAppActionType.setSkin => AiToolIds.setSkin,
      AiAppActionType.setDailyReminder => AiToolIds.setDailyReminder,
      AiAppActionType.setServerUrl => AiToolIds.setServerUrl,
      AiAppActionType.logout => AiToolIds.logout,
      AiAppActionType.addCourse => AiToolIds.addCourse,
      AiAppActionType.renameCourse => AiToolIds.renameCourse,
      AiAppActionType.deleteCourse => AiToolIds.deleteCourse,
      AiAppActionType.toggleFlashcardStar => AiToolIds.toggleFlashcardStar,
      AiAppActionType.addFlashcard => AiToolIds.addFlashcard,
      AiAppActionType.generateTodayFlashcards =>
        AiToolIds.generateTodayFlashcards,
      AiAppActionType.startFocus => AiToolIds.startFocus,
      AiAppActionType.addTaskDirect => AiToolIds.addTaskDirect,
      AiAppActionType.updateSubtask => AiToolIds.updateSubtask,
      AiAppActionType.emptyTrash => AiToolIds.emptyTrash,
      AiAppActionType.generateWeeklyPlan => AiToolIds.generateWeeklyPlan,
      AiAppActionType.noteFromLog => AiToolIds.noteFromLog,
      AiAppActionType.createLoopFromSource => AiToolIds.createLoopFromSource,
      AiAppActionType.generateTodayMission => AiToolIds.generateTodayMission,
      AiAppActionType.searchMemory => AiToolIds.searchMemory,
      AiAppActionType.noteFromOcr => AiToolIds.noteFromOcr,
      AiAppActionType.createFlashcardBatch => AiToolIds.createFlashcardBatch,
      AiAppActionType.startFocusWithTask => AiToolIds.startFocusWithTask,
      _ => null,
    };
  }

  bool _isNavigationAction(AiAppActionType type) {
    final toolId = _actionTypeToToolId(type);
    if (toolId == null) return false;
    return AiToolRegistry.instance.isNavigationTool(toolId);
  }

  Future<AiActionResult> _executeDataAction(
    AiAppAction action, {
    required String input,
    required String assistantReply,
  }) async {
    try {
      return switch (action.type) {
        AiAppActionType.addTask => await _addTask(action, input),
        AiAppActionType.createLog => await _createLog(action, input),
        AiAppActionType.markTaskStatus => await _markTaskStatus(action),
        AiAppActionType.saveNote =>
          await _saveNote(action, input, assistantReply),
        AiAppActionType.summarizeStarredCards =>
          await _summarizeStarredCards(action),
        AiAppActionType.deleteTask => await _deleteTask(action),
        AiAppActionType.deleteLog => await _deleteLog(action),
        AiAppActionType.deleteNote => await _deleteNote(action),
        AiAppActionType.deleteFlashcard => await _deleteFlashcard(action),
        AiAppActionType.overwriteNote =>
          await _overwriteNote(action, assistantReply),
        AiAppActionType.setDarkMode => await _setDarkMode(action),
        AiAppActionType.setSkin => await _setSkin(action),
        AiAppActionType.setDailyReminder => await _setDailyReminder(action),
        AiAppActionType.setServerUrl => await _setServerUrl(action),
        AiAppActionType.logout => await _logout(action),
        AiAppActionType.addCourse => await _addCourse(action),
        AiAppActionType.renameCourse => await _renameCourse(action),
        AiAppActionType.deleteCourse => await _deleteCourse(action),
        AiAppActionType.toggleFlashcardStar =>
          await _toggleFlashcardStar(action),
        AiAppActionType.addFlashcard => await _addFlashcard(action),
        AiAppActionType.generateTodayFlashcards =>
          await _generateTodayFlashcards(action),
        AiAppActionType.addTaskDirect => await _addTaskDirect(action),
        AiAppActionType.updateSubtask => await _updateSubtask(action),
        AiAppActionType.emptyTrash => await _emptyTrash(action),
        AiAppActionType.generateWeeklyPlan =>
          await _generateWeeklyPlan(action),
        AiAppActionType.noteFromLog => await _noteFromLog(action),
        AiAppActionType.createLoopFromSource =>
          await _createLoopFromSource(action, input),
        AiAppActionType.generateTodayMission =>
          await _generateTodayMission(action),
        AiAppActionType.searchMemory => await _searchMemory(action, input),
        AiAppActionType.noteFromOcr => await _noteFromOcr(action, input),
        AiAppActionType.createFlashcardBatch =>
          await _createFlashcardBatch(action, input),
        _ => AiActionResult(
            action: action,
            success: false,
            message: '暂不支持这个操作',
          ),
      };
    } catch (error) {
      return AiActionResult(
        action: action,
        success: false,
        message: '执行失败：$error',
      );
    }
  }

  Future<AiActionResult> _addTask(AiAppAction action, String input) async {
    final source = _bestSource(action, input);
    final plan = await aiService.generateTaskPlan(source);
    if (plan.mainTitle.trim().isEmpty) {
      return AiActionResult(
        action: action,
        success: false,
        message: 'AI 没有生成有效任务标题',
      );
    }
    final now = DateTime.now();
    final subTasks = plan.plannedSubTasks.isNotEmpty
        ? plan.plannedSubTasks
            .map((p) => StudySubTaskItem(
                  id: 'sub_${now.microsecondsSinceEpoch}_${plan.plannedSubTasks.indexOf(p)}',
                  title: p.title,
                  startAt: p.startAt,
                  deadline: p.deadline,
                  note: p.note,
                  createdAt: now,
                  updatedAt: now,
                ))
            .toList()
        : plan.subTasks
            .map((title) => StudySubTaskItem(
                  id: 'sub_${now.microsecondsSinceEpoch}_${plan.subTasks.indexOf(title)}',
                  title: title,
                  deadline: plan.deadline,
                  createdAt: now,
                  updatedAt: now,
                ))
            .toList();
    final note = [
      if (plan.difficulty.isNotEmpty) '难度：${plan.difficulty}',
      if (plan.schedule.isNotEmpty) '推荐安排：\n${plan.schedule}',
    ].join('\n');
    final task = await controller.addStudyTask(
      title: plan.mainTitle,
      type: plan.taskType,
      courseName: plan.courseName,
      deadline: plan.deadline,
      note: note,
      subTasks: subTasks,
    );
    return AiActionResult(
      action: action,
      success: true,
      message: '已创建任务：${task.title}',
      createdId: task.id,
    );
  }

  Future<AiActionResult> _createLog(AiAppAction action, String input) async {
    final log = await aiService.generateStudyLog(_bestSource(action, input));
    final saved = await controller.addStudyLog(
      date: DateTime.now(),
      courseName: log.courseName,
      content: log.content,
      problems: log.problems,
      thoughts: log.thoughts,
      nextPlan: log.nextPlan,
    );
    return AiActionResult(
      action: action,
      success: true,
      message: '已保存学习日志：${saved.courseName}',
      createdId: saved.id,
    );
  }

  Future<AiActionResult> _markTaskStatus(
    AiAppAction action,
  ) async {
    final status = _statusFromAction(action);
    if (status == null) {
      return AiActionResult(
        action: action,
        success: false,
        message: '没有识别到要标记成“已完成”还是“进行中”',
      );
    }

    // 批量模式：targetTitle/content 是特殊关键字
    final batchTargets = _resolveBatchTargets(action);
    if (batchTargets != null) {
      if (batchTargets.isEmpty) {
        return AiActionResult(
          action: action,
          success: false,
          message: '没有找到符合批量条件的任务',
        );
      }
      for (final task in batchTargets) {
        await _applyStatusToTask(task, status);
      }
      return AiActionResult(
        action: action,
        success: true,
        message: '已批量将 ${batchTargets.length} 个任务标记为${status.label}',
      );
    }

    final resolution = _resolveTask(action);
    if (resolution.target == null) {
      final names = resolution.candidates.isEmpty
          ? controller.studyTasks
              .where((task) => task.effectiveStatus != StudyTaskStatus.completed)
              .take(5)
              .map((task) => task.title)
              .toList()
          : resolution.candidates.map((task) => task.title).toList();
      return AiActionResult(
        action: action,
        success: false,
        message: names.isEmpty
            ? '没有找到可标记的任务'
            : '任务不够明确，请指定：${names.join('、')}',
        candidates: names,
      );
    }

    final task = resolution.target!;
    await _applyStatusToTask(task, status);
    return AiActionResult(
      action: action,
      success: true,
      message: '任务“${task.title}”已标记为${status.label}',
      createdId: task.id,
    );
  }

  /// 把状态应用到单个任务（含子任务同步）
  Future<void> _applyStatusToTask(
    StudyTaskItem task,
    StudyTaskStatus status,
  ) async {
    if (task.subTasks.isEmpty) {
      await controller.updateStudyTaskStatus(task.id, status);
      return;
    }
    final subStatus = status == StudyTaskStatus.completed
        ? SubTaskStatus.completed
        : SubTaskStatus.inProgress;
    final subTasks = task.subTasks
        .map((subTask) => subTask.copyWith(
              status: status == StudyTaskStatus.completed
                  ? subStatus
                  : (subTask.status == SubTaskStatus.completed
                      ? subTask.status
                      : subStatus),
            ))
        .toList();
    await controller.updateStudyTask(
      task.id,
      title: task.title,
      type: task.type,
      courseName: task.courseName,
      deadline: task.deadline,
      status: status,
      note: task.note,
      subTasks: subTasks,
      reminderTime: task.reminderTime,
    );
  }

  /// 从 action 中识别批量关键字并返回目标任务列表。返回 null 表示非批量模式。
  List<StudyTaskItem>? _resolveBatchTargets(AiAppAction action) {
    final raw = (action.targetId ??
            action.targetTitle ??
            action.title ??
            action.content ??
            action.sourceText ??
            '')
        .trim()
        .toLowerCase();
    if (raw.isEmpty) return null;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final tomorrow = today.add(const Duration(days: 1));
    bool isBatch = false;
    bool Function(StudyTaskItem) filter;
    switch (raw) {
      case 'all_overdue':
      case 'all overdue':
      case 'overdue':
      case '所有过期任务':
      case '所有逾期任务':
      case '全部过期':
      case '全部逾期':
        isBatch = true;
        filter = (t) =>
            t.effectiveStatus != StudyTaskStatus.completed &&
            t.deadline.isBefore(now);
        break;
      case 'all_today':
      case 'today':
      case '所有今天的任务':
      case '今天的任务':
      case '所有今日任务':
        isBatch = true;
        filter = (t) =>
            t.effectiveStatus != StudyTaskStatus.completed &&
            !t.deadline.isBefore(today) &&
            t.deadline.isBefore(tomorrow);
        break;
      case 'all_pending':
      case 'all_in_progress':
      case '所有进行中':
      case '全部进行中':
        isBatch = true;
        filter = (t) => t.effectiveStatus == StudyTaskStatus.inProgress;
        break;
      case 'all_not_completed':
      case '所有未完成':
      case '全部未完成':
        isBatch = true;
        filter = (t) => t.effectiveStatus != StudyTaskStatus.completed;
        break;
      default:
        return null;
    }
    if (!isBatch) return null;
    return controller.studyTasks.where(filter).toList();
  }

  Future<AiActionResult> _saveNote(
    AiAppAction action,
    String input,
    String assistantReply,
  ) async {
    var content = action.content?.trim() ??
        action.sourceText?.trim() ??
        assistantReply.trim();
    if (content.isEmpty || content == input.trim()) {
      content = assistantReply.trim();
    }
    if (content.isEmpty) {
      return AiActionResult(
        action: action,
        success: false,
        message: '没有可保存的笔记内容',
      );
    }
    // 防止超长内容把本地存储写爆。单条笔记最多 20000 字，超了截断并提示。
    const maxNoteLength = 20000;
    var wasTruncated = false;
    if (content.length > maxNoteLength) {
      content = '${content.substring(0, maxNoteLength)}\n\n[内容过长，已截断]';
      wasTruncated = true;
    }
    final now = DateTime.now();
    final title = action.title?.trim().isNotEmpty == true
        ? action.title!.trim()
        : 'AI 笔记 ${now.month}/${now.day}';
    final note = await controller.addStudyNote(
      title: title,
      content: content,
      blocks: _markdownToNoteBlocks(content),
    );
    return AiActionResult(
      action: action,
      success: true,
      message: wasTruncated
          ? '已保存笔记：${note.title}（内容过长已截断到 2 万字）'
          : '已保存笔记：${note.title}',
      createdId: note.id,
    );
  }

  Future<AiActionResult> _summarizeStarredCards(AiAppAction action) async {
    final starred = controller.flashCards.where((card) => card.isStarred).toList();
    if (starred.isEmpty) {
      return AiActionResult(
        action: action,
        success: false,
        message: '还没有收藏闪卡，先收藏几张再让 AI 整理',
      );
    }
    final context = starred
        .take(12)
        .map((card) =>
            '【${card.courseName.isEmpty ? '未归类' : card.courseName}】${card.question} / ${card.answer}')
        .toList(growable: false);
    final noteText = await aiService.generateAssistantReply(
      input: '请根据这些收藏闪卡整理一份结构清晰的学习笔记。',
      context: context,
      purpose: 'note',
    );
    final note = await controller.addStudyNote(
      title: '收藏闪卡整理 ${DateTime.now().month}/${DateTime.now().day}',
      content: noteText,
      blocks: _markdownToNoteBlocks(noteText),
    );
    return AiActionResult(
      action: action,
      success: true,
      message: '已根据收藏闪卡生成笔记：${note.title}',
      createdId: note.id,
    );
  }

  // ── 危险数据动作：删除/覆盖 ──
  // 这些动作由对话页 `needsConfirmation` 路径上的确认卡触发，
  // 执行前前端已经获得用户的明确点击。删除均走回收站（可恢复）。

  Future<AiActionResult> _deleteTask(AiAppAction action) async {
    final resolution = _resolveTask(action);
    final target = resolution.target;
    if (target == null) {
      final names = resolution.candidates.map((t) => t.title).toList();
      return AiActionResult(
        action: action,
        success: false,
        message: names.isEmpty
            ? '没有找到要删除的任务'
            : '任务不够明确，请指定：${names.join('、')}',
        candidates: names,
      );
    }
    await controller.deleteStudyTask(target.id);
    return AiActionResult(
      action: action,
      success: true,
      message: '已将任务“${target.title}”移入回收站',
      createdId: target.id,
    );
  }

  Future<AiActionResult> _deleteLog(AiAppAction action) async {
    final targetId = action.targetId?.trim();
    if (targetId == null || targetId.isEmpty) {
      return AiActionResult(
        action: action,
        success: false,
        message: '删除日志必须指定 targetId',
      );
    }
    final exists = controller.studyLogs.any((l) => l.id == targetId);
    if (!exists) {
      return AiActionResult(
        action: action,
        success: false,
        message: '未找到 id 为 $targetId 的日志',
      );
    }
    await controller.deleteStudyLog(targetId);
    return AiActionResult(
      action: action,
      success: true,
      message: '已将学习日志移入回收站',
      createdId: targetId,
    );
  }

  Future<AiActionResult> _deleteNote(AiAppAction action) async {
    final resolved = _resolveNote(action);
    if (resolved == null) {
      return AiActionResult(
        action: action,
        success: false,
        message: '未找到要删除的笔记，请指定 targetId 或完整标题',
      );
    }
    await controller.deleteStudyNote(resolved.id);
    return AiActionResult(
      action: action,
      success: true,
      message: '已将笔记“${resolved.title}”移入回收站',
      createdId: resolved.id,
    );
  }

  Future<AiActionResult> _deleteFlashcard(AiAppAction action) async {
    final targetId = action.targetId?.trim();
    if (targetId == null || targetId.isEmpty) {
      return AiActionResult(
        action: action,
        success: false,
        message: '删除闪卡必须指定 targetId',
      );
    }
    final exists = controller.flashCards.any((c) => c.id == targetId);
    if (!exists) {
      return AiActionResult(
        action: action,
        success: false,
        message: '未找到 id 为 $targetId 的闪卡',
      );
    }
    await controller.deleteFlashCard(targetId);
    return AiActionResult(
      action: action,
      success: true,
      message: '已将闪卡移入回收站',
      createdId: targetId,
    );
  }

  Future<AiActionResult> _overwriteNote(
    AiAppAction action,
    String assistantReply,
  ) async {
    final resolved = _resolveNote(action);
    if (resolved == null) {
      return AiActionResult(
        action: action,
        success: false,
        message: '未找到要覆盖的笔记，请指定 targetId 或完整标题',
      );
    }
    final newContent =
        (action.content?.trim().isNotEmpty == true
                ? action.content!
                : assistantReply)
            .trim();
    if (newContent.isEmpty) {
      return AiActionResult(
        action: action,
        success: false,
        message: '没有可用于覆盖的新内容',
      );
    }
    final newTitle = action.title?.trim().isNotEmpty == true
        ? action.title!.trim()
        : resolved.title;
    await controller.updateStudyNote(
      resolved.id,
      title: newTitle,
      content: newContent,
      blocks: _markdownToNoteBlocks(newContent),
    );
    return AiActionResult(
      action: action,
      success: true,
      message: '已覆盖笔记“$newTitle”',
      createdId: resolved.id,
    );
  }

  /// 按 targetId 或标题解析笔记。比任务匹配更严格，
  /// 避免删/改动到无关笔记。
  StudyNote? _resolveNote(AiAppAction action) {
    final notes = controller.studyNotes.where((n) => !n.isFolder).toList();
    final targetId = action.targetId?.trim();
    if (targetId != null && targetId.isNotEmpty) {
      for (final note in notes) {
        if (note.id == targetId) return note;
      }
    }
    final query =
        (action.targetTitle ?? action.title ?? '').trim();
    if (query.isEmpty) return null;
    final normalizedQuery = _normalize(query);
    if (normalizedQuery.length < 3) return null;
    final exact = notes
        .where((n) => _normalize(n.title) == normalizedQuery)
        .toList();
    if (exact.length == 1) return exact.first;
    return null; // 歧义时拒绝，避免误伤
  }

  // ── 扩展动作：系统设置 ──

  Future<AiActionResult> _setDarkMode(AiAppAction action) async {
    final raw = (action.status ?? action.content ?? action.title ?? '')
        .trim()
        .toLowerCase();
    bool next;
    switch (raw) {
      case 'on':
      case 'true':
      case 'enable':
      case 'enabled':
      case '开':
      case '开启':
      case '打开':
      case '深色':
      case 'dark':
        next = true;
        break;
      case 'off':
      case 'false':
      case 'disable':
      case 'disabled':
      case '关':
      case '关闭':
      case '浅色':
      case 'light':
        next = false;
        break;
      case 'toggle':
      case '切换':
      case '':
        next = !controller.darkMode;
        break;
      default:
        next = !controller.darkMode;
    }
    await controller.setDarkMode(next);
    return AiActionResult(
      action: action,
      success: true,
      message: next ? '已切换到深色模式' : '已切换到浅色模式',
    );
  }

  Future<AiActionResult> _setSkin(AiAppAction action) async {
    final raw = (action.status ?? action.content ?? action.title ?? '')
        .trim()
        .toLowerCase();
    bool next;
    switch (raw) {
      case 'vivo':
      case 'blue':
      case '蓝':
      case 'vivo蓝':
        next = true;
        break;
      case 'classic':
      case 'purple':
      case '紫':
      case '传统':
      case '传统紫':
        next = false;
        break;
      case 'toggle':
      case '切换':
      case '':
      default:
        next = !controller.skinVivo;
    }
    await controller.setSkinVivo(next);
    return AiActionResult(
      action: action,
      success: true,
      message: next ? '已切换到 vivo 蓝皮肤' : '已切换到传统紫皮肤',
    );
  }

  Future<AiActionResult> _setDailyReminder(AiAppAction action) async {
    final statusRaw = (action.status ?? '').trim().toLowerCase();
    // 时间可能塞在各种字段里
    final timeFields = [
      action.sourceText,
      action.content,
      action.title,
      action.targetTitle,
      action.status, // status 里也可能直接就是时间字符串
    ].whereType<String>().toList();
    final current = await controller.loadDailyReminderSettings();
    bool enabled = current.enabled;
    switch (statusRaw) {
      case 'on':
      case 'enable':
      case 'enabled':
      case '开':
      case '开启':
      case '打开':
        enabled = true;
        break;
      case 'off':
      case 'disable':
      case 'disabled':
      case '关':
      case '关闭':
        enabled = false;
        break;
      case 'toggle':
      case '切换':
        enabled = !enabled;
        break;
    }
    TimeOfDay time = current.time;
    String? timeHit;
    for (final field in timeFields) {
      final match = RegExp(r'(\d{1,2})[:：](\d{1,2})').firstMatch(field);
      if (match != null) {
        timeHit = field;
        final h = int.tryParse(match.group(1) ?? '') ?? current.time.hour;
        final m = int.tryParse(match.group(2) ?? '') ?? current.time.minute;
        if (h >= 0 && h < 24 && m >= 0 && m < 60) {
          time = TimeOfDay(hour: h, minute: m);
        }
        break;
      }
    }
    // 没给 status 但给了时间 → 视为开启
    if (statusRaw.isEmpty && timeHit != null) enabled = true;
    final newSettings = current.copyWith(enabled: enabled, time: time);
    await controller.saveDailyReminderSettings(newSettings);
    final hh = time.hour.toString().padLeft(2, '0');
    final mm = time.minute.toString().padLeft(2, '0');
    return AiActionResult(
      action: action,
      success: true,
      message: enabled
          ? '每日学习提醒已开启（$hh:$mm）'
          : '每日学习提醒已关闭',
    );
  }

  Future<AiActionResult> _setServerUrl(AiAppAction action) async {
    return AiActionResult(
      action: action,
      success: false,
      message: '比赛版使用内置云服务，服务地址不可由用户或 AI 修改',
    );
  }

  Future<AiActionResult> _logout(AiAppAction action) async {
    if (!controller.isLoggedIn) {
      return AiActionResult(
        action: action,
        success: false,
        message: '当前未登录，无需退出',
      );
    }
    await controller.logout();
    return AiActionResult(
      action: action,
      success: true,
      message: '已退出登录',
    );
  }

  // ── 扩展动作：课程管理 ──

  Future<AiActionResult> _addCourse(AiAppAction action) async {
    final name =
        (action.title ?? action.targetTitle ?? action.content ?? '').trim();
    if (name.isEmpty) {
      return AiActionResult(
        action: action,
        success: false,
        message: '请给出 title 字段（课程名）',
      );
    }
    if (controller.courses.contains(name)) {
      return AiActionResult(
        action: action,
        success: false,
        message: '课程「$name」已存在',
      );
    }
    await controller.addCourse(name);
    return AiActionResult(
      action: action,
      success: true,
      message: '已新增课程：$name',
    );
  }

  Future<AiActionResult> _renameCourse(AiAppAction action) async {
    final oldName = (action.targetTitle ?? '').trim();
    final newName = (action.title ?? action.content ?? '').trim();
    if (oldName.isEmpty || newName.isEmpty) {
      return AiActionResult(
        action: action,
        success: false,
        message: '请同时指定 targetTitle（旧课程名）和 title（新课程名）',
      );
    }
    if (!controller.courses.contains(oldName)) {
      return AiActionResult(
        action: action,
        success: false,
        message: '课程「$oldName」不存在',
      );
    }
    if (oldName == newName) {
      return AiActionResult(
        action: action,
        success: false,
        message: '新旧课程名相同',
      );
    }
    await controller.renameCourse(oldName, newName);
    return AiActionResult(
      action: action,
      success: true,
      message: '课程已重命名：$oldName → $newName',
    );
  }

  Future<AiActionResult> _deleteCourse(AiAppAction action) async {
    final name = (action.targetTitle ?? action.title ?? '').trim();
    if (name.isEmpty) {
      return AiActionResult(
        action: action,
        success: false,
        message: '请指定 targetTitle（课程名）',
      );
    }
    if (!controller.courses.contains(name)) {
      return AiActionResult(
        action: action,
        success: false,
        message: '课程「$name」不存在',
      );
    }
    await controller.deleteCourse(name);
    return AiActionResult(
      action: action,
      success: true,
      message: '已删除课程：$name',
    );
  }

  // ── 扩展动作：闪卡 ──

  Future<AiActionResult> _toggleFlashcardStar(AiAppAction action) async {
    final targetId = action.targetId?.trim();
    if (targetId == null || targetId.isEmpty) {
      return AiActionResult(
        action: action,
        success: false,
        message: '请指定 targetId（闪卡 id）',
      );
    }
    final card = controller.flashCards
        .cast<AiFlashCard?>()
        .firstWhere((c) => c?.id == targetId, orElse: () => null);
    if (card == null) {
      return AiActionResult(
        action: action,
        success: false,
        message: '未找到 id 为 $targetId 的闪卡',
      );
    }
    final raw = (action.status ?? action.content ?? '').trim().toLowerCase();
    bool next;
    switch (raw) {
      case 'starred':
      case 'star':
      case 'on':
      case 'true':
      case '收藏':
        next = true;
        break;
      case 'unstarred':
      case 'unstar':
      case 'off':
      case 'false':
      case '取消收藏':
        next = false;
        break;
      case 'toggle':
      case '切换':
      case '':
      default:
        next = !card.isStarred;
    }
    await controller.updateFlashCard(targetId, isStarred: next);
    return AiActionResult(
      action: action,
      success: true,
      message: next ? '已收藏闪卡' : '已取消收藏闪卡',
      createdId: targetId,
    );
  }

  Future<AiActionResult> _addFlashcard(AiAppAction action) async {
    final question = (action.title ?? action.sourceText ?? '').trim();
    final answer = (action.content ?? '').trim();
    final course = (action.targetTitle ?? '').trim();
    if (question.isEmpty || answer.isEmpty) {
      return AiActionResult(
        action: action,
        success: false,
        message: '请同时给出 title（题面）和 content（答案）',
      );
    }
    final now = DateTime.now();
    final card = AiFlashCard(
      id: 'fc_${now.microsecondsSinceEpoch}',
      question: question,
      answer: answer,
      courseName: course,
      createdAt: now,
    );
    await controller.addFlashCards([card]);
    return AiActionResult(
      action: action,
      success: true,
      message: '已新增闪卡：$question',
      createdId: card.id,
    );
  }

  Future<AiActionResult> _generateTodayFlashcards(AiAppAction action) async {
    final rawCount = (action.status ?? action.content ?? action.title ?? '')
        .trim();
    var count = int.tryParse(rawCount) ?? 5;
    count = count.clamp(1, 20);
    final today = DateTime.now();
    final todayLogs = controller.studyLogs.where((l) {
      return l.date.year == today.year &&
          l.date.month == today.month &&
          l.date.day == today.day;
    }).toList();
    if (todayLogs.isEmpty) {
      return AiActionResult(
        action: action,
        success: false,
        message: '今天还没有学习日志，先记录一些再生成闪卡',
      );
    }
    final cards = await aiService.generateFlashCards(
      logs: todayLogs,
      count: count,
    );
    if (cards.isEmpty) {
      return AiActionResult(
        action: action,
        success: false,
        message: 'AI 没有生成有效闪卡',
      );
    }
    await controller.addFlashCards(cards);
    return AiActionResult(
      action: action,
      success: true,
      message: '已根据今日日志生成 ${cards.length} 张闪卡',
    );
  }

  // ── 扩展动作：任务扩展 ──

  Future<AiActionResult> _addTaskDirect(AiAppAction action) async {
    final title = (action.title ?? action.sourceText ?? '').trim();
    if (title.isEmpty) {
      return AiActionResult(
        action: action,
        success: false,
        message: '请给出 title（任务名）',
      );
    }
    final note = (action.content ?? '').trim();
    final course = (action.targetTitle ?? '').trim();
    DateTime deadline = DateTime.now().add(const Duration(days: 3));
    final statusRaw = (action.status ?? '').trim();
    if (statusRaw.isNotEmpty) {
      final parsed = DateTime.tryParse(statusRaw);
      if (parsed != null) deadline = parsed;
    }
    final task = await controller.addStudyTask(
      title: title,
      type: StudyTaskType.other,
      courseName: course,
      deadline: deadline,
      note: note,
    );
    return AiActionResult(
      action: action,
      success: true,
      message: '已创建任务：${task.title}',
      createdId: task.id,
    );
  }

  Future<AiActionResult> _updateSubtask(AiAppAction action) async {
    final parentId = action.targetId?.trim();
    final subTitle = (action.targetTitle ?? '').trim();
    if (parentId == null || parentId.isEmpty || subTitle.isEmpty) {
      return AiActionResult(
        action: action,
        success: false,
        message: '请同时指定 targetId（父任务 id）和 targetTitle（子任务标题）',
      );
    }
    final statusRaw = (action.status ?? action.content ?? '')
        .trim()
        .toLowerCase()
        .replaceAll('-', '_');
    final SubTaskStatus newStatus;
    switch (statusRaw) {
      case 'completed':
      case 'done':
      case 'finished':
      case '完成':
      case '已完成':
        newStatus = SubTaskStatus.completed;
        break;
      case 'in_progress':
      case 'inprogress':
      case 'doing':
      case 'progress':
      case '进行中':
        newStatus = SubTaskStatus.inProgress;
        break;
      case 'not_started':
      case 'notstarted':
      case 'todo':
      case 'pending':
      case '未开始':
      case '未完成':
        newStatus = SubTaskStatus.notStarted;
        break;
      default:
        return AiActionResult(
          action: action,
          success: false,
          message: 'status 只能是 completed/in_progress/not_started',
        );
    }
    final taskIndex =
        controller.studyTasks.indexWhere((t) => t.id == parentId);
    if (taskIndex < 0) {
      return AiActionResult(
        action: action,
        success: false,
        message: '未找到父任务 $parentId',
      );
    }
    final task = controller.studyTasks[taskIndex];
    final normalizedSub = _normalize(subTitle);
    final matched = task.subTasks.where((st) {
      final title = _normalize(st.title);
      return title == normalizedSub || title.contains(normalizedSub);
    }).toList();
    if (matched.isEmpty) {
      return AiActionResult(
        action: action,
        success: false,
        message: '父任务「${task.title}」下没有匹配的子任务：$subTitle',
      );
    }
    if (matched.length > 1) {
      return AiActionResult(
        action: action,
        success: false,
        message: '匹配到多个子任务：${matched.map((e) => e.title).join("、")}',
        candidates: matched.map((e) => e.title).toList(),
      );
    }
    final target = matched.first;
    final newSubTasks = task.subTasks
        .map((st) => st.id == target.id
            ? st.copyWith(status: newStatus)
            : st)
        .toList();
    await controller.updateStudyTask(
      task.id,
      title: task.title,
      type: task.type,
      courseName: task.courseName,
      deadline: task.deadline,
      status: task.status,
      note: task.note,
      subTasks: newSubTasks,
      reminderTime: task.reminderTime,
    );
    return AiActionResult(
      action: action,
      success: true,
      message: '子任务「${target.title}」已更新为${_subTaskLabel(newStatus)}',
      createdId: task.id,
    );
  }

  String _subTaskLabel(SubTaskStatus status) {
    return switch (status) {
      SubTaskStatus.completed => '已完成',
      SubTaskStatus.inProgress => '进行中',
      SubTaskStatus.notStarted => '未开始',
    };
  }

  // ── 扩展动作：回收站 ──

  Future<AiActionResult> _emptyTrash(AiAppAction action) async {
    final count = controller.trashItems.length;
    if (count == 0) {
      return AiActionResult(
        action: action,
        success: false,
        message: '回收站已经是空的',
      );
    }
    await controller.emptyTrash();
    return AiActionResult(
      action: action,
      success: true,
      message: '已清空回收站（$count 项）',
    );
  }

  // ── Phase 2 扩展：AI 周计划 / 日志扩写 ──

  Future<AiActionResult> _generateWeeklyPlan(AiAppAction action) async {
    // status 可覆盖天数，默认 7
    final rawDays = (action.status ?? '').trim();
    var days = int.tryParse(rawDays) ?? 7;
    days = days.clamp(1, 14);
    final now = DateTime.now();
    final weekAgo = now.subtract(const Duration(days: 7));
    final recentLogs = controller.studyLogs
        .where((l) => !l.date.isBefore(weekAgo))
        .toList();
    List<DailyPlan> plans;
    try {
      plans = await aiService.generateWeeklyPlan(
        existingTasks: controller.studyTasks,
        recentLogs: recentLogs,
        courses: controller.courses,
        days: days,
      );
    } catch (error) {
      return AiActionResult(
        action: action,
        success: false,
        message: '生成学习计划失败：$error',
      );
    }
    if (plans.isEmpty) {
      return AiActionResult(
        action: action,
        success: false,
        message: 'AI 没有生成有效计划',
      );
    }
    var created = 0;
    final today = DateTime.now();
    final todayStart = DateTime(today.year, today.month, today.day);
    for (final day in plans) {
      // 忽略历史日期；如果是今天，deadline = 今天 23:59
      if (day.date.isBefore(todayStart)) continue;
      final isToday = day.date.year == today.year &&
          day.date.month == today.month &&
          day.date.day == today.day;
      final deadline = isToday
          ? DateTime(day.date.year, day.date.month, day.date.day, 23, 59)
          : DateTime(day.date.year, day.date.month, day.date.day, 18);
      for (final item in day.tasks) {
        await controller.addStudyTask(
          title: item.title,
          type: StudyTaskType.other,
          courseName: item.courseName,
          deadline: deadline,
          note: item.note,
        );
        created++;
      }
    }
    if (created == 0) {
      return AiActionResult(
        action: action,
        success: false,
        message: 'AI 生成的计划全是历史日期，已忽略',
      );
    }
    return AiActionResult(
      action: action,
      success: true,
      message: '已为您生成未来 $days 天共 $created 个学习任务',
    );
  }

  Future<AiActionResult> _noteFromLog(AiAppAction action) async {
    final resolved = _resolveLog(action);
    if (resolved == null) {
      return AiActionResult(
        action: action,
        success: false,
        message: '未找到匹配的学习日志，请指定 targetId 或更明确的课程/关键词',
      );
    }
    final log = resolved;
    final context = <String>[
      '日期：${log.date.toIso8601String()}',
      if (log.courseName.isNotEmpty) '课程：${log.courseName}',
      if (log.content.isNotEmpty) '学习内容：${log.content}',
      if (log.problems.isNotEmpty) '遇到的问题：${log.problems}',
      if (log.thoughts.isNotEmpty) '思考收获：${log.thoughts}',
      if (log.nextPlan.isNotEmpty) '下一步计划：${log.nextPlan}',
    ];
    final noteText = await aiService.generateAssistantReply(
      input: '请根据上述学习日志扩写成一篇结构清晰的学习笔记，用小标题和列表组织。',
      context: context,
      purpose: 'note',
    );
    final safeText = noteText.trim().isEmpty ? context.join('\n') : noteText;
    final title = log.courseName.isNotEmpty
        ? '${log.courseName} 学习笔记 ${log.date.month}/${log.date.day}'
        : 'AI 学习笔记 ${DateTime.now().month}/${DateTime.now().day}';
    final note = await controller.addStudyNote(
      title: title,
      content: safeText,
      blocks: _markdownToNoteBlocks(safeText),
      courseName: log.courseName,
    );
    return AiActionResult(
      action: action,
      success: true,
      message: '已扩写为笔记：${note.title}',
      createdId: note.id,
    );
  }

  Future<AiActionResult> _createLoopFromSource(
    AiAppAction action,
    String input,
  ) async {
    final source = _bestSource(action, input);
    if (source.isEmpty) {
      return AiActionResult(
        action: action,
        success: false,
        message: '请提供要生成闭环的学习材料',
      );
    }
    final plan = await aiService.generateLearningLoop(
      sourceText: source,
      sourceKind: 'text',
      context: _compactContext(),
    );
    final created = await _applyLearningLoopPlan(plan);
    return AiActionResult(
      action: action,
      success: created == 0 ? false : true,
      message: created == 0
          ? 'AI 生成了闭环草稿，但没有可落地内容'
          : '已生成并落地学习闭环：$created 项内容',
    );
  }

  Future<AiActionResult> _generateTodayMission(AiAppAction action) async {
    final plan = await aiService.generateLearningLoop(
      sourceText: '请基于我的当前学习状态生成今日最优学习路径。',
      sourceKind: 'manual',
      target: 'task',
      context: _compactContext(),
    );
    var created = 0;
    final today = DateTime.now();
    for (final item in plan.reviewPlan.take(4)) {
      await controller.addStudyTask(
        title: item.title,
        type: StudyTaskType.other,
        courseName: plan.courseName,
        deadline: item.date ?? DateTime(today.year, today.month, today.day, 22),
        note: [
          if (item.reason.isNotEmpty) item.reason,
          '建议专注 ${item.minutes} 分钟',
          if (plan.summary.isNotEmpty) 'AI 路径摘要：${plan.summary}',
        ].join('\n'),
      );
      created++;
    }
    if (created == 0) {
      created = await _applyLearningLoopTasks(plan);
    }
    return AiActionResult(
      action: action,
      success: created > 0,
      message: created > 0 ? '已生成今日最优路径：$created 个学习块' : '暂时没有生成可执行路径',
    );
  }

  Future<AiActionResult> _searchMemory(AiAppAction action, String input) async {
    final query = _bestSource(action, input);
    if (query.isEmpty) {
      return AiActionResult(
        action: action,
        success: false,
        message: '请告诉我要检索哪段学习记忆',
      );
    }
    final hits = _localMemoryHits(query, limit: 5);
    return AiActionResult(
      action: action,
      success: hits.isNotEmpty,
      message: hits.isEmpty ? '没有找到明显相关的学习记忆' : '找到相关学习记忆：${hits.join('；')}',
    );
  }

  Future<AiActionResult> _noteFromOcr(AiAppAction action, String input) async {
    final text = _bestSource(action, input);
    if (text.isEmpty) {
      return AiActionResult(
        action: action,
        success: false,
        message: '请提供 OCR 文本',
      );
    }
    final title = (action.title ?? '').trim().isNotEmpty
        ? action.title!.trim()
        : (text.length > 20 ? text.substring(0, 20) : text);
    final note = await controller.addStudyNote(
      title: title.isEmpty ? '拍照笔记' : title,
      content: text,
      courseName: (action.targetTitle ?? '').trim(),
      blocks: _markdownToNoteBlocks(text),
    );
    return AiActionResult(
      action: action,
      success: true,
      message: '已保存 OCR 笔记：${note.title}',
      createdId: note.id,
    );
  }

  Future<AiActionResult> _createFlashcardBatch(
    AiAppAction action,
    String input,
  ) async {
    final source = _bestSource(action, input);
    if (source.isEmpty) {
      return AiActionResult(
        action: action,
        success: false,
        message: '请提供生成闪卡的材料',
      );
    }
    final plan = await aiService.generateLearningLoop(
      sourceText: source,
      sourceKind: 'text',
      target: 'flashcard',
      context: _compactContext(),
    );
    final count = await _applyLearningLoopFlashcards(plan);
    return AiActionResult(
      action: action,
      success: count > 0,
      message: count > 0 ? '已生成 $count 张知识闪卡' : 'AI 没有生成有效闪卡',
    );
  }

  Future<int> _applyLearningLoopPlan(AiLearningLoopPlan plan) async {
    var created = 0;
    if (plan.summary.trim().isNotEmpty) {
      await controller.addStudyLog(
        date: DateTime.now(),
        courseName: plan.courseName,
        content: plan.summary,
        nextPlan: plan.reviewPlan.map((item) => item.title).join('；'),
      );
      created++;
    }
    created += await _applyLearningLoopTasks(plan);
    if (plan.noteDraft.title.isNotEmpty || plan.noteDraft.content.isNotEmpty) {
      await controller.addStudyNote(
        title: plan.noteDraft.title.isNotEmpty
            ? plan.noteDraft.title
            : '${plan.courseName.isEmpty ? '学习' : plan.courseName}闭环笔记',
        content: plan.noteDraft.content.isNotEmpty
            ? plan.noteDraft.content
            : plan.summary,
        courseName: plan.courseName,
        blocks: _blocksFromLoopDraft(plan),
      );
      created++;
    }
    created += await _applyLearningLoopFlashcards(plan);
    return created;
  }

  Future<int> _applyLearningLoopTasks(AiLearningLoopPlan plan) async {
    var created = 0;
    for (final draft in plan.taskDrafts.take(3)) {
      final now = DateTime.now();
      final subTasks = draft.subTasks.take(4).map((item) {
        final index = draft.subTasks.indexOf(item);
        return StudySubTaskItem(
          id: 'sub_${now.microsecondsSinceEpoch}_$index',
          title: item.title,
          deadline: item.deadline ?? draft.deadline ?? now.add(const Duration(days: 3)),
          note: item.note,
          createdAt: now,
          updatedAt: now,
        );
      }).toList();
      await controller.addStudyTask(
        title: draft.title,
        type: draft.type,
        courseName: plan.courseName,
        deadline: draft.deadline ?? now.add(const Duration(days: 3)),
        note: draft.note.isNotEmpty ? draft.note : plan.summary,
        subTasks: subTasks,
      );
      created++;
    }
    return created;
  }

  Future<int> _applyLearningLoopFlashcards(AiLearningLoopPlan plan) async {
    final now = DateTime.now();
    final cards = plan.flashcards.take(8).map((draft) {
      final index = plan.flashcards.indexOf(draft);
      return AiFlashCard(
        id: 'fc_${now.microsecondsSinceEpoch}_$index',
        question: draft.question,
        answer: draft.answer,
        hint: draft.hint,
        courseName: draft.courseName.isNotEmpty ? draft.courseName : plan.courseName,
        createdAt: now,
      );
    }).toList();
    if (cards.isNotEmpty) {
      await controller.addFlashCards(cards);
    }
    return cards.length;
  }

  List<NoteBlock> _blocksFromLoopDraft(AiLearningLoopPlan plan) {
    if (plan.noteDraft.blocks.isEmpty) {
      return _markdownToNoteBlocks(plan.noteDraft.content.isNotEmpty
          ? plan.noteDraft.content
          : plan.summary);
    }
    var idCounter = DateTime.now().microsecondsSinceEpoch;
    String id() => '${idCounter++}';
    return plan.noteDraft.blocks.map((block) {
      final type = switch (block.type) {
        'heading' => NoteBlockType.heading,
        'bullet' => NoteBlockType.bullet,
        'todo' => NoteBlockType.todo,
        _ => NoteBlockType.text,
      };
      return NoteBlock(id: id(), type: type, content: block.content);
    }).toList();
  }

  List<String> _compactContext() {
    return [
      '未完成任务：${controller.studyTasks.where((t) => t.effectiveStatus != StudyTaskStatus.completed).take(8).map((t) => '${t.id}:${t.title}/${t.courseName}/${t.deadline.toIso8601String()}').join('；')}',
      '最近日志：${controller.studyLogs.take(6).map((l) => '${l.courseName}:${l.content}').join('；')}',
      '笔记标题：${controller.studyNotes.where((n) => !n.isFolder).take(8).map((n) => n.title).join('；')}',
      '待复习闪卡：${controller.flashCards.where((c) => c.isDueForReview).take(8).map((c) => c.question).join('；')}',
    ];
  }

  List<String> _localMemoryHits(String query, {int limit = 5}) {
    final q = _normalize(query);
    if (q.isEmpty) return const [];
    final hits = <String>[];
    bool matches(String text) {
      final normalized = _normalize(text);
      return normalized.contains(q) || q.contains(normalized);
    }

    for (final task in controller.studyTasks) {
      if (hits.length >= limit) break;
      final blob = '${task.title} ${task.courseName} ${task.note}';
      if (matches(blob)) hits.add('任务「${task.title}」');
    }
    for (final log in controller.studyLogs) {
      if (hits.length >= limit) break;
      final blob = '${log.courseName} ${log.content} ${log.problems} ${log.nextPlan}';
      if (matches(blob)) hits.add('日志「${log.courseName.isEmpty ? log.content : log.courseName}」');
    }
    for (final note in controller.studyNotes.where((n) => !n.isFolder)) {
      if (hits.length >= limit) break;
      final blob = '${note.title} ${note.courseName} ${note.content}';
      if (matches(blob)) hits.add('笔记「${note.title}」');
    }
    for (final card in controller.flashCards) {
      if (hits.length >= limit) break;
      final blob = '${card.courseName} ${card.question} ${card.answer} ${card.hint}';
      if (matches(blob)) hits.add('闪卡「${card.question}」');
    }
    return hits;
  }

  /// 按 targetId 或 targetTitle/content 在学习日志里做解析
  StudyLogItem? _resolveLog(AiAppAction action) {
    final logs = controller.studyLogs;
    final targetId = action.targetId?.trim();
    if (targetId != null && targetId.isNotEmpty) {
      for (final l in logs) {
        if (l.id == targetId) return l;
      }
    }
    final query = (action.targetTitle ??
            action.title ??
            action.content ??
            action.sourceText ??
            '')
        .trim();
    if (query.isEmpty) return null;
    final normalized = _normalize(query);
    if (normalized.length < 2) return null;
    // 优先按课程名 + 日期近一周匹配
    final now = DateTime.now();
    final weekAgo = now.subtract(const Duration(days: 7));
    final candidates = logs.where((l) {
      if (l.date.isBefore(weekAgo)) return false;
      final blob = _normalize('${l.courseName} ${l.content} ${l.nextPlan}');
      return blob.contains(normalized);
    }).toList();
    if (candidates.length == 1) return candidates.first;
    if (candidates.isNotEmpty) {
      // 多候选时取最新的一条
      candidates.sort((a, b) => b.date.compareTo(a.date));
      return candidates.first;
    }
    return null;
  }

  StudyTaskStatus? _statusFromAction(AiAppAction action) {
    final status = (action.status ?? action.content ?? action.title ?? '')
        .trim()
        .toLowerCase()
        .replaceAll('-', '_')
        .replaceAll(' ', '_');
    return switch (status) {
      'completed' || 'done' || 'finish' || 'finished' || '已完成' || '完成' =>
        StudyTaskStatus.completed,
      'in_progress' || 'inprogress' || 'progress' || 'doing' || '进行中' =>
        StudyTaskStatus.inProgress,
      _ => null,
    };
  }

  _TaskResolution _resolveTask(AiAppAction action) {
    final tasks = controller.studyTasks;
    final targetId = action.targetId?.trim();
    if (targetId != null && targetId.isNotEmpty) {
      final matches = tasks.where((task) => task.id == targetId).toList();
      if (matches.length == 1) return _TaskResolution(target: matches.first);
    }

    final query = (action.targetTitle ??
            action.title ??
            action.sourceText ??
            action.content ??
            '')
        .trim();
    if (query.isEmpty) return const _TaskResolution();
    final normalizedQuery = _normalize(query);
    // 至少 3 字，避免"复习""任务"这种短词灾难性匹配
    if (normalizedQuery.length < 3) return const _TaskResolution();

    // 1) 完全一致
    final exact = tasks
        .where((task) => _normalize(task.title) == normalizedQuery)
        .toList();
    if (exact.length == 1) return _TaskResolution(target: exact.first);
    if (exact.length > 1) return _TaskResolution(candidates: exact);

    // 2) title 包含 query（去掉反向 contains 规则，避免"数据"命中"Python 数据清洗"）
    //    仅当 query 出现在 title 里才算候选
    final partial = tasks.where((task) {
      final title = _normalize(task.title);
      return title.contains(normalizedQuery);
    }).toList();

    if (partial.isEmpty) return const _TaskResolution();

    // 3) 单个候选：要求覆盖率 >= 60%，否则返回 candidates 让用户澄清
    if (partial.length == 1) {
      final title = _normalize(partial.first.title);
      final coverage = title.isEmpty
          ? 0.0
          : normalizedQuery.length / title.length;
      if (coverage >= 0.6) return _TaskResolution(target: partial.first);
      return _TaskResolution(candidates: partial);
    }

    // 4) 多个候选：全部返回让用户澄清
    return _TaskResolution(candidates: partial);
  }

  String _bestSource(AiAppAction action, String input) {
    return (action.sourceText ??
            action.content ??
            action.title ??
            action.targetTitle ??
            input)
        .trim();
  }

  String _normalize(String text) {
    return text.toLowerCase().replaceAll(RegExp(r'\s+'), '');
  }

  List<NoteBlock> _markdownToNoteBlocks(String markdown) {
    final blocks = <NoteBlock>[];
    var idCounter = DateTime.now().microsecondsSinceEpoch;
    String id() => '${idCounter++}';

    final lines = markdown.split('\n');
    var inCode = false;
    final codeBuffer = StringBuffer();
    for (final line in lines) {
      final trimmed = line.trim();
      if (trimmed.startsWith('```')) {
        if (inCode) {
          final code = codeBuffer.toString().trim();
          if (code.isNotEmpty) {
            blocks.add(NoteBlock(
              id: id(),
              type: NoteBlockType.code,
              content: code,
            ));
          }
          codeBuffer.clear();
          inCode = false;
        } else {
          inCode = true;
        }
        continue;
      }
      if (inCode) {
        codeBuffer.writeln(line);
        continue;
      }
      if (trimmed.isEmpty) continue;
      if (trimmed == '---' || trimmed == '***') {
        blocks.add(NoteBlock(id: id(), type: NoteBlockType.divider));
      } else if (trimmed.startsWith('#')) {
        blocks.add(NoteBlock(
          id: id(),
          type: NoteBlockType.heading,
          content: trimmed.replaceFirst(RegExp(r'^#+\s*'), ''),
        ));
      } else if (trimmed.startsWith('- [ ]') || trimmed.startsWith('- [x]')) {
        blocks.add(NoteBlock(
          id: id(),
          type: NoteBlockType.todo,
          content: trimmed.substring(5).trim(),
          checked: trimmed.startsWith('- [x]'),
        ));
      } else if (trimmed.startsWith('- ') || trimmed.startsWith('* ')) {
        blocks.add(NoteBlock(
          id: id(),
          type: NoteBlockType.bullet,
          content: trimmed.substring(2).trim(),
        ));
      } else {
        blocks.add(NoteBlock(
          id: id(),
          type: NoteBlockType.text,
          content: trimmed,
        ));
      }
    }
    if (blocks.isEmpty) {
      blocks.add(NoteBlock(id: id(), content: markdown.trim()));
    }
    return blocks;
  }
}

class _TaskResolution {
  const _TaskResolution({
    this.target,
    this.candidates = const [],
  });

  final StudyTaskItem? target;
  final List<StudyTaskItem> candidates;
}
