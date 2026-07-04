import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';

import '../../controllers/app_data_controller.dart';
import '../../models/study_log_item.dart';
import '../../models/study_task_item.dart';
import '../../theme/app_theme.dart';
import '../shared/common_widgets.dart';

class CalendarPage extends StatefulWidget {
  const CalendarPage({
    super.key,
    required this.isDarkMode,
    required this.controller,
    this.onOpenTasks,
    this.onOpenLogs,
  });

  final bool isDarkMode;
  final AppDataController controller;
  final VoidCallback? onOpenTasks;
  final VoidCallback? onOpenLogs;

  @override
  State<CalendarPage> createState() => _CalendarPageState();
}

class _CalendarPageState extends State<CalendarPage> {
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay = DateTime.now();
  CalendarFormat _calendarFormat = CalendarFormat.month;

  Map<DateTime, List<StudyLogItem>> _groupLogsByDate(
    List<StudyLogItem> logs,
  ) {
    final map = <DateTime, List<StudyLogItem>>{};
    for (final log in logs) {
      final day = _dayKey(log.date);
      map.putIfAbsent(day, () => []).add(log);
    }
    return map;
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.controller,
      builder: (context, _) {
        const accent = StudyUi.pathBlue;
        final isDarkMode = widget.isDarkMode;
        final logs = widget.controller.studyLogs;
        final tasks = widget.controller.studyTasks;
        final logsByDate = _groupLogsByDate(logs);
        final tasksByDate = _groupTasksByDate(tasks);
        final now = DateTime.now();
        final today = _dayKey(now);
        final selectedDayKey =
            _selectedDay != null ? _dayKey(_selectedDay!) : null;
        final selectedDayLogs = _selectedDay != null
            ? logsByDate[selectedDayKey!] ?? const <StudyLogItem>[]
            : <StudyLogItem>[];
        final selectedDayTasks = _selectedDay != null
            ? tasksByDate[selectedDayKey!] ?? const <StudyTaskItem>[]
            : <StudyTaskItem>[];
        final selectedDayOpenTasks = selectedDayTasks
            .where((task) => task.effectiveStatus != StudyTaskStatus.completed)
            .toList()
          ..sort((a, b) => a.deadline.compareTo(b.deadline));
        final compactHeader = StudyCompactHeaderScope.of(context);
        final pathTasks = [...selectedDayTasks]..sort((a, b) {
            if (a.effectiveStatus == b.effectiveStatus) {
              return a.deadline.compareTo(b.deadline);
            }
            if (a.effectiveStatus == StudyTaskStatus.completed) return 1;
            if (b.effectiveStatus == StudyTaskStatus.completed) return -1;
            return a.deadline.compareTo(b.deadline);
          });
        final visiblePathTasks = pathTasks.take(3).toList(growable: false);
        final nextTask =
            selectedDayOpenTasks.isNotEmpty ? selectedDayOpenTasks.first : null;

        return RefreshIndicator(
          onRefresh: widget.controller.load,
          child: ListView(
            key: const Key('page_calendar'),
            padding: EdgeInsets.fromLTRB(22, compactHeader ? 8 : 16, 22, 124),
            children: [
              StudyPathHero(
                isDarkMode: isDarkMode,
                accent: accent,
                badge: '学习日历',
                title: '点一天，看这天怎么学',
                subtitle: '往前看几天，往后排一排，点哪天就看哪天该做什么。',
                icon: Icons.calendar_month_rounded,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _weekLegendCard(),
                    const SizedBox(height: 12),
                    _weekStrip(logsByDate, tasksByDate),
                    const SizedBox(height: 12),
                    _nextStepCard(
                      selectedDay: selectedDayKey ?? today,
                      task: nextTask,
                      taskCount: selectedDayTasks.length,
                      logCount: selectedDayLogs.length,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              _sectionTitle(
                _selectedDayPlanTitle(selectedDayKey ?? today, today),
                '${pathTasks.length} 项',
              ),
              const SizedBox(height: 10),
              if (visiblePathTasks.isEmpty)
                StudyEmptyState.tasks(
                  title: _selectedDayEmptyTitle(selectedDayKey ?? today, today),
                  message: _selectedDayEmptyMessage(
                    selectedDay: selectedDayKey ?? today,
                    today: today,
                    logCount: selectedDayLogs.length,
                  ),
                  compact: true,
                )
              else
                for (var i = 0; i < visiblePathTasks.length; i++) ...[
                  _taskPathCard(
                    visiblePathTasks[i],
                    index: i + 1,
                    isLast: i == visiblePathTasks.length - 1,
                  ),
                  if (i != visiblePathTasks.length - 1)
                    const SizedBox(height: 8),
                ],
              if (pathTasks.length > visiblePathTasks.length) ...[
                const SizedBox(height: 4),
                Text(
                  '还有 ${pathTasks.length - visiblePathTasks.length} 件事，往下看日历就能找到',
                  style: TextStyle(
                    color: StudyUi.muted(isDarkMode),
                    fontSize: 12,
                    fontWeight: AppTypography.title,
                  ),
                ),
              ],
              const SizedBox(height: 18),
              _sectionTitle('整月看看', _selectedDayLabel()),
              const SizedBox(height: 10),
              _calendarCard(logsByDate, tasksByDate),
              const SizedBox(height: 16),
              if (selectedDayLogs.isEmpty &&
                  selectedDayTasks.isEmpty &&
                  _selectedDay != null)
                const StudyEmptyState.calendar(compact: true)
              else if (selectedDayLogs.isNotEmpty) ...[
                _sectionTitle(
                  '${_selectedDayLabel()}复盘',
                  '${selectedDayLogs.length} 条',
                ),
                const SizedBox(height: 10),
                for (final log in selectedDayLogs) ...[
                  StudyLogSummaryCard(
                    log: log,
                    isDarkMode: isDarkMode,
                    showDate: false,
                    maxLines: 2,
                    onTap: () => showStudyLogDetailDialog(context, log),
                  ),
                  const SizedBox(height: 10),
                ],
              ],
            ],
          ), // RefreshIndicator
        );
      },
    );
  }

  Widget _weekStrip(
    Map<DateTime, List<StudyLogItem>> logsByDate,
    Map<DateTime, List<StudyTaskItem>> tasksByDate,
  ) {
    final now = DateTime.now();
    final today = _dayKey(now);
    final start = today.subtract(const Duration(days: 3));
    final labels = ['一', '二', '三', '四', '五', '六', '日'];
    return SizedBox(
      height: 88,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        child: Row(
          children: [
            for (var i = 0; i < 14; i++) ...[
              Builder(
                builder: (context) {
                  final day = start.add(Duration(days: i));
                  final key = _dayKey(day);
                  return SizedBox(
                    width: 68,
                    child: _weekDayCell(
                      day: day,
                      label: labels[day.weekday - 1],
                      logs: logsByDate[key]?.length ?? 0,
                      tasks: tasksByDate[key] ?? const <StudyTaskItem>[],
                    ),
                  );
                },
              ),
              if (i != 13) const SizedBox(width: 8),
            ],
          ],
        ),
      ),
    );
  }

