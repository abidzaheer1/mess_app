import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../utils/currency_format.dart';
import 'monthly_settlement.dart';

Future<Uint8List> buildSettlementPdf({
  required MonthlySettlementReport report,
  required String messName,
  String? currencyCode,
}) async {
  final doc = pw.Document();
  final title = settlementMonthLabel(report.month);

  doc.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(32),
      build: (context) => [
        pw.Text('Alpha Mess — Monthly Settlement', style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold)),
        pw.SizedBox(height: 4),
        pw.Text('$messName · $title', style: const pw.TextStyle(fontSize: 12)),
        pw.SizedBox(height: 16),
        pw.Text(
          report.isFinalized ? 'Status: Finalized' : 'Status: In progress (preview)',
          style: pw.TextStyle(fontSize: 11, color: PdfColors.grey700),
        ),
        pw.SizedBox(height: 20),
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            _metric('Total spent', formatMessMoney(report.totalSpent, currencyCode: currencyCode)),
            _metric('Per person share', formatMessMoney(report.perPersonShare, currencyCode: currencyCode)),
            _metric('Members', '${report.members.length}'),
          ],
        ),
        pw.SizedBox(height: 24),
        pw.Text('Member breakdown', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
        pw.SizedBox(height: 8),
        pw.Table.fromTextArray(
          headers: const ['Member', 'Paid', 'Share', 'Net', 'Pays admin', 'Admin pays back'],
          data: report.lines.map((l) {
            return [
              l.member.displayName,
              formatMessMoney(l.paid, currencyCode: currencyCode),
              formatMessMoney(l.share, currencyCode: currencyCode),
              formatMessMoney(l.net, currencyCode: currencyCode),
              l.owesAdmin > 0 ? formatMessMoney(l.owesAdmin, currencyCode: currencyCode) : '—',
              l.adminOwes > 0 ? formatMessMoney(l.adminOwes, currencyCode: currencyCode) : '—',
            ];
          }).toList(),
          headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
          cellAlignment: pw.Alignment.centerLeft,
        ),
        pw.SizedBox(height: 24),
        pw.Text('Expenses (${report.expenses.length})', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
        pw.SizedBox(height: 8),
        pw.Table.fromTextArray(
          headers: const ['Date', 'Title', 'Paid by', 'Amount'],
          data: report.expenses.map((e) {
            final dt = e.expenseDateParsed ?? DateTime.fromMillisecondsSinceEpoch(e.createdAt);
            return [
              '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}',
              e.title,
              e.paidByName,
              formatMessMoney(e.amount, currencyCode: currencyCode),
            ];
          }).toList(),
          headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
        ),
      ],
    ),
  );

  return doc.save();
}

pw.Widget _metric(String label, String value) {
  return pw.Column(
    crossAxisAlignment: pw.CrossAxisAlignment.start,
    children: [
      pw.Text(label, style: pw.TextStyle(fontSize: 9, color: PdfColors.grey700)),
      pw.SizedBox(height: 4),
      pw.Text(value, style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold)),
    ],
  );
}
