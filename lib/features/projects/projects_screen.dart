import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/money.dart';
import '../../core/widgets/error_view.dart';
import 'add_project_sheet.dart';
import 'project_detail_screen.dart';
import 'project_model.dart';
import 'projects_repository.dart';

class ProjectsScreen extends ConsumerStatefulWidget {
  const ProjectsScreen({super.key});

  @override
  ConsumerState<ProjectsScreen> createState() => _ProjectsScreenState();
}

class _ProjectsScreenState extends ConsumerState<ProjectsScreen> {
  String _selectedStream = 'All';
  int _selectedStatusIndex = 0; // 0: Active, 1: Completed, 2: All

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    final projectsAsync = ref.watch(allProjectsStreamProvider);
    final allPaymentsAsync = ref.watch(allProjectPaymentsStreamProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Projects & Quotes'),
      ),
      body: projectsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => ErrorView(
          title: 'Failed to load projects',
          message: e.toString(),
        ),
        data: (projects) {
          final allPayments = allPaymentsAsync.valueOrNull ?? const <ProjectPayment>[];

          // Compute payments map: projectId -> totalReceivedPaise
          final paymentsMap = <int, int>{};
          for (final p in allPayments) {
            paymentsMap[p.projectId] = (paymentsMap[p.projectId] ?? 0) + p.amount.paise;
          }

          // Financial overview stats
          var totalQuotedPaise = 0;
          var totalReceivedPaise = 0;
          for (final prj in projects) {
            totalQuotedPaise += prj.quoteAmount.paise;
            totalReceivedPaise += (paymentsMap[prj.id] ?? 0);
          }
          final totalPendingPaise = totalQuotedPaise - totalReceivedPaise;

          // Unique streams for filter
          final streams = {'All', ...projects.map((p) => p.stream)};

          // Filter by stream
          var filtered = _selectedStream == 'All'
              ? projects
              : projects.where((p) => p.stream == _selectedStream).toList();

          // Filter by status
          if (_selectedStatusIndex == 0) {
            filtered = filtered.where((p) => p.status == ProjectStatus.active).toList();
          } else if (_selectedStatusIndex == 1) {
            filtered = filtered.where((p) => p.status == ProjectStatus.completed).toList();
          }

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 80),
            children: [
              // Summary Headline Card
              Card(
                elevation: 0,
                color: cs.surfaceContainerHighest.withValues(alpha: 0.5),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: _StatTile(
                              label: 'Total Quoted',
                              amount: Money(totalQuotedPaise),
                              color: cs.onSurface,
                            ),
                          ),
                          Expanded(
                            child: _StatTile(
                              label: 'Received',
                              amount: Money(totalReceivedPaise),
                              color: Colors.green,
                            ),
                          ),
                          Expanded(
                            child: _StatTile(
                              label: 'Pending Dues',
                              amount: Money(totalPendingPaise > 0 ? totalPendingPaise : 0),
                              color: totalPendingPaise > 0 ? Colors.orange[800] : Colors.grey,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'Money from quotes only enters your accounts when you record a payment received.',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 14),

              // Status Filter Tabs
              SegmentedButton<int>(
                segments: const [
                  ButtonSegment(value: 0, label: Text('Active')),
                  ButtonSegment(value: 1, label: Text('Completed')),
                  ButtonSegment(value: 2, label: Text('All')),
                ],
                selected: {_selectedStatusIndex},
                onSelectionChanged: (set) => setState(() => _selectedStatusIndex = set.first),
              ),
              const SizedBox(height: 10),

              // Stream Filter Chips
              if (streams.length > 2)
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: streams.map((s) {
                      final isSelected = _selectedStream == s;
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: FilterChip(
                          label: Text(s),
                          selected: isSelected,
                          onSelected: (val) {
                            if (val) setState(() => _selectedStream = s);
                          },
                        ),
                      );
                    }).toList(),
                  ),
                ),
              const SizedBox(height: 14),

              // Project List
              if (filtered.isEmpty)
                Card(
                  elevation: 0,
                  color: cs.surfaceContainerHighest.withValues(alpha: 0.2),
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Center(
                      child: Column(
                        children: [
                          Icon(Icons.assignment_outlined, size: 48, color: cs.onSurfaceVariant),
                          const SizedBox(height: 12),
                          Text(
                            projects.isEmpty
                                ? 'No projects or quotes yet'
                                : 'No matching projects in this view',
                            style: theme.textTheme.titleMedium,
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Tap the button below to add your first freelance or teaching project quote.',
                            textAlign: TextAlign.center,
                            style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant),
                          ),
                        ],
                      ),
                    ),
                  ),
                )
              else
                ...filtered.map((prj) {
                  final receivedPaise = paymentsMap[prj.id] ?? 0;
                  final pendingPaise = prj.quoteAmount.paise - receivedPaise;
                  final progress = prj.quoteAmount.paise > 0
                      ? (receivedPaise / prj.quoteAmount.paise).clamp(0.0, 1.0)
                      : 0.0;
                  final percent = (progress * 100).toInt();
                  final isDone = prj.status == ProjectStatus.completed;

                  return Card(
                    elevation: 0,
                    margin: const EdgeInsets.only(bottom: 12),
                    color: cs.surfaceContainerHighest.withValues(alpha: 0.4),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(16),
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => ProjectDetailScreen(projectId: prj.id),
                          ),
                        );
                      },
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: cs.primaryContainer,
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    prj.stream,
                                    style: TextStyle(
                                      color: cs.onPrimaryContainer,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 11,
                                    ),
                                  ),
                                ),
                                if (prj.dueDate != null)
                                  Text(
                                    'Due: ${DateFormat('d MMM').format(prj.dueDate!)}',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: cs.onSurfaceVariant,
                                    ),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            Text(
                              prj.title,
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Client: ${prj.clientName}',
                              style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant),
                            ),
                            const SizedBox(height: 14),

                            // Mini Progress Bar
                            ClipRRect(
                              borderRadius: BorderRadius.circular(4),
                              child: LinearProgressIndicator(
                                value: progress,
                                minHeight: 6,
                                backgroundColor: cs.surfaceContainerHighest,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  isDone ? Colors.green : cs.primary,
                                ),
                              ),
                            ),
                            const SizedBox(height: 8),

                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  '$percent% · Rec: ${MoneyFormat.compact(Money(receivedPaise))}',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.green[700],
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                if (pendingPaise > 0)
                                  Text(
                                    'Pending: ${MoneyFormat.compact(Money(pendingPaise))}',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: cs.primary,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                Text(
                                  'Quote: ${MoneyFormat.compact(prj.quoteAmount)}',
                                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }),
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          showModalBottomSheet(
            context: context,
            isScrollControlled: true,
            builder: (_) => const AddProjectSheet(),
          );
        },
        icon: const Icon(Icons.add_rounded),
        label: const Text('New Project / Quote'),
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({
    required this.label,
    required this.amount,
    required this.color,
  });

  final String label;
  final Money amount;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(
          label,
          style: TextStyle(fontSize: 11, color: Theme.of(context).colorScheme.onSurfaceVariant),
        ),
        const SizedBox(height: 4),
        Text(
          MoneyFormat.compact(amount),
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }
}
