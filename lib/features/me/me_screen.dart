import 'dart:convert';
import 'dart:typed_data';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/providers.dart';
import '../../data/user_prefs.dart';
import '../../domain/services/backup_service.dart';
import '../../domain/services/zip_backup_service.dart';
import '../../config/plantly_features.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../marketplace/plantly_auth.dart';
import '../../plugins/plantly_ro/plantly_ro_plugin.dart';
import '../../plugins/plugin_registry.dart';
import '../../services/file_export.dart';
import '../../theme/tokens.dart';
import '../home/home_providers.dart';
import 'backup_actions.dart';
import '../../app/navigation.dart';

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
    final t = AppLocalizations.of(context);
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
        automaticallyImplyLeading: false,
        leading: adaptiveBackButton(context, surface),
        title: Text(
          t.meTitle,
          style: TextStyle(fontFamily: PlantlyFonts.plusJakartaSans, 
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
          const SizedBox(height: 12),
          _ActionRow(
            label: t.meStatsLabel,
            value: t.meStatsValue,
            icon: Icons.insert_chart_outlined,
            surface: surface,
            onTap: () => openMeSection(context, 'stats'),
          ),
          const SizedBox(height: 20),
          _SectionLabel(text: t.meSectionYou, surface: surface),
          const SizedBox(height: 8),
          _NameRow(surface: surface),
          const SizedBox(height: 6),
          _ActionRow(
            label: t.mePrivacyLabel,
            value: t.mePrivacyValue,
            icon: Icons.shield_outlined,
            surface: surface,
            onTap: () => openMeSection(context, 'privacy'),
          ),
          if (ref.watch(sellEnabledProvider)) ...[
            const SizedBox(height: 20),
            _SectionLabel(text: t.meSectionPlantlyAccount, surface: surface),
            const SizedBox(height: 8),
            _PlantlyAccountRow(surface: surface),
          ],
          const SizedBox(height: 20),
          _SectionLabel(text: t.meSectionAppearance, surface: surface),
          const SizedBox(height: 8),
          _ThemeToggleRow(mode: mode, surface: surface),
          const SizedBox(height: 20),
          _SectionLabel(text: t.meSectionLists, surface: surface),
          const SizedBox(height: 8),
          _ActionRow(
            label: t.meCareTypesLabel,
            value: t.meCareTypesValue,
            icon: Icons.category_outlined,
            surface: surface,
            onTap: () => openMeSection(context, 'care-types'),
          ),
          const SizedBox(height: 20),
          _SectionLabel(text: t.meSectionNotifications, surface: surface),
          const SizedBox(height: 8),
          _NotificationRow(surface: surface),
          const SizedBox(height: 6),
          _ActionRow(
            label: t.meMutedLabel,
            value: t.meMutedValue,
            icon: Icons.notifications_off_outlined,
            surface: surface,
            onTap: () => openMeSection(context, 'notifications'),
          ),
          const SizedBox(height: 20),
          _SectionLabel(text: t.meSectionBackup, surface: surface),
          const SizedBox(height: 8),
          _BackupRow(surface: surface, withPhotos: false),
          const SizedBox(height: 6),
          _BackupRow(surface: surface, withPhotos: true),
          const SizedBox(height: 6),
          _ImportRow(surface: surface),
          const SizedBox(height: 6),
          _CsvExportRow(surface: surface),
          const SizedBox(height: 20),
          _SectionLabel(text: t.meSectionCalendar, surface: surface),
          const SizedBox(height: 8),
          _ICalRow(surface: surface),
          const SizedBox(height: 20),
          _SectionLabel(text: t.meSectionAbout, surface: surface),
          const SizedBox(height: 8),
          _ReadOnlyRow(
            label: t.meAboutApp,
            value: t.meAboutAppValue,
            icon: Icons.info_outline,
            surface: surface,
          ),
          const SizedBox(height: 8),
          _ReadOnlyRow(
            label: t.meAboutLicense,
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
    final t = AppLocalizations.of(context);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: surface.surface,
        border: Border.all(color: surface.border),
        borderRadius: BorderRadius.circular(PlantlyTokens.radiusXl),
      ),
      child: Row(
        children: [
          Expanded(child: _StatCol(label: t.meStatCardPlants, value: plants?.toString() ?? '…', surface: surface)),
          Container(width: 1, height: 40, color: surface.border),
          Expanded(child: _StatCol(label: t.meStatCardSpaces, value: locations?.toString() ?? '…', surface: surface)),
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
          style: TextStyle(fontFamily: PlantlyFonts.plusJakartaSans, 
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

/// "Plantly account" (CONTRACT §5): signed in as `username` → sign out, or
/// sign in through the plugin's login sheet.
class _PlantlyAccountRow extends ConsumerWidget {
  const _PlantlyAccountRow({required this.surface});
  final PlantlySurface surface;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = AppLocalizations.of(context);
    final session = ref.watch(plantlyAuthProvider);
    final username = session.asData?.value?.username;
    final signedIn = username != null;
    return _ActionRow(
      key: const Key('me-plantly-account'),
      label: t.mePlantlyAccountLabel,
      value: session.isLoading
          ? '…'
          : signedIn
              ? t.mePlantlySignedInAs(username)
              : t.mePlantlySignedOut,
      icon: Icons.storefront_outlined,
      surface: surface,
      valueColor: signedIn ? surface.green : null,
      onTap: () => signedIn ? _signOut(context, ref, username) : _signIn(context, ref),
    );
  }

  Future<void> _signIn(BuildContext context, WidgetRef ref) async {
    final plugin = ref.read(plantlyRoPluginProvider);
    if (plugin == null) return;
    try {
      final session = await plugin.authenticate(context);
      await plugin.storeCredentials(session);
    } on PlantlyAuthCancelled {
      // Dismissed — nothing to do.
    }
  }

  Future<void> _signOut(BuildContext context, WidgetRef ref, String username) async {
    final t = AppLocalizations.of(context);
    final plugin = ref.read(plantlyRoPluginProvider); // before the await (#14)
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(t.mePlantlySignOutTitle),
        content: Text(t.mePlantlySignOutBody(username)),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: Text(t.listedCancel)),
          FilledButton(
            key: const Key('me-plantly-sign-out-confirm'),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(t.mePlantlySignOut),
          ),
        ],
      ),
    );
    if (ok == true) await plugin?.revoke();
  }
}

