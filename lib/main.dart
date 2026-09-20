import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

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
    final navKey = navigatorKey ?? rootNavigatorKey;
    return MaterialApp(
      title: 'PlantlyInventory',
      debugShowCheckedModeBanner: false,
      navigatorKey: navKey,
      themeMode: mode,
      theme: _buildTheme(Brightness.light),
      darkTheme: _buildTheme(Brightness.dark),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      builder: (context, child) => HandoffListener(
        navigatorKey: navKey,
        child: child ?? const SizedBox.shrink(),
      ),
      home: const HomeScreen(),
    );
  }

  ThemeData _buildTheme(Brightness b) {
    return ThemeData(
      useMaterial3: true,
      brightness: b,
      colorScheme: ColorScheme.fromSeed(
        seedColor: PlantlyTokens.botanical500,
        brightness: b,
      ),
      textTheme: GoogleFonts.interTextTheme(
        b == Brightness.light
            ? ThemeData.light().textTheme
            : ThemeData.dark().textTheme,
      ),
    );
  }
}
