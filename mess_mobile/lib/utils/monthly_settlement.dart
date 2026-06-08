import '../models/app_models.dart';

/// Which calendar month the app should treat as the published settlement.
/// On the 1st of each month (and thereafter), the previous month is shown.
DateTime settlementDisplayMonth([DateTime? now]) {
  final t = now ?? DateTime.now();
  return DateTime(t.year, t.month - 1);
}

/// Whether a month's equal-split settlement is finalized (last day of that month, noon+).
bool isSettlementMonthFinalized(DateTime month, [DateTime? now]) {
  final t = now ?? DateTime.now();
  final lastDay = DateTime(month.year, month.month + 1, 0);
  final finalizeAt = DateTime(lastDay.year, lastDay.month, lastDay.day, 12);
  return !t.isBefore(finalizeAt);
}

/// Live in-progress month (current calendar month expenses).
DateTime currentTrackingMonth([DateTime? now]) {
  final t = now ?? DateTime.now();
  return DateTime(t.year, t.month);
}

bool expenseInMonth(Expense e, DateTime month) {
  final dt = e.expenseDateParsed ??
      DateTime.fromMillisecondsSinceEpoch(e.createdAt);
  return dt.year == month.year && dt.month == month.month;
}

List<Expense> messExpensesForMonth(List<Expense> all, DateTime month) {
  return all
      .where((e) =>
          (e.eventId == null || e.eventId!.isEmpty) && expenseInMonth(e, month))
      .toList();
}

class MemberSettlementLine {
  const MemberSettlementLine({
    required this.member,
    required this.paid,
    required this.share,
    required this.net,
    required this.owesAdmin,
    required this.adminOwes,
  });

  final Member member;
  final double paid;
  final double share;
  /// Positive = overpaid (admin reimburses). Negative = underpaid (pays admin).
  final double net;
  final double owesAdmin;
  final double adminOwes;
}

class MonthlySettlementReport {
  const MonthlySettlementReport({
    required this.month,
    required this.members,
    required this.expenses,
    required this.lines,
    required this.totalSpent,
    required this.perPersonShare,
    required this.isFinalized,
  });

  final DateTime month;
  final List<Member> members;
  final List<Expense> expenses;
  final List<MemberSettlementLine> lines;
  final double totalSpent;
  final double perPersonShare;
  final bool isFinalized;

  MemberSettlementLine? lineFor(String uid) {
    for (final l in lines) {
      if (l.member.uid == uid) return l;
    }
    return null;
  }
}

MonthlySettlementReport buildMonthlySettlement({
  required DateTime month,
  required List<Expense> allExpenses,
  required List<Member> members,
  DateTime? asOf,
}) {
  final expenses = messExpensesForMonth(allExpenses, month);
  final monthEnd = DateTime(month.year, month.month + 1, 0, 23, 59, 59, 999);
  final monthEndMs = monthEnd.millisecondsSinceEpoch;

  final active = members.where((m) => m.joinedAt <= monthEndMs).toList();
  final n = active.isEmpty ? 1 : active.length;
  final total = expenses.fold<double>(0, (s, e) => s + e.amount);
  final share = total / n;

  final paidByUid = <String, double>{};
  for (final e in expenses) {
    paidByUid[e.paidByUid] = (paidByUid[e.paidByUid] ?? 0) + e.amount;
  }

  final lines = active.map((m) {
    final paid = paidByUid[m.uid] ?? 0;
    final net = paid - share;
    return MemberSettlementLine(
      member: m,
      paid: paid,
      share: share,
      net: net,
      owesAdmin: net < 0 ? -net : 0,
      adminOwes: net > 0 ? net : 0,
    );
  }).toList()
    ..sort((a, b) => b.paid.compareTo(a.paid));

  final isFinalized = isSettlementMonthFinalized(month, asOf);

  return MonthlySettlementReport(
    month: month,
    members: active,
    expenses: expenses,
    lines: lines,
    totalSpent: total,
    perPersonShare: share,
    isFinalized: isFinalized,
  );
}

String settlementMonthLabel(DateTime month) {
  const names = [
    'January', 'February', 'March', 'April', 'May', 'June',
    'July', 'August', 'September', 'October', 'November', 'December',
  ];
  return '${names[month.month - 1]} ${month.year}';
}