class _NameRow extends ConsumerWidget {
  const _NameRow({required this.surface});
  final PlantlySurface surface;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final name = ref.watch(userPrefsProvider).userName;
    final t = AppLocalizations.of(context);
    return _ActionRow(
      label: t.meYourName,
      value: (name == null || name.isEmpty) ? t.meYourNameEmpty : name,
      icon: Icons.person_outline,
      surface: surface,
      onTap: () => _edit(context, ref, name),
    );
  }

  Future<void> _edit(BuildContext context, WidgetRef ref, String? current) async {
    final prefs = ref.read(userPrefsProvider.notifier); // before the await (#14)
    final result = await showDialog<String?>(
      context: context,
      builder: (_) => _NameDialog(current: current, surface: surface),
    );
    if (result == null) return;
    await prefs.setName(result);
  }
}

/// Owns its [TextEditingController] so it is disposed with the route, not
/// the moment `showDialog` returns (the dialog is still animating out then).
class _NameDialog extends StatefulWidget {
  const _NameDialog({required this.current, required this.surface});
  final String? current;
  final PlantlySurface surface;

  @override
  State<_NameDialog> createState() => _NameDialogState();
}

class _NameDialogState extends State<_NameDialog> {
  late final TextEditingController _controller = TextEditingController(text: widget.current ?? '');

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    return AlertDialog(
      title: Text(t.meYourName),
      content: TextField(
        controller: _controller,
        autofocus: true,
        textCapitalization: TextCapitalization.words,
        decoration: InputDecoration(hintText: t.meYourNameHint, border: const OutlineInputBorder()),
        onSubmitted: (v) => Navigator.of(context).pop(v),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(null), child: Text(t.cancel)),
        if ((widget.current ?? '').isNotEmpty)
          TextButton(
            style: TextButton.styleFrom(foregroundColor: widget.surface.terra),
            onPressed: () => Navigator.of(context).pop(''),
            child: Text(t.commonClear),
          ),
        FilledButton(onPressed: () => Navigator.of(context).pop(_controller.text), child: Text(t.commonSave)),
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
    final t = AppLocalizations.of(context);
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
                  t.meThemeLabel,
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: surface.text),
                ),
                Text(
                  isDark ? t.meThemeDark : t.meThemeLight,
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
    final t = AppLocalizations.of(context);
    final granted = ref.watch(notificationPermissionProvider);
    final supported = ref.watch(notificationServiceProvider).isSupported;
    final (status, color) = switch (granted) {
      _ when !supported => (t.notificationsWebUnavailable, surface.muted),
      null => (t.meNotifChecking, surface.muted),
      true => (t.meNotifEnabled, surface.green),
      false => (t.meNotifDisabledRetry, surface.terra),
    };
    return _ActionRow(
      label: t.meNotificationsLabel,
      value: status,
      icon: granted == true ? Icons.notifications_active_outlined : Icons.notifications_off_outlined,
      valueColor: color,
      surface: surface,
      onTap: granted == true || !supported
          ? null
          : () async {
              final notifications = ref.read(notificationServiceProvider); // before the await (#14)
              final permission = ref.read(notificationPermissionProvider.notifier);
              final ok = await notifications.requestPermissions();
              permission.state = ok;
              if (!context.mounted) return;
              _toast(context, ok ? t.meNotifEnabledToast : t.meNotifStillDenied);
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
    final t = AppLocalizations.of(context);
    final label = withPhotos ? t.meExportZipLabel : t.meExportJsonLabel;
    final subtitle = withPhotos ? t.meExportZipValue : t.meExportJsonValue;
    return _ActionRow(
      label: label,
      value: subtitle,
      icon: withPhotos ? Icons.archive_outlined : Icons.file_download_outlined,
      surface: surface,
      onTap: () => _runExport(context, ref),
    );
  }

  Future<void> _runExport(BuildContext context, WidgetRef ref) async {
    // Resolve everything before the first await. The passphrase dialog's
    // keyboard can shrink the viewport enough to unmount this row, after
    // which `ref` is dead (issue #14); `actions` lives in the container.
    final t = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final actions = ref.read(backupActionsProvider);
    final secret = await _promptSecret(context, title: t.meBackupPassphrase);
    if (secret == null || secret.isEmpty) return;
    try {
      final where = withPhotos
          ? await actions.exportZip(secret: secret)
          : await actions.exportJson(secret: secret);
      messenger
        ..clearSnackBars()
        ..showSnackBar(SnackBar(content: Text(t.meBackupSaved(where))));
    } catch (e) {
      messenger
        ..clearSnackBars()
        ..showSnackBar(SnackBar(content: Text(t.meExportFailed('$e'))));
    }
  }
}

class _ImportRow extends ConsumerWidget {
  const _ImportRow({required this.surface});
  final PlantlySurface surface;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = AppLocalizations.of(context);
    return _ActionRow(
      label: t.meImportLabel,
      value: t.meImportValue,
      icon: Icons.file_upload_outlined,
      surface: surface,
      onTap: () => _run(context, ref),
    );
  }

  Future<void> _run(BuildContext context, WidgetRef ref) async {
    // Same as _BackupRow: the file picker + passphrase dialog can both
    // unmount this row, so resolve the controller before any await (#14).
    final t = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final actions = ref.read(backupActionsProvider);
    final file = await openFile(
      acceptedTypeGroups: [
        XTypeGroup(label: t.meImportFileType, extensions: const ['json', 'zip']),
      ],
    );
    if (file == null) return;
    if (!context.mounted) return;
    final secret = await _promptSecret(context, title: t.meBackupPassphrase);
    if (secret == null || secret.isEmpty) return;
    try {
      final bytes = await file.readAsBytes();
      final result = await actions.importBackup(fileName: file.name, bytes: bytes, secret: secret);
      final rows = t.meImportedRows(result.rows);
      final msg = result.photos == null ? rows : '$rows + ${t.meImportedPhotos(result.photos!)}';
      messenger
        ..clearSnackBars()
        ..showSnackBar(SnackBar(content: Text(msg)));
    } on BackupSignatureError {
      messenger
        ..clearSnackBars()
        ..showSnackBar(SnackBar(content: Text(t.meImportWrongPassphrase)));
    } on BackupFormatError catch (e) {
      messenger
        ..clearSnackBars()
        ..showSnackBar(SnackBar(content: Text(t.meImportInvalidBackup(e.message))));
    } on ZipBackupFormatError catch (e) {
      messenger
        ..clearSnackBars()
        ..showSnackBar(SnackBar(content: Text(t.meImportInvalidZip(e.message))));
    } catch (e) {
      messenger
        ..clearSnackBars()
        ..showSnackBar(SnackBar(content: Text(t.meImportFailed('$e'))));
    }
  }
}

