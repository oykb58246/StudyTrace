import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';

import '../../controllers/app_data_controller.dart';
import '../../models/study_log_item.dart';
import '../../models/study_task_item.dart';
import '../shared/common_widgets.dart';

class CalendarPage extends StatefulWidget {
  const CalendarPage({
    super.key,
    required this.isDarkMode,
    required this.controller,
  });

  final bool isDarkMode;
  final AppDataController controller;

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
        final accent = StudyUi.primary;
        final isDarkMode = widget.isDarkMode;
        final logs = widget.controller.studyLogs;
        final tasks = widget.controller.studyTasks;
        final logsByDate = _groupLogsByDate(logs);
        final tasksByDate = _groupTasksByDate(tasks);
        final selectedDayKey =
            _selectedDay != null ? _dayKey(_selectedDay!) : null;
        final selectedDayLogs = _selectedDay != null
            ? logsByDate[selectedDayKey!] ?? const <StudyLogItem>[]
            : <StudyLogItem>[];
        final selectedDayTasks = _selectedDay != null
            ? tasksByDate[selectedDayKey!] ?? const <StudyTaskItem>[]
            : <StudyTaskItem>[];

        return RefreshIndicator(
          onRefresh: () async => widget.controller.notifyListeners(),
          child: ListView(
          key: const Key('page_calendar'),
          padding: const EdgeInsets.fromLTRB(22, 82, 22, 124),
          children: [
            Text(
              '学习日历',
              style: TextStyle(
                color: StudyUi.title(isDarkMode),
                fontSize: 24,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 18),
            StudyCard(
              padding: const EdgeInsets.fromLTRB(8, 10, 8, 12),
              child: TableCalendar(
                firstDay: DateTime(2024),
                lastDay: DateTime(2030),
                focusedDay: _focusedDay,
                calendarFormat: _calendarFormat,
                selectedDayPredicate: (day) =>
                    isSameDay(_selectedDay, day),
                onDaySelected: (selected, focused) {
                  setState(() {
                    _selectedDay = selected;
                    _focusedDay = focused;
                  });
                },
                onFormatChanged: (format) {
                  setState(() => _calendarFormat = format);
                },
                onPageChanged: (focused) => _focusedDay = focused,
                eventLoader: (day) => [
                  ...?logsByDate[_dayKey(day)],
                  ...?tasksByDate[_dayKey(day)],
                ],
                headerStyle: HeaderStyle(
                  formatButtonVisible: true,
                  titleCentered: true,
                  titleTextStyle: TextStyle(
                    color: StudyUi.title(isDarkMode),
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                  ),
                  leftChevronIcon: Icon(
                    Icons.chevron_left_rounded,
                    color: StudyUi.muted(isDarkMode),
                  ),
                  rightChevronIcon: Icon(
                    Icons.chevron_right_rounded,
                    color: StudyUi.muted(isDarkMode),
                  ),
                  formatButtonDecoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(10),
                    color: accent.withValues(alpha: 0.15),
                  ),
                  formatButtonTextStyle: TextStyle(
                    color: accent,
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                  ),
                ),
                calendarStyle: CalendarStyle(
                  selectedDecoration: BoxDecoration(
                    color: accent,
                    shape: BoxShape.circle,
                  ),
                  todayDecoration: BoxDecoration(
                    color: accent.withValues(alpha: 0.3),
                    shape: BoxShape.circle,
                  ),
                  markerDecoration: const BoxDecoration(
                    color: StudyUi.success,
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
            ),
            const SizedBox(height: 18),
            if (_selectedDay != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text(
                  '${_selectedDay!.year}-${_selectedDay!.month.toString().padLeft(2, '0')}-${_selectedDay!.day.toString().padLeft(2, '0')} 的学习记录',
                  style: TextStyle(
                    color: StudyUi.title(isDarkMode),
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            if (selectedDayTasks.isNotEmpty) ...[
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  '日程任务',
                  style: TextStyle(
                    color: StudyUi.muted(isDarkMode),
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              ...selectedDayTasks.map((t) => _taskCard(t)),
              const SizedBox(height: 16),
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  '学习记录',
                  style: TextStyle(
                    color: StudyUi.muted(isDarkMode),
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
            if (selectedDayLogs.isEmpty && selectedDayTasks.isEmpty && _selectedDay != null)
              const StudyEmptyState.calendar(compact: true)
            else if (selectedDayLogs.isNotEmpty)
              for (final log in selectedDayLogs) ...[
                StudyCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: StudyUi.chipBackground(
                                    StudyUi.secondary, isDarkMode),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                log.courseName,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: StudyUi.secondary,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      if (log.content.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Text(
                          log.content,
                          style: TextStyle(
                            color: StudyUi.body(isDarkMode),
                            height: 1.5,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 10),
              ],
          ],
          ), // RefreshIndicator
        );
      },
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

  DateTime _dayKey(DateTime date) =>
      DateTime(date.year, date.month, date.day);

  Widget _taskCard(StudyTaskItem task) {
    final statusColor = switch (task.status) {
      StudyTaskStatus.completed => StudyUi.success,
      StudyTaskStatus.inProgress => StudyUi.warning,
      StudyTaskStatus.notStarted => StudyUi.secondary,
    };
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: StudyCard(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            Container(
              width: 4,
              height: 36,
              decoration: BoxDecoration(
                color: statusColor,
                borderRadius: BorderRadius.circular(2),
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
                      '${task.type.label} · ${task.courseName}',
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
}
