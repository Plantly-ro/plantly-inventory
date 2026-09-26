import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../data/care_types.dart';
import '../l10n/generated/app_localizations.dart';
import '../theme/tokens.dart';
import 'care_type_labels.dart';

/// Brief, themed feedback for "I just did a thing" care events — richer
/// than the default white SnackBar. Composed of three pieces, any of
/// which you can skip via the named args:
///   - haptic: a medium-impact tap
///   - overlay: the care-type's icon scales up + fades from the screen
///     center over ~700 ms, colour-tinted by the care type
///   - snackbar: a colored banner across the bottom of the scaffold
///
/// Call from a BuildContext that has a ScaffoldMessenger + Overlay in
/// scope (typical Plant Detail / Home / Calendar screens).
Future<void> showCareFeedback(
  BuildContext context, {
  required CareType type,
  required String plantName,
  required PlantlySurface surface,
  String? verb,
  bool haptic = true,
  bool overlay = true,
  bool snackbar = true,
}) async {
  if (haptic) {
    unawaited(HapticFeedback.mediumImpact());
  }
  if (overlay) {
    _showIconOverlay(context, type: type, surface: surface);
  }
  if (snackbar) {
    final messenger = ScaffoldMessenger.of(context);
    final effectiveVerb = verb ?? careTypePastLabel(AppLocalizations.of(context), type);
    messenger
      ..clearSnackBars()
      ..showSnackBar(SnackBar(
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.fromLTRB(14, 0, 14, 80),
        duration: const Duration(milliseconds: 1600),
        backgroundColor: type.color ?? surface.green,
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(PlantlyTokens.radius)),
        content: Row(
          children: [
            Icon(type.icon, color: Colors.white, size: 18),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                '$effectiveVerb · $plantName',
                style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
      ));
  }
}

void _showIconOverlay(
  BuildContext context, {
  required CareType type,
  required PlantlySurface surface,
}) {
  final overlay = Overlay.maybeOf(context, rootOverlay: true);
  if (overlay == null) return;
  final color = type.color ?? surface.green;
  final entry = OverlayEntry(
    builder: (_) => IgnorePointer(
      child: _CareIconBurst(icon: type.icon, color: color),
    ),
  );
  overlay.insert(entry);
  // Strip after the animation has had time to play.
  Future.delayed(const Duration(milliseconds: 900), entry.remove);
}

class _CareIconBurst extends StatefulWidget {
  const _CareIconBurst({required this.icon, required this.color});
  final IconData icon;
  final Color color;

  @override
  State<_CareIconBurst> createState() => _CareIconBurstState();
}

class _CareIconBurstState extends State<_CareIconBurst> with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _scale;
  late final Animation<double> _opacity;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(duration: const Duration(milliseconds: 700), vsync: this)..forward();
    _scale = Tween(begin: 0.5, end: 1.6).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeOutBack),
    );
    _opacity = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: 1.0), weight: 20),
      TweenSequenceItem(tween: ConstantTween(1.0), weight: 30),
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 0.0), weight: 50),
    ]).animate(_ctrl);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: AnimatedBuilder(
        animation: _ctrl,
        builder: (_, _) {
          return Opacity(
            opacity: _opacity.value,
            child: Transform.scale(
              scale: _scale.value,
              child: Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  color: widget.color.withValues(alpha: 0.9),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(color: widget.color.withValues(alpha: 0.4), blurRadius: 30, spreadRadius: 10),
                  ],
                ),
                child: Icon(widget.icon, size: 72, color: Colors.white),
              ),
            ),
          );
        },
      ),
    );
  }
}
