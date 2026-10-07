import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../cloud/entitlement.dart';
import '../../cloud/local_data_wipe.dart';
import '../../cloud/sign_in_events.dart';
import '../../cloud/web_access.dart';
import '../../config/plantly_hosts.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../marketplace/plantly_api.dart';
import '../../marketplace/plantly_auth.dart';
import '../../plugins/plantly_ro/login_sheet.dart';
import '../../shared/web_sign_out_flow.dart';
import '../../theme/tokens.dart';
import '../home/home_providers.dart';

/// `/gate` — what the browser build shows instead of the app shell while
/// [webAccessProvider] is closed (WEB-ACCESS-POLICY §0). Three states:
///
///  1. signed out      → value prop + "Sign in" (existing plantly.ro OAuth /
///                       login sheet) + the free-Android card;
///  2. not entitled    → greeting + plan prices (`/subscriptions/plans`,
///                       fixed EUR copy when that fails) + "Subscribe on
///                       plantly.ro" (same tab) + "I already subscribed —
///                       check again" + Android card + Pro note + sign-out;
///  3. open / checking → a spinner; the router moves on (or in) at once.
///
/// Plus the unreachable variant of 2 (offline, nothing usable cached): the
/// same frame with a retry instead of the plan summary.
class WebAccessGate extends ConsumerStatefulWidget {
  const WebAccessGate({super.key});

  @override
  ConsumerState<WebAccessGate> createState() => _WebAccessGateState();
}

class _WebAccessGateState extends ConsumerState<WebAccessGate> {
  bool _busy = false;

  @override
  Widget build(BuildContext context) {
    final access = ref.watch(webAccessProvider);
    final mode = ref.watch(themeModeProvider);
    final surface = mode == ThemeMode.dark ? PlantlySurface.dark : PlantlySurface.light;
    final t = AppLocalizations.of(context);

    final Widget body = switch (access) {
      WebAccessSignedOut() => _SignedOut(surface: surface, onSignIn: _signIn, key: const Key('gate-signed-out')),
      WebAccessNotEntitled(:final username) => _NotEntitled(
        key: const Key('gate-not-entitled'),
        surface: surface,
        username: username,
        busy: _busy,
        onSubscribe: _subscribe,
        onRetry: _retry,
        onSignOut: () => _signOut(username),
      ),
      WebAccessUnreachable(:final username) => _Unreachable(
        key: const Key('gate-unreachable'),
        surface: surface,
        username: username,
        busy: _busy,
        onRetry: _retry,
        onSignOut: () => _signOut(username),
      ),
      WebAccessHeldByOther(:final username, :final other) => _HeldByOther(
        key: const Key('gate-held-by-other'),
        surface: surface,
        username: username,
        other: other,
        busy: _busy,
        onClear: _clearLocal,
        onSignOut: () => _signOut(username),
      ),
      WebAccessChecking() || WebAccessOpen() => _Checking(surface: surface, label: t.gateChecking),
    };

    return Scaffold(
      key: const Key('web-access-gate'),
      backgroundColor: surface.bg,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _Brand(surface: surface),
                  const SizedBox(height: 20),
                  body,
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _signIn() async {
    final auth = ref.read(plantlyAuthProvider.notifier); // before the await (#14)
    final events = ref.read(signInEventsProvider);
    final session = await showPlantlyLoginSheet(context, auth: auth, purpose: LoginPurpose.cloud);
    if (session != null) events.emit(session);
  }

  /// Same tab (§0): the subscription page comes back to this origin and
  /// the next entitlement check (focus / retry) opens the gate.
  Future<void> _subscribe() async {
    final url = Uri.parse(PlantlyHosts.subscriptionUrl());
    if (kIsWeb) {
      await launchUrl(url, webOnlyWindowName: '_self');
    } else {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    }
  }

  Future<void> _retry() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await ref.read(cloudEntitlementProvider.notifier).refresh();
    } catch (_) {
      // The verdict (unreachable / not entitled) renders from the provider.
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// Held by another account: drop this browser's copy (the session stays)
  /// and start over — the reload re-links for the signed-in account.
  Future<void> _clearLocal() async {
    if (_busy) return;
    final t = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _busy = true);
    try {
      await ref.read(localDataWiperProvider).wipeAndReload();
    } catch (e) {
      if (mounted) setState(() => _busy = false);
      messenger.showSnackBar(SnackBar(content: Text(t.gateClearFailed('$e'))));
    }
  }

  Future<void> _signOut(String username) async {
    final t = AppLocalizations.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(t.cloudSignOutTitle),
        content: Text(t.cloudSignOutBodyWeb(username)),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: Text(t.cancel)),
          FilledButton(
            key: const Key('gate-sign-out-confirm'),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(t.cloudSignOut),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    // The gate only exists on web: an explicit sign-out wipes this browser.
    await completeWebSignOut(context, ref);
  }
}

class _Brand extends StatelessWidget {
  const _Brand({required this.surface});
  final PlantlySurface surface;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(color: surface.green, borderRadius: BorderRadius.circular(12)),
          child: const Icon(Icons.inventory_2_outlined, color: Colors.white, size: 22),
        ),
        const SizedBox(width: 12),
        Text(
          'Plantly Inventory',
          style: TextStyle(
            fontFamily: PlantlyFonts.plusJakartaSans,
            fontSize: 20,
            fontWeight: FontWeight.w800,
            color: surface.text,
          ),
        ),
      ],
    );
  }
}

