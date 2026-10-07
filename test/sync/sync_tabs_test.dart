import 'package:flutter_test/flutter_test.dart';
import 'package:plantly_inventory/cloud/sync_runner.dart';
import 'package:plantly_inventory/sync/hlc.dart';
import 'package:plantly_inventory/sync/sync_tabs.dart';

void main() {
  test('cross-tab messages round-trip (status + HLC); junk is rejected', () {
    final at = DateTime.utc(2026, 10, 7, 12);
    final m = SyncTabMessage(SyncTabMessageKind.status, 'col-1',
        hlc: '01791388816705-00001-dev',
        status: SyncStatus(
            lastSyncAt: at,
            pendingOps: 3,
            bytesStored: 10,
            bytesQuota: 20,
            inFlight: true,
            lastError: 'collection_unavailable',
            lastErrorDetail: 'read_only',
            rejectedOps: 1,
            rejectedReason: 'x'));
    final back = SyncTabMessage.fromJson(m.toJson())!;
    expect(back.kind, SyncTabMessageKind.status);
    expect(back.collectionId, 'col-1');
    expect(back.hlc, '01791388816705-00001-dev');
    expect(back.status.toString(), m.status.toString());
    expect(SyncTabMessage.fromJson(const SyncTabMessage(SyncTabMessageKind.reload, '').toJson())!.kind,
        SyncTabMessageKind.reload);
    expect(SyncTabMessage.fromJson({'k': 'nope', 'c': 'x'}), isNull);
    expect(SyncTabMessage.fromJson('garbage'), isNull);
  });

  test('mergeTabHlc: merges a valid stamp, ignores a malformed one', () {
    final clock = HlcClock(deviceId: 'dev', nowProvider: () => DateTime.utc(2026, 10, 7, 12), lane: 1);
    final ahead = Hlc(DateTime.utc(2026, 10, 7, 12, 0, 5).millisecondsSinceEpoch, 3, 'other');
    mergeTabHlc(clock, SyncTabMessage(SyncTabMessageKind.changed, 'c', hlc: ahead.encode()));
    expect(clock.now() > ahead, isTrue);
    mergeTabHlc(clock, const SyncTabMessage(SyncTabMessageKind.changed, 'c', hlc: 'nope'));
    expect(clock.now().logical % HlcClock.laneCount, 1);
  });
}
