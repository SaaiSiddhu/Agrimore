// ignore_for_file: public_member_api_docs

import 'package:flutter/material.dart';

import '../themes/sales_associate_tokens.dart';

/// The apps that share the AgriMore Workspace design system.
///
/// Same foundation (spacing, type, radii, neutrals, semantics); a different
/// brand palette. Source: `docs/design-system/SELLER_APP_CANONICAL_ADR.md` §5.
enum WorkspaceBrand {
  /// `apps/employee` — blue `#2563EB`.
  salesAssociate,

  /// `apps/seller` — teal `#0F766E`.
  seller,
}

/// Every colour role a Workspace screen may use, for one brand and one
/// brightness. Read it with `context.ws`; never write a colour literal in a
/// screen.
@immutable
class WorkspaceTokens extends ThemeExtension<WorkspaceTokens> {
  const WorkspaceTokens({
    required this.brand,
    required this.brightness,
    required this.primary,
    required this.primaryPressed,
    required this.primarySubtle,
    required this.primaryMuted,
    required this.onPrimary,
    required this.focusRing,
    required this.pageBackground,
    required this.surface,
    required this.surfaceElevated,
    required this.surfaceSunken,
    required this.textPrimary,
    required this.textSecondary,
    required this.textTertiary,
    required this.divider,
    required this.inputBorder,
    required this.disabledContainer,
    required this.disabledContent,
    required this.scrim,
    required this.successFg,
    required this.successBg,
    required this.warningFg,
    required this.warningBg,
    required this.errorFg,
    required this.errorBg,
    required this.infoFg,
    required this.infoBg,
    required this.dataViz,
  });

  final WorkspaceBrand brand;
  final Brightness brightness;

  // Brand
  final Color primary;
  final Color primaryPressed;
  final Color primarySubtle;
  final Color primaryMuted;
  final Color onPrimary;
  final Color focusRing;

  // Neutrals
  final Color pageBackground;
  final Color surface;
  final Color surfaceElevated;
  final Color surfaceSunken;
  final Color textPrimary;
  final Color textSecondary;
  final Color textTertiary;
  final Color divider;
  final Color inputBorder;
  final Color disabledContainer;
  final Color disabledContent;
  final Color scrim;

  // Semantics
  final Color successFg;
  final Color successBg;
  final Color warningFg;
  final Color warningBg;
  final Color errorFg;
  final Color errorBg;
  final Color infoFg;
  final Color infoBg;

  /// Ordered chart series colours; series 1 is always the brand.
  final List<Color> dataViz;

  bool get isDark => brightness == Brightness.dark;

  static WorkspaceTokens forBrand(WorkspaceBrand brand, Brightness brightness) {
    switch (brand) {
      case WorkspaceBrand.salesAssociate:
        return brightness == Brightness.dark ? salesAssociateDark : salesAssociateLight;
      case WorkspaceBrand.seller:
        return brightness == Brightness.dark ? sellerDark : sellerLight;
    }
  }

  // ── Shared neutrals & semantics (from SaTokens; new roles marked) ──────────

  static const Color _lightSurfaceSunken = Color(0xFFF1F5F9); // new, slate-100
  static const Color _lightTextTertiary = Color(0xFF64748B); // new, slate-500
  static const Color _lightScrim = Color(0x7A0F172A); // new, slate-900 @ 48 %
  static const Color _lightInfoFg = Color(0xFF1D4ED8); // new, blue-700
  static const Color _lightInfoBg = Color(0xFFEFF6FF); // new, blue-50

  static const Color _darkSurfaceSunken = Color(0xFF0B1222); // new
  static const Color _darkTextTertiary = Color(0xFF8594AA); // new — 4.75:1 on darkSurface (slate-500 fails at 3.07)
  static const Color _darkScrim = Color(0xA3000000); // new, black @ 64 %
  static const Color _darkInfoFg = Color(0xFF60A5FA); // new, blue-400
  static const Color _darkInfoBg = Color(0xFF172554); // new, blue-950

  // ── Sales Associate (blue) — identical to SaTokens ─────────────────────────

