import 'dart:async';

import 'package:flutter/foundation.dart' show defaultTargetPlatform, kIsWeb, TargetPlatform;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../cloud/account_decision.dart';
import '../../cloud/cloud_state.dart';
import '../../cloud/collection_link.dart';
import '../../cloud/collections.dart';
import '../../cloud/entitlement.dart';
import '../../cloud/join_parking.dart';
import '../../cloud/play_billing.dart';
import '../../cloud/play_billing_providers.dart';
import '../../cloud/sign_in_events.dart';
import '../../cloud/cloud_sync.dart';
import '../../cloud/sync_runner.dart';
import '../../app/navigation.dart';
import '../../config/plantly_features.dart';
import '../../config/plantly_hosts.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../marketplace/plantly_api.dart';
import '../../marketplace/plantly_auth.dart';
import '../../plugins/plantly_ro/login_sheet.dart';
import '../../theme/tokens.dart';
import '../collections/sharing_rows.dart';
import 'me_rows.dart';
import 'play_plan_picker.dart';
import 'sync_rejections_screen.dart';

/// Whether this build may link to the plantly.ro checkout. Google Play
/// policy (CLOUD-SYNC-CONTRACT §0): the Android app never links to a web
/// purchase; iOS follows the same rule. Web + desktop may.
final cloudPurchaseLinkAllowedProvider = Provider<bool>((_) {
  if (kIsWeb) return true;
  return defaultTargetPlatform != TargetPlatform.android && defaultTargetPlatform != TargetPlatform.iOS;
});

/// Me → Cloud (§2.4 status surface). Renders nothing when the feature flag
/// is off; otherwise a section header (tap → `/me/cloud`, the `CloudScreen`)
/// and the rows for the current [CloudPhase].
class CloudSection extends ConsumerWidget {
  const CloudSection({super.key, required this.surface});
  final PlantlySurface surface;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(cloudStateProvider);
    if (state.phase == CloudPhase.off) return const SizedBox.shrink();
    final t = AppLocalizations.of(context);
    return Column(
      key: const Key('me-cloud-section'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 20),
        InkWell(
          key: const Key('cloud-section-title'),
          borderRadius: BorderRadius.circular(PlantlyTokens.radius),
          onTap: () => openMeSection(context, 'cloud'),
          child: Row(
            children: [
              Expanded(child: MeSectionLabel(text: t.cloudSectionTitle, surface: surface)),
              Icon(Icons.chevron_right, size: 16, color: surface.muted),
            ],
          ),
        ),
        const SizedBox(height: 8),
        CloudRows(surface: surface, detailed: false),
        // Shared collections (§3): hidden with 0/1 collection.
        SharingSummaryRow(surface: surface, onTap: () => openMeSection(context, 'cloud')),
      ],
    );
  }
}

/// The phase-dependent rows, shared by the Me section and [CloudScreen].
/// Also the place that kicks off the one-time collection link once the
/// account is entitled (§2.4 "Linking").
class CloudRows extends ConsumerStatefulWidget {
  const CloudRows({super.key, required this.surface, required this.detailed});
  final PlantlySurface surface;
  final bool detailed;

  @override
  ConsumerState<CloudRows> createState() => _CloudRowsState();
}

class _CloudRowsState extends ConsumerState<CloudRows> {
  bool _linking = false;
  String? _linkError;

  /// Account the automatic link was last attempted for. One attempt per
  /// account: a failure leaves a "tap to retry" row instead of re-firing on
  /// every state tick (which would hammer the server while offline).
  String? _autoLinkedFor;

