// MULTI-USER-V2 §8 — a join the user could not complete for lack of their
// own plan is parked for 7 days (prefs), bound to the account, cleared on
// success / dismiss / expiry / account change.
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plantly_inventory/cloud/join_parking.dart';
import 'package:plantly_inventory/marketplace/plantly_auth.dart';
import 'package:plantly_inventory/marketplace/session_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../marketplace/plantly_session_test.dart' show fakeJwt;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final now = DateTime.utc(2026, 10, 4, 12);
  final secs = now.millisecondsSinceEpoch ~/ 1000;
  final aliceToken = fakeJwt(iat: secs, exp: secs + 86400);
  final bobToken = fakeJwt(iat: secs, exp: secs + 86400, username: 'bob', userId: 'u-2');

  ProviderContainer make({DateTime? at, String? token}) {
    final c = ProviderContainer(overrides: [
      sessionStoreProvider.overrideWith((_) => InMemorySessionStore(token)),
      joinParkingProvider.overrideWith((ref) => JoinParking(ref, now: () => at ?? now)),
    ]);
    addTearDown(c.dispose);
    return c;
  }

  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('park normalises the code, persists code/at/user/reason; clear wipes all', () async {
    final c = make();
    final parking = c.read(joinParkingProvider.notifier);
    await parking.ready;
    expect(parking.code, isNull);
    await parking.park(' abcd-efgh ', reason: ParkReason.cloudRequired, userId: 'u-1');
    expect(parking.code, 'ABCDEFGH');
    expect(c.read(joinParkingProvider), const ParkedJoin(code: 'ABCDEFGH', reason: ParkReason.cloudRequired, userId: 'u-1'));
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString(JoinParking.codeKey), 'ABCDEFGH');
    expect(prefs.getInt(JoinParking.atKey), now.millisecondsSinceEpoch);
    expect(prefs.getString(JoinParking.userKey), 'u-1');
    expect(prefs.getString(JoinParking.reasonKey), 'cloudRequired');

    await parking.park('not a code', reason: ParkReason.gated);
    expect(parking.code, 'ABCDEFGH', reason: 'malformed input ignored');

    await parking.park('ZZZZZZZZ', reason: ParkReason.gated);
    expect(parking.parked!.userId, isNull, reason: 'pre-sign-in gated park is unbound');
    expect(prefs.getString(JoinParking.userKey), isNull);

    await parking.clear();
    expect(parking.code, isNull);
    for (final k in [JoinParking.codeKey, JoinParking.atKey, JoinParking.userKey, JoinParking.reasonKey]) {
      expect(prefs.get(k), isNull, reason: k);
    }
  });

  test('hydrates from prefs on a new instance while younger than 7 days; expired → wiped', () async {
    final a = make();
    await a.read(joinParkingProvider.notifier).park('ABCDEFGH', reason: ParkReason.gated, userId: 'u-1');

    final fresh = make(at: now.add(const Duration(days: 6, hours: 23)));
    final p1 = fresh.read(joinParkingProvider.notifier);
    await p1.ready;
    expect(p1.parked, const ParkedJoin(code: 'ABCDEFGH', reason: ParkReason.gated, userId: 'u-1'));

    final stale = make(at: now.add(const Duration(days: 7, minutes: 1)));
    final p2 = stale.read(joinParkingProvider.notifier);
    await p2.ready;
    expect(p2.code, isNull);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString(JoinParking.codeKey), isNull, reason: 'expired entry removed');
  });

  test('a code parked before prefs load wins over the stored one', () async {
    SharedPreferences.setMockInitialValues({
      JoinParking.codeKey: 'ZZZZZZZZ',
      JoinParking.atKey: now.millisecondsSinceEpoch,
    });
    final c = make();
    final parking = c.read(joinParkingProvider.notifier);
    await parking.park('ABCDEFGH', reason: ParkReason.cloudRequired, userId: 'u-1');
    await parking.ready;
    expect(parking.code, 'ABCDEFGH');
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString(JoinParking.codeKey), 'ABCDEFGH');
  });

  test('account-bound (P1): another account\'s park is invisible to the session and dropped on account change / sign-out',
      () async {
    SharedPreferences.setMockInitialValues({
      JoinParking.codeKey: 'ABCDEFGH',
      JoinParking.atKey: now.millisecondsSinceEpoch,
      JoinParking.userKey: 'u-1',
      JoinParking.reasonKey: 'cloudRequired',
    });
    // Bob's session: alice's park is not his.
    final c = make(token: bobToken);
    await c.read(plantlyAuthProvider.notifier).current();
    final parking = c.read(joinParkingProvider.notifier);
    await parking.ready;
    expect(parking.parked?.forUser('u-2'), isFalse);
    expect(c.read(parkedJoinForSessionProvider), isNull);
    // An unbound (pre-sign-in gated) park is anyone's.
    expect(const ParkedJoin(code: 'X', reason: ParkReason.gated).forUser('u-2'), isTrue);

    // Alice parks, signs out → gone; bob signs in → nothing to resume.
    SharedPreferences.setMockInitialValues({});
    final d = make(token: aliceToken);
    final auth = d.read(plantlyAuthProvider.notifier);
    await auth.current();
    final p = d.read(joinParkingProvider.notifier);
    await p.ready;
    d.listen(parkedJoinForSessionProvider, (_, _) {});
    await p.park('ABCDEFGH', reason: ParkReason.cloudRequired, userId: 'u-1');
    expect(d.read(parkedJoinForSessionProvider)?.code, 'ABCDEFGH');
    await auth.signOut();
    await Future<void>.delayed(Duration.zero);
    expect(p.parked, isNull, reason: 'cleared on sign-out');
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString(JoinParking.codeKey), isNull);

    // Direct account switch (alice → bob) clears too.
    await auth.adoptToken(aliceToken);
    await Future<void>.delayed(Duration.zero);
    await p.park('ABCDEFGH', reason: ParkReason.cloudRequired, userId: 'u-1');
    await auth.adoptToken(bobToken);
    await Future<void>.delayed(Duration.zero);
    expect(p.parked, isNull);
    expect(d.read(parkedJoinForSessionProvider), isNull);
  });
}
