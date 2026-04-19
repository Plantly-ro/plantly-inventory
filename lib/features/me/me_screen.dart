import 'dart:io';
import 'dart:typed_data';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../data/providers.dart';
import '../../domain/services/backup_service.dart';
import '../../domain/services/zip_backup_service.dart';
import '../../theme/tokens.dart';
import '../home/home_providers.dart';
import 'care_types_screen.dart';

/// "Me" tab — settings + Phase-1 user-facing actions (backup / iCal /
/// notification permission). Split into ApplianceRows grouped under
/// section labels so each feature is discoverable even though the
/// surface is intentionally flat.
class MeScreen extends ConsumerWidget {
  const MeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mode = ref.watch(themeModeProvider);
    final surface = mode == ThemeMode.dark ? PlantlySurface.dark : PlantlySurface.light;
    final plants = ref.watch(plantsStreamProvider).maybeWhen(
          data: (rows) => rows.length,
          orElse: () => null,
        );
    final locations = ref.watch(locationsStreamProvider).maybeWhen(
          data: (rows) => rows.length,
          orElse: () => null,
        );

    return Scaffold(
      backgroundColor: surface.bg,
      appBar: AppBar(
        backgroundColor: surface.bg,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.chevron_left, color: surface.text),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        title: Text(
          'Me',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 22,
            fontWeight: FontWeight.w800,
            color: surface.text,
            letterSpacing: -0.02 * 22,
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
        children: [
          _StatCard(surface: surface, plants: plants, locations: locations),
          const SizedBox(height: 20),
          _SectionLabel(text: 'APPEARANCE', surface: surface),
          const SizedBox(height: 8),
          _ThemeToggleRow(mode: mode, surface: surface),
          const SizedBox(height: 20),
          _SectionLabel(text: 'LISTS', surface: surface),
          const SizedBox(height: 8),
          _ActionRow(
            label: 'Care types',
            value: 'Rename, reorder, or add custom reminders and events.',
            icon: Icons.category_outlined,
            surface: surface,
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const CareTypesScreen()),
              );
            },
          ),
          const SizedBox(height: 20),
          _SectionLabel(text: 'NOTIFICATIONS', surface: surface),
          const SizedBox(height: 8),
          _NotificationRow(surface: surface),
          const SizedBox(height: 20),
          _SectionLabel(text: 'BACKUP', surface: surface),
          const SizedBox(height: 8),
          _BackupRow(surface: surface, withPhotos: false),
          const SizedBox(height: 6),
          _BackupRow(surface: surface, withPhotos: true),
          const SizedBox(height: 6),
          _ImportRow(surface: surface),
          const SizedBox(height: 20),
          _SectionLabel(text: 'CALENDAR', surface: surface),
          const SizedBox(height: 8),
          _ICalRow(surface: surface),
          const SizedBox(height: 20),
          _SectionLabel(text: 'ABOUT', surface: surface),
          const SizedBox(height: 8),
          _ReadOnlyRow(
            label: 'App',
            value: 'PlantlyInventory · Phase 1',
            icon: Icons.info_outline,
            surface: surface,
          ),
          const SizedBox(height: 8),
          _ReadOnlyRow(
            label: 'License',
            value: 'AGPL-3.0-or-later',
            icon: Icons.description_outlined,
            surface: surface,
          ),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({required this.surface, required this.plants, required this.locations});
  final PlantlySurface surface;
  final int? plants;
  final int? locations;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: surface.surface,
        border: Border.all(color: surface.border),
        borderRadius: BorderRadius.circular(PlantlyTokens.radiusXl),
      ),
      child: Row(
        children: [
          Expanded(child: _StatCol(label: 'PLANTS', value: plants?.toString() ?? '…', surface: surface)),
          Container(width: 1, height: 40, color: surface.border),
          Expanded(child: _StatCol(label: 'SPACES', value: locations?.toString() ?? '…', surface: surface)),
        ],
      ),
    );
  }
}

class _StatCol extends StatelessWidget {
  const _StatCol({required this.label, required this.value, required this.surface});
  final String label;
  final String value;
  final PlantlySurface surface;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 22,
            fontWeight: FontWeight.w800,
            color: surface.text,
            height: 1,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w700,
            color: surface.muted,
            letterSpacing: 0.1 * 10,
          ),
        ),
      ],
    );
  }
}

class _ThemeToggleRow extends ConsumerWidget {
  const _ThemeToggleRow({required this.mode, required this.surface});
  final ThemeMode mode;
  final PlantlySurface surface;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = mode == ThemeMode.dark;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: surface.surface,
        border: Border.all(color: surface.border),
        borderRadius: BorderRadius.circular(PlantlyTokens.radius),
      ),
      child: Row(
        children: [
          Icon(isDark ? Icons.dark_mode_outlined : Icons.light_mode_outlined, color: surface.green),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Theme',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: surface.text),
                ),
                Text(
                  isDark ? 'Dark' : 'Light',
                  style: TextStyle(fontSize: 12, color: surface.muted),
                ),
              ],
            ),
          ),
          Switch(
            value: isDark,
            activeThumbColor: surface.green,
            onChanged: (_) => ref.read(themeModeProvider.notifier).toggle(),
          ),
        ],
      ),
    );
  }
}

