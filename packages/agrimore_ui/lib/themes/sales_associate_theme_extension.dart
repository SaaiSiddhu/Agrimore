// ignore_for_file: public_member_api_docs

import 'package:flutter/material.dart';
import 'sales_associate_tokens.dart';

/// A [ThemeExtension] that makes [SaTokens] colour values available through
/// [Theme.of(context).extension<SalesAssociateTokens>()].
///
/// Attach this extension to [SalesAssociateTheme.lightTheme] so that every
/// Sales Associate widget can read the semantic token set without needing a
/// direct import of [SaTokens].
///
/// Example:
/// ```dart
/// final tokens = Theme.of(context).extension<SalesAssociateTokens>()!;
/// container.color = tokens.primary;
/// ```
@immutable
class SalesAssociateTokens extends ThemeExtension<SalesAssociateTokens> {
  const SalesAssociateTokens({
    required this.primary,
    required this.primaryPressed,
    required this.primarySubtle,
    required this.pageBackground,
    required this.surface,
    required this.textPrimary,
    required this.textSecondary,
    required this.divider,
    required this.inputBorder,
    required this.successFg,
    required this.successBg,
    required this.warningFg,
    required this.warningBg,
    required this.errorFg,
    required this.errorBg,
    required this.disabledContainer,
    required this.disabledContent,
  });

  /// Light-theme canonical instance wired to [SaTokens] constants.
  static const SalesAssociateTokens light = SalesAssociateTokens(
    primary: SaTokens.primary,
    primaryPressed: SaTokens.primaryPressed,
    primarySubtle: SaTokens.primarySubtle,
    pageBackground: SaTokens.pageBackground,
    surface: SaTokens.surface,
    textPrimary: SaTokens.textPrimary,
    textSecondary: SaTokens.textSecondary,
    divider: SaTokens.divider,
    inputBorder: SaTokens.inputBorder,
    successFg: SaTokens.successFg,
    successBg: SaTokens.successBg,
    warningFg: SaTokens.warningFg,
    warningBg: SaTokens.warningBg,
    errorFg: SaTokens.errorFg,
    errorBg: SaTokens.errorBg,
    disabledContainer: SaTokens.disabledContainer,
    disabledContent: SaTokens.disabledContent,
  );

  /// Dark-theme canonical instance wired to [SaTokens] dark constants.
  static const SalesAssociateTokens dark = SalesAssociateTokens(
    primary: SaTokens.darkPrimary,
    primaryPressed: SaTokens.darkPrimaryPressed,
    primarySubtle: SaTokens.darkPrimarySubtle,
    pageBackground: SaTokens.darkPageBackground,
    surface: SaTokens.darkSurface,
    textPrimary: SaTokens.darkTextPrimary,
    textSecondary: SaTokens.darkTextSecondary,
    divider: SaTokens.darkDivider,
    inputBorder: SaTokens.darkInputBorder,
    successFg: SaTokens.darkSuccessFg,
    successBg: SaTokens.darkSuccessBg,
    warningFg: SaTokens.darkWarningFg,
    warningBg: SaTokens.darkWarningBg,
    errorFg: SaTokens.darkErrorFg,
    errorBg: SaTokens.darkErrorBg,
    disabledContainer: SaTokens.darkDisabledContainer,
    disabledContent: SaTokens.darkDisabledContent,
  );

  final Color primary;
  final Color primaryPressed;
  final Color primarySubtle;
  final Color pageBackground;
  final Color surface;
  final Color textPrimary;
  final Color textSecondary;
  final Color divider;
  final Color inputBorder;
  final Color successFg;
  final Color successBg;
  final Color warningFg;
  final Color warningBg;
  final Color errorFg;
  final Color errorBg;
  final Color disabledContainer;
  final Color disabledContent;

  @override
  SalesAssociateTokens copyWith({
    Color? primary,
    Color? primaryPressed,
    Color? primarySubtle,
    Color? pageBackground,
    Color? surface,
    Color? textPrimary,
    Color? textSecondary,
    Color? divider,
    Color? inputBorder,
    Color? successFg,
    Color? successBg,
    Color? warningFg,
    Color? warningBg,
    Color? errorFg,
    Color? errorBg,
    Color? disabledContainer,
    Color? disabledContent,
  }) {
    return SalesAssociateTokens(
      primary: primary ?? this.primary,
      primaryPressed: primaryPressed ?? this.primaryPressed,
      primarySubtle: primarySubtle ?? this.primarySubtle,
      pageBackground: pageBackground ?? this.pageBackground,
      surface: surface ?? this.surface,
      textPrimary: textPrimary ?? this.textPrimary,
      textSecondary: textSecondary ?? this.textSecondary,
      divider: divider ?? this.divider,
      inputBorder: inputBorder ?? this.inputBorder,
      successFg: successFg ?? this.successFg,
      successBg: successBg ?? this.successBg,
      warningFg: warningFg ?? this.warningFg,
      warningBg: warningBg ?? this.warningBg,
      errorFg: errorFg ?? this.errorFg,
      errorBg: errorBg ?? this.errorBg,
      disabledContainer: disabledContainer ?? this.disabledContainer,
      disabledContent: disabledContent ?? this.disabledContent,
    );
  }

  @override
  SalesAssociateTokens lerp(SalesAssociateTokens? other, double t) {
    if (other == null) return this;
    return SalesAssociateTokens(
      primary: Color.lerp(primary, other.primary, t)!,
      primaryPressed: Color.lerp(primaryPressed, other.primaryPressed, t)!,
      primarySubtle: Color.lerp(primarySubtle, other.primarySubtle, t)!,
      pageBackground: Color.lerp(pageBackground, other.pageBackground, t)!,
      surface: Color.lerp(surface, other.surface, t)!,
      textPrimary: Color.lerp(textPrimary, other.textPrimary, t)!,
      textSecondary: Color.lerp(textSecondary, other.textSecondary, t)!,
      divider: Color.lerp(divider, other.divider, t)!,
      inputBorder: Color.lerp(inputBorder, other.inputBorder, t)!,
      successFg: Color.lerp(successFg, other.successFg, t)!,
      successBg: Color.lerp(successBg, other.successBg, t)!,
      warningFg: Color.lerp(warningFg, other.warningFg, t)!,
      warningBg: Color.lerp(warningBg, other.warningBg, t)!,
      errorFg: Color.lerp(errorFg, other.errorFg, t)!,
      errorBg: Color.lerp(errorBg, other.errorBg, t)!,
      disabledContainer:
          Color.lerp(disabledContainer, other.disabledContainer, t)!,
      disabledContent: Color.lerp(disabledContent, other.disabledContent, t)!,
    );
  }
}

/// Extension on [BuildContext] for ergonomic access to Sales Associate design tokens.
extension SalesAssociateThemeContext on BuildContext {
  /// Access active [SalesAssociateTokens], dynamically resolving between light and dark
  /// based on the ambient [ThemeData.brightness].
  SalesAssociateTokens get saTokens {
    final ext = Theme.of(this).extension<SalesAssociateTokens>();
    if (ext != null) return ext;
    return Theme.of(this).brightness == Brightness.dark
        ? SalesAssociateTokens.dark
        : SalesAssociateTokens.light;
  }
}

