import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/providers.dart';
import 'import_plant_sheet.dart';
import 'incoming_links.dart';
import 'plantly_export.dart';

/// Sits under `MaterialApp` (via `builder`) and turns incoming import links
/// into the [ImportPlantSheet] over whatever route is current. Waits for
/// the DB bootstrap before showing anything so a cold start via a link
/// doesn't race the seed.
class HandoffListener extends ConsumerStatefulWidget {
  const HandoffListener({super.key, required this.navigatorKey, required this.child});
  final GlobalKey<NavigatorState> navigatorKey;
  final Widget child;

  @override
  ConsumerState<HandoffListener> createState() => _HandoffListenerState();
}

class _HandoffListenerState extends ConsumerState<HandoffListener> {
  StreamSubscription<Uri>? _sub;
  final _pending = <String>[];
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

  void _enqueue(Uri uri) {
    final d = extractImportParam(uri);
    // `_lastHandled` only dedupes the initial-link + stream double delivery
    // of the same URI; it is cleared once the sheet closes so the same link
    // can be opened again deliberately.
    if (d == null || d == _lastHandled) return;
    _lastHandled = d;
    ref.read(incomingLinksProvider).consume();
    _pending.add(d);
    _drain();
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
    final d = _pending.removeAt(0);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final ctx = widget.navigatorKey.currentContext;
      if (ctx == null || !ctx.mounted) return;
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
    // `ref.listen` only fires on change; cover the already-ready case.
    if (!_ready && ref.read(appContextProvider).hasValue) {
      _ready = true;
      WidgetsBinding.instance.addPostFrameCallback((_) => _drain());
    }
    return widget.child;
  }
}
