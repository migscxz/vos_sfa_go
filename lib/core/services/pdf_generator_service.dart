import 'dart:io';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';

class PdfGeneratorService {
  Future<File> generateCallsheetPdf({
    required String customerName,
    required String customerCode,
    required List<String> dates,
    required List<Map<String, dynamic>> products,
  }) async {
    final pdf = pw.Document();

    // Define format
    final headerStyle = pw.TextStyle(
      fontWeight: pw.FontWeight.bold,
      fontSize: 10,
    );
    final cellStyle = const pw.TextStyle(fontSize: 9);
    final smallStyle = const pw.TextStyle(fontSize: 8);

    // Build Table Columns
    final tableHeaders = <pw.Widget>[
      pw.Text('PRODUCT', style: headerStyle),
      pw.Padding(
        padding: const pw.EdgeInsets.only(right: 8.0),
        child: pw.Align(
          alignment: pw.Alignment.centerRight,
          child: pw.Text('PRICE', style: headerStyle),
        ),
      ),
    ];

    // Date Headers
    for (var date in dates) {
      String displayDate = date;
      try {
        final dt = DateTime.parse(date);
        displayDate = DateFormat('MM/dd').format(dt);
      } catch (_) {}

      tableHeaders.add(
        pw.Column(
          children: [
            pw.Text(displayDate, style: headerStyle),
            pw.SizedBox(height: 2),
            pw.Divider(color: PdfColors.grey400, thickness: 0.5),
            pw.Row(
              children: [
                pw.Expanded(
                  child: pw.Center(child: pw.Text('Qty', style: smallStyle)),
                ),
                pw.Container(width: 0.5, height: 10, color: PdfColors.grey400),
                pw.Expanded(
                  child: pw.Center(child: pw.Text('Inv', style: smallStyle)),
                ),
              ],
            ),
          ],
        ),
      );
    }

    // Build Table Rows
    final tableRows = products.map((product) {
      final history = product['history'] as Map<String, dynamic>? ?? {};

      final rowCells = <pw.Widget>[
        // Product Name
        pw.Text(product['name'] ?? '', style: cellStyle),
        // Price
        pw.Padding(
          padding: const pw.EdgeInsets.only(right: 8.0),
          child: pw.Align(
            alignment: pw.Alignment.centerRight,
            child: pw.Text(
              (product['price'] as double).toStringAsFixed(2),
              style: cellStyle,
            ),
          ),
        ),
      ];

      for (var date in dates) {
        final qty = history[date];
        final displayQty = qty != null ? qty.toStringAsFixed(0) : '-';

        rowCells.add(
          pw.Row(
            children: [
              pw.Expanded(
                child: pw.Center(
                  child: pw.Text(
                    displayQty,
                    style: qty != null
                        ? cellStyle.copyWith(fontWeight: pw.FontWeight.bold)
                        : cellStyle.copyWith(color: PdfColors.grey400),
                  ),
                ),
              ),
              pw.Container(width: 0.5, height: 12, color: PdfColors.grey300),
              pw.Expanded(
                child: pw.Center(
                  child: pw.Text(
                    '', // Inventory data not yet available, keeping empty
                    style: cellStyle,
                  ),
                ),
              ),
            ],
          ),
        );
      }

      return pw.TableRow(children: rowCells);
    }).toList();

    // Generate
    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4.landscape,
        margin: const pw.EdgeInsets.all(40),
        build: (pw.Context context) {
          return [
            // Header Info
            pw.Container(
              decoration: const pw.BoxDecoration(
                border: pw.Border(
                  bottom: pw.BorderSide(color: PdfColors.black, width: 2),
                ),
              ),
              padding: const pw.EdgeInsets.only(bottom: 10),
              margin: const pw.EdgeInsets.only(bottom: 20),
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        customerName.toUpperCase(),
                        style: pw.TextStyle(
                          fontSize: 16,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                      pw.SizedBox(height: 4),
                      pw.Text(
                        "CODE: $customerCode",
                        style: const pw.TextStyle(
                          fontSize: 12,
                          color: PdfColors.grey700,
                        ),
                      ),
                    ],
                  ),
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Text(
                        "CALLSHEET HISTORY",
                        style: pw.TextStyle(
                          fontSize: 16,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColors.blue800,
                        ),
                      ),
                      pw.SizedBox(height: 4),
                      pw.Text(
                        DateFormat('MMMM dd, yyyy').format(DateTime.now()),
                        style: const pw.TextStyle(
                          fontSize: 10,
                          color: PdfColors.grey700,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Table
            pw.Table(
              border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
              columnWidths: {
                0: const pw.FixedColumnWidth(160), // Product Name
                1: const pw.FixedColumnWidth(60), // Price
                // Dates auto-sized or fixed
              },
              children: [
                // Header Row
                pw.TableRow(
                  decoration: const pw.BoxDecoration(color: PdfColors.grey100),
                  children: tableHeaders.map((header) {
                    return pw.Container(
                      padding: const pw.EdgeInsets.symmetric(
                        vertical: 8,
                        horizontal: 4,
                      ),
                      alignment: pw.Alignment.center,
                      child: header,
                    );
                  }).toList(),
                ),
                // Data Rows
                ...tableRows.map((row) {
                  return pw.TableRow(
                    children: row.children.map((cell) {
                      // Extract inner text widget if possible, or just wrap
                      return pw.Container(
                        padding: const pw.EdgeInsets.symmetric(
                          vertical: 6,
                          horizontal: 4,
                        ),
                        alignment: pw.Alignment.centerLeft,
                        child: cell,
                      );
                    }).toList(),
                  );
                }),
              ],
            ),
          ];
        },
      ),
    );

    // Save File
    final output = await getTemporaryDirectory();
    final file = File(
      "${output.path}/callsheet_${DateTime.now().millisecondsSinceEpoch}.pdf",
    );
    await file.writeAsBytes(await pdf.save());

    return file;
  }
}
