// lib/features/customers/presentation/sales_history_page.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:getwidget/getwidget.dart';

import '../../../core/theme/app_colors.dart';
import 'package:vos_sfa_go/core/database/database_manager.dart';

import '../../../providers/auth_provider.dart';

class SalesHistoryPage extends ConsumerStatefulWidget {
  const SalesHistoryPage({
    super.key,
    this.salesmanId,
  });

  final int? salesmanId;

  @override
  ConsumerState<SalesHistoryPage> createState() =>
      _SalesHistoryPageState();
}

class _SalesHistoryPageState extends ConsumerState<SalesHistoryPage> {
  final TextEditingController _searchController = TextEditingController();

  List<_SalesInvoiceRow> _allInvoices = [];
  String _query = '';
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();

    _searchController.addListener(() {
      setState(() {
        _query = _searchController.text.toLowerCase();
      });
    });

    _loadSalesHistory();
  }

  Future<void> _loadSalesHistory() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final dbSales =
      await DatabaseManager().getDatabase(DatabaseManager.dbSales);
      final dbCustomer =
      await DatabaseManager().getDatabase(DatabaseManager.dbCustomer);

      final customerRows = await dbCustomer.query(
        'customer',
        columns: ['customer_code', 'customer_name'],
      );

      final Map<String, String> codeToName = {};
      for (final row in customerRows) {
        final code = (row['customer_code'] ?? '').toString();
        final name = (row['customer_name'] ?? '').toString();
        if (code.isEmpty) continue;
        codeToName[code] = name;
      }

      final authState = ref.read(authProvider);
      final loggedSalesmanId = authState.salesman?.id;
      final effectiveSalesmanId = widget.salesmanId ?? loggedSalesmanId;

      List<Map<String, dynamic>> rows;

      if (effectiveSalesmanId != null) {
        rows = await dbSales.query(
          'sales_invoice',
          columns: [
            'invoice_id',
            'invoice_no',
            'customer_code',
            'dispatch_date',
            'invoice_date',
            'total_amount',
            'isRemitted',
          ],
          where: 'salesman_id = ?',
          whereArgs: [effectiveSalesmanId],
          orderBy: 'dispatch_date DESC, invoice_id DESC',
        );
      } else {
        rows = await dbSales.query(
          'sales_invoice',
          columns: [
            'invoice_id',
            'invoice_no',
            'customer_code',
            'dispatch_date',
            'invoice_date',
            'total_amount',
            'isRemitted',
          ],
          orderBy: 'dispatch_date DESC, invoice_id DESC',
        );
      }

      final List<_SalesInvoiceRow> list = [];
      for (final row in rows) {
        try {
          final code = row['customer_code']?.toString() ?? '';
          final name = codeToName[code] ?? '';
          list.add(_SalesInvoiceRow.fromMap(row, customerName: name));
        } catch (e) {
          debugPrint('Error parsing sales_invoice row: $e');
        }
      }

      setState(() {
        _allInvoices = list;
      });
    } catch (e) {
      debugPrint('Error loading sales history: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to load sales history: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final filtered = _allInvoices.where((inv) {
      if (_query.isEmpty) return true;
      final name = inv.customerName.toLowerCase();
      final code = inv.customerCode.toLowerCase();
      final invoiceNo = inv.invoiceNo.toLowerCase();

      return invoiceNo.contains(_query) ||
          code.contains(_query) ||
          name.contains(_query);
    }).toList();

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              _buildHeader(theme),
              const SizedBox(height: 20),
              _buildSearchBar(theme),
              const SizedBox(height: 20),
              _buildStatsOverview(filtered),
              const SizedBox(height: 20),
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: const Color(0xFFE2E8F0),
                      width: 1,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.04),
                        blurRadius: 20,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: _isLoading
                      ? const Center(child: CircularProgressIndicator())
                      : filtered.isEmpty
                      ? _buildEmptyState()
                      : ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: filtered.length,
                    separatorBuilder: (_, __) =>
                    const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final inv = filtered[index];
                      return _SalesInvoiceTile(invoice: inv);
                    },
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(ThemeData theme) {
    final authState = ref.watch(authProvider);
    final salesman = authState.salesman;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.blueBright,
            AppColors.blueBright.withOpacity(0.8),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppColors.blueBright.withOpacity(0.3),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.history,
              color: Colors.white,
              size: 28,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Sales History',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  salesman != null
                      ? '${salesman.name} • ${salesman.code}'
                      : 'All Sales Invoices',
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.white.withOpacity(0.9),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          Container(
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: IconButton(
              onPressed: _loadSalesHistory,
              icon: const Icon(Icons.refresh, color: Colors.white),
              iconSize: 22,
              padding: const EdgeInsets.all(10),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar(ThemeData theme) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFFE2E8F0),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: TextField(
        controller: _searchController,
        style: const TextStyle(
          color: AppColors.textDark,
          fontSize: 15,
        ),
        decoration: InputDecoration(
          hintText: 'Search invoices, customers...',
          hintStyle: TextStyle(
            color: AppColors.textMuted.withOpacity(0.7),
            fontSize: 15,
          ),
          prefixIcon: const Icon(
            Icons.search,
            color: AppColors.textMuted,
            size: 22,
          ),
          suffixIcon: _query.isNotEmpty
              ? IconButton(
            icon: const Icon(Icons.clear, size: 20),
            onPressed: () => _searchController.clear(),
            color: AppColors.textMuted,
          )
              : null,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 16,
          ),
        ),
      ),
    );
  }

  Widget _buildStatsOverview(List<_SalesInvoiceRow> filtered) {
    final total = filtered.fold<double>(
      0,
          (sum, inv) => sum + inv.totalAmount,
    );
    final remittedCount = filtered.where((inv) => inv.isRemitted).length;

    return Row(
      children: [
        Expanded(
          child: _buildStatCard(
            icon: Icons.receipt_long_outlined,
            label: 'Total Invoices',
            value: filtered.length.toString(),
            color: AppColors.blueBright,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildStatCard(
            icon: Icons.check_circle_outline,
            label: 'Remitted',
            value: remittedCount.toString(),
            color: Colors.green,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildStatCard(
            icon: Icons.currency_exchange,
            label: 'Total Sales',
            value: '₱${(total / 1000).toStringAsFixed(1)}K',
            color: Colors.orange,
          ),
        ),
      ],
    );
  }

  Widget _buildStatCard({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFFE2E8F0),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: AppColors.textDark,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: AppColors.textMuted,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: AppColors.blueBright.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.receipt_long_outlined,
              size: 64,
              color: AppColors.blueBright.withOpacity(0.5),
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            'No sales history found',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: AppColors.textDark,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Your sales invoices will appear here',
            style: TextStyle(
              fontSize: 14,
              color: AppColors.textMuted,
            ),
          ),
        ],
      ),
    );
  }
}

