import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../app/breakpoints.dart';
import '../../app/side_sheet.dart';
import '../../cloud/account_decision.dart';
import '../../cloud/cloud_state.dart';
import '../../cloud/cloud_sync.dart';
import '../../cloud/collection_link.dart';
import '../../cloud/collections.dart';
import '../../cloud/entitlement.dart';
import '../../cloud/join_parking.dart';
import '../../cloud/sign_in_events.dart';
import '../../config/plantly_hosts.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../marketplace/plantly_api.dart';
import '../../marketplace/plantly_auth.dart';
import '../../plugins/plantly_ro/login_sheet.dart';
import '../../shared/sheet_chrome.dart';
import '../../theme/tokens.dart';
import '../home/home_providers.dart';
import '../me/cloud_section.dart' show cloudPurchaseLinkAllowedProvider;
import 'collection_ui.dart';

/// "Join with code" (CLOUD-SYNC-CONTRACT §3). Opened from the switcher, the
/// Sharing rows and by `HandoffListener` for `…/join#c=<code>` links (the
/// code arrives pre-filled). Resolves with the joined collection, or null.
///
/// Flow: validate the code → sign in first when signed out (login sheet on
/// top) → the account-switch decision when this device still holds another
/// account's plants (`resolveHeldByOther`; cancel = no join) → the
/// entitlement check (MULTI-USER-V2 §8: every member needs their OWN
/// Inventory Cloud / Pro plan — not entitled → the requirement step, the
/// code is parked for 7 days, `JoinParking`) → `POST /collections/join`
/// (a `402 cloud_required` lands on the same step; the invite is not
/// consumed) → switch to it → one `syncNow()` so it fills straight away.
///
/// [resume] = the code was parked earlier: submit right away (the user
/// subscribed and came back; `HandoffListener` reopens the sheet).
Future<CloudCollection?> showJoinCollectionSheet(BuildContext context, {String? initialCode, bool resume = false}) {
  return showAdaptiveSheet<CloudCollection>(
    context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => JoinCollectionSheet(initialCode: initialCode, resume: resume),
  );
}

class JoinCollectionSheet extends ConsumerStatefulWidget {
  const JoinCollectionSheet({super.key, this.initialCode, this.resume = false});
  final String? initialCode;
  final bool resume;

  @override
  ConsumerState<JoinCollectionSheet> createState() => _JoinCollectionSheetState();
}

class _JoinCollectionSheetState extends ConsumerState<JoinCollectionSheet> {
  late final TextEditingController _code;
  bool _busy = false;
  String? _error;

  /// The requirement step (§8) is showing for [_parkedCode].
  bool _cloudRequired = false;
  String? _parkedCode;

  /// A "Try again" came back not entitled: say so under the step.
  bool _stillRequired = false;

  /// `openJoinSheetsProvider`'s controller, captured while `ref` is live so
  /// `dispose` can decrement without touching `ref`; [_counted] guards the
  /// decrement so it happens exactly once per sheet.
  StateController<int>? _openFlag;
  bool _counted = false;

