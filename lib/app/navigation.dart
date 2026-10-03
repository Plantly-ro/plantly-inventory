import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../features/calendar/calendar_screen.dart';
import '../features/locations/location_detail_screen.dart';
import '../features/locations/locations_screen.dart';
import '../features/me/care_types_screen.dart';
import '../features/me/cloud_screen.dart';
import '../features/me/devices_screen.dart';
import '../features/me/me_screen.dart';
import '../features/me/notifications_screen.dart';
import '../features/me/privacy_screen.dart';
import '../features/me/stats_screen.dart';
import '../features/plant_detail/plant_detail_screen.dart';
import '../theme/tokens.dart';
import 'breakpoints.dart';

/// URL vocabulary (CLOUD-SYNC-CONTRACT §5). Keep the strings here; the
/// router and every `context.go/push` call site read them from this class.
abstract final class AppRoutes {
  static const String home = '/';
  static const String calendar = '/calendar';
  static const String spaces = '/spaces';
  static const String me = '/me';

  /// Canonical import link — `/import?d=<PlantlyExport>`; the legacy hash
  /// form `/#/import?d=` keeps working (see `handoff/incoming_links.dart`).
  static const String import = '/import';

  /// OAuth return (CLOUD-SYNC-CONTRACT §2.4). The server sends the browser
  /// to `<INVENTORY_WEB>/#/auth/callback?token=&nonce=` — under the path
  /// URL strategy that is location `/` plus a hash, which `HandoffListener`
  /// reads and scrubs. The path form `/auth/callback?token=` is accepted
  /// too and redirected home once the listener has consumed it.
  static const String authCallback = '/auth/callback';

  /// Shared-collection invite landing (CLOUD-SYNC-CONTRACT §3) —
  /// `/join?c=<code>`; `HandoffListener` reads the code off the URL and
  /// opens the join sheet, the router redirects home (like [import]).
  static const String join = '/join';

  /// Web access gate (WEB-ACCESS-POLICY §1) — outside the shell; the router
  /// sends every closed-gate visit here and resumes the parked URL after.
  static const String gate = '/gate';

  static String plant(String id) => '/plants/${Uri.encodeComponent(id)}';
  static String space(String id) => '/spaces/${Uri.encodeComponent(id)}';
  static String meSection(String section) => '/me/$section';

  /// Me → Cloud → Devices (MULTI-USER-V2 §2.12): the installs syncing this
  /// account, with revoke. Two segments, so it never collides with
  /// `/me/:section`; desktop renders it in the Me detail pane like a section.
  static const String meCloudDevices = '/me/cloud/devices';

  /// `/me/:section` values with a screen. `cloud` renders regardless of the
  /// `PLANTLY_CLOUD_ENABLED` flag (the screen shows nothing useful when off;
  /// the Me list simply doesn't link to it).
  static const List<String> meSections = ['notifications', 'care-types', 'stats', 'privacy', 'cloud'];
}

/// Screen for a `/me/:section` value, or null when unknown (→ redirect).
Widget? meSectionScreen(String section) {
  switch (section) {
    case 'notifications':
      return const NotificationsScreen();
    case 'care-types':
      return const CareTypesScreen();
    case 'stats':
      return const StatsScreen();
    case 'privacy':
      return const PrivacyScreen();
    case 'cloud':
      return const CloudScreen();
    case 'cloud/devices':
      return const DevicesScreen();
    default:
      return null;
  }
}

/// Top-level navigation helpers.
///
/// Desktop selects in place (`go` → URL changes, master pane keeps its
/// state, browser history gets an entry). Phone/tablet push a full-screen
/// route exactly as the old `Navigator.push(MaterialPageRoute)` did — the
/// browser back button now pops it. Without a `GoRouter` in scope (screens
/// pumped bare in widget tests) they fall back to the old imperative push.
void openPlant(BuildContext context, String id) =>
    _open(context, AppRoutes.plant(id), () => PlantDetailScreen(plantId: id));

void openSpace(BuildContext context, String id) =>
    _open(context, AppRoutes.space(id), () => LocationDetailScreen(locationId: id));

