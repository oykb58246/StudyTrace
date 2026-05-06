import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

import '../models/weekly_report_item.dart';

class ReportExportService {
  const ReportExportService();

  Future<File> exportWeeklyReportMarkdown(WeeklyReportItem report) async {
    final dir = await _exportDirectory();
    final file = File('${dir.path}${Platform.pathSeparator}'
        '${_reportFileName(report, extension: 'md')}');
    await file.writeAsString(_markdownForReport(report), encoding: utf8);
    return file;
  }

  Future<File> exportWeeklyReportPdf(WeeklyReportItem report) async {
    final dir = await _exportDirectory();
    final file = File('${dir.path}${Platform.pathSeparator}'
        '${_reportFileName(report, extension: 'pdf')}');
    final bytes = _SimplePdfTextWriter(
      title: '学习周报 ${_fmtDate(report.startDate)} - ${_fmtDate(report.endDate)}',
      body: [
        '生成时间：${_fmtDateTime(report.createdAt)}',
        '学习记录：${report.sourceLogIds.length} 条',
        '',
        report.content.trim(),
      ].join('\n'),
    ).build();
    await file.writeAsBytes(bytes, flush: true);
    return file;
  }

  Future<File> exportAllReportsMarkdown(List<WeeklyReportItem> reports) async {
    final dir = await _exportDirectory();
    final now = DateTime.now();
    final file = File('${dir.path}${Platform.pathSeparator}'
        'studytrace_all_reports_${_stampDateTime(now)}.md');
    await file.writeAsString(
      _markdownForReports(reports, exportedAt: now),
      encoding: utf8,
    );
    return file;
  }

  Future<Directory> _exportDirectory() async {
    final base = await getApplicationDocumentsDirectory();
    final dir =
        Directory('${base.path}${Platform.pathSeparator}studytrace_exports');
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  String _markdownForReport(WeeklyReportItem report) {
    return [
      '# 学习周报 ${_fmtDate(report.startDate)} - ${_fmtDate(report.endDate)}',
      '',
      '生成时间：${_fmtDateTime(report.createdAt)}',
      '学习记录：${report.sourceLogIds.length} 条',
      '',
      report.content.trim(),
      '',
    ].join('\n');
  }

  String _markdownForReports(
    List<WeeklyReportItem> reports, {
    required DateTime exportedAt,
  }) {
    final buffer = StringBuffer()
      ..writeln('# StudyTrace 历史周报')
      ..writeln()
      ..writeln('导出时间：${_fmtDateTime(exportedAt)}')
      ..writeln('周报数量：${reports.length}')
      ..writeln();

    for (final report in reports) {
      buffer
        ..writeln('## ${_fmtDate(report.startDate)} - ${_fmtDate(report.endDate)}')
        ..writeln()
        ..writeln('生成时间：${_fmtDateTime(report.createdAt)}')
        ..writeln('学习记录：${report.sourceLogIds.length} 条')
        ..writeln()
        ..writeln(report.content.trim())
        ..writeln();
    }
    return buffer.toString();
  }

  String _reportFileName(WeeklyReportItem report, {required String extension}) {
    final idPart = _safeFilePart(report.id).takeLast(8);
    return 'studytrace_report_${_stampDate(report.startDate)}_'
        '${_stampDate(report.endDate)}_$idPart.$extension';
  }

  String _safeFilePart(String value) {
    return value.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_');
  }

  String _fmtDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-'
        '${date.day.toString().padLeft(2, '0')}';
  }

  String _fmtDateTime(DateTime date) {
    return '${_fmtDate(date)} ${date.hour.toString().padLeft(2, '0')}:'
        '${date.minute.toString().padLeft(2, '0')}';
  }

  String _stampDate(DateTime date) {
    return '${date.year}${date.month.toString().padLeft(2, '0')}'
        '${date.day.toString().padLeft(2, '0')}';
  }

  String _stampDateTime(DateTime date) {
    return '${_stampDate(date)}_${date.hour.toString().padLeft(2, '0')}'
        '${date.minute.toString().padLeft(2, '0')}'
        '${date.second.toString().padLeft(2, '0')}';
  }
}

class _SimplePdfTextWriter {
  _SimplePdfTextWriter({
    required this.title,
    required this.body,
  });

  static const double _pageWidth = 595;
  static const double _pageHeight = 842;
  static const double _marginX = 56;
  static const double _topY = 790;
  static const double _bottomY = 56;

  final String title;
  final String body;

  List<int> build() {
    final pages = _paginate(_buildLines());
    final objects = <int, List<int>>{};
    final pageIds = <int>[];

    objects[1] = ascii.encode('<< /Type /Catalog /Pages 2 0 R >>');
    objects[3] = ascii.encode(_fontObject());

    for (var i = 0; i < pages.length; i++) {
      final pageId = 4 + i * 2;
      final contentId = pageId + 1;
      pageIds.add(pageId);
      final content = ascii.encode(_contentStream(pages[i]));
      objects[pageId] = ascii.encode(
        '<< /Type /Page /Parent 2 0 R /MediaBox [0 0 $_pageWidth $_pageHeight] '
        '/Resources << /Font << /F1 3 0 R >> >> /Contents $contentId 0 R >>',
      );
      objects[contentId] = [
        ...ascii.encode('<< /Length ${content.length} >>\nstream\n'),
        ...content,
        ...ascii.encode('\nendstream'),
      ];
    }

    objects[2] = ascii.encode(
      '<< /Type /Pages /Kids [${pageIds.map((id) => '$id 0 R').join(' ')}] '
      '/Count ${pageIds.length} >>',
    );

    return _pdfBytes(objects);
  }

