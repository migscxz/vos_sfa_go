// lib/data/models/task_model.dart
enum TaskPriority {
  low,
  normal,
  high,
}

class TaskModel {
  final String id;
  final String title;
  final String customerName;
  final TaskPriority priority;
  final DateTime? dueDate;
  final String notes;
  final bool isCompleted;
  final DateTime createdAt;

  TaskModel({
    required this.id,
    required this.title,
    required this.customerName,
    required this.priority,
    required this.dueDate,
    required this.notes,
    required this.isCompleted,
    required this.createdAt,
  });

  TaskModel copyWith({
    String? id,
    String? title,
    String? customerName,
    TaskPriority? priority,
    DateTime? dueDate,
    String? notes,
    bool? isCompleted,
    DateTime? createdAt,
  }) {
    return TaskModel(
      id: id ?? this.id,
      title: title ?? this.title,
      customerName: customerName ?? this.customerName,
      priority: priority ?? this.priority,
      dueDate: dueDate ?? this.dueDate,
      notes: notes ?? this.notes,
      isCompleted: isCompleted ?? this.isCompleted,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
