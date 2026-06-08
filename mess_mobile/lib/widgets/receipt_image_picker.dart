import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../models/app_models.dart';
import '../theme/app_theme.dart';
import '../utils/receipt_firestore.dart';

class PickedReceiptImage {
  const PickedReceiptImage({required this.bytes, required this.contentType});

  final Uint8List bytes;
  final String contentType;
}

class ReceiptImagePicker extends StatelessWidget {
  const ReceiptImagePicker({
    super.key,
    required this.image,
    required this.onImageChanged,
    this.busy = false,
  });

  final PickedReceiptImage? image;
  final ValueChanged<PickedReceiptImage?> onImageChanged;
  final bool busy;

  static final _picker = ImagePicker();

  Future<void> _pick(BuildContext context, ImageSource source) async {
    try {
      final file = await _picker.pickImage(
        source: source,
        maxWidth: 1280,
        maxHeight: 1280,
        imageQuality: 70,
      );
      if (file == null) return;
      final bytes = await file.readAsBytes();
      if (bytes.isEmpty) return;
      final name = file.name.toLowerCase();
      final contentType = name.endsWith('.png') ? 'image/png' : 'image/jpeg';
      onImageChanged(PickedReceiptImage(bytes: bytes, contentType: contentType));
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not load image: $e')),
      );
    }
  }

  void _showSourceSheet(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Receipt photo',
                  style: Theme.of(ctx).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 12),
                ListTile(
                  leading: const Icon(Icons.photo_camera_outlined),
                  title: const Text('Take photo'),
                  onTap: () {
                    Navigator.pop(ctx);
                    _pick(context, ImageSource.camera);
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.photo_library_outlined),
                  title: const Text('Choose from gallery'),
                  onTap: () {
                    Navigator.pop(ctx);
                    _pick(context, ImageSource.gallery);
                  },
                ),
                if (image != null)
                  ListTile(
                    leading: Icon(Icons.delete_outline, color: Theme.of(ctx).colorScheme.error),
                    title: Text('Remove photo', style: TextStyle(color: Theme.of(ctx).colorScheme.error)),
                    onTap: () {
                      Navigator.pop(ctx);
                      onImageChanged(null);
                    },
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Receipt image', style: Theme.of(context).textTheme.labelLarge),
        const SizedBox(height: 8),
        Text(
          'Optional — snap or upload a bill photo for this expense.',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.onSurfaceVariant),
        ),
        const SizedBox(height: 10),
        if (image != null)
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Stack(
              alignment: Alignment.topRight,
              children: [
                Image.memory(
                  image!.bytes,
                  height: 180,
                  width: double.infinity,
                  fit: BoxFit.cover,
                ),
                IconButton.filled(
                  style: IconButton.styleFrom(
                    backgroundColor: Colors.black54,
                    foregroundColor: Colors.white,
                  ),
                  onPressed: busy ? null : () => onImageChanged(null),
                  icon: const Icon(Icons.close_rounded, size: 20),
                ),
              ],
            ),
          )
        else
          OutlinedButton.icon(
            onPressed: busy ? null : () => _showSourceSheet(context),
            icon: const Icon(Icons.add_a_photo_outlined),
            label: const Text('Add receipt photo'),
          ),
        if (image != null) ...[
          const SizedBox(height: 8),
          TextButton.icon(
            onPressed: busy ? null : () => _showSourceSheet(context),
            icon: const Icon(Icons.swap_horiz_rounded),
            label: const Text('Change photo'),
          ),
        ],
      ],
    );
  }
}

void showExpenseReceipt(BuildContext context, Expense expense, {String? title}) {
  showDialog<void>(
    context: context,
    builder: (ctx) => Dialog(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (title != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Text(title, style: Theme.of(ctx).textTheme.titleMedium),
            ),
          InteractiveViewer(
            child: ExpenseReceiptImage(
              expense: expense,
              fit: BoxFit.contain,
            ),
          ),
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close')),
        ],
      ),
    ),
  );
}

class ExpenseReceiptImage extends StatelessWidget {
  const ExpenseReceiptImage({
    super.key,
    required this.expense,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.errorChild,
  });

  final Expense expense;
  final double? width;
  final double? height;
  final BoxFit fit;
  final Widget? errorChild;

  @override
  Widget build(BuildContext context) {
    final fallback = errorChild ??
        const Padding(
          padding: EdgeInsets.all(24),
          child: Text('Could not load receipt image'),
        );

    if (expense.receiptBase64 != null && expense.receiptBase64!.isNotEmpty) {
      final bytes = decodeReceiptBytes(expense.receiptBase64);
      if (bytes == null) return fallback;
      return Image.memory(
        bytes,
        width: width,
        height: height,
        fit: fit,
        errorBuilder: (_, _, _) => fallback,
      );
    }

    if (expenseReceiptIsNetwork(expense)) {
      return Image.network(
        expense.receiptUrl!,
        width: width,
        height: height,
        fit: fit,
        loadingBuilder: (_, child, progress) {
          if (progress == null) return child;
          return SizedBox(
            width: width,
            height: height,
            child: const Center(child: CircularProgressIndicator()),
          );
        },
        errorBuilder: (_, _, _) => fallback,
      );
    }

    return fallback;
  }
}
