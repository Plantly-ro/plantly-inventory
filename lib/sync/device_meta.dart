import 'package:flutter/foundation.dart';

import '../config/plantly_hosts.dart';
import 'sync_transport.dart';
import 'device_meta_stub.dart' if (dart.library.io) 'device_meta_io.dart' as impl;

/// Builds the [SyncDeviceMeta] this install sends on push/pull
/// (MULTI-USER-V2 §2.12). Platform from the Flutter target, version from
/// the build-time `PLANTLY_APP_VERSION`, device name from the io seam
/// (hostname on desktop, platform label elsewhere) — no plugin needed.
SyncDeviceMeta currentDeviceMeta({String deviceId = ''}) {
  final platform = kIsWeb ? 'web' : defaultTargetPlatform.name.toLowerCase();
  return SyncDeviceMeta(
    deviceId: deviceId,
    deviceName: impl.deviceName(platform),
    appVersion: PlantlyHosts.appVersion,
    platform: platform,
  );
}
