import 'package:flutter/material.dart';
import '../../utils/pdf_export.dart';

import '../../models/app_models.dart';
import '../../repositories/mess_repository.dart';
import '../../theme/app_theme.dart';
import '../../utils/currency_format.dart';
import '../../utils/monthly_settlement.dart';
import '../../utils/settlement_pdf.dart';
import '../../widgets/common.dart';
import '../../widgets/expense_visuals.dart';

class SettlementAnalyticsScreen extends StatefulWidget {
  const SettlementAnalyticsScreen({
    super.key,
    required this.repo,
    required this.messId,
    required this.profile,
    this.initialMonth,
  });

  final MessRepository repo;
  final String messId;
  final UserProfile profile;
  final DateTime? initialMonth;

  @override
  State<SettlementAnalyticsScreen> createState() => _SettlementAnalyticsScreenState();
}

class _SettlementAnalyticsScreenState extends State<SettlementAnalyticsScreen> {
  late DateTime _month = widget.initialMonth ?? settlementDisplayMonth();
  var _exporting = false;

  void _shiftMonth(int delta) {
    setState(() => _month = DateTime(_month.year, _month.month + delta));
  }

  Future<void> _exportPdf(MonthlySettlementReport report, String messName, String? currency) async {
    setState(() => _exporting = true);
    try {
      final bytes = await buildSettlementPdf(
        report: report,
        messName: messName,
        currencyCode: currency,
      );
      final name = 'mess-settlement-${_month.year}-${_month.month.toString().padLeft(2, '0')}.pdf';
      await openPdfViewer(bytes, filename: name);
    } catch (e) {
      if (mounted) showSnackError(context, e);
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: const BackButton(),
        title: const Text('Monthly settlement'),
        actions: [
          IconButton(
            tooltip: 'Previous month',
            onPressed: () => _shiftMonth(-1),
            icon: const Icon(Icons.chevron_left_rounded),
          ),
          IconButton(
            tooltip: 'Next month',
            onPressed: () => _shiftMonth(1),
            icon: const Icon(Icons.chevron_right_rounded),
          ),
        ],
      ),
      body: StreamBuilder<Mess?>(
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
                  if (!membersSnap.hasData || !expSnap.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  final report = buildMonthlySettlement(
                    month: _month,
                    allExpenses: expSnap.data ?? const [],
                    members: members,
                  );
                  final myLine = report.lineFor(widget.profile.uid);
                  final currency = mess?.currency;

                  return ListView(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
                    children: [
                      Text(
                        settlementMonthLabel(_month),
                        style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w900),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        report.isFinalized
                            ? 'Finalized settlement — members pay the admin (or receive reimbursement) based on equal split.'
                            : 'Live preview for this month. Final numbers publish on the 1st after noon.',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: AppColors.onSurfaceVariant,
                            ),
                      ),
                      const SizedBox(height: 16),
                      _SummaryGrid(
                        total: report.totalSpent,
                        share: report.perPersonShare,
                        memberCount: report.members.length,
                        expenseCount: report.expenses.length,
                        currencyCode: currency,
                      ),
                      if (myLine != null) ...[
                        const SizedBox(height: 14),
                        _YourLineCard(line: myLine, currencyCode: currency),
                      ],
                      const SizedBox(height: 20),
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              'Who spent & who owes',
                              style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
                            ),
                          ),
                          FilledButton.tonalIcon(
                            onPressed: _exporting || mess == null
                                ? null
                                : () => _exportPdf(report, mess.name, currency),
                            icon: _exporting
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(strokeWidth: 2),
                                  )
                                : const Icon(Icons.picture_as_pdf_outlined),
                            label: const Text('View PDF'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      for (final line in report.lines)
                        _MemberLineTile(line: line, currencyCode: currency),
                      const SizedBox(height: 24),
                      Text(
                        'Expenses this month',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 8),
                      if (report.expenses.isEmpty)
                        Text(
                          'No mess expenses recorded for this month.',
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                color: AppColors.onSurfaceVariant,
                              ),
                        )
                      else
                        for (final e in report.expenses)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 4),
                            child: ExpenseRow(expense: e, currencyCode: currency, compact: true),
                          ),
                    ],
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}

class _SummaryGrid extends StatelessWidget {
  const _SummaryGrid({
    required this.total,
    required this.share,
    required this.memberCount,
    required this.expenseCount,
    required this.currencyCode,
  });

  final double total;
  final double share;
  final int memberCount;
  final int expenseCount;
  final String? currencyCode;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: _cell('Total spent', formatMessMoney(total, currencyCode: currencyCode))),
        const SizedBox(width: 8),
        Expanded(child: _cell('Per person', formatMessMoney(share, currencyCode: currencyCode))),
        const SizedBox(width: 8),
        Expanded(child: _cell('Entries', '$expenseCount · $memberCount members')),
      ],
    );
  }

  Widget _cell(String label, String value) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.secondaryContainerTint,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontSize: 11, color: AppColors.onSurfaceVariant)),
          const SizedBox(height: 4),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
        ],
      ),
    );
  }
}

class _YourLineCard extends StatelessWidget {
  const _YourLineCard({required this.line, required this.currencyCode});

  final MemberSettlementLine line;
  final String? currencyCode;

  @override
  Widget build(BuildContext context) {
    final positive = line.net >= 0;
    return Card(
      color: positive ? AppColors.secondaryContainerTint : const Color(0xFFFFF2F2),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Your position', style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800)),
            const SizedBox(height: 8),
            Text('You paid: ${formatMessMoney(line.paid, currencyCode: currencyCode)}'),
            Text('Your share: ${formatMessMoney(line.share, currencyCode: currencyCode)}'),
            const SizedBox(height: 8),
            Text(
              positive
                  ? 'Admin pays you back ${formatMessMoney(line.adminOwes, currencyCode: currencyCode)}'
                  : 'You pay admin ${formatMessMoney(line.owesAdmin, currencyCode: currencyCode)}',
              style: TextStyle(
                fontWeight: FontWeight.w800,
                color: positive ? AppColors.secondary : const Color(0xFFB91C1C),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MemberLineTile extends StatelessWidget {
  const _MemberLineTile({required this.line, required this.currencyCode});

  final MemberSettlementLine line;
  final String? currencyCode;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: CircleAvatar(
          child: Text(line.member.displayName.isEmpty ? '?' : line.member.displayName.characters.first.toUpperCase()),
        ),
        title: Text(line.member.displayName, style: const TextStyle(fontWeight: FontWeight.w700)),
        subtitle: Text(
          'Paid ${formatMessMoney(line.paid, currencyCode: currencyCode)} · '
          'Share ${formatMessMoney(line.share, currencyCode: currencyCode)}',
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            if (line.owesAdmin > 0)
              Text(
                'Owes ${formatMessMoney(line.owesAdmin, currencyCode: currencyCode)}',
                style: const TextStyle(color: Color(0xFFB91C1C), fontWeight: FontWeight.w700, fontSize: 12),
              )
            else if (line.adminOwes > 0)
              Text(
                '+${formatMessMoney(line.adminOwes, currencyCode: currencyCode)}',
                style: TextStyle(color: AppColors.secondary, fontWeight: FontWeight.w700, fontSize: 12),
              )
            else
              const Text('Settled', style: TextStyle(fontSize: 12)),
          ],
        ),
      ),
    );
  }
}
