import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:horizontal_data_table/horizontal_data_table.dart';
import '../../../../core/theme/app_colors.dart';

class CallsheetDataEntryPage extends ConsumerStatefulWidget {
  const CallsheetDataEntryPage({super.key});

  @override
  ConsumerState<CallsheetDataEntryPage> createState() => _CallsheetDataEntryPageState();
}

class _CallsheetDataEntryPageState extends ConsumerState<CallsheetDataEntryPage> {
  // --- A4 LANDSCAPE CONFIGURATION (~1123px total width) ---
  // Adjusted widths to closer match the visual proportion in the image
  static const double leftColWidth = 200.0; // Product Description is wider
  static const double stdColWidth = 80.0;   // Price, Suggested, Barcode, Inv
  static const double daySubColWidth = 40.0; // Inv / Last Order
  static const double dayGroupWidth = daySubColWidth * 2;
  static const int numberOfDays = 8;

  // Generate empty rows to match the "blank form" look of the image
  final List<String> _products = List.generate(40, (index) => "");

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text("Call Sheet Entry"),
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        actions: [
          IconButton(
            icon: const Icon(Icons.print),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Ready for PDF Generation')),
              );
            },
          )
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            _buildTopInfoSection(theme),
            // The table header in the image acts as the divider, so we don't need a separate one if the table starts immediately.
            Expanded(
              child: _buildTable(theme),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopInfoSection(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Left Side: Customer Info
          Expanded(
            flex: 2,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildLabelField("CUSTOMER NAME:", ""),
                const SizedBox(height: 4),
                _buildLabelField("ADDRESS:", ""),
              ],
            ),
          ),
          // Right Side: Logo / Header Area
          Expanded(
            flex: 1,
            child: Container(
              height: 60,
              alignment: Alignment.center,
              child: const Text(
                "LOGO / HEADER AREA",
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLabelField(String label, String value) {
    return Row(
      children: [
        SizedBox(
          width: 110,
          child: Text(
            label,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
          ),
        ),
        Expanded(
          child: Container(
            height: 24,
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: Colors.black, width: 0.5)),
            ),
            alignment: Alignment.centerLeft,
            child: Text(value, style: const TextStyle(fontSize: 13)),
          ),
        ),
      ],
    );
  }

  Widget _buildTable(ThemeData theme) {
    return HorizontalDataTable(
      leftHandSideColumnWidth: leftColWidth,
      rightHandSideColumnWidth: (stdColWidth * 4) + (dayGroupWidth * numberOfDays),
      isFixedHeader: true,
      headerWidgets: _buildHeaderWidgets(),
      leftSideItemBuilder: _buildLeftColumnItem,
      rightSideItemBuilder: _buildRightColumnItems,
      itemCount: _products.length,
      rowSeparatorWidget: const Divider(color: Colors.black, height: 1.0, thickness: 1.0),
      leftHandSideColBackgroundColor: Colors.white,
      rightHandSideColBackgroundColor: Colors.white,
      verticalScrollbarStyle: const ScrollbarStyle(
        thumbColor: Colors.grey,
        isAlwaysShown: true,
        thickness: 4.0,
        radius: Radius.circular(5.0),
      ),
      horizontalScrollbarStyle: const ScrollbarStyle(
        thumbColor: Colors.grey,
        isAlwaysShown: true,
        thickness: 4.0,
        radius: Radius.circular(5.0),
      ),
    );
  }

  List<Widget> _buildHeaderWidgets() {
    // The image has headers with borders.
    var leftHeader = _buildHeaderCell("PRODUCT DESCRIPTION", leftColWidth, height: 50, alignment: Alignment.centerLeft);

    List<Widget> rightHeaders = [
      _buildHeaderCell("unit price", stdColWidth, height: 50),
      _buildHeaderCell("suggested order", stdColWidth, height: 50),
      _buildHeaderCell("barcode", stdColWidth, height: 50),
      _buildHeaderCell("inventory", stdColWidth, height: 50),
    ];

    for (int i = 1; i <= numberOfDays; i++) {
      rightHeaders.add(_buildDayGroupHeader("DAY $i"));
    }

    return [leftHeader, ...rightHeaders];
  }

  Widget _buildHeaderCell(String text, double width, {double height = 50, Alignment alignment = Alignment.center}) {
    return Container(
      width: width,
      height: height,
      padding: const EdgeInsets.symmetric(horizontal: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(
          right: const BorderSide(color: Colors.black, width: 1),
          bottom: const BorderSide(color: Colors.black, width: 1),
          top: const BorderSide(color: Colors.black, width: 1),
          // Left border handled by previous cell or container
        ),
      ),
      alignment: alignment,
      child: Text(
        text.toUpperCase(), // Image has headers in uppercase (mostly)
        textAlign: TextAlign.center,
        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Colors.black),
      ),
    );
  }

  Widget _buildDayGroupHeader(String title) {
    return Container(
      width: dayGroupWidth,
      height: 50,
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(
          right: const BorderSide(color: Colors.black, width: 1),
          bottom: const BorderSide(color: Colors.black, width: 1),
          top: const BorderSide(color: Colors.black, width: 1),
        ),
      ),
      child: Column(
        children: [
          Expanded(
            child: Container(
              alignment: Alignment.center,
              width: double.infinity,
              decoration: const BoxDecoration(
                border: Border(bottom: BorderSide(color: Colors.black, width: 1)),
              ),
              child: Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
            ),
          ),
          Expanded(
            child: Row(
              children: [
                Expanded(
                  child: Container(
                    alignment: Alignment.center,
                    decoration: const BoxDecoration(
                      border: Border(right: BorderSide(color: Colors.black, width: 1)),
                    ),
                    child: const Text("Inv", style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                  ),
                ),
                Expanded(
                  child: Container(
                    alignment: Alignment.center,
                    child: const Text("Last Order", style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLeftColumnItem(BuildContext context, int index) {
    return Container(
      width: leftColWidth,
      height: 30, // Reduced height to match dense spreadsheet look
      alignment: Alignment.centerLeft,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: const BoxDecoration(
        border: Border(
          right: BorderSide(color: Colors.black, width: 1),
          bottom: BorderSide(color: Colors.black, width: 1),
          left: BorderSide(color: Colors.black, width: 1), // Left column needs left border
        ),
      ),
      child: Text(
        _products[index],
        style: const TextStyle(fontSize: 11),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }

  Widget _buildRightColumnItems(BuildContext context, int index) {
    List<Widget> cells = [
      _buildDataCell(stdColWidth, ""), // Unit Price
      _buildDataCell(stdColWidth, ""), // Suggested
      _buildDataCell(stdColWidth, ""), // Barcode
      _buildDataCell(stdColWidth, ""), // Inventory
    ];

    for (int i = 0; i < numberOfDays; i++) {
      cells.add(_buildDataCell(daySubColWidth, "")); // Inv
      cells.add(_buildDataCell(daySubColWidth, "")); // Last Order
    }

    return Row(children: cells);
  }

  Widget _buildDataCell(double width, String text) {
    return Container(
      width: width,
      height: 30, // Match row height
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(
          right: BorderSide(color: Colors.black, width: 1),
          bottom: BorderSide(color: Colors.black, width: 1),
        ),
      ),
      // Since it's a blank form for now, we just keep it empty or put a TextField if editable
      child: const SizedBox(),
    );
  }
}