import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:horizontal_data_table/horizontal_data_table.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../data/models/customer_model.dart';
import '../../orders/data/repositories/order_repository.dart';
import 'package:vos_sfa_go/features/orders/presentation/order_form.dart';
import '../../../../core/services/file_api_service.dart';
import '../../../../core/services/pdf_generator_service.dart';

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
  static const double subColWidth = 70.0; // Widened for full text
  static const double dayColWidth = subColWidth * 2; // Date Header Width

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
    setState(() => _isLoading = true);

    try {
      // 1. Generate PDF
      final pdfFile = await PdfGeneratorService().generateCallsheetPdf(
        customerName: widget.customer.name,
        customerCode: widget.customer.code,
        dates: _orderDates,
        products: _productsData,
      );

      // 2. Upload PDF
      await FileApiService().uploadFile(pdfFile);

      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Callsheet Saved & Uploaded Successfully!'),
            backgroundColor: Colors.green,
          ),
        );
        // Optional: clear cache or pop if needed? user just said remove photo page
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error uploading: $e'),
            backgroundColor: Colors.red,
          ),
        );
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

            // PO Number Field (Commented out)
            // Padding(
            //   padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            //   child: Row(
            //     children: [
            //       const Text(
            //         'PO Number: ',
            //         style: TextStyle(fontWeight: FontWeight.bold),
            //       ),
            //       const SizedBox(width: 8),
            //       Expanded(
            //         child: TextField(
            //           controller: _poNumberCtrl,
            //           decoration: const InputDecoration(
            //             hintText: 'Enter PO Number or Scan...',
            //             border: OutlineInputBorder(),
            //             isDense: true,
            //             contentPadding: EdgeInsets.symmetric(
            //               horizontal: 12,
            //               vertical: 8,
            //             ),
            //           ),
            //         ),
            //       ),
            //     ],
            //   ),
            // ),
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
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => OrderFormPage(initialCustomer: widget.customer),
            ),
          );
        },
        icon: const Icon(Icons.add_shopping_cart, color: Colors.white),
        label: const Text("+ Product"),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
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
      label: "PRODUCT",
      width: leftColWidth,
      alignment: Alignment.centerLeft,
      color: Colors.grey[200],
    );

    List<Widget> rightHeaders = [
      _buildHeaderCell(
        label: "PRICE",
        width: stdColWidth,
        color: Colors.grey[200],
      ),
    ];

    for (String date in _orderDates) {
      // Format 2023-10-25 -> 10/25
      String displayDate = date;
      try {
        final dt = DateTime.parse(date);
        displayDate = DateFormat('MM/dd').format(dt);
      } catch (_) {}

      // Double Header: Date on top, Quantity | Inventory below
      rightHeaders.add(
        _buildDoubleHeaderCell(
          topLabel: displayDate,
          subLabel1: "Quantity",
          subLabel2: "Inventory",
          width: dayColWidth,
          color: Colors.grey[200],
        ),
      );
    }

    return [leftHeader, ...rightHeaders];
  }

  Widget _buildHeaderCell({
    required String label,
    String? subLabel,
    required double width,
    Alignment alignment = Alignment.center,
    Color? color,
  }) {
    return Container(
      width: width,
      height: 50, // Increased height for double row
      padding: const EdgeInsets.symmetric(horizontal: 4),
      decoration: BoxDecoration(
        color: color ?? Colors.white,
        border: const Border(
          bottom: BorderSide(color: Colors.black, width: 1.0),
          right: BorderSide(color: Colors.black12, width: 0.5),
        ),
      ),
      alignment: alignment,
      child: subLabel == null
          ? Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
            )
          : Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
                Text(
                  subLabel,
                  style: TextStyle(
                    fontWeight: FontWeight.w500,
                    fontSize: 10,
                    color: Colors.blue[800],
                  ),
                ),
              ],
            ),
    );
  }

  // Double Header Cell (Date -> Qty | Inv)
  Widget _buildDoubleHeaderCell({
    required String topLabel,
    required String subLabel1,
    required String subLabel2,
    required double width,
    Color? color,
  }) {
    return Container(
      width: width,
      height: 50,
      decoration: BoxDecoration(
        color: color ?? Colors.white,
        border: const Border(
          bottom: BorderSide(color: Colors.black, width: 1.0),
          right: BorderSide(color: Colors.black12, width: 0.5),
        ),
      ),
      child: Column(
        children: [
          // Top Part (Date)
          Expanded(
            child: Container(
              alignment: Alignment.center,
              decoration: const BoxDecoration(
                border: Border(
                  bottom: BorderSide(color: Colors.black12, width: 0.5),
                ),
              ),
              child: Text(
                topLabel,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
            ),
          ),
          // Bottom Part (Qty | Inv)
          Expanded(
            child: Row(
              children: [
                Expanded(
                  child: Container(
                    alignment: Alignment.center,
                    decoration: const BoxDecoration(
                      border: Border(
                        right: BorderSide(color: Colors.black12, width: 0.5),
                      ),
                    ),
                    child: Text(
                      subLabel1,
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: Colors.blue[800],
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: Container(
                    alignment: Alignment.center,
                    child: Text(
                      subLabel2,
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: Colors.blue[800],
                      ),
                    ),
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
    final product = _productsData[index];
    final isEven = index % 2 == 0;

    return Container(
      width: leftColWidth,
      height: 48,
      alignment: Alignment.centerLeft,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: isEven ? Colors.white : Colors.grey[50], // Zebra striping
        border: const Border(
          bottom: BorderSide(color: Colors.black12, width: 0.5),
          right: BorderSide(color: Colors.black12, width: 0.5),
        ),
      ),
      child: Text(
        product['name'] ?? '',
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontSize: 12),
      ),
    );
  }

  Widget _buildRightColumnItems(BuildContext context, int index) {
    final product = _productsData[index];
    final history = product['history'] as Map<String, dynamic>? ?? {};
    final isEven = index % 2 == 0;
    final rowColor = isEven ? Colors.white : Colors.grey[50];

    List<Widget> cells = [];

    // Price
    cells.add(
      Container(
        width: stdColWidth,
        height: 48,
        decoration: BoxDecoration(
          color: rowColor,
          border: const Border(
            right: BorderSide(color: Colors.black12, width: 0.5),
            bottom: BorderSide(color: Colors.black12, width: 0.5),
          ),
        ),
        alignment: Alignment.center,
        child: Text(
          (product['price'] as double).toStringAsFixed(2),
          style: const TextStyle(fontSize: 12),
        ),
      ),
    );

    // Dates
    // Dates
    for (String date in _orderDates) {
      final qty = history[date]; // might be null
      final displayQty = qty != null ? qty.toStringAsFixed(0) : '-';

      // 1. Qty Cell
      cells.add(
        Container(
          width: subColWidth,
          height: 48,
          decoration: BoxDecoration(
            color: rowColor,
            border: const Border(
              right: BorderSide(color: Colors.black12, width: 0.5),
              bottom: BorderSide(color: Colors.black12, width: 0.5),
            ),
          ),
          alignment: Alignment.center,
          child: Text(
            displayQty,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: qty != null ? Colors.black : Colors.grey[300],
            ),
          ),
        ),
      );

      // 2. Inv Cell (Placeholder)
      cells.add(
        Container(
          width: subColWidth,
          height: 48,
          decoration: BoxDecoration(
            color: rowColor,
            border: const Border(
              right: BorderSide(color: Colors.black12, width: 0.5),
              bottom: BorderSide(color: Colors.black12, width: 0.5),
            ),
          ),
          alignment: Alignment.center,
          child: const Text(''),
        ),
      );
    }

    return Row(children: cells);
  }
}
