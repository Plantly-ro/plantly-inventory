import 'dart:async';

import 'package:drift/drift.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../app/breakpoints.dart';
import '../app/navigation.dart';
import '../data/database/app_database.dart';
import '../data/providers.dart';
import '../l10n/generated/app_localizations.dart';
import 'reminder_payload.dart';

/// Where a tapped reminder leads.
enum ReminderTapTarget {
  /// The plant is live in the active tenant: open its detail.
  plant,

  /// The plant lives in another (hidden) collection on this device.
  otherCollection,

  /// The plant was deleted (or never synced here).
  gone,
}

/// Resolve [payload] against the database: the plant must be alive in
/// [activeTenant] to be opened. The payload's tenant is not trusted for
/// this — a link / move re-tenants rows after the reminder was armed.
Future<ReminderTapTarget> resolveReminderTap(AppDatabase db, String activeTenant, ReminderPayload payload) async {
  final rows = await (db.select(db.plants)
        ..where((p) => p.id.equals(payload.plantId) & p.deletedAt.isNull()))
      .get();
  if (rows.any((p) => p.tenantId == activeTenant)) return ReminderTapTarget.plant;
  if (rows.isNotEmpty) return ReminderTapTarget.otherCollection;
  return ReminderTapTarget.gone;
}

/// Sits under `MaterialApp` (via `builder`, below the root
/// ScaffoldMessenger) and turns a tapped plant-care reminder into the
/// plant's detail page — for taps while the app runs
/// ([NotificationService.taps]) and for the tap that cold-started it
/// ([NotificationService.takeLaunchPayload]). A plant in another collection
/// or one that is gone lands on Home with a short notice instead.
class NotificationTapListener extends ConsumerStatefulWidget {
  const NotificationTapListener({super.key, required this.router, required this.child});

  final GoRouter router;
  final Widget child;

  @override
  ConsumerState<NotificationTapListener> createState() => _NotificationTapListenerState();
}

class _NotificationTapListenerState extends ConsumerState<NotificationTapListener> {
  StreamSubscription<String>? _sub;

  @override
  void initState() {
    super.initState();
    final svc = ref.read(notificationServiceProvider);
    _sub = svc.taps.listen((p) => unawaited(_handle(p)));
    unawaited(svc.takeLaunchPayload().then((p) {
      if (p != null) return _handle(p);
    }).catchError((Object _) {}));
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  Future<void> _handle(String raw) async {
    final payload = ReminderPayload.decode(raw);
    if (payload == null) return; // older reminder without a payload: the app just opens
    final AppContext ctx;
    try {
      ctx = await ref.read(appContextProvider.future);
    } catch (_) {
      return;
    }
    final target = await resolveReminderTap(ctx.db, ctx.tenantId, payload);
    if (!mounted) return;
    final router = widget.router;
    switch (target) {
      case ReminderTapTarget.plant:
        final location = AppRoutes.plant(payload.plantId);
        if (router.routerDelegate.currentConfiguration.uri.path == location) return;
        if (context.isDesktop) {
          router.go(location);
        } else {
          router.push(location);
        }
      case ReminderTapTarget.otherCollection:
      case ReminderTapTarget.gone:
        router.go(AppRoutes.home);
        final t = AppLocalizations.of(context);
        ScaffoldMessenger.maybeOf(context)
          ?..clearSnackBars()
          ..showSnackBar(SnackBar(
            key: Key(target == ReminderTapTarget.gone ? 'reminder-tap-gone' : 'reminder-tap-other-collection'),
            content: Text(target == ReminderTapTarget.gone ? t.reminderTapPlantGone : t.reminderTapOtherCollection),
          ));
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