  static const WorkspaceTokens salesAssociateLight = WorkspaceTokens(
    brand: WorkspaceBrand.salesAssociate,
    brightness: Brightness.light,
    primary: SaTokens.primary,
    primaryPressed: SaTokens.primaryPressed,
    primarySubtle: SaTokens.primarySubtle,
    primaryMuted: Color(0xFFDBEAFE), // new, blue-100
    onPrimary: Color(0xFFFFFFFF),
    focusRing: Color(0x662563EB), // primary @ 40 %
    pageBackground: SaTokens.pageBackground,
    surface: SaTokens.surface,
    surfaceElevated: SaTokens.surface,
    surfaceSunken: _lightSurfaceSunken,
    textPrimary: SaTokens.textPrimary,
    textSecondary: SaTokens.textSecondary,
    textTertiary: _lightTextTertiary,
    divider: SaTokens.divider,
    inputBorder: SaTokens.inputBorder,
    disabledContainer: SaTokens.disabledContainer,
    disabledContent: SaTokens.disabledContent,
    scrim: _lightScrim,
    successFg: SaTokens.successFg,
    successBg: SaTokens.successBg,
    warningFg: SaTokens.warningFg,
    warningBg: SaTokens.warningBg,
    errorFg: SaTokens.errorFg,
    errorBg: SaTokens.errorBg,
    infoFg: _lightInfoFg,
    infoBg: _lightInfoBg,
    dataViz: [
      SaTokens.primary,
      Color(0xFF0F766E),
      Color(0xFFB45309),
      Color(0xFF7C3AED),
      Color(0xFFBE123C),
      Color(0xFF475569),
    ],
  );

  static const WorkspaceTokens salesAssociateDark = WorkspaceTokens(
    brand: WorkspaceBrand.salesAssociate,
    brightness: Brightness.dark,
    primary: SaTokens.darkPrimary,
    primaryPressed: SaTokens.darkPrimaryPressed,
    primarySubtle: SaTokens.darkPrimarySubtle,
    primaryMuted: Color(0xFF1E3A8A), // new, blue-900
    onPrimary: Color(0xFFFFFFFF),
    focusRing: Color(0x803B82F6), // primary @ 50 %
    pageBackground: SaTokens.darkPageBackground,
    surface: SaTokens.darkSurface,
    surfaceElevated: SaTokens.darkSurfaceElevated,
    surfaceSunken: _darkSurfaceSunken,
    textPrimary: SaTokens.darkTextPrimary,
    textSecondary: SaTokens.darkTextSecondary,
    textTertiary: _darkTextTertiary,
    divider: SaTokens.darkDivider,
    inputBorder: SaTokens.darkInputBorder,
    disabledContainer: SaTokens.darkDisabledContainer,
    disabledContent: SaTokens.darkDisabledContent,
    scrim: _darkScrim,
    successFg: SaTokens.darkSuccessFg,
    successBg: SaTokens.darkSuccessBg,
    warningFg: SaTokens.darkWarningFg,
    warningBg: SaTokens.darkWarningBg,
    errorFg: SaTokens.darkErrorFg,
    errorBg: SaTokens.darkErrorBg,
    infoFg: _darkInfoFg,
    infoBg: _darkInfoBg,
    dataViz: [
      SaTokens.darkPrimary,
      Color(0xFF2DD4BF),
      Color(0xFFFBBF24),
      Color(0xFFA78BFA),
      Color(0xFFFB7185),
      Color(0xFF94A3B8),
    ],
  );

  // ── Seller (teal) — ADR §5.1 ───────────────────────────────────────────────

