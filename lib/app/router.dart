import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../cloud/web_access.dart';
import '../features/calendar/calendar_screen.dart';
import '../features/collections/collection_activity_screen.dart';
import '../features/gate/web_access_gate.dart';
import '../handoff/incoming_links.dart';
import '../features/home/home_screen.dart';
import '../features/locations/location_detail_screen.dart';
import '../features/locations/locations_screen.dart';
import '../features/me/devices_screen.dart';
import '../features/me/me_screen.dart';
import '../features/plant_detail/plant_detail_screen.dart';
import 'breakpoints.dart';
import 'master_detail.dart';
import 'navigation.dart';
import 'shell.dart';

/// Navigator inside [AppShell]; imperative `Navigator.push` from features
/// (search, activity, reorder photos…) lands here, under the side nav.
final GlobalKey<NavigatorState> shellNavigatorKey = GlobalKey<NavigatorState>(debugLabel: 'shell');

/// Route table (CLOUD-SYNC-CONTRACT §5):
///
/// | URL               | phone / tablet                    | desktop (≥ 1100)                        |
/// |-------------------|-----------------------------------|-----------------------------------------|
/// | `/`               | HomeScreen                        | HomeDesktopPage → HomeDashboard         |
/// | `/plants/:id`     | PlantDetailScreen (pushed)        | HomeDesktopPage(selected) — same page   |
/// | `/calendar`       | CalendarScreen                    | CalendarScreen (full content width)     |
/// | `/spaces`         | LocationsScreen                   | SpacesDesktopPage → LocationsScreen     |
/// | `/spaces/:id`     | LocationDetailScreen (pushed)     | SpacesDesktopPage(selected)             |
/// | `/me`             | MeScreen                          | MeMasterDetail                          |
/// | `/me/:section`    | section screen (pushed)           | MeMasterDetail(section)                 |
/// | `/import?d=`      | redirect `/` (HandoffListener opens the import sheet from the URL)  |
/// | `/auth/callback`  | redirect `/` (HandoffListener adopted the token from the URL first) |
/// | `/join?c=`        | redirect `/` (HandoffListener opens the join-collection sheet)      |
/// | `/gate`           | [WebAccessGate] — web only, outside the shell (WEB-ACCESS-POLICY)   |
///
/// All app routes are siblings under one [ShellRoute]: on desktop a
/// section's list and detail URLs produce pages with the *same key*, so
/// `go()` updates the page in place instead of rebuilding the master pane.
///
/// Web access gate (WEB-ACCESS-POLICY §1): while [webAccessProvider] is not
/// open, every route except `/gate`, `/auth/callback`, `/join` and `/import`
/// redirects to `/gate`, parking the requested location; the link routes
/// redirect to `/gate` too but the payload is parked by `HandoffListener`.
/// Once open, `/gate` resumes the parked location (or Home). Off web the
/// provider is always open, so the gate never engages. [refreshListenable]
/// (see [webAccessListenableProvider]) re-runs the redirect on each verdict.
GoRouter buildAppRouter({
  required GlobalKey<NavigatorState> navigatorKey,
  String? initialLocation,
  Listenable? refreshListenable,
}) {
  return GoRouter(
    navigatorKey: navigatorKey,
    initialLocation: initialLocation ?? AppRoutes.home,
    refreshListenable: refreshListenable,
    redirect: webAccessRedirect,
    routes: [
      GoRoute(
        path: AppRoutes.gate,
        pageBuilder: (context, state) => const NoTransitionPage<void>(child: WebAccessGate()),
      ),
      ShellRoute(
        navigatorKey: shellNavigatorKey,
        builder: (context, state, child) =>
            AppShell(location: state.uri.path, shellNavigatorKey: shellNavigatorKey, child: child),
        routes: [
          GoRoute(
            path: AppRoutes.home,
            pageBuilder: (context, state) => _adaptive(
              context,
              state,
              desktopKey: 'home',
              phone: () => const HomeScreen(),
              desktop: () => const HomeDesktopPage(),
            ),
          ),
          GoRoute(
            path: '/plants/:id',
            pageBuilder: (context, state) {
              final id = state.pathParameters['id']!;
              return _adaptive(
                context,
                state,
                desktopKey: 'home',
                phone: () => PlantDetailScreen(plantId: id),
                desktop: () => HomeDesktopPage(selectedPlantId: id),
              );
            },
          ),
          GoRoute(
            path: AppRoutes.calendar,
            pageBuilder: (context, state) => _adaptive(
              context,
              state,
              desktopKey: 'calendar',
              phone: () => const CalendarScreen(),
              desktop: () => const CalendarScreen(),
            ),
          ),
          GoRoute(
            path: AppRoutes.spaces,
            pageBuilder: (context, state) => _adaptive(
              context,
              state,
              desktopKey: 'spaces',
              phone: () => const LocationsScreen(),
              desktop: () => const SpacesDesktopPage(),
            ),
          ),
          GoRoute(
            path: '/spaces/:id',
            pageBuilder: (context, state) {
              final id = state.pathParameters['id']!;
              return _adaptive(
                context,
                state,
                desktopKey: 'spaces',
                phone: () => LocationDetailScreen(locationId: id),
                desktop: () => SpacesDesktopPage(selectedLocationId: id),
              );
            },
          ),
          GoRoute(
            path: AppRoutes.me,
            pageBuilder: (context, state) => _adaptive(
              context,
              state,
              desktopKey: 'me',
              phone: () => const MeScreen(),
              desktop: () => const MeMasterDetail(),
            ),
          ),
          // Before `/me/:section` for readability only — two segments never
          // match the one-segment pattern.
          GoRoute(
            path: AppRoutes.meCloudDevices,
            pageBuilder: (context, state) => _adaptive(
              context,
              state,
              desktopKey: 'me',
              phone: () => const DevicesScreen(),
              desktop: () => const MeMasterDetail(section: 'cloud/devices'),
            ),
          ),
          GoRoute(
            path: '/me/:section',
            redirect: (context, state) =>
                meSectionScreen(state.pathParameters['section']!) == null ? AppRoutes.me : null,
            pageBuilder: (context, state) {
              final section = state.pathParameters['section']!;
              return _adaptive(
                context,
                state,
                desktopKey: 'me',
                phone: () => meSectionScreen(section)!,
                desktop: () => MeMasterDetail(section: section),
              );
            },
          ),
          // The payload is read off the browser URL by `HandoffListener`
          // (`IncomingLinks.initial()`), which also opens the sheet once the
          // DB is up; the router only has to land somewhere sensible and
          // clear the address bar.
          GoRoute(
            path: '/collections/:id/activity',
            pageBuilder: (context, state) {
              final id = state.pathParameters['id']!;
              return _adaptive(
                context,
                state,
                desktopKey: 'collection-activity-$id',
                phone: () => CollectionActivityScreen(collectionId: id),
                desktop: () => CollectionActivityScreen(collectionId: id),
              );
            },
          ),
          GoRoute(path: AppRoutes.import, redirect: (context, state) => AppRoutes.home),
          // Same for the OAuth return: the hash form (`/#/auth/callback?…`)
          // never reaches the router under the path strategy; the path form
          // does, and must not 404 — the listener has already read the token
          // off `window.location` and scrubbed it.
          GoRoute(path: AppRoutes.authCallback, redirect: (context, state) => AppRoutes.home),
          // Invite landing (§3): the listener has the code, the sheet does
          // the rest; the URL must not keep the code around.
          GoRoute(path: AppRoutes.join, redirect: (context, state) => AppRoutes.home),
        ],
      ),
    ],
  );
}

