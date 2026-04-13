import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';
import '../models/report_definition.dart';

class ReportExportService {
  static Future<void> exportPdf({
    required BuildContext context,
    required ReportDefinition report,
    required List<Map<String, dynamic>> rows,
    required List<String> Function(Map<String, dynamic>) cellBuilder,
    DateTimeRange? dateRange,
  }) async {
    final pdf = pw.Document();
    final color = PdfColor.fromInt(report.category.color.toARGB32());
    final dateLabel = dateRange != null
        ? '${_fmt(dateRange.start)} – ${_fmt(dateRange.end)}'
        : 'All dates';

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        header: (_) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text('Omwa Sacco',
                    style: pw.TextStyle(
                        fontSize: 18,
                        fontWeight: pw.FontWeight.bold,
                        color: color)),
                pw.Text(_fmt(DateTime.now()),
                    style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey600)),
              ],
            ),
            pw.SizedBox(height: 4),
            pw.Text(report.title,
                style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
            pw.Text(report.description,
                style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700)),
            pw.Text('Period: $dateLabel',
                style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700)),
            pw.Divider(color: color),
            pw.SizedBox(height: 4),
          ],
        ),
        footer: (ctx) => pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text('${rows.length} record${rows.length == 1 ? '' : 's'}',
                style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey)),
            pw.Text('Page ${ctx.pageNumber} of ${ctx.pagesCount}',
                style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey)),
          ],
        ),
        build: (_) => [
          pw.TableHelper.fromTextArray(
            headers: report.columns,
            headerStyle: pw.TextStyle(
                fontWeight: pw.FontWeight.bold, fontSize: 10, color: PdfColors.white),
            headerDecoration: pw.BoxDecoration(color: color),
            cellStyle: const pw.TextStyle(fontSize: 9),
            cellAlignments: {for (var i = 0; i < report.columns.length; i++) i: pw.Alignment.centerLeft},
            rowDecoration: const pw.BoxDecoration(),
            oddRowDecoration: const pw.BoxDecoration(color: PdfColors.grey100),
            data: rows.map(cellBuilder).toList(),
            border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
            cellPadding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 4),
          ),
        ],
      ),
    );

    await Printing.layoutPdf(onLayout: (_) async => pdf.save());
  }

  static Future<void> exportCsv({
    required ReportDefinition report,
    required List<Map<String, dynamic>> rows,
    required List<String> Function(Map<String, dynamic>) cellBuilder,
  }) async {
    final buffer = StringBuffer();
    // Header
    buffer.writeln(report.columns.map(_csvEscape).join(','));
    // Rows
    for (final row in rows) {
      buffer.writeln(cellBuilder(row).map(_csvEscape).join(','));
    }

    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/${report.id}_${DateTime.now().millisecondsSinceEpoch}.csv');
    await file.writeAsString(buffer.toString());

    await Share.shareXFiles(
      [XFile(file.path, mimeType: 'text/csv')],
      subject: '${report.title} — Omwa Sacco',
    );
  }

  static String _csvEscape(String v) {
    if (v.contains(',') || v.contains('"') || v.contains('\n')) {
      return '"${v.replaceAll('"', '""')}"';
    }
    return v;
  }

  static String _fmt(DateTime d) => '${d.day}/${d.month}/${d.year}';
}
