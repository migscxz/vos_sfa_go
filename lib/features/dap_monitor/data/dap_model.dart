class DapWithDetails {
  final int id;
  final int? taskId;               // daily_action_plan.task_id
  final int? mcpId;                // daily_action_plan.mcp_id
  final int? customerId;           // daily_action_plan.customer_id

  final String taskName;           // joined from task.name AS task_name
  final String accountName;        // either customer_name or additional_description
  final String? customerCode;      // from customer.customer_code (if joined)

  final String priority;           // daily_action_plan.priority_level
  final bool isCompleted;          // daily_action_plan.is_completed
  final DateTime date;             // daily_action_plan.date
  final String? additionalDescription; // daily_action_plan.additional_description

  DapWithDetails({
    required this.id,
    required this.taskId,
    required this.mcpId,
    required this.customerId,
    required this.taskName,
    required this.accountName,
    required this.customerCode,
    required this.priority,
    required this.isCompleted,
    required this.date,
    required this.additionalDescription,
  });

  factory DapWithDetails.fromSqlite(Map<String, dynamic> row) {
    final rawDate = row['date'] as String?;
    final parsedDate = (rawDate != null && rawDate.isNotEmpty)
        ? DateTime.tryParse(rawDate)
        : null;

    // Decide what to show in the "Accounts" column:
    // 1) Prefer customer_name
    // 2) Else use additional_description
    // 3) Else fallback text
    String resolvedAccountName;
    final customerName = row['customer_name'] as String?;
    final addlDesc = row['additional_description'] as String?;

    if (customerName != null && customerName.isNotEmpty) {
      resolvedAccountName = customerName;
    } else if (addlDesc != null && addlDesc.isNotEmpty) {
      resolvedAccountName = addlDesc;
    } else {
      resolvedAccountName = 'General Task';
    }

    return DapWithDetails(
      id: row['id'] as int,
      taskId: row['task_id'] as int?,
      mcpId: row['mcp_id'] as int?,
      customerId: row['customer_id'] as int?,
      taskName: row['task_name'] ?? 'Unknown Task',
      accountName: resolvedAccountName,
      customerCode: row['customer_code'] as String?,
      priority: row['priority_level'] ?? 'mid',
      isCompleted: (row['is_completed'] == 1),
      date: parsedDate ?? DateTime.now(),
      additionalDescription: addlDesc,
    );
  }
}
