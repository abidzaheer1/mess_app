import 'dart:convert';
import 'dart:typed_data';

import '../models/app_models.dart';

/// Firestore documents are capped at 1 MiB; keep receipt payload under this.
const int maxReceiptBase64Length = 850000;

Map<String, String> encodeReceiptForFirestore(
  Uint8List bytes, {
  String contentType = 'image/jpeg',
}) {
  if (bytes.isEmpty) {
    throw ArgumentError('Receipt image is empty');
  }
  final encoded = base64Encode(bytes);
  if (encoded.length > maxReceiptBase64Length) {
    throw StateError(
      'Receipt photo is too large (${(bytes.length / 1024).round()} KB). '
      'Use a smaller image or lower resolution.',
    );
  }
  return <String, String>{
    'receiptBase64': encoded,
    'receiptContentType': contentType,
  };
}

Uint8List? decodeReceiptBytes(String? base64) {
  if (base64 == null || base64.isEmpty) return null;
  try {
    return base64Decode(base64);
  } catch (_) {
    return null;
  }
}

bool expenseReceiptIsNetwork(Expense expense) {
  final url = expense.receiptUrl;
  return url != null &&
      url.isNotEmpty &&
      (url.startsWith('http://') || url.startsWith('https://'));
}
