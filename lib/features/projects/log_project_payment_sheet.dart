import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/money.dart';
import '../../data/database.dart';
import '../../data/providers.dart';
import '../../data/tables.dart' show CategoryKind;
import 'project_model.dart';
import 'projects_repository.dart';

class LogProjectPaymentSheet extends ConsumerStatefulWidget {
  const LogProjectPaymentSheet({
    super.key,
    required this.project,
    required this.pendingAmount,
  });

  final Project project;
  final Money pendingAmount;

  @override
  ConsumerState<LogProjectPaymentSheet> createState() => _LogProjectPaymentSheetState();
}

class _LogProjectPaymentSheetState extends ConsumerState<LogProjectPaymentSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _amountController;
  final _noteController = TextEditingController();

  int? _selectedAccountId;
  int? _selectedCategoryId;
  DateTime _paymentDate = DateTime.now();
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    // Pre-fill with remaining pending amount if positive
    final defaultPaise = widget.pendingAmount.isPositive ? widget.pendingAmount.paise : 0;
    _amountController = TextEditingController(
      text: defaultPaise > 0 ? (defaultPaise / 100).toStringAsFixed(2) : '',
    );
  }

  @override
  void dispose() {
    _amountController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _paymentDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 30)),
    );
    if (picked != null) {
      setState(() => _paymentDate = picked);
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedAccountId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select an account where money was received.')),
      );
      return;
    }

    final parsedAmount = double.tryParse(_amountController.text.trim());
    if (parsedAmount == null || parsedAmount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid payment amount.')),
      );
      return;
    }

    setState(() => _submitting = true);
    try {
      final repo = ref.read(projectsRepositoryProvider);
      final money = Money.fromUnits(parsedAmount);

      await repo.recordPayment(
        project: widget.project,
        amount: money,
        accountId: _selectedAccountId!,
        categoryId: _selectedCategoryId,
        date: _paymentDate,
        note: _noteController.text.trim().isEmpty ? null : _noteController.text.trim(),
      );

      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Recorded ${MoneyFormat.full(money)} received! Added to your account.',
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to record payment: $e')),
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
    final incomeCategories =
        ref.watch(categoriesProvider(CategoryKind.income)).valueOrNull ??
            const <CategoryRow>[];

    // Default account to first active account if not set
    if (_selectedAccountId == null && accounts.isNotEmpty) {
      final active = accounts.where((a) => !a.isArchived).toList();
      if (active.isNotEmpty) {
        _selectedAccountId = active.first.id;
      }
    }

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
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Record Payment Received',
                          style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          widget.project.title,
                          style: theme.textTheme.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: cs.surfaceContainerHighest.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Total Quote: ${MoneyFormat.compact(widget.project.quoteAmount)}'),
                    Text(
                      'Pending: ${MoneyFormat.compact(widget.pendingAmount)}',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: widget.pendingAmount.isPositive ? Colors.amber[800] : Colors.green,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Amount
              TextFormField(
                controller: _amountController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  labelText: 'Amount Received *',
                  hintText: '0.00',
                  prefixIcon: Icon(Icons.add_circle_outline_rounded, color: Colors.green),
                  border: OutlineInputBorder(),
                ),
                validator: (val) {
                  if (val == null || val.trim().isEmpty) return 'Enter the amount received';
                  final num = double.tryParse(val.trim());
                  if (num == null || num <= 0) return 'Enter a positive amount';
                  return null;
                },
              ),
              const SizedBox(height: 14),

              // Account Picker
              DropdownButtonFormField<int>(
                value: _selectedAccountId,
                decoration: const InputDecoration(
                  labelText: 'Deposit into Account *',
                  prefixIcon: Icon(Icons.account_balance_rounded),
                  border: OutlineInputBorder(),
                ),
                items: [
                  for (final a in accounts.where((a) => !a.isArchived))
                    DropdownMenuItem<int>(
                      value: a.id,
                      child: Text(a.name),
                    ),
                ],
                onChanged: (val) => setState(() => _selectedAccountId = val),
              ),
              const SizedBox(height: 14),

              // Category Picker (Optional)
              DropdownButtonFormField<int?>(
                value: _selectedCategoryId,
                decoration: const InputDecoration(
                  labelText: 'Income Category (Optional)',
                  prefixIcon: Icon(Icons.category_outlined),
                  border: OutlineInputBorder(),
                ),
                items: [
                  const DropdownMenuItem<int?>(
                    value: null,
                    child: Text('None / General Income'),
                  ),
                  for (final c in incomeCategories)
                    DropdownMenuItem<int?>(
                      value: c.id,
                      child: Text(c.name),
                    ),
                ],
                onChanged: (val) => setState(() => _selectedCategoryId = val),
              ),
              const SizedBox(height: 14),

              // Date
              OutlinedButton.icon(
                onPressed: _pickDate,
                icon: const Icon(Icons.calendar_today_outlined, size: 18),
                label: Text('Payment Date: ${DateFormat('d MMM yyyy').format(_paymentDate)}'),
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
                  labelText: 'Payment Note / Milestone Details (Optional)',
                  hintText: 'e.g. 50% Advance, Milestone 2: Dark mode & API revisions, Final payment',
                  prefixIcon: Icon(Icons.description_outlined),
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 20),

              FilledButton(
                onPressed: _submitting ? null : _submit,
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.green[700],
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                child: _submitting
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                      )
                    : const Text(
                        'Confirm & Deposit Income',
                        style: TextStyle(fontSize: 16, color: Colors.white, fontWeight: FontWeight.bold),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
