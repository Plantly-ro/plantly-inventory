import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../cloud/data_residency.dart';
import '../../config/plantly_features.dart';
import '../../data/user_prefs.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../theme/tokens.dart';
import '../home/home_providers.dart';
import '../../app/navigation.dart';

/// Privacy & Data — the plain-English statement of where the collection
/// lives and what leaves the device (true per [DataResidency]: local-only
/// app, app with cloud sync running, web), plus two toggles the user must
/// opt in to explicitly. Both default off; no telemetry is collected
/// unless the user flips these on.
class PrivacyScreen extends ConsumerWidget {
  const PrivacyScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mode = ref.watch(themeModeProvider);
    final surface = mode == ThemeMode.dark ? PlantlySurface.dark : PlantlySurface.light;
    final prefs = ref.watch(userPrefsProvider);
    final t = AppLocalizations.of(context);
    final residency = ref.watch(dataResidencyProvider);
    final web = residency == DataResidency.web;

    return Scaffold(
      backgroundColor: surface.bg,
      appBar: AppBar(
        backgroundColor: surface.bg,
        elevation: 0,
        automaticallyImplyLeading: false,
        leading: adaptiveBackButton(context, surface, fallback: AppRoutes.me),
        title: Text(
          t.mePrivacyTitle,
          style: TextStyle(fontFamily: PlantlyFonts.plusJakartaSans, 
            fontSize: 22,
            fontWeight: FontWeight.w800,
            color: surface.text,
            letterSpacing: -0.44,
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
        children: [
          _Card(
            surface: surface,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  web ? t.mePrivacyWhereDataLives : t.mePrivacyWhatLeaves,
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: surface.text),
                ),
                const SizedBox(height: 8),
                _Bullet(
                  key: const ValueKey('privacy-bullet-storage'),
                  surface: surface,
                  text: switch (residency) {
                    DataResidency.deviceOnly => t.mePrivacyBulletLocal,
                    DataResidency.deviceAndCloud => t.mePrivacyBulletCloud,
                    DataResidency.syncPaused => t.mePrivacyBulletPaused,
                    DataResidency.web => t.mePrivacyBulletWeb,
                  },
                ),
                _Bullet(
                  surface: surface,
                  text: web ? t.mePrivacyBulletBackupsWeb : t.mePrivacyBulletBackups,
                ),
                _Bullet(
                  surface: surface,
                  text: web ? t.mePrivacyBulletNotificationsWeb : t.mePrivacyBulletNotifications,
                ),
                if (ref.watch(sellEnabledProvider))
                  _Bullet(
                    key: const ValueKey('privacy-bullet-marketplace'),
                    surface: surface,
                    text: residency == DataResidency.deviceOnly
                        ? t.mePrivacyBulletMarketplace
                        : t.mePrivacyBulletMarketplaceCloud,
                  ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _SectionLabel(text: t.mePrivacySectionTelemetry, surface: surface),
          const SizedBox(height: 8),
          _ToggleRow(
            surface: surface,
            title: t.mePrivacyCrashTitle,
            subtitle: t.mePrivacyCrashBody,
            icon: Icons.bug_report_outlined,
            value: prefs.crashConsent,
            onChanged: (v) => ref.read(userPrefsProvider.notifier).setCrashConsent(v),
          ),
          const SizedBox(height: 8),
          _ToggleRow(
            surface: surface,
            title: t.mePrivacyUsageTitle,
            subtitle: t.mePrivacyUsageBody,
            icon: Icons.insights_outlined,
            value: prefs.analyticsConsent,
            onChanged: (v) => ref.read(userPrefsProvider.notifier).setAnalyticsConsent(v),
          ),
          const SizedBox(height: 16),
          _SectionLabel(text: t.mePrivacySectionLegal, surface: surface),
          const SizedBox(height: 8),
          _ReadOnlyRow(
            surface: surface,
            label: t.meAboutLicense,
            value: t.mePrivacyLicenseValue,
            icon: Icons.description_outlined,
          ),
        ],
      ),
    );
  }
}

class _ToggleRow extends StatelessWidget {
  const _ToggleRow({
    required this.surface,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.value,
    required this.onChanged,
  });
  final PlantlySurface surface;
  final String title;
  final String subtitle;
  final IconData icon;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: surface.surface,
        border: Border.all(color: surface.border),
        borderRadius: BorderRadius.circular(PlantlyTokens.radius),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: surface.green),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: surface.text)),
                Text(subtitle, style: TextStyle(fontSize: 12, color: surface.muted)),
              ],
            ),
          ),
          Switch(
            value: value,
            activeThumbColor: surface.green,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}

class _Card extends StatelessWidget {
  const _Card({required this.surface, required this.child});
  final PlantlySurface surface;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: surface.surface,
        border: Border.all(color: surface.border),
        borderRadius: BorderRadius.circular(PlantlyTokens.radiusXl),
      ),
      child: child,
    );
  }
}

class _Bullet extends StatelessWidget {
  const _Bullet({super.key, required this.surface, required this.text});
  final PlantlySurface surface;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 6, right: 8),
            child: Icon(Icons.circle, size: 5, color: surface.muted),
          ),
          Expanded(
            child: Text(text, style: TextStyle(fontSize: 13, color: surface.text, height: 1.35)),
          ),
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.text, required this.surface});
  final String text;
  final PlantlySurface surface;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: surface.green,
          letterSpacing: 1.1,
        ),
      ),
    );
  }
}

class _ReadOnlyRow extends StatelessWidget {
  const _ReadOnlyRow({
    required this.surface,
    required this.label,
    required this.value,
    required this.icon,
  });
  final PlantlySurface surface;
  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: surface.surface,
        border: Border.all(color: surface.border),
        borderRadius: BorderRadius.circular(PlantlyTokens.radius),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: surface.muted),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: surface.text)),
                Text(value, style: TextStyle(fontSize: 12, color: surface.muted)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
