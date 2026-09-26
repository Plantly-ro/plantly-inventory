import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config/plantly_features.dart';
import '../marketplace/plantly_auth.dart';
import 'collection_link.dart';
import 'entitlement.dart';

/// Where the device stands on the cloud ladder (CLOUD-SYNC-CONTRACT §2.4
/// status surface). Strictly ordered: each phase implies the ones before.
enum CloudPhase {
  /// Feature flag off — nothing cloud-related renders or runs.
  off,

  /// No plantly.ro session.
  signedOut,

  /// Signed in, but no `inventory_cloud` entitlement (or still checking —
  /// see [CloudState.checking]).
  notEntitled,

  /// Signed in + entitled. Syncable once [CloudState.collectionId] is set.
  ready,
}

class CloudState {
  const CloudState({
    required this.phase,
    this.account,
    this.entitlement,
    this.collectionId,
    this.collectionName,
    this.checking = false,
    this.unlinkedByUser = false,
    this.heldByOther,
  });

  final CloudPhase phase;

  /// Username of the signed-in account (null when signed out).
  final String? account;
  final CloudEntitlement? entitlement;
  final String? collectionId;
  final String? collectionName;

  /// The session or entitlement lookup is still in flight; the UI shows a
  /// neutral "checking" copy instead of the phase's verdict.
  final bool checking;

  /// The user chose "Unlink this device": stay unlinked until they ask
  /// again — no automatic re-link.
  final bool unlinkedByUser;

  /// Display name of another account whose collection this device is still
  /// linked to. Non-null = the user must decide (move / start empty) before
  /// anything links or syncs; nothing happens automatically.
  final String? heldByOther;

  static const CloudState off = CloudState(phase: CloudPhase.off);

  bool get linked => collectionId != null && collectionId!.isNotEmpty;

  /// The engine's green light: entitled and a collection to talk to.
  bool get canSync => phase == CloudPhase.ready && linked;

  @override
  bool operator ==(Object other) =>
      other is CloudState &&
      other.phase == phase &&
      other.account == account &&
      other.entitlement == entitlement &&
      other.collectionId == collectionId &&
      other.collectionName == collectionName &&
      other.checking == checking &&
      other.unlinkedByUser == unlinkedByUser &&
      other.heldByOther == heldByOther;

  @override
  int get hashCode =>
      Object.hash(phase, account, entitlement, collectionId, collectionName, checking, unlinkedByUser, heldByOther);

  @override
  String toString() => 'CloudState($phase, account=$account, linked=$linked, checking=$checking)';
}

/// Pure derivation: flag × session × entitlement × link → [CloudState].
final cloudStateProvider = Provider<CloudState>((ref) {
  if (!ref.watch(cloudEnabledProvider)) return CloudState.off;
  final auth = ref.watch(plantlyAuthProvider);
  final session = auth.valueOrNull;
  if (session == null) {
    return CloudState(phase: CloudPhase.signedOut, checking: auth.isLoading);
  }
  final entitlement = ref.watch(cloudEntitlementProvider);
  final linkState = ref.watch(collectionLinkProvider);
  // A link made by another account on this device does not count — and
  // blocks auto-linking until the user decides what to do with that data.
  final stored = linkState.link;
  final foreign = stored != null && stored.userId != session.userId;
  final link = foreign ? null : stored;
  final e = entitlement.valueOrNull;
  return CloudState(
    phase: e == null || !e.active ? CloudPhase.notEntitled : CloudPhase.ready,
    account: session.username,
    entitlement: e,
    collectionId: link?.id,
    collectionName: link?.name,
    checking: entitlement.isLoading,
    unlinkedByUser: linkState.unlinkedByUser,
    heldByOther: foreign ? stored.accountLabel : null,
  );
});
