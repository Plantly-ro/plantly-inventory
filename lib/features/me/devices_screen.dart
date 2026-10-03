import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../app/navigation.dart';
import '../../data/providers.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../marketplace/plantly_api.dart';
import '../../marketplace/plantly_auth.dart';
import '../../theme/tokens.dart';
import '../home/home_providers.dart';

/// `GET /inventory/devices` (MULTI-USER-V2 §2.12) for the signed-in
/// account; an empty list when signed out. Auto-disposes with the screen,
/// `ref.invalidate` after a revoke to refetch.
final cloudDevicesProvider = FutureProvider.autoDispose<List<CloudDevice>>((ref) async {
  // Every `watch` comes before the first await (a watch after an await is
  // not tracked reliably by Riverpod). The app context is `read`, not
  // watched: this install's device id never changes, and watching it
  // would refetch the list once the context finishes opening.
  final auth = ref.watch(plantlyAuthProvider);
  final api = ref.watch(plantlyApiProvider);
  final session = auth.valueOrNull ?? await ref.read(plantlyAuthProvider.notifier).current();
  if (session == null) return const [];
  final ownDeviceId = (await ref.read(appContextProvider.future)).deviceId;
  return api.listDevices(session.token, deviceId: ownDeviceId);
});

/// Me → Cloud → Devices (`/me/cloud/devices`): every install that pushed or
/// pulled under this account, with "Disconnect" (§2.12 revoke) on the
/// others. The current install is marked and cannot revoke itself here —
/// that is the ordinary sign-out / unlink flow.
class DevicesScreen extends ConsumerWidget {
  const DevicesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mode = ref.watch(themeModeProvider);
    final surface = mode == ThemeMode.dark ? PlantlySurface.dark : PlantlySurface.light;
    final t = AppLocalizations.of(context);
    final session = ref.watch(plantlyAuthProvider).valueOrNull;
    final ownDeviceId = ref.watch(appContextProvider).valueOrNull?.deviceId;
    final devices = ref.watch(cloudDevicesProvider);

    return Scaffold(
      backgroundColor: surface.bg,
      appBar: AppBar(
        backgroundColor: surface.bg,
        elevation: 0,
        automaticallyImplyLeading: false,
        leading: adaptiveBackButton(context, surface, fallback: AppRoutes.meSection('cloud')),
        title: Text(
          t.devicesTitle,
          style: TextStyle(
            fontFamily: PlantlyFonts.plusJakartaSans,
            fontSize: 22,
            fontWeight: FontWeight.w800,
            color: surface.text,
            letterSpacing: -0.02 * 22,
          ),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: () => ref.refresh(cloudDevicesProvider.future),
        child: ListView(
          key: const Key('devices-list'),
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
          children: [
            Text(
              t.devicesIntro,
              key: const Key('devices-intro'),
              style: TextStyle(fontSize: 13, height: 1.4, color: surface.muted),
            ),
            const SizedBox(height: 16),
            if (session == null)
              Text(t.devicesSignedOut, key: const Key('devices-signed-out'), style: TextStyle(fontSize: 13, color: surface.muted))
            else
              devices.when(
                loading: () => const Padding(
                  padding: EdgeInsets.symmetric(vertical: 24),
                  child: Center(child: CircularProgressIndicator(key: Key('devices-loading'))),
                ),
                error: (_, _) => _ErrorBlock(surface: surface, onRetry: () => ref.invalidate(cloudDevicesProvider)),
                data: (list) {
                  final others = list.where((d) => !_isCurrent(d, ownDeviceId)).toList();
                  if (others.isEmpty) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        for (final d in list) ...[
                          _DeviceTile(device: d, current: true, surface: surface),
                          const SizedBox(height: 6),
                        ],
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text(
                            t.devicesEmpty,
                            key: const Key('devices-empty'),
                            style: TextStyle(fontSize: 13, color: surface.muted),
                          ),
                        ),
                      ],
                    );
                  }
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      for (final d in list) ...[
                        _DeviceTile(
                          device: d,
                          current: _isCurrent(d, ownDeviceId),
                          surface: surface,
                          onRevoke: _isCurrent(d, ownDeviceId) ? null : () => _revoke(context, ref, d),
                        ),
                        const SizedBox(height: 6),
                      ],
                    ],
                  );
                },
              ),
          ],
        ),
      ),
    );
  }

  /// The server flag, or — for an older server without `current` — the
  /// install id this app writes under.
  static bool _isCurrent(CloudDevice d, String? ownDeviceId) =>
      d.current || (ownDeviceId != null && d.deviceId == ownDeviceId);

  Future<void> _revoke(BuildContext context, WidgetRef ref, CloudDevice device) async {
    final t = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.maybeOf(context);
    final name = deviceDisplayName(device, t);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        key: const Key('devices-revoke-dialog'),
        title: Text(t.devicesRevokeConfirmTitle),
        content: Text(t.devicesRevokeConfirmBody(name)),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: Text(t.cancel)),
          TextButton(
            key: const Key('devices-revoke-confirm'),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(t.devicesRevoke),
          ),
        ],
      ),
    );
    if (ok != true) return;
    final session = await ref.read(plantlyAuthProvider.notifier).current();
    if (session == null) return;
    try {
      await ref.read(plantlyApiProvider).revokeDevice(session.token, device.deviceId);
    } catch (_) {
      messenger
        ?..clearSnackBars()
        ..showSnackBar(SnackBar(key: const Key('devices-revoke-failed'), content: Text(t.devicesRevokeFailed)));
      return;
    }
    ref.invalidate(cloudDevicesProvider);
    messenger
      ?..clearSnackBars()
      ..showSnackBar(SnackBar(key: const Key('devices-revoked'), content: Text(t.devicesRevoked)));
  }
}

