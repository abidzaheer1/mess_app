import 'package:flutter/material.dart';
import '../models/app_models.dart';
import '../utils/currency_format.dart';
import 'receipt_image_picker.dart';

class ExpenseCategoryMeta {
  const ExpenseCategoryMeta({required this.id, required this.label});

  final String id;
  final String label;
}

abstract final class ExpenseCategories {
  static const String groceries = 'groceries';
  static const String utilities = 'utilities';
  static const String meals = 'meals';
  static const String transport = 'transport';
  static const String misc = 'misc';

  static const List<ExpenseCategoryMeta> all = [
    ExpenseCategoryMeta(id: groceries, label: 'Groceries'),
    ExpenseCategoryMeta(id: utilities, label: 'Utilities'),
    ExpenseCategoryMeta(id: meals, label: 'Meals'),
    ExpenseCategoryMeta(id: transport, label: 'Transport'),
    ExpenseCategoryMeta(id: misc, label: 'Misc'),
  ];
}

IconData categoryIcon(String id) {
  switch (id) {
    case ExpenseCategories.groceries:
      return Icons.shopping_basket_outlined;
    case ExpenseCategories.utilities:
      return Icons.water_drop_outlined;
    case ExpenseCategories.meals:
      return Icons.restaurant_outlined;
    case ExpenseCategories.transport:
      return Icons.local_shipping_outlined;
    default:
      return Icons.receipt_long_outlined;
  }
}

Color categoryTint(String id) {
  switch (id) {
    case ExpenseCategories.groceries:
      return const Color(0xFFFFE4E6);
    case ExpenseCategories.utilities:
      return const Color(0xFFFFF3E0);
    case ExpenseCategories.meals:
      return const Color(0xFFE8F5E9);
    case ExpenseCategories.transport:
      return const Color(0xFFE3F2FD);
    default:
      return const Color(0xFFF1F5F9);
  }
}

class ExpenseRow extends StatelessWidget {
  const ExpenseRow({
    super.key,
    required this.expense,
    this.compact = false,
    this.currencyCode,
  });

  final Expense expense;
  final bool compact;
  final String? currencyCode;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tint = categoryTint(expense.category);
    final icon = categoryIcon(expense.category);
    final paid = expense.status == ExpenseStatuses.paid;
    final amount = formatMessMoney(expense.amount, currencyCode: currencyCode);

    Widget leading;
    if (expense.hasReceipt) {
      leading = GestureDetector(
        onTap: () => showExpenseReceipt(context, expense, title: expense.title),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: Stack(
            fit: StackFit.expand,
            children: [
              ExpenseReceiptImage(
                expense: expense,
                width: 52,
                height: 52,
                fit: BoxFit.cover,
                errorChild: Container(
                  color: tint,
                  child: Icon(icon, color: const Color(0xFF475569)),
                ),
              ),
              const Positioned(
                right: 2,
                bottom: 2,
                child: Icon(Icons.zoom_in_rounded, size: 14, color: Colors.white),
              ),
            ],
          ),
        ),
      );
    } else {
      leading = Container(
        width: 52,
        height: 52,
        decoration: BoxDecoration(
          color: tint,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: const Color(0xFF475569)),
      );
    }

    return Padding(
      padding: EdgeInsets.symmetric(vertical: compact ? 6 : 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 52, height: 52, child: leading),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(expense.title, style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
                const SizedBox(height: 2),
                Text(
                  'Paid by ${expense.paidByName}',
                  style: theme.textTheme.bodySmall?.copyWith(color: const Color(0xFF475569)),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(amount, style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800)),
              const SizedBox(height: 4),
              Chip(
                label: Text(
                  paid ? 'PAID' : 'PENDING',
                  style: const TextStyle(fontSize: 10, letterSpacing: 0.08, fontWeight: FontWeight.w700),
                ),
                padding: EdgeInsets.zero,
                labelPadding: const EdgeInsets.symmetric(horizontal: 8),
                visualDensity: VisualDensity.compact,
                shape: StadiumBorder(side: BorderSide(color: paid ? Colors.green.shade200 : Colors.orange.shade200)),
                backgroundColor:
                    paid ? const Color(0xFFE9F9EF).withOpacity(0.92) : const Color(0xFFFFF8E9).withOpacity(0.92),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
