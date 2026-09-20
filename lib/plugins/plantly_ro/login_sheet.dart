import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../config/plantly_hosts.dart';
import '../../features/home/home_providers.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../marketplace/plantly_api.dart';
import '../../marketplace/plantly_auth.dart';
import '../../marketplace/plantly_session.dart';
import '../../theme/tokens.dart';

/// Email + password sign-in to plantly.ro (CONTRACT §1/§5). Registration
/// and password reset are web-only — the links open the marketplace.
/// Resolves with the session, or null when dismissed.
Future<PlantlySession?> showPlantlyLoginSheet(
  BuildContext context, {
  required PlantlyAuth auth,
  String? host,
}) {
  return showModalBottomSheet<PlantlySession>(
    context: context,
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

  @override
  Widget build(BuildContext context) {
    final mode = ref.watch(themeModeProvider);
    final surface = mode == ThemeMode.dark ? PlantlySurface.dark : PlantlySurface.light;
    final t = AppLocalizations.of(context);
    final inset = MediaQuery.of(context).viewInsets.bottom;
    return Padding(
      padding: EdgeInsets.only(bottom: inset),
      child: Container(
        decoration: BoxDecoration(
          color: surface.bg,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(PlantlyTokens.radius2xl)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  height: 4,
                  width: 40,
                  decoration: BoxDecoration(color: surface.border, borderRadius: BorderRadius.circular(2)),
                ),
              ),
              const SizedBox(height: 14),
              Text(
                t.plantlyLoginTitle,
                style: GoogleFonts.plusJakartaSans(fontSize: 19, fontWeight: FontWeight.w800, color: surface.text),
              ),
              const SizedBox(height: 4),
              Text(t.plantlyLoginSubtitle, style: TextStyle(fontSize: 12.5, color: surface.muted)),
              const SizedBox(height: 16),
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
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
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
