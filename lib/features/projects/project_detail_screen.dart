import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/money.dart';
import '../../core/widgets/error_view.dart';
import '../../data/database.dart';
import '../../data/providers.dart';
import '../../data/tables.dart' show CategoryKind;
import '../transactions/transaction_link_picker_sheet.dart';
import 'add_project_sheet.dart';
import 'log_project_payment_sheet.dart';
import 'project_model.dart';
import 'projects_repository.dart';

class ProjectDetailScreen extends ConsumerWidget {
  const ProjectDetailScreen({super.key, required this.projectId});

  final int projectId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final repo = ref.watch(projectsRepositoryProvider);

    final projectsAsync = ref.watch(allProjectsStreamProvider);
    final paymentsAsync = ref.watch(projectPaymentsStreamProvider(projectId));

    return projectsAsync.when(
      loading: () => const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (e, _) => Scaffold(
        body: ErrorView(
          title: 'Failed to load project',
          message: e.toString(),
        ),
      ),
      data: (projects) {
        final project = projects.where((p) => p.id == projectId).firstOrNull;
        if (project == null) {
          return Scaffold(
            appBar: AppBar(title: const Text('Project Details')),
            body: const Center(child: Text('Project not found or deleted.')),
          );
        }

        final payments = paymentsAsync.valueOrNull ?? const <ProjectPayment>[];
        final totalReceivedPaise = payments.fold<int>(0, (sum, p) => sum + p.amount.paise);
        final totalReceived = Money(totalReceivedPaise);
        final pendingPaise = project.quoteAmount.paise - totalReceivedPaise;
        final pendingAmount = Money(pendingPaise > 0 ? pendingPaise : 0);
        final progress = project.quoteAmount.paise > 0
            ? (totalReceivedPaise / project.quoteAmount.paise).clamp(0.0, 1.0)
            : 0.0;
        final percentStr = (progress * 100).toInt();

        final isCompleted = project.status == ProjectStatus.completed;

        return Scaffold(
          appBar: AppBar(
            title: Text(project.title),
            actions: [
              IconButton(
                icon: const Icon(Icons.edit_outlined),
                tooltip: 'Edit / Revise Quote',
                onPressed: () {
                  showModalBottomSheet(
                    context: context,
                    isScrollControlled: true,
                    builder: (_) => AddProjectSheet(existingProject: project),
                  );
                },
              ),
              PopupMenuButton<String>(
                onSelected: (val) async {
                  if (val == 'edit') {
                    showModalBottomSheet(
                      context: context,
                      isScrollControlled: true,
                      builder: (_) => AddProjectSheet(existingProject: project),
                    );
                  } else if (val == 'toggle_status') {
                    final nextStatus = isCompleted ? ProjectStatus.active : ProjectStatus.completed;
                    await repo.updateProjectStatus(project.id, nextStatus);
                  } else if (val == 'delete') {
                    final confirm = await showDialog<bool>(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        title: const Text('Delete Project?'),
                        content: Text(
                          'Delete "${project.title}"? Logged income transactions in your ledger will not be removed.',
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.of(ctx).pop(false),
                            child: const Text('Cancel'),
                          ),
                          TextButton(
                            onPressed: () => Navigator.of(ctx).pop(true),
                            style: TextButton.styleFrom(foregroundColor: Colors.red),
                            child: const Text('Delete'),
                          ),
                        ],
                      ),
                    );
                    if (confirm == true) {
                      await repo.deleteProject(project.id);
                      if (context.mounted) Navigator.of(context).pop();
                    }
                  }
                },
                itemBuilder: (ctx) => [
                  const PopupMenuItem(
                    value: 'edit',
                    child: Text('Edit / Revise Quote'),
                  ),
                  PopupMenuItem(
                    value: 'toggle_status',
                    child: Text(isCompleted ? 'Mark as In Progress' : 'Mark as Completed'),
                  ),
                  const PopupMenuItem(
                    value: 'delete',
                    child: Text('Delete Project', style: TextStyle(color: Colors.red)),
                  ),
                ],
              ),
            ],
          ),
          body: ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 40),
            children: [
              // Header Card
              Card(
                elevation: 0,
                color: cs.surfaceContainerHighest.withValues(alpha: 0.4),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: cs.primaryContainer,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              project.stream,
                              style: TextStyle(
                                color: cs.onPrimaryContainer,
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: isCompleted
                                  ? Colors.green.withValues(alpha: 0.2)
                                  : Colors.blue.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              isCompleted ? 'Completed' : 'In Progress',
                              style: TextStyle(
                                color: isCompleted ? Colors.green[800] : Colors.blue[800],
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      Text(
                        project.title,
                        style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          const Icon(Icons.person_outline_rounded, size: 16),
                          const SizedBox(width: 6),
                          Text(
                            project.clientName,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: cs.onSurfaceVariant,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),

                      // Progress Bar
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: LinearProgressIndicator(
                          value: progress,
                          minHeight: 10,
                          backgroundColor: cs.surfaceContainerHighest,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            isCompleted ? Colors.green : cs.primary,
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            '$percentStr% Paid',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          Text(
                            '${MoneyFormat.compact(totalReceived)} of ${MoneyFormat.compact(project.quoteAmount)}',
                            style: TextStyle(color: cs.onSurfaceVariant),
                          ),
                        ],
                      ),
                      const Divider(height: 28),

                      // Financial stats row
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Quoted Total',
                                  style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  MoneyFormat.compact(project.quoteAmount),
                                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                          ),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Received',
                                  style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  MoneyFormat.compact(totalReceived),
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.green,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Pending Due',
                                  style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  MoneyFormat.compact(pendingAmount),
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: pendingAmount.isPositive ? Colors.orange[800] : Colors.grey,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      OutlinedButton.icon(
                        onPressed: () {
                          showModalBottomSheet(
                            context: context,
                            isScrollControlled: true,
                            builder: (_) => AddProjectSheet(existingProject: project),
                          );
                        },
                        icon: const Icon(Icons.edit_note_rounded, size: 18),
                        label: const Text('Revise Quote / Scope'),
                        style: OutlinedButton.styleFrom(
                          visualDensity: VisualDensity.compact,
                        ),
                      ),

                      if (project.dueDate != null) ...[
                        const SizedBox(height: 14),
                        Row(
                          children: [
                            Icon(Icons.event_outlined, size: 16, color: cs.onSurfaceVariant),
                            const SizedBox(width: 6),
                            Text(
                              'Target Deadline: ${DateFormat('d MMM yyyy').format(project.dueDate!)}',
                              style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant),
                            ),
                          ],
                        ),
                      ],

                      if (project.note != null && project.note!.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: cs.surface,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            project.note!,
                            style: TextStyle(fontSize: 13, color: cs.onSurface),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 18),

              // Action button to record payment
              FilledButton.icon(
                onPressed: () {
                  showModalBottomSheet(
                    context: context,
                    isScrollControlled: true,
                    builder: (ctx) => LogProjectPaymentSheet(
                      project: project,
                      pendingAmount: pendingAmount,
                    ),
                  );
                },
                icon: const Icon(Icons.add_card_rounded),
                label: const Text('Record Payment Received'),
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  backgroundColor: Colors.green[700],
                ),
              ),
              const SizedBox(height: 24),

              // Payments list
              Text(
                'Payment Milestones (${payments.length})',
                style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),

              if (payments.isEmpty)
                Card(
                  elevation: 0,
                  color: cs.surfaceContainerHighest.withValues(alpha: 0.2),
                  child: const Padding(
                    padding: EdgeInsets.all(24),
                    child: Center(
                      child: Text('No payments recorded yet. Tap "Record Payment Received" above when the client pays.'),
                    ),
                  ),
                )
              else
                ...payments.map((p) {
                  return Card(
                    elevation: 0,
                    margin: const EdgeInsets.only(bottom: 10),
                    color: cs.surfaceContainerHighest.withValues(alpha: 0.35),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const CircleAvatar(
                            radius: 18,
                            backgroundColor: Colors.green,
                            child: Icon(Icons.check, color: Colors.white, size: 18),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      '+${MoneyFormat.compact(p.amount)}',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 17,
                                        color: Colors.green,
                                      ),
                                    ),
                                    Text(
                                      DateFormat('d MMM yyyy').format(p.date),
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: cs.onSurfaceVariant,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  p.note != null && p.note!.isNotEmpty
                                      ? p.note!
                                      : 'Payment Received',
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: p.note != null && p.note!.isNotEmpty
                                        ? cs.onSurface
                                        : cs.onSurfaceVariant,
                                    fontStyle: p.note != null && p.note!.isNotEmpty
                                        ? FontStyle.normal
                                        : FontStyle.italic,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                if (p.transactionId == null) ...[
                                  Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                        decoration: BoxDecoration(
                                          color: Colors.amber.withValues(alpha: 0.15),
                                          borderRadius: BorderRadius.circular(6),
                                          border: Border.all(color: Colors.amber.withValues(alpha: 0.4)),
                                        ),
                                        child: const Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(Icons.bookmark_border_rounded, size: 12, color: Colors.amber),
                                            SizedBox(width: 4),
                                            Text(
                                              'Project Starter · Not in Account',
                                              style: TextStyle(
                                                fontSize: 11,
                                                fontWeight: FontWeight.w600,
                                                color: Colors.amber,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      const Spacer(),
                                      OutlinedButton.icon(
                                        icon: const Icon(Icons.add_to_photos_outlined, size: 15),
                                        label: const Text('Add to Account', style: TextStyle(fontSize: 12)),
                                        style: OutlinedButton.styleFrom(
                                          visualDensity: VisualDensity.compact,
                                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                                        ),
                                        onPressed: () {
                                          showModalBottomSheet(
                                            context: context,
                                            isScrollControlled: true,
                                            builder: (_) => _AddToAccountSheet(
                                              project: project,
                                              payment: p,
                                            ),
                                          );
                                        },
                                      ),
                                    ],
                                  ),
                                ] else ...[
                                  Row(
                                    children: [
                                      Icon(Icons.check_circle_outline_rounded, size: 13, color: cs.primary),
                                      const SizedBox(width: 4),
                                      Text(
                                        'In Account Ledger',
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: cs.onSurfaceVariant,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }),
            ],
          ),
        );
      },
    );
  }
}

