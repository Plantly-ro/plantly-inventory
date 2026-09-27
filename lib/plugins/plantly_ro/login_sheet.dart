import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../app/breakpoints.dart';
import '../../app/side_sheet.dart';
import '../../cloud/oauth_handshake.dart';
import '../../config/plantly_hosts.dart';
import '../../features/home/home_providers.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../marketplace/plantly_api.dart';
import '../../marketplace/plantly_auth.dart';
import '../../marketplace/plantly_session.dart';
import '../../shared/sheet_chrome.dart';
import '../../theme/tokens.dart';

/// Sign-in to plantly.ro (CONTRACT §1/§5): Google / Facebook through the
/// marketplace's OAuth start URL (the callback deep link lands the token in
/// [PlantlyAuth], which this sheet watches), or email + password inline.
/// Registration and password reset are web-only — the links open the
/// marketplace. Resolves with the session, or null when dismissed.
///
/// Bottom sheet on phone/tablet, right-side sheet on desktop (same as every
/// other sheet — `showAdaptiveSheet` + [SheetChrome]).
Future<PlantlySession?> showPlantlyLoginSheet(
  BuildContext context, {
  required PlantlyAuth auth,
  String? host,
}) {
  return showAdaptiveSheet<PlantlySession>(
    context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => PlantlyLoginSheet(auth: auth, host: host ?? PlantlyHosts.host),
  );
}

class PlantlyLoginSheet extends ConsumerStatefulWidget {
  const PlantlyLoginSheet({super.key, required this.auth, required this.host});
  final PlantlyAuth auth;
  final String host;

  @override
  ConsumerState<PlantlyLoginSheet> createState() => _PlantlyLoginSheetState();
}

