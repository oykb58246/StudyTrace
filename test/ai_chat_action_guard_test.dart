import 'package:flutter_test/flutter_test.dart';
import 'package:studytrace/src/models/ai_app_action.dart';
import 'package:studytrace/src/services/ai_chat_action_guard.dart';

void main() {
  group('AiChatActionGuard - media generation', () {
    test('stops after a media task is created even before a URL is ready', () {
      const action = AiAppAction(
        type: AiAppActionType.generateImage,
        sourceText: '生成一张高数极限图解',
      );
      const result = AiActionResult(
        action: action,
        success: false,
        message: '图片任务已创建，稍后刷新查看结果',
        createdId: 'img_task_1',
      );

      expect(AiChatActionGuard.shouldStopAfterSafeActions([result]), isTrue);
      expect(
        AiChatActionGuard.isAlreadyHandledAgentAction(action, [result]),
        isTrue,
      );
    });
  });

  group('AiChatActionGuard - note fallback', () {
    test('adds saveNote action for explicit note creation requests', () {
      const reply = '# 牛顿第二定律\n\n- 核心公式：F = ma。\n- 适用条件：宏观低速情境。';

      final actions = AiChatActionGuard.withFallbackNoteAction(
        input: '帮我制作笔记：牛顿第二定律的公式、适用条件和例题思路',
        assistantReply: reply,
        actions: const [],
      );

      expect(actions, hasLength(1));
      expect(actions.single.type, AiAppActionType.saveNote);
      expect(actions.single.title, contains('笔记'));
      expect(actions.single.content, reply);
    });

    test('does not add saveNote when a note action already exists', () {
      const existing = AiAppAction(
        type: AiAppActionType.saveNote,
        title: '已有笔记',
        content: '# 已有内容',
      );

      final actions = AiChatActionGuard.withFallbackNoteAction(
        input: '帮我制作笔记：牛顿第二定律',
        assistantReply: '# 牛顿第二定律\n\n- F = ma',
        actions: const [existing],
      );

      expect(actions, hasLength(1));
      expect(actions.single, same(existing));
    });

    test('does not save generic conversational replies as notes', () {
      final actions = AiChatActionGuard.withFallbackNoteAction(
        input: '帮我制作笔记：牛顿第二定律',
        assistantReply: '可以，我来帮你整理。',
        actions: const [],
      );

      expect(actions, isEmpty);
    });
  });
}
