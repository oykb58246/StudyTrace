import 'package:flutter_test/flutter_test.dart';
import 'package:studytrace/src/models/ai_app_action.dart';

void main() {
  group('aiAppActionTypeFromWire - 精确命名空间匹配', () {
    test('导航类精确匹配', () {
      expect(aiAppActionTypeFromWire('navigation.open_timer'),
          AiAppActionType.openTimer);
      expect(aiAppActionTypeFromWire('navigation.switch_tab'),
          AiAppActionType.switchTab);
      expect(aiAppActionTypeFromWire('navigation.open_dashboard'),
          AiAppActionType.openDashboard);
    });

    test('数据类精确匹配', () {
      expect(aiAppActionTypeFromWire('task.add'), AiAppActionType.addTask);
      expect(aiAppActionTypeFromWire('task.mark_status'),
          AiAppActionType.markTaskStatus);
      expect(aiAppActionTypeFromWire('log.create'), AiAppActionType.createLog);
      expect(aiAppActionTypeFromWire('note.save'), AiAppActionType.saveNote);
    });

    test('危险类精确匹配', () {
      expect(aiAppActionTypeFromWire('task.delete'),
          AiAppActionType.deleteTask);
      expect(aiAppActionTypeFromWire('note.overwrite'),
          AiAppActionType.overwriteNote);
      expect(aiAppActionTypeFromWire('auth.logout'), AiAppActionType.logout);
      expect(aiAppActionTypeFromWire('trash.empty'),
          AiAppActionType.emptyTrash);
    });

    test('Phase 2 扩展', () {
      expect(aiAppActionTypeFromWire('plan.generate_weekly'),
          AiAppActionType.generateWeeklyPlan);
      expect(aiAppActionTypeFromWire('note.from_log'),
          AiAppActionType.noteFromLog);
    });
  });

  group('aiAppActionTypeFromWire - 别名回退', () {
    test('无命名空间的 wire 字符串', () {
      expect(aiAppActionTypeFromWire('open_timer'), AiAppActionType.openTimer);
      expect(aiAppActionTypeFromWire('add_task'), AiAppActionType.addTask);
      expect(aiAppActionTypeFromWire('save_note'), AiAppActionType.saveNote);
    });

    test('中文别名', () {
      expect(aiAppActionTypeFromWire('生成周报'),
          AiAppActionType.openWeeklyReport);
      expect(aiAppActionTypeFromWire('系统设置'),
          AiAppActionType.openSystemSettings);
      expect(
          aiAppActionTypeFromWire('清空回收站'), AiAppActionType.emptyTrash);
    });

    test('同义词', () {
      expect(aiAppActionTypeFromWire('create_task'), AiAppActionType.addTask);
      expect(aiAppActionTypeFromWire('remove_task'),
          AiAppActionType.deleteTask);
      expect(aiAppActionTypeFromWire('update_note'),
          AiAppActionType.overwriteNote);
    });

    test('大小写/连字符不敏感', () {
      expect(aiAppActionTypeFromWire('Open-Timer'), AiAppActionType.openTimer);
      expect(aiAppActionTypeFromWire('ADD TASK'), AiAppActionType.addTask);
    });
  });

  group('aiAppActionTypeFromWire - 命名空间污染防护（历史 bug）', () {
    test('course.add 不应被解析为 add_task', () {
      // 曾经的 bug：剥离 course. 后剩 "add"，被别名映射到 add_task
      expect(aiAppActionTypeFromWire('course.add'), AiAppActionType.addCourse);
      expect(aiAppActionTypeFromWire('course.delete'),
          AiAppActionType.deleteCourse);
    });

    test('settings.set_dark_mode 不与 setSkin 混淆', () {
      expect(aiAppActionTypeFromWire('settings.set_dark_mode'),
          AiAppActionType.setDarkMode);
      expect(aiAppActionTypeFromWire('settings.set_skin'),
          AiAppActionType.setSkin);
    });

    test('flashcard.add 不应被误当 addFlashcard 以外的东西', () {
      expect(aiAppActionTypeFromWire('flashcard.add'),
          AiAppActionType.addFlashcard);
    });
  });

  group('aiAppActionTypeFromWire - 无法识别', () {
    test('完全未知返回 null', () {
      expect(aiAppActionTypeFromWire('nonsense.random'), isNull);
      expect(aiAppActionTypeFromWire('xyz'), isNull);
      expect(aiAppActionTypeFromWire(''), isNull);
    });
  });

  group('AiAppAction.tryParse - 额外字段合并到 sourceText', () {
    test('模型自造 time 字段被合并', () {
      final action = AiAppAction.tryParse({
        'type': 'settings.set_daily_reminder',
        'status': 'on',
        'time': '20:30',
      });
      expect(action, isNotNull);
      expect(action!.type, AiAppActionType.setDailyReminder);
      expect(action.sourceText, contains('time: 20:30'));
    });

    test('模型自造数组字段被 jsonEncode', () {
      final action = AiAppAction.tryParse({
        'type': 'task.add',
        'subTasks': ['a', 'b'],
      });
      expect(action, isNotNull);
      expect(action!.sourceText, contains('subTasks: ["a","b"]'));
    });

    test('未知 type 返回 null', () {
      final action = AiAppAction.tryParse({'type': 'unknown.action'});
      expect(action, isNull);
    });
  });

  group('aiAppActionTypeToWire - 双向一致性', () {
    test('所有枚举值都有对应 wire 字符串', () {
      for (final type in AiAppActionType.values) {
        final wire = aiAppActionTypeToWire(type);
        expect(wire, isNotEmpty, reason: '$type 缺少 wire 映射');
      }
    });
  });
}
