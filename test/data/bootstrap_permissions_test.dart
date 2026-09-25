import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plantly_inventory/data/database/app_database.dart';
import 'package:plantly_inventory/data/providers.dart';
import 'package:plantly_inventory/notifications/notification_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// QA B4 — on a fresh cold start the OS notification dialog appeared BEFORE
/// the first onboarding page (and again ahead of the onboarding "Reminders"
/// step, which has its own Allow button) because `appContextProvider`
/// called the prompting `requestPermissions()` on init. Bootstrap must only
/// *read* the state via `checkPermissions()`; prompting is reserved for the
/// onboarding button, the Home banner and Me → Notifications.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FakeNotificationService fake;
  late ProviderContainer container;

  setUp(() {
    SharedPreferences.setMockInitialValues({}); // fresh install: nothing onboarded
    fake = FakeNotificationService();
    container = ProviderContainer(overrides: [
      databaseProvider.overrideWith((ref) {
        final db = AppDatabase.forTesting(NativeDatabase.memory());
        ref.onDispose(db.close);
        return db;
      }),
      notificationServiceProvider.overrideWith((ref) => fake),
    ]);
  });

  tearDown(() => container.dispose());

  Future<void> bootstrap() async {
    await container.read(appContextProvider.future);
    // The permission probe is fire-and-forget; let its microtasks settle.
    await pumpEventQueue();
  }

  test('bootstrap never prompts — it only checks the current permission state', () async {
    fake.permissionGranted = false;
    await bootstrap();

    expect(fake.requestPermissionsCalls, 0, reason: 'startup must not open the system dialog');
    expect(fake.checkPermissionsCalls, 1);
    expect(container.read(notificationPermissionProvider), isFalse,
        reason: 'denied/undetermined → Home banner + Me → Notifications offer the request');
  });

  test('an already-granted permission is reflected without prompting', () async {
    fake.permissionGranted = true;
    await bootstrap();

    expect(fake.requestPermissionsCalls, 0);
    expect(container.read(notificationPermissionProvider), isTrue);
  });

  test('an unknown state (null) is treated as not granted, still without prompting', () async {
    fake.permissionGranted = null;
    await bootstrap();

    expect(fake.requestPermissionsCalls, 0);
    expect(container.read(notificationPermissionProvider), isFalse);
  });

  test('the seeded demo data is in place after a non-prompting bootstrap (app still works)', () async {
    fake.permissionGranted = false;
    await bootstrap();
    final ctx = container.read(appContextProvider).requireValue;
    expect(await ctx.db.managers.plants.count(), 8);
    expect(fake.requestPermissionsCalls, 0);
  });
}