class _SalesInvoiceRow {
  final int invoiceId;
  final String invoiceNo;
  final String customerCode;
  final String customerName;
  final DateTime? dispatchDate;
  final DateTime? invoiceDate;
  final double totalAmount;
  final bool isRemitted;

  const _SalesInvoiceRow({
    required this.invoiceId,
    required this.invoiceNo,
    required this.customerCode,
    required this.customerName,
    required this.dispatchDate,
    required this.invoiceDate,
    required this.totalAmount,
    required this.isRemitted,
  });

  factory _SalesInvoiceRow.fromMap(
      Map<String, dynamic> map, {
        String? customerName,
      }) {
    final rawDispatch = map['dispatch_date'];
    final rawInvoiceDate = map['invoice_date'];

    DateTime? parseDate(dynamic value) {
      if (value == null) return null;
      if (value is String && value.isNotEmpty) {
        return DateTime.tryParse(value);
      }
      return null;
    }

    final totalRaw = map['total_amount'];
    double total = 0;
    if (totalRaw is num) {
      total = totalRaw.toDouble();
    } else if (totalRaw is String) {
      total = double.tryParse(totalRaw) ?? 0;
    }

    final remittedRaw = map['isRemitted'];
    bool remitted = false;
    if (remittedRaw is int) {
      remitted = remittedRaw != 0;
    } else if (remittedRaw is bool) {
      remitted = remittedRaw;
    }

    return _SalesInvoiceRow(
      invoiceId: (map['invoice_id'] as num).toInt(),
      invoiceNo: map['invoice_no']?.toString() ?? '',
      customerCode: map['customer_code']?.toString() ?? '',
      customerName: customerName ?? '',
      dispatchDate: parseDate(rawDispatch),
      invoiceDate: parseDate(rawInvoiceDate),
      totalAmount: total,
      isRemitted: remitted,
    );
  }

