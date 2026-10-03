import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/side_sheet.dart';
import '../../cloud/account_decision.dart';
import '../../cloud/cloud_state.dart';
import '../../cloud/cloud_sync.dart';
import '../../cloud/collection_link.dart';
import '../../cloud/collections.dart';
import '../../cloud/sign_in_events.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../marketplace/plantly_api.dart';
import '../../marketplace/plantly_auth.dart';
import '../../plugins/plantly_ro/login_sheet.dart';
import '../../shared/sheet_chrome.dart';
import '../../theme/tokens.dart';
import '../home/home_providers.dart';
import 'collection_ui.dart';

/// "Join with code" (CLOUD-SYNC-CONTRACT §3). Opened from the switcher, the
/// Sharing rows and by `HandoffListener` for `…/join#c=<code>` links (the
/// code arrives pre-filled). Resolves with the joined collection, or null.
///
/// Flow: validate the code → sign in first when signed out (login sheet on
/// top) → the account-switch decision when this device still holds another
/// account's plants (`resolveHeldByOther`; cancel = no join) →
/// `POST /collections/join` → switch to it (when the device can sync) → one
/// `syncNow()` so it fills straight away. Not entitled: the join still goes
/// through (the server accepts; writes will 402) and the sheet says so up
/// front.
Future<CloudCollection?> showJoinCollectionSheet(BuildContext context, {String? initialCode}) {
  return showAdaptiveSheet<CloudCollection>(
    context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => JoinCollectionSheet(initialCode: initialCode),
  );
}

class JoinCollectionSheet extends ConsumerStatefulWidget {
  const JoinCollectionSheet({super.key, this.initialCode});
  final String? initialCode;

  @override
  ConsumerState<JoinCollectionSheet> createState() => _JoinCollectionSheetState();
}

