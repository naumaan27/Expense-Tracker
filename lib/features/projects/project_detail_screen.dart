import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/money.dart';
import '../../core/widgets/error_view.dart';
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