  String get displayDate {
    final d = dispatchDate ?? invoiceDate;
    if (d == null) return '-';
    return '${d.year.toString().padLeft(4, '0')}-'
        '${d.month.toString().padLeft(2, '0')}-'
        '${d.day.toString().padLeft(2, '0')}';
  }

  String get displayCustomer {
    if (customerName.trim().isNotEmpty) {
      return customerName;
    }
    return customerCode;
  }
}

class _SalesInvoiceTile extends StatelessWidget {
  final _SalesInvoiceRow invoice;

  const _SalesInvoiceTile({required this.invoice});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFFE2E8F0),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => _showInvoiceDetail(context, invoice),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.blueBright.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.receipt_long,
                    color: AppColors.blueBright,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              invoice.invoiceNo,
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                                color: AppColors.textDark,
                              ),
                            ),
                          ),
                          _buildStatusBadge(),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Icon(
                            Icons.person_outline,
                            size: 14,
                            color: AppColors.textMuted,
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              invoice.displayCustomer,
                              style: const TextStyle(
                                fontSize: 13,
                                color: AppColors.textDark,
                                fontWeight: FontWeight.w500,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Icon(
                            Icons.calendar_today_outlined,
                            size: 13,
                            color: AppColors.textMuted,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            invoice.displayDate,
                            style: TextStyle(
                              fontSize: 12,
                              color: AppColors.textMuted,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.blueBright.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              '₱${invoice.totalAmount.toStringAsFixed(2)}',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: AppColors.blueBright,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Icon(
                  Icons.chevron_right,
                  color: AppColors.textMuted.withOpacity(0.5),
                  size: 20,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStatusBadge() {
    final color = invoice.isRemitted
        ? Colors.green
        : Colors.orange;
    final icon = invoice.isRemitted
        ? Icons.check_circle
        : Icons.schedule;
    final text = invoice.isRemitted
        ? 'Remitted'
        : 'Pending';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: color.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(
            text,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  void _showInvoiceDetail(BuildContext context, _SalesInvoiceRow invoice) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 40,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 20),
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.blueBright.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          Icons.receipt_long,
                          color: AppColors.blueBright,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Text(
                          'Invoice Details',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      _buildStatusBadge(),
                    ],
                  ),
                  const SizedBox(height: 24),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: const Color(0xFFE2E8F0),
                        width: 1,
                      ),
                    ),
                    child: Column(
                      children: [
                        _detailRow('Invoice No', invoice.invoiceNo),
                        const Divider(height: 24),
                        _detailRow('Customer', invoice.displayCustomer),
                        const Divider(height: 24),
                        _detailRow('Customer Code', invoice.customerCode),
                        const Divider(height: 24),
                        _detailRow('Date', invoice.displayDate),
                        const Divider(height: 24),
                        _detailRow(
                          'Total Amount',
                          '₱${invoice.totalAmount.toStringAsFixed(2)}',
                          isAmount: true,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () => Navigator.of(ctx).pop(),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.blueBright,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 0,
                      ),
                      child: const Text(
                        'Close',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _detailRow(String label, String value, {bool isAmount = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 14,
            color: AppColors.textMuted,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(width: 16),
        Flexible(
          child: Text(
            value,
            style: TextStyle(
              fontSize: isAmount ? 16 : 14,
              color: AppColors.textDark,
              fontWeight: isAmount ? FontWeight.bold : FontWeight.w600,
            ),
            textAlign: TextAlign.right,
          ),
        ),
      ],
    );
  }
}