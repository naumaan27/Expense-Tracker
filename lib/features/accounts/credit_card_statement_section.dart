import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/money.dart';
import '../../core/theme/app_colors.dart';
import '../../data/database.dart';
import '../../data/providers.dart';
import 'credit_card_limit_service.dart';

/// Credit Card Hub: Manages Credit Card Limits, Utilization Tracking,
/// Health Warnings (Extensively Used / Over-limit), and Statement / Billing Cycle.
class CreditCardStatementSection extends ConsumerWidget {
  const CreditCardStatementSection({required this.account, super.key});

  final AccountRow account;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detail = ref.watch(creditCardDetailsProvider(account.id)).valueOrNull;
    final limit = ref.watch(creditCardLimitProvider(account.id)).valueOrNull;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // 1. Credit Limit & Utilization Card
        _CreditCardHealthCard(
          account: account,
          limit: limit,
          onEdit: () => _showCycleDialog(
            context,
            ref,
            existingDetail: detail,
            existingLimit: limit,
          ),
        ),

        // 2. Billing Cycle & Statement Tracking Card
        _BillingCycleCard(
          account: account,
          detail: detail,
          onToggle: (enable) => enable
              ? _showCycleDialog(
                  context,
                  ref,
                  existingDetail: null,
                  existingLimit: limit,
                )
              : _turnOffCycle(context, ref),
          onEdit: () => _showCycleDialog(
            context,
            ref,
            existingDetail: detail,
            existingLimit: limit,
          ),
        ),
      ],
    );
  }

  Future<void> _showCycleDialog(
    BuildContext context,
    WidgetRef ref, {
    required CreditCardDetailRow? existingDetail,
    required Money? existingLimit,
  }) async {
    final result = await showDialog<_CycleResult>(
      context: context,
      builder: (_) => _CreditCardCycleDialog(
        existingDetail: existingDetail,
        existingLimit: existingLimit,
      ),
    );
    if (result == null) return;

    if (result.limit != null && result.limit!.isPositive) {
      await ref
          .read(creditCardLimitServiceProvider)
          .setCreditLimit(account.id, result.limit!);
    }

    if (result.trackCycle) {
      await ref
          .read(dbProvider)
          .upsertCreditCardDetails(
            accountId: account.id,
            statementDay: result.statementDay,
            dueDay: result.dueDay,
            notifyDaysBefore: result.notifyDaysBefore,
          );
    }
  }

  Future<void> _turnOffCycle(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Stop tracking this card\'s cycle?'),
        content: const Text(
          'The statement close day, due day and reminders will be removed. '
          'Your card balance and credit limit remain unchanged.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Turn off'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await ref.read(dbProvider).deleteCreditCardDetails(account.id);
  }
}

/// Card presenting Total Limit, Amount Utilized, Available Credit, Progress Bar,
/// and Warning Signs when extensively utilized.
class _CreditCardHealthCard extends StatelessWidget {
  const _CreditCardHealthCard({
    required this.account,
    required this.limit,
    required this.onEdit,
  });

  final AccountRow account;
  final Money? limit;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final owed = account.currentBalance.isNegative ? account.currentBalance.abs : const Money.zero();

    final hasLimit = limit != null && limit!.isPositive;
    final util = hasLimit
        ? CreditCardUtilization(limit: limit!, utilized: owed)
        : null;

    return Card(
      margin: const EdgeInsets.fromLTRB(20, 8, 20, 8),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(
          color: util?.status == CreditHealthStatus.extensivelyUsed ||
                  util?.status == CreditHealthStatus.overLimit
              ? util!.statusColor.withValues(alpha: 0.5)
              : cs.outlineVariant,
          width: util?.status == CreditHealthStatus.extensivelyUsed ||
                  util?.status == CreditHealthStatus.overLimit
              ? 1.5
              : 1.0,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Header: Title + Edit Button
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: cs.primaryContainer.withValues(alpha: 0.6),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(Icons.credit_card_rounded, size: 20, color: cs.primary),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Card Limit & Utilization',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (hasLimit)
                        Text(
                          '${util!.percentage.toStringAsFixed(1)}% utilized',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: util.statusColor,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                    ],
                  ),
                ),
                TextButton.icon(
                  onPressed: onEdit,
                  icon: const Icon(Icons.edit_outlined, size: 16),
                  label: Text(hasLimit ? 'Edit' : 'Set Limit'),
                  style: TextButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            if (hasLimit) ...[
              // 3-Column Metrics: Limit, Utilized, Available
              Container(
                padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                decoration: BoxDecoration(
                  color: cs.surfaceContainerHighest.withValues(alpha: 0.35),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _metricColumn(
                      theme,
                      'Total Limit',
                      MoneyFormat.symbol(limit!),
                      cs.onSurface,
                    ),
                    _divider(theme),
                    _metricColumn(
                      theme,
                      'Utilized',
                      MoneyFormat.symbol(owed),
                      util!.statusColor,
                    ),
                    _divider(theme),
                    _metricColumn(
                      theme,
                      'Available',
                      MoneyFormat.symbol(util.available),
                      AppColors.income,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Progress Bar
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: LinearProgressIndicator(
                  value: util.ratio.clamp(0.0, 1.0),
                  minHeight: 10,
                  backgroundColor: cs.surfaceContainerHighest,
                  valueColor: AlwaysStoppedAnimation<Color>(util.statusColor),
                ),
              ),
              const SizedBox(height: 6),

              // Benchmark Legend
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('0%', style: theme.textTheme.labelSmall?.copyWith(color: cs.onSurfaceVariant)),
                  Text(
                    '30% Recommended',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: cs.onSurfaceVariant,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  Text('100% Limit', style: theme.textTheme.labelSmall?.copyWith(color: cs.onSurfaceVariant)),
                ],
              ),
              const SizedBox(height: 14),

              // Warning or Health Banner
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: util.statusColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: util.statusColor.withValues(alpha: 0.3)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(util.statusIcon, size: 20, color: util.statusColor),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            util.statusBadgeLabel,
                            style: theme.textTheme.labelMedium?.copyWith(
                              color: util.statusColor,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            util.warningMessage,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: cs.onSurface,
                              height: 1.3,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ] else ...[
              // Prompt to set limit
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: cs.surfaceContainerHighest.withValues(alpha: 0.35),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline_rounded, color: cs.primary, size: 22),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Set your card limit to see real-time credit utilization and receive warnings when spending is too high.',
                        style: theme.textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _metricColumn(ThemeData theme, String label, String value, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: theme.textTheme.labelSmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }

  Widget _divider(ThemeData theme) {
    return Container(
      width: 1,
      height: 28,
      color: theme.colorScheme.outlineVariant,
    );
  }
}

/// Card presenting Billing Cycle, Statement Close Day, and Payment Due Date.
class _BillingCycleCard extends StatelessWidget {
  const _BillingCycleCard({
    required this.account,
    required this.detail,
    required this.onToggle,
    required this.onEdit,
  });

  final AccountRow account;
  final CreditCardDetailRow? detail;
  final ValueChanged<bool> onToggle;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Card(
      margin: const EdgeInsets.fromLTRB(20, 4, 20, 8),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: cs.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SwitchListTile(
            title: const Text('Track statement & due date'),
            subtitle: Text(
              detail != null
                  ? "Know when this month's bill is generated and when payment is due."
                  : 'Set statement closing date and bill payment due date.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: cs.onSurfaceVariant,
              ),
            ),
            value: detail != null,
            onChanged: onToggle,
          ),
          if (detail != null) ...[
            const Divider(height: 1, indent: 16),
            _StatementSummary(account: account, detail: detail!),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed: onEdit,
                  icon: const Icon(Icons.edit_calendar_outlined, size: 16),
                  label: const Text('Edit Cycle'),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _StatementSummary extends ConsumerWidget {
  const _StatementSummary({required this.account, required this.detail});

  final AccountRow account;
  final CreditCardDetailRow detail;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final period = ref.watch(creditCardStatementPeriodProvider(account.id))!;
    final dueDate = ref.watch(creditCardNextDueDateProvider(account.id))!;
    final daysLeft = dueDate.difference(DateTime.now()).inDays;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: _row(
                  theme,
                  'Statement / Billing Date',
                  'The ${_ordinal(detail.statementDay)} of every month',
                ),
              ),
              Expanded(
                child: _row(
                  theme,
                  'Payment Due Date',
                  '${DateFormat('d MMM yyyy').format(dueDate)} (${_dueInLabel(daysLeft)})',
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _row(
            theme,
            'Current Statement Period',
            '${DateFormat('d MMM').format(period.start)} – ${DateFormat('d MMM').format(period.end)}',
          ),
        ],
      ),
    );
  }

  Widget _row(ThemeData theme, String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: theme.textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  String _dueInLabel(int daysLeft) {
    if (daysLeft < 0) return 'overdue';
    if (daysLeft == 0) return 'today';
    if (daysLeft == 1) return 'tomorrow';
    return 'in $daysLeft days';
  }

  String _ordinal(int day) {
    if (day >= 11 && day <= 13) return '${day}th';
    switch (day % 10) {
      case 1:
        return '${day}st';
      case 2:
        return '${day}nd';
      case 3:
        return '${day}rd';
      default:
        return '${day}th';
    }
  }
}

typedef _CycleResult = ({
  int statementDay,
  int dueDay,
  int notifyDaysBefore,
  Money? limit,
  bool trackCycle,
});

/// Dialog to edit Card Limit, Statement Date, and Due Date.
class _CreditCardCycleDialog extends StatefulWidget {
  const _CreditCardCycleDialog({
    required this.existingDetail,
    required this.existingLimit,
  });

  final CreditCardDetailRow? existingDetail;
  final Money? existingLimit;

  @override
  State<_CreditCardCycleDialog> createState() => _CreditCardCycleDialogState();
}

class _CreditCardCycleDialogState extends State<_CreditCardCycleDialog> {
  late final TextEditingController _limitController;
  late int _statementDay = widget.existingDetail?.statementDay ?? 1;
  late int _dueDay = widget.existingDetail?.dueDay ?? 20;
  late double _notifyDays = (widget.existingDetail?.notifyDaysBefore ?? 3).toDouble();

  @override
  void initState() {
    super.initState();
    _limitController = TextEditingController(
      text: widget.existingLimit != null && widget.existingLimit!.isPositive
          ? MoneyFormat.formatWithCommas(widget.existingLimit!.rupees.toStringAsFixed(0))
          : '',
    );
  }

  @override
  void dispose() {
    _limitController.dispose();
    super.dispose();
  }

  Future<void> _pickDay({required bool forStatement}) async {
    final initialDay = forStatement ? _statementDay : _dueDay;
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime(now.year, now.month, initialDay.clamp(1, 28)),
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 1),
    );
    if (picked == null || !mounted) return;
    setState(() {
      if (forStatement) {
        _statementDay = picked.day;
      } else {
        _dueDay = picked.day;
      }
    });
  }

  String _ordinal(int day) {
    if (day >= 11 && day <= 13) return '${day}th';
    switch (day % 10) {
      case 1:
        return '${day}st';
      case 2:
        return '${day}nd';
      case 3:
        return '${day}rd';
      default:
        return '${day}th';
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return AlertDialog(
      title: const Text('Credit Card Settings'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Card Limit
            TextField(
              controller: _limitController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [ThousandsSeparatorInputFormatter()],
              decoration: const InputDecoration(
                labelText: 'Total Card Limit',
                hintText: 'e.g. 100,000',
                prefixIcon: Icon(Icons.credit_card_rounded),
              ),
            ),
            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 8),

            Text(
              'BILLING CYCLE & REMINDERS',
              style: theme.textTheme.labelSmall?.copyWith(
                color: cs.primary,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.1,
              ),
            ),
            const SizedBox(height: 8),

            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Statement / Billing Date'),
              subtitle: Text('The ${_ordinal(_statementDay)} of each month'),
              trailing: const Icon(Icons.calendar_month_outlined),
              onTap: () => _pickDay(forStatement: true),
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Payment Due Date'),
              subtitle: Text('The ${_ordinal(_dueDay)} of each month'),
              trailing: const Icon(Icons.calendar_month_outlined),
              onTap: () => _pickDay(forStatement: false),
            ),
            const SizedBox(height: 8),
            Text(
              'Notify me ${_notifyDays.round()} '
              'day${_notifyDays.round() == 1 ? '' : 's'} before payment due',
              style: theme.textTheme.bodyMedium,
            ),
            Slider(
              value: _notifyDays,
              min: 0,
              max: 7,
              divisions: 7,
              label: '${_notifyDays.round()}',
              onChanged: (v) => setState(() => _notifyDays = v),
            ),
            Text(
              'A shorter month snaps the close/due day to its last day, '
              'then returns once that day exists again.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: cs.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () {
            final limit = Money.tryParse(_limitController.text);
            Navigator.of(context).pop((
              statementDay: _statementDay,
              dueDay: _dueDay,
              notifyDaysBefore: _notifyDays.round(),
              limit: limit,
              trackCycle: true,
            ));
          },
          child: const Text('Save'),
        ),
      ],
    );
  }
}
