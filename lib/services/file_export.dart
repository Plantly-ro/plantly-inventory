import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';

// Platform half chosen at compile time: write-to-documents + OS share sheet
// on io, an anchor-click download in the browser.
import 'file_export_io.dart' if (dart.library.js_interop) 'file_export_web.dart' as platform;

/// Hands a generated file (backup JSON/ZIP, .ics, CSV) to the user.
abstract class FileExporter {
  /// Returns where the bytes went, for the confirmation toast: a full path
  /// on io, the download's file name on web.
  Future<String> save({
    required String fileName,
    required Uint8List bytes,
    required String mimeType,
    required String shareText,
  });
}

/// Test double — records every call, touches nothing.
class RecordingFileExporter implements FileExporter {
  final List<({String fileName, Uint8List bytes, String mimeType})> saved = [];

  @override
  Future<String> save({
    required String fileName,
    required Uint8List bytes,
    required String mimeType,
    required String shareText,
  }) async {
    saved.add((fileName: fileName, bytes: bytes, mimeType: mimeType));
    return fileName;
  }
}

final fileExporterProvider = Provider<FileExporter>((_) => platform.createFileExporter());
