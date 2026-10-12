import 'dart:io';

void downloadCsv(String filename, String content) {
  final sanitizedName = filename.replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_');
  final file = File('${Directory.systemTemp.path}/$sanitizedName');
  file.writeAsStringSync(content);
}
