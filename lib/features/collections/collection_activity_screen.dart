import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../app/navigation.dart';
import '../../cloud/collection_activity.dart';
import '../../cloud/collections.dart';
import '../../config/plantly_features.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../marketplace/plantly_api.dart';
import '../../theme/tokens.dart';
import '../home/home_providers.dart';
import '../me/me_rows.dart';

/// "Activitate" for a shared collection (MULTI-USER-V2 §3): the server
/// feed, newest first, pull-to-refresh, "Load more", cached offline.
/// Route `/collections/:id/activity` ([openCollectionActivity]).

// --- copy (pure, unit-testable) ---------------------------------------------

/// "Maria added Monstera" / "Maria a adăugat Monstera".
String describeActivityEvent(AppLocalizations t, ActivityEvent e) {
  final user = e.user.isUnknown ? t.activityUnknownUser : e.user.username.trim();
  final object = describeActivityObject(t, e);
  return switch (e.kind) {
    ActivityKind.created => t.activityCreated(user, object),
    ActivityKind.updated => t.activityUpdated(user, object),
    ActivityKind.deleted => t.activityDeleted(user, object),
  };
}

/// The object phrase per codec entity, with a generic noun when the server
/// sent no `summary.name`.
String describeActivityObject(AppLocalizations t, ActivityEvent e) {
  final name = (e.summaryName ?? '').trim();
  final named = name.isNotEmpty;
  return switch (e.entity) {
    'plants' => named ? name : t.activityObjPlant,
    'locations' => named ? t.activityObjSpace(name) : t.activityObjSpaceUnnamed,
    'care_schedules' => named ? t.activityObjReminder(name) : t.activityObjReminderUnnamed,
    'care_events' => named ? t.activityObjCareEvent(name) : t.activityObjCareEventUnnamed,
    'photos' || 'plant_photos' || 'location_photos' => named ? t.activityObjPhoto(name) : t.activityObjPhotoUnnamed,
    _ => named ? name : t.activityObjItem,
  };
}

/// "just now" · "5 min ago" · "3 h ago" · "2 d ago" · "Sep 14".
String describeActivityTime(AppLocalizations t, DateTime at, {DateTime? now}) {
  final diff = (now ?? DateTime.now().toUtc()).difference(at.toUtc());
  if (diff.inMinutes < 1) return t.activityJustNow;
  if (diff.inHours < 1) return t.activityMinutesAgo(diff.inMinutes);
  if (diff.inDays < 1) return t.activityHoursAgo(diff.inHours);
  if (diff.inDays < 7) return t.homeDaysAgo(diff.inDays);
  return DateFormat.MMMd(t.localeName).format(at.toLocal());
}

/// "Last edited by Maria · 5 min ago", or null when [events] hold no edit
/// of [entityId] by someone other than [me].
String? describeLastEditedBy(
  AppLocalizations t,
  Iterable<ActivityEvent> events, {
  required String entityId,
  String? me,
  DateTime? now,
}) {
  final e = latestEditBy(events, entityId: entityId, excludeUserId: me);
  if (e == null) return null;
  final name = e.user.isUnknown ? t.activityUnknownUser : e.user.username.trim();
  final at = e.at;
  if (at == null) return t.activityLastEditedByNoTime(name);
  return t.activityLastEditedBy(name, describeActivityTime(t, at, now: now));
}

IconData activityEntityIcon(String entity) => switch (entity) {
      'plants' => Icons.local_florist_outlined,
      'locations' => Icons.place_outlined,
      'care_schedules' => Icons.alarm_outlined,
      'care_events' => Icons.water_drop_outlined,
      'photos' || 'plant_photos' || 'location_photos' => Icons.photo_outlined,
      _ => Icons.edit_outlined,
    };

// --- entry points -----------------------------------------------------------

/// Cloud screen row: "Activity · Who changed what in this collection" for
/// the collection on screen when it is shared; nothing otherwise.
class CollectionActivityRow extends ConsumerWidget {
  const CollectionActivityRow({super.key, required this.surface});
  final PlantlySurface surface;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!ref.watch(cloudEnabledProvider)) return const SizedBox.shrink();
    final col = ref.watch(activeCollectionProvider);
    if (!isSharedCollection(col)) return const SizedBox.shrink();
    final t = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: MeActionRow(
        key: const Key('cloud-activity'),
        label: t.activityEntryLabel,
        value: t.activityEntryValue,
        icon: Icons.history,
        surface: surface,
        onTap: () => openCollectionActivity(context, col!.id),
      ),
    );
  }
}

