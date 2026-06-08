import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../models/app_models.dart';
import '../../repositories/mess_repository.dart';
import '../../theme/app_theme.dart';
import '../../utils/currency_format.dart';
import '../../widgets/expense_visuals.dart';
import '../chat/chat_screen.dart';
import '../expenses/add_expense_screen.dart';

class EventDetailScreen extends StatelessWidget {
  const EventDetailScreen({
    super.key,
    required this.repo,
    required this.messId,
    required this.profile,
    required this.eventId,
  });

  final MessRepository repo;
  final String messId;
  final UserProfile profile;
  final String eventId;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<MessEvent?>(
      stream: repo.eventStream(messId, eventId),
      builder: (context, snap) {
        final event = snap.data;
        if (event == null) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }
        return StreamBuilder<List<Expense>>(
          stream: repo.eventExpensesStream(messId, eventId),
          builder: (context, expSnap) {
            return StreamBuilder<Mess?>(
              stream: repo.messStream(messId),
              builder: (_, messSnap) {
                final mess = messSnap.data;
                final expenses = expSnap.data ?? const <Expense>[];
                final totalSpent = expenses.fold<double>(0, (sum, e) => sum + e.amount);
                final myShare = event.isJoiner(profile.uid) && event.joinerUids.isNotEmpty
                    ? totalSpent / event.joinerUids.length
                    : 0.0;
                final myPaid = expenses
                    .where((e) => e.paidByUid == profile.uid)
                    .fold<double>(0, (sum, e) => sum + e.amount);
                final net = myPaid - myShare;
                final isJoiner = event.isJoiner(profile.uid);
                final isCreator = event.createdBy == profile.uid;
                final closed = event.status == EventStatuses.closed;

                return Scaffold(
                  appBar: AppBar(
                    leading: const BackButton(),
                    title: Text(event.title),
                    actions: [
                      IconButton(
                        tooltip: 'Event chat',
                        icon: const Icon(Icons.chat_bubble_outline_rounded),
                        onPressed: () {
                          Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (_) => ChatScreen(
                                repo: repo,
                                messId: messId,
                                profile: profile,
                                eventId: event.id,
                                title: '${event.title} chat',
                              ),
                            ),
                          );
                        },
                      ),
                      if (isCreator && !closed)
                        IconButton(
                          tooltip: 'Close event',
                          icon: const Icon(Icons.lock_outline_rounded),
                          onPressed: () async {
                            await repo.closeEvent(messId, event.id);
                          },
                        ),
                    ],
                  ),
                  body: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(event.title,
                                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                        fontWeight: FontWeight.w800,
                                      )),
                              if (event.description.isNotEmpty) ...[
                                const SizedBox(height: 6),
                                Text(event.description),
                              ],
                              const SizedBox(height: 10),
                              Row(
                                children: [
                                  Icon(Icons.schedule_rounded,
                                      size: 16, color: AppColors.onSurfaceVariant),
                                  const SizedBox(width: 4),
                                  Text(
                                    event.startsAt > 0
                                        ? DateFormat.yMMMd()
                                            .add_jm()
                                            .format(DateTime.fromMillisecondsSinceEpoch(event.startsAt))
                                        : 'TBD',
                                    style: Theme.of(context).textTheme.labelMedium,
                                  ),
                                ],
                              ),
                              const SizedBox(height: 10),
                              if (event.estimatedCost != null && event.estimatedCost! > 0) ...[
                                Text(
                                  event.joinerUids.isEmpty
                                      ? 'Estimated total: ${formatMessMoney(event.estimatedCost!, currencyCode: mess?.currency)}'
                                      : 'Estimated total: ${formatMessMoney(event.estimatedCost!, currencyCode: mess?.currency)} · '
                                          '${formatMessMoney(event.estimatedPerPerson, currencyCode: mess?.currency)} per joiner',
                                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                        fontWeight: FontWeight.w700,
                                        color: AppColors.primaryDark,
                                      ),
                                ),
                                const SizedBox(height: 10),
                              ],
                              Wrap(
                                spacing: 6,
                                children: [
                                  Chip(
                                    label: Text('${event.joinerUids.length} joiner${event.joinerUids.length == 1 ? '' : 's'}'),
                                    backgroundColor: AppColors.secondaryContainerTint,
                                    visualDensity: VisualDensity.compact,
                                  ),
                                  if (closed)
                                    const Chip(
                                      label: Text('Closed'),
                                      visualDensity: VisualDensity.compact,
                                    ),
                                ],
                              ),
                              const SizedBox(height: 14),
                              if (!closed)
                                FilledButton.icon(
                                  onPressed: () => repo.setEventJoined(
                                    messId: messId,
                                    eventId: event.id,
                                    uid: profile.uid,
                                    join: !isJoiner,
                                  ),
                                  icon: Icon(isJoiner
                                      ? Icons.exit_to_app_rounded
                                      : Icons.add_circle_outline_rounded),
                                  label: Text(isJoiner ? 'Leave event' : 'Join event'),
                                ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      _EventBalanceCard(
                        totalSpent: totalSpent,
                        myShare: myShare,
                        net: net,
                        joinerCount: event.joinerUids.length,
                        currencyCode: mess?.currency,
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              'Event expenses',
                              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.w800,
                                  ),
                            ),
                          ),
                          if (!closed && isJoiner)
                            FilledButton.tonalIcon(
                              onPressed: () {
                                Navigator.of(context).push(
                                  MaterialPageRoute<void>(
                                    builder: (_) => AddExpenseScreen(
                                      repo: repo,
                                      messId: messId,
                                      profile: profile,
                                      eventId: event.id,
                                      eventTitle: event.title,
                                    ),
                                  ),
                                );
                              },
                              icon: const Icon(Icons.add_rounded),
                              label: const Text('Add'),
                            ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      if (expenses.isEmpty)
                        Padding(
                          padding: const EdgeInsets.all(16),
                          child: Text(
                            'No expenses logged for this event yet.',
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                  color: AppColors.onSurfaceVariant,
                                ),
                          ),
                        )
                      else
                        ...expenses.map((e) => Padding(
                              padding: const EdgeInsets.symmetric(vertical: 4),
                              child: ExpenseRow(expense: e, currencyCode: mess?.currency),
                            )),
                    ],
                  ),
                );
              },
            );
          },
        );
      },
    );
  }
}

