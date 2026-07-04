import 'package:flutter/material.dart';

import '../../config/ui_review_config.dart';
import '../../controllers/app_data_controller.dart';
import '../../models/ai_flash_card.dart';
import '../../models/study_log_item.dart';
import '../../models/study_note.dart';
import '../../models/study_task_item.dart';
import '../../theme/app_theme.dart';
import '../shared/app_assets.dart';
import '../shared/common_widgets.dart';

class KnowledgeGraphPage extends StatefulWidget {
  const KnowledgeGraphPage({
    super.key,
    required this.isDarkMode,
    required this.controller,
  });

  final bool isDarkMode;
  final AppDataController controller;

  @override
  State<KnowledgeGraphPage> createState() => _KnowledgeGraphPageState();
}

class _KnowledgeGraphPageState extends State<KnowledgeGraphPage> {
  String? _selectedCourse;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.controller,
      builder: (context, _) {
        final maps = _courseMaps();
        if (maps.isEmpty) {
          return StudyScreenBackground(
            isDarkMode: widget.isDarkMode,
            accent: widget.controller.primaryColor,
            child: Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: StudyEmptyState(
                  asset: AppAssets.uiRefreshFeatureKnowledge,
                  title: '还没有知识地图',
                  message: '先保存学习记录、笔记或闪卡，这里会按课程整理出该复习什么、哪里还不熟。',
                ),
              ),
            ),
          );
        }

        final selected = _selectedMap(maps);
        final totalCards =
            maps.fold<int>(0, (sum, item) => sum + item.cards.length);
        final dueCards = maps.fold<int>(
          0,
          (sum, item) =>
              sum + item.cards.where((card) => card.isDueForReview).length,
        );
        final openTasks = maps.fold<int>(
          0,
          (sum, item) =>
              sum +
              item.tasks
                  .where(
                    (task) =>
                        task.effectiveStatus != StudyTaskStatus.completed,
                  )
                  .length,
        );

        return StudyScreenBackground(
          isDarkMode: widget.isDarkMode,
          accent: widget.controller.primaryColor,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 120),
            children: [
              _KnowledgeHero(
                isDarkMode: widget.isDarkMode,
                accent: widget.controller.primaryColor,
                courseCount: maps.length,
                cardCount: totalCards,
                dueCardCount: dueCards,
                openTaskCount: openTasks,
              ),
              const SizedBox(height: 16),
              _CourseMapStrip(
                maps: maps,
                selectedCourse: selected.courseName,
                isDarkMode: widget.isDarkMode,
                onSelected: (course) =>
                    setState(() => _selectedCourse = course),
              ),
              const SizedBox(height: 16),
              _CourseDetailPanel(
                map: selected,
                isDarkMode: widget.isDarkMode,
                accent: _courseColor(selected),
              ),
              const SizedBox(height: 16),
              _KnowledgeSection(
                title: '先补这里',
                subtitle: selected.nextFocus,
                icon: Icons.flag_rounded,
                color: StudyUi.warning,
                isDarkMode: widget.isDarkMode,
                children: [
                  if (selected.weakCards.isNotEmpty)
                    ...selected.weakCards
                        .take(3)
                        .map((card) => _FlashCardKnowledgeTile(
                              card: card,
                              isDarkMode: widget.isDarkMode,
                            ))
                  else
                    _SoftHintTile(
                      icon: Icons.check_circle_rounded,
                      title: '暂时没有明显薄弱闪卡',
                      subtitle: '可以先看本课程最近的任务和笔记，继续补充复习卡。',
                      color: StudyUi.success,
                      isDarkMode: widget.isDarkMode,
                    ),
                ],
              ),
              const SizedBox(height: 14),
              _KnowledgeSection(
                title: '相关笔记',
                subtitle: selected.notes.isEmpty
                    ? '这门课还没有笔记'
                    : '复习前先扫一眼最近整理的内容。',
                icon: Icons.edit_note_rounded,
                color: StudyUi.pathCyan,
                isDarkMode: widget.isDarkMode,
                children: selected.notes.isEmpty
                    ? [
                        _SoftHintTile(
                          icon: Icons.note_add_rounded,
                          title: '还没有这门课的笔记',
                          subtitle: '下次整理学习材料时保存成笔记，这里会自动串起来。',
                          color: StudyUi.pathCyan,
                          isDarkMode: widget.isDarkMode,
                        ),
                      ]
                    : selected.notes
                        .take(3)
                        .map((note) => _NoteKnowledgeTile(
                              note: note,
                              isDarkMode: widget.isDarkMode,
                            ))
                        .toList(),
              ),
              const SizedBox(height: 14),
              _KnowledgeSection(
                title: '下一步任务',
                subtitle: selected.openTasks.isEmpty
                    ? '暂时没有未完成任务'
                    : '把地图落到今天能做的一小步。',
                icon: Icons.task_alt_rounded,
                color: StudyUi.success,
                isDarkMode: widget.isDarkMode,
                children: selected.openTasks.isEmpty
                    ? [
                        _SoftHintTile(
                          icon: Icons.done_all_rounded,
                          title: '这门课暂时没有待办',
                          subtitle: '如果复习时发现缺口，可以从学习助手整理一个下一步。',
                          color: StudyUi.success,
                          isDarkMode: widget.isDarkMode,
                        ),
                      ]
                    : selected.openTasks
                        .take(3)
                        .map((task) => _TaskKnowledgeTile(
                              task: task,
                              isDarkMode: widget.isDarkMode,
                            ))
                        .toList(),
              ),
              const SizedBox(height: 14),
              _KnowledgeSection(
                title: '最近学习',
                subtitle: selected.logs.isEmpty
                    ? '还没有这门课的学习记录'
                    : '看看最近学了什么，以及上次留下的下一步。',
                icon: Icons.history_rounded,
                color: StudyUi.pathViolet,
                isDarkMode: widget.isDarkMode,
                children: selected.logs.isEmpty
                    ? [
                        _SoftHintTile(
                          icon: Icons.history_toggle_off_rounded,
                          title: '还没有学习记录',
                          subtitle: '完成复盘或专注后保存记录，地图会更准。',
                          color: StudyUi.pathViolet,
                          isDarkMode: widget.isDarkMode,
                        ),
                      ]
                    : selected.logs
                        .take(2)
                        .map((log) => _LogKnowledgeTile(
                              log: log,
                              isDarkMode: widget.isDarkMode,
                            ))
                        .toList(),
              ),
            ],
          ),
        );
      },
    );
  }

  List<_CourseKnowledgeMap> _courseMaps() {
    final courseNames = <String>{};
    for (final name in widget.controller.courseNames) {
      if (name.trim().isNotEmpty) courseNames.add(name.trim());
    }
    for (final note in widget.controller.studyNotes) {
      if (!note.isFolder && note.courseName.trim().isNotEmpty) {
        courseNames.add(note.courseName.trim());
      }
    }
    for (final card in widget.controller.flashCards) {
      if (card.courseName.trim().isNotEmpty) {
        courseNames.add(card.courseName.trim());
      }
    }

    if (UiReviewConfig.enabled && courseNames.isEmpty) {
      courseNames.addAll(['高等数学', '计算机导论']);
    }

    final maps = courseNames.map((course) {
      final tasks = widget.controller.studyTasks
          .where((task) => task.courseName == course)
          .toList()
        ..sort((a, b) => a.deadline.compareTo(b.deadline));
      final notes = widget.controller.studyNotes
          .where((note) => !note.isFolder && note.courseName == course)
          .toList()
        ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
      final cards = widget.controller.flashCards
          .where((card) => card.courseName == course)
          .toList()
        ..sort((a, b) {
          if (a.isDueForReview != b.isDueForReview) {
            return a.isDueForReview ? -1 : 1;
          }
          return a.masteryPercent.compareTo(b.masteryPercent);
        });
      final logs = widget.controller.studyLogs
          .where((log) => log.courseName == course)
          .toList()
        ..sort((a, b) => b.date.compareTo(a.date));
      return _CourseKnowledgeMap(
        courseName: course,
        tasks: tasks.isEmpty && UiReviewConfig.enabled
            ? _reviewTasksFor(course)
            : tasks,
        notes: notes.isEmpty && UiReviewConfig.enabled
            ? _reviewNotesFor(course)
            : notes,
        cards: cards.isEmpty && UiReviewConfig.enabled
            ? _reviewCardsFor(course)
            : cards,
        logs: logs.isEmpty && UiReviewConfig.enabled
            ? _reviewLogsFor(course)
            : logs,
      );
    }).toList();

    maps.sort((a, b) => b.priorityScore.compareTo(a.priorityScore));
    return maps;
  }

  _CourseKnowledgeMap _selectedMap(List<_CourseKnowledgeMap> maps) {
    final selectedCourse = _selectedCourse;
    if (selectedCourse != null) {
      for (final map in maps) {
        if (map.courseName == selectedCourse) return map;
      }
    }
    return maps.first;
  }

  Color _courseColor(_CourseKnowledgeMap map) {
    if (map.dueCardCount > 0 || map.weakCards.isNotEmpty) return StudyUi.warning;
    if (map.openTasks.isNotEmpty) return StudyUi.pathCyan;
    return StudyUi.success;
  }

  List<StudyTaskItem> _reviewTasksFor(String course) {
    final now = DateTime.now();
    return [
      StudyTaskItem(
        id: 'knowledge_review_task_$course',
        title: course.contains('数学') ? '重做 3 道洛必达判断题' : '整理章节知识关系',
        type: course.contains('数学')
            ? StudyTaskType.examReview
            : StudyTaskType.readingNotes,
        courseName: course,
        deadline: DateTime(now.year, now.month, now.day, 22),
        note: course.contains('数学')
            ? '先判断未定式，再看可导条件。'
            : '把概念、例题和错题放到同一页。',
        createdAt: now,
        updatedAt: now,
      ),
    ];
  }

  List<StudyNote> _reviewNotesFor(String course) {
    final now = DateTime.now();
    return [
      StudyNote(
        id: 'knowledge_review_note_$course',
        title: course.contains('数学') ? '洛必达法则使用条件' : '课程重点整理',
        content: course.contains('数学')
            ? '先确认 0/0 或无穷/无穷型，再检查可导条件和求导后的极限。'
            : '把本章概念、例子和容易混淆的点放在一起复习。',
        courseName: course,
        createdAt: now.subtract(const Duration(days: 1)),
        updatedAt: now,
      ),
    ];
  }

  List<AiFlashCard> _reviewCardsFor(String course) {
    final now = DateTime.now();
    return [
      AiFlashCard(
        id: 'knowledge_review_card_$course',
        question: course.contains('数学')
            ? '洛必达法则使用前先检查什么？'
            : '复习这一章时先看哪三类内容？',
        answer: course.contains('数学')
            ? '先确认未定式，再检查可导条件，最后看求导后的极限是否存在。'
            : '先看核心概念，再看例题，最后看自己做错或没弄懂的地方。',
        hint: course.contains('数学') ? '从形式、条件、结果三步检查。' : '概念、例题、难点。',
        courseName: course,
        createdAt: now.subtract(const Duration(days: 2)),
        lastReviewScore: course.contains('数学') ? 2 : 3,
        nextReviewDate: now.subtract(const Duration(hours: 2)),
        weakTags: const ['优先复习'],
      ),
    ];
  }

  List<StudyLogItem> _reviewLogsFor(String course) {
    final now = DateTime.now();
    return [
      StudyLogItem(
        id: 'knowledge_review_log_$course',
        date: now.subtract(const Duration(days: 1)),
        courseName: course,
        content: course.contains('数学')
            ? '复习了极限题，发现条件判断还不稳。'
            : '整理了章节概念，准备补一组复习卡。',
        problems: course.contains('数学') ? '容易跳过未定式判断。' : '',
        nextPlan: course.contains('数学')
            ? '先重做 3 道判断题'
            : '把易混点做成闪卡',
        createdAt: now.subtract(const Duration(days: 1)),
      ),
    ];
  }
}

