import 'dart:async';
import 'dart:js_interop';
import 'dart:typed_data';

import 'package:web/web.dart' as web;

import 'file_export.dart';

FileExporter createFileExporter() => const DownloadFileExporter();

/// Browser: wrap the bytes in a Blob and click a hidden `<a download>`.
/// share_plus has no file sharing on web, and the File System Access API
/// is Chromium-only, so a plain download is the portable option.
class DownloadFileExporter implements FileExporter {
  const DownloadFileExporter();

  @override
  Future<String> save({
    required String fileName,
    required Uint8List bytes,
    required String mimeType,
    required String shareText,
  }) async {
    final blob = web.Blob(
      [bytes.toJS].toJS,
      web.BlobPropertyBag(type: mimeType),
    );
    final url = web.URL.createObjectURL(blob);
    final anchor = web.HTMLAnchorElement()
      ..href = url
      ..download = fileName
      ..style.display = 'none';
    web.document.body!.append(anchor);
    anchor.click();
    anchor.remove();
    // Revoking right after click() cancels the download in Safari and older
    // Firefox — the fetch of the blob URL is asynchronous. Give it a while.
    Timer(const Duration(seconds: 40), () => web.URL.revokeObjectURL(url));
    return fileName;
  }
}