  PlantlySurface get surface => widget.surface;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _maybeAutoLink(ref.read(cloudStateProvider));
    });
  }

  /// Links entitled AND not-entitled accounts alike (§3: the link names
  /// "home"; editors sync shared collections on the owner's plan) — never
  /// while signed out, checking, unlinked by the user or undecided.
  void _maybeAutoLink(CloudState state) {
    if (state.phase == CloudPhase.off || state.phase == CloudPhase.signedOut) return;
    if (state.linked || state.checking || state.unlinkedByUser) return;
    if (state.heldByOther != null) return; // the user decides — never automatic
    if (_linking || _autoLinkedFor == state.account) return;
    _autoLinkedFor = state.account;
    unawaited(_link());
  }

  Future<void> _link() async {
    final links = ref.read(collectionLinkProvider.notifier);
    setState(() {
      _linking = true;
      _linkError = null;
    });
    try {
      await links.link();
    } catch (e) {
      if (mounted) setState(() => _linkError = _describe(e));
    } finally {
      if (mounted) setState(() => _linking = false);
    }
  }

  String _describe(Object e) => describeLinkError(AppLocalizations.of(context), e);

  @override
  Widget build(BuildContext context) {
    ref.listen<CloudState>(cloudStateProvider, (_, next) => _maybeAutoLink(next));
    final state = ref.watch(cloudStateProvider);
    final t = AppLocalizations.of(context);
    final rows = switch (state.phase) {
      CloudPhase.off => const <Widget>[],
      CloudPhase.signedOut => _signedOut(t),
      CloudPhase.notEntitled => _notEntitled(t, state),
      CloudPhase.ready => _ready(t, state),
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < rows.length; i++) ...[
          if (i > 0) const SizedBox(height: 6),
          rows[i],
        ],
      ],
    );
  }

  List<Widget> _signedOut(AppLocalizations t) => [
        MeActionRow(
          key: const Key('cloud-sign-in'),
          label: t.cloudSignInLabel,
          value: t.cloudSignInPitch,
          icon: Icons.cloud_outlined,
          surface: surface,
          onTap: _signIn,
        ),
      ];

  List<Widget> _notEntitled(AppLocalizations t, CloudState state) {
    // The decision comes before the paywall: a user without a plan can
    // still hold (and join, §3) collections, and never on top of another
    // account's link.
    if (state.heldByOther != null) return _heldByOther(t, state);
    final purchaseLink = ref.watch(cloudPurchaseLinkAllowedProvider);
    // Android with both flags on: buy in-app (PLAY-BILLING-CONTRACT §4). The
    // picker never shows while the entitlement is still being checked —
    // "no purchase CTA when entitled" (§0) must be decided on fresh data.
    final playBilling = ref.watch(playBillingAvailableProvider) && !state.checking;
    final collectionName = ref.watch(activeCollectionProvider)?.displayName;
    // A shared collection still pulls under the read grace here (§8), so
    // its status / last error stay visible.
    final sharedActive = ref.watch(activeCollectionIsSharedProvider);
    final status = ref.watch(syncStatusProvider).valueOrNull ?? SyncStatus.empty;
    final needsCloudForShared =
        !state.checking && (ref.watch(sharedCollectionsNeedCloudProvider) || ref.watch(parkedJoinForSessionProvider) != null);
    return [
      if (sharedActive)
        MeActionRow(
          key: const Key('cloud-status'),
          label: t.cloudStatusLabel,
          value: describeSyncStatus(t, status),
          icon: status.inFlight ? Icons.cloud_sync_outlined : Icons.cloud_done_outlined,
          surface: surface,
          valueColor: status.lastError != null ? surface.terra : null,
          onTap: widget.detailed ? null : () => openMeSection(context, 'cloud'),
        ),
      if (sharedActive && widget.detailed && status.lastError != null)
        MeActionRow(
          key: const Key('cloud-last-error'),
          label: t.cloudLastErrorLabel,
          value: describeSyncError(t, status.lastError!,
              detail: status.lastErrorDetail, status: status, collectionName: collectionName, web: ref.watch(webPlatformProvider)),
          icon: Icons.error_outline,
          surface: surface,
          valueColor: surface.terra,
        ),
      MeActionRow(
        key: const Key('cloud-not-included'),
        label: t.cloudNotIncludedLabel,
        value: state.checking ? t.cloudChecking : t.cloudNotIncludedValue,
        icon: Icons.cloud_off_outlined,
        surface: surface,
      ),
      // MULTI-USER-V2 §8: every member of a shared collection needs their
      // own plan. With shared collections (or an invite waiting) and no
      // plan: say so, with the subscribe path where policy allows a link
      // (web / desktop) and the plain policy copy on Android / iOS.
      if (needsCloudForShared)
        MeActionRow(
          key: const Key('cloud-shared-requires'),
          label: t.cloudSharedRequiresLabel,
          value: purchaseLink ? t.cloudSharedRequiresValueLink : t.cloudSharedRequiresValue,
          icon: purchaseLink ? Icons.open_in_new : Icons.group_outlined,
          surface: surface,
          valueColor: surface.terra,
          onTap: purchaseLink
              ? () => launchUrl(Uri.parse(PlantlyHosts.subscriptionUrl()), mode: LaunchMode.externalApplication)
              : null,
        ),
      if (playBilling) PlayPlanPicker(surface: surface),
      if (purchaseLink)
        MeActionRow(
          key: const Key('cloud-subscribe'),
          label: t.cloudSubscribeLabel,
          value: t.cloudSubscribeValue,
          icon: Icons.open_in_new,
          surface: surface,
          onTap: () => launchUrl(Uri.parse(PlantlyHosts.subscriptionUrl()), mode: LaunchMode.externalApplication),
        ),
      MeActionRow(
        key: const Key('cloud-refresh'),
        label: t.cloudRefreshStatusLabel,
        value: t.cloudRefreshStatusValue,
        icon: Icons.refresh,
        surface: surface,
        onTap: state.checking ? null : _refreshEntitlement,
      ),
      _accountRow(t, state),
    ];
  }

  /// Account switch: the persisted link belongs to [CloudState.heldByOther].
  List<Widget> _heldByOther(AppLocalizations t, CloudState state) {
    final other = state.heldByOther!;
    final me = state.account ?? '';
    return [
      MeActionRow(
        key: const Key('cloud-held-by-other'),
        label: t.cloudStatusLabel,
        value: _linking ? t.cloudSettingUp : (_linkError ?? t.cloudHeldByOther(other)),
        icon: Icons.switch_account_outlined,
        surface: surface,
        valueColor: _linkError != null ? surface.terra : null,
      ),
      MeActionRow(
        key: const Key('cloud-move-to-me'),
        label: t.cloudMoveToMeLabel(me),
        value: t.cloudMoveToMeValue(other),
        icon: Icons.drive_file_move_outline,
        surface: surface,
        onTap: _linking ? null : () => _moveToMe(other, me),
      ),
      MeActionRow(
        key: const Key('cloud-start-empty'),
        label: t.cloudStartEmptyLabel(me),
        value: t.cloudStartEmptyValue(other),
        icon: Icons.fiber_new_outlined,
        surface: surface,
        onTap: _linking ? null : _startEmpty,
      ),
      _accountRow(t, state),
    ];
  }

  List<Widget> _ready(AppLocalizations t, CloudState state) {
    if (state.heldByOther != null) return _heldByOther(t, state);
    final status = ref.watch(syncStatusProvider).valueOrNull ?? SyncStatus.empty;
    final collectionName = ref.watch(activeCollectionProvider)?.displayName;
    final String statusText;
    Color? statusColor;
    VoidCallback? statusTap;
    if (!state.linked) {
      if (_linking) {
        statusText = t.cloudSettingUp;
      } else if (_linkError != null) {
        statusText = t.cloudSetupFailed;
        statusColor = surface.terra;
        statusTap = _link;
      } else if (state.unlinkedByUser) {
        statusText = t.cloudSyncOffHere;
        statusTap = _link;
      } else {
        statusText = t.cloudSettingUp;
      }
    } else {
      statusText = describeSyncStatus(t, status);
      if (status.lastError != null) statusColor = surface.terra;
      if (!widget.detailed) {
        statusTap = () => openMeSection(context, 'cloud');
      }
    }
    return [
      MeActionRow(
        key: const Key('cloud-status'),
        label: t.cloudStatusLabel,
        value: statusText,
        icon: status.inFlight ? Icons.cloud_sync_outlined : Icons.cloud_done_outlined,
        surface: surface,
        valueColor: statusColor,
        onTap: statusTap,
      ),
      if (widget.detailed) ...[
        MeActionRow(
          key: const Key('cloud-plan'),
          label: t.cloudPlanLabel,
          value: describeEntitlement(t, state.entitlement),
          icon: Icons.workspace_premium_outlined,
          surface: surface,
        ),
        if (state.entitlement?.managedByPlay == true)
          MeActionRow(
            key: const Key('cloud-manage-play'),
            label: t.cloudPlayManageLabel,
            value: t.cloudPlayManageValue,
            icon: Icons.open_in_new,
            surface: surface,
            onTap: () => launchUrl(Uri.parse(kPlayManageSubscriptionUrl), mode: LaunchMode.externalApplication),
          ),
        if (state.linked)
          MeActionRow(
            key: const Key('cloud-collection'),
            label: t.cloudCollectionLabel,
            value: (state.collectionName ?? '').isEmpty ? state.collectionId! : state.collectionName!,
            icon: Icons.folder_outlined,
            surface: surface,
          ),
        if (status.lastError != null)
          MeActionRow(
            key: const Key('cloud-last-error'),
            label: t.cloudLastErrorLabel,
            value: describeSyncError(t, status.lastError!,
                detail: status.lastErrorDetail, status: status, collectionName: collectionName, web: ref.watch(webPlatformProvider)),
            icon: Icons.error_outline,
            surface: surface,
            valueColor: surface.terra,
          ),
        if (status.lastError == 'rejected')
          MeActionRow(
            key: const Key('cloud-rejections'),
            label: t.cloudRejDetailsLabel,
            value: t.cloudRejDetailsValue,
            icon: Icons.list_alt_outlined,
            surface: surface,
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const SyncRejectionsScreen()),
            ),
          ),
      ],
      MeActionRow(
        key: const Key('cloud-sync-now'),
        label: t.cloudSyncNowLabel,
        value: t.cloudSyncNowValue,
        icon: Icons.sync,
        surface: surface,
        onTap: state.linked && !status.inFlight ? _syncNow : null,
      ),
      _accountRow(t, state),
      // Not on web: the browser IS the Inventory Cloud surface. Unlinking it
      // would leave the gate open on a stale, unsynced browser copy whose
      // edits never reach the account — signing out is the browser's exit.
      if (!ref.watch(webPlatformProvider))
        MeActionRow(
          key: const Key('cloud-unlink'),
          label: t.cloudUnlinkLabel,
          value: t.cloudUnlinkValue,
          icon: Icons.link_off,
          surface: surface,
          onTap: state.linked ? _unlink : null,
        ),
    ];
  }

  Widget _accountRow(AppLocalizations t, CloudState state) => MeActionRow(
        key: const Key('cloud-account'),
        label: t.cloudAccountLabel,
        value: t.cloudAccountValue(state.account ?? ''),
        icon: Icons.person_outline,
        surface: surface,
        valueColor: surface.green,
        onTap: () => _signOut(state.account ?? ''),
      );

  // --- actions -------------------------------------------------------------

  Future<void> _moveToMe(String other, String me) async {
    final ok = await confirmMoveToMe(context, other: other, me: me);
    if (!ok || !mounted) return; // cancel = stay as is (sticky)
    await _link();
  }

  Future<void> _startEmpty() async {
    final links = ref.read(collectionLinkProvider.notifier); // before the await (#14)
    setState(() {
      _linking = true;
      _linkError = null;
    });
    try {
      await links.startEmpty();
    } catch (e) {
      if (mounted) setState(() => _linkError = _describe(e));
    } finally {
      if (mounted) setState(() => _linking = false);
    }
  }

  Future<void> _signIn() async {
    final auth = ref.read(plantlyAuthProvider.notifier); // before the await (#14)
    final events = ref.read(signInEventsProvider);
    final session = await showPlantlyLoginSheet(context, auth: auth, purpose: LoginPurpose.cloud);
    if (session != null) events.emit(session);
  }

  Future<void> _refreshEntitlement() async {
    final messenger = ScaffoldMessenger.of(context);
    final t = AppLocalizations.of(context);
    final notifier = ref.read(cloudEntitlementProvider.notifier);
    try {
      await notifier.refresh();
    } catch (e) {
      messenger
        ..clearSnackBars()
        ..showSnackBar(SnackBar(content: Text(e is PlantlyNetworkException ? t.plantlyErrorNetwork : '$e')));
    }
  }

  Future<void> _syncNow() async {
    final messenger = ScaffoldMessenger.of(context);
    final t = AppLocalizations.of(context);
    final runner = ref.read(syncRunnerProvider);
    messenger
      ..clearSnackBars()
      ..showSnackBar(SnackBar(content: Text(t.cloudSyncing)));
    await runner.syncNow();
  }

  Future<void> _signOut(String username) async {
    final t = AppLocalizations.of(context);
    final auth = ref.read(plantlyAuthProvider.notifier); // before the await (#14)
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(t.cloudSignOutTitle),
        content: Text(t.cloudSignOutBody(username)),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: Text(t.cancel)),
          FilledButton(
            key: const Key('cloud-sign-out-confirm'),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(t.cloudSignOut),
          ),
        ],
      ),
    );
    if (ok == true) await auth.signOut();
  }

  Future<void> _unlink() async {
    final t = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final links = ref.read(collectionLinkProvider.notifier); // before the await (#14)
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(t.cloudUnlinkTitle),
        content: Text(t.cloudUnlinkBody),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: Text(t.cancel)),
          FilledButton(
            key: const Key('cloud-unlink-confirm'),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(t.cloudUnlink),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await links.unlink();
    messenger
      ..clearSnackBars()
      ..showSnackBar(SnackBar(content: Text(t.cloudUnlinked)));
  }
}