class _CourseKnowledgeMap {
  const _CourseKnowledgeMap({
    required this.courseName,
    required this.tasks,
    required this.notes,
    required this.cards,
    required this.logs,
  });

  final String courseName;
  final List<StudyTaskItem> tasks;
  final List<StudyNote> notes;
  final List<AiFlashCard> cards;
  final List<StudyLogItem> logs;

  List<StudyTaskItem> get openTasks => tasks
      .where((task) => task.effectiveStatus != StudyTaskStatus.completed)
      .toList();

  int get dueCardCount => cards.where((card) => card.isDueForReview).length;

  List<AiFlashCard> get weakCards => cards
      .where(
        (card) =>
            card.isDueForReview ||
            card.masteryPercent < 70 ||
            card.weakTags.isNotEmpty,
      )
      .toList();

  int get priorityScore =>
      dueCardCount * 5 + weakCards.length * 3 + openTasks.length * 2 + notes.length;

  double get progress {
    final taskProgress = tasks.isEmpty
        ? 0.0
        : tasks.fold<double>(0, (sum, task) => sum + task.progress) /
            tasks.length;
    final cardProgress = cards.isEmpty
        ? 0.0
        : cards.fold<double>(
              0,
              (sum, card) => sum + card.masteryPercent.clamp(0, 100) / 100,
            ) /
            cards.length;
    if (tasks.isEmpty && cards.isEmpty) return notes.isEmpty ? 0.0 : 0.36;
    if (tasks.isEmpty) return cardProgress;
    if (cards.isEmpty) return taskProgress;
    return (taskProgress * 0.46 + cardProgress * 0.54).clamp(0.0, 1.0);
  }