/// Collection switcher tile trailing: a history icon for shared
/// collections; `SizedBox.shrink()` for a private one.
class CollectionActivityIconButton extends StatelessWidget {
  const CollectionActivityIconButton({super.key, required this.collection, required this.surface});
  final CloudCollection collection;
  final PlantlySurface surface;

  @override
  Widget build(BuildContext context) {
    if (!isSharedCollection(collection)) return const SizedBox.shrink();
    final t = AppLocalizations.of(context);
    return IconButton(
      key: Key('collection-activity-${collection.id}'),
      tooltip: t.activityEntryTooltip(collection.displayName),
      visualDensity: VisualDensity.compact,
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints.tightFor(width: 32, height: 32),
      icon: Icon(Icons.history, size: 18, color: surface.muted),
      onPressed: () {
        Navigator.of(context).pop();
        openCollectionActivity(context, collection.id);
      },
    );
  }
}

/// Plant detail: "Last edited by Maria · 5 min ago", from the activity
/// cache of the plant's collection. Hidden when the collection is private
/// or the feed knows no edit by another member.
class LastEditedByLine extends ConsumerWidget {
  const LastEditedByLine({
    super.key,
    required this.tenantId,
    required this.entityId,
    required this.surface,
    this.padding = const EdgeInsets.only(top: 4),
  });
  final String tenantId;
  final String entityId;
  final PlantlySurface surface;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!ref.watch(cloudEnabledProvider)) return const SizedBox.shrink();
    final col = ref.watch(collectionsProvider.select((s) => s.byId(tenantId)));
    if (!isSharedCollection(col)) return const SizedBox.shrink();
    final me = ref.watch(currentUserIdProvider);
    final events = ref.watch(collectionActivityProvider(tenantId).select((s) => s.events));
    final text = describeLastEditedBy(AppLocalizations.of(context), events, entityId: entityId, me: me);
    if (text == null) return const SizedBox.shrink();
    return Padding(
      padding: padding,
      child: Row(
        key: const Key('plant-last-edited-by'),
        children: [
          Icon(Icons.history, size: 12, color: surface.muted),
          const SizedBox(width: 5),
          Flexible(
            child: Text(text, maxLines: 1, overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 12, color: surface.muted)),
          ),
        ],
      ),
    );
  }
}

// --- screen -----------------------------------------------------------------

class CollectionActivityScreen extends ConsumerWidget {
  const CollectionActivityScreen({super.key, required this.collectionId});
  final String collectionId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mode = ref.watch(themeModeProvider);
    final surface = mode == ThemeMode.dark ? PlantlySurface.dark : PlantlySurface.light;
    final t = AppLocalizations.of(context);
    final collection = ref.watch(collectionsProvider.select((s) => s.byId(collectionId)));
    final feed = ref.watch(collectionActivityProvider(collectionId));
    final notifier = ref.read(collectionActivityProvider(collectionId).notifier);

