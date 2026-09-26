import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../marketplace/plantly_session.dart';

/// "A session was just established" — fired by the OAuth deep-link handler
/// (and anyone else completing a sign-in) so interested parties (the
/// entitlement cache, the login sheet) react without knowing the source.
class SignInEvents {
  final _controller = StreamController<PlantlySession>.broadcast();

  Stream<PlantlySession> get stream => _controller.stream;

  void emit(PlantlySession session) {
    if (!_controller.isClosed) _controller.add(session);
  }

  Future<void> dispose() => _controller.close();
}

final signInEventsProvider = Provider<SignInEvents>((ref) {
  final events = SignInEvents();
  ref.onDispose(events.dispose);
  return events;
});
