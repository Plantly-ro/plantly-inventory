import 'package:flutter_test/flutter_test.dart';
import 'package:plantly_inventory/domain/services/ical_export.dart';
import 'package:plantly_inventory/notifications/notification_service.dart';

ICalEvent _evt(String uid, int day) => ICalEvent(
      uid: uid,
      summary: 'Water $uid',
      start: DateTime.utc(2026, 4, day, 9),
    );

void main() {
  late FakeNotificationService svc;

  setUp(() {
    svc = FakeNotificationService();
  });

  test('schedule stores id + event', () async {
    await svc.schedule(id: 1, event: _evt('a', 1));
    expect(svc.calls, hasLength(1));
    expect(svc.calls.first.id, 1);
    expect(svc.calls.first.event.summary, 'Water a');
  });

  test('cancel records the id', () async {
    await svc.cancel(7);
    expect(svc.cancelled, {7});
  });

  test('cancelAll clears scheduled + flags the call', () async {
    await svc.schedule(id: 1, event: _evt('a', 1));
    await svc.cancelAll();
    expect(svc.calls, isEmpty);
    expect(svc.cancelAllCalled, isTrue);
  });

  test('syncAll replaces the whole schedule in one call', () async {
    await svc.schedule(id: 99, event: _evt('old', 1));
    await svc.syncAll([_evt('a', 1), _evt('b', 2), _evt('c', 3)]);
    expect(svc.cancelAllCalled, isTrue);
    expect(svc.calls.map((c) => c.event.uid).toList(), ['a', 'b', 'c']);
    expect(svc.calls.map((c) => c.id).toList(), [0, 1, 2]);
  });
}