class _JoinCollectionSheetState extends ConsumerState<JoinCollectionSheet> {
  late final TextEditingController _code;
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _code = TextEditingController(text: InviteCode.normalize(widget.initialCode ?? '') ?? (widget.initialCode ?? ''));
  }

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  bool get _valid => InviteCode.isValid(_code.text);

  Future<void> _join() async {
    final t = AppLocalizations.of(context);
    final code = InviteCode.normalize(_code.text);
    if (code == null) {
      setState(() => _error = t.shareJoinCodeInvalid);
      return;
    }
    // Everything below crosses awaits that may unmount this sheet (#14).
    final auth = ref.read(plantlyAuthProvider.notifier);
    final events = ref.read(signInEventsProvider);
    final collections = ref.read(collectionsProvider.notifier);
    final links = ref.read(collectionLinkProvider.notifier);
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.maybeOf(context);

    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      var session = await auth.current();
      if (session == null) {
        if (!mounted) return;
        session = await showPlantlyLoginSheet(context, auth: auth);
        if (session == null) {
          if (mounted) setState(() => _busy = false);
          return;
        }
        events.emit(session);
      }
      // Another account's plants on this device (its link, or the marker it
      // left behind): the user decides where they go BEFORE the join —
      // otherwise `join` finds no link of ours and lands nowhere (QA2 BUG-4).
      await links.ready;
      if (!mounted) return;
      final cloud = ref.read(cloudStateProvider);
      final other = cloud.heldByOther;
      if (other != null) {
        final decided = await resolveHeldByOther(context, ref, other: other, me: cloud.account ?? session.username);
        if (!decided) {
          if (mounted) setState(() => _busy = false); // cancelled: no error, sheet stays
          return;
        }
      }
      final col = await collections.join(code);
      // Fill the new tenant right away (a no-op runner just returns).
      unawaited(ref.read(syncRunnerProvider).syncNow());
      messenger
        ?..clearSnackBars()
        ..showSnackBar(SnackBar(content: Text(t.shareJoined(col.displayName))));
      navigator.pop(col);
    } catch (e) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = describeShareError(t, e);
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final mode = ref.watch(themeModeProvider);
    final surface = mode == ThemeMode.dark ? PlantlySurface.dark : PlantlySurface.light;
    final t = AppLocalizations.of(context);
    final cloud = ref.watch(cloudStateProvider);
    final auth = ref.watch(plantlyAuthProvider);
    final inset = MediaQuery.of(context).viewInsets.bottom;
    // The session, not the cloud phase: the sheet signs in regardless of
    // the feature flag (a join link may arrive on a build with cloud off).
    final signedOut = !auth.isLoading && auth.valueOrNull == null;
    final notEntitled = cloud.phase == CloudPhase.notEntitled && !cloud.checking;

    final joinButton = SizedBox(
      width: double.infinity,
      child: FilledButton(
        key: const Key('join-collection-submit'),
        style: FilledButton.styleFrom(
          backgroundColor: surface.green,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(PlantlyTokens.radius + 2)),
        ),
        onPressed: _busy || !_valid ? null : _join,
        child: _busy
            ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
            : Text(t.shareJoinButton, style: const TextStyle(fontWeight: FontWeight.w700)),
      ),
    );

    return Padding(
      padding: EdgeInsets.only(bottom: inset),
      child: SheetChrome(
        surface: surface,
        title: t.shareJoinTitle,
        subtitle: t.shareJoinBody,
        crossAxisAlignment: CrossAxisAlignment.start,
        footer: joinButton,
        children: [
          SafeArea(
            top: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  t.shareJoinTitle,
                  key: const Key('join-collection-title'),
                  style: TextStyle(
                    fontFamily: PlantlyFonts.plusJakartaSans,
                    fontSize: 19,
                    fontWeight: FontWeight.w800,
                    color: surface.text,
                  ),
                ),
                const SizedBox(height: 4),
                Text(t.shareJoinBody, style: TextStyle(fontSize: 12.5, color: surface.muted)),
                const SizedBox(height: 16),
                TextField(
                  key: const Key('join-collection-code'),
                  controller: _code,
                  autofocus: widget.initialCode == null,
                  enabled: !_busy,
                  textCapitalization: TextCapitalization.characters,
                  autocorrect: false,
                  enableSuggestions: false,
                  maxLength: InviteCode.length + 1, // room for one dash while typing
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'[A-Za-z0-9\- ]')),
                    _UpperCaseFormatter(),
                  ],
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 4,
                    color: surface.text,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                  decoration: InputDecoration(
                    labelText: t.shareJoinCodeLabel,
                    counterText: '',
                    errorText: _error,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(PlantlyTokens.radius)),
                  ),
                  onChanged: (_) => setState(() => _error = null),
                  onSubmitted: (_) => _valid && !_busy ? _join() : null,
                ),
                if (_code.text.isNotEmpty && !_valid && _error == null) ...[
                  const SizedBox(height: 6),
                  Text(
                    t.shareJoinCodeInvalid,
                    key: const Key('join-collection-hint'),
                    style: TextStyle(fontSize: 11.5, color: surface.muted),
                  ),
                ],
                if (signedOut) ...[
                  const SizedBox(height: 12),
                  _Note(icon: Icons.login, text: t.shareJoinSignInFirst, surface: surface, key: const Key('join-sign-in-note')),
                ],
                if (notEntitled) ...[
                  const SizedBox(height: 12),
                  _Note(
                    icon: Icons.workspace_premium_outlined,
                    text: t.shareJoinPaywallNote,
                    surface: surface,
                    key: const Key('join-paywall-note'),
                    color: surface.terra,
                  ),
                ],
                const SizedBox(height: 16),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Note extends StatelessWidget {
  const _Note({super.key, required this.icon, required this.text, required this.surface, this.color});
  final IconData icon;
  final String text;
  final PlantlySurface surface;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: color ?? surface.muted),
        const SizedBox(width: 8),
        Expanded(child: Text(text, style: TextStyle(fontSize: 12, height: 1.35, color: color ?? surface.muted))),
      ],
    );
  }
}

class _UpperCaseFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) =>
      newValue.copyWith(text: newValue.text.toUpperCase());
}
