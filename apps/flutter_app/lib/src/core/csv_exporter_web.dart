import 'dart:convert';
import 'dart:js_interop';
import 'package:web/web.dart' as web;

void downloadCsv(String filename, String content) {
  final bytes = utf8.encode(content);
  final blobParts = [bytes.toJS].toJS;
  final blob = web.Blob(blobParts, web.BlobPropertyBag(type: 'text/csv'));
  final url = web.URL.createObjectURL(blob);
  final anchor = web.HTMLAnchorElement()
    ..href = url
    ..download = filename;
  web.document.body?.append(anchor);
  anchor.click();
  anchor.remove();
  web.URL.revokeObjectURL(url);
}
