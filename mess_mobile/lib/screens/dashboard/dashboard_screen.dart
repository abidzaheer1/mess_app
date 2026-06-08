import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../models/app_models.dart';
import '../../repositories/mess_repository.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common.dart';
import '../../widgets/expense_visuals.dart';
import '../../widgets/monthly_expense_chart.dart';
import '../expenses/add_expense_screen.dart';
import '../settings/mess_settings_screen.dart';
import '../../utils/currency_format.dart';
import '../../utils/monthly_settlement.dart';
import '../expenses/settlement_analytics_screen.dart';
import '../../widgets/join_requests_panel.dart';
import '../../widgets/mess_admin_builder.dart';
import '../../widgets/admin_join_notification.dart';
import '../../widgets/notifications_panel.dart';
import '../../services/local_notification_service.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({
    super.key,
    required this.repo,
    required this.messId,
    required this.profile,
    this.onOpenMembers,
  });

  final MessRepository repo;
  final String messId;
  final UserProfile profile;
  final VoidCallback? onOpenMembers;

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  late DateTime _month = DateTime(DateTime.now().year, DateTime.now().month);

  void _shiftMonth(int delta) {
    setState(() => _month = DateTime(_month.year, _month.month + delta));
  }

  List<Expense> _monthExpenses(List<Expense> all) {
    return all.where((e) {
      final dt = e.expenseDateParsed;
      return dt != null && dt.year == _month.year && dt.month == _month.month;
    }).toList();
  }

  List<MonthWeekBucket> _monthWeeks(List<Expense> monthSlice) {
    return monthWeekBucketsFromExpenses(
      month: _month,
      expenses: monthSlice.map((e) => (date: e.expenseDateParsed, amount: e.amount)),
    );
  }

  void _openAddExpense() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => AddExpenseScreen(
          repo: widget.repo,
          messId: widget.messId,
          profile: widget.profile,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final greetingName = widget.profile.displayName.trim().split(' ').first;
    final monthLabel = DateFormat.yMMMM().format(_month);

    final bottomInset = MediaQuery.paddingOf(context).bottom + kBottomNavigationBarHeight + 8;

    return StreamBuilder<Mess?>(
      stream: widget.repo.messStream(widget.messId),
      builder: (_, messSnap) {
        final mess = messSnap.data;

        return StreamBuilder<List<Member>>(
          stream: widget.repo.membersStream(widget.messId),
          builder: (_, membersSnap) {
                final members = membersSnap.data ?? const <Member>[];

            return StreamBuilder<List<Expense>>(
              stream: widget.repo.expensesStream(widget.messId),
              builder: (_, expSnap) {
                final expenses = expSnap.data ?? const <Expense>[];
                final scoped = _monthExpenses(expenses);
                final monthlySum = scoped.fold<double>(0, (a, b) => a + b.amount);

                final net = members.isEmpty
                    ? 0.0
                    : netBalanceEqualSplit(
                        uid: widget.profile.uid,
                        expensesInPeriod: scoped,
                        members: members,
                      );

                final weeks = _monthWeeks(scoped);
                final settlementMonth = settlementDisplayMonth();
                final settlement = buildMonthlySettlement(
                  month: settlementMonth,
                  allExpenses: expenses,
                  members: members,
                );
                final mySettlement = settlement.lineFor(widget.profile.uid);
                final settlementNet = mySettlement?.net ?? net;

                return Stack(
                  children: [
                    RefreshIndicator.adaptive(
                      onRefresh: () async {},
                      child: CustomScrollView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        slivers: [
                          SliverToBoxAdapter(
                            child: Padding(
                              padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _DashboardTopBar(
                                    repo: widget.repo,
                                    messId: widget.messId,
                                    profile: widget.profile,
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    'Dashboard',
                                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                                          fontWeight: FontWeight.w800,
                                          color: AppColors.onSurface,
                                        ),
                                  ),
                                  MessAdminBuilder(
                                    repo: widget.repo,
                                    messId: widget.messId,
                                    profile: widget.profile,
                                    builder: (_, isAdmin) {
                                      if (!isAdmin) return const SizedBox.shrink();
                                      return Padding(
                                        padding: const EdgeInsets.only(top: 12),
                                        child: JoinRequestsPanel(
                                          repo: widget.repo,
                                          messId: widget.messId,
                                          adminUid: widget.profile.uid,
                                        ),
                                      );
                                    },
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    mess == null ? 'Fetching…' : 'Welcome back, $greetingName. Here’s your mess overview.',
                                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                          color: AppColors.onSurfaceVariant,
                                        ),
                                  ),
                                  const SizedBox(height: 12),
                                  LayoutBuilder(
                                    builder: (context, constraints) {
                                      return Align(
                                        alignment: Alignment.centerLeft,
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                                          decoration: BoxDecoration(
                                            borderRadius: BorderRadius.circular(999),
                                            border: Border.all(color: Colors.black.withValues(alpha: 0.05)),
                                            color: Colors.white,
                                          ),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Icon(Icons.calendar_month_outlined,
                                                  size: 18, color: Theme.of(context).colorScheme.primary),
                                              const SizedBox(width: 6),
                                              ConstrainedBox(
                                                constraints: BoxConstraints(
                                                  maxWidth: constraints.maxWidth - 120,
                                                ),
                                                child: Text(
                                                  monthLabel,
                                                  overflow: TextOverflow.ellipsis,
                                                ),
                                              ),
                                              IconButton(
                                                padding: EdgeInsets.zero,
                                                visualDensity: VisualDensity.compact,
                                                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                                                onPressed: () => _shiftMonth(-1),
                                                icon: const Icon(Icons.chevron_left_rounded, size: 22),
                                              ),
                                              IconButton(
                                                padding: EdgeInsets.zero,
                                                visualDensity: VisualDensity.compact,
                                                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                                                onPressed: () => _shiftMonth(1),
                                                icon: const Icon(Icons.chevron_right_rounded, size: 22),
                                              ),
                                            ],
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                                  const SizedBox(height: 16),
                                  _SummaryCard(
                                    title: 'Total monthly expenses',
                                    value: formatMessMoney(monthlySum, currencyCode: mess?.currency),
                                    child: MonthlyExpenseChart(
                                      weeks: weeks,
                                      currencyCode: mess?.currency,
                                    ),
                                  ),
                                  const SizedBox(height: 14),
                                  _AddExpenseHero(onTap: _openAddExpense),
                                  const SizedBox(height: 14),
                                  _BalanceCard(
                                    net: settlementNet,
                                    currencyCode: mess?.currency,
                                    settlementMonthLabel: settlementMonthLabel(settlementMonth),
                                    isFinalized: settlement.isFinalized,
                                    perPersonShare: settlement.perPersonShare,
                                    onTap: () {
                                      Navigator.of(context).push(
                                        MaterialPageRoute<void>(
                                          builder: (_) => SettlementAnalyticsScreen(
                                            repo: widget.repo,
                                            messId: widget.messId,
                                            profile: widget.profile,
                                            initialMonth: settlementMonth,
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                                  const SizedBox(height: 14),
                                  MessAdminBuilder(
                                    repo: widget.repo,
                                    messId: widget.messId,
                                    profile: widget.profile,
                                    builder: (_, isAdmin) => _DutyCard(
                                    repo: widget.repo,
                                    messId: widget.messId,
                                    duty: mess?.currentDuty,
                                    isAdmin: isAdmin,
                                    members: members,
                                    profileUid: widget.profile.uid,
                                    onNotify: () async {
                                      final duty = mess?.currentDuty;
                                      if (duty == null) return;
                                      await LocalNotificationService.instance.showAlert(
                                        id: 'duty_${duty.assigneeUid}',
                                        title: 'Grocery duty reminder',
                                        body: '${duty.assigneeName}, you are on grocery duty today.',
                                      );
                                      if (!context.mounted) return;
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(content: Text('Duty reminder sent.')),
                                      );
                                    },
                                    onSwap: () => _DutySwapSheet.show(
                                      context,
                                      repo: widget.repo,
                                      messId: widget.messId,
                                      profileUid: widget.profile.uid,
                                      duty: mess?.currentDuty,
                                      members: members,
                                    ),
                                    onEditDuty: (duty) =>
                                        widget.repo.updateMessDuty(widget.messId, duty),
                                  ),
                                  ),
                                  const SizedBox(height: 8),
                                  Row(
                                    children: [
                                      Text(
                                        'Recent Expenses',
                                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                              fontWeight: FontWeight.w800,
                                            ),
                                      ),
                                      const Spacer(),
                                      TextButton(
                                        onPressed: () {},
                                        child: const Text('View All'),
                                      ),
                                    ],
                                  ),
                                  Container(
                                    width: double.infinity,
                                    padding: const EdgeInsets.all(14),
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(14),
                                      boxShadow: [cardGlow()],
                                      border: Border.all(color: Colors.black.withOpacity(0.04)),
                                    ),
                                    child: Column(
                                      children: [
                                        for (final expense in scoped.take(3))
                                          ExpenseRow(
                                            expense: expense,
                                            compact: true,
                                            currencyCode: mess?.currency,
                                          ),
                                        if (scoped.isEmpty)
                                          Padding(
                                            padding: const EdgeInsets.symmetric(vertical: 10),
                                            child: Text(
                                              'No tracked expenses yet for $monthLabel',
                                              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                                    color: AppColors.onSurfaceVariant,
                                                  ),
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                  SizedBox(height: bottomInset),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                );
              },
            );
          },
        );
      },
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.title, required this.value, required this.child});

  final String title;
  final String value;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [cardGlow()],
        border: Border.all(color: Colors.black.withOpacity(0.04)),
      ),
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        letterSpacing: 0.08,
                        color: AppColors.onSurfaceVariant,
                      ),
                ),
              ),
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: AppColors.primaryDark.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(Icons.show_chart_rounded, color: AppColors.primaryDark),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w900,
                  color: AppColors.primaryDark,
                ),
          ),
          const SizedBox(height: 16),
          Divider(height: 1, color: Colors.black.withValues(alpha: 0.06)),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }
}

class _AddExpenseHero extends StatelessWidget {
  const _AddExpenseHero({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: Ink(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: const LinearGradient(
            colors: [Color(0xFF102B8C), AppColors.primaryDark],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.add_shopping_cart_rounded, color: Colors.white),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Add Expense',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                          ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Log a new grocery purchase or mess utility bill',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.white.withOpacity(0.86)),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BalanceCard extends StatelessWidget {
  const _BalanceCard({
    required this.net,
    required this.onTap,
    required this.settlementMonthLabel,
    required this.isFinalized,
    required this.perPersonShare,
    this.currencyCode,
  });

  final double net;
  final VoidCallback onTap;
  final String settlementMonthLabel;
  final bool isFinalized;
  final double perPersonShare;
  final String? currencyCode;

  @override
  Widget build(BuildContext context) {
    final positive = net >= 0;
    final amount = formatMessMoney(net.abs(), currencyCode: currencyCode);
    final shareLabel = formatMessMoney(perPersonShare, currencyCode: currencyCode);

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      elevation: 0,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            boxShadow: [cardGlow()],
            border: Border.all(color: Colors.black.withValues(alpha: 0.05)),
          ),
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      backgroundColor: AppColors.primaryDark.withValues(alpha: 0.12),
                      child: Icon(Icons.analytics_outlined, color: AppColors.primaryDark),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Monthly settlement',
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900),
                          ),
                          Text(
                            '$settlementMonthLabel · $shareLabel per person${isFinalized ? '' : ' (preview)'}',
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.onSurfaceVariant),
                          ),
                        ],
                      ),
                    ),
                    Icon(Icons.chevron_right_rounded, color: AppColors.onSurfaceVariant),
                  ],
                ),
                const SizedBox(height: 14),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: positive ? AppColors.secondaryContainerTint : const Color(0xFFFFF2F2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        positive ? 'ADMIN PAYS YOU BACK' : 'YOU PAY ADMIN',
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                              fontWeight: FontWeight.w800,
                              color: positive ? AppColors.secondary : const Color(0xFFB91C1C),
                              letterSpacing: 0.08,
                            ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        amount,
                        style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                              fontWeight: FontWeight.w900,
                              color: positive ? const Color(0xFF0E5B3C) : const Color(0xFFB91C1C),
                            ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Tap for full breakdown & PDF',
                        style: Theme.of(context).textTheme.labelMedium?.copyWith(
                              color: AppColors.onSurfaceVariant,
                            ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DutyCard extends StatelessWidget {
  const _DutyCard({
    required this.repo,
    required this.messId,
    required this.duty,
    required this.isAdmin,
    required this.members,
    required this.profileUid,
    required this.onNotify,
    required this.onSwap,
    required this.onEditDuty,
  });

  final MessRepository repo;
  final String messId;
  final DutyInfo? duty;
  final bool isAdmin;
  final List<Member> members;
  final String profileUid;
  final VoidCallback onNotify;
  final VoidCallback onSwap;
  final Future<void> Function(DutyInfo duty) onEditDuty;

  bool get _canSwap {
    if (duty == null || members.length < 2) return false;
    return duty!.assigneeUid == profileUid;
  }

  @override
  Widget build(BuildContext context) {
    final info = duty;

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [cardGlow()],
        border: Border.all(color: Colors.black.withOpacity(0.05)),
      ),
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.restaurant_menu_rounded, color: AppColors.primaryDark),
              const SizedBox(width: 8),
              Text(
                "Today’s Duty",
                style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900),
              ),
              const Spacer(),
              Chip(
                label: Text(
                  info?.type.toUpperCase() ?? 'ROTATION',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(letterSpacing: 0.12),
                ),
                backgroundColor: AppColors.warningSurface,
                visualDensity: VisualDensity.compact,
              ),
              if (isAdmin)
                IconButton(
                  onPressed: () => _DutyEditorSheet.show(context, info, members, onEditDuty),
                  icon: const Icon(Icons.edit_calendar_outlined),
                ),
            ],
          ),
          const SizedBox(height: 14),
          if (info == null)
            Text(
              'No duty pinned yet.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppColors.onSurfaceVariant),
            )
          else
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  backgroundColor: AppColors.primaryDark.withOpacity(0.12),
                  child: Text(
                    info.assigneeName.isEmpty ? '?' : info.assigneeName.characters.first.toUpperCase(),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(info.assigneeName, style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800)),
                      const SizedBox(height: 4),
                      Text(info.description, style: Theme.of(context).textTheme.bodyMedium),
                    ],
                  ),
                ),
              ],
            ),
          const SizedBox(height: 12),
          StreamBuilder<List<DutySwapRequest>>(
            stream: repo.dutySwapRequestsStream(messId, profileUid),
            builder: (context, snap) {
              final requests = snap.data ?? const <DutySwapRequest>[];
              if (requests.isEmpty) return const SizedBox.shrink();
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (final req in requests)
                    _SwapRequestTile(
                      repo: repo,
                      messId: messId,
                      request: req,
                      profileUid: profileUid,
                    ),
                  const SizedBox(height: 8),
                ],
              );
            },
          ),
          LayoutBuilder(
            builder: (context, constraints) {
              if (constraints.maxWidth < 340) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    OutlinedButton(onPressed: onNotify, child: const Text('Notify assignee')),
                    const SizedBox(height: 8),
                    OutlinedButton(
                      onPressed: _canSwap ? onSwap : null,
                      child: const Text('Request swap'),
                    ),
                  ],
                );
              }
              return Row(
                children: [
                  Expanded(
                    child: OutlinedButton(onPressed: onNotify, child: const Text('Notify assignee')),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _canSwap ? onSwap : null,
                      child: const Text('Request swap'),
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

abstract final class _DutyEditorSheet {
  static Future<void> show(
    BuildContext context,
    DutyInfo? current,
    List<Member> members,
    Future<void> Function(DutyInfo duty) onSave,
  ) async {
    if (members.isEmpty) {
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        const SnackBar(content: Text('Add members before assigning duty.')),
      );
      return;
    }

    final typeCtrl = TextEditingController(text: current?.type ?? 'GROCERY');
    final descCtrl = TextEditingController(text: current?.description ?? 'Assigned for grocery run.');
    var selectedUid = members.any((m) => m.uid == current?.assigneeUid)
        ? current!.assigneeUid
        : members.first.uid;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(ctx).bottom + 16),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
            child: StatefulBuilder(
              builder: (_, setInner) {
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text('Duty roster', style: Theme.of(context).textTheme.titleLarge),
                    Text(
                      'Assignments surface on the Alpha Mess dashboard for everyone.',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.onSurfaceVariant),
                    ),
                    const SizedBox(height: 12),
                    // ignore: deprecated_member_use
                    DropdownButtonFormField<String>(
                      value: selectedUid,
                      items: members
                          .map(
                            (m) => DropdownMenuItem<String>(
                              value: m.uid,
                              child: Text(m.displayName),
                            ),
                          )
                          .toList(),
                      decoration: const InputDecoration(labelText: 'Assign member'),
                      onChanged: (v) {
                        if (v == null) return;
                        setInner(() => selectedUid = v);
                      },
                    ),
                    TextField(controller: typeCtrl, decoration: const InputDecoration(labelText: 'Duty type')),
                    TextField(controller: descCtrl, decoration: const InputDecoration(labelText: 'Notes')),
                    const SizedBox(height: 14),
                    FilledButton(
                      onPressed: () async {
                        final member = members.firstWhere((m) => m.uid == selectedUid);
                        final duty = DutyInfo(
                          assigneeUid: member.uid,
                          assigneeName: member.displayName,
                          type: typeCtrl.text.trim().isEmpty ? 'GROCERY' : typeCtrl.text.trim(),
                          description:
                              descCtrl.text.trim().isEmpty ? 'Morning market run.' : descCtrl.text.trim(),
                          date: DateTime.now().toIso8601String().split('T').first,
                        );
                        Navigator.of(ctx).pop();
                        await onSave(duty);
                      },
                      child: const Text('Save duty'),
                    ),
                  ],
                );
              },
            ),
          ),
        );
      },
    );
  }
}