class _AddToAccountSheet extends ConsumerStatefulWidget {
  const _AddToAccountSheet({required this.project, required this.payment});

  final Project project;
  final ProjectPayment payment;

  @override
  ConsumerState<_AddToAccountSheet> createState() => _AddToAccountSheetState();
}

class _AddToAccountSheetState extends ConsumerState<_AddToAccountSheet> {
  int? _selectedAccountId;
  int? _selectedCategoryId;
  bool _submitting = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final accounts = ref.watch(accountsProvider).valueOrNull ?? const <AccountRow>[];
    final incomeCategories =
        ref.watch(categoriesProvider(CategoryKind.income)).valueOrNull ??
            const <CategoryRow>[];

    final activeAccounts = accounts.where((a) => !a.isArchived).toList();
    if (_selectedAccountId == null && activeAccounts.isNotEmpty) {
      _selectedAccountId = activeAccounts.first.id;
    }

    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Add to Account Ledger',
                    style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Deposit starter payment into your accounts',
                    style: theme.textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                  ),
                ],
              ),
              IconButton(
                icon: const Icon(Icons.close_rounded),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: cs.surfaceContainerHighest.withValues(alpha: 0.4),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Payment Amount:', style: theme.textTheme.bodyMedium),
                Text(
                  '+${MoneyFormat.symbol(widget.payment.amount)}',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.green,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Account Picker
          DropdownButtonFormField<int>(
            initialValue: _selectedAccountId,
            decoration: const InputDecoration(
              labelText: 'Target Account *',
              prefixIcon: Icon(Icons.account_balance_rounded),
              border: OutlineInputBorder(),
            ),
            items: [
              for (final a in activeAccounts)
                DropdownMenuItem<int>(
                  value: a.id,
                  child: Text(a.name),
                ),
            ],
            onChanged: (val) => setState(() => _selectedAccountId = val),
          ),
          const SizedBox(height: 14),

          // Category Picker
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
          const SizedBox(height: 20),

          FilledButton(
            onPressed: _submitting || _selectedAccountId == null
                ? null
                : () async {
                    setState(() => _submitting = true);
                    try {
                      final repo = ref.read(projectsRepositoryProvider);
                      await repo.addPaymentToAccount(
                        project: widget.project,
                        payment: widget.payment,
                        accountId: _selectedAccountId!,
                        categoryId: _selectedCategoryId,
                      );
                      if (context.mounted) {
                        Navigator.of(context).pop();
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              'Added ${MoneyFormat.symbol(widget.payment.amount)} to your account!',
                            ),
                          ),
                        );
                      }
                    } catch (e) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Failed to add to account: $e')),
                        );
                      }
                    } finally {
                      if (mounted) setState(() => _submitting = false);
                    }
                  },
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 14),
              backgroundColor: Colors.green[700],
            ),
            child: _submitting
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : const Text('Deposit as New Income to Account', style: TextStyle(fontSize: 16)),
          ),
          const SizedBox(height: 14),

          Row(
            children: [
              const Expanded(child: Divider()),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Text('OR', style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant)),
              ),
              const Expanded(child: Divider()),
            ],
          ),
          const SizedBox(height: 14),

          OutlinedButton.icon(
            icon: const Icon(Icons.link_rounded),
            label: const Text('Link from Past Transaction (No Duplication)'),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 13),
            ),
            onPressed: _submitting
                ? null
                : () async {
                    final pickedTxId = await showModalBottomSheet<int>(
                      context: context,
                      isScrollControlled: true,
                      builder: (_) => const TransactionLinkPickerSheet(excludeIds: {}),
                    );
                    if (pickedTxId != null && context.mounted) {
                      setState(() => _submitting = true);
                      try {
                        final repo = ref.read(projectsRepositoryProvider);
                        await repo.linkExistingTransactionToPayment(
                          paymentId: widget.payment.id,
                          transactionId: pickedTxId,
                        );
                        if (context.mounted) {
                          Navigator.of(context).pop();
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Linked existing past transaction to project payment!'),
                            ),
                          );
                        }
                      } catch (e) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Failed to link transaction: $e')),
                          );
                        }
                      } finally {
                        if (mounted) setState(() => _submitting = false);
                      }
                    }
                  },
          ),
        ],
      ),
    );
  }
}
