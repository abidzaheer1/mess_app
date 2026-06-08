import 'dart:typed_data';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:printing/printing.dart';

/// Opens the PDF in the platform viewer (browser preview on web, native on mobile).
Future<void> openPdfViewer(Uint8List bytes, {String? filename}) async {
  await Printing.layoutPdf(
    onLayout: (_) async => bytes,
    name: filename ?? 'mess-settlement.pdf',
  );
}

/// Saves a copy when not on web (best-effort; viewer is primary).
Future<void> exportSettlementPdf(Uint8List bytes, String filename) async {
  await openPdfViewer(bytes, filename: filename);
  if (kIsWeb) return;
  try {
    await Printing.sharePdf(bytes: bytes, filename: filename);
  } catch (_) {
    // Viewer already opened; share is optional.
  }
}