abstract final class _DutySwapSheet {
  static Future<void> show(
    BuildContext context, {
    required MessRepository repo,
    required String messId,
    required String profileUid,
    required DutyInfo? duty,
    required List<Member> members,
  }) async {
    if (duty == null) {
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        const SnackBar(content: Text('No duty is assigned to swap.')),
      );
      return;
    }
    if (duty.assigneeUid != profileUid) {
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        const SnackBar(content: Text('Only the person on duty can request a swap.')),
      );
      return;
    }

    final candidates = members.where((m) => m.uid != duty.assigneeUid).toList();
    if (candidates.isEmpty) {
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        const SnackBar(content: Text('Need at least one other member to swap with.')),
      );
      return;
    }

    var busy = false;
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setInner) {
            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Request shift swap',
                      style: Theme.of(ctx).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Choose a member to send a swap request. They must accept before duty changes.',
                      style: Theme.of(ctx).textTheme.bodyMedium?.copyWith(
                            color: AppColors.onSurfaceVariant,
                          ),
                    ),
                    const SizedBox(height: 12),
                    ...candidates.map(
                      (m) => ListTile(
                        leading: CircleAvatar(child: Text(m.displayName.isEmpty ? '?' : m.displayName[0].toUpperCase())),
                        title: Text(m.displayName),
                        trailing: busy
                            ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                            : const Icon(Icons.send_rounded),
                        onTap: busy
                            ? null
                            : () async {
                                setInner(() => busy = true);
                                try {
                                  await repo.createDutySwapRequest(
                                    messId: messId,
                                    fromUid: profileUid,
                                    fromName: duty.assigneeName,
                                    toUid: m.uid,
                                    toName: m.displayName,
                                  );
                                  if (ctx.mounted) Navigator.pop(ctx);
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(content: Text('Swap request sent to ${m.displayName}.')),
                                    );
                                  }
                                } catch (e) {
                                  if (context.mounted) showSnackError(context, e);
                                } finally {
                                  if (ctx.mounted) setInner(() => busy = false);
                                }
                              },
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}

