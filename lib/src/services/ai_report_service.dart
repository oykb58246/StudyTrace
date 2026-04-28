// AI 周报润色服务
// 第一版使用本地模板润色，后续可接入 DeepSeek、OpenAI 或通义千问
// 接入方式：将 polishReport 方法内部替换为 HTTP API 调用

class AiReportService {
  const AiReportService();

  /// 对生成的周报进行 AI 润色
  /// [content] 原始周报文本
  /// 第一版返回模拟润色结果，后续改为调用真实 AI API
  String polishReport(String content) {
    // TODO: 接入真实 AI API
    // 示例：
    // final response = await http.post(
    //   Uri.parse('https://api.deepseek.com/v1/chat/completions'),
    //   headers: {'Authorization': 'Bearer $apiKey'},
    //   body: jsonEncode({
    //     'model': 'deepseek-chat',
    //     'messages': [{'role': 'user', 'content': '请润色以下周报：$content'}],
    //   }),
    // );

    // 第一版：简单的文本格式优化
    final lines = content.split('\n');
    final buffer = StringBuffer();

    for (final line in lines) {
      final trimmed = line.trim();
      if (trimmed.isEmpty) {
        buffer.writeln();
      } else if (trimmed.startsWith('###')) {
        buffer.writeln(trimmed);
        buffer.writeln();
      } else if (trimmed.startsWith('- ')) {
        buffer.writeln(trimmed);
      } else {
        buffer.writeln(trimmed);
      }
    }

    return buffer.toString().trim();
  }
}