    return Scaffold(
      backgroundColor: surface.bg,
      appBar: AppBar(
        backgroundColor: surface.bg,
        elevation: 0,
        automaticallyImplyLeading: false,
        leading: detailLeading(context, surface, parent: AppRoutes.meSection('cloud')),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              t.activityScreenTitle,
              style: TextStyle(
                fontFamily: PlantlyFonts.plusJakartaSans,
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: surface.text,
                letterSpacing: -0.02 * 22,
              ),
            ),
            if (collection != null)
              Text(
                collection.displayName,
                key: const Key('activity-collection-name'),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 12, color: surface.muted),
              ),
          ],
        ),
      ),
      body: RefreshIndicator(
        color: surface.green,
        onRefresh: notifier.refresh,
        child: _body(context, t, surface, feed, notifier),
      ),
    );
  }

  Widget _body(
    BuildContext context,
    AppLocalizations t,
    PlantlySurface surface,
    ActivityFeedState feed,
    CollectionActivityNotifier notifier,
  ) {
    // Always a scrollable so pull-to-refresh works on the empty / error
    // states too.
    if (feed.isEmpty) {
      final Widget child;
      if (!feed.loaded || (feed.loading && feed.error == null)) {
        child = Center(child: CircularProgressIndicator(color: surface.green));
      } else if (feed.error != null) {
        child = _Message(
          key: const Key('activity-error'),
          icon: Icons.cloud_off_outlined,
          text: '${t.activityLoadError}\n${_describeError(t, feed.error!)}',
          surface: surface,
          color: surface.terra,
        );
      } else {
        child = _Message(
          key: const Key('activity-empty'),
          icon: Icons.history,
          text: t.activityFeedEmpty,
          surface: surface,
        );
      }
      return LayoutBuilder(
        builder: (context, c) => ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: [SizedBox(height: c.maxHeight, child: child)],
        ),
      );
    }

    final events = feed.events;
    return ListView.builder(
      key: const Key('activity-list'),
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
      itemCount: events.length + 2,
      itemBuilder: (context, i) {
        if (i == 0) {
          if (feed.error == null) return const SizedBox.shrink();
          return _Banner(
            key: const Key('activity-offline-banner'),
            text: feed.error is PlantlyNetworkException ? t.activityCachedOffline : t.activityLoadError,
            surface: surface,
          );
        }
        if (i == events.length + 1) {
          if (!feed.hasMore) return const SizedBox(height: 8);
          return Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Center(
              child: feed.loadingMore
                  ? SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(strokeWidth: 2, color: surface.green),
                    )
                  : TextButton.icon(
                      key: const Key('activity-load-more'),
                      onPressed: notifier.loadMore,
                      icon: Icon(Icons.expand_more, size: 18, color: surface.green),
                      label: Text(
                        t.activityLoadMore,
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: surface.green),
                      ),
                    ),
            ),
          );
        }
        final e = events[i - 1];
        return ActivityEventTile(event: e, surface: surface, last: i == events.length);
      },
    );
  }

  static String _describeError(AppLocalizations t, Object e) {
    if (e is PlantlyNetworkException) return t.plantlyErrorNetwork;
    if (e is PlantlyApiException) {
      if (e.isRateLimited) return t.plantlyErrorRateLimited;
      if (e.status == 403 || e.status == 404 || e.status == 410) return t.cloudErrCollectionUnavailable;
      return e.message;
    }
    return '$e';
  }
}

/// One feed row: avatar initial · "Maria added Monstera" · "5 min ago".
class ActivityEventTile extends StatelessWidget {
  const ActivityEventTile({super.key, required this.event, required this.surface, this.last = false, this.now});
  final ActivityEvent event;
  final PlantlySurface surface;
  final bool last;

  /// Test clock.
  final DateTime? now;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final username = event.user.username.trim();
    // Unknown / blank user → neutral glyph, never a letter from the fallback copy.
    final initial = username.isEmpty ? '?' : username.characters.first.toUpperCase();
    return Container(
      key: Key('activity-event-${event.seq}'),
      decoration: BoxDecoration(border: last ? null : Border(bottom: BorderSide(color: surface.border))),
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 32,
            height: 32,
            alignment: Alignment.center,
            decoration: BoxDecoration(color: surface.greenSoft, shape: BoxShape.circle),
            child: Text(initial, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: surface.green)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  describeActivityEvent(t, event),
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: surface.text, height: 1.3),
                ),
                const SizedBox(height: 3),
                Row(
                  children: [
                    Icon(activityEntityIcon(event.entity), size: 12, color: surface.muted),
                    if (event.at != null) ...[
                      const SizedBox(width: 4),
                      Text(describeActivityTime(t, event.at!, now: now), style: TextStyle(fontSize: 12, color: surface.muted)),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Message extends StatelessWidget {
  const _Message({super.key, required this.icon, required this.text, required this.surface, this.color});
  final IconData icon;
  final String text;
  final PlantlySurface surface;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 36, color: color ?? surface.muted),
            const SizedBox(height: 12),
            Text(text, textAlign: TextAlign.center, style: TextStyle(color: color ?? surface.muted, fontSize: 14, height: 1.4)),
          ],
        ),
      ),
    );
  }
}

class _Banner extends StatelessWidget {
  const _Banner({super.key, required this.text, required this.surface});
  final String text;
  final PlantlySurface surface;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: surface.terraSoft,
        borderRadius: BorderRadius.circular(PlantlyTokens.radius),
      ),
      child: Row(
        children: [
          Icon(Icons.cloud_off_outlined, size: 16, color: surface.terra),
          const SizedBox(width: 8),
          Expanded(child: Text(text, style: TextStyle(fontSize: 12, color: surface.terra))),
        ],
      ),
    );
  }
}