void openSpaces(BuildContext context) => _open(context, AppRoutes.spaces, () => const LocationsScreen());

void openCalendar(BuildContext context) => _open(context, AppRoutes.calendar, () => const CalendarScreen());

void openMe(BuildContext context) => _open(context, AppRoutes.me, () => const MeScreen());

void openMeCloudDevices(BuildContext context) =>
    _open(context, AppRoutes.meCloudDevices, () => const DevicesScreen());

void openMeSection(BuildContext context, String section) {
  final screen = meSectionScreen(section);
  if (screen == null) return;
  _open(context, AppRoutes.meSection(section), () => screen);
}

/// `pushReplacement` equivalent for "this plant became that plant"
/// (propagate / duplicate): swaps the current detail for [id].
void replaceWithPlant(BuildContext context, String id) {
  final router = GoRouter.maybeOf(context);
  if (router == null) {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(builder: (_) => PlantDetailScreen(plantId: id)),
    );
    return;
  }
  if (context.isDesktop) {
    router.go(AppRoutes.plant(id));
  } else {
    router.pushReplacement(AppRoutes.plant(id));
  }
}

/// Back chevron / post-delete exit: pop when there is something to pop,
/// otherwise (deep link, desktop pane) go to [fallback].
void goBack(BuildContext context, {String fallback = AppRoutes.home}) {
  final nav = Navigator.of(context);
  if (nav.canPop()) {
    nav.pop();
    return;
  }
  GoRouter.maybeOf(context)?.go(fallback);
}

/// Capture the navigation target *before* an `await` that may unmount the
/// caller (sheets that pop themselves and then open a plant).
PlantOpener preparePlantOpener(BuildContext context) => PlantOpener._(
      GoRouter.maybeOf(context),
      context.isDesktop,
      Navigator.of(context),
    );

class PlantOpener {
  PlantOpener._(this._router, this._desktop, this._navigator);
  final GoRouter? _router;
  final bool _desktop;
  final NavigatorState _navigator;

  void open(String id) {
    final router = _router;
    if (router == null) {
      _navigator.push(MaterialPageRoute<void>(builder: (_) => PlantDetailScreen(plantId: id)));
      return;
    }
    if (_desktop) {
      router.go(AppRoutes.plant(id));
    } else {
      router.push(AppRoutes.plant(id));
    }
  }
}

void _open(BuildContext context, String location, Widget Function() fallback) {
  final router = GoRouter.maybeOf(context);
  if (router == null) {
    Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => fallback()));
    return;
  }
  if (context.isDesktop) {
    // Pageless routes pushed imperatively on top (search, activity…) would
    // otherwise stay stacked over the in-place page update — clear them.
    Navigator.of(context).popUntil((route) => route.settings is Page);
    router.go(location);
  } else {
    router.push(location);
  }
}

/// The `‹` AppBar button every pushed screen uses. Null on desktop, where
/// the screen sits in the shell / a master–detail pane and has nothing to
/// go back to; callers pair it with `automaticallyImplyLeading: false`.
Widget? adaptiveBackButton(BuildContext context, PlantlySurface surface, {String fallback = AppRoutes.home}) {
  if (context.isDesktop) return null;
  return IconButton(
    icon: Icon(Icons.chevron_left, color: surface.text),
    onPressed: () => goBack(context, fallback: fallback),
  );
}

/// Leading button for detail screens (plant, space). Phone/tablet: the
/// same `‹` as always. Desktop: the screen lives in the right pane, so a
/// `×` that clears the selection (`go(parent)`) replaces it.
Widget detailLeading(BuildContext context, PlantlySurface surface, {required String parent}) {
  if (!context.isDesktop) {
    return IconButton(
      icon: Icon(Icons.chevron_left, color: surface.text),
      onPressed: () => goBack(context, fallback: parent),
    );
  }
  return IconButton(
    icon: Icon(Icons.close, color: surface.muted),
    tooltip: MaterialLocalizations.of(context).closeButtonTooltip,
    onPressed: () => goBack(context, fallback: parent),
  );
}
