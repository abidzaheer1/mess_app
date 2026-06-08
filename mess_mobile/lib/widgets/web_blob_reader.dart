import 'dart:typed_data';

import 'package:http/http.dart' as http;

Future<Uint8List?> readWebBlobUrl(String url) async {
  final resp = await http.get(Uri.parse(url));
  if (resp.statusCode == 200) return resp.bodyBytes;
  return null;
}
