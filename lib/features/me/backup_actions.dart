import 'dart:typed_data';

import 'package:flutter/foundation.dart' show debugPrint, kDebugMode;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/providers.dart';
import '../../domain/services/backup_service.dart';
import '../../services/file_export.dart';

/// Backup export / import use-cases, hoisted out of the Me-screen rows.
///
/// The rows sit in a lazy `ListView`. The passphrase dialog's soft keyboard
/// (adjustResize) can shrink the viewport enough that the row which started
/// the action scrolls out of the cache extent and is unmounted — after which
/// its `ref` is dead and any post-`await` `ref.read` throws
/// `Bad state: Cannot use "ref" after the widget was disposed` (issue #14).
///
/// This object lives in the `ProviderContainer`, so its [Ref] stays valid
/// for the whole async flow. Rows resolve it *before* their first `await`
/// and only call methods on it afterwards.
class BackupActions {
  BackupActions(this._ref);

  final Ref _ref;

  static String _stamp() =>
      DateTime.now().toUtc().toIso8601String().replaceAll(':', '-').substring(0, 19);

  /// HMAC-signed JSON of every plant / schedule / event → file exporter.
  /// Returns where the bytes went (for the confirmation toast).
  Future<String> exportJson({required String secret}) async {
    final blob = await _ref.read(backupServiceProvider).export(secret: secret);
    return _ref.read(fileExporterProvider).save(
          fileName: 'plantly-backup-${_stamp()}.json',
          bytes: BackupService.encodeBlob(blob),
          mimeType: 'application/json',
          shareText: 'PlantlyInventory backup',
        );
  }

  /// Same as [exportJson] plus every attached photo, as a ZIP.
  Future<String> exportZip({required String secret}) async {
    final bytes = await _ref.read(zipBackupServiceProvider).exportZip(secret: secret);
    return _ref.read(fileExporterProvider).save(
          fileName: 'plantly-backup-${_stamp()}.zip',
          bytes: bytes,
          mimeType: 'application/zip',
          shareText: 'PlantlyInventory backup',
        );
  }

  /// Import a `.json` or `.zip` backup picked by the user. Returns a short
  /// human-readable summary. Throws `BackupSignatureError`,
  /// `BackupFormatError` or `ZipBackupFormatError` exactly like the
  /// underlying services so the caller can word the toast.
  Future<String> importBackup({
    required String fileName,
    required Uint8List bytes,
    required String secret,
  }) async {
    final opLog = _ref.read(appContextProvider).requireValue.opLog;
    String msg;
    if (fileName.toLowerCase().endsWith('.zip')) {
      final result = await _ref.read(zipBackupServiceProvider).importZip(
            bytes: bytes,
            secret: secret,
            opLog: opLog,
          );
      msg = 'Imported ${result.json.total} rows + ${result.photosRestored} photos';
    } else {
      final result = await _ref.read(backupServiceProvider).import(
            blob: BackupService.decodeBlob(bytes),
            secret: secret,
            opLog: opLog,
          );
      msg = 'Imported ${result.total} rows';
    }
    // The restored schedules carry `next_due_at` values the OS knows
    // nothing about yet — same class of gap as issue #13. Best-effort.
    try {
      await _ref.read(reminderSyncProvider).syncFromDatabase();
    } catch (e) {
      if (kDebugMode) debugPrint('reminder re-sync failed: $e');
    }
    return msg;
  }
}

final backupActionsProvider = Provider<BackupActions>(BackupActions.new);
