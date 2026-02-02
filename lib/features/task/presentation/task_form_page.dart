// lib/features/tasks/presentation/task_form_page.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/models/task_model.dart';
import '../../../providers/task_providers.dart';

class TaskFormPage extends ConsumerStatefulWidget {
  const TaskFormPage({super.key});

  @override
  ConsumerState<TaskFormPage> createState() => _TaskFormPageState();
}

class _TaskFormPageState extends ConsumerState<TaskFormPage> {
  final _formKey = GlobalKey<FormState>();

  final TextEditingController _titleCtrl = TextEditingController();
  final TextEditingController _customerCtrl = TextEditingController();
  final TextEditingController _notesCtrl = TextEditingController();

  DateTime? _dueDate;
  TaskPriority _priority = TaskPriority.normal;

  @override
  void dispose() {
    _titleCtrl.dispose();
    _customerCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDueDate() async {
    final now = DateTime.now();
    final result = await showDatePicker(
      context: context,
      initialDate: _dueDate ?? now,
      firstDate: now.subtract(const Duration(days: 365)),
      lastDate: now.add(const Duration(days: 365 * 2)),
    );

    if (result != null) {
      setState(() {
        _dueDate = result;
      });
    }
  }

  void _saveTask() {
    if (!_formKey.currentState!.validate()) return;

    final now = DateTime.now();

    final task = TaskModel(
      id: 'TASK-${now.microsecondsSinceEpoch}',
      title: _titleCtrl.text.trim(),
      customerName: _customerCtrl.text.trim(),
      priority: _priority,
      dueDate: _dueDate,
      notes: _notesCtrl.text.trim(),
      isCompleted: false,
      createdAt: now,
    );

    ref.read(taskListProvider.notifier).addTask(task);

    final df = DateFormat('MMM d, yyyy');
    final due = _dueDate != null ? df.format(_dueDate!) : 'No due date';

    final summary = StringBuffer()
      ..writeln('Title: ${task.title}')
      ..writeln('Customer: ${task.customerName.isEmpty ? "(none)" : task.customerName}')
      ..writeln('Priority: ${task.priority.name}')
      ..writeln('Due: $due')
      ..writeln('Notes: ${task.notes}');

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Task Saved (Demo)'),
        content: Text(
          summary.toString(),
          style: const TextStyle(fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop(); // dialog
              Navigator.of(context).pop(); // page
            },
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final df = DateFormat('MMM d, yyyy');
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('New Task'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: SingleChildScrollView(
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: AppColors.border,
                width: 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: AppColors.shadowBase.withOpacity(0.06),
                  blurRadius: 12,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            padding: const EdgeInsets.all(16),
            child: Form(
              key: _formKey,
              child: Column(
                children: [
                  TextFormField(
                    controller: _titleCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Task Title',
                    ),
                    validator: (val) {
                      if (val == null || val.trim().isEmpty) {
                        return 'Title is required';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 10),

                  TextFormField(
                    controller: _customerCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Customer (optional)',
                    ),
                  ),
                  const SizedBox(height: 10),

                  // Priority
                  DropdownButtonFormField<TaskPriority>(
                    decoration: const InputDecoration(
                      labelText: 'Priority',
                    ),
                    value: _priority,
                    items: const [
                      DropdownMenuItem(
                        value: TaskPriority.low,
                        child: Text('Low'),
                      ),
                      DropdownMenuItem(
                        value: TaskPriority.normal,
                        child: Text('Normal'),
                      ),
                      DropdownMenuItem(
                        value: TaskPriority.high,
                        child: Text('High'),
                      ),
                    ],
                    onChanged: (val) {
                      setState(() {
                        _priority = val ?? TaskPriority.normal;
                      });
                    },
                  ),
                  const SizedBox(height: 10),

                  // Due date
                  InkWell(
                    onTap: _pickDueDate,
                    borderRadius: BorderRadius.circular(8),
                    child: InputDecorator(
                      decoration: const InputDecoration(
                        labelText: 'Due Date',
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.calendar_today,
                            size: 18,
                            color: AppColors.textMuted,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            _dueDate != null
                                ? df.format(_dueDate!)
                                : 'Tap to select date',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: AppColors.textDark,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),

                  TextFormField(
                    controller: _notesCtrl,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      labelText: 'Notes (optional)',
                    ),
                  ),
                  const SizedBox(height: 20),

                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _saveTask,
                      child: const Text('Save Task (Demo Only)'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