  @override
  void initState() {
    super.initState();
    _code = TextEditingController(text: InviteCode.normalize(widget.initialCode ?? '') ?? (widget.initialCode ?? ''));
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _openFlag = ref.read(openJoinSheetsProvider.notifier);
      _openFlag!.state++;
      _counted = true;
      if (widget.resume && _valid) unawaited(_join());
    });
  }

  @override
  void dispose() {
    // Safety net for a swipe / back dismissal; the deliberate closes below
    // lower the flag themselves. Providers must not change during a widget
    // life-cycle, so this runs once the frame is done (a microtask, not a
    // timer).
    if (_counted) {
      _counted = false;
      final flag = _openFlag!;
      scheduleMicrotask(() {
        try {
          flag.state--;
        } catch (_) {
          // Container already gone (app teardown).
        }
      });
    }
    _code.dispose();
    super.dispose();
  }

  void _closed() {
    if (!_counted) return;
    _counted = false;
    try {
      _openFlag!.state--;
    } catch (_) {
      // Container already gone.
    }
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
    final parking = ref.read(joinParkingProvider.notifier);
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.maybeOf(context);

    setState(() {
      _busy = true;
      _error = null;
      _stillRequired = false;
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
      await links.releaseEmptyForeignClaims(session.userId);
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
      // §8: the caller needs their own plan. A known "not active" stops
      // here (no request, the invite is untouched); an unknown verdict
      // (server unreachable, nothing cached) lets the server decide.
      if (await _knownNotEntitled()) {
        await _requireCloud(parking, code);
        return;
      }
      final col = await collections.join(code);
      await parking.clear();
      // Fill the new tenant right away (a no-op runner just returns).
      unawaited(ref.read(syncRunnerProvider).syncNow());
      messenger
        ?..clearSnackBars()
        ..showSnackBar(SnackBar(content: Text(t.shareJoined(collectionDisplayName(t, col)))));
      _closed();
      navigator.pop(col);
    } on PlantlyApiException catch (e) {
      if (e.status == 402 && e.errorCode != 'cloud_required_owner') {
        // `cloud_required`: our plan. The invite was not consumed (§8).
        if (mounted) await _requireCloud(parking, code);
        return;
      }
      // Terminal: the invite is dead / the join can never succeed as is
      // (invalid, already a member, deleted, owner lapsed, …) — nothing to
      // resume later.
      await parking.clear();
      _fail(t, e);
    } on PlantlyNetworkException catch (e) {
      // Offline: the parked code (if any) stays for the next attempt.
      _fail(t, e);
    } catch (e) {
      await parking.clear();
      _fail(t, e);
    }
  }

  /// Show [e] on the form (leaving the requirement step, whose invite is
  /// no longer worth waiting for — unless it was a network hiccup, when
  /// the step stays and shows the line).
  void _fail(AppLocalizations t, Object e) {
    if (!mounted) return;
    setState(() {
      _busy = false;
      _error = describeShareError(t, e);
      if (e is! PlantlyNetworkException) _cloudRequired = false;
    });
  }

  /// True when the entitlement is known and inactive. Errors / no value →
  /// false (unknown), the server is the judge then.
  Future<bool> _knownNotEntitled() async {
    try {
      final e = await ref.read(cloudEntitlementProvider.future);
      return e != null && !e.active;
    } catch (_) {
      return false;
    }
  }

  Future<void> _requireCloud(JoinParking parking, String code) async {
    await parking.park(
      code,
      reason: ParkReason.cloudRequired,
      userId: ref.read(plantlyAuthProvider).valueOrNull?.userId,
    );
    if (!mounted) return;
    setState(() {
      _busy = false;
      _error = null;
      _stillRequired = _cloudRequired; // second time round = a retry that failed
      _cloudRequired = true;
      _parkedCode = code;
    });
  }

  /// "Try again": re-ask the server for the entitlement, then join.
  Future<void> _retry() async {
    final notifier = ref.read(cloudEntitlementProvider.notifier);
    setState(() => _busy = true);
    try {
      await notifier.refresh();
    } catch (_) {
      // Offline: `_join` falls through to the server (or its cached verdict).
    }
    if (!mounted) return;
    await _join();
  }

  /// Explicit dismiss: forget the parked invite, close.
  Future<void> _dismiss() async {
    final navigator = Navigator.of(context);
    await ref.read(joinParkingProvider.notifier).clear();
    _closed();
    if (navigator.mounted) navigator.pop();
  }

  @override
  Widget build(BuildContext context) {
    final mode = ref.watch(themeModeProvider);
    final surface = mode == ThemeMode.dark ? PlantlySurface.dark : PlantlySurface.light;
    final t = AppLocalizations.of(context);
    final cloud = ref.watch(cloudStateProvider);
    final auth = ref.watch(plantlyAuthProvider);
    final inset = MediaQuery.of(context).viewInsets.bottom;
    final desktop = context.isDesktop;
    // Resume by itself: the plan turned active while the step was showing
    // (the user subscribed in the browser / Play and came back).
    ref.listen<AsyncValue<CloudEntitlement?>>(cloudEntitlementProvider, (prev, next) {
      if (!_cloudRequired || _busy) return;
      final was = prev?.valueOrNull?.active ?? false;
      if (!was && next.valueOrNull?.active == true) {
        // Off the provider's notification turn: `_join` reads providers
        // and calls setState.
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && _cloudRequired && !_busy) unawaited(_join());
        });
        WidgetsBinding.instance.scheduleFrame();
      }
    });
    // The session, not the cloud phase: the sheet signs in regardless of
    // the feature flag (a join link may arrive on a build with cloud off).
    final signedOut = !auth.isLoading && auth.valueOrNull == null;
    final notEntitled = cloud.phase == CloudPhase.notEntitled && !cloud.checking;
    final purchaseLink = ref.watch(cloudPurchaseLinkAllowedProvider);

    if (_cloudRequired) {
      // Two stacked buttons don't fit SheetChrome's fixed 64 px desktop
      // bar: on desktop they close the body instead (phone: unchanged,
      // the footer follows the body either way).
      final footer = _requirementFooter(t, surface, purchaseLink);
      return Padding(
        padding: EdgeInsets.only(bottom: inset),
        child: SheetChrome(
          surface: surface,
          title: t.shareJoinCloudRequiredTitle,
          subtitle: t.shareJoinCloudRequiredBody,
          crossAxisAlignment: CrossAxisAlignment.start,
          footer: desktop ? null : footer,
          children: [
            SafeArea(
              top: false,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Desktop: the SheetChrome header already carries the
                  // title + body as title/subtitle (#29).
                  if (!desktop) ...[
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.workspace_premium_outlined, size: 22, color: surface.terra),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            t.shareJoinCloudRequiredTitle,
                            key: const Key('join-cloud-required'),
                            style: TextStyle(
                              fontFamily: PlantlyFonts.plusJakartaSans,
                              fontSize: 19,
                              fontWeight: FontWeight.w800,
                              color: surface.text,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      t.shareJoinCloudRequiredBody,
                      key: const Key('join-cloud-required-body'),
                      style: TextStyle(fontSize: 12.5, height: 1.4, color: surface.muted),
                    ),
                    const SizedBox(height: 10),
                  ],
                  _Note(
                    icon: Icons.check_circle_outline,
                    text: t.cloudNotIncludedValue,
                    surface: surface,
                    key: const Key('join-cloud-pro-note'),
                    color: surface.green,
                  ),
                  if (_parkedCode != null) ...[
                    const SizedBox(height: 8),
                    _Note(
                      icon: Icons.schedule_outlined,
                      text: t.shareJoinParkedHint(_pretty(_parkedCode!)),
                      surface: surface,
                      key: const Key('join-cloud-parked'),
                    ),
                  ],
                  if (_error != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      _error!,
                      key: const Key('join-cloud-error'),
                      style: TextStyle(fontSize: 12, color: surface.terra, fontWeight: FontWeight.w600),
                    ),
                  ],
                  if (_stillRequired) ...[
                    const SizedBox(height: 8),
                    Text(
                      t.shareJoinStillRequired,
                      key: const Key('join-cloud-still-required'),
                      style: TextStyle(fontSize: 12, color: surface.terra, fontWeight: FontWeight.w600),
                    ),
                  ],
                  const SizedBox(height: 10),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      key: const Key('join-cloud-dismiss'),
                      onPressed: _busy ? null : _dismiss,
                      child: Text(t.shareJoinDismiss, style: TextStyle(color: surface.muted)),
                    ),
                  ),
                ],
              ),
            ),
            if (desktop) footer,
          ],
        ),
      );
    }

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
                // Desktop: title + body live in the SheetChrome header (#29).
                if (!desktop) ...[
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
                ],
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
                  // §8, up front: without a plan the join stops at the
                  // requirement step (the code is kept for later).
                  _Note(
                    icon: Icons.workspace_premium_outlined,
                    text: t.shareJoinCloudRequiredTitle,
                    surface: surface,
                    key: const Key('join-cloud-required-note'),
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

  Widget _requirementFooter(AppLocalizations t, PlantlySurface surface, bool purchaseLink) {
    final shape = RoundedRectangleBorder(borderRadius: BorderRadius.circular(PlantlyTokens.radius + 2));
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Web / desktop: the plantly.ro checkout. Android / iOS: no link
        // (store policy) — the copy above says what is needed.
        if (purchaseLink) ...[
          FilledButton.icon(
            key: const Key('join-cloud-subscribe'),
            style: FilledButton.styleFrom(
              backgroundColor: surface.green,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: shape,
            ),
            onPressed: () => launchUrl(Uri.parse(PlantlyHosts.subscriptionUrl()), mode: LaunchMode.externalApplication),
            icon: const Icon(Icons.open_in_new, size: 18),
            label: Text(t.cloudSubscribeLabel, style: const TextStyle(fontWeight: FontWeight.w700)),
          ),
          const SizedBox(height: 8),
        ],
        OutlinedButton.icon(
          key: const Key('join-cloud-retry'),
          style: OutlinedButton.styleFrom(
            foregroundColor: surface.text,
            side: BorderSide(color: surface.border),
            padding: const EdgeInsets.symmetric(vertical: 12),
            shape: shape,
          ),
          onPressed: _busy ? null : _retry,
          icon: _busy
              ? SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: surface.green))
              : const Icon(Icons.refresh, size: 18),
          label: Text(t.shareJoinRetry, style: const TextStyle(fontWeight: FontWeight.w700)),
        ),
      ],
    );
  }

  /// `ABCDEFGH` → `ABCD-EFGH` for reading.
  static String _pretty(String code) => code.length == 8 ? '${code.substring(0, 4)}-${code.substring(4)}' : code;
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
