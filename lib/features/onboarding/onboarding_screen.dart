import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../data/providers.dart';
import '../../data/user_prefs.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../theme/tokens.dart';
import '../home/home_providers.dart';

/// First-run onboarding. Three steps:
///   1. Welcome + optional display name — used by the greeting.
///   2. Notification permission — plant reminders won't fire without it.
///   3. Privacy & consent — both toggles default off; the user explicitly
///      opts in to crash reports and/or anonymous usage.
/// Finishes by flipping [UserPrefs.onboardingSeen] so this never shows
/// again on the same install.
class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final _pages = PageController();
  final _name = TextEditingController();
  int _step = 0;
  bool _notifGranted = false;
  bool _crash = false;
  bool _analytics = false;

  @override
  void dispose() {
    _pages.dispose();
    _name.dispose();
    super.dispose();
  }

  Future<void> _next() async {
    if (_step == 2) {
      final prefsCtrl = ref.read(userPrefsProvider.notifier);
      await prefsCtrl.setName(_name.text);
      await prefsCtrl.setCrashConsent(_crash);
      await prefsCtrl.setAnalyticsConsent(_analytics);
      await prefsCtrl.markOnboarded();
      if (mounted) Navigator.of(context).pop();
      return;
    }
    setState(() => _step += 1);
    _pages.animateToPage(_step, duration: const Duration(milliseconds: 220), curve: Curves.easeOut);
  }

  Future<void> _requestNotif() async {
    final ok = await ref.read(notificationServiceProvider).requestPermissions();
    ref.read(notificationPermissionProvider.notifier).state = ok;
    if (mounted) setState(() => _notifGranted = ok);
  }

  @override
  Widget build(BuildContext context) {
    final mode = ref.watch(themeModeProvider);
    final surface = mode == ThemeMode.dark ? PlantlySurface.dark : PlantlySurface.light;

    return Scaffold(
      backgroundColor: surface.bg,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
              child: Row(
                children: [
                  for (var i = 0; i < 3; i++) ...[
                    Expanded(
                      child: Container(
                        height: 3,
                        decoration: BoxDecoration(
                          color: i <= _step ? surface.green : surface.border,
                          borderRadius: BorderRadius.circular(999),
                        ),
                      ),
                    ),
                    if (i < 2) const SizedBox(width: 6),
                  ],
                ],
              ),
            ),
            Expanded(
              child: PageView(
                controller: _pages,
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  _WelcomeStep(surface: surface, nameController: _name),
                  _NotifStep(
                    surface: surface,
                    granted: _notifGranted,
                    supported: ref.watch(notificationServiceProvider).isSupported,
                    onRequest: _requestNotif,
                  ),
                  _PrivacyStep(
                    surface: surface,
                    crash: _crash,
                    analytics: _analytics,
                    onCrash: (v) => setState(() => _crash = v),
                    onAnalytics: (v) => setState(() => _analytics = v),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: surface.green,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(PlantlyTokens.radius)),
                  ),
                  onPressed: _next,
                  child: Text(_step == 2 ? AppLocalizations.of(context).onbStart : AppLocalizations.of(context).onbContinue,
                      style: GoogleFonts.plusJakartaSans(fontSize: 15, fontWeight: FontWeight.w700)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _WelcomeStep extends StatelessWidget {
  const _WelcomeStep({required this.surface, required this.nameController});
  final PlantlySurface surface;
  final TextEditingController nameController;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 56,
            height: 56,
            alignment: Alignment.center,
            decoration: BoxDecoration(color: surface.greenSoft, borderRadius: BorderRadius.circular(28)),
            child: Icon(Icons.eco_outlined, color: surface.green, size: 30),
          ),
          const SizedBox(height: 20),
          Text(
            t.onbWelcomeTitle,
            style: GoogleFonts.plusJakartaSans(fontSize: 26, fontWeight: FontWeight.w800, color: surface.text, letterSpacing: -0.5),
          ),
          const SizedBox(height: 8),
          Text(
            t.onbWelcomeBody,
            style: TextStyle(fontSize: 14, color: surface.muted, height: 1.4),
          ),
          const SizedBox(height: 28),
          Text(t.onbNameLabel, style: _labelStyle(surface)),
          const SizedBox(height: 8),
          TextField(
            controller: nameController,
            textCapitalization: TextCapitalization.words,
            decoration: InputDecoration(
              hintText: t.meYourNameHint,
              hintStyle: TextStyle(color: surface.muted),
              filled: true,
              fillColor: surface.surface,
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(PlantlyTokens.radius),
                borderSide: BorderSide(color: surface.border),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(PlantlyTokens.radius),
                borderSide: BorderSide(color: surface.border),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(PlantlyTokens.radius),
                borderSide: BorderSide(color: surface.green, width: 1.5),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            t.onbNameHelp,
            style: TextStyle(fontSize: 12, color: surface.muted),
          ),
        ],
      ),
    );
  }
}

