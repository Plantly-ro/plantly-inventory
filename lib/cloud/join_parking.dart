import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/providers.dart';
import '../marketplace/plantly_api.dart';
import '../marketplace/plantly_auth.dart';

/// Why an invite code sits in the parking lot.
enum ParkReason {
  /// The web gate was closed when the link arrived (signed out / no plan):
  /// replayed as a prefilled form, never auto-submitted.
  gated,

  /// The join stopped at the Inventory Cloud requirement (MULTI-USER-V2
  /// §8): auto-submitted once the plan is active.
  cloudRequired,
}

/// A parked invite: the code, the account it belongs to (null only for a
/// pre-sign-in gated park) and why it was parked.
class ParkedJoin {
  const ParkedJoin({required this.code, required this.reason, this.userId});
  final String code;
  final ParkReason reason;
  final String? userId;

  /// Whether [sessionUserId] may use this park: unbound, or the same user.
  bool forUser(String? sessionUserId) => userId == null || userId == sessionUserId;

  @override
  bool operator ==(Object other) =>
      other is ParkedJoin && other.code == code && other.reason == reason && other.userId == userId;

  @override
  int get hashCode => Object.hash(code, reason, userId);

  @override
  String toString() => 'ParkedJoin($code, $reason, user=$userId)';
}

/// An invite code the user could not redeem yet because their own
/// Inventory Cloud entitlement is missing (MULTI-USER-V2 §8: every member
/// needs a plan; the server refuses the join with 402 `cloud_required` and
/// does NOT consume the invite), or that arrived while the web gate was
/// closed. Parked in prefs for [ttl], bound to the account that parked it:
/// another account signing in drops it (never joins on someone else's
/// invite). Cleared on success, on an explicit dismiss, on a terminal join
/// failure, or when it expires.
class JoinParking extends StateNotifier<ParkedJoin?> {
  JoinParking(this._ref, {DateTime Function()? now})
      : _now = now ?? (() => DateTime.now().toUtc()),
        super(null) {
    ready = _load();
    // Account change / sign-out: a park bound to the previous user is gone.
    _ref.listen<String?>(plantlyAuthProvider.select((s) => s.valueOrNull?.userId), (prev, next) {
      final p = state;
      if (p?.userId != null && p!.userId != next) unawaited(clear());
    });
  }

  static const String codeKey = 'plantly_parked_join_code';
  static const String atKey = 'plantly_parked_join_code_at';
  static const String userKey = 'plantly_parked_join_code_user';
  static const String reasonKey = 'plantly_parked_join_code_reason';
  static const Duration ttl = Duration(days: 7);

  final Ref _ref;
  final DateTime Function() _now;
  late final Future<void> ready;
  SharedPreferences? _prefs;

  Future<void> _load() async {
    try {
      final p = await _ref.read(sharedPreferencesProvider.future);
      _prefs = p;
      final code = p.getString(codeKey);
      final at = p.getInt(atKey);
      if (code == null || at == null) return;
      if (_now().difference(DateTime.fromMillisecondsSinceEpoch(at, isUtc: true)) > ttl) {
        await _wipe(p);
        return;
      }
      final user = p.getString(userKey);
      final reason = p.getString(reasonKey) == ParkReason.gated.name ? ParkReason.gated : ParkReason.cloudRequired;
      // Only hydrate when nothing was parked meanwhile in this session.
      if (mounted && state == null) {
        state = ParkedJoin(code: code, reason: reason, userId: user == null || user.isEmpty ? null : user);
      }
    } catch (_) {
      // No prefs (pure-Dart tests): in-memory only.
    }
  }

  /// The parked entry, or null.
  ParkedJoin? get parked => state;

  /// The parked code (normalised), or null.
  String? get code => state?.code;

  /// Park [raw] (normalised; malformed codes are ignored) for [userId]
  /// (null = not signed in yet). Replaces any previous one — there is one
  /// pending invite per device.
  Future<void> park(String raw, {required ParkReason reason, String? userId}) async {
    final code = InviteCode.normalize(raw);
    if (code == null) return;
    final entry = ParkedJoin(code: code, reason: reason, userId: userId);
    if (mounted) state = entry;
    await ready;
    final p = _prefs;
    if (p == null) return;
    await p.setString(codeKey, code);
    await p.setInt(atKey, _now().millisecondsSinceEpoch);
    await p.setString(reasonKey, reason.name);
    if (userId == null) {
      await p.remove(userKey);
    } else {
      await p.setString(userKey, userId);
    }
  }

  /// Forget the parked code (joined, dismissed, the invite turned out to be
  /// invalid, or another account signed in).
  Future<void> clear() async {
    if (mounted) state = null;
    await ready;
    final p = _prefs;
    if (p != null) await _wipe(p);
  }

  Future<void> _wipe(SharedPreferences p) async {
    await p.remove(codeKey);
    await p.remove(atKey);
    await p.remove(userKey);
    await p.remove(reasonKey);
  }
}

final joinParkingProvider = StateNotifierProvider<JoinParking, ParkedJoin?>((ref) => JoinParking(ref));

/// The parked invite the SIGNED-IN account may use (unbound, or its own);
/// null for another account's park. What the UI and the resume logic read.
final parkedJoinForSessionProvider = Provider<ParkedJoin?>((ref) {
  final parked = ref.watch(joinParkingProvider);
  if (parked == null) return null;
  final userId = ref.watch(plantlyAuthProvider.select((s) => s.valueOrNull?.userId));
  return parked.forUser(userId) ? parked : null;
});

/// Number of join sheets on screen (a closing sheet's pop animation and a
/// new one may overlap). `HandoffListener` reads it before resuming a
/// parked invite on an entitlement change so the sheet already open (which
/// resumes by itself) is not doubled.
final openJoinSheetsProvider = StateProvider<int>((_) => 0);
