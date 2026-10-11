import 'dart:io';

/// Desktop: the machine's hostname is the name people recognise in a
/// device list. Android: the marketing model from the system properties
/// (`getprop ro.product.model`, e.g. "Pixel 8" / "Samsung SM-S918B") — no
/// plugin needed; every phone used to read "Android". iOS (and any lookup
/// failure): a platform label.
String deviceName(String platform) {
  if (platform == 'ios') return 'iPhone/iPad';
  if (platform == 'android') return _androidModel ??= androidModelName(_getprop) ?? 'Android';
  try {
    final host = Platform.localHostname.trim();
    if (host.isNotEmpty && host != 'localhost') return host;
  } catch (_) {
    // sandboxed / unavailable
  }
  return platform.isEmpty ? 'Device' : '${platform[0].toUpperCase()}${platform.substring(1)}';
}

String? _androidModel;

String? _getprop(String key) {
  try {
    final r = Process.runSync('getprop', [key]);
    if (r.exitCode != 0) return null;
    return (r.stdout as String).trim();
  } catch (_) {
    return null;
  }
}

/// `<Manufacturer> <model>` ("Google Pixel 8", "Samsung SM-S918B"), or just
/// the model when it already names the maker ("OnePlus 12"). Null when the
/// model is unavailable. [read] is `getprop` (injectable for tests).
String? androidModelName(String? Function(String key) read) {
  final model = (read('ro.product.model') ?? '').trim();
  if (model.isEmpty) return null;
  final maker = (read('ro.product.manufacturer') ?? '').trim();
  if (maker.isEmpty || model.toLowerCase().startsWith(maker.toLowerCase())) return model;
  final pretty = '${maker[0].toUpperCase()}${maker.substring(1)}';
  return '$pretty $model';
}
