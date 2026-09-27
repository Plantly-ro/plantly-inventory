import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../features/calendar/calendar_screen.dart';
import '../features/home/home_screen.dart';
import '../features/locations/location_detail_screen.dart';
import '../features/locations/locations_screen.dart';
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
///
/// All routes are siblings under one [ShellRoute]: on desktop a section's
/// list and detail URLs produce pages with the *same key*, so `go()`
/// updates the page in place instead of rebuilding the master pane.
GoRouter buildAppRouter({
  required GlobalKey<NavigatorState> navigatorKey,
  String? initialLocation,
}) {
  return GoRouter(
    navigatorKey: navigatorKey,
    initialLocation: initialLocation ?? AppRoutes.home,
    routes: [
      ShellRoute(
        navigatorKey: shellNavigatorKey,
        builder: (context, state, child) => AppShell(
          location: state.uri.path,
          shellNavigatorKey: shellNavigatorKey,
          child: child,
        ),
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
          GoRoute(path: AppRoutes.import, redirect: (context, state) => AppRoutes.home),
        ],
      ),
    ],
  );
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
