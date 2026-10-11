import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'app/desktop_theme.dart';
import 'app/ro_informal_material.dart';
import 'app/router.dart';
import 'app/scroll_behavior.dart';
import 'app/url_strategy.dart';
import 'cloud/account_name.dart';
import 'cloud/cloud_notices.dart';
import 'cloud/cloud_sync.dart';
import 'cloud/local_data_wipe.dart';
import 'cloud/play_billing_notices.dart';
import 'cloud/play_billing_providers.dart';
import 'cloud/web_access.dart';
import 'data/providers.dart';
import 'features/gate/web_offline_banner.dart';
import 'features/home/home_providers.dart';
import 'handoff/handoff_listener.dart';
import 'l10n/generated/app_localizations.dart';
import 'notifications/notification_tap_listener.dart';
import 'services/telemetry.dart';
import 'services/web_bootstrap.dart';
import 'theme/tokens.dart';

Future<void> main() async {
  // First: records the launch URL (with its `#fragment`) before anything
  // touches the browser history.
  configureUrlStrategy();
  WidgetsFlutterBinding.ensureInitialized();
  final container = ProviderContainer();
  final telemetry = container.read(telemetryServiceProvider);
  await telemetry.init();
  await initWebPlatform();
  await runGuarded(() async {
    runApp(UncontrolledProviderScope(container: container, child: const PlantlyApp()));
  }, telemetry);
}

/// Root navigator — lets the handoff listener open the import sheet over
/// whatever route is current without threading contexts around.
final GlobalKey<NavigatorState> rootNavigatorKey = GlobalKey<NavigatorState>(debugLabel: 'root');

class PlantlyApp extends ConsumerStatefulWidget {
  const PlantlyApp({super.key, this.navigatorKey, this.initialLocation});

  /// Override for tests; production uses [rootNavigatorKey].
  final GlobalKey<NavigatorState>? navigatorKey;

  /// Start URL for tests / previews (`/plants/<id>`, `/calendar`, …).
  /// Ignored when the platform supplies one (browser address bar).
  final String? initialLocation;

  @override
  ConsumerState<PlantlyApp> createState() => _PlantlyAppState();

  /// App theme for [b]. Public (static) so tests can assert the bundled
  /// typefaces are wired in without pumping the whole app.
  static ThemeData buildTheme(Brightness b) {
    return ThemeData(
      useMaterial3: true,
      brightness: b,
      colorScheme: ColorScheme.fromSeed(
        seedColor: PlantlyTokens.botanical500,
        brightness: b,
      ),
      // Bundled in assets/fonts/ (see pubspec `fonts:`) — no runtime font
      // download, so the app renders offline and makes no request to Google.
      fontFamily: PlantlyFonts.inter,
    );
  }
}

class _PlantlyAppState extends ConsumerState<PlantlyApp> {
  late final GlobalKey<NavigatorState> _navKey = widget.navigatorKey ?? rootNavigatorKey;
  late final GoRouter _router = buildAppRouter(
    navigatorKey: _navKey,
    initialLocation: widget.initialLocation,
    // Re-runs the web access redirect on every verdict change (inert off web).
    refreshListenable: ref.read(webAccessListenableProvider),
  );

  @override
  void dispose() {
    _router.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final mode = ref.watch(themeModeProvider);
    // Cloud sync glue lives for the whole session (inert when the flag is off).
    ref.watch(cloudSyncCoordinatorProvider);
    // OS reminders follow the active tenant (collection switch, link, …).
    ref.watch(reminderTenantResyncProvider);
    // Play Billing restore/resume glue (inert off Android or with the flags off).
    ref.watch(playBillingCoordinatorProvider);
    // Signed in with no greeting name on this device: adopt the plantly.ro
    // account's first name (never over a local one).
    ref.watch(accountNameAdoptionProvider);
    // Web access gate: keeps the verdict → router bridge alive and re-checks
    // the entitlement on tab focus (inert off web).
    ref.watch(webAccessListenableProvider);
    ref.watch(webAccessWatcherProvider);
    // Web: reload when another tab signs out; wipe on device_revoked (inert off web).
    ref.watch(webSessionGuardProvider);
    return MaterialApp.router(
      title: 'Plantly Inventory',
      debugShowCheckedModeBanner: false,
      routerConfig: _router,
      themeMode: mode,
      theme: PlantlyApp.buildTheme(Brightness.light),
      darkTheme: PlantlyApp.buildTheme(Brightness.dark),
      scrollBehavior: const AppScrollBehavior(),
      // Informal Romanian framework strings first (first delegate of a
      // type wins), then the generated list.
      localizationsDelegates: const [RoInformalMaterialLocalizations.delegate, ...AppLocalizations.localizationsDelegates],
      supportedLocales: AppLocalizations.supportedLocales,
      // `builder` runs under the root ScaffoldMessenger, which is what
      // CloudNotices needs for its SnackBars.
      builder: (context, child) => DesktopThemeScope(
        child: HandoffListener(
          navigatorKey: _navKey,
          child: NotificationTapListener(
            router: _router,
            child: CloudNotices(
              child: PlayBillingNotices(
                navigatorKey: _navKey,
                child: WebOfflineBanner(child: child ?? const SizedBox.shrink()),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
