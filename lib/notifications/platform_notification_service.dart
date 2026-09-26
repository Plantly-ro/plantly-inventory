// Picks the reminder backend at compile time so the web build never links
// flutter_local_notifications (which has no web implementation).
export 'platform_notification_service_io.dart'
    if (dart.library.js_interop) 'platform_notification_service_web.dart';
