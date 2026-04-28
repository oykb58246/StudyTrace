import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';

import '../../controllers/app_data_controller.dart';
import '../../models/study_log_item.dart';
import '../../theme/app_theme.dart';
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
  DateTime? _selectedDay;
  CalendarFormat _calendarFormat = CalendarFormat.month;

  Map<DateTime, List<StudyLogItem>> _groupLogsByDate(
    List<StudyLogItem> logs,
  ) {
    final map = <DateTime, List<StudyLogItem>>{};
    for (final log in logs) {
      final day = DateTime(log.date.year, log.date.month, log.date.day);
      map.putIfAbsent(day, () => []).add(log);
    }
    return map;
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.controller,
      builder: (context, _) {
        final logs = widget.controller.studyLogs;
        final logsByDate = _groupLogsByDate(logs);
        final selectedDayLogs = _selectedDay != null
            ? logsByDate[_selectedDay!] ?? []
            : <StudyLogItem>[];

        return ListView(
          key: const Key('page_calendar'),
          padding: const EdgeInsets.fromLTRB(22, 82, 22, 124),
          children: [
            Text(
              '学习日历',
              style: TextStyle(
                color: widget.isDarkMode ? Colors.white : Colors.black,
                fontSize: 24,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 18),
            Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(24),
                color: widget.isDarkMode
                    ? const Color(0xFF242B37).withValues(alpha: 0.9)
                    : Colors.white,
              ),
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
                eventLoader: (day) => logsByDate[day] ?? [],
                headerStyle: HeaderStyle(
                  formatButtonVisible: true,
                  titleCentered: true,
                  titleTextStyle: TextStyle(
                    color: widget.isDarkMode ? Colors.white : AppColors.ink,
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                  ),
                  leftChevronIcon: Icon(
                    Icons.chevron_left_rounded,
                    color: widget.isDarkMode ? Colors.white54 : AppColors.muted,
                  ),
                  rightChevronIcon: Icon(
                    Icons.chevron_right_rounded,
                    color: widget.isDarkMode ? Colors.white54 : AppColors.muted,
                  ),
                  formatButtonDecoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(10),
                    color: const Color(0xFF7040F2).withValues(alpha: 0.15),
                  ),
                  formatButtonTextStyle: const TextStyle(
                    color: Color(0xFF7040F2),
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                  ),
                ),
                calendarStyle: CalendarStyle(
                  selectedDecoration: const BoxDecoration(
                    color: Color(0xFF7040F2),
                    shape: BoxShape.circle,
                  ),
                  todayDecoration: BoxDecoration(
                    color: const Color(0xFF7040F2).withValues(alpha: 0.3),
                    shape: BoxShape.circle,
                  ),
                  markerDecoration: const BoxDecoration(
                    color: Color(0xFF4BC4A1),
                    shape: BoxShape.circle,
                  ),
                  markerSize: 6,
                  defaultTextStyle: TextStyle(
                    color: widget.isDarkMode ? Colors.white : AppColors.ink,
                  ),
                  weekendTextStyle: TextStyle(
                    color: widget.isDarkMode ? Colors.white54 : AppColors.muted,
                  ),
                  outsideTextStyle: TextStyle(
                    color: widget.isDarkMode ? Colors.white24 : Colors.black26,
                  ),
                ),
                daysOfWeekStyle: DaysOfWeekStyle(
                  weekdayStyle: TextStyle(
                    color: widget.isDarkMode ? Colors.white54 : AppColors.muted,
                    fontSize: 12,
                  ),
                  weekendStyle: TextStyle(
                    color: widget.isDarkMode ? Colors.white54 : AppColors.muted,
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
                    color: widget.isDarkMode ? Colors.white : Colors.black,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            if (selectedDayLogs.isEmpty && _selectedDay != null)
              GlassCard(
                color: widget.isDarkMode
                    ? const Color(0xFF242B37).withValues(alpha: 0.9)
                    : null,
                child: Text(
                  '当天没有学习记录。',
                  style: TextStyle(
                    color: widget.isDarkMode
                        ? const Color(0xFFC2C8D6)
                        : AppColors.body,
                    height: 1.55,
                  ),
                ),
              )
            else
              for (final log in selectedDayLogs) ...[
                GlassCard(
                  color: widget.isDarkMode
                      ? const Color(0xFF242B37).withValues(alpha: 0.9)
                      : null,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0x197394F9),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              log.courseName,
                              style: const TextStyle(
                                color: Color(0xFF7394F9),
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
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
                            color: widget.isDarkMode
                                ? const Color(0xFFC2C8D6)
                                : AppColors.body,
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
        );
      },
    );
  }
}
