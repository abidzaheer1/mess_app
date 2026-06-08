import 'package:flutter/material.dart';

import '../../models/app_models.dart';
import '../../repositories/mess_repository.dart';
import '../../theme/app_theme.dart';
import '../../utils/currency_format.dart';
import '../../widgets/common.dart';
import '../../widgets/expense_visuals.dart';
import '../../widgets/receipt_image_picker.dart';

class AddExpenseScreen extends StatefulWidget {
  const AddExpenseScreen({
    super.key,
    required this.repo,
    required this.messId,
    required this.profile,
    this.eventId,
    this.eventTitle,
  });

  final MessRepository repo;
  final String messId;
  final UserProfile profile;
  final String? eventId;
  final String? eventTitle;

  @override
  State<AddExpenseScreen> createState() => _AddExpenseScreenState();
}

class _AddExpenseScreenState extends State<AddExpenseScreen> {
  final _title = TextEditingController();
  final _amount = TextEditingController();
  var _category = ExpenseCategories.groceries;
  var _status = ExpenseStatuses.paid;
  late DateTime _day = DateTime.now();
  var _busy = false;
  PickedReceiptImage? _receipt;

  @override
  void dispose() {
    _title.dispose();
    _amount.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _day,
      firstDate: DateTime(DateTime.now().year - 1),
      lastDate: DateTime(DateTime.now().year + 1),
    );
    if (picked != null) setState(() => _day = picked);
  }

  Future<void> _submit() async {
    final title = _title.text.trim();
    final amountParsed = double.tryParse(_amount.text.trim());
    if (title.isEmpty) {
      showSnackError(context, StateError('Add a descriptive title'));
      return;
    }
    if (amountParsed == null || amountParsed <= 0) {
      showSnackError(context, StateError('Enter a valid positive amount'));
      return;
    }
    final expenseDate =
        '${_day.year.toString().padLeft(4, '0')}-${_day.month.toString().padLeft(2, '0')}-${_day.day.toString().padLeft(2, '0')}';

    setState(() => _busy = true);
    try {
      await widget.repo.createExpense(
        widget.messId,
        Expense(
          id: '',
          title: title,
          amount: amountParsed,
          category: _category,
          paidByUid: widget.profile.uid,
          paidByName: widget.profile.displayName.isEmpty ? 'You' : widget.profile.displayName,
          status: _status,
          createdAt: 0,
          expenseDate: expenseDate,
          eventId: widget.eventId,
        ),
        receiptBytes: _receipt?.bytes,
        receiptContentType: _receipt?.contentType ?? 'image/jpeg',
      );
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) showSnackError(context, e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<Mess?>(
      stream: widget.repo.messStream(widget.messId),
      builder: (_, messSnap) {
        final currency = messSnap.data?.currency;
        final symbol = messCurrencyMeta[resolveMessCurrency(currency)]?.symbol ?? 'AED ';

        return Scaffold(
          appBar: AppBar(
            leading: const BackButton(),
            title: Text(widget.eventId == null ? 'Add expense' : 'Add event expense'),
          ),
          body: ListView(
            padding: EdgeInsets.fromLTRB(20, 16, 20, 28 + MediaQuery.paddingOf(context).bottom),
            children: [
              if (widget.eventTitle != null)
                Container(
                  padding: const EdgeInsets.all(12),
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: AppColors.warningSurface,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.event_rounded, color: AppColors.primaryDark),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'This expense will only be split among members of "${widget.eventTitle}".',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ),
                    ],
                  ),
                ),
              TextField(
                controller: _title,
                enabled: !_busy,
                decoration: borderedField(
                  label: 'What did you purchase?',
                  hint: 'Groceries, utilities, outings…',
                  prefix: Icon(Icons.receipt_long_outlined, color: AppColors.onSurfaceVariant),
                ),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: _amount,
                enabled: !_busy,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: borderedField(
                  label: 'Amount',
                  hint: '120.35',
                  prefix: Padding(
                    padding: const EdgeInsets.only(left: 12),
                    child: Text(
                      symbol,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              ReceiptImagePicker(
                image: _receipt,
                busy: _busy,
                onImageChanged: (img) => setState(() => _receipt = img),
              ),
              const SizedBox(height: 18),
              Text('Category', style: Theme.of(context).textTheme.labelLarge),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: ExpenseCategories.all
                    .map(
                      (c) => ChoiceChip(
                        label: Text(c.label),
                        selected: _category == c.id,
                        onSelected: _busy ? null : (_) => setState(() => _category = c.id),
                      ),
                    )
                    .toList(),
              ),
              const SizedBox(height: 18),
              Text('Status', style: Theme.of(context).textTheme.labelLarge),
              const SizedBox(height: 10),
              SegmentedButton<String>(
                segments: const [
                  ButtonSegment(
                    value: ExpenseStatuses.paid,
                    label: Text('Paid'),
                    icon: Icon(Icons.check_circle_outline),
                  ),
                  ButtonSegment(
                    value: ExpenseStatuses.pending,
                    label: Text('Pending'),
                    icon: Icon(Icons.schedule_outlined),
                  ),
                ],
                selected: {_status},
                onSelectionChanged: _busy ? null : (s) => setState(() => _status = s.first),
              ),
              const SizedBox(height: 18),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Expense date'),
                subtitle: Text(
                  MaterialLocalizations.of(context).formatMediumDate(_day),
                ),
                trailing: const Icon(Icons.calendar_month_outlined),
                onTap: _busy ? null : _pickDate,
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: _busy ? null : _submit,
                child: _busy
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(_receipt == null ? 'Save expense' : 'Save expense with receipt'),
              ),
            ],
          ),
        );
      },
    );
  }
}
