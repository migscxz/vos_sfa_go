import '../../../core/database/database_manager.dart';

class McpRepository {
  final DatabaseManager _dbManager = DatabaseManager();

  /// Returns a Map where Key = Day of Month (int), Value = Status (0=Unfinished, 1=Completed)
  /// We check the 'daily_action_plan' table for this because that's where the tasks and dates are.
  Future<Map<int, int>> getMcpStatus(int year, int month, int userId) async {
    final db = await _dbManager.getDatabase(DatabaseManager.dbTasks);

    // Format: '2025-11-%'
    final monthStr = month.toString().padLeft(2, '0');
    final datePattern = '$year-$monthStr-%';

    // We need to join MCP to filter by USER_ID (Salesman specific)
    // 1. Get all DAPs for this month for this user
    final result = await db.rawQuery('''
      SELECT 
        strftime('%d', dap.date) as day,
        dap.is_completed
      FROM daily_action_plan dap
      LEFT JOIN monthly_coverage_plan mcp ON dap.mcp_id = mcp.id
      WHERE dap.date LIKE ? AND mcp.user_id = ?
    ''', [datePattern, userId]);

    // 2. Process the logic in Dart
    // Map<Day, List<bool>>
    final Map<int, List<bool>> dailyStatusMap = {};

    for (var row in result) {
      final day = int.tryParse(row['day'] as String) ?? 0;
      final isCompleted = (row['is_completed'] as int) == 1;

      if (!dailyStatusMap.containsKey(day)) {
        dailyStatusMap[day] = [];
      }
      dailyStatusMap[day]!.add(isCompleted);
    }

    // 3. Determine Final Color per Day
    final Map<int, int> finalStatus = {};

    dailyStatusMap.forEach((day, statuses) {
      // If ANY task is false (unfinished), the whole day is unfinished (Red/0)
      // If ALL tasks are true, the day is completed (Green/1)
      if (statuses.contains(false)) {
        finalStatus[day] = 0; // Unfinished
      } else {
        finalStatus[day] = 1; // Completed
      }
    });

    return finalStatus;
  }
}