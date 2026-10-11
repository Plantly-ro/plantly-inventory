import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'session_tab_events_stub.dart' if (dart.library.js_interop) 'session_tab_events_web.dart' as platform;

/// Fires when ANOTHER browser tab of this origin removed the plantly.ro
/// session (`storage` event on `plantly_ro/jwt`, or a full localStorage
/// clear). Never fires off web. Tests override.
final sessionRemovedInOtherTabProvider = Provider<Stream<void>>((_) => platform.sessionRemovedInOtherTab());
