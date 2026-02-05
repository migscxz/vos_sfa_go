import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:horizontal_data_table/horizontal_data_table.dart';
import 'package:intl/intl.dart';

import '../../../../core/database/database_manager.dart';
import '../../../../data/models/order_model.dart';
import '../../orders/data/repositories/order_repository.dart';

class MonitoringOrderListPage extends ConsumerStatefulWidget {
  const MonitoringOrderListPage({super.key});

  @override
  ConsumerState<MonitoringOrderListPage> createState() =>
      _MonitoringOrderListPageState();
}

class _StatusSummary {
  int count = 0;
  double totalAmount = 0;
  DateTime? oldestDate;
}

class _CustomerRow {
  final String customerName;
  final String customerCode;
  final Map<String, _StatusSummary> statusData;

  _CustomerRow({
    required this.customerName,
    required this.customerCode,
    required this.statusData,
  });
}

class _MonitoringOrderListPageState
    extends ConsumerState<MonitoringOrderListPage> {
  final OrderRepository _orderRepo = OrderRepository();
  bool _isLoading = true;
  List<OrderModel> _allOrders = [];
  List<_CustomerRow> _rows = [];
  String _searchQuery = '';

  final List<String> _statuses = [
    'For Approval',
    'For Consolidation',
    'For Picking',
    'For Invoicing',
    'For Loading',
    'For Shipping',
    'En Route',
    'Delivered',
    'On Hold',
    'Cancelled',
    'Not Fulfilled',
  ];

  static const double leftColWidth = 160.0;
  static const double statusColWidth = 140.0;

  @override
  void initState() {
    super.initState();
    _loadOrders();
  }

  Future<void> _loadOrders() async {
    setState(() => _isLoading = true);
    try {
      // Load ALL orders and Customers
      final orders = await _orderRepo.getOrders();

      // Fetch customers for name lookup
      final db = await DatabaseManager().getDatabase();
      final customerRows = await db.query('customer');
      final Map<String, String> customerNames = {};
      for (final row in customerRows) {
        final code = (row['customer_code'] ?? row['code'] ?? '').toString();
        final name = (row['customer_name'] ?? row['name'] ?? '').toString();
        if (code.isNotEmpty) {
          customerNames[code] = name;
        }
      }

      if (mounted) {
        setState(() {
          _allOrders = orders;
          _processData(customerNames);
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint("Error loading orders: $e");
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _processData(Map<String, String> customerNames) {
    // Map<CustomerCode, _CustomerRow>
    final Map<String, _CustomerRow> rowMap = {};

    for (final order in _allOrders) {
      final code = order.customerCode ?? 'UNKNOWN';
      // Use lookup name if available, otherwise fallback to order's stored name/code
      final name = customerNames[code] ?? order.customerName;
      final status = _matchStatus(order.status);

      if (!rowMap.containsKey(code)) {
        rowMap[code] = _CustomerRow(
          customerName: name,
          customerCode: code,
          statusData: {},
        );
      }

      final row = rowMap[code]!;
      if (!row.statusData.containsKey(status)) {
        row.statusData[status] = _StatusSummary();
      }

      final summary = row.statusData[status]!;
      summary.count++;
      summary.totalAmount += order.totalAmount;

      // Check oldest date
      if (summary.oldestDate == null ||
          order.orderDate.isBefore(summary.oldestDate!)) {
        summary.oldestDate = order.orderDate;
      }
    }

    _rows = rowMap.values.toList();

    // Optional: Sort by customer name
    _rows.sort((a, b) => a.customerName.compareTo(b.customerName));
  }

  // Helper to normalize status strings case-insensitively
  String _matchStatus(String rawStatus) {
    for (final s in _statuses) {
      if (s.toLowerCase() == rawStatus.toLowerCase()) return s;
    }
    return 'Other'; // Or handle unknown statuses
  }

  List<_CustomerRow> get _filteredRows {
    if (_searchQuery.isEmpty) return _rows;
    return _rows
        .where(
          (row) =>
              row.customerName.toLowerCase().contains(
                _searchQuery.toLowerCase(),
              ) ||
              row.customerCode.toLowerCase().contains(
                _searchQuery.toLowerCase(),
              ),
        )
        .toList();
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'for approval':
        return Colors.orange;
      case 'for consolidation':
        return Colors.blue;
      case 'for picking':
        return Colors.purple;
      case 'for invoicing':
        return Colors.indigo;
      case 'for loading':
        return Colors.teal;
      case 'for shipping':
        return Colors.cyan;
      case 'en route':
        return Colors.lightBlue;
      case 'delivered':
        return Colors.green;
      case 'on hold':
        return Colors.redAccent;
      case 'cancelled':
        return Colors.red;
      case 'not fulfilled':
        return Colors.grey;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Order Monitoring Dashboard"),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
      ),
      backgroundColor: Colors.white,
      body: Column(
        children: [
          // Search Bar
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              decoration: InputDecoration(
                hintText: 'Search Customer...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.grey[300]!),
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16),
              ),
              onChanged: (value) {
                setState(() {
                  _searchQuery = value;
                });
              },
            ),
          ),
          // Table
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : HorizontalDataTable(
                    leftHandSideColumnWidth: leftColWidth,
                    rightHandSideColumnWidth: _statuses.length * statusColWidth,
                    isFixedHeader: true,
                    headerWidgets: _buildHeaderWidgets(),
                    leftSideItemBuilder: _buildLeftColumnItem,
                    rightSideItemBuilder: _buildRightColumnItems,
                    itemCount: _filteredRows.length,
                    rowSeparatorWidget: const Divider(
                      color: Colors.black12,
                      height: 1.0,
                      thickness: 1.0,
                    ),
                    leftHandSideColBackgroundColor: Colors.white,
                    rightHandSideColBackgroundColor: Colors.white,
                  ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildHeaderWidgets() {
    return [
      _buildHeaderCell(
        "Customer",
        width: leftColWidth,
        alignment: Alignment.centerLeft,
      ),
      ..._statuses.map((s) => _buildHeaderCell(s, width: statusColWidth)),
    ];
  }

  Widget _buildHeaderCell(
    String label, {
    required double width,
    Alignment alignment = Alignment.center,
  }) {
    return Container(
      width: width,
      height: 56,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      alignment: alignment,
      decoration: BoxDecoration(
        color: Colors.grey[100],
        border: const Border(
          bottom: BorderSide(color: Colors.black12, width: 1.0),
          right: BorderSide(color: Colors.black12, width: 0.5),
        ),
      ),
      child: Text(
        label,
        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        textAlign: TextAlign.center,
      ),
    );
  }

  Widget _buildLeftColumnItem(BuildContext context, int index) {
    if (index >= _filteredRows.length) return const SizedBox();
    final row = _filteredRows[index];

    return Container(
      width: leftColWidth,
      height: 80, // Taller rows for potential content
      padding: const EdgeInsets.all(8),
      alignment: Alignment.centerLeft,
      decoration: const BoxDecoration(
        border: Border(
          bottom: BorderSide(color: Colors.black12, width: 0.5),
          right: BorderSide(color: Colors.black12, width: 0.5),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            row.customerName,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 4),
          Text(
            row.customerCode,
            style: TextStyle(color: Colors.grey[600], fontSize: 11),
          ),
        ],
      ),
    );
  }

  Widget _buildRightColumnItems(BuildContext context, int index) {
    if (index >= _filteredRows.length) return const SizedBox();
    final row = _filteredRows[index];

    return Row(
      children: _statuses.map((status) {
        final summary = row.statusData[status];
        return _buildStatusCell(row, status, summary, statusColWidth);
      }).toList(),
    );
  }

  Widget _buildStatusCell(
    _CustomerRow row,
    String status,
    _StatusSummary? summary,
    double width,
  ) {
    if (summary == null) {
      return Container(
        width: width,
        height: 80,
        decoration: const BoxDecoration(
          border: Border(
            right: BorderSide(color: Colors.black12, width: 0.5),
            bottom: BorderSide(color: Colors.black12, width: 0.5),
          ),
        ),
      );
    }

    final color = _getStatusColor(status);
    final dateStr = summary.oldestDate != null
        ? DateFormat('MM/dd/yy').format(summary.oldestDate!)
        : '';

    return Container(
      width: width,
      height: 80,
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
      decoration: const BoxDecoration(
        border: Border(
          right: BorderSide(color: Colors.black12, width: 0.5),
          bottom: BorderSide(color: Colors.black12, width: 0.5),
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Badge
          InkWell(
            onTap: () => _showOrdersModal(row, status),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: color),
              ),
              child: Text(
                "${summary.count}",
                style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ),
          ),
          const SizedBox(height: 6),
          // Amount
          Text(
            NumberFormat.compactCurrency(
              symbol: '₱',
            ).format(summary.totalAmount),
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
          ),
          // Date
          if (dateStr.isNotEmpty) ...[
            const SizedBox(height: 2),
            Text(
              dateStr,
              style: TextStyle(color: Colors.grey[600], fontSize: 11),
            ),
          ],
        ],
      ),
    );
  }

  void _showOrdersModal(_CustomerRow row, String status) {
    // Filter orders for this specific cell
    final cellOrders = _allOrders.where((o) {
      return (o.customerCode == row.customerCode) &&
          (_matchStatus(o.status) == status);
    }).toList();

    // Sort by date (oldest first)
    cellOrders.sort((a, b) => a.orderDate.compareTo(b.orderDate));

    showDialog(
      context: context,
      builder: (context) => _OrderListModal(
        customerName: row.customerName,
        status: status,
        orders: cellOrders,
      ),
    );
  }
}

class _OrderListModal extends StatefulWidget {
  final String customerName;
  final String status;
  final List<OrderModel> orders;

  const _OrderListModal({
    required this.customerName,
    required this.status,
    required this.orders,
  });

  @override
  State<_OrderListModal> createState() => _OrderListModalState();
}

class _OrderListModalState extends State<_OrderListModal> {
  late List<OrderModel> _filteredOrders;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _filteredOrders = widget.orders;
  }

  void _filterOrders(String query) {
    setState(() {
      _searchQuery = query;
      if (query.isEmpty) {
        _filteredOrders = widget.orders;
      } else {
        _filteredOrders = widget.orders.where((order) {
          final q = query.toLowerCase();
          return order.orderNo.toLowerCase().contains(q) ||
              (order.poNo?.toLowerCase().contains(q) ?? false) ||
              order.totalAmount.toString().contains(q);
        }).toList();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: 600, // Fixed width for tablet/desktop feel
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.8,
        ),
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            // Header
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.customerName,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: _getStatusColor(
                            widget.status,
                          ).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          widget.status.toUpperCase(),
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: _getStatusColor(widget.status),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                  tooltip: 'Close',
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Search Bar
            TextField(
              decoration: InputDecoration(
                hintText: 'Search Order No, PO, or Amount...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: Colors.grey[300]!),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: Colors.grey[300]!),
                ),
                filled: true,
                fillColor: Colors.grey[50],
                contentPadding: const EdgeInsets.symmetric(
                  vertical: 12,
                  horizontal: 16,
                ),
              ),
              onChanged: _filterOrders,
            ),
            const SizedBox(height: 16),

            // Results Summary
            Row(
              children: [
                Text(
                  "${_filteredOrders.length} orders found",
                  style: TextStyle(color: Colors.grey[600], fontSize: 13),
                ),
                const Spacer(),
                const Text("Total: ", style: TextStyle(fontSize: 13)),
                Text(
                  NumberFormat.currency(symbol: '₱').format(
                    _filteredOrders.fold(
                      0.0,
                      (sum, item) => sum + item.totalAmount,
                    ),
                  ),
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // List
            Expanded(
              child: _filteredOrders.isEmpty
                  ? Center(
                      child: Text(
                        _searchQuery.isEmpty
                            ? "No orders yet."
                            : "No matches found.",
                        style: TextStyle(color: Colors.grey[400]),
                      ),
                    )
                  : ListView.builder(
                      itemCount: _filteredOrders.length,
                      itemBuilder: (context, index) {
                        final order = _filteredOrders[index];
                        return Card(
                          margin: const EdgeInsets.only(bottom: 12),
                          elevation: 2,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                            side: BorderSide(
                              color: Colors.grey.withOpacity(0.2),
                            ),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        order.orderNo.isEmpty
                                            ? "Order #${order.id}"
                                            : order.orderNo,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 16,
                                        ),
                                      ),
                                    ),
                                    Text(
                                      NumberFormat.currency(
                                        symbol: '₱',
                                      ).format(order.totalAmount),
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                        color: Colors.green,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Row(
                                  children: [
                                    Icon(
                                      Icons.calendar_today,
                                      size: 14,
                                      color: Colors.grey[600],
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      DateFormat(
                                        'MMM dd, yyyy • h:mm a',
                                      ).format(order.orderDate),
                                      style: TextStyle(
                                        fontSize: 13,
                                        color: Colors.grey[600],
                                      ),
                                    ),
                                    if (order.poNo != null &&
                                        order.poNo!.isNotEmpty) ...[
                                      const Spacer(),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 4,
                                        ),
                                        decoration: BoxDecoration(
                                          color: Colors.grey[100],
                                          borderRadius: BorderRadius.circular(
                                            6,
                                          ),
                                          border: Border.all(
                                            color: Colors.grey[300]!,
                                          ),
                                        ),
                                        child: Text(
                                          "PO: ${order.poNo}",
                                          style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w600,
                                            color: Colors.grey[800],
                                          ),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'for approval':
        return Colors.orange;
      case 'for consolidation':
        return Colors.blue;
      case 'for picking':
        return Colors.purple;
      case 'for invoicing':
        return Colors.indigo;
      case 'for loading':
        return Colors.teal;
      case 'for shipping':
        return Colors.cyan;
      case 'en route':
        return Colors.lightBlue;
      case 'delivered':
        return Colors.green;
      case 'on hold':
        return Colors.redAccent;
      case 'cancelled':
        return Colors.red;
      case 'not fulfilled':
        return Colors.grey;
      default:
        return Colors.grey;
    }
  }
}