class _ICalRow extends ConsumerWidget {
  const _ICalRow({required this.surface});
  final PlantlySurface surface;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = AppLocalizations.of(context);
    return _ActionRow(
      label: t.meIcsLabel,
      value: t.meIcsValue,
      icon: Icons.event_note_outlined,
      surface: surface,
      onTap: () => _run(context, ref),
    );
  }

  Future<void> _run(BuildContext context, WidgetRef ref) async {
    final t = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final exporter = ref.read(fileExporterProvider); // before the await (#14)
    try {
      final ics = await ref.read(iCalFutureProvider.future);
      final stamp = DateTime.now().toUtc().toIso8601String().replaceAll(':', '-').substring(0, 19);
      final where = await exporter.save(
            fileName: 'plantly-reminders-$stamp.ics',
            bytes: Uint8List.fromList(utf8.encode(ics)),
            mimeType: 'text/calendar',
            shareText: t.meIcsShareText,
          );
      messenger
        ..clearSnackBars()
        ..showSnackBar(SnackBar(content: Text(t.meIcsSaved(where))));
    } catch (e) {
      messenger
        ..clearSnackBars()
        ..showSnackBar(SnackBar(content: Text(t.meExportFailed('$e'))));
    }
  }
}

Future<String?> _promptSecret(BuildContext context, {required String title}) {
  return showDialog<String>(
    context: context,
    builder: (_) => _SecretDialog(title: title),
  );
}

