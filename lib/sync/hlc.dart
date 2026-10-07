import 'dart:developer' as developer;
import 'dart:math';

/// Hybrid Logical Clock — the single ordering primitive for every synced
/// row. PLAN.md locks this: `updated_hlc` on every table, sortable across
/// devices with monotonic guarantees under clock skew.
///
/// Wire format: `<physicalMs>-<logical>-<deviceId>`, each component a fixed
/// width so lexicographic compare == temporal compare.
///   - physicalMs : 14-digit zero-padded unix ms (good until year ~5138)
///   - logical    : 5-digit zero-padded counter (handles 100k ops/ms)
///   - deviceId   : arbitrary string — only used as tie-break, never parsed
///
/// Example: `00001776511234567-00003-a1b2c3d4`.
class Hlc implements Comparable<Hlc> {
  const Hlc(this.physicalMs, this.logical, this.deviceId);

  final int physicalMs;
  final int logical;
  final String deviceId;

  static const int _maxLogical = 99999;

  /// Parse the wire format back into an Hlc.
  factory Hlc.parse(String raw) {
    final parts = raw.split('-');
    if (parts.length < 3) {
      throw FormatException('not an HLC timestamp: $raw');
    }
    final phys = int.parse(parts[0]);
    final logi = int.parse(parts[1]);
    final dev = parts.sublist(2).join('-');
    return Hlc(phys, logi, dev);
  }

  /// [Hlc.parse] that returns null instead of throwing.
  static Hlc? tryParse(String raw) {
    try {
      return Hlc.parse(raw);
    } on FormatException {
      return null;
    }
  }

  String encode() {
    return '${physicalMs.toString().padLeft(14, '0')}'
        '-${logical.toString().padLeft(5, '0')}'
        '-$deviceId';
  }

  @override
  int compareTo(Hlc other) {
    final a = physicalMs.compareTo(other.physicalMs);
    if (a != 0) return a;
    final b = logical.compareTo(other.logical);
    if (b != 0) return b;
    return deviceId.compareTo(other.deviceId);
  }

  bool operator >(Hlc other) => compareTo(other) > 0;
  bool operator <(Hlc other) => compareTo(other) < 0;
  bool operator >=(Hlc other) => compareTo(other) >= 0;
  bool operator <=(Hlc other) => compareTo(other) <= 0;

  @override
  bool operator ==(Object other) =>
      other is Hlc &&
      other.physicalMs == physicalMs &&
      other.logical == logical &&
      other.deviceId == deviceId;

  @override
  int get hashCode => Object.hash(physicalMs, logical, deviceId);

  @override
  String toString() => encode();
}

/// Mutable clock tracking the highest HLC this device has produced.
/// Every row mutation calls [now] to stamp `updated_hlc`; [merge] is
/// invoked on every inbound sync op so the physical component can't drift
/// backwards more than one tick relative to what we've seen.
class HlcClock {
  HlcClock({
    required this.deviceId,
    DateTime Function()? nowProvider,
    this.maxRemoteDrift = const Duration(hours: 24),
    void Function(String message)? log,
    int? lane,
  })  : _nowProvider = nowProvider ?? (() => DateTime.now().toUtc()),
        _log = log ?? _developerLog,
        lane = lane ?? defaultLane {
    final l = this.lane;
    if (l != null && (l < 0 || l >= laneCount)) throw ArgumentError.value(l, 'lane', 'must be in 0..${laneCount - 1}');
  }

  final String deviceId;

  /// Number of logical-counter lanes (see [lane]).
  static const int laneCount = 100;

  /// Lane every clock gets unless one is passed: set once at startup by the
  /// web bootstrap (each browser tab claims a distinct one through the Web
  /// Locks API); null everywhere else.
  static int? defaultLane;

  /// Several writers sharing one [deviceId] — browser tabs of the same
  /// install, all writing the same database — would otherwise mint
  /// IDENTICAL stamps for edits in the same millisecond, and the server
  /// keeps only the first op per `(entity, entity_id, field, hlc,
  /// device_id)`. With a lane the logical component only takes values
  /// `≡ lane (mod laneCount)`, so each writer's stamps are disjoint while
  /// the wire format, the ordering and the device id stay as they are.
  /// Null = a single writer: the counter steps by 1 (the original clock).
  final int? lane;
  final DateTime Function() _nowProvider;

