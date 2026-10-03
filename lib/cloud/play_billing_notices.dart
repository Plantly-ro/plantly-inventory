import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../l10n/generated/app_localizations.dart';
import 'play_billing.dart';
import 'play_billing_providers.dart';

/// Surfaces [PlayBillingService.outcomes] from the app root (mounted next to
/// `CloudNotices` in `main.dart`'s `builder:`), so a restore on app start
/// can talk to the user even when no Cloud screen is open:
/// `already_entitled` → the §4 sheet; pending / verified / failed → SnackBar.
class PlayBillingNotices extends ConsumerStatefulWidget {
  const PlayBillingNotices({super.key, required this.navigatorKey, required this.child});

  /// The root navigator — this widget sits above it (`MaterialApp.builder`),
  /// so the sheet needs the navigator's own context.
  final GlobalKey<NavigatorState> navigatorKey;
  final Widget child;

  @override
  ConsumerState<PlayBillingNotices> createState() => _PlayBillingNoticesState();
}

class _PlayBillingNoticesState extends ConsumerState<PlayBillingNotices> {
  StreamSubscription<PlayPurchaseOutcome>? _sub;
  bool _sheetOpen = false;

  @override
  void initState() {
    super.initState();
    if (ref.read(playBillingAvailableProvider)) {
      _sub = ref.read(playBillingServiceProvider).outcomes.listen(_onOutcome);
    }
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  void _onOutcome(PlayPurchaseOutcome o) {
    if (!mounted) return;
    final t = AppLocalizations.of(context);
    switch (o.kind) {
      case PlayOutcomeKind.alreadyEntitled:
        unawaited(_showAlreadyEntitled(t));
      case PlayOutcomeKind.pending:
        _snack(const Key('play-notice-pending'), t.cloudPlayPending);
      case PlayOutcomeKind.verified:
        _snack(const Key('play-notice-verified'), t.cloudPlayVerified);
      case PlayOutcomeKind.canceled:
        break;
      case PlayOutcomeKind.failed:
        // Restore-time failures (offline at launch, server hiccup) retry
        // silently on resume; only a tap-driven failure deserves a toast.
        if (o.restored) return;
        final text = switch (o.code) {
          'signed_out' => t.cloudSignInLabel,
          'launch_failed' || 'store_error' => t.cloudPlayPurchaseFailed,
          'network' => t.plantlyErrorNetwork,
          'token_owned_by_other_user' => t.cloudPlayTokenOwnedByOther,
          _ => t.cloudPlayVerifyFailed,
        };
        final retryable = o.code != 'token_owned_by_other_user' && o.code != 'invalid_purchase';
        _snack(
          const Key('play-notice-failed'),
          text,
          action: retryable
              ? SnackBarAction(
                  label: t.cloudPlayRetry,
                  onPressed: () => ref.read(playBillingServiceProvider).retryPending(),
                )
              : null,
        );
    }
  }

  void _snack(Key key, String text, {SnackBarAction? action}) {
    ScaffoldMessenger.maybeOf(context)
      ?..clearSnackBars()
      ..showSnackBar(SnackBar(key: key, content: Text(text), action: action));
  }

  Future<void> _showAlreadyEntitled(AppLocalizations t) async {
    final navContext = widget.navigatorKey.currentContext;
    if (_sheetOpen || navContext == null) return;
    _sheetOpen = true;
    try {
      await showModalBottomSheet<void>(
        context: navContext,
        showDragHandle: true,
        builder: (ctx) => SafeArea(
          child: Padding(
            key: const Key('play-already-entitled-sheet'),
            padding: const EdgeInsets.fromLTRB(24, 4, 24, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(t.cloudPlayAlreadyEntitledTitle, style: Theme.of(ctx).textTheme.titleLarge),
                const SizedBox(height: 12),
                Text(t.cloudPlayAlreadyEntitledBody, style: Theme.of(ctx).textTheme.bodyMedium),
                const SizedBox(height: 20),
                FilledButton(
                  key: const Key('play-already-entitled-ok'),
                  onPressed: () => Navigator.of(ctx).pop(),
                  child: Text(MaterialLocalizations.of(ctx).okButtonLabel),
                ),
              ],
            ),
          ),
        ),
      );
    } finally {
      _sheetOpen = false;
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