class _PlantlyLoginSheetState extends ConsumerState<PlantlyLoginSheet> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _busy = false;
  bool _obscure = true;
  bool _waitingOauth = false;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final t = AppLocalizations.of(context);
    final email = _email.text.trim();
    final password = _password.text;
    if (email.isEmpty || password.isEmpty) {
      setState(() => _error = t.plantlyLoginMissingFields);
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final session = await widget.auth.signIn(email, password);
      if (mounted) Navigator.of(context).pop(session);
    } on PlantlyApiException catch (e) {
      if (!mounted) return;
      setState(() => _error = mapLoginError(t, e));
    } on PlantlyNetworkException {
      if (!mounted) return;
      setState(() => _error = t.plantlyErrorNetwork);
    } on FormatException {
      if (!mounted) return;
      setState(() => _error = t.plantlyLoginFailed);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// Stable server codes → localized copy.
  static String mapLoginError(AppLocalizations t, PlantlyApiException e) {
    if (e.status == 401) return t.plantlyLoginInvalid;
    if (e.status == 403 && e.code == 'email_not_verified') return t.plantlyLoginNotVerified;
    if (e.status == 403 && e.code == 'account_suspended') return t.plantlyLoginSuspended;
    if (e.status == 429) return t.plantlyErrorRateLimited;
    return t.plantlyLoginFailed;
  }

  Future<void> _open(String url) async {
    await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
  }

  /// Hand off to the marketplace's OAuth flow. Mobile/desktop: external
  /// browser, the app comes back via `plantlyinventory://auth/callback`.
  /// Web: same tab — the page reloads on `/#/auth/callback?token=&nonce=`
  /// (a hash on `/` under the path URL strategy) and the handoff listener
  /// adopts the token.
  Future<void> _oauth(String provider) async {
    final handshake = ref.read(oauthHandshakeProvider); // before the await (#14)
    setState(() {
      _waitingOauth = true;
      _error = null;
    });
    final nonce = await handshake.begin();
    if (!mounted) return;
    final url = Uri.parse(PlantlyHosts.oauthStartUrl(provider, origin: widget.host, nonce: nonce));
    final ok = kIsWeb
        ? await launchUrl(url, webOnlyWindowName: '_self')
        : await launchUrl(url, mode: LaunchMode.externalApplication);
    if (!ok && mounted) {
      final t = AppLocalizations.of(context);
      setState(() {
        _waitingOauth = false;
        _error = t.plantlyLoginFailed;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // A session appearing while we wait on the browser = the OAuth callback
    // landed; resolve exactly like a successful password sign-in.
    ref.listen<AsyncValue<PlantlySession?>>(plantlyAuthProvider, (_, next) {
      final session = next.valueOrNull;
      if (session != null && _waitingOauth && mounted) Navigator.of(context).pop(session);
    });
    final mode = ref.watch(themeModeProvider);
    final surface = mode == ThemeMode.dark ? PlantlySurface.dark : PlantlySurface.light;
    final t = AppLocalizations.of(context);
    final inset = MediaQuery.of(context).viewInsets.bottom;
    final desktop = context.isDesktop;
    // Phone: SheetChrome draws the exact frame this sheet used to hand-roll
    // (bg container, 2xl top radius, 20/12/20/20 padding, handle + 14 gap);
    // the SafeArea keeps the bottom inset inside the sheet as before.
    // Desktop: the chrome header carries title/subtitle + `×`, so the
    // in-body title is skipped there.
    return Padding(
      padding: EdgeInsets.only(bottom: inset),
      child: SheetChrome(
        surface: surface,
        title: t.plantlyLoginTitle,
        subtitle: t.plantlyLoginSubtitle,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
        SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (!desktop) ...[
              Text(
                t.plantlyLoginTitle,
                style: TextStyle(fontFamily: PlantlyFonts.plusJakartaSans, fontSize: 19, fontWeight: FontWeight.w800, color: surface.text),
              ),
              const SizedBox(height: 4),
              Text(t.plantlyLoginSubtitle, style: TextStyle(fontSize: 12.5, color: surface.muted)),
              const SizedBox(height: 16),
              ],
              _SocialButton(
                key: const Key('plantly-login-google'),
                label: t.cloudLoginGoogle,
                icon: Icons.g_mobiledata_rounded,
                surface: surface,
                onPressed: _busy ? null : () => _oauth('google'),
              ),
              const SizedBox(height: 8),
              _SocialButton(
                key: const Key('plantly-login-facebook'),
                label: t.cloudLoginFacebook,
                icon: Icons.facebook_rounded,
                surface: surface,
                onPressed: _busy ? null : () => _oauth('facebook'),
              ),
              if (_waitingOauth) ...[
                const SizedBox(height: 8),
                Text(
                  t.cloudLoginOauthWaiting,
                  key: const Key('plantly-login-oauth-waiting'),
                  style: TextStyle(fontSize: 12, color: surface.muted),
                ),
              ],
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(child: Divider(color: surface.border, height: 1)),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    child: Text(t.cloudLoginOr, style: TextStyle(fontSize: 11.5, color: surface.muted)),
                  ),
                  Expanded(child: Divider(color: surface.border, height: 1)),
                ],
              ),
              const SizedBox(height: 14),
              TextField(
                key: const Key('plantly-login-email'),
                controller: _email,
                enabled: !_busy,
                keyboardType: TextInputType.emailAddress,
                autocorrect: false,
                textInputAction: TextInputAction.next,
                style: TextStyle(fontSize: 14, color: surface.text),
                decoration: _dec(surface, t.plantlyLoginEmail),
              ),
              const SizedBox(height: 10),
              TextField(
                key: const Key('plantly-login-password'),
                controller: _password,
                enabled: !_busy,
                obscureText: _obscure,
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => _submit(),
                style: TextStyle(fontSize: 14, color: surface.text),
                decoration: _dec(surface, t.plantlyLoginPassword).copyWith(
                  suffixIcon: IconButton(
                    icon: Icon(_obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                        size: 18, color: surface.muted),
                    onPressed: () => setState(() => _obscure = !_obscure),
                  ),
                ),
              ),
              if (_error != null) ...[
                const SizedBox(height: 10),
                Text(_error!, key: const Key('plantly-login-error'), style: TextStyle(fontSize: 12.5, color: surface.terra)),
              ],
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  key: const Key('plantly-login-submit'),
                  style: FilledButton.styleFrom(
                    backgroundColor: surface.green,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(PlantlyTokens.radius + 2)),
                  ),
                  onPressed: _busy ? null : _submit,
                  child: _busy
                      ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : Text(t.plantlyLoginSubmit, style: const TextStyle(fontWeight: FontWeight.w700)),
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                alignment: WrapAlignment.spaceBetween,
                children: [
                  TextButton(
                    onPressed: () => _open(PlantlyHosts.authUrl(mode: 'register', origin: widget.host)),
                    child: Text(t.plantlyLoginCreateAccount, style: TextStyle(fontSize: 12.5, color: surface.green)),
                  ),
                  TextButton(
                    onPressed: () => _open(PlantlyHosts.authUrl(mode: 'forgot', origin: widget.host)),
                    child: Text(t.plantlyLoginForgot, style: TextStyle(fontSize: 12.5, color: surface.muted)),
                  ),
                ],
              ),
            ],
          ),
        ),
        ],
      ),
    );
  }

  InputDecoration _dec(PlantlySurface surface, String hint) => InputDecoration(
        isDense: true,
        filled: true,
        fillColor: surface.surface,
        hintText: hint,
        hintStyle: TextStyle(fontSize: 14, color: surface.muted),
        contentPadding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
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
      );
}

class _SocialButton extends StatelessWidget {
  const _SocialButton({
    super.key,
    required this.label,
    required this.icon,
    required this.surface,
    required this.onPressed,
  });

  final String label;
  final IconData icon;
  final PlantlySurface surface;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        style: OutlinedButton.styleFrom(
          foregroundColor: surface.text,
          side: BorderSide(color: surface.border),
          padding: const EdgeInsets.symmetric(vertical: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(PlantlyTokens.radius + 2)),
        ),
        onPressed: onPressed,
        icon: Icon(icon, size: 20),
        label: Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
      ),
    );
  }
}