class _SwapRequestTile extends StatelessWidget {
  const _SwapRequestTile({
    required this.repo,
    required this.messId,
    required this.request,
    required this.profileUid,
  });

  final MessRepository repo;
  final String messId;
  final DutySwapRequest request;
  final String profileUid;

  @override
  Widget build(BuildContext context) {
    final incoming = request.toUid == profileUid;
    final outgoing = request.fromUid == profileUid;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.warningSurface,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            incoming
                ? '${request.fromName} wants to swap duty with you'
                : 'Waiting for ${request.toName} to accept your swap',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
          if (incoming) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: FilledButton(
                    onPressed: () async {
                      try {
                        await repo.respondToDutySwapRequest(
                          messId: messId,
                          requestId: request.id,
                          responderUid: profileUid,
                          accept: true,
                        );
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Swap accepted — duty updated.')),
                          );
                        }
                      } catch (e) {
                        if (context.mounted) showSnackError(context, e);
                      }
                    },
                    child: const Text('Accept'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton(
                    onPressed: () async {
                      try {
                        await repo.respondToDutySwapRequest(
                          messId: messId,
                          requestId: request.id,
                          responderUid: profileUid,
                          accept: false,
                        );
                      } catch (e) {
                        if (context.mounted) showSnackError(context, e);
                      }
                    },
                    child: const Text('Decline'),
                  ),
                ),
              ],
            ),
          ] else if (outgoing) ...[
            const SizedBox(height: 4),
            Text(
              'Pending approval',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(color: AppColors.onSurfaceVariant),
            ),
          ],
        ],
      ),
    );
  }
}

