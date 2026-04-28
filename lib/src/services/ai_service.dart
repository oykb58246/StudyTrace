import '../models/analysis_item.dart';

class AiService {
  const AiService();

  Future<AnalysisItem> analyzeText(String text) async {
    final cleaned = text.trim();
    await Future<void>.delayed(const Duration(milliseconds: 420));
    return _mockAnalysis(cleaned, source: 'text');
  }

  Future<AnalysisItem> analyzeImageText(String ocrText) async {
    final cleaned = ocrText.trim();
    await Future<void>.delayed(const Duration(milliseconds: 520));
    return _mockAnalysis(cleaned, source: 'image');
  }

  AnalysisItem _mockAnalysis(String text, {required String source}) {
    final contentType = _detectType(text);
    final summary = _summaryFor(text, contentType, source);
    final keyPoints = _keyPointsFor(text, contentType);
    final suggestedActions = _actionsFor(contentType);

    return AnalysisItem(
      id: 'analysis_${DateTime.now().microsecondsSinceEpoch}',
      rawContent: text,
      contentType: contentType,
      summary: summary,
      keyPoints: keyPoints,
      suggestedActions: suggestedActions,
      createdAt: DateTime.now(),
    );
  }

  String _detectType(String text) {
    final lower = text.toLowerCase();
    if (_containsAny(text, const ['会议', '待办', '截止', '安排', '计划', '任务']) ||
        lower.contains('todo')) {
      return '任务';
    }
    if (_containsAny(text, const ['提醒', '通知', '日程', '明天', '今天', '后天'])) {
      return '通知';
    }
    if (_containsAny(text, const ['学习', '课程', '考试', '论文', '笔记', '复习'])) {
      return '学习';
    }
    if (_containsAny(text, const ['买', '订单', '快递', '购物', '优惠', '付款'])) {
      return '购物';
    }
    if (_containsAny(text, const ['微信', '聊天', '回复', '消息', '群里'])) {
      return '聊天';
    }
    return '其他';
  }

  bool _containsAny(String text, List<String> words) {
    return words.any(text.contains);
  }

  String _summaryFor(String text, String type, String source) {
    final preview = text.length > 56 ? '${text.substring(0, 56)}...' : text;
    final sourceLabel = source == 'image' ? '截图文字' : '输入内容';
    return '已将$sourceLabel识别为「$type」类信息，核心内容是：$preview';
  }

  List<String> _keyPointsFor(String text, String type) {
    final lines = text
        .split(RegExp(r'[\n。；;,.，]'))
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .take(3)
        .toList();
    if (lines.isNotEmpty) {
      return lines;
    }
    return [
      '内容类型：$type',
      '需要进一步整理为可执行事项',
      '建议保存到历史，方便后续回看',
    ];
  }

  List<String> _actionsFor(String type) {
    switch (type) {
      case '任务':
        return const ['创建待办并设置截止时间', '拆分为 3 个执行步骤', '完成后回到历史记录复盘'];
      case '通知':
        return const ['生成提醒事项', '同步到今日计划', '提前 30 分钟推送提示'];
      case '学习':
        return const ['整理学习摘要', '生成复习清单', '安排明晚 20:00 复习'];
      case '购物':
        return const ['提取商品和价格', '加入购物核对清单', '设置物流或付款提醒'];
      case '聊天':
        return const ['总结对话意图', '生成回复草稿', '标记需要跟进的人和时间'];
      default:
        return const ['保存分析结果', '转成待办事项', '生成下一步行动计划'];
    }
  }
}
