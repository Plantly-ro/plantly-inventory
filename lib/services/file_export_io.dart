import 'dart:io';
import 'dart:typed_data';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import 'file_export.dart';

FileExporter createFileExporter() => const ShareSheetFileExporter();

/// Writes into the app documents dir, then hands the file to whatever the
/// OS considers "share" (Files, Drive, Messages, email attachment, …).
class ShareSheetFileExporter implements FileExporter {
  const ShareSheetFileExporter();

  @override
  Future<String> save({
    required String fileName,
    required Uint8List bytes,
    required String mimeType,
    required String shareText,
  }) async {
    final docs = await getApplicationDocumentsDirectory();
    final file = File(p.join(docs.path, fileName));
    await file.writeAsBytes(bytes, flush: true);
    await SharePlus.instance.share(ShareParams(
      files: [XFile(file.path, mimeType: mimeType)],
      text: shareText,
    ));
    return file.path;
  }
}