/// `device_name`, else a platform label.
String deviceDisplayName(CloudDevice d, AppLocalizations t) {
  final name = d.deviceName?.trim() ?? '';
  return name.isNotEmpty ? name : devicePlatformLabel(d.platform, t);
}

String devicePlatformLabel(String? platform, AppLocalizations t) {
  switch (platform) {
    case 'android':
      return t.devicesPlatformAndroid;
    case 'ios':
      return t.devicesPlatformIos;
    case 'web':
      return t.devicesPlatformWeb;
    case 'linux':
    case 'macos':
    case 'windows':
      return t.devicesPlatformDesktop;
    default:
      return t.devicesPlatformUnknown;
  }
}

IconData devicePlatformIcon(String? platform) {
  switch (platform) {
    case 'android':
      return Icons.android;
    case 'ios':
      return Icons.phone_iphone;
    case 'web':
      return Icons.language;
    case 'linux':
    case 'macos':
    case 'windows':
      return Icons.computer;
    default:
      return Icons.devices_other;
  }
}

/// Short "last seen": time of day when today, otherwise a short date.
String formatLastSeen(DateTime at, String locale, {DateTime? now}) {
  final local = at.toLocal();
  final ref = (now ?? DateTime.now()).toLocal();
  final sameDay = local.year == ref.year && local.month == ref.month && local.day == ref.day;
  return sameDay ? DateFormat.Hm(locale).format(local) : DateFormat.yMMMd(locale).format(local);
}

class _DeviceTile extends StatelessWidget {
  const _DeviceTile({required this.device, required this.current, required this.surface, this.onRevoke});
  final CloudDevice device;
  final bool current;
  final PlantlySurface surface;
  final VoidCallback? onRevoke;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final parts = <String>[
      devicePlatformLabel(device.platform, t),
      if ((device.appVersion ?? '').isNotEmpty) 'v${device.appVersion}',
      if (device.lastSeenAt != null) t.devicesLastSeen(formatLastSeen(device.lastSeenAt!, t.localeName)),
    ];
    return Container(
      key: Key('device-${device.deviceId}'),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: surface.surface,
        border: Border.all(color: surface.border),
        borderRadius: BorderRadius.circular(PlantlyTokens.radius),
      ),
      child: Row(
        children: [
          Icon(devicePlatformIcon(device.platform), size: 20, color: surface.green),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        deviceDisplayName(device, t),
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: surface.text),
                      ),
                    ),
                    if (current) ...[
                      const SizedBox(width: 8),
                      Container(
                        key: Key('device-current-${device.deviceId}'),
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: surface.green.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          t.devicesThisDevice,
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: surface.green),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 2),
                Text(parts.join(' · '), style: TextStyle(fontSize: 12, color: surface.muted)),
              ],
            ),
          ),
          if (onRevoke != null) ...[
            const SizedBox(width: 8),
            TextButton(
              key: Key('device-revoke-${device.deviceId}'),
              onPressed: onRevoke,
              style: TextButton.styleFrom(
                foregroundColor: surface.terra,
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: Text(t.devicesRevoke, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
            ),
          ],
        ],
      ),
    );
  }
}

class _ErrorBlock extends StatelessWidget {
  const _ErrorBlock({required this.surface, required this.onRetry});
  final PlantlySurface surface;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(t.devicesError, key: const Key('devices-error'), style: TextStyle(fontSize: 13, color: surface.muted)),
        const SizedBox(height: 8),
        OutlinedButton(
          key: const Key('devices-retry'),
          onPressed: onRetry,
          child: Text(t.devicesRetry),
        ),
      ],
    );
  }
}
