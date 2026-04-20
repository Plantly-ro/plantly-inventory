import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

import '../data/user_prefs.dart';

/// Opt-in crash reporting + anonymous usage events.
///
/// Nothing leaves the device unless two conditions are met:
///   1. The user flipped the corresponding toggle in Me → Privacy.
///   2. The build was compiled with a real `SENTRY_DSN` via
///      `--dart-define=SENTRY_DSN=…`. Without a DSN Sentry init is a
///      no-op by design — the public APK ships with DSN empty, so
///      even if a user opts in, nothing gets sent. Forks or the
///      maintainer's own builds can supply a DSN to enable routing.
///
/// Both toggles default **off**. We re-read the consent state before
/// every event, so flipping a switch takes effect immediately.
class TelemetryService {
  TelemetryService(this._ref);
  final Ref _ref;
  bool _initialized = false;

  static const _dsn = String.fromEnvironment('SENTRY_DSN', defaultValue: '');

  UserPrefs get _prefs => _ref.read(userPrefsProvider);

  /// Wrap app bootstrap so unhandled errors route through Sentry when
  /// the user has opted in. Call from `main()` around `runApp`.
  Future<void> init() async {
    if (_initialized) return;
    if (_dsn.isEmpty) {
      _initialized = true;
      return;
    }
    await SentryFlutter.init((options) {
      options.dsn = _dsn;
      options.debug = kDebugMode;
      options.sendDefaultPii = false;
      options.beforeSend = _beforeSend;
      options.beforeSendTransaction = _beforeSendTransaction;
      options.tracesSampleRate = 0.0;
    });
    _initialized = true;
  }

  /// Record an unhandled error. No-op unless crash consent is on.
  Future<void> recordError(Object error, StackTrace? stack, {String? hint}) async {
    if (!_prefs.crashConsent) return;
    if (_dsn.isEmpty) return;
    await Sentry.captureException(error, stackTrace: stack, hint: hint == null ? null : Hint.withMap({'note': hint}));
  }

  /// Record a light usage event. No-op unless analytics consent is on.
  /// We intentionally keep the payload minimal: event name + a handful
  /// of categorical tags. No free-text user input, no identifiers.
  Future<void> track(String eventName, {Map<String, String>? tags}) async {
    if (!_prefs.analyticsConsent) return;
    if (_dsn.isEmpty) return;
    await Sentry.captureEvent(
      SentryEvent(
        message: SentryMessage(eventName),
        level: SentryLevel.info,
        tags: tags,
      ),
    );
  }

  SentryEvent? _beforeSend(SentryEvent event, Hint hint) {
    if (!_prefs.crashConsent && event.level != SentryLevel.info) return null;
    if (!_prefs.analyticsConsent && event.level == SentryLevel.info) return null;
    return event;
  }

  SentryTransaction? _beforeSendTransaction(SentryTransaction t, Hint hint) {
    if (!_prefs.analyticsConsent) return null;
    return t;
  }
}

final telemetryServiceProvider = Provider<TelemetryService>((ref) {
  return TelemetryService(ref);
});

/// Flutter runZonedGuarded hook for uncaught errors. Wire into main().
Future<void> runGuarded(FutureOr<void> Function() body, TelemetryService telemetry) async {
  FlutterError.onError = (details) {
    FlutterError.presentError(details);
    telemetry.recordError(details.exception, details.stack);
  };
  await runZonedGuarded(() async {
    await body();
  }, (error, stack) {
    telemetry.recordError(error, stack);
  });
}
