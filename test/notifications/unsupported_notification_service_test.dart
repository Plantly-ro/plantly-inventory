import 'package:flutter_test/flutter_test.dart';
import 'package:plantly_inventory/domain/services/ical_export.dart';
import 'package:plantly_inventory/notifications/dnd_settings.dart';
import 'package:plantly_inventory/notifications/notification_service.dart';

void main() {
  test('UnsupportedNotificationService accepts every call without throwing', () async {
    final svc = UnsupportedNotificationService();
    expect(svc.isSupported, isFalse);
    expect(await svc.requestPermissions(), isFalse);
    await svc.init();
    svc.dnd = DndSettings.disabled;
    await svc.syncAll([
      ICalEvent(uid: 'a', summary: 'Water', start: DateTime.utc(2026, 4, 1, 9)),
    ]);
    await svc.cancel(1);
    await svc.cancelAll();
  });

  test('the fake and the io backend report supported', () {
    expect(FakeNotificationService().isSupported, isTrue);
  });
}
