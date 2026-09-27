import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../cloud/collections.dart';
import '../config/plantly_features.dart';
import '../data/database/app_database.dart';
import '../l10n/generated/app_localizations.dart';

/// `by <username>` for a care event logged by another member of a shared
/// collection (CLOUD-SYNC-CONTRACT §3 "who watered"), or null when the row
/// has no actor, the actor is the signed-in user, or the feature is off.
/// Names come from the members cache (`membersProvider(tenant)`); an actor
/// the cache does not know renders as "by another member".
String? careEventActorLabel(WidgetRef ref, AppLocalizations t, CareEventRow e) {
  final actor = e.actorUserId;
  if (actor == null || actor.isEmpty) return null;
  if (!ref.watch(cloudEnabledProvider)) return null;
  if (ref.watch(currentUserIdProvider) == actor) return null;
  final name = memberUsername(ref.watch(membersProvider(e.tenantId)).valueOrNull, actor);
  return name == null ? t.shareByOtherMember : t.shareByActor(name);
}

/// `<text> · by <name>` when there is an actor to show, else [text].
String withActor(String text, String? actor) => actor == null ? text : '$text · $actor';