  /// How far ahead of the local wall clock a remote HLC may be and still
  /// move this clock forward. A remote stamp further out than this is not a
  /// peer slightly ahead of us — it is a malformed or forged timestamp
  /// (one op stamped `20260927102954-…`, i.e. year ~2612, pinned a device's
  /// clock there and every later local edit inherited it). Such stamps are
  /// ignored by [merge]; the op itself still applies under LWW.
  ///
  /// Must stay >= the server's `hlcFutureTolerance` (24 h; it refuses ops
  /// further ahead as `hlc_future`): every op the server accepted has to be
  /// mergeable here, otherwise a peer whose clock runs ahead by more than
  /// this window outranks an edit we make after seeing its op — the edit
  /// loses everywhere. Lower both together, server first.
  final Duration maxRemoteDrift;
  final void Function(String message) _log;

  int _lastPhysical = 0;
  int _logical = 0;

  /// The last stamp [now] produced (or the merged high-water mark); null
  /// before the first one. Shared with the other tabs so their clocks stay
  /// causally ahead of this one's edits.
  Hlc? get latest => _lastPhysical == 0 ? null : Hlc(_lastPhysical, _logical, deviceId);

  /// Smallest logical value `>= v` that belongs to this clock's [lane].
  int _inLane(int v) {
    final l = lane;
    if (l == null) return v;
    final r = v % laneCount;
    return r <= l ? v - r + l : v - r + laneCount + l;
  }

  /// Keeps the logical component within its 5 digits: past the cap, move
  /// to the next millisecond (stays monotonic) instead of growing a digit.
  void _capLogical() {
    if (_logical > Hlc._maxLogical) {
      _lastPhysical++;
      _logical = _inLane(0);
    }
  }

  /// Remote HLCs [merge] refused because they were further than
  /// [maxRemoteDrift] ahead of the local wall clock (diagnostics/tests).
  int ignoredRemoteCount = 0;

  static void _developerLog(String message) => developer.log(message, name: 'plantly.hlc');

  /// The clock's wall time source, unix ms.
  int get wallMillis => _nowProvider().millisecondsSinceEpoch;

  /// Emit a fresh HLC that is strictly greater than every previous call on
  /// this clock, and greater than every remote HLC that has been [merge]d.
  Hlc now() {
    final wall = _nowProvider().millisecondsSinceEpoch;
    if (wall > _lastPhysical) {
      _lastPhysical = wall;
      _logical = _inLane(0);
    } else {
      _logical = _inLane(_logical + 1);
      // Should be unreachable; bump physical past the overflow so we stay
      // monotonic rather than aborting.
      _capLogical();
    }
    return Hlc(_lastPhysical, _logical, deviceId);
  }

  /// Absorb a remote HLC. After this call, subsequent [now] results are
  /// guaranteed to be strictly greater than [remote] — unless [remote] is
  /// more than [maxRemoteDrift] ahead of the local wall clock, in which case
  /// it is logged and ignored (returns false) so a single bad stamp cannot
  /// drag every future local edit into the far future.
  bool merge(Hlc remote) {
    final wall = _nowProvider().millisecondsSinceEpoch;
    if (remote.physicalMs - wall > maxRemoteDrift.inMilliseconds) {
      ignoredRemoteCount++;
      _log('ignoring remote HLC ${remote.encode()}: '
          '${Duration(milliseconds: remote.physicalMs - wall)} ahead of local time');
      return false;
    }
    final physCap = max(max(_lastPhysical, remote.physicalMs), wall);
    if (physCap == _lastPhysical && physCap == remote.physicalMs) {
      _logical = _inLane(max(_logical, remote.logical) + 1);
    } else if (physCap == _lastPhysical) {
      _logical = _inLane(_logical + 1);
    } else if (physCap == remote.physicalMs) {
      _logical = _inLane(remote.logical + 1);
    } else {
      _logical = _inLane(0);
    }
    _lastPhysical = physCap;
    _capLogical();
    return true;
  }
}