  static const WorkspaceTokens sellerLight = WorkspaceTokens(
    brand: WorkspaceBrand.seller,
    brightness: Brightness.light,
    primary: Color(0xFF0F766E), // teal-700 — 5.5:1 with white text
    primaryPressed: Color(0xFF115E59), // teal-800
    primarySubtle: Color(0xFFF0FDFA), // teal-50
    primaryMuted: Color(0xFFCCFBF1), // teal-100
    onPrimary: Color(0xFFFFFFFF),
    focusRing: Color(0x660F766E), // primary @ 40 %
    pageBackground: SaTokens.pageBackground,
    surface: SaTokens.surface,
    surfaceElevated: SaTokens.surface,
    surfaceSunken: _lightSurfaceSunken,
    textPrimary: SaTokens.textPrimary,
    textSecondary: SaTokens.textSecondary,
    textTertiary: _lightTextTertiary,
    divider: SaTokens.divider,
    inputBorder: SaTokens.inputBorder,
    disabledContainer: SaTokens.disabledContainer,
    disabledContent: SaTokens.disabledContent,
    scrim: _lightScrim,
    successFg: SaTokens.successFg,
    successBg: SaTokens.successBg,
    warningFg: SaTokens.warningFg,
    warningBg: SaTokens.warningBg,
    errorFg: SaTokens.errorFg,
    errorBg: SaTokens.errorBg,
    infoFg: _lightInfoFg,
    infoBg: _lightInfoBg,
    dataViz: [
      Color(0xFF0F766E),
      Color(0xFF2563EB),
      Color(0xFFB45309),
      Color(0xFF7C3AED),
      Color(0xFFBE123C),
      Color(0xFF475569),
    ],
  );

  static const WorkspaceTokens sellerDark = WorkspaceTokens(
    brand: WorkspaceBrand.seller,
    brightness: Brightness.dark,
    primary: Color(0xFF2DD4BF), // teal-400 — 9.6:1 on slate-900
    primaryPressed: Color(0xFF5EEAD4), // teal-300
    primarySubtle: Color(0xFF042F2E), // teal-950
    primaryMuted: Color(0xFF134E4A), // teal-900
    onPrimary: Color(0xFF042F2E), // dark text on bright teal
    focusRing: Color(0x802DD4BF), // primary @ 50 %
    pageBackground: SaTokens.darkPageBackground,
    surface: SaTokens.darkSurface,
    surfaceElevated: SaTokens.darkSurfaceElevated,
    surfaceSunken: _darkSurfaceSunken,
    textPrimary: SaTokens.darkTextPrimary,
    textSecondary: SaTokens.darkTextSecondary,
    textTertiary: _darkTextTertiary,
    divider: SaTokens.darkDivider,
    inputBorder: SaTokens.darkInputBorder,
    disabledContainer: SaTokens.darkDisabledContainer,
    disabledContent: SaTokens.darkDisabledContent,
    scrim: _darkScrim,
    successFg: SaTokens.darkSuccessFg,
    successBg: SaTokens.darkSuccessBg,
    warningFg: SaTokens.darkWarningFg,
    warningBg: SaTokens.darkWarningBg,
    errorFg: SaTokens.darkErrorFg,
    errorBg: SaTokens.darkErrorBg,
    infoFg: _darkInfoFg,
    infoBg: _darkInfoBg,
    dataViz: [
      Color(0xFF2DD4BF),
      Color(0xFF60A5FA),
      Color(0xFFFBBF24),
      Color(0xFFA78BFA),
      Color(0xFFFB7185),
      Color(0xFF94A3B8),
    ],
  );