/// Top-level redirect implementing the gate (see [buildAppRouter]).
String? webAccessRedirect(BuildContext context, GoRouterState state) {
  final container = ProviderScope.containerOf(context, listen: false);
  final access = container.read(webAccessProvider);
  final path = state.uri.path;
  final atGate = path == AppRoutes.gate;
  if (access.isOpen) {
    if (!atGate) return null;
    final parked = container.read(webGateParkingProvider).takeRoute();
    return parked ?? AppRoutes.home;
  }
  if (atGate) return null;
  // Payload links: the listener parks the import param / join code off the
  // browser URL itself; the router only has to land on the gate.
  if (isAuthCallbackPath(path) || isJoinPath(path) || isImportPath(path)) return AppRoutes.gate;
  // Compare the full location: `/` with a query (`?prefill=…`) is a
  // destination worth coming back to; bare Home is where the gate lands anyway.
  final location = state.uri.toString();
  if (location != AppRoutes.home) {
    container.read(webGateParkingProvider).parkRoute(location);
  }
  return AppRoutes.gate;
}

/// Phone/tablet: a normal [MaterialPage] (slide transition, pushes stack).
/// Desktop: a [NoTransitionPage] keyed per section so list ↔ detail URLs
/// update one page in place. `MediaQuery.sizeOf` registers a dependency on
/// the navigator's context, so a window resize across the breakpoint
/// re-runs the page builders.
Page<void> _adaptive(
  BuildContext context,
  GoRouterState state, {
  required String desktopKey,
  required Widget Function() phone,
  required Widget Function() desktop,
}) {
  if (context.isDesktop) {
    return NoTransitionPage<void>(key: ValueKey('desktop-$desktopKey'), child: desktop());
  }
  return MaterialPage<void>(key: state.pageKey, child: phone());
}
