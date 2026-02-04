import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:horizontal_data_table/horizontal_data_table.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

import '../../../../core/theme/app_colors.dart';
import '../../../../data/models/customer_model.dart';
import '../../../../providers/auth_provider.dart';
import '../../orders/data/repositories/order_repository.dart';
import 'callsheet_capture_page.dart';

class CallsheetDataEntryPage extends ConsumerStatefulWidget {
  final Customer customer;

  const CallsheetDataEntryPage({super.key, required this.customer});

  @override
  ConsumerState<CallsheetDataEntryPage> createState() =>
      _CallsheetDataEntryPageState();
}

class _CallsheetDataEntryPageState
    extends ConsumerState<CallsheetDataEntryPage> {
  // --- A4 LANDSCAPE CONFIGURATION (~1123px total width) ---
  static const double leftColWidth = 180.0;
  static const double stdColWidth = 70.0;
  static const double dayColWidth = 60.0;

  // State
  bool _isLoading = true;
  List<String> _orderDates = [];
  List<Map<String, dynamic>> _productsData = [];
  final TextEditingController _poNumberCtrl = TextEditingController();
  final OrderRepository _orderRepo = OrderRepository();

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final data = await _orderRepo.getCallsheetData(widget.customer.code);
      if (mounted) {
        setState(() {
          _orderDates = List<String>.from(data['dates'] ?? []);
          _productsData = List<Map<String, dynamic>>.from(
            data['products'] ?? [],
          );
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint("Error loading callsheet data: $e");
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _handleUpload() async {
    // 1. Check PO Number
    if (_poNumberCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a PO Number first.')),
      );
      return;
    }

    // 2. Capture Image
    final imagePath = await Navigator.of(context).push<String>(
      MaterialPageRoute(builder: (_) => const CallsheetCapturePage()),
    );

    if (imagePath == null) return;

    // 3. Save
    try {
      final user = ref.read(authProvider).user;
      final userId = user?.userId ?? 0;

      // Rename file to [OrderNo].jpg handling
      final orderNo = _poNumberCtrl.text
          .trim(); // Using PO as identifier for now
      final appDir = await getApplicationDocumentsDirectory();
      final fileName = '$orderNo.jpg';
      final newPath = p.join(appDir.path, fileName);

      await File(imagePath).copy(newPath);

      // Save info to DB
      await _orderRepo.saveCallsheetAttachment(
        salesOrderId: null, // We don't have a structured sales_order yet
        attachmentPath: newPath,
        createdBy: userId,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Callsheet Uploaded Successfully!')),
        );
        Navigator.of(context).pop(); // Go back to dashboard?
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error uploading: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // Dynamic Columns calculation
    // Left + Price + Dates
    final rightWidth = stdColWidth + (_orderDates.length * dayColWidth);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text("Call Sheet Entry"),
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        actions: [
          // Upload Button
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
            child: ElevatedButton.icon(
              onPressed: _handleUpload,
              icon: const Icon(Icons.upload_file, size: 18),
              label: const Text("SAVE & UPLOAD"),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
              ),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            _buildTopInfoSection(theme),

            // PO Number Field
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  const Text(
                    'PO Number: ',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: _poNumberCtrl,
                      decoration: const InputDecoration(
                        hintText: 'Enter PO Number or Scan...',
                        border: OutlineInputBorder(),
                        isDense: true,
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _productsData.isEmpty
                  ? const Center(
                      child: Text(
                        'No historical data found for this customer.',
                      ),
                    )
                  : HorizontalDataTable(
                      leftHandSideColumnWidth: leftColWidth,
                      rightHandSideColumnWidth: rightWidth,
                      isFixedHeader: true,
                      headerWidgets: _buildHeaderWidgets(),
                      leftSideItemBuilder: _buildLeftColumnItem,
                      rightSideItemBuilder: _buildRightColumnItems,
                      itemCount: _productsData.length,
                      rowSeparatorWidget: const Divider(
                        color: Colors.black,
                        height: 1.0,
                        thickness: 1.0,
                      ),
                      leftHandSideColBackgroundColor: Colors.white,
                      rightHandSideColBackgroundColor: Colors.white,
                    ),
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
          Expanded(
            flex: 2,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildLabelField("CUSTOMER NAME:", widget.customer.name),
                const SizedBox(height: 4),
                _buildLabelField("CODE:", widget.customer.code),
              ],
            ),
          ),
          Expanded(
            flex: 1,
            child: Container(
              height: 60,
              alignment: Alignment.center,
              child: const Text(
                "CALLSHEET / HISTORY",
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
            decoration: const BoxDecoration(
              border: Border(
                bottom: BorderSide(color: Colors.black, width: 0.5),
              ),
            ),
            alignment: Alignment.centerLeft,
            child: Text(value, style: const TextStyle(fontSize: 13)),
          ),
        ),
      ],
    );
  }

  List<Widget> _buildHeaderWidgets() {
    var leftHeader = _buildHeaderCell(
      "PRODUCT",
      leftColWidth,
      alignment: Alignment.centerLeft,
    );

    List<Widget> rightHeaders = [_buildHeaderCell("PRICE", stdColWidth)];

    for (String date in _orderDates) {
      // Format 2023-10-25 -> 10/25
      String displayDate = date;
      try {
        final dt = DateTime.parse(date);
        displayDate = DateFormat('MM/dd').format(dt);
      } catch (_) {}

      rightHeaders.add(_buildHeaderCell(displayDate, dayColWidth));
    }

    return [leftHeader, ...rightHeaders];
  }

  Widget _buildHeaderCell(
    String text,
    double width, {
    Alignment alignment = Alignment.center,
  }) {
    return Container(
      width: width,
      height: 40,
      padding: const EdgeInsets.symmetric(horizontal: 4),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(
          right: BorderSide(color: Colors.black, width: 1),
          bottom: BorderSide(color: Colors.black, width: 1),
          top: BorderSide(color: Colors.black, width: 1),
        ),
      ),
      alignment: alignment,
      child: Text(
        text,
        maxLines: 2,
        textAlign: TextAlign.center,
        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11),
      ),
    );
  }

  Widget _buildLeftColumnItem(BuildContext context, int index) {
    final item = _productsData[index];
    return Container(
      width: leftColWidth,
      height: 30,
      alignment: Alignment.centerLeft,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: const BoxDecoration(
        border: Border(
          right: BorderSide(color: Colors.black, width: 1),
          bottom: BorderSide(color: Colors.black, width: 1),
          left: BorderSide(color: Colors.black, width: 1),
        ),
      ),
      child: Text(
        item['name'] ?? '',
        style: const TextStyle(fontSize: 11),
        overflow: TextOverflow.ellipsis,
      ),
    );
  }

  Widget _buildRightColumnItems(BuildContext context, int index) {
    final item = _productsData[index];
    final history = item['history'] as Map<String, dynamic>? ?? {};

    List<Widget> cells = [];

    // Price
    cells.add(
      Container(
        width: stdColWidth,
        height: 30,
        alignment: Alignment.center,
        decoration: const BoxDecoration(
          border: Border(
            right: BorderSide(color: Colors.black, width: 1),
            bottom: BorderSide(color: Colors.black, width: 1),
          ),
        ),
        child: Text(
          (item['price'] as double).toStringAsFixed(2),
          style: const TextStyle(fontSize: 11),
        ),
      ),
    );

    // Dates
    for (String date in _orderDates) {
      final qty = history[date];
      cells.add(
        Container(
          width: dayColWidth,
          height: 30,
          alignment: Alignment.center,
          decoration: const BoxDecoration(
            border: Border(
              right: BorderSide(color: Colors.black, width: 1),
              bottom: BorderSide(color: Colors.black, width: 1),
            ),
          ),
          child: Text(
            qty != null ? qty.toStringAsFixed(0) : '-',
            style: TextStyle(
              fontSize: 11,
              fontWeight: qty != null ? FontWeight.bold : FontWeight.normal,
              color: qty != null ? Colors.black : Colors.grey[300],
            ),
          ),
        ),
      );
    }

    return Row(children: cells);
  }
}
