import 'package:shared_preferences/shared_preferences.dart';
import 'package:ulid/ulid.dart';

/// Stable per-install identifier. Lives in shared_preferences so Drift tables
/// can stamp `device_id` without creating a chicken-and-egg with the DB
/// initialization path.
class DeviceId {
  DeviceId._();

  static const _kKey = 'plantly_device_id';

  static Future<String> load(SharedPreferences prefs) async {
    final existing = prefs.getString(_kKey);
    if (existing != null) return existing;
    final fresh = Ulid().toString();
    await prefs.setString(_kKey, fresh);
    return fresh;
  }
}
