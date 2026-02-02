import '../../../core/database/database_manager.dart';
import 'dap_model.dart';

class DapRepository {
  final DatabaseManager _dbManager = DatabaseManager();

  /// Get DAPs for a specific date AND specific user (salesman)
  Future<List<DapWithDetails>> getDapForDate(DateTime date, int userId) async {
    // Tasks DB (DAP, Task, MCP)
    final dbTasks = await _dbManager.getDatabase(DatabaseManager.dbTasks);
    // Customer DB (for resolving customer_name & customer_code)
    final dbCustomer = await _dbManager.getDatabase(DatabaseManager.dbCustomer);

    final dateStr = date.toIso8601String().split('T')[0];

    // Filter by MCP.user_id (owner of the plan) and date
    final dapResult = await dbTasks.rawQuery('''
      SELECT 
        dap.*,
        t.name AS task_name,
        mcp.user_id
      FROM daily_action_plan dap
      LEFT JOIN task t ON dap.task_id = t.id
      LEFT JOIN monthly_coverage_plan mcp ON dap.mcp_id = mcp.id
      WHERE dap.date LIKE ? AND mcp.user_id = ?
    ''', ['$dateStr%', userId]);

    // Collect all customer_ids from DAP rows
    final Set<int> customerIds = {};
    for (final row in dapResult) {
      final cid = row['customer_id'];
      if (cid is int) {
        customerIds.add(cid);
      }
    }

    // Build a map: customer_id -> { customer_name, customer_code }
    final Map<int, Map<String, String?>> customerMap = {};
    if (customerIds.isNotEmpty) {
      final placeholders = List.filled(customerIds.length, '?').join(',');
      final customerRows = await dbCustomer.rawQuery(
        'SELECT id, customer_name, customer_code FROM customer WHERE id IN ($placeholders)',
        customerIds.toList(),
      );

      for (final cRow in customerRows) {
        final id = cRow['id'];
        final name = cRow['customer_name'];
        final code = cRow['customer_code'];
        if (id is int) {
          customerMap[id] = {
            'customer_name': name is String ? name : null,
            'customer_code': code is String ? code : null,
          };
        }
      }
    }

    // Inject customer_name / customer_code into each DAP row and map to model
    return dapResult.map((row) {
      final newRow = Map<String, dynamic>.from(row);

      final cid = row['customer_id'];
      if (cid is int && customerMap.containsKey(cid)) {
        final cmap = customerMap[cid]!;
        newRow['customer_name'] = cmap['customer_name'];
        newRow['customer_code'] = cmap['customer_code'];
      } else {
        // No specific customer for this task
        // Keep customer_name null so DapWithDetails can fallback to additional_description
        newRow['customer_name'] = newRow['customer_name'] ?? '';
      }

      return DapWithDetails.fromSqlite(newRow);
    }).toList();
  }

  Future<void> toggleStatus(int dapId, bool currentStatus) async {
    final db = await _dbManager.getDatabase(DatabaseManager.dbTasks);
    await db.update(
      'daily_action_plan',
      {'is_completed': currentStatus ? 0 : 1},
      where: 'id = ?',
      whereArgs: [dapId],
    );
  }
}
