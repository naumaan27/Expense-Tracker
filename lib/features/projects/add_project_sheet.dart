import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/money.dart';
import 'project_model.dart';
import 'projects_repository.dart';

class AddProjectSheet extends ConsumerStatefulWidget {
  const AddProjectSheet({super.key, this.existingProject});

  final Project? existingProject;

  @override
  ConsumerState<AddProjectSheet> createState() => _AddProjectSheetState();
}

class _AddProjectSheetState extends ConsumerState<AddProjectSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _titleController;
  late final TextEditingController _clientController;
  late final TextEditingController _amountController;
  late final TextEditingController _noteController;

  late String _selectedStream;
  DateTime? _dueDate;
  bool _submitting = false;
  final List<String> _customStreams = [];

  bool get _isEditing => widget.existingProject != null;

  final List<String> _suggestedStreams = const [
    'Freelancing',
    'Teaching',
    'Consulting',
    'Design',
    'Development',
    'Writing',
  ];

  @override
  void initState() {
    super.initState();
    final p = widget.existingProject;
    _titleController = TextEditingController(text: p?.title ?? '');
    _clientController = TextEditingController(text: p?.clientName ?? '');
    _amountController = TextEditingController(
      text: p != null
          ? MoneyFormat.formatWithCommas(
              p.quoteAmount.paise % 100 == 0
                  ? '${p.quoteAmount.paise ~/ 100}'
                  : (p.quoteAmount.paise / 100).toStringAsFixed(2),
            )
          : '',
    );
    _noteController = TextEditingController(text: p?.note ?? '');
    _selectedStream = p?.stream ?? 'Freelancing';
    _dueDate = p?.dueDate;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _clientController.dispose();
    _amountController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _showAddCustomStreamDialog() async {
    final controller = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('New Income Stream'),
        content: TextField(
          controller: controller,
          autofocus: true,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(
            labelText: 'Stream Name',
            hintText: 'e.g. Photography, Mentorship, YouTube',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              final val = controller.text.trim();
              if (val.isNotEmpty) {
                Navigator.of(ctx).pop(val);
              }
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );

    if (result != null && result.isNotEmpty) {
      setState(() {
        if (!_customStreams.contains(result)) {
          _customStreams.add(result);
        }
        _selectedStream = result;
      });
    }
  }

  Future<void> _pickDueDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _dueDate ?? now.add(const Duration(days: 14)),
      firstDate: now.subtract(const Duration(days: 365)),
      lastDate: now.add(const Duration(days: 365 * 5)),
    );
    if (picked != null) {
      setState(() => _dueDate = picked);
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final cleanText = _amountController.text.replaceAll(',', '').trim();
    final parsedAmount = double.tryParse(cleanText);
    if (parsedAmount == null || parsedAmount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid quote amount.')),
      );
      return;
    }

    setState(() => _submitting = true);
    try {
      final repo = ref.read(projectsRepositoryProvider);
      final money = Money.fromRupees(parsedAmount);

      if (_isEditing) {
        await repo.updateProject(
          id: widget.existingProject!.id,
          title: _titleController.text.trim(),
          clientName: _clientController.text.trim(),
          stream: _selectedStream,
          quoteAmount: money,
          dueDate: _dueDate,
          note: _noteController.text.trim().isEmpty ? null : _noteController.text.trim(),
        );
      } else {
        await repo.createProject(
          title: _titleController.text.trim(),
          clientName: _clientController.text.trim(),
          stream: _selectedStream,
          quoteAmount: money,
          dueDate: _dueDate,
          note: _noteController.text.trim().isEmpty ? null : _noteController.text.trim(),
        );
      }

      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _isEditing ? 'Project quote & details updated!' : 'Project / Quote created!',
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save project: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    final allProjects = ref.watch(allProjectsStreamProvider).valueOrNull ?? const <Project>[];
    final existingStreams = allProjects.map((p) => p.stream).toSet();
    final allStreams = {
      ..._suggestedStreams,
      ...existingStreams,
      ..._customStreams,
      if (_selectedStream.isNotEmpty) _selectedStream,
    }.toList();

    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    _isEditing ? 'Edit Project / Revise Quote' : 'New Project / Quote',
                    style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                'Add a client quote or income stream. This never deducts money from your accounts.',
                style: theme.textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant),
              ),
              const SizedBox(height: 18),

              // Title
              TextFormField(
                controller: _titleController,
                decoration: const InputDecoration(
                  labelText: 'Project Title *',
                  hintText: 'e.g. Website Redesign, Physics Batch 1',
                  prefixIcon: Icon(Icons.work_outline_rounded),
                  border: OutlineInputBorder(),
                ),
                validator: (val) =>
                    (val == null || val.trim().isEmpty) ? 'Please enter a project title' : null,
              ),
              const SizedBox(height: 14),

              // Client Name
              TextFormField(
                controller: _clientController,
                decoration: const InputDecoration(
                  labelText: 'Client / Student Name *',
                  hintText: 'e.g. Acme Corp, Rahul Sharma',
                  prefixIcon: Icon(Icons.person_outline_rounded),
                  border: OutlineInputBorder(),
                ),
                validator: (val) =>
                    (val == null || val.trim().isEmpty) ? 'Please enter a client name' : null,
              ),
              const SizedBox(height: 14),

              // Income Stream Picker
              Text(
                'Income Stream',
                style: theme.textTheme.labelMedium?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 4,
                children: [
                  ...allStreams.map((stream) {
                    final isSelected = _selectedStream == stream;
                    return ChoiceChip(
                      label: Text(stream),
                      selected: isSelected,
                      onSelected: (selected) {
                        if (selected) setState(() => _selectedStream = stream);
                      },
                    );
                  }),
                  ActionChip(
                    avatar: const Icon(Icons.add_rounded, size: 18),
                    label: const Text('Custom Stream'),
                    onPressed: _showAddCustomStreamDialog,
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // Quote Amount
              TextFormField(
                controller: _amountController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: const [ThousandsSeparatorInputFormatter()],
                onChanged: (val) {
                  final formatted = MoneyFormat.formatWithCommas(val);
                  if (formatted != val) {
                    _amountController.value = TextEditingValue(
                      text: formatted,
                      selection: TextSelection.collapsed(offset: formatted.length),
                      composing: TextRange.empty,
                    );
                  }
                },
                decoration: const InputDecoration(
                  labelText: 'Total Quote Amount *',
                  hintText: '0.00',
                  prefixIcon: Icon(Icons.payments_outlined),
                  border: OutlineInputBorder(),
                ),
                validator: (val) {
                  if (val == null || val.trim().isEmpty) return 'Please enter the quoted amount';
                  final num = double.tryParse(val.replaceAll(',', '').trim());
                  if (num == null || num <= 0) return 'Enter a positive amount';
                  return null;
                },
              ),
              const SizedBox(height: 14),

              // Deadline / Due Date
              OutlinedButton.icon(
                onPressed: _pickDueDate,
                icon: const Icon(Icons.calendar_today_outlined, size: 18),
                label: Text(
                  _dueDate == null
                      ? 'Set Deadline (Optional)'
                      : 'Deadline: ${DateFormat('d MMM yyyy').format(_dueDate!)}',
                ),
                style: OutlinedButton.styleFrom(
                  alignment: Alignment.centerLeft,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                ),
              ),
              const SizedBox(height: 14),

              // Note
              TextFormField(
                controller: _noteController,
                maxLines: 2,
                decoration: const InputDecoration(
                  labelText: 'Notes / Scope (Optional)',
                  hintText: 'Deliverables, payment terms, or milestone details',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 20),

              FilledButton(
                onPressed: _submitting ? null : _submit,
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                child: _submitting
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(
                        _isEditing ? 'Save Revised Quote' : 'Create Project / Quote',
                        style: const TextStyle(fontSize: 16),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