/// Top bar with title on one row and action icons on the next — avoids overlap on narrow web.
class _DashboardTopBar extends StatelessWidget {
  const _DashboardTopBar({
    required this.repo,
    required this.messId,
    required this.profile,
  });

  final MessRepository repo;
  final String messId;
  final UserProfile profile;

  @override
  Widget build(BuildContext context) {
    return MessAdminBuilder(
      repo: repo,
      messId: messId,
      profile: profile,
      builder: (context, isAdmin) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                if (isAdmin)
                  IconButton(
                    tooltip: 'Admin settings',
                    visualDensity: VisualDensity.compact,
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => MessSettingsScreen(
                            repo: repo,
                            messId: messId,
                            profile: profile,
                          ),
                        ),
                      );
                    },
                    icon: Icon(Icons.settings_rounded, color: Theme.of(context).colorScheme.primary),
                  )
                else
                  const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Alpha Mess',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: Theme.of(context).colorScheme.primary,
                          fontWeight: FontWeight.w800,
                        ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                NotificationsButton(repo: repo, messId: messId, profile: profile),
                if (isAdmin)
                  StreamBuilder<Member?>(
                    stream: repo.memberStream(messId, profile.uid),
                    builder: (context, memberSnap) {
                      return AdminJoinRequestBadge(
                        repo: repo,
                        messId: messId,
                        profile: profile,
                        member: memberSnap.data,
                        child: _CompactHeaderIcon(
                          tooltip: 'Join requests',
                          icon: Icons.person_add_alt_1_rounded,
                          onPressed: () {
                            showAdminJoinRequestsSheet(
                              context,
                              repo: repo,
                              messId: messId,
                              adminUid: profile.uid,
                            );
                          },
                        ),
                      );
                    },
                  ),
              ],
            ),
          ],
        );
      },
    );
  }
}

class _CompactHeaderIcon extends StatelessWidget {
  const _CompactHeaderIcon({
    required this.tooltip,
    required this.icon,
    required this.onPressed,
  });

  final String tooltip;
  final IconData icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 44,
      height: 44,
      child: IconButton(
        tooltip: tooltip,
        visualDensity: VisualDensity.compact,
        padding: EdgeInsets.zero,
        iconSize: 22,
        onPressed: onPressed,
        icon: Icon(icon),
      ),
    );
  }
}