class _NotifStep extends StatelessWidget {
  const _NotifStep({
    required this.surface,
    required this.granted,
    required this.supported,
    required this.onRequest,
  });
  final PlantlySurface surface;
  final bool granted;
  /// False on web — no permission to grant, say so instead.
  final bool supported;
  final VoidCallback onRequest;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 56,
            height: 56,
            alignment: Alignment.center,
            decoration: BoxDecoration(color: surface.greenSoft, borderRadius: BorderRadius.circular(28)),
            child: Icon(Icons.notifications_active_outlined, color: surface.green, size: 30),
          ),
          const SizedBox(height: 20),
          Text(
            t.onbNotifTitle,
            style: GoogleFonts.plusJakartaSans(fontSize: 26, fontWeight: FontWeight.w800, color: surface.text, letterSpacing: -0.5),
          ),
          const SizedBox(height: 8),
          Text(
            t.onbNotifBody,
            style: TextStyle(fontSize: 14, color: surface.muted, height: 1.4),
          ),
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: surface.surface,
              border: Border.all(color: surface.border),
              borderRadius: BorderRadius.circular(PlantlyTokens.radius),
            ),
            child: Row(
              children: [
                Icon(granted ? Icons.check_circle : Icons.notifications_outlined,
                    color: granted ? surface.green : surface.muted, size: 22),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    !supported
                        ? t.notificationsWebUnavailableDetail
                        : granted
                            ? t.onbNotifGranted
                            : t.onbNotifAsk,
                    style: TextStyle(fontSize: 14, color: surface.text, fontWeight: FontWeight.w600),
                  ),
                ),
                if (!granted && supported)
                  TextButton(
                    style: TextButton.styleFrom(foregroundColor: surface.green),
                    onPressed: onRequest,
                    child: Text(t.onbGrant),
                  ),
              ],
            ),
          ),
          if (supported) ...[
            const SizedBox(height: 12),
            Text(
              t.onbNotifSkip,
              style: TextStyle(fontSize: 12, color: surface.muted),
            ),
          ],
        ],
      ),
    );
  }
}

class _PrivacyStep extends StatelessWidget {
  const _PrivacyStep({
    required this.surface,
    required this.crash,
    required this.analytics,
    required this.onCrash,
    required this.onAnalytics,
  });
  final PlantlySurface surface;
  final bool crash;
  final bool analytics;
  final ValueChanged<bool> onCrash;
  final ValueChanged<bool> onAnalytics;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 56,
            height: 56,
            alignment: Alignment.center,
            decoration: BoxDecoration(color: surface.greenSoft, borderRadius: BorderRadius.circular(28)),
            child: Icon(Icons.shield_outlined, color: surface.green, size: 30),
          ),
          const SizedBox(height: 20),
          Text(
            t.onbPrivacyTitle,
            style: GoogleFonts.plusJakartaSans(fontSize: 26, fontWeight: FontWeight.w800, color: surface.text, letterSpacing: -0.5),
          ),
          const SizedBox(height: 8),
          Text(
            t.onbPrivacyBody,
            style: TextStyle(fontSize: 14, color: surface.muted, height: 1.4),
          ),
          const SizedBox(height: 20),
          _ConsentTile(
            surface: surface,
            icon: Icons.bug_report_outlined,
            title: t.onbCrashTitle,
            subtitle: t.onbCrashSub,
            value: crash,
            onChanged: onCrash,
          ),
          const SizedBox(height: 10),
          _ConsentTile(
            surface: surface,
            icon: Icons.insights_outlined,
            title: t.onbUsageTitle,
            subtitle: t.onbUsageSub,
            value: analytics,
            onChanged: onAnalytics,
          ),
        ],
      ),
    );
  }
}

class _ConsentTile extends StatelessWidget {
  const _ConsentTile({
    required this.surface,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });
  final PlantlySurface surface;
  final IconData icon;
  final String title;
  final String subtitle;
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
          Icon(icon, size: 20, color: surface.green),
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

TextStyle _labelStyle(PlantlySurface s) => TextStyle(
      fontSize: 11,
      fontWeight: FontWeight.w700,
      color: s.muted,
      letterSpacing: 1.1,
    );