class _Card extends StatelessWidget {
  const _Card({required this.surface, required this.child, this.alt = false, super.key});
  final PlantlySurface surface;
  final Widget child;
  final bool alt;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: alt ? surface.surfaceAlt : surface.surface,
        borderRadius: BorderRadius.circular(PlantlyTokens.radiusXl),
        border: Border.all(color: surface.border),
      ),
      child: child,
    );
  }
}

class _SignedOut extends StatelessWidget {
  const _SignedOut({required this.surface, required this.onSignIn, super.key});
  final PlantlySurface surface;
  final VoidCallback onSignIn;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _Card(
          surface: surface,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                t.gateHeadline,
                key: const Key('gate-headline'),
                style: TextStyle(
                  fontFamily: PlantlyFonts.plusJakartaSans,
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                  color: surface.text,
                  height: 1.15,
                ),
              ),
              const SizedBox(height: 12),
              Text(t.gateValueProp, style: TextStyle(fontSize: 15, color: surface.muted, height: 1.45)),
              const SizedBox(height: 20),
              FilledButton.icon(
                key: const Key('gate-sign-in'),
                onPressed: onSignIn,
                icon: const Icon(Icons.login),
                label: Text(t.gateSignIn),
                style: FilledButton.styleFrom(
                  backgroundColor: surface.green,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        _AndroidCard(surface: surface),
      ],
    );
  }
}

class _NotEntitled extends ConsumerWidget {
  const _NotEntitled({
    required this.surface,
    required this.username,
    required this.busy,
    required this.onSubscribe,
    required this.onRetry,
    required this.onSignOut,
    super.key,
  });
  final PlantlySurface surface;
  final String username;
  final bool busy;
  final VoidCallback onSubscribe;
  final VoidCallback onRetry;
  final VoidCallback onSignOut;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _Card(
          surface: surface,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                t.gateHello(username),
                key: const Key('gate-hello'),
                style: TextStyle(
                  fontFamily: PlantlyFonts.plusJakartaSans,
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: surface.text,
                  height: 1.2,
                ),
              ),
              const SizedBox(height: 14),
              _PlanSummary(surface: surface),
              const SizedBox(height: 6),
              Text(
                t.gateIncludedInPro,
                key: const Key('gate-pro-note'),
                style: TextStyle(fontSize: 13, color: surface.muted),
              ),
              const SizedBox(height: 20),
              FilledButton.icon(
                key: const Key('gate-subscribe'),
                onPressed: onSubscribe,
                // Same-tab navigation (§0), so not the "opens elsewhere" glyph.
                icon: const Icon(Icons.arrow_forward),
                label: Text(t.gateSubscribe),
                style: FilledButton.styleFrom(
                  backgroundColor: surface.green,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                ),
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                key: const Key('gate-retry'),
                onPressed: busy ? null : onRetry,
                icon: busy
                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.refresh),
                label: Text(t.gateRetry),
                style: OutlinedButton.styleFrom(
                  foregroundColor: surface.text,
                  side: BorderSide(color: surface.border),
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                t.gateDataKept,
                key: const Key('gate-data-kept'),
                style: TextStyle(fontSize: 12.5, color: surface.muted, height: 1.4),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        _AndroidCard(surface: surface),
        const SizedBox(height: 12),
        Center(
          child: TextButton(
            key: const Key('gate-sign-out'),
            onPressed: onSignOut,
            child: Text(t.gateSignOutLink, style: TextStyle(color: surface.muted)),
          ),
        ),
      ],
    );
  }
}

