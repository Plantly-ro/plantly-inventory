import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plantly_inventory/l10n/generated/app_localizations_en.dart';
import 'package:plantly_inventory/l10n/generated/app_localizations_ro.dart';
import 'package:plantly_inventory/notifications/local_notification_service.dart';

/// QA B6 — the Android notification channel showed "Plant care reminders" on
/// a Romanian device. The channel name/description are now resolved from the
/// ARBs at creation time; the id stays stable so existing schedules keep
/// pointing at the same channel.
void main() {
  test('channel name + description follow the locale, id stays stable', () {
    final en = androidReminderDetails(AppLocalizationsEn());
    final ro = androidReminderDetails(AppLocalizationsRo());

    expect(en.channelId, kPlantCareChannelId);
    expect(ro.channelId, kPlantCareChannelId);
    expect(en.channelName, 'Plant care reminders');
    expect(en.channelDescription, 'Watering, fertilising, and other plant care reminders.');
    expect(ro.channelName, 'Memento-uri de îngrijire a plantelor');
    expect(ro.channelDescription, 'Udare, fertilizare și alte memento-uri de îngrijire a plantelor.');
  });

  test('channel is (re)labelled on every schedule so a device-language switch applies', () {
    // Never `update`: on a fresh install the plugin would then skip channel
    // creation and Android 8+ would drop every reminder.
    expect(androidReminderDetails(AppLocalizationsRo()).channelAction, AndroidNotificationChannelAction.createIfNotExists);
    final ch = plantCareChannel(AppLocalizationsRo());
    expect(ch.id, kPlantCareChannelId);
    expect(ch.name, AppLocalizationsRo().notifChannelName);
    expect(ch.description, AppLocalizationsRo().notifChannelDescription);
  });
}
