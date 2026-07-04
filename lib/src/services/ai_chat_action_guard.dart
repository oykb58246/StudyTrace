import '../models/ai_app_action.dart';

class AiChatActionGuard {
  const AiChatActionGuard._();

  static List<AiAppAction> withFallbackNoteAction({
    required String input,
    required String assistantReply,
    required List<AiAppAction> actions,
  }) {
    if (hasNoteCreationAction(actions) ||
        !looksLikeNoteCreationRequest(input) ||
        !looksLikeSavableNoteReply(assistantReply, input)) {
      return actions;
    }
    return [
      ...actions,
      AiAppAction(
        type: AiAppActionType.saveNote,
        title: noteTitleFromInput(input),
        content: assistantReply.trim(),
      ),
    ];
  }

  static bool hasNoteCreationAction(List<AiAppAction> actions) {
    return actions.any((action) {
      return switch (action.type) {
        AiAppActionType.saveNote ||
        AiAppActionType.noteFromLog ||
        AiAppActionType.noteFromOcr ||
        AiAppActionType.summarizeStarredCards =>
          true,
        _ => false,
      };
    });
  }

  static bool looksLikeNoteCreationRequest(String input) {
    final text = input.trim();
    if (text.isEmpty) return false;
    if (RegExp(r'(不要|不用|别|先别|无需).{0,8}(保存|生成|制作|创建|整理).{0,8}笔记')
        .hasMatch(text)) {
      return false;
    }
    return RegExp(
          r'(生成|制作|制作为|保存|创建|新建|整理成|做成|写成|产出|转成).{0,16}(笔记|学习笔记|课堂笔记|复习笔记)',
        ).hasMatch(text) ||
        RegExp(
          r'(笔记|学习笔记|课堂笔记|复习笔记).{0,16}(生成|制作|保存|创建|新建|整理|做成|写成|产出|转成)',
        ).hasMatch(text);
  }

  static bool looksLikeSavableNoteReply(String reply, String input) {
    final text = reply.trim();
    if (text.length < 32) return false;
    if (text == input.trim()) return false;
    if (isGenericAssistantReply(text)) return false;
    return RegExp(r'(^|\n)#{1,6}\s').hasMatch(text) ||
        RegExp(r'\n\s*([-*•]|\d+[.)、])\s').hasMatch(text) ||
        (text.length >= 80 && RegExp(r'[\n。；;：:]').hasMatch(text));
  }

  static bool isGenericAssistantReply(String reply) {
    final text = reply.trim();
    if (text.length >= 120) return false;
    return RegExp(r'^(可以|好的|好，我|我来|请提供|无法|抱歉|暂时|没法|不能)').hasMatch(text);
  }

  static String noteTitleFromInput(String input) {
    var topic = input
        .replaceAll(
          RegExp(
            r'帮我|请|生成|制作|制作为|保存|创建|新建|整理成|整理|做成|写成|写|产出|转成|一个|一份|一篇|详细的|详细|完整的|完整|学习笔记|课堂笔记|复习笔记|笔记',
          ),
          '',
        )
        .replaceAll(RegExp(r'[\s，。！？!?:：、；;#*\-]+'), '')
        .trim();
    if (topic.length > 18) {
      topic = topic.substring(0, 18);
    }
    return '${topic.isEmpty ? '学习' : topic}笔记';
  }

  static bool shouldStopAfterSafeActions(List<AiActionResult> results) {
    return results.any(
      (result) =>
          isMediaAction(result.action.type) ||
          (result.success && isTerminalSafeAction(result.action.type)),
    );
  }

  static bool isAlreadyHandledAgentAction(
    AiAppAction action,
    List<AiActionResult> previousResults,
  ) {
    return previousResults.any((result) {
      final equivalent = areEquivalentAgentActions(result.action, action);
      if (!equivalent) return false;
      if (isMediaAction(action.type)) {
        return result.success || (result.createdId?.trim().isNotEmpty ?? false);
      }
      return result.success;
    });
  }

  static bool areEquivalentAgentActions(AiAppAction left, AiAppAction right) {
    return left.type == right.type &&
        (left.targetId ?? '') == (right.targetId ?? '') &&
        (left.targetTitle ?? '') == (right.targetTitle ?? '') &&
        (left.status ?? '') == (right.status ?? '') &&
        (left.title ?? '') == (right.title ?? '') &&
        (left.content ?? '') == (right.content ?? '') &&
        (left.sourceText ?? '') == (right.sourceText ?? '');
  }

  static bool isTerminalSafeAction(AiAppActionType type) {
    return switch (type) {
      AiAppActionType.saveNote ||
      AiAppActionType.noteFromLog ||
      AiAppActionType.noteFromOcr ||
      AiAppActionType.addTask ||
      AiAppActionType.addTaskDirect ||
      AiAppActionType.createLog ||
      AiAppActionType.createLoopFromSource ||
      AiAppActionType.createFlashcardBatch ||
      AiAppActionType.generateTodayMission ||
      AiAppActionType.generateTodayFlashcards ||
      AiAppActionType.generateWeeklyPlan ||
      AiAppActionType.generateImage ||
      AiAppActionType.refreshImage ||
      AiAppActionType.generateVideo ||
      AiAppActionType.refreshVideo =>
        true,
      _ => false,
    };
  }

  static bool isMediaAction(AiAppActionType type) {
    return switch (type) {
      AiAppActionType.generateImage ||
      AiAppActionType.refreshImage ||
      AiAppActionType.generateVideo ||
      AiAppActionType.refreshVideo =>
        true,
      _ => false,
    };
  }
}
