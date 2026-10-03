import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../cloud/collections.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../marketplace/plantly_api.dart';
import '../../theme/tokens.dart';
import 'collection_ui.dart';
import 'sharing_rows.dart';

/// Active invites of a collection (`GET …/invites`, owner only —
/// MULTI-USER-V2 §2.5). Auto-disposed: the list lives as long as the
/// members sheet shows it; create / revoke invalidate it.
final invitesProvider = FutureProvider.autoDispose.family<List<CollectionInvite>, String>((ref, collectionId) {
  return ref.watch(collectionsProvider.notifier).listInvites(collectionId);
});

/// "Invites" block under the members list (owner only): header + "New
/// invite", one row per active invite (label, role badge, `used/max`,
/// relative expiry, trailing revoke with a short confirm), empty / error
/// states. Opens [showInviteSheet] and refreshes afterwards.
class InvitesSection extends ConsumerWidget {
  const InvitesSection({super.key, required this.collection, required this.surface});
  final CloudCollection collection;
  final PlantlySurface surface;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = AppLocalizations.of(context);
    final invites = ref.watch(invitesProvider(collection.id));
    return Column(
      key: const Key('invites-section'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 6, 0, 0),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  t.shareInvitesSection.toUpperCase(),
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 0.6, color: surface.muted),
                ),
              ),
              TextButton.icon(
                key: const Key('invites-new'),
                style: TextButton.styleFrom(foregroundColor: surface.green, visualDensity: VisualDensity.compact),
                onPressed: () async {
                  await showInviteSheet(context, collection);
                  ref.invalidate(invitesProvider(collection.id));
                },
                icon: const Icon(Icons.add, size: 16),
                label: Text(t.shareInviteNew),
              ),
            ],
          ),
        ),
        invites.when(
          loading: () => Padding(
            padding: const EdgeInsets.all(12),
            child: Center(
              child: SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: surface.green)),
            ),
          ),
          error: (e, _) => Padding(
            padding: const EdgeInsets.fromLTRB(4, 4, 4, 4),
            child: Text(
              t.shareInvitesError,
              key: const Key('invites-error'),
              style: TextStyle(fontSize: 12.5, color: surface.terra),
            ),
          ),
          data: (list) => list.isEmpty
              ? Padding(
                  padding: const EdgeInsets.fromLTRB(4, 4, 4, 4),
                  child: Text(
                    t.shareInvitesEmpty,
                    key: const Key('invites-empty'),
                    style: TextStyle(fontSize: 12.5, color: surface.muted),
                  ),
                )
              : Column(children: [for (final i in list) _InviteTile(collection: collection, invite: i, surface: surface)]),
        ),
      ],
    );
  }
}

class _InviteTile extends ConsumerWidget {
  const _InviteTile({required this.collection, required this.invite, required this.surface});
  final CloudCollection collection;
  final CollectionInvite invite;
  final PlantlySurface surface;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = AppLocalizations.of(context);
    final expiry = inviteExpiryLabel(t, invite.expiresAt);
    final meta = [t.shareInviteUses(invite.useCount, invite.maxUses), ?expiry].join(' · ');
    return Material(
      type: MaterialType.transparency,
      child: ListTile(
        key: Key('invite-${invite.id}'),
        dense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 4),
        leading: Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(border: Border.all(color: surface.border), shape: BoxShape.circle),
          child: Icon(Icons.vpn_key_outlined, size: 16, color: surface.muted),
        ),
        title: Row(
          children: [
            Flexible(
              child: Text(
                invite.label ?? t.shareInviteDefaultLabel,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: surface.text),
              ),
            ),
            const SizedBox(width: 8),
            RoleBadge(role: invite.role, surface: surface),
          ],
        ),
        subtitle: Text(meta, style: TextStyle(fontSize: 11.5, color: surface.muted)),
        trailing: IconButton(
          key: Key('invite-revoke-${invite.id}'),
          tooltip: t.shareInviteRevoke,
          visualDensity: VisualDensity.compact,
          icon: Icon(Icons.close, size: 18, color: surface.terra),
          onPressed: () => _revoke(context, ref, t),
        ),
      ),
    );
  }

  Future<void> _revoke(BuildContext context, WidgetRef ref, AppLocalizations t) async {
    final messenger = ScaffoldMessenger.maybeOf(context);
    final collections = ref.read(collectionsProvider.notifier); // before the await (#14)
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(t.shareInviteRevokeTitle),
        content: Text(t.shareInviteRevokeBody),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: Text(t.cancel)),
          FilledButton(
            key: const Key('invite-revoke-confirm'),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(t.shareInviteRevoke),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await collections.revokeInvite(collection.id, invite.id);
      ref.invalidate(invitesProvider(collection.id));
      messenger
        ?..clearSnackBars()
        ..showSnackBar(SnackBar(content: Text(t.shareInviteRevoked)));
    } catch (e) {
      messenger
        ?..clearSnackBars()
        ..showSnackBar(SnackBar(content: Text(describeShareError(t, e, action: ShareAction.invite))));
    }
  }
}