/// Owns its [TextEditingController] so it is disposed with the route, not
/// the moment `showDialog` returns — the dialog is still animating out then
/// and its TextField would rebuild against a disposed controller.
class _SecretDialog extends StatefulWidget {
  const _SecretDialog({required this.title});
  final String title;

  @override
  State<_SecretDialog> createState() => _SecretDialogState();
}

class _SecretDialogState extends State<_SecretDialog> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    return AlertDialog(
      title: Text(widget.title),
      content: TextField(
        controller: _controller,
        autofocus: true,
        obscureText: true,
        decoration: InputDecoration(
          hintText: t.meBackupPassphraseHint,
          border: OutlineInputBorder(),
        ),
        onSubmitted: (v) => Navigator.of(context).pop(v),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(null), child: Text(t.cancel)),
        FilledButton(onPressed: () => Navigator.of(context).pop(_controller.text), child: Text(t.commonOk)),
      ],
    );
  }
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
    super.key,
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

class _CsvExportRow extends ConsumerWidget {
  const _CsvExportRow({required this.surface});
  final PlantlySurface surface;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = AppLocalizations.of(context);
    return _ActionRow(
      label: t.meCsvLabel,
      value: t.meCsvValue,
      icon: Icons.table_chart_outlined,
      surface: surface,
      onTap: () async {
        final messenger = ScaffoldMessenger.of(context);
        final exporter = ref.read(fileExporterProvider); // before the first await (#14)
        try {
          final ctx = ref.read(appContextProvider).requireValue;
          final plants = await ctx.db.select(ctx.db.plants).get();
          final events = await ctx.db.select(ctx.db.careEvents).get();
          final locations = await ctx.db.select(ctx.db.locations).get();
          final byLoc = {for (final l in locations) l.id: l.name};
          final speciesRows = await ctx.db.select(ctx.db.species).get();
          final bySpecies = {for (final sp in speciesRows) sp.id: sp.scientificName};
          final buf = StringBuffer();
          buf.writeln('type,plant_id,nickname,species,location,status,acquired_at,notes,done_at,care_type,product,dose,care_notes');
          String esc(String? v) {
            if (v == null) return '';
            if (v.contains(',') || v.contains('"') || v.contains('\n')) {
              return '"${v.replaceAll('"', '""')}"';
            }
            return v;
          }
          for (final p in plants) {
            if (p.deletedAt != null) continue;
            buf.writeln([
              'plant',
              esc(p.id),
              esc(p.nickname),
              esc(p.speciesId == null ? null : (bySpecies[p.speciesId] ?? p.speciesId)),
              esc(p.locationId == null ? null : byLoc[p.locationId]),
              esc(p.status),
              p.acquiredAt == null ? '' : DateTime.fromMillisecondsSinceEpoch(p.acquiredAt!, isUtc: true).toIso8601String(),
              esc(p.notes),
              '', '', '', '', '',
            ].join(','));
          }
          for (final e in events) {
            if (e.deletedAt != null) continue;
            final nickname = plants.where((p) => p.id == e.plantId).map((p) => p.nickname).firstOrNull;
            buf.writeln([
              'event',
              esc(e.plantId),
              esc(nickname),
              '', '', '', '', '',
              DateTime.fromMillisecondsSinceEpoch(e.doneAt, isUtc: true).toIso8601String(),
              esc(e.type),
              esc(e.product),
              esc(e.dose),
              esc(e.notes),
            ].join(','));
          }
          final stamp = DateTime.now().toUtc().toIso8601String().replaceAll(':', '-').substring(0, 19);
          final where = await exporter.save(
                fileName: 'plantly-export-$stamp.csv',
                bytes: Uint8List.fromList(utf8.encode(buf.toString())),
                mimeType: 'text/csv',
                shareText: t.meCsvShareText,
              );
          messenger
            ..clearSnackBars()
            ..showSnackBar(SnackBar(content: Text(t.meCsvSaved(where))));
        } catch (e) {
          messenger
            ..clearSnackBars()
            ..showSnackBar(SnackBar(content: Text(t.meCsvFailed('$e'))));
        }
      },
    );
  }
}