  @override
  WorkspaceTokens copyWith({
    Color? primary,
    Color? primaryPressed,
    Color? primarySubtle,
    Color? primaryMuted,
    Color? onPrimary,
    Color? focusRing,
    Color? pageBackground,
    Color? surface,
    Color? surfaceElevated,
    Color? surfaceSunken,
    Color? textPrimary,
    Color? textSecondary,
    Color? textTertiary,
    Color? divider,
    Color? inputBorder,
    Color? disabledContainer,
    Color? disabledContent,
    Color? scrim,
    Color? successFg,
    Color? successBg,
    Color? warningFg,
    Color? warningBg,
    Color? errorFg,
    Color? errorBg,
    Color? infoFg,
    Color? infoBg,
    List<Color>? dataViz,
  }) {
    return WorkspaceTokens(
      brand: brand,
      brightness: brightness,
      primary: primary ?? this.primary,
      primaryPressed: primaryPressed ?? this.primaryPressed,
      primarySubtle: primarySubtle ?? this.primarySubtle,
      primaryMuted: primaryMuted ?? this.primaryMuted,
      onPrimary: onPrimary ?? this.onPrimary,
      focusRing: focusRing ?? this.focusRing,
      pageBackground: pageBackground ?? this.pageBackground,
      surface: surface ?? this.surface,
      surfaceElevated: surfaceElevated ?? this.surfaceElevated,
      surfaceSunken: surfaceSunken ?? this.surfaceSunken,
      textPrimary: textPrimary ?? this.textPrimary,
      textSecondary: textSecondary ?? this.textSecondary,
      textTertiary: textTertiary ?? this.textTertiary,
      divider: divider ?? this.divider,
      inputBorder: inputBorder ?? this.inputBorder,
      disabledContainer: disabledContainer ?? this.disabledContainer,
      disabledContent: disabledContent ?? this.disabledContent,
      scrim: scrim ?? this.scrim,
      successFg: successFg ?? this.successFg,
      successBg: successBg ?? this.successBg,
      warningFg: warningFg ?? this.warningFg,
      warningBg: warningBg ?? this.warningBg,
      errorFg: errorFg ?? this.errorFg,
      errorBg: errorBg ?? this.errorBg,
      infoFg: infoFg ?? this.infoFg,
      infoBg: infoBg ?? this.infoBg,
      dataViz: dataViz ?? this.dataViz,
    );
  }

  @override
  WorkspaceTokens lerp(WorkspaceTokens? other, double t) {
    if (other == null) return this;
    Color l(Color a, Color b) => Color.lerp(a, b, t)!;
    final series = List<Color>.generate(
      dataViz.length,
      (i) => i < other.dataViz.length ? l(dataViz[i], other.dataViz[i]) : dataViz[i],
    );
    return WorkspaceTokens(
      brand: t < 0.5 ? brand : other.brand,
      brightness: t < 0.5 ? brightness : other.brightness,
      primary: l(primary, other.primary),
      primaryPressed: l(primaryPressed, other.primaryPressed),
      primarySubtle: l(primarySubtle, other.primarySubtle),
      primaryMuted: l(primaryMuted, other.primaryMuted),
      onPrimary: l(onPrimary, other.onPrimary),
      focusRing: l(focusRing, other.focusRing),
      pageBackground: l(pageBackground, other.pageBackground),
      surface: l(surface, other.surface),
      surfaceElevated: l(surfaceElevated, other.surfaceElevated),
      surfaceSunken: l(surfaceSunken, other.surfaceSunken),
      textPrimary: l(textPrimary, other.textPrimary),
      textSecondary: l(textSecondary, other.textSecondary),
      textTertiary: l(textTertiary, other.textTertiary),
      divider: l(divider, other.divider),
      inputBorder: l(inputBorder, other.inputBorder),
      disabledContainer: l(disabledContainer, other.disabledContainer),
      disabledContent: l(disabledContent, other.disabledContent),
      scrim: l(scrim, other.scrim),
      successFg: l(successFg, other.successFg),
      successBg: l(successBg, other.successBg),
      warningFg: l(warningFg, other.warningFg),
      warningBg: l(warningBg, other.warningBg),
      errorFg: l(errorFg, other.errorFg),
      errorBg: l(errorBg, other.errorBg),
      infoFg: l(infoFg, other.infoFg),
      infoBg: l(infoBg, other.infoBg),
      dataViz: series,
    );
  }
}

/// `context.ws` — the active [WorkspaceTokens]. Throws if the theme was not
/// built by `WorkspaceTheme.build` (or the Sales Associate theme): a missing
/// extension must fail loudly, never silently paint another brand's colours.
extension WorkspaceThemeContext on BuildContext {
  WorkspaceTokens get ws {
    final tokens = Theme.of(this).extension<WorkspaceTokens>();
    if (tokens == null) {
      throw FlutterError(
        'No WorkspaceTokens in the theme. Build the app theme with '
        'WorkspaceTheme.build(WorkspaceBrand.<brand>, brightness).',
      );
    }
    return tokens;
  }

  /// The active text theme (Workspace type scale).
  TextTheme get wsText => Theme.of(this).textTheme;
}