  Widget _weekLegendCard() {
    final dark = widget.isDarkMode;
    return StudyCard(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Row(
        children: [
          Icon(Icons.touch_app_rounded, color: StudyUi.pathBlue, size: 16),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '点某一天看看当天安排。圆点代表还有事要做，勾代表已完成，短线代表有学习回顾。',
              style: TextStyle(
                color: StudyUi.body(dark),
                fontSize: 12,
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _weekDayCell({
    required DateTime day,
    required String label,
    required int logs,
    required List<StudyTaskItem> tasks,
  }) {
    final key = _dayKey(day);
    final selected = _selectedDay != null && key == _dayKey(_selectedDay!);
    final isToday = key == _dayKey(DateTime.now());
    final openTasks = tasks
        .where((task) => task.effectiveStatus != StudyTaskStatus.completed)
        .length;
    final hasOpenTasks = openTasks > 0;
    final hasCompletedTasks = tasks.isNotEmpty && openTasks == 0;
    final hasLogs = logs > 0;
    final dark = widget.isDarkMode;
    return GestureDetector(
      onTap: () => setState(() {
        _selectedDay = day;
        _focusedDay = day;
      }),
      child: Container(
        height: 86,
        padding: const EdgeInsets.symmetric(vertical: 5),
        decoration: BoxDecoration(
          gradient: selected
              ? const LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [StudyUi.pathBlue, StudyUi.pathCyan],
                )
              : null,
          color: selected
              ? null
              : Colors.white.withValues(alpha: dark ? 0.05 : 0.70),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected
                ? Colors.white.withValues(alpha: 0.72)
                : StudyUi.border(dark),
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              label,
              style: TextStyle(
                color: selected ? Colors.white : StudyUi.muted(dark),
                fontSize: 10,
                fontWeight: AppTypography.title,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '${day.day}',
              style: TextStyle(
                color: selected ? Colors.white : StudyUi.title(dark),
                fontSize: isToday ? 17 : 14,
                fontWeight: AppTypography.hero,
              ),
            ),
            const SizedBox(height: 4),
            _dayMarker(
              selected: selected,
              dark: dark,
              hasOpenTasks: hasOpenTasks,
              hasCompletedTasks: hasCompletedTasks,
              hasLogs: hasLogs,
            ),
          ],
        ),
      ),
    );
  }

  Widget _dayMarker({
    required bool selected,
    required bool dark,
    required bool hasOpenTasks,
    required bool hasCompletedTasks,
    required bool hasLogs,
  }) {
    final activeColor = selected ? Colors.white : StudyUi.pathMint;
    if (hasOpenTasks) {
      return Container(
        width: 7,
        height: 7,
        decoration: BoxDecoration(
          color: activeColor,
          shape: BoxShape.circle,
        ),
      );
    }
    if (hasCompletedTasks) {
      return Icon(Icons.check_rounded, color: activeColor, size: 14);
    }
    if (hasLogs) {
      return Container(
        width: 13,
        height: 3,
        decoration: BoxDecoration(
          color: selected ? Colors.white : StudyUi.secondary,
          borderRadius: BorderRadius.circular(999),
        ),
      );
    }
    return Container(
      width: 5,
      height: 5,
      decoration: BoxDecoration(
        color: StudyUi.muted(dark).withValues(alpha: 0.28),
        shape: BoxShape.circle,
      ),
    );
  }

  Widget _nextStepCard({
    required DateTime selectedDay,
    required StudyTaskItem? task,
    required int taskCount,
    required int logCount,
  }) {
    final dark = widget.isDarkMode;
    final today = _dayKey(DateTime.now());
    final isToday = _dayKey(selectedDay) == today;
    final hasDoneTasks = task == null && taskCount > 0;
    final hasLogsOnly = task == null && taskCount == 0 && logCount > 0;
    final title = task != null
        ? task.title
        : hasDoneTasks
            ? (isToday ? '今天的任务已经做完了' : '这一天的任务已经做完了')
            : hasLogsOnly
                ? '这一天先回看复盘'
                : (isToday ? '今天先补一个下一步' : '这一天还没有安排');
    final subtitle = task != null
        ? '${task.courseName.isEmpty ? task.type.label : task.courseName} · ${_taskFmtDate(task.deadline)}'
        : hasDoneTasks
            ? '$taskCount 项任务已完成${logCount > 0 ? '，也有 $logCount 条复盘' : ''}。'
            : hasLogsOnly
                ? '这天有 $logCount 条复盘，可以先回看难点，再补一个下一步。'
                : '还没有任务或复盘，先加一个安排，这一页就会连起来。';
    final statusColor = task != null
        ? _taskStatusColor(task)
        : hasDoneTasks
            ? StudyUi.pathMint
            : hasLogsOnly
                ? StudyUi.secondary
                : StudyUi.pathViolet;
    final leadingIcon = task != null
        ? Icons.play_arrow_rounded
        : hasDoneTasks
            ? Icons.check_rounded
            : hasLogsOnly
                ? Icons.menu_book_rounded
                : Icons.auto_awesome_rounded;
    final heading = task != null
        ? (isToday
            ? '今天先做这一步'
            : '${selectedDay.month}月${selectedDay.day}日先做这一步')
        : hasDoneTasks
            ? (isToday
                ? '今天已经收尾了'
                : '${selectedDay.month}月${selectedDay.day}日已经收尾了')
            : hasLogsOnly
                ? (isToday
                    ? '今天先回看一下'
                    : '${selectedDay.month}月${selectedDay.day}日先回看一下')
                : (isToday
                    ? '今天先安排一下'
                    : '${selectedDay.month}月${selectedDay.day}日先安排一下');
    final actionLabel = task != null
        ? '看任务'
        : hasLogsOnly
            ? '看复盘'
            : '去安排';
    final actionIcon = task != null
        ? Icons.arrow_forward_rounded
        : hasLogsOnly
            ? Icons.notes_rounded
            : Icons.add_rounded;
    final onActionTap = task != null || hasDoneTasks
        ? widget.onOpenTasks
        : hasLogsOnly
            ? widget.onOpenLogs
            : widget.onOpenTasks;
    final progress = task?.progress ?? 0.0;
    return StudyCard(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          StudyGlassIconNode(
            icon: leadingIcon,
            accent: statusColor,
            size: 52,
            isDarkMode: dark,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  heading,
                  style: TextStyle(
                    color: StudyUi.muted(dark),
                    fontSize: 12,
                    fontWeight: AppTypography.title,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: StudyUi.title(dark),
                    fontSize: 16,
                    fontWeight: AppTypography.hero,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: StudyUi.body(dark), fontSize: 12),
                ),
                const SizedBox(height: 8),
                if (task != null)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(999),
                    child: LinearProgressIndicator(
                      value: progress.clamp(0.0, 1.0).toDouble(),
                      minHeight: 5,
                      backgroundColor: dark
                          ? Colors.white.withValues(alpha: 0.10)
                          : const Color(0xFFE7ECFF),
                      color: statusColor,
                    ),
                  )
                else
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _dayInfoChip(
                        label: '$taskCount 项任务',
                        color: statusColor,
                      ),
                      _dayInfoChip(
                        label: '$logCount 条复盘',
                        color:
                            hasLogsOnly ? StudyUi.secondary : StudyUi.pathBlue,
                      ),
                    ],
                  ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          if (onActionTap != null)
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  actionLabel,
                  style: TextStyle(
                    color: statusColor,
                    fontSize: 11,
                    fontWeight: AppTypography.title,
                  ),
                ),
                const SizedBox(height: 8),
                Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: onActionTap,
                    customBorder: const CircleBorder(),
                    child: Ink(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: const LinearGradient(
                          colors: [StudyUi.pathBlue, StudyUi.pathCyan],
                        ),
                        boxShadow: [
                          if (!dark)
                            BoxShadow(
                              color: StudyUi.pathBlue.withValues(alpha: 0.22),
                              blurRadius: 18,
                              offset: const Offset(0, 10),
                            ),
                        ],
                      ),
                      child: Icon(
                        actionIcon,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _sectionTitle(String title, String trailing) {
    final dark = widget.isDarkMode;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: TextStyle(
                color: StudyUi.title(dark),
                fontSize: 18,
                fontWeight: AppTypography.hero,
              ),
            ),
          ),
          BadgePill(
            label: trailing,
            background: StudyUi.chipBackground(StudyUi.pathBlue, dark),
            foreground: StudyUi.pathBlue,
          ),
        ],
      ),
    );
  }

  Widget _dayInfoChip({
    required String label,
    required Color color,
  }) {
    final dark = widget.isDarkMode;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: dark ? 0.18 : 0.10),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.16)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: AppTypography.title,
        ),
      ),
    );
  }

  String _selectedDayPlanTitle(DateTime selectedDay, DateTime today) {
    final label = _dayKey(selectedDay) == today
        ? '今天安排'
        : '${selectedDay.month}月${selectedDay.day}日安排';
    return label;
  }

  String _selectedDayEmptyTitle(DateTime selectedDay, DateTime today) {
    if (_dayKey(selectedDay) == today) return '今天还没有任务';
    return '${selectedDay.month}月${selectedDay.day}日还没有任务';
  }

  String _selectedDayEmptyMessage({
    required DateTime selectedDay,
    required DateTime today,
    required int logCount,
  }) {
    final isToday = _dayKey(selectedDay) == today;
    if (logCount > 0) {
      return isToday
          ? '今天虽然没有待办，但已经有 $logCount 条复盘。可以先回看一下，再补一个下一步。'
          : '${selectedDay.month}月${selectedDay.day}日这天没有待办，但已经有 $logCount 条复盘。';
    }
    return isToday
        ? '先加一个任务，或者记一条复盘，这一页就会把今天的安排连起来。'
        : '这一天还是空的，等你加上任务或复盘后，这里会自动补上。';
  }

  Widget _taskPathCard(
    StudyTaskItem task, {
    required int index,
    required bool isLast,
  }) {
    final statusColor = _taskStatusColor(task);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 34,
          child: Column(
            children: [
              StudyGlassIconNode(
                icon: task.effectiveStatus == StudyTaskStatus.completed
                    ? Icons.check_rounded
                    : Icons.route_rounded,
                accent: statusColor,
                size: 32,
                iconSize: 14,
                isDarkMode: widget.isDarkMode,
              ),
              if (!isLast)
                Container(
                  width: 2,
                  height: 54,
                  margin: const EdgeInsets.symmetric(vertical: 3),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.25),
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(width: 10),
        Expanded(child: _taskCard(task, index: index)),
      ],
    );
  }

  Widget _calendarViewControls() {
    final dark = widget.isDarkMode;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6),
      child: Row(
        children: [
          Expanded(
            child: Text(
              '日历显示',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: StudyUi.body(dark),
                fontSize: 12,
                fontWeight: AppTypography.title,
              ),
            ),
          ),
          Wrap(
            spacing: 6,
            children: [
              _calendarFormatChip(CalendarFormat.month, '月'),
              _calendarFormatChip(CalendarFormat.twoWeeks, '双周'),
              _calendarFormatChip(CalendarFormat.week, '周'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _calendarFormatChip(CalendarFormat format, String label) {
    final selected = _calendarFormat == format;
    return StudyStatusChip(
      label: label,
      color: StudyUi.pathBlue,
      selected: selected,
      onTap: () => setState(() => _calendarFormat = format),
    );
  }

  Widget _calendarCard(
    Map<DateTime, List<StudyLogItem>> logsByDate,
    Map<DateTime, List<StudyTaskItem>> tasksByDate,
  ) {
    const accent = StudyUi.pathBlue;
    final isDarkMode = widget.isDarkMode;
    return StudyCard(
      padding: const EdgeInsets.fromLTRB(8, 10, 8, 12),
      child: Column(
        children: [
          _calendarViewControls(),
          const SizedBox(height: 8),
          TableCalendar(
            availableCalendarFormats: const {
              CalendarFormat.month: '按月看',
              CalendarFormat.twoWeeks: '双周',
              CalendarFormat.week: '按周看',
            },
            firstDay: DateTime(2024),
            lastDay: DateTime(2030),
            focusedDay: _focusedDay,
            calendarFormat: _calendarFormat,
            startingDayOfWeek: StartingDayOfWeek.monday,
            selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
            onDaySelected: (selected, focused) {
              setState(() {
                _selectedDay = selected;
                _focusedDay = focused;
              });
            },
            onFormatChanged: (format) {
              setState(() => _calendarFormat = format);
            },
            onPageChanged: (focused) => setState(() => _focusedDay = focused),
            eventLoader: (day) => [
              ...?logsByDate[_dayKey(day)],
              ...?tasksByDate[_dayKey(day)],
            ],
            headerStyle: HeaderStyle(
              formatButtonVisible: false,
              titleCentered: true,
              titleTextStyle: TextStyle(
                color: StudyUi.title(isDarkMode),
                fontSize: 17,
                fontWeight: AppTypography.title,
              ),
              leftChevronIcon: Icon(
                Icons.chevron_left_rounded,
                color: StudyUi.muted(isDarkMode),
              ),
              rightChevronIcon: Icon(
                Icons.chevron_right_rounded,
                color: StudyUi.muted(isDarkMode),
              ),
            ),
            calendarBuilders: CalendarBuilders(
              headerTitleBuilder: (context, focusedDay) {
                return Center(
                  child: Text(
                    _monthTitle(focusedDay),
                    style: TextStyle(
                      color: StudyUi.title(isDarkMode),
                      fontSize: 17,
                      fontWeight: AppTypography.title,
                    ),
                  ),
                );
              },
              dowBuilder: (context, day) {
                return Center(
                  child: Text(
                    _weekdayLabel(day),
                    style: TextStyle(
                      color: StudyUi.muted(isDarkMode),
                      fontSize: 12,
                      fontWeight: AppTypography.title,
                    ),
                  ),
                );
              },
            ),
            calendarStyle: CalendarStyle(
              selectedDecoration: const BoxDecoration(
                color: accent,
                shape: BoxShape.circle,
              ),
              todayDecoration: BoxDecoration(
                color: accent.withValues(alpha: 0.3),
                shape: BoxShape.circle,
              ),
              markerDecoration: const BoxDecoration(
                color: StudyUi.pathMint,
                shape: BoxShape.circle,
              ),
              markerSize: 6,
              defaultTextStyle: TextStyle(
                color: StudyUi.title(isDarkMode),
              ),
              weekendTextStyle: TextStyle(
                color: StudyUi.muted(isDarkMode),
              ),
              outsideTextStyle: TextStyle(
                color: StudyUi.muted(isDarkMode).withValues(alpha: 0.45),
              ),
            ),
            daysOfWeekStyle: DaysOfWeekStyle(
              weekdayStyle: TextStyle(
                color: StudyUi.muted(isDarkMode),
                fontSize: 12,
              ),
              weekendStyle: TextStyle(
                color: StudyUi.muted(isDarkMode),
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Map<DateTime, List<StudyTaskItem>> _groupTasksByDate(
    List<StudyTaskItem> tasks,
  ) {
    final map = <DateTime, List<StudyTaskItem>>{};
    for (final task in tasks) {
      final day = _dayKey(task.deadline);
      map.putIfAbsent(day, () => []).add(task);
    }
    return map;
  }

  DateTime _dayKey(DateTime date) => DateTime(date.year, date.month, date.day);

  Widget _taskCard(StudyTaskItem task, {int? index}) {
    final statusColor = _taskStatusColor(task);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: StudyCard(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: statusColor.withValues(
                  alpha: widget.isDarkMode ? 0.18 : 0.12,
                ),
                borderRadius: BorderRadius.circular(13),
              ),
              child: Text(
                index == null ? _taskTypeInitial(task) : '$index',
                style: TextStyle(
                  color: statusColor,
                  fontSize: 14,
                  fontWeight: AppTypography.hero,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    task.title,
                    style: TextStyle(
                      color: StudyUi.title(widget.isDarkMode),
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (task.courseName.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      '${task.type.label} · ${task.courseName} · ${_taskFmtDate(task.deadline)}',
                      style: TextStyle(
                        color: StudyUi.muted(widget.isDarkMode),
                        fontSize: 11,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
              decoration: BoxDecoration(
                color: statusColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                task.status.label,
                style: TextStyle(
                  color: statusColor,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _taskStatusColor(StudyTaskItem task) {
    return switch (task.effectiveStatus) {
      StudyTaskStatus.completed => StudyUi.pathMint,
      StudyTaskStatus.inProgress => StudyUi.pathViolet,
      StudyTaskStatus.notStarted => task.deadline.isBefore(DateTime.now())
          ? StudyUi.danger
          : StudyUi.pathBlue,
    };
  }

  String _selectedDayLabel() {
    if (_selectedDay == null) return '选择一天查看';
    return '${_selectedDay!.month}月${_selectedDay!.day}日';
  }

  String _taskFmtDate(DateTime date) {
    final hour = date.hour.toString().padLeft(2, '0');
    final minute = date.minute.toString().padLeft(2, '0');
    return '${date.month}月${date.day}日 $hour:$minute';
  }

  String _monthTitle(DateTime date) {
    return '${date.year}年${date.month}月';
  }

  String _weekdayLabel(DateTime date) {
    return switch (date.weekday) {
      DateTime.monday => '周一',
      DateTime.tuesday => '周二',
      DateTime.wednesday => '周三',
      DateTime.thursday => '周四',
      DateTime.friday => '周五',
      DateTime.saturday => '周六',
      DateTime.sunday => '周日',
      _ => '',
    };
  }

  String _taskTypeInitial(StudyTaskItem task) {
    final label = task.type.label.trim();
    return label.isEmpty ? '•' : label.substring(0, 1);
  }
}
