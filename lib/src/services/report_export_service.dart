import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../models/weekly_report_item.dart';
import 'platform_file_saver.dart';

class ReportExportService {
  const ReportExportService();

  Future<SavedExportFile> exportWeeklyReportMarkdown(
    WeeklyReportItem report,
  ) async {
    return saveExportFile(
      fileName: _reportFileName(report, extension: 'md'),
      mimeType: 'text/markdown;charset=utf-8',
      text: _markdownForReport(report),
    );
  }

  Future<SavedExportFile> exportWeeklyReportPdf(WeeklyReportItem report) async {
    final pdf = pw.Document();
    final title =
        '学习周报 ${_fmtDate(report.startDate)} - ${_fmtDate(report.endDate)}';
    final meta = '生成时间：${_fmtDateTime(report.createdAt)}  |  '
        '学习记录：${report.sourceLogIds.length} 条';
    final content = report.content.trim();

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(40),
        header: (ctx) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text('StudyTrace',
                    style: pw.TextStyle(
                        fontSize: 10,
                        color: PdfColor.fromHex('#7040F2'),
                        fontWeight: pw.FontWeight.bold)),
                pw.Text('学迹',
                    style: const pw.TextStyle(
                        fontSize: 10, color: PdfColors.grey600)),
              ],
            ),
            pw.SizedBox(height: 8),
            pw.Divider(thickness: 0.5, color: PdfColors.grey300),
            pw.SizedBox(height: 12),
          ],
        ),
        footer: (ctx) => pw.Container(
          alignment: pw.Alignment.centerRight,
          child: pw.Text(
            '第 ${ctx.pageNumber} / ${ctx.pagesCount} 页',
            style:
                const pw.TextStyle(fontSize: 9, color: PdfColors.grey500),
          ),
        ),
        build: (ctx) => [
          pw.Text(title,
              style: pw.TextStyle(
                  fontSize: 18, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 6),
          pw.Text(meta,
              style: const pw.TextStyle(
                  fontSize: 10, color: PdfColors.grey600)),
          pw.SizedBox(height: 16),
          // 按段落渲染
          ...content.split('\n').map((line) {
            final trimmed = line.trim();
            if (trimmed.isEmpty) return pw.SizedBox(height: 8);
            if (trimmed.startsWith('###')) {
              return pw.Padding(
                padding: const pw.EdgeInsets.only(top: 10, bottom: 4),
                child: pw.Text(
                  trimmed.replaceFirst(RegExp(r'^#+\s*'), ''),
                  style: pw.TextStyle(
                      fontSize: 13, fontWeight: pw.FontWeight.bold),
                ),
              );
            }
            if (trimmed.startsWith('##')) {
              return pw.Padding(
                padding: const pw.EdgeInsets.only(top: 12, bottom: 4),
                child: pw.Text(
                  trimmed.replaceFirst(RegExp(r'^#+\s*'), ''),
                  style: pw.TextStyle(
                      fontSize: 15, fontWeight: pw.FontWeight.bold),
                ),
              );
            }
            if (trimmed.startsWith('- ')) {
              return pw.Padding(
                padding: const pw.EdgeInsets.only(left: 12, bottom: 3),
                child: pw.Row(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text('• ', style: const pw.TextStyle(fontSize: 11)),
                    pw.Expanded(
                      child: pw.Text(trimmed.substring(2),
                          style: const pw.TextStyle(
                              fontSize: 11, lineSpacing: 3)),
                    ),
                  ],
                ),
              );
            }
            return pw.Padding(
              padding: const pw.EdgeInsets.only(bottom: 4),
              child: pw.Text(trimmed,
                  style: const pw.TextStyle(fontSize: 11, lineSpacing: 3)),
            );
          }),
        ],
      ),
    );

    final bytes = await pdf.save();
    return saveExportFile(
      fileName: _reportFileName(report, extension: 'pdf'),
      mimeType: 'application/pdf',
      bytes: bytes,
    );
  }

  Future<SavedExportFile> exportAllReportsMarkdown(
    List<WeeklyReportItem> reports,
  ) async {
    final now = DateTime.now();
    return saveExportFile(
      fileName: 'studytrace_all_reports_${_stampDateTime(now)}.md',
      mimeType: 'text/markdown;charset=utf-8',
      text: _markdownForReports(reports, exportedAt: now),
    );
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

extension _TakeLast on String {
  String takeLast(int count) {
    if (length <= count) return this;
    return substring(length - count);
  }
}
