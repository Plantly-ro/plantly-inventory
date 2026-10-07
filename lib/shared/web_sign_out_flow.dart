import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../cloud/local_data_wipe.dart';
import '../l10n/generated/app_localizations.dart';

/// The rest of an explicit web sign-out, once the user confirmed the first
/// dialog (Me → Cloud, the gate, Me → plantly.ro): push what is pending
/// (looping until empty or the deadline), ask again when changes would be
/// lost, then sign out + wipe this browser + reload
/// ([LocalDataWiper.signOutAndWipe]). Returns false when the user backed
/// out at the second question (nothing changed).
Future<bool> completeWebSignOut(BuildContext context, WidgetRef ref) async {
  final t = AppLocalizations.of(context);
  final wiper = ref.read(localDataWiperProvider);
  final messenger = ScaffoldMessenger.maybeOf(context);
  final navigator = Navigator.of(context, rootNavigator: true);

  var progressOpen = true;
  showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (_) => PopScope(
      canPop: false,
      child: AlertDialog(
        key: const Key('sign-out-syncing'),
        content: Row(
          children: [
            const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
            const SizedBox(width: 16),
            Expanded(child: Text(t.signOutSyncing)),
          ],
        ),
      ),
    ),
  ).whenComplete(() => progressOpen = false);
  final pending = await wiper.flush();
  if (progressOpen) navigator.pop();
  if (!context.mounted) return false;

  if (pending > 0) {
    final go = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        key: const Key('sign-out-unsynced'),
        title: Text(t.signOutUnsyncedTitle),
        content: Text(t.signOutUnsyncedBody(pending)),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: Text(t.cancel)),
          FilledButton(
            key: const Key('sign-out-anyway'),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(t.signOutAnyway),
          ),
        ],
      ),
    );
    if (go != true) return false;
  }

  try {
    await wiper.signOutAndWipe();
  } catch (e) {
    messenger?.showSnackBar(SnackBar(content: Text(t.signOutWipeFailed('$e')), duration: const Duration(seconds: 10)));
  }
  return true;
}