  String get nextFocus {
    if (weakCards.isNotEmpty) {
      final card = weakCards.first;
      return '先复习「${_clip(card.question, 18)}」，这张卡最需要回看。';
    }
    if (openTasks.isNotEmpty) {
      return '先推进「${_clip(openTasks.first.title, 18)}」。';
    }
    if (notes.isNotEmpty) {
      return '先扫一眼「${_clip(notes.first.title, 18)}」，再补一张复习卡。';
    }
    return '先补一条学习记录或笔记，地图会更有用。';
  }
}

class _KnowledgeHero extends StatelessWidget {
  const _KnowledgeHero({
    required this.isDarkMode,
    required this.accent,
    required this.courseCount,
    required this.cardCount,
    required this.dueCardCount,
    required this.openTaskCount,
  });

  final bool isDarkMode;
  final Color accent;
  final int courseCount;
  final int cardCount;
  final int dueCardCount;
  final int openTaskCount;

  @override
  Widget build(BuildContext context) {
    return StudyPathHero(
      isDarkMode: isDarkMode,
      accent: accent,
      badge: '知识地图',
      title: '先看哪门课还不熟',
      subtitle: '按课程把笔记、闪卡、任务和学习记录放在一起，先补薄弱点，再做下一步。',
      icon: Icons.account_tree_rounded,
      child: Row(
        children: [
          Expanded(
            child: StudyPathMetricPill(
              label: '课程',
              value: '$courseCount',
              icon: Icons.school_rounded,
              color: accent,
              isDarkMode: isDarkMode,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: StudyPathMetricPill(
              label: '待复习',
              value: '$dueCardCount/$cardCount',
              icon: Icons.style_rounded,
              color: StudyUi.warning,
              isDarkMode: isDarkMode,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: StudyPathMetricPill(
              label: '待办',
              value: '$openTaskCount',
              icon: Icons.task_alt_rounded,
              color: StudyUi.success,
              isDarkMode: isDarkMode,
            ),
          ),
        ],
      ),
    );
  }
}

class _CourseMapStrip extends StatelessWidget {
  const _CourseMapStrip({
    required this.maps,
    required this.selectedCourse,
    required this.isDarkMode,
    required this.onSelected,
  });

  final List<_CourseKnowledgeMap> maps;
  final String selectedCourse;
  final bool isDarkMode;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 132,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: maps.length,
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (context, index) {
          final map = maps[index];
          final selected = map.courseName == selectedCourse;
          return _CourseMapCard(
            map: map,
            selected: selected,
            isDarkMode: isDarkMode,
            onTap: () => onSelected(map.courseName),
          );
        },
      ),
    );
  }
}

