import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../theme/app_theme.dart';
import '../utils/currency_format.dart';

class MonthWeekBucket {
  const MonthWeekBucket({
    required this.label,
    required this.start,
    required this.end,
    required this.amount,
    required this.isCurrentWeek,
  });

  final String label;
  final DateTime start;
  final DateTime end;
  final double amount;
  final bool isCurrentWeek;

  String get dateRangeLabel {
    final sameMonth = start.month == end.month;
    if (sameMonth) {
      return '${start.day}–${end.day}';
    }
    return '${DateFormat.Md().format(start)}–${DateFormat.Md().format(end)}';
  }
}

List<MonthWeekBucket> monthWeekBucketsFromExpenses({
  required DateTime month,
  required Iterable<({DateTime? date, double amount})> expenses,
  DateTime? asOf,
}) {
  final first = DateTime(month.year, month.month, 1);
  final last = DateTime(month.year, month.month + 1, 0);
  final now = asOf ?? DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final buckets = <MonthWeekBucket>[];
  var cursor = first;
  var weekIndex = 1;

  while (!cursor.isAfter(last)) {
    final endCandidate = cursor.add(const Duration(days: 6));
    final weekEnd = endCandidate.isAfter(last) ? last : endCandidate;

    var total = 0.0;
    for (final e in expenses) {
      final dt = e.date;
      if (dt == null) continue;
      final day = DateTime(dt.year, dt.month, dt.day);
      if (!day.isBefore(cursor) && !day.isAfter(weekEnd)) {
        total += e.amount;
      }
    }

    final isCurrent = month.year == now.year &&
        month.month == now.month &&
        !today.isBefore(cursor) &&
        !today.isAfter(weekEnd);

    buckets.add(
      MonthWeekBucket(
        label: 'W$weekIndex',
        start: cursor,
        end: weekEnd,
        amount: total,
        isCurrentWeek: isCurrent,
      ),
    );

    cursor = weekEnd.add(const Duration(days: 1));
    weekIndex++;
  }

  return buckets;
}

String compactMessMoney(double amount, {String? currencyCode}) {
  if (amount <= 0) return '—';
  if (amount < 1000) {
    return formatMessMoney(amount, currencyCode: currencyCode);
  }
  final code = resolveMessCurrency(currencyCode);
  final symbol = messCurrencyMeta[code]!.symbol.trim();
  if (amount >= 1000000) {
    return '$symbol${(amount / 1000000).toStringAsFixed(1)}M';
  }
  if (amount >= 10000) {
    return '$symbol${(amount / 1000).toStringAsFixed(0)}k';
  }
  return '$symbol${(amount / 1000).toStringAsFixed(1)}k';
}

class MonthlyExpenseChart extends StatelessWidget {
  const MonthlyExpenseChart({
    super.key,
    required this.weeks,
    this.currencyCode,
  });

  final List<MonthWeekBucket> weeks;
  final String? currencyCode;

  @override
  Widget build(BuildContext context) {
    if (weeks.isEmpty) {
      return _emptyState(context);
    }

    final peak = weeks.fold<double>(0, (p, w) => w.amount > p ? w.amount : p);
    final hasAnySpend = peak > 0;
    const maxHeight = 72.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'Spending by week',
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: AppColors.onSurface,
                  ),
            ),
            const Spacer(),
            if (weeks.any((w) => w.isCurrentWeek))
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.primaryDark.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  'This week',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: AppColors.primaryDark,
                        fontWeight: FontWeight.w700,
                      ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 132,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              for (var i = 0; i < weeks.length; i++) ...[
                if (i > 0) const SizedBox(width: 6),
                Expanded(
                  child: _WeekColumn(
                    bucket: weeks[i],
                    barHeight: hasAnySpend
                        ? ((weeks[i].amount / peak).clamp(0.0, 1.0) * maxHeight).clamp(6.0, maxHeight)
                        : 6.0,
                    currencyCode: currencyCode,
                    showAmount: hasAnySpend,
                  ),
                ),
              ],
            ],
          ),
        ),
        if (!hasAnySpend) ...[
          const SizedBox(height: 8),
          Text(
            'No expenses recorded this month yet.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppColors.onSurfaceVariant,
                ),
          ),
        ],
      ],
    );
  }

  Widget _emptyState(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Spending by week',
          style: Theme.of(context).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 12),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.outlineVariant.withValues(alpha: 0.35)),
          ),
          child: Text(
            'No expense data for this month.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.onSurfaceVariant),
          ),
        ),
      ],
    );
  }
}

class _WeekColumn extends StatelessWidget {
  const _WeekColumn({
    required this.bucket,
    required this.barHeight,
    required this.currencyCode,
    required this.showAmount,
  });

  final MonthWeekBucket bucket;
  final double barHeight;
  final String? currencyCode;
  final bool showAmount;

  @override
  Widget build(BuildContext context) {
    final active = bucket.isCurrentWeek;
    final barColor = active
        ? AppColors.primaryDark
        : bucket.amount > 0
            ? AppColors.primaryDark.withValues(alpha: 0.35)
            : AppColors.outlineVariant.withValues(alpha: 0.35);

    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        Text(
          showAmount ? compactMessMoney(bucket.amount, currencyCode: currencyCode) : '—',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w800,
            color: bucket.amount > 0 ? AppColors.onSurface : AppColors.onSurfaceVariant,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
        const SizedBox(height: 6),
        AnimatedContainer(
          duration: const Duration(milliseconds: 350),
          curve: Curves.easeOutCubic,
          height: barHeight,
          width: double.infinity,
          decoration: BoxDecoration(
            color: barColor,
            borderRadius: BorderRadius.circular(8),
            border: active
                ? Border.all(color: AppColors.primaryDark.withValues(alpha: 0.2), width: 1.5)
                : null,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          bucket.label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: active ? FontWeight.w800 : FontWeight.w600,
            color: active ? AppColors.primaryDark : AppColors.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          bucket.dateRangeLabel,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                fontSize: 9,
                color: AppColors.onSurfaceVariant.withValues(alpha: 0.85),
              ),
        ),
      ],
    );
  }
}
