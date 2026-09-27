import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'cloud/cloud_sync.dart';
import 'features/home/home_providers.dart';
import 'features/home/home_screen.dart';
import 'handoff/handoff_listener.dart';
import 'l10n/generated/app_localizations.dart';
import 'services/telemetry.dart';
import 'services/web_bootstrap.dart';
import 'theme/tokens.dart';

Future<void> main() async {
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

class PlantlyApp extends ConsumerWidget {
  const PlantlyApp({super.key, this.navigatorKey});

  /// Override for tests; production uses [rootNavigatorKey].
  final GlobalKey<NavigatorState>? navigatorKey;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mode = ref.watch(themeModeProvider);
    // Cloud sync glue lives for the whole session (inert when the flag is off).
    ref.watch(cloudSyncCoordinatorProvider);
    final navKey = navigatorKey ?? rootNavigatorKey;
    return MaterialApp(
      title: 'PlantlyInventory',
      debugShowCheckedModeBanner: false,
      navigatorKey: navKey,
      themeMode: mode,
      theme: buildTheme(Brightness.light),
      darkTheme: buildTheme(Brightness.dark),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      builder: (context, child) => HandoffListener(
        navigatorKey: navKey,
        child: child ?? const SizedBox.shrink(),
      ),
      home: const HomeScreen(),
    );
  }

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