class _NotificationRow extends ConsumerWidget {
  const _NotificationRow({required this.surface});
  final PlantlySurface surface;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final granted = ref.watch(notificationPermissionProvider);
    final (status, color) = switch (granted) {
      null => ('Checking…', surface.muted),
      true => ('Enabled', surface.green),
      false => ('Disabled — tap to retry', surface.terra),
    };
    return _ActionRow(
      label: 'Notifications',
      value: status,
      icon: granted == true ? Icons.notifications_active_outlined : Icons.notifications_off_outlined,
      valueColor: color,
      surface: surface,
      onTap: granted == true
          ? null
          : () async {
              final ok = await ref.read(notificationServiceProvider).requestPermissions();
              ref.read(notificationPermissionProvider.notifier).state = ok;
              if (!context.mounted) return;
              _toast(context, ok ? 'Notifications enabled' : 'Still denied — enable in system settings');
            },
    );
  }
}

class _BackupRow extends ConsumerWidget {
  const _BackupRow({required this.surface, required this.withPhotos});
  final PlantlySurface surface;
  final bool withPhotos;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final label = withPhotos ? 'Export ZIP (with photos)' : 'Export JSON (signed)';
    final subtitle = withPhotos
        ? 'Includes every attached photo. Larger file.'
        : 'HMAC-signed JSON of every plant / schedule / event.';
    return _ActionRow(
      label: label,
      value: subtitle,
      icon: withPhotos ? Icons.archive_outlined : Icons.file_download_outlined,
      surface: surface,
      onTap: () => _runExport(context, ref),
    );
  }

  Future<void> _runExport(BuildContext context, WidgetRef ref) async {
    final messenger = ScaffoldMessenger.of(context);
    final secret = await _promptSecret(context, surface, title: 'Backup passphrase');
    if (secret == null || secret.isEmpty) return;
    try {
      final bytes = withPhotos
          ? await ref.read(zipBackupServiceProvider).exportZip(secret: secret)
          : Uint8List.fromList((await ref.read(backupServiceProvider).export(secret: secret)).codeUnits);
      final docs = await getApplicationDocumentsDirectory();
      final stamp = DateTime.now().toUtc().toIso8601String().replaceAll(':', '-').substring(0, 19);
      final ext = withPhotos ? 'zip' : 'json';
      final file = File(p.join(docs.path, 'plantly-backup-$stamp.$ext'));
      await file.writeAsBytes(bytes, flush: true);
      await SharePlus.instance.share(ShareParams(
        files: [XFile(file.path)],
        text: 'PlantlyInventory backup',
      ));
      messenger
        ..clearSnackBars()
        ..showSnackBar(SnackBar(content: Text('Backup saved: ${file.path}')));
    } catch (e) {
      messenger
        ..clearSnackBars()
        ..showSnackBar(SnackBar(content: Text('Export failed: $e')));
    }
  }
}

class _ImportRow extends ConsumerWidget {
  const _ImportRow({required this.surface});
  final PlantlySurface surface;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return _ActionRow(
      label: 'Import backup',
      value: 'Pick a .json or .zip from this device.',
      icon: Icons.file_upload_outlined,
      surface: surface,
      onTap: () => _run(context, ref),
    );
  }

  Future<void> _run(BuildContext context, WidgetRef ref) async {
    final messenger = ScaffoldMessenger.of(context);
    final file = await openFile(
      acceptedTypeGroups: [
        const XTypeGroup(label: 'Plantly backup', extensions: ['json', 'zip']),
      ],
    );
    if (file == null) return;
    if (!context.mounted) return;
    final secret = await _promptSecret(context, surface, title: 'Backup passphrase');
    if (secret == null || secret.isEmpty) return;
    try {
      final bytes = await file.readAsBytes();
      final ctx = ref.read(appContextProvider).requireValue;
      final opLog = ctx.opLog;
      String msg;
      if (file.name.toLowerCase().endsWith('.zip')) {
        final docs = await getApplicationDocumentsDirectory();
        final photoRoot = Directory(p.join(docs.path, 'photos'));
        final result = await ref.read(zipBackupServiceProvider).importZip(
              bytes: bytes,
              secret: secret,
              opLog: opLog,
              photoStoreRoot: photoRoot,
            );
        msg = 'Imported ${result.json.total} rows + ${result.photosRestored} photos';
      } else {
        final json = String.fromCharCodes(bytes);
        final result = await ref.read(backupServiceProvider).import(
              blob: json,
              secret: secret,
              opLog: opLog,
            );
        msg = 'Imported ${result.total} rows';
      }
      messenger
        ..clearSnackBars()
        ..showSnackBar(SnackBar(content: Text(msg)));
    } on BackupSignatureError {
      messenger
        ..clearSnackBars()
        ..showSnackBar(const SnackBar(content: Text('Wrong passphrase for this backup.')));
    } on BackupFormatError catch (e) {
      messenger
        ..clearSnackBars()
        ..showSnackBar(SnackBar(content: Text('Invalid backup: ${e.message}')));
    } on ZipBackupFormatError catch (e) {
      messenger
        ..clearSnackBars()
        ..showSnackBar(SnackBar(content: Text('Invalid ZIP: ${e.message}')));
    } catch (e) {
      messenger
        ..clearSnackBars()
        ..showSnackBar(SnackBar(content: Text('Import failed: $e')));
    }
  }
}

