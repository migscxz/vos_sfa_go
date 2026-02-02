// lib/providers/task_providers.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/models/task_model.dart';

class TaskListNotifier extends StateNotifier<List<TaskModel>> {
  TaskListNotifier() : super(const []);

  void addTask(TaskModel task) {
    state = [...state, task];
  }

  void toggleComplete(String taskId) {
    state = [
      for (final t in state)
        if (t.id == taskId)
          t.copyWith(isCompleted: !t.isCompleted)
        else
          t,
    ];
  }

  void clearAll() {
    state = const [];
  }
}

final taskListProvider =
StateNotifierProvider<TaskListNotifier, List<TaskModel>>(
      (ref) => TaskListNotifier(),
);