// --- formatting helpers (pure, unit-testable) --------------------------------

/// "Synced 5 min ago · 3 changes waiting · 12 MB of 2 GB used".
String describeSyncStatus(AppLocalizations t, SyncStatus s, {DateTime? now}) {
  final parts = <String>[
    if (s.inFlight) t.cloudSyncing else describeLastSync(t, s.lastSyncAt, now: now),
    t.cloudPendingOps(s.pendingOps),
    if (s.bytesStored != null && s.bytesQuota != null)
      t.cloudStorageUsed(formatCloudBytes(s.bytesStored!), formatCloudBytes(s.bytesQuota!)),
  ];
  return parts.join(' · ');
}

String describeLastSync(AppLocalizations t, DateTime? at, {DateTime? now}) {
  if (at == null) return t.cloudLastSyncNever;
  final diff = (now ?? DateTime.now().toUtc()).difference(at.toUtc());
  if (diff.inMinutes < 1) return t.cloudLastSyncJustNow;
  if (diff.inHours < 1) return t.cloudLastSyncMinutes(diff.inMinutes);
  if (diff.inDays < 1) return t.cloudLastSyncHours(diff.inHours);
  return t.cloudLastSyncDays(diff.inDays);
}

String describeEntitlement(AppLocalizations t, CloudEntitlement? e) {
  if (e == null || !e.active) return t.cloudNotIncludedValue;
  final base = e.source == 'pro' ? t.cloudEntitlementSourcePro : t.cloudEntitlementSourceCloud;
  final source = e.managedByPlay ? '$base · ${t.cloudEntitlementViaPlay}' : base;
  final end = e.currentPeriodEnd;
  if (end == null) return source;
  final date = DateFormat.yMMMd(t.localeName).format(end.toLocal());
  return '$source · ${e.cancelAtPeriodEnd ? t.cloudEndsOn(date) : t.cloudRenewsOn(date)}';
}

