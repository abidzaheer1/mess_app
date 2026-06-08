import 'package:flutter/material.dart';

import '../../models/app_models.dart';
import '../../repositories/mess_repository.dart';
import '../../theme/app_theme.dart';
import '../../utils/currency_format.dart';
import '../../utils/monthly_settlement.dart';
import '../../widgets/expense_visuals.dart';
import 'settlement_analytics_screen.dart';

class ExpensesScreen extends StatelessWidget {
  const ExpensesScreen({super.key, required this.repo, required this.messId, required this.profile});

  final MessRepository repo;
  final String messId;
  final UserProfile profile;

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.paddingOf(context).bottom + kBottomNavigationBarHeight + 24;
    final settlementMonth = settlementDisplayMonth();

    return CustomScrollView(
      slivers: [
        SliverAppBar(
          pinned: true,
          automaticallyImplyLeading: false,
          titleSpacing: 16,
          title: Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'Expenses & settlement',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
            ),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
          sliver: StreamBuilder<Mess?>(
            stream: repo.messStream(messId),
            builder: (_, messSnap) {
              final mess = messSnap.data;
              final currency = mess?.currency;
              return StreamBuilder<List<Member>>(
                stream: repo.membersStream(messId),
                builder: (_, membersSnap) {
                  final members = membersSnap.data ?? const <Member>[];
                  return StreamBuilder<List<Expense>>(
                    stream: repo.expensesStream(messId),
                    builder: (_, expSnap) {
                      if (!expSnap.hasData || !membersSnap.hasData) {
                        return const SliverToBoxAdapter(child: Center(child: CircularProgressIndicator()));
                      }
                      final expenses = expSnap.data ?? const [];
                      final report = buildMonthlySettlement(
                        month: settlementMonth,
                        allExpenses: expenses,
                        members: members,
                      );
                      final myLine = report.lineFor(profile.uid);

                      return SliverList(
                        delegate: SliverChildListDelegate([
                          _SettlementBanner(
                            report: report,
                            currencyCode: currency,
                            myLine: myLine,
                            onOpenDetails: () {
                              Navigator.of(context).push(
                                MaterialPageRoute<void>(
                                  builder: (_) => SettlementAnalyticsScreen(
                                    repo: repo,
                                    messId: messId,
                                    profile: profile,
                                    initialMonth: settlementMonth,
                                  ),
                                ),
                              );
                            },
                          ),
                          const SizedBox(height: 20),
                          Text(
                            'All expenses (60-day history)',
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
                          ),
                          const SizedBox(height: 10),
                          if (expenses.isEmpty)
                            Text(
                              'No expenses tracked yet.',
                              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                    color: AppColors.onSurfaceVariant,
                                  ),
                            )
                          else
                            ...expenses.map(
                              (e) => Padding(
                                padding: const EdgeInsets.symmetric(vertical: 6),
                                child: ExpenseRow(expense: e, currencyCode: currency),
                              ),
                            ),
                          SizedBox(height: bottomInset),
                        ]),
                      );
                    },
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}

class _SettlementBanner extends StatelessWidget {
  const _SettlementBanner({
    required this.report,
    required this.currencyCode,
    required this.myLine,
    required this.onOpenDetails,
  });

  final MonthlySettlementReport report;
  final String? currencyCode;
  final MemberSettlementLine? myLine;
  final VoidCallback onOpenDetails;

  @override
  Widget build(BuildContext context) {
    final positive = (myLine?.net ?? 0) >= 0;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onOpenDetails,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      settlementMonthLabel(report.month),
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
                    ),
                  ),
                  Chip(
                    label: Text(report.isFinalized ? 'Finalized' : 'Preview'),
                    visualDensity: VisualDensity.compact,
                    backgroundColor: report.isFinalized
                        ? AppColors.secondaryContainerTint
                        : AppColors.warningSurface,
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'Total ${formatMessMoney(report.totalSpent, currencyCode: currencyCode)} · '
                '${formatMessMoney(report.perPersonShare, currencyCode: currencyCode)} per member',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppColors.onSurfaceVariant,
                    ),
              ),
              if (myLine != null) ...[
                const SizedBox(height: 12),
                Text(
                  positive
                      ? 'Admin pays you ${formatMessMoney(myLine!.adminOwes, currencyCode: currencyCode)}'
                      : 'You pay admin ${formatMessMoney(myLine!.owesAdmin, currencyCode: currencyCode)}',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    color: positive ? AppColors.secondary : const Color(0xFFB91C1C),
                  ),
                ),
              ],
              const SizedBox(height: 12),
              Row(
                children: [
                  const Icon(Icons.picture_as_pdf_outlined, size: 18),
                  const SizedBox(width: 6),
                  Text(
                    'Open detailed analytics & download PDF',
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                          color: Theme.of(context).colorScheme.primary,
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                  const Spacer(),
                  const Icon(Icons.chevron_right_rounded),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
