import 'package:flutter/material.dart';

/// Design tokens — mechanical port of
/// `web/prototype/design-system/colors_and_type.css`.
///
/// Every value here has a counterpart in the CSS custom-property source;
/// when the prototype updates (new Claude Design session), diff the CSS
/// and update these in lockstep.
class PlantlyTokens {
  PlantlyTokens._();

  // ─── Botanical (brand green) ────────────────────────────────────────────
  static const Color botanical50 = Color(0xFFF0F7F3);
  static const Color botanical100 = Color(0xFFD9EBE0);
  static const Color botanical200 = Color(0xFFB5D6C3);
  static const Color botanical300 = Color(0xFF86BB9D);
  static const Color botanical400 = Color(0xFF5AAC83);
  static const Color botanical500 = Color(0xFF3D7A5F); // primary
  static const Color botanical600 = Color(0xFF2F6149);
  static const Color botanical700 = Color(0xFF264E3B);
  static const Color botanical800 = Color(0xFF1E3E30);
  static const Color botanical900 = Color(0xFF172F24);
  static const Color botanical950 = Color(0xFF0A1A13);

  // ─── Terracotta (accent) ────────────────────────────────────────────────
  static const Color terra50 = Color(0xFFFDF5EF);
  static const Color terra100 = Color(0xFFFBE8D7);
  static const Color terra200 = Color(0xFFF6CFAB);
  static const Color terra300 = Color(0xFFEEAF7A);
  static const Color terra400 = Color(0xFFE58255);
  static const Color terra500 = Color(0xFFC26A3A); // accent anchor
  static const Color terra600 = Color(0xFFA25529);
  static const Color terra700 = Color(0xFF834324);
  static const Color terra800 = Color(0xFF653320);
  static const Color terra900 = Color(0xFF4D281B);
  static const Color terra950 = Color(0xFF2A140D);

  // ─── Zinc neutrals ──────────────────────────────────────────────────────
  static const Color zinc50 = Color(0xFFFAFAFA);
  static const Color zinc100 = Color(0xFFF4F4F5);
  static const Color zinc200 = Color(0xFFE4E4E7);
  static const Color zinc300 = Color(0xFFD4D4D8);
  static const Color zinc400 = Color(0xFFA1A1AA);
  static const Color zinc500 = Color(0xFF71717A);
  static const Color zinc600 = Color(0xFF52525B);
  static const Color zinc700 = Color(0xFF3F3F46);
  static const Color zinc800 = Color(0xFF27272A);
  static const Color zinc900 = Color(0xFF18181B);
  static const Color zinc950 = Color(0xFF09090B);

  // ─── Typography ─────────────────────────────────────────────────────────
  static const String displayFamily = 'Plus Jakarta Sans';
  static const String bodyFamily = 'Inter';

  static const double textXs = 12;
  static const double textSm = 14;
  static const double textBase = 16;
  static const double textLg = 18;
  static const double textXl = 20;
  static const double text2xl = 24;
  static const double text3xl = 30;
  static const double text4xl = 36;
  static const double text5xl = 48;

  // ─── Spacing (4pt rhythm) ───────────────────────────────────────────────
  static const double space1 = 4;
  static const double space2 = 8;
  static const double space3 = 12;
  static const double space4 = 16;
  static const double space5 = 20;
  static const double space6 = 24;
  static const double space8 = 32;
  static const double space10 = 40;
  static const double space12 = 48;

  // ─── Radius ─────────────────────────────────────────────────────────────
  static const double radiusSm = 6;
  static const double radiusMd = 8;
  static const double radius = 10;
  static const double radiusLg = 10;
  static const double radiusXl = 14;
  static const double radius2xl = 16;
  static const double radius3xl = 24;

  // ─── Durations (matches the CSS --dur-* and --ease-* tokens) ────────────
  static const Duration durFast = Duration(milliseconds: 200);
  static const Duration durBase = Duration(milliseconds: 350);

  static const Cubic easeOutSoft = Cubic(0.16, 1, 0.3, 1);
  static const Cubic easeOut = Cubic(0, 0, 0.2, 1);
  static const Cubic easeIn = Cubic(0.4, 0, 1, 1);
  static const Cubic easeInOut = Cubic(0.4, 0, 0.2, 1);
}

/// Semantic surface/foreground pairs per theme — matches the `useTheme`
/// helper in `web/prototype/components/widgets.jsx`.
class PlantlySurface {
  const PlantlySurface({
    required this.bg,
    required this.surface,
    required this.surfaceAlt,
    required this.text,
    required this.muted,
    required this.border,
    required this.green,
    required this.greenDeep,
    required this.greenSoft,
    required this.terra,
    required this.terraSoft,
  });

  final Color bg;
  final Color surface;
  final Color surfaceAlt;
  final Color text;
  final Color muted;
  final Color border;
  final Color green;
  final Color greenDeep;
  final Color greenSoft;
  final Color terra;
  final Color terraSoft;

  static const light = PlantlySurface(
    bg: Color(0xFFF7F6F2),
    surface: Color(0xFFFFFFFF),
    surfaceAlt: Color(0xFFFAFAF7),
    text: PlantlyTokens.zinc900,
    muted: PlantlyTokens.zinc600,
    border: PlantlyTokens.zinc200,
    green: PlantlyTokens.botanical500,
    greenDeep: PlantlyTokens.botanical700,
    greenSoft: PlantlyTokens.botanical50,
    terra: PlantlyTokens.terra500,
    terraSoft: PlantlyTokens.terra100,
  );

  static const dark = PlantlySurface(
    bg: Color(0xFF0A0A0A),
    surface: PlantlyTokens.zinc900,
    surfaceAlt: PlantlyTokens.zinc950,
    text: Color(0xFFFAFAFA),
    muted: PlantlyTokens.zinc400,
    border: PlantlyTokens.zinc800,
    green: PlantlyTokens.botanical400,
    greenDeep: PlantlyTokens.botanical300,
    greenSoft: Color(0x265AAC83), // rgba(90,172,131,0.15)
    terra: PlantlyTokens.terra400,
    terraSoft: Color(0x26E58255), // rgba(229,130,85,0.15)
  );
}