class _HeldByOther extends StatelessWidget {
  const _HeldByOther({
    required this.surface,
    required this.username,
    required this.other,
    required this.busy,
    required this.onClear,
    required this.onSignOut,
    super.key,
  });
  final PlantlySurface surface;
  final String username;
  final String other;
  final bool busy;
  final VoidCallback onClear;
  final VoidCallback onSignOut;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _Card(
          surface: surface,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: Icon(Icons.lock_person_outlined, color: surface.muted, size: 32),
              ),
              const SizedBox(height: 12),
              Text(
                t.gateHeldByOtherTitle(other),
                key: const Key('gate-held-by-other-title'),
                style: TextStyle(
                  fontFamily: PlantlyFonts.plusJakartaSans,
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: surface.text,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                t.gateHeldByOtherBody(username, other),
                style: TextStyle(fontSize: 14.5, color: surface.muted, height: 1.4),
              ),
              const SizedBox(height: 20),
              FilledButton.icon(
                key: const Key('gate-clear-local'),
                onPressed: busy ? null : onClear,
                icon: busy
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.cleaning_services_outlined),
                label: Text(t.gateClearLocal),
                style: FilledButton.styleFrom(
                  backgroundColor: surface.green,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Center(
          child: TextButton(
            key: const Key('gate-sign-out'),
            onPressed: busy ? null : onSignOut,
            child: Text(t.gateSignOutLink, style: TextStyle(color: surface.muted)),
          ),
        ),
      ],
    );
  }
}

class _Unreachable extends StatelessWidget {
  const _Unreachable({
    required this.surface,
    required this.username,
    required this.busy,
    required this.onRetry,
    required this.onSignOut,
    super.key,
  });
  final PlantlySurface surface;
  final String username;
  final bool busy;
  final VoidCallback onRetry;
  final VoidCallback onSignOut;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _Card(
          surface: surface,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: Icon(Icons.cloud_off_outlined, color: surface.muted, size: 32),
              ),
              const SizedBox(height: 12),
              Text(
                t.gateUnreachableTitle,
                key: const Key('gate-unreachable-title'),
                style: TextStyle(
                  fontFamily: PlantlyFonts.plusJakartaSans,
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: surface.text,
                ),
              ),
              const SizedBox(height: 8),
              Text(t.gateUnreachableBody, style: TextStyle(fontSize: 14.5, color: surface.muted, height: 1.4)),
              const SizedBox(height: 20),
              FilledButton.icon(
                key: const Key('gate-retry'),
                onPressed: busy ? null : onRetry,
                icon: busy
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.refresh),
                label: Text(t.gateTryAgain),
                style: FilledButton.styleFrom(
                  backgroundColor: surface.green,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                ),
              ),
              const SizedBox(height: 16),
              Text(t.gateDataKept, style: TextStyle(fontSize: 12.5, color: surface.muted, height: 1.4)),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Center(
          child: TextButton(
            key: const Key('gate-sign-out'),
            onPressed: onSignOut,
            child: Text(t.gateSignOutLink, style: TextStyle(color: surface.muted)),
          ),
        ),
      ],
    );
  }
}

class _Checking extends StatelessWidget {
  const _Checking({required this.surface, required this.label});
  final PlantlySurface surface;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Column(
      key: const Key('gate-checking'),
      children: [
        const SizedBox(height: 24),
        SizedBox(width: 28, height: 28, child: CircularProgressIndicator(strokeWidth: 2.5, color: surface.green)),
        const SizedBox(height: 16),
        Text(label, style: TextStyle(color: surface.muted)),
      ],
    );
  }
}

