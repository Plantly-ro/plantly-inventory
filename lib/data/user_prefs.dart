import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'providers.dart';

/// Per-user, device-local preferences: the user's display name (shown in
/// the greeting), the one-time onboarding flag, and the two privacy
/// consent toggles (both default false — the user has to explicitly opt in
/// before anything leaves the device).
class UserPrefs {
  const UserPrefs({
    this.userName,
    this.onboardingSeen = false,
    this.crashConsent = false,
    this.analyticsConsent = false,
    this.loaded = false,
  });

  final String? userName;
  final bool onboardingSeen;
  final bool crashConsent;
  final bool analyticsConsent;

  /// True once we've read the backing SharedPreferences at least once.
  /// Callers gating first-run UI should wait for this so they don't
  /// flash onboarding against the default-false state while disk I/O
  /// is in flight.
  final bool loaded;

  UserPrefs copyWith({
    Object? userName = _unset,
    bool? onboardingSeen,
    bool? crashConsent,
    bool? analyticsConsent,
    bool? loaded,
  }) {
    return UserPrefs(
      userName: identical(userName, _unset) ? this.userName : userName as String?,
      onboardingSeen: onboardingSeen ?? this.onboardingSeen,
      crashConsent: crashConsent ?? this.crashConsent,
      analyticsConsent: analyticsConsent ?? this.analyticsConsent,
      loaded: loaded ?? this.loaded,
    );
  }

  static const _unset = Object();
}

class UserPrefsController extends StateNotifier<UserPrefs> {
  UserPrefsController(this._prefs) : super(const UserPrefs()) {
    _load();
  }

  static const _kName = 'plantly_user_name';
  static const _kOnboarded = 'plantly_onboarded';
  static const _kCrash = 'plantly_crash_consent';
  static const _kAnalytics = 'plantly_analytics_consent';

  final Future<SharedPreferences> _prefs;

  Future<void> _load() async {
    final p = await _prefs;
    state = UserPrefs(
      userName: p.getString(_kName),
      onboardingSeen: p.getBool(_kOnboarded) ?? false,
      crashConsent: p.getBool(_kCrash) ?? false,
      analyticsConsent: p.getBool(_kAnalytics) ?? false,
      loaded: true,
    );
  }

  Future<void> setName(String? name) async {
    final trimmed = (name ?? '').trim();
    final next = trimmed.isEmpty ? null : trimmed;
    state = state.copyWith(userName: next);
    final p = await _prefs;
    if (next == null) {
      await p.remove(_kName);
    } else {
      await p.setString(_kName, next);
    }
  }

  Future<void> markOnboarded() async {
    state = state.copyWith(onboardingSeen: true);
    final p = await _prefs;
    await p.setBool(_kOnboarded, true);
  }

  Future<void> setCrashConsent(bool v) async {
    state = state.copyWith(crashConsent: v);
    final p = await _prefs;
    await p.setBool(_kCrash, v);
  }

  Future<void> setAnalyticsConsent(bool v) async {
    state = state.copyWith(analyticsConsent: v);
    final p = await _prefs;
    await p.setBool(_kAnalytics, v);
  }
}

final userPrefsProvider = StateNotifierProvider<UserPrefsController, UserPrefs>((ref) {
  return UserPrefsController(ref.watch(sharedPreferencesProvider.future));
});
