import 'local_notification_service.dart';
import 'notification_service.dart';

NotificationService createPlatformNotificationService() => LocalNotificationService();