/// Prices of the Inventory Cloud plans in the visitor's currency (RON for a
/// Romanian UI, EUR otherwise — the server offers both), or the fixed EUR
/// copy when the endpoint is unavailable / returns nothing priced.
class _PlanSummary extends ConsumerWidget {
  const _PlanSummary({required this.surface});
  final PlantlySurface surface;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = AppLocalizations.of(context);
    final plans = ref.watch(cloudPlansProvider);
    final style = TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: surface.text);
    return plans.when(
      loading: () => Text(
        t.gatePlansLoading,
        key: const Key('gate-plans-loading'),
        style: TextStyle(fontSize: 14, color: surface.muted),
      ),
      error: (_, _) => Text(t.gatePlansFallback, key: const Key('gate-plans-fallback'), style: style),
      data: (list) {
        final text = formatPlans(list, t, Localizations.localeOf(context));
        return text == null
            ? Text(t.gatePlansFallback, key: const Key('gate-plans-fallback'), style: style)
            : Text(text, key: const Key('gate-plans'), style: style);
      },
    );
  }

  /// "9,00 RON/lună sau 79,00 RON/an"; null when no plan carries a price.
  static String? formatPlans(List<SubscriptionPlan> plans, AppLocalizations t, Locale locale) {
    final currency = locale.languageCode == 'ro' ? 'ron' : 'eur';
    final parts = <String>[];
    for (final interval in const ['month', 'year']) {
      SubscriptionPlan? plan;
      for (final p in plans) {
        if (p.interval == interval) plan = p;
      }
      final price = plan?.priceIn(currency);
      if (price == null) continue;
      final amount = formatMoney(price.amountMinor, price.currency, locale);
      parts.add(interval == 'month' ? t.gatePlanMonthly(amount) : t.gatePlanYearly(amount));
    }
    if (parts.isEmpty) return null;
    return parts.join(' ${t.gatePlansOr} ');
  }

  static String formatMoney(int minor, String currency, Locale locale) {
    final f = NumberFormat.simpleCurrency(locale: locale.toString(), name: currency.toUpperCase());
    return f.format(minor / 100);
  }
}

/// "Prefer your phone?" — the free Android app, with the official Play
/// badge (RO/EN by UI locale) and the one-line cloud pitch.
class _AndroidCard extends StatelessWidget {
  const _AndroidCard({required this.surface});
  final PlantlySurface surface;

  /// Google's badge guidelines: never alter the artwork, minimum height
  /// 40 px, clear space around it of at least a quarter of its height.
  static const double badgeHeight = 56;
  static const double badgeClearSpace = badgeHeight / 4;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final lang = Localizations.localeOf(context).languageCode == 'ro' ? 'ro' : 'en';
    return _Card(
      key: const Key('gate-android-card'),
      surface: surface,
      alt: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            t.gateAndroidTitle,
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: surface.text),
          ),
          const SizedBox(height: 4),
          Text(t.gateAndroidBody, style: TextStyle(fontSize: 14, color: surface.muted, height: 1.4)),
          const SizedBox(height: 8),
          Semantics(
            button: true,
            link: true,
            label: t.gatePlayBadgeLabel,
            child: InkWell(
              key: const Key('gate-play-badge'),
              onTap: () => launchUrl(Uri.parse(PlantlyHosts.playStoreUrl)),
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding: const EdgeInsets.all(badgeClearSpace),
                child: Image.asset(
                  'assets/badges/${lang}_badge_web_generic.png',
                  height: badgeHeight,
                  fit: BoxFit.contain,
                  filterQuality: FilterQuality.medium,
                  semanticLabel: t.gatePlayBadgeLabel,
                ),
              ),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            t.gateAndroidCloudLine,
            key: const Key('gate-android-cloud-line'),
            style: TextStyle(fontSize: 13, color: surface.muted, height: 1.4),
          ),
        ],
      ),
    );
  }
}