class _EventBalanceCard extends StatelessWidget {
  const _EventBalanceCard({
    required this.totalSpent,
    required this.myShare,
    required this.net,
    required this.joinerCount,
    required this.currencyCode,
  });

  final double totalSpent;
  final double myShare;
  final double net;
  final int joinerCount;
  final String? currencyCode;

  @override
  Widget build(BuildContext context) {
    final positive = net >= 0;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Event split', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
            const SizedBox(height: 6),
            Text(
              joinerCount == 0
                  ? 'Nobody has joined this event yet — invite members from chat.'
                  : 'Total ${formatMessMoney(totalSpent, currencyCode: currencyCode)} split equally among $joinerCount joiner${joinerCount == 1 ? '' : 's'}.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppColors.onSurfaceVariant,
                  ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: _MetricTile(
                    label: 'YOUR SHARE',
                    value: formatMessMoney(myShare, currencyCode: currencyCode),
                    color: AppColors.primaryDark,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _MetricTile(
                    label: positive ? 'OWED TO YOU' : 'YOU OWE',
                    value: formatMessMoney(net.abs(), currencyCode: currencyCode),
                    color: positive ? AppColors.secondary : const Color(0xFFB91C1C),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _MetricTile extends StatelessWidget {
  const _MetricTile({required this.label, required this.value, required this.color});

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: color,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.08,
                  )),
          const SizedBox(height: 6),
          Text(value,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w900,
                    color: color,
                  )),
        ],
      ),
    );
  }
}
