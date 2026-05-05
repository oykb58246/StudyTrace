import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:studytrace/app/app.dart';
import 'package:studytrace/src/controllers/app_data_controller.dart';
import 'package:studytrace/src/models/ai_flash_card.dart';
import 'package:studytrace/src/models/study_log_item.dart';
import 'package:studytrace/src/models/study_task_item.dart';

import 'package:studytrace/src/services/weekly_report_service.dart';
import 'package:studytrace/src/ui/shell/app_shell.dart';
import 'package:studytrace/src/ui/shell/navigation_models.dart';
import 'package:studytrace/src/ui/study/flash_card_page.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('app flows from welcome to main shell',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const MyApp());
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 800));

    expect(find.byKey(const Key('landing_title')), findsOneWidget);
    expect(find.byKey(const Key('splash_primary_button')), findsOneWidget);

    await tester.tap(find.byKey(const Key('splash_primary_button')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 1700));

    expect(find.byKey(const Key('login_email_field')), findsOneWidget);
    expect(find.byKey(const Key('login_password_field')), findsOneWidget);

    await tester.enterText(
      find.byKey(const Key('login_email_field')),
      'demo@studytrace.ai',
    );
    await tester.enterText(
      find.byKey(const Key('login_password_field')),
      '12345678',
    );

    await tester.tap(find.byKey(const Key('splash_primary_button')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 2600));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('page_home')), findsOneWidget);
  });

  testWidgets('shell renders each primary tab with expected content',
      (WidgetTester tester) async {
    Future<void> pumpShell(PrimaryTab tab) async {
      await tester.pumpWidget(
        MaterialApp(
          home: AppShell(
            key: ValueKey(tab),
            debugInitialPrimaryTab: tab,
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    await pumpShell(PrimaryTab.scenarios);
    expect(find.byKey(const Key('page_study_logs')), findsOneWidget);

    await pumpShell(PrimaryTab.create);
    expect(find.byKey(const Key('page_study_tasks')), findsOneWidget);

    await pumpShell(PrimaryTab.profile);
    expect(find.byKey(const Key('page_course_archive')), findsOneWidget);
  });

  testWidgets('shell renders admin section page', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      const MaterialApp(
        home: AppShell(
          debugMenuInitiallyOpen: true,
          debugInitialAdminSection: AdminSection.overview,
        ),
      ),
    );
    await tester.pumpAndSettle();

    final transformWidget = tester.widget<Transform>(
      find.byKey(const Key('shell_front_transform')),
    );
    expect(transformWidget.transform.isIdentity(), isFalse);

    expect(find.text('BROWSE'), findsOneWidget);
    expect(find.byKey(const Key('admin_title_overview')), findsOneWidget);
  });

  test('add study task and retrieve from controller', () async {
    final controller = AppDataController();
    await controller.load();

    final task = await controller.addStudyTask(
      title: '完成第三章习题',
      type: StudyTaskType.programmingHomework,
      courseName: '高等数学',
      deadline: DateTime(2026, 5, 10),
      status: StudyTaskStatus.notStarted,
      note: '重点复习积分部分',
    );

    expect(controller.studyTasks, hasLength(1));
    expect(controller.studyTasks.first.title, '完成第三章习题');
    expect(controller.studyTasks.first.courseName, '高等数学');

    await controller.updateStudyTaskStatus(
      task.id,
      StudyTaskStatus.inProgress,
    );
    expect(
      controller.studyTasks.first.status,
      StudyTaskStatus.inProgress,
    );

    await controller.updateStudyTaskStatus(
      task.id,
      StudyTaskStatus.completed,
    );
    expect(
      controller.studyTasks.first.status,
      StudyTaskStatus.completed,
    );

    await controller.deleteStudyTask(task.id);
    expect(controller.studyTasks, isEmpty);
  });

  test('add study log and retrieve from controller', () async {
    final controller = AppDataController();
    await controller.load();

    await controller.addStudyLog(
      date: DateTime(2026, 4, 27),
      courseName: '高等数学',
      content: '完成了第三章积分习题',
      problems: '分部积分法掌握不牢',
      thoughts: '需要多做练习',
      nextPlan: '明天复习定积分',
    );

    expect(controller.studyLogs, hasLength(1));
    expect(controller.studyLogs.first.courseName, '高等数学');

    final logId = controller.studyLogs.first.id;
    await controller.deleteStudyLog(logId);
    expect(controller.studyLogs, isEmpty);
  });

  test('weekly report generation and save', () {
    const service = WeeklyReportService();
    final logs = [
      StudyLogItem(
        id: 'log_1',
        date: DateTime(2026, 4, 25),
        courseName: '高等数学',
        content: '学习了积分',
        problems: '有点难',
        thoughts: '多练习',
        nextPlan: '继续',
        createdAt: DateTime(2026, 4, 25),
      ),
    ];
    final tasks = [
      StudyTaskItem(
        id: 'task_1',
        title: '完成作业',
        type: StudyTaskType.programmingHomework,
        courseName: '高等数学',
        deadline: DateTime(2026, 4, 28),
        status: StudyTaskStatus.completed,
        note: '',
        createdAt: DateTime(2026, 4, 20),
        updatedAt: DateTime(2026, 4, 20),
      ),
    ];

    final report = service.generate(
      startDate: DateTime(2026, 4, 21),
      endDate: DateTime(2026, 4, 27),
      logs: logs,
      tasks: tasks,
    );

    expect(report.contains('学习周报'), isTrue);
    expect(report.contains('本周学习内容'), isTrue);
    expect(report.contains('本周完成进度'), isTrue);
    expect(report.contains('遇到的问题'), isTrue);
    expect(report.contains('思考与收获'), isTrue);
    expect(report.contains('下周学习计划'), isTrue);
    expect(report.contains('高等数学'), isTrue);
  });

  test('controller generates and saves weekly report', () async {
    final controller = AppDataController();
    await controller.load();

    // Add a study log
    await controller.addStudyLog(
      date: DateTime(2026, 4, 25),
      courseName: '线性代数',
      content: '学习了矩阵运算',
    );

    final content = controller.generateWeeklyReportContent(
      startDate: DateTime(2026, 4, 21),
      endDate: DateTime(2026, 4, 27),
    );

    expect(content.contains('学习周报'), isTrue);

    await controller.saveWeeklyReport(
      content,
      startDate: DateTime(2026, 4, 21),
      endDate: DateTime(2026, 4, 27),
    );

    expect(controller.weeklyReports, hasLength(1));
    expect(controller.weeklyReports.first.content, content);
  });

  test('data persists across controller reloads', () async {
    var controller = AppDataController();
    await controller.load();

    await controller.addStudyTask(
      title: '持久化测试任务',
      type: StudyTaskType.labReport,
      courseName: '物理实验',
      deadline: DateTime(2026, 6, 1),
    );

    await controller.addStudyLog(
      date: DateTime(2026, 4, 27),
      courseName: '物理实验',
      content: '完成了实验报告',
    );

    final reportContent = controller.generateWeeklyReportContent(
      startDate: DateTime(2026, 4, 21),
      endDate: DateTime(2026, 4, 27),
    );
    await controller.saveWeeklyReport(
      reportContent,
      startDate: DateTime(2026, 4, 21),
      endDate: DateTime(2026, 4, 27),
    );

    // Reload
    controller = AppDataController();
    await controller.load();

    expect(controller.studyTasks, hasLength(1));
    expect(controller.studyLogs, hasLength(1));
    expect(controller.weeklyReports, hasLength(1));
  });

  test('course names are aggregated from tasks and logs', () async {
    final controller = AppDataController();
    await controller.load();

    await controller.addStudyTask(
      title: '任务A',
      type: StudyTaskType.classHomework,
      courseName: '高等数学',
      deadline: DateTime(2026, 5, 10),
    );

    await controller.addStudyLog(
      date: DateTime(2026, 4, 27),
      courseName: '线性代数',
      content: '矩阵运算',
    );

    await controller.addStudyLog(
      date: DateTime(2026, 4, 26),
      courseName: '高等数学',
      content: '积分复习',
    );

    final courses = controller.courseNames;
    expect(courses, contains('高等数学'));
    expect(courses, contains('线性代数'));
    expect(courses.length, 2);

    final mathTasks = controller.tasksForCourse('高等数学');
    expect(mathTasks, hasLength(1));

    final mathLogs = controller.logsForCourse('高等数学');
    expect(mathLogs, hasLength(1));
  });

  testWidgets('flash card page groups by date and merges short final shelf',
      (WidgetTester tester) async {
    final controller = AppDataController();
    final date = DateTime(2026, 4, 28);
    await controller.saveFlashCards(_flashCards(10, date: date));

    await _pumpFlashCards(tester, controller);

    expect(find.byKey(const Key('flash_card_date_group_2026-04-28')),
        findsOneWidget);
    expect(
        find.byKey(const Key('flash_card_shelf_2026-04-28_0')), findsOneWidget);
    expect(
        find.byKey(const Key('flash_card_shelf_2026-04-28_1')), findsNothing);
    expect(find.byKey(const Key('flash_card_mini_card_10')), findsOneWidget);
  });

  testWidgets('flash card page splits shelves after eight cards',
      (WidgetTester tester) async {
    final controller = AppDataController();
    final date = DateTime(2026, 4, 28);
    await controller.saveFlashCards(_flashCards(11, date: date));

    await _pumpFlashCards(tester, controller);

    expect(
        find.byKey(const Key('flash_card_shelf_2026-04-28_0')), findsOneWidget);
    expect(
        find.byKey(const Key('flash_card_shelf_2026-04-28_1')), findsOneWidget);
  });

  testWidgets('flash card page toggles star and manages groups',
      (WidgetTester tester) async {
    final controller = AppDataController();
    final date = DateTime(2026, 4, 28);
    await controller.saveFlashCards([
      AiFlashCard(
        id: 'target',
        question: '待分组卡',
        answer: '答案',
        createdAt: date,
      ),
      AiFlashCard(
        id: 'group_source',
        question: '已有分组卡',
        answer: '答案',
        groupName: '复习组',
        createdAt: date,
      ),
    ]);

    await _pumpFlashCards(tester, controller);

    await tester.tap(find.byKey(const Key('flash_card_star_target')));
    await tester.pump(const Duration(milliseconds: 120));
    expect(
      controller.flashCards.firstWhere((c) => c.id == 'target').isStarred,
      isTrue,
    );

    await tester.tap(find.byKey(const Key('flash_card_group_menu_target')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('flash_card_group_option_复习组')));
    await tester.pump(const Duration(seconds: 1));
    expect(
      controller.flashCards.firstWhere((c) => c.id == 'target').groupName,
      '复习组',
    );

    await tester.tap(find.byKey(const Key('flash_card_group_menu_target')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('flash_card_group_option_new')));
    await tester.pump(const Duration(seconds: 1));
    await tester.enterText(
      find.byKey(const Key('flash_card_new_group_field')),
      '考前冲刺',
    );
    await tester.tap(find.byKey(const Key('flash_card_create_group_button')));
    await tester.pump(const Duration(seconds: 1));
    expect(
      controller.flashCards.firstWhere((c) => c.id == 'target').groupName,
      '考前冲刺',
    );

    await tester.tap(find.byKey(const Key('flash_card_group_menu_target')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('flash_card_group_option_remove')));
    await tester.pump(const Duration(seconds: 1));
    expect(
      controller.flashCards.firstWhere((c) => c.id == 'target').groupName,
      isEmpty,
    );
  });

  testWidgets('tapping a mini flash card opens scoped browse mode',
      (WidgetTester tester) async {
    final controller = AppDataController();
    final date = DateTime(2026, 4, 28);
    await controller.saveFlashCards(_flashCards(3, date: date));

    await _pumpFlashCards(tester, controller);
    await tester.tap(find.byKey(const Key('flash_card_mini_card_2')));
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('闪卡浏览'), findsOneWidget);
    expect(find.text('2 / 3'), findsOneWidget);
    expect(find.text('问题 2'), findsOneWidget);
  });
}

List<AiFlashCard> _flashCards(int count, {required DateTime date}) {
  return List.generate(
    count,
    (i) => AiFlashCard(
      id: 'card_${i + 1}',
      question: '问题 ${i + 1}',
      answer: '答案 ${i + 1}',
      courseName: '高等数学',
      createdAt: date.add(Duration(minutes: i)),
    ),
  );
}

Future<void> _pumpFlashCards(
  WidgetTester tester,
  AppDataController controller,
) async {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(
    MaterialApp(
      home: FlashCardPage(
        isDarkMode: false,
        controller: controller,
        autoGenerate: false,
      ),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 120));
}
