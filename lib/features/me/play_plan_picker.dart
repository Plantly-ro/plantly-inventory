import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../cloud/play_billing.dart';
import '../../cloud/play_billing_providers.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../theme/tokens.dart';

/// The two Inventory Cloud base plans with Play's localized prices
/// (PLAY-BILLING-CONTRACT §4). Rendered by `CloudRows` on Android when both
/// flags are on and the account is not entitled. Loads the plans on first
/// build; shows loading / unavailable / busy states. Purchase outcomes
/// (sheet, toasts) are surfaced by `PlayBillingNotices` at the app root.
class PlayPlanPicker extends ConsumerStatefulWidget {
  const PlayPlanPicker({super.key, required this.surface});
  final PlantlySurface surface;

  @override
  ConsumerState<PlayPlanPicker> createState() => _PlayPlanPickerState();
}

class _PlayPlanPickerState extends ConsumerState<PlayPlanPicker> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) ref.read(playBillingServiceProvider).loadPlans();
    });
  }

  @override
  Widget build(BuildContext context) {
    final surface = widget.surface;
    final t = AppLocalizations.of(context);
    final state = ref.watch(playBillingStateProvider);
    final service = ref.read(playBillingServiceProvider);
    final Widget body;
    switch (state.phase) {
      case PlayBillingPhase.idle:
      case PlayBillingPhase.loadingPlans:
        body = _note(key: const Key('play-plans-loading'), text: t.cloudPlayLoadingPlans, surface: surface);
      case PlayBillingPhase.unavailable:
        body = Row(
          children: [
            Expanded(child: _note(key: const Key('play-plans-unavailable'), text: t.cloudPlayUnavailable, surface: surface)),
            TextButton(
              key: const Key('play-plans-retry'),
              onPressed: service.loadPlans,
              child: Text(t.cloudPlayRetry),
            ),
          ],
        );
      case PlayBillingPhase.ready:
      case PlayBillingPhase.purchasing:
      case PlayBillingPhase.verifying:
        body = Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (var i = 0; i < state.plans.length; i++) ...[
              if (i > 0) const SizedBox(height: 6),
              _PlanCard(
                plan: state.plans[i],
                surface: surface,
                busy: state.busy,
                onTap: state.busy ? null : () => service.buy(state.plans[i]),
              ),
            ],
          ],
        );
    }
    return Column(
      key: const Key('cloud-play-plans'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 4, 4, 6),
          child: Text(
            t.cloudPlayPlansTitle,
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: surface.muted, letterSpacing: 0.3),
          ),
        ),
        body,
      ],
    );
  }

  Widget _note({required Key key, required String text, required PlantlySurface surface}) => Padding(
        key: key,
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
        child: Text(text, style: TextStyle(fontSize: 13, height: 1.4, color: surface.muted)),
      );
}

class _PlanCard extends StatelessWidget {
  const _PlanCard({required this.plan, required this.surface, required this.busy, this.onTap});
  final PlayPlan plan;
  final PlantlySurface surface;
  final bool busy;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final name = plan.isYearly ? t.cloudPlayPlanYearly : t.cloudPlayPlanMonthly;
    final price = plan.isYearly ? t.cloudPlayPerYear(plan.formattedPrice) : t.cloudPlayPerMonth(plan.formattedPrice);
    return Material(
      color: surface.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(PlantlyTokens.radius),
        side: BorderSide(color: surface.border),
      ),
      child: InkWell(
        key: Key('play-plan-${plan.basePlanId}'),
        borderRadius: BorderRadius.circular(PlantlyTokens.radius),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              Icon(plan.isYearly ? Icons.calendar_month_outlined : Icons.calendar_view_month_outlined,
                  size: 20, color: surface.green),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(name, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: surface.text)),
                    const SizedBox(height: 2),
                    Text(
                      busy ? t.cloudPlayActivating : price,
                      key: Key('play-plan-${plan.basePlanId}-price'),
                      style: TextStyle(fontSize: 12.5, color: surface.muted),
                    ),
                  ],
                ),
              ),
              if (busy)
                const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
              else
                Icon(Icons.chevron_right, size: 16, color: surface.muted),
            ],
          ),
        ),
      ),
    );
  }
}
