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
  HlcClock({required this.deviceId, DateTime Function()? nowProvider})
      : _nowProvider = nowProvider ?? (() => DateTime.now().toUtc());

  final String deviceId;
  final DateTime Function() _nowProvider;

  int _lastPhysical = 0;
  int _logical = 0;

  /// Emit a fresh HLC that is strictly greater than every previous call on
  /// this clock, and greater than every remote HLC that has been [merge]d.
  Hlc now() {
    final wall = _nowProvider().millisecondsSinceEpoch;
    if (wall > _lastPhysical) {
      _lastPhysical = wall;
      _logical = 0;
    } else {
      _logical++;
      if (_logical > Hlc._maxLogical) {
        // Should be unreachable; bump physical past the overflow so we stay
        // monotonic rather than aborting.
        _lastPhysical++;
        _logical = 0;
      }
    }
    return Hlc(_lastPhysical, _logical, deviceId);
  }

  /// Absorb a remote HLC. After this call, subsequent [now] results are
  /// guaranteed to be strictly greater than [remote].
  void merge(Hlc remote) {
    final wall = _nowProvider().millisecondsSinceEpoch;
    final physCap = max(max(_lastPhysical, remote.physicalMs), wall);
    if (physCap == _lastPhysical && physCap == remote.physicalMs) {
      _logical = max(_logical, remote.logical) + 1;
    } else if (physCap == _lastPhysical) {
      _logical++;
    } else if (physCap == remote.physicalMs) {
      _logical = remote.logical + 1;
    } else {
      _logical = 0;
    }
    _lastPhysical = physCap;
  }
}