class _CourseMapCard extends StatelessWidget {
  const _CourseMapCard({
    required this.map,
    required this.selected,
    required this.isDarkMode,
    required this.onTap,
  });

  final _CourseKnowledgeMap map;
  final bool selected;
  final bool isDarkMode;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final accent = map.dueCardCount > 0
        ? StudyUi.warning
        : (map.openTasks.isNotEmpty ? StudyUi.pathCyan : StudyUi.success);
    final titleColor = StudyUi.title(isDarkMode);
    final bodyColor = StudyUi.body(isDarkMode);
    return SizedBox(
      width: 196,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(22),
          onTap: onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: selected
                  ? accent.withValues(alpha: isDarkMode ? 0.18 : 0.13)
                  : StudyUi.surfaceAlt(isDarkMode),
              borderRadius: BorderRadius.circular(22),
              border: Border.all(
                color: selected
                    ? accent.withValues(alpha: 0.44)
                    : StudyUi.border(isDarkMode),
              ),
              boxShadow: [
                if (selected && !isDarkMode)
                  BoxShadow(
                    color: accent.withValues(alpha: 0.16),
                    blurRadius: 22,
                    offset: const Offset(0, 12),
                  ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    StudyGlassIconNode(
                      icon: Icons.school_rounded,
                      accent: accent,
                      size: 34,
                      iconSize: 16,
                      isDarkMode: isDarkMode,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        map.courseName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: titleColor,
                          fontWeight: AppTypography.hero,
                        ),
                      ),
                    ),
                  ],
                ),
                const Spacer(),
                _MiniProgressBar(
                  value: map.progress,
                  color: accent,
                  isDarkMode: isDarkMode,
                ),
                const SizedBox(height: 8),
                Text(
                  map.dueCardCount > 0
                      ? '${map.dueCardCount} 张要复习'
                      : '${map.openTasks.length} 个下一步',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: bodyColor, fontSize: 12),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CourseDetailPanel extends StatelessWidget {
  const _CourseDetailPanel({
    required this.map,
    required this.isDarkMode,
    required this.accent,
  });

  final _CourseKnowledgeMap map;
  final bool isDarkMode;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final titleColor = StudyUi.title(isDarkMode);
    final bodyColor = StudyUi.body(isDarkMode);
    return StudyCard(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              StudyGlassIconNode(
                icon: Icons.route_rounded,
                accent: accent,
                size: 46,
                iconSize: 20,
                isDarkMode: isDarkMode,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      map.courseName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: titleColor,
                        fontSize: 20,
                        fontWeight: AppTypography.hero,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      map.nextFocus,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: bodyColor,
                        fontSize: 13,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _MiniProgressBar(
            value: map.progress,
            color: accent,
            isDarkMode: isDarkMode,
            height: 10,
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              BadgePill(
                label: '笔记 ${map.notes.length}',
                background: StudyUi.chipBackground(StudyUi.pathCyan, isDarkMode),
                foreground: StudyUi.pathCyan,
              ),
              BadgePill(
                label: '闪卡 ${map.cards.length}',
                background: StudyUi.chipBackground(StudyUi.warning, isDarkMode),
                foreground: StudyUi.warning,
              ),
              BadgePill(
                label: '待办 ${map.openTasks.length}',
                background: StudyUi.chipBackground(StudyUi.success, isDarkMode),
                foreground: StudyUi.success,
              ),
              BadgePill(
                label: '记录 ${map.logs.length}',
                background:
                    StudyUi.chipBackground(StudyUi.pathViolet, isDarkMode),
                foreground: StudyUi.pathViolet,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _KnowledgeSection extends StatelessWidget {
  const _KnowledgeSection({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.isDarkMode,
    required this.children,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final bool isDarkMode;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final titleColor = StudyUi.title(isDarkMode);
    final bodyColor = StudyUi.body(isDarkMode);
    return StudyCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              StudyGlassIconNode(
                icon: icon,
                accent: color,
                size: 38,
                iconSize: 17,
                isDarkMode: isDarkMode,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        color: titleColor,
                        fontSize: 16,
                        fontWeight: AppTypography.hero,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: bodyColor,
                        fontSize: 12,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...children,
        ],
      ),
    );
  }
}

class _FlashCardKnowledgeTile extends StatelessWidget {
  const _FlashCardKnowledgeTile({
    required this.card,
    required this.isDarkMode,
  });

  final AiFlashCard card;
  final bool isDarkMode;

  @override
  Widget build(BuildContext context) {
    return _KnowledgeTile(
      icon: Icons.style_rounded,
      color: card.masteryPercent < 70 ? StudyUi.warning : StudyUi.pathCyan,
      title: card.question,
      subtitle: card.hint.isNotEmpty
          ? card.hint
          : '${card.masteryLabel} · 掌握 ${card.masteryPercent}%',
      trailing: card.isDueForReview ? '今天看' : '${card.masteryPercent}%',
      isDarkMode: isDarkMode,
    );
  }
}

class _NoteKnowledgeTile extends StatelessWidget {
  const _NoteKnowledgeTile({
    required this.note,
    required this.isDarkMode,
  });

  final StudyNote note;
  final bool isDarkMode;

  @override
  Widget build(BuildContext context) {
    final summary = note.content.trim().isNotEmpty
        ? note.content.trim()
        : note.blocks
            .map((block) => block.content.trim())
            .where((content) => content.isNotEmpty)
            .join(' ');
    return _KnowledgeTile(
      icon: Icons.edit_note_rounded,
      color: StudyUi.pathCyan,
      title: note.title.isEmpty ? '学习笔记' : note.title,
      subtitle: summary.isEmpty ? '打开笔记补充这门课的重点。' : summary,
      trailing: _dateLabel(note.updatedAt),
      isDarkMode: isDarkMode,
    );
  }
}

class _TaskKnowledgeTile extends StatelessWidget {
  const _TaskKnowledgeTile({
    required this.task,
    required this.isDarkMode,
  });

  final StudyTaskItem task;
  final bool isDarkMode;

  @override
  Widget build(BuildContext context) {
    return _KnowledgeTile(
      icon: task.type.icon,
      color: task.effectiveStatus == StudyTaskStatus.inProgress
          ? StudyUi.pathCyan
          : StudyUi.success,
      title: task.title,
      subtitle: task.note.isEmpty ? task.type.label : task.note,
      trailing: _dateLabel(task.deadline),
      isDarkMode: isDarkMode,
    );
  }
}

class _LogKnowledgeTile extends StatelessWidget {
  const _LogKnowledgeTile({
    required this.log,
    required this.isDarkMode,
  });

  final StudyLogItem log;
  final bool isDarkMode;

  @override
  Widget build(BuildContext context) {
    final text = log.nextPlan.trim().isNotEmpty
        ? '下一步：${log.nextPlan.trim()}'
        : log.content.trim();
    return _KnowledgeTile(
      icon: Icons.history_rounded,
      color: StudyUi.pathViolet,
      title: _dateLabel(log.date),
      subtitle: text.isEmpty ? '这条记录还没有下一步。' : text,
      trailing: log.problems.trim().isNotEmpty ? '有难点' : '记录',
      isDarkMode: isDarkMode,
    );
  }
}

class _SoftHintTile extends StatelessWidget {
  const _SoftHintTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.isDarkMode,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final bool isDarkMode;

  @override
  Widget build(BuildContext context) {
    return _KnowledgeTile(
      icon: icon,
      color: color,
      title: title,
      subtitle: subtitle,
      trailing: '',
      isDarkMode: isDarkMode,
    );
  }
}

class _KnowledgeTile extends StatelessWidget {
  const _KnowledgeTile({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.trailing,
    required this.isDarkMode,
  });

  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final String trailing;
  final bool isDarkMode;

  @override
  Widget build(BuildContext context) {
    final titleColor = StudyUi.title(isDarkMode);
    final bodyColor = StudyUi.body(isDarkMode);
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: StudyUi.surfaceAlt(isDarkMode),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: StudyUi.border(isDarkMode)),
      ),
      child: Row(
        children: [
          StudyGlassIconNode(
            icon: icon,
            accent: color,
            size: 34,
            iconSize: 16,
            isDarkMode: isDarkMode,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: titleColor,
                    fontWeight: AppTypography.title,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: bodyColor,
                    fontSize: 12,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
          if (trailing.trim().isNotEmpty) ...[
            const SizedBox(width: 8),
            BadgePill(
              label: trailing,
              background: StudyUi.chipBackground(color, isDarkMode),
              foreground: color,
            ),
          ],
        ],
      ),
    );
  }
}

class _MiniProgressBar extends StatelessWidget {
  const _MiniProgressBar({
    required this.value,
    required this.color,
    required this.isDarkMode,
    this.height = 7,
  });

  final double value;
  final Color color;
  final bool isDarkMode;
  final double height;

  @override
  Widget build(BuildContext context) {
    final normalized = value.clamp(0.0, 1.0);
    return ClipRRect(
      borderRadius: BorderRadius.circular(999),
      child: Stack(
        children: [
          Container(
            height: height,
            color: StudyUi.border(isDarkMode).withValues(alpha: 0.48),
          ),
          FractionallySizedBox(
            widthFactor: normalized,
            child: Container(
              height: height,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    color.withValues(alpha: 0.78),
                    color,
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

String _clip(String text, int maxLength) {
  final trimmed = text.trim();
  if (trimmed.length <= maxLength) return trimmed;
  return '${trimmed.substring(0, maxLength)}...';
}

String _dateLabel(DateTime date) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final day = DateTime(date.year, date.month, date.day);
  final diff = day.difference(today).inDays;
  if (diff == 0) return '今天';
  if (diff == 1) return '明天';
  if (diff == -1) return '昨天';
  return '${date.month}/${date.day}';
}