class _ICalRow extends ConsumerWidget {
  const _ICalRow({required this.surface});
  final PlantlySurface surface;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return _ActionRow(
      label: 'Download .ics',
      value: 'Open the next 30 days of reminders in any calendar app.',
      icon: Icons.event_note_outlined,
      surface: surface,
      onTap: () => _run(context, ref),
    );
  }

  Future<void> _run(BuildContext context, WidgetRef ref) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      final ics = await ref.read(iCalFutureProvider.future);
      final docs = await getApplicationDocumentsDirectory();
      final stamp = DateTime.now().toUtc().toIso8601String().replaceAll(':', '-').substring(0, 19);
      final file = File(p.join(docs.path, 'plantly-reminders-$stamp.ics'));
      await file.writeAsString(ics, flush: true);
      await SharePlus.instance.share(ShareParams(
        files: [XFile(file.path)],
        text: 'PlantlyInventory reminders',
      ));
      messenger
        ..clearSnackBars()
        ..showSnackBar(SnackBar(content: Text('.ics saved: ${file.path}')));
    } catch (e) {
      messenger
        ..clearSnackBars()
        ..showSnackBar(SnackBar(content: Text('Export failed: $e')));
    }
  }
}

Future<String?> _promptSecret(BuildContext context, PlantlySurface surface, {required String title}) async {
  final controller = TextEditingController();
  final result = await showDialog<String>(
    context: context,
    builder: (ctx) {
      return AlertDialog(
        title: Text(title),
        content: TextField(
          controller: controller,
          autofocus: true,
          obscureText: true,
          decoration: const InputDecoration(
            hintText: 'Pick anything — needed to import again',
            border: OutlineInputBorder(),
          ),
          onSubmitted: (v) => Navigator.of(ctx).pop(v),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(null), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.of(ctx).pop(controller.text), child: const Text('OK')),
        ],
      );
    },
  );
  controller.dispose();
  return result;
}

void _toast(BuildContext context, String msg) {
  ScaffoldMessenger.of(context)
    ..clearSnackBars()
    ..showSnackBar(SnackBar(content: Text(msg)));
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.text, required this.surface});
  final String text;
  final PlantlySurface surface;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: surface.green,
          letterSpacing: 0.1 * 11,
        ),
      ),
    );
  }
}

class _ActionRow extends StatelessWidget {
  const _ActionRow({
    required this.label,
    required this.value,
    required this.icon,
    required this.surface,
    this.valueColor,
    this.onTap,
  });

  final String label;
  final String value;
  final IconData icon;
  final PlantlySurface surface;
  final Color? valueColor;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: surface.surface,
      borderRadius: BorderRadius.circular(PlantlyTokens.radius),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(PlantlyTokens.radius),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            border: Border.all(color: surface.border),
            borderRadius: BorderRadius.circular(PlantlyTokens.radius),
          ),
          child: Row(
            children: [
              Icon(icon, size: 18, color: surface.green),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(label, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: surface.text)),
                    Text(
                      value,
                      style: TextStyle(fontSize: 12, color: valueColor ?? surface.muted),
                    ),
                  ],
                ),
              ),
              if (onTap != null) Icon(Icons.chevron_right, color: surface.muted),
            ],
          ),
        ),
      ),
    );
  }
}

class _ReadOnlyRow extends StatelessWidget {
  const _ReadOnlyRow({
    required this.label,
    required this.value,
    required this.icon,
    required this.surface,
  });
  final String label;
  final String value;
  final IconData icon;
  final PlantlySurface surface;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: surface.surface,
        border: Border.all(color: surface.border),
        borderRadius: BorderRadius.circular(PlantlyTokens.radius),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: surface.muted),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: surface.text)),
                Text(value, style: TextStyle(fontSize: 12, color: surface.muted)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
