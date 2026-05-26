// AI weekly report polishing service.
// The first version uses local template polishing. Future cloud AI calls should
// go through the backend proxy so the app never stores model provider keys.

class AiReportService {
  const AiReportService();

  String polishReport(String content) {
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
