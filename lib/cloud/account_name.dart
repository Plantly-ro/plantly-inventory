import 'dart:async';

import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/providers.dart';
import '../data/user_prefs.dart';
import '../marketplace/plantly_auth.dart';

/// Longest greeting name we adopt from the account (in characters).
const int accountGreetingNameMaxLength = 40;

/// The greeting name a plantly.ro account suggests, from a `GET /users/me`
/// body: `first_name` (additive — older servers omit it), else the first
/// word of `full_name`, else null. Never the `username`: that is a handle,
/// not a name. Whitespace runs collapse to one space; capped at
/// [accountGreetingNameMaxLength] characters.
String? accountGreetingName(Map<String, dynamic> me) {
  String? clean(Object? v) {
    if (v is! String) return null;
    final t = v.trim().replaceAll(RegExp(r'\s+'), ' ');
    return t.isEmpty ? null : t;
  }

  final name = clean(me['first_name']) ?? clean(me['full_name'])?.split(' ').first;
  if (name == null) return null;
  final runes = name.runes;
  if (runes.length <= accountGreetingNameMaxLength) return name;
  return String.fromCharCodes(runes.take(accountGreetingNameMaxLength)).trimRight();
}

/// The signed-in account's greeting name ([accountGreetingName] of
/// `/users/me`), re-resolved whenever the signed-in account changes.
/// Signed out → null without touching the network; any failure (offline,
/// HTTP error, odd body) → null. Never throws: this only ever *suggests* a
/// name, nothing waits on it.
final accountGreetingNameProvider = FutureProvider<String?>((ref) async {
  // The user id only: `auth.current()` re-emits an equal session object
  // (see cloudEntitlementProvider), so watching the whole value would loop.
  final userId = ref.watch(plantlyAuthProvider.select((s) => s.valueOrNull?.userId));
  if (userId == null || userId.isEmpty) return null;
  try {
    // `current()` refreshes the token first when it is due, like every
    // other authenticated call.
    final live = await ref.read(plantlyAuthProvider.notifier).current();
    if (live == null || live.userId != userId) return null;
    final me = await ref.read(plantlyApiProvider).me(live.token);
    return accountGreetingName(me);
  } on Object catch (e) {
    debugPrint('accountGreetingName: $e');
    return null;
  }
});

/// App-lifetime effect (watched by the app root): when a signed-in account
/// suggests a name and the device has none, adopt it as the greeting name.
///
/// * Never overwrites a local name — the Me screen / onboarding value is
///   authoritative per device (the user may prefer a nickname).
/// * Decides at most once per account per device ([adoptedForKey]): once an
///   account's name has been seen, a later clear (Me screen, onboarding)
///   sticks instead of being refilled behind the user's back. Signing into
///   a different account decides afresh.
final accountNameAdoptionProvider = Provider<void>((ref) {
  var disposed = false;
  var scheduled = false;
  ref.onDispose(() => disposed = true);

  Future<void> run() async {
    scheduled = false;
    if (disposed) return;
    final userId = ref.read(plantlyAuthProvider).valueOrNull?.userId;
    if (userId == null || userId.isEmpty) return;
    final nameAsync = ref.read(accountGreetingNameProvider);
    // While (re)loading the value may still be the previous account's.
    if (nameAsync.isLoading || !nameAsync.hasValue) return;
    final name = nameAsync.value;
    if (name == null) return;
    final local = ref.read(userPrefsProvider);
    if (!local.loaded) return;
    final prefs = await ref.read(sharedPreferencesProvider.future);
    if (disposed) return;
    if (prefs.getString(adoptedForKey) == userId) return;
    // Re-check after the await: still the same account, still no name.
    if (ref.read(plantlyAuthProvider).valueOrNull?.userId != userId) return;
    await prefs.setString(adoptedForKey, userId);
    if (disposed) return;
    if (ref.read(userPrefsProvider).userName == null) {
      await ref.read(userPrefsProvider.notifier).setName(name);
    }
  }

  // Never mutate another provider from inside a build / notification:
  // hop to a microtask, coalescing bursts.
  void schedule() {
    if (scheduled || disposed) return;
    scheduled = true;
    scheduleMicrotask(() => unawaited(run()));
  }

  ref.listen(accountGreetingNameProvider, (_, _) => schedule());
  ref.listen(userPrefsProvider.select((p) => (p.loaded, p.userName)), (_, _) => schedule());
  ref.listen(plantlyAuthProvider.select((s) => s.valueOrNull?.userId), (_, _) => schedule());
  schedule();
});

/// SharedPreferences key: the account whose suggested name this device has
/// already considered (see [accountNameAdoptionProvider]).
const String adoptedForKey = 'plantly_user_name_account_adopted_for';
