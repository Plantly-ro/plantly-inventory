import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../cloud/oauth_handshake.dart';
import '../cloud/sign_in_events.dart';
import '../cloud/web_access.dart';
import '../data/providers.dart';
import '../features/collections/join_collection_sheet.dart';
import '../marketplace/plantly_auth.dart';
import 'import_plant_sheet.dart';
import 'incoming_links.dart';
import 'plantly_export.dart';

/// Sits under `MaterialApp` (via `builder`) and turns incoming import links
/// into the [ImportPlantSheet] over whatever route is current. Waits for
/// the DB bootstrap before showing anything so a cold start via a link
/// doesn't race the seed. OAuth callback links (`auth/callback#token=`)
/// are adopted straight into [PlantlyAuth] and announced on
/// [signInEventsProvider] — no UI of their own. Shared-collection invite
/// links (`join#c=<code>`, §3) open the join sheet with the code filled in.
///
/// Web access gate (WEB-ACCESS-POLICY §0): while the gate is closed an
/// import / join link is *parked* ([WebGateParking], prefs — it must survive
/// the OAuth page reload) instead of opening a sheet over the gate, and
/// replayed the moment the gate opens.
class HandoffListener extends ConsumerStatefulWidget {
  const HandoffListener({super.key, required this.navigatorKey, required this.child});
  final GlobalKey<NavigatorState> navigatorKey;
  final Widget child;

  @override
  ConsumerState<HandoffListener> createState() => _HandoffListenerState();
}

class _HandoffListenerState extends ConsumerState<HandoffListener> {
  StreamSubscription<Uri>? _sub;
  final _pending = <_PendingLink>[];
  String? _lastHandled;
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    final links = ref.read(incomingLinksProvider);
    unawaited(links.initial().then((uri) {
      if (uri != null) _enqueue(uri);
    }));
    _sub = links.stream.listen(_enqueue);
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  String? _lastToken;

  void _enqueue(Uri uri, {bool replay = false}) {
    final callback = extractAuthCallback(uri);
    if (callback != null) {
      if (callback.token == _lastToken) return;
      _lastToken = callback.token;
      ref.read(incomingLinksProvider).consume();
      unawaited(_adoptToken(callback));
      return;
    }
    final code = extractJoinCode(uri);
    if (code != null) {
      final key = 'join:$code';
      if (key == _lastHandled) return;
      _lastHandled = key;
      if (!replay) ref.read(incomingLinksProvider).consume();
      if (_parkWhileGated(uri)) {
        _lastHandled = null;
        return;
      }
      _pending.add(_PendingLink.join(code));
      _drain();
      return;
    }
    final d = extractImportParam(uri);
    // `_lastHandled` only dedupes the initial-link + stream double delivery
    // of the same URI; it is cleared once the sheet closes so the same link
    // can be opened again deliberately.
    if (d == null || d == _lastHandled) return;
    _lastHandled = d;
    if (!replay) ref.read(incomingLinksProvider).consume();
    if (_parkWhileGated(uri)) {
      _lastHandled = null;
      return;
    }
    _pending.add(_PendingLink.import(d));
    _drain();
  }

  /// True when the web gate is closed: the link went to the parking lot and
  /// [_replayParked] will bring it back once the gate opens.
  bool _parkWhileGated(Uri uri) {
    if (ref.read(webAccessProvider).isOpen) return false;
    ref.read(webGateParkingProvider).parkLink(uri);
    return true;
  }

  void _replayParked() {
    final uri = ref.read(webGateParkingProvider).takeLink();
    if (uri != null) _enqueue(uri, replay: true);
  }

  /// Adopt only callbacks that answer a sign-in this device started (nonce +
  /// 10-minute window, see [OAuthHandshake]) — anything else is a fixation
  /// attempt or a stale link and is dropped without a trace of the token.
  Future<void> _adoptToken(AuthCallback callback) async {
    final handshake = ref.read(oauthHandshakeProvider);
    final auth = ref.read(plantlyAuthProvider.notifier);
    final events = ref.read(signInEventsProvider);
    if (!await handshake.consume(callback.nonce, allowMissingNonce: callback.customScheme)) {
      debugPrint('oauth callback ignored: no matching sign-in in progress');
      return;
    }
    try {
      final session = await auth.adoptToken(callback.token);
      events.emit(session);
    } on FormatException {
      // Not a usable JWT — the link was malformed; nothing to show.
    }
  }

  void _release(String d) {
    if (_lastHandled == d) _lastHandled = null;
  }

  void _drain() {
    if (!_ready || _pending.isEmpty) return;
    final context = widget.navigatorKey.currentContext;
    if (context == null) {
      // Navigator not mounted yet — retry next frame.
      WidgetsBinding.instance.addPostFrameCallback((_) => _drain());
      return;
    }
    final link = _pending.removeAt(0);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final ctx = widget.navigatorKey.currentContext;
      if (ctx == null || !ctx.mounted) return;
      if (link.joinCode != null) {
        final key = 'join:${link.joinCode}';
        unawaited(showJoinCollectionSheet(ctx, initialCode: link.joinCode).whenComplete(() => _release(key)));
        return;
      }
      final d = link.importParam!;
      try {
        final payload = PlantlyExportPayload.decodeParam(d);
        unawaited(showImportPlantSheet(ctx, payload).whenComplete(() => _release(d)));
      } on PlantlyExportFormatException catch (e) {
        unawaited(showImportErrorSheet(ctx, e.error).whenComplete(() => _release(d)));
      }
    });
    // A link arriving while the app is idle (web `hashchange`, resumed
    // activity) doesn't schedule a frame by itself — force one so the
    // post-frame callback above actually runs.
    WidgetsBinding.instance.scheduleFrame();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(appContextProvider, (_, next) {
      if (next.hasValue && !_ready) {
        _ready = true;
        _drain();
      }
    });
    ref.listen<WebAccess>(webAccessProvider, (prev, next) {
      if (next.isOpen && !(prev?.isOpen ?? false)) _replayParked();
    });
    // `ref.listen` only fires on change; cover the already-ready case.
    if (!_ready && ref.read(appContextProvider).hasValue) {
      _ready = true;
      WidgetsBinding.instance.addPostFrameCallback((_) => _drain());
    }
    return widget.child;
  }
}

/// One queued link: a PlantlyExport import param or a join code.
class _PendingLink {
  const _PendingLink.import(this.importParam) : joinCode = null;
  const _PendingLink.join(this.joinCode) : importParam = null;
  final String? importParam;
  final String? joinCode;
}
