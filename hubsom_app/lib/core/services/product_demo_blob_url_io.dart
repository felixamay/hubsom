import 'dart:io';
import 'dart:typed_data';

import 'package:path_provider/path_provider.dart';

Future<String> createDemoVideoObjectUrl({
  required Uint8List bytes,
  required String mimeType,
}) async {
  final dir = await getTemporaryDirectory();
  final ext = mimeType.contains('webm')
      ? 'webm'
      : mimeType.contains('quicktime')
          ? 'mov'
          : 'mp4';
  final file = File(
    '${dir.path}/hubsom_demo_${DateTime.now().microsecondsSinceEpoch}.$ext',
  );
  await file.writeAsBytes(bytes, flush: true);
  return file.path;
}

Future<void> revokeDemoVideoObjectUrl(String url) async {
  if (url.startsWith('/') || url.contains('hubsom_demo_')) {
    try {
      final file = File(url);
      if (await file.exists()) await file.delete();
    } catch (_) {}
  }
}