  List<_PdfLine> _buildLines() {
    return [
      for (final line in _wrapText(title, maxChars: 24))
        _PdfLine(line, fontSize: 16, lineHeight: 24),
      const _PdfLine('', fontSize: 11, lineHeight: 12),
      for (final paragraph in body.split('\n')) ...[
        if (paragraph.trim().isEmpty)
          const _PdfLine('', fontSize: 11, lineHeight: 12)
        else
          for (final line in _wrapText(paragraph.trim(), maxChars: 38))
            _PdfLine(line, fontSize: 11, lineHeight: 17),
      ],
    ];
  }

  List<List<_PdfLine>> _paginate(List<_PdfLine> lines) {
    final pages = <List<_PdfLine>>[];
    var current = <_PdfLine>[];
    var y = _topY;

    for (final line in lines) {
      if (current.isNotEmpty && y - line.lineHeight < _bottomY) {
        pages.add(current);
        current = <_PdfLine>[];
        y = _topY;
      }
      current.add(line);
      y -= line.lineHeight;
    }
    if (current.isNotEmpty) pages.add(current);
    return pages.isEmpty ? [const <_PdfLine>[]] : pages;
  }

  List<String> _wrapText(String text, {required int maxChars}) {
    final normalized = text.replaceAll('\t', ' ').trimRight();
    if (normalized.isEmpty) return const [''];

    final lines = <String>[];
    final buffer = StringBuffer();
    var width = 0;

    for (final rune in normalized.runes) {
      final char = String.fromCharCode(rune);
      final charWidth = rune < 128 ? 1 : 2;
      if (buffer.isNotEmpty && width + charWidth > maxChars * 2) {
        lines.add(buffer.toString().trimRight());
        buffer.clear();
        width = 0;
      }
      buffer.write(char);
      width += charWidth;
    }
    if (buffer.isNotEmpty) lines.add(buffer.toString().trimRight());
    return lines;
  }

  String _contentStream(List<_PdfLine> lines) {
    final buffer = StringBuffer()..writeln('q');
    var y = _topY;
    for (final line in lines) {
      if (line.text.isNotEmpty) {
        buffer
          ..writeln('BT')
          ..writeln('/F1 ${line.fontSize} Tf')
          ..writeln('1 0 0 1 $_marginX ${y.toStringAsFixed(1)} Tm')
          ..writeln('<${_utf16Hex(line.text)}> Tj')
          ..writeln('ET');
      }
      y -= line.lineHeight;
    }
    buffer.writeln('Q');
    return buffer.toString();
  }

  String _utf16Hex(String text) {
    final buffer = StringBuffer('FEFF');
    for (final codeUnit in text.codeUnits) {
      buffer.write(codeUnit.toRadixString(16).padLeft(4, '0').toUpperCase());
    }
    return buffer.toString();
  }

  String _fontObject() {
    return '''
<< /Type /Font
/Subtype /Type0
/BaseFont /STSong-Light
/Encoding /UniGB-UCS2-H
/DescendantFonts [
<< /Type /Font
/Subtype /CIDFontType0
/BaseFont /STSong-Light
/CIDSystemInfo << /Registry (Adobe) /Ordering (GB1) /Supplement 2 >>
/FontDescriptor << /Type /FontDescriptor /FontName /STSong-Light /Flags 6 /FontBBox [-25 -254 1000 880] /ItalicAngle 0 /Ascent 880 /Descent -120 /CapHeight 880 /StemV 80 >>
>>
]
>>''';
  }

  List<int> _pdfBytes(Map<int, List<int>> objects) {
    final maxObjectId = objects.keys.reduce((a, b) => a > b ? a : b);
    final bytes = <int>[];
    final offsets = List<int>.filled(maxObjectId + 1, 0);

    bytes.addAll(ascii.encode('%PDF-1.4\n'));
    bytes.addAll([0x25, 0xE2, 0xE3, 0xCF, 0xD3, 0x0A]);

    for (var id = 1; id <= maxObjectId; id++) {
      final object = objects[id];
      if (object == null) continue;
      offsets[id] = bytes.length;
      bytes.addAll(ascii.encode('$id 0 obj\n'));
      bytes.addAll(object);
      bytes.addAll(ascii.encode('\nendobj\n'));
    }

    final xrefOffset = bytes.length;
    bytes.addAll(ascii.encode('xref\n0 ${maxObjectId + 1}\n'));
    bytes.addAll(ascii.encode('0000000000 65535 f \n'));
    for (var id = 1; id <= maxObjectId; id++) {
      bytes.addAll(
        ascii.encode('${offsets[id].toString().padLeft(10, '0')} 00000 n \n'),
      );
    }
    bytes.addAll(
      ascii.encode(
        'trailer\n<< /Size ${maxObjectId + 1} /Root 1 0 R >>\n'
        'startxref\n$xrefOffset\n%%EOF',
      ),
    );
    return bytes;
  }
}

class _PdfLine {
  const _PdfLine(
    this.text, {
    required this.fontSize,
    required this.lineHeight,
  });

  final String text;
  final int fontSize;
  final double lineHeight;
}

extension _TakeLast on String {
  String takeLast(int count) {
    if (length <= count) return this;
    return substring(length - count);
  }
}
