import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/money.dart';
import '../../data/database.dart';
import '../../data/providers.dart';
import '../../data/tables.dart' show CategoryKind;
import '../transactions/transaction_link_picker_sheet.dart';
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
  bool _keepAsStarter = false;
  int? _linkedTransactionId;

  @override
  void initState() {
    super.initState();
    // Pre-fill with remaining pending amount if positive
    final defaultPaise = widget.pendingAmount.isPositive ? widget.pendingAmount.paise : 0;
    _amountController = TextEditingController(
      text: defaultPaise > 0
          ? MoneyFormat.formatWithCommas((defaultPaise / 100).toStringAsFixed(2))
          : '',
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
    if (_linkedTransactionId == null && !_keepAsStarter && _selectedAccountId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select an account where money was received.')),
      );
      return;
    }

    final cleanText = _amountController.text.replaceAll(',', '').trim();
    final parsedAmount = double.tryParse(cleanText);
    if (parsedAmount == null || parsedAmount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid payment amount.')),
      );
      return;
    }

    setState(() => _submitting = true);
    try {
      final repo = ref.read(projectsRepositoryProvider);
      final money = Money.fromRupees(parsedAmount);

      if (_linkedTransactionId != null) {
        await repo.recordExistingPayment(
          project: widget.project,
          amount: money,
          transactionId: _linkedTransactionId!,
          date: _paymentDate,
          note: _noteController.text.trim().isEmpty ? null : _noteController.text.trim(),
        );
      } else {
        await repo.recordPayment(
          project: widget.project,
          amount: money,
          accountId: _keepAsStarter ? null : _selectedAccountId,
          categoryId: _keepAsStarter ? null : _selectedCategoryId,
          date: _paymentDate,
          note: _noteController.text.trim().isEmpty ? null : _noteController.text.trim(),
        );
      }

      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _linkedTransactionId != null
                  ? 'Linked past transaction to project (no duplicate money created)!'
                  : _keepAsStarter
                      ? 'Recorded ${MoneyFormat.symbol(money)} as project starter (not added to account).'
                      : 'Recorded ${MoneyFormat.symbol(money)} received! Added to your account.',
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
    final accounts = ref.watch(accountsProvider).valueOrNull ?? const <AccountRow>[];
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
                  labelText: 'Amount Received *',
                  hintText: '0.00',
                  prefixIcon: Icon(Icons.add_circle_outline_rounded, color: Colors.green),
                  border: OutlineInputBorder(),
                ),
                validator: (val) {
                  if (val == null || val.trim().isEmpty) return 'Enter the amount received';
                  final num = double.tryParse(val.replaceAll(',', '').trim());
                  if (num == null || num <= 0) return 'Enter a positive amount';
                  return null;
                },
              ),
              const SizedBox(height: 8),

              // Link past transaction button
              OutlinedButton.icon(
                icon: const Icon(Icons.link_rounded, size: 18),
                label: Text(
                  _linkedTransactionId != null
                      ? 'Linked to Transaction #$_linkedTransactionId (Tap to Change)'
                      : 'Already logged this in Accounts? Link past transaction',
                  style: const TextStyle(fontSize: 12),
                ),
                style: OutlinedButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                ),
                onPressed: () async {
                  final pickedTxId = await showModalBottomSheet<int>(
                    context: context,
                    isScrollControlled: true,
                    builder: (_) => const TransactionLinkPickerSheet(excludeIds: {}),
                  );
                  if (pickedTxId != null) {
                    final db = ref.read(dbProvider);
                    final tx = await db.transactionById(pickedTxId);
                    if (tx != null) {
                      setState(() {
                        _linkedTransactionId = tx.id;
                        _amountController.text = MoneyFormat.formatWithCommas(
                          (tx.amount.paise / 100).toStringAsFixed(2),
                        );
                        _paymentDate = tx.date;
                        _selectedAccountId = tx.accountId;
                        if (tx.note != null && tx.note!.isNotEmpty && _noteController.text.isEmpty) {
                          _noteController.text = tx.note!;
                        }
                      });
                    }
                  }
                },
              ),
              if (_linkedTransactionId != null) ...[
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.blue.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.blue.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.info_outline, size: 16, color: Colors.blue),
                      const SizedBox(width: 8),
                      const Expanded(
                        child: Text(
                          'Linked to past transaction. No duplicate income will be created.',
                          style: TextStyle(fontSize: 12, color: Colors.blue),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, size: 14),
                        onPressed: () => setState(() => _linkedTransactionId = null),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 14),

              if (_linkedTransactionId == null) ...[
                // Starter Toggle Card
                Card(
                  elevation: 0,
                  color: _keepAsStarter
                      ? cs.primaryContainer.withValues(alpha: 0.35)
                      : cs.surfaceContainerHighest.withValues(alpha: 0.35),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  child: SwitchListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
                    secondary: Icon(
                      _keepAsStarter ? Icons.bookmark_added_outlined : Icons.account_balance_wallet_outlined,
                      color: _keepAsStarter ? cs.primary : cs.onSurfaceVariant,
                    ),
                    title: const Text('Keep as project starter', style: TextStyle(fontWeight: FontWeight.w600)),
                    subtitle: Text(
                      _keepAsStarter
                          ? 'Tracks progress in project only — will not be added to your account ledger yet'
                          : 'Deposits payment as an income transaction into your account',
                      style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
                    ),
                    value: _keepAsStarter,
                    onChanged: (val) => setState(() => _keepAsStarter = val),
                  ),
                ),
                const SizedBox(height: 14),
              ],

              if (_linkedTransactionId == null && !_keepAsStarter) ...[
                // Account Picker
                DropdownButtonFormField<int>(
                  initialValue: _selectedAccountId,
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
                  initialValue: _selectedCategoryId,
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
              ],

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