/// Engine error codes (`SyncStatus.lastError`) → copy; anything else is
/// shown as-is. [detail] is `SyncStatus.lastErrorDetail` (the offending
/// `<entity>/<id>` for `op_too_large`, [kOwnerPlanLapsedDetail] /
/// [kMemberPlanLapsedDetail] for a 402 on a shared collection — the owner's
/// plan vs the caller's own, MULTI-USER-V2 §8 — the server code for
/// `collection_unavailable`);
/// `rejected` reads the count and server reason from [status] and falls
/// back to [detail] without it. [collectionName] names the collection for
/// the `not_a_member` copy ("You were removed from …"). The MULTI-USER-V2
/// halts (`read_only`, `device_revoked`, `too_many_devices`) and the
/// `device_lookup_failed` retry each get their own line.
/// [web]: the browser build has no "Unlink this device", so the generic
/// collection-unavailable copy points at signing out and in again.
String describeSyncError(AppLocalizations t, String code,
        {String? detail, SyncStatus? status, String? collectionName, bool web = false}) =>
    switch (code) {
      'cloud_required' => switch (detail) {
          kOwnerPlanLapsedDetail => t.shareErrOwnerLapsed,
          kMemberPlanLapsedDetail => t.shareErrMemberLapsed,
          _ => t.cloudNotIncludedValue,
        },
      'unauthorized' => t.cloudSignInLabel,
      'collection_unavailable' => switch (detail) {
          kNotAMemberDetail when collectionName != null && collectionName.isNotEmpty =>
            t.shareRemovedFromCollection(collectionName),
          kReadOnlyDetail => t.shareErrReadOnly,
          kDeviceRevokedDetail => t.shareErrDeviceRevoked,
          kTooManyDevicesDetail => t.shareErrTooManyDevices,
          _ => web ? t.cloudErrCollectionUnavailableWeb : t.cloudErrCollectionUnavailable,
        },
      'quota_exceeded' => t.cloudErrQuotaExceeded,
      'op_too_large' => detail == null || detail.isEmpty ? t.cloudErrOpTooLarge : t.cloudErrOpTooLargeDetail(detail),
      'rejected' => status != null && status.rejectedOps > 0
          ? t.cloudErrRejected(status.rejectedOps, status.rejectedReason ?? '?')
          : (detail ?? code),
      'retrying' => detail == kDeviceLookupFailedDetail ? t.shareErrDeviceLookupFailed : t.cloudErrRetrying,
      'offline' => t.cloudErrOffline,
      'error' => t.cloudErrGeneric,
      _ => code,
    };

/// 1024-based, at most one decimal: `0 B`, `512 KB`, `1.5 MB`, `2 GB`.
String formatCloudBytes(int bytes) {
  const units = ['B', 'KB', 'MB', 'GB', 'TB'];
  var v = bytes.toDouble();
  var i = 0;
  while (v >= 1024 && i < units.length - 1) {
    v /= 1024;
    i++;
  }
  final text = i == 0 || v >= 100 || v == v.roundToDouble() ? v.round().toString() : v.toStringAsFixed(1);
  return '$text ${units[i]}';
}
