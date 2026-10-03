import 'dart:io';

/// Desktop: the machine's hostname is the name people recognise in a
/// device list. Mobile: `localHostname` is `localhost`, so fall back to a
/// capitalised platform label ("Android", "Ios" → "iPhone/iPad").
String deviceName(String platform) {
  if (platform == 'android' || platform == 'ios') {
    return platform == 'ios' ? 'iPhone/iPad' : 'Android';
  }
  try {
    final host = Platform.localHostname.trim();
    if (host.isNotEmpty && host != 'localhost') return host;
  } catch (_) {
    // sandboxed / unavailable
  }
  return platform.isEmpty ? 'Device' : '${platform[0].toUpperCase()}${platform.substring(1)}';
}
