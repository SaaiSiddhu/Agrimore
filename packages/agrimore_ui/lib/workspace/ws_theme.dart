// ignore_for_file: public_member_api_docs

import 'package:flutter/material.dart';

import '../themes/sales_associate_theme_extension.dart';
import 'ws_foundation.dart';
import 'ws_tokens.dart';

/// Builds the AgriMore Workspace [ThemeData] for a brand and brightness.
///
/// Mirrors the structure of `SalesAssociateTheme` (flat bordered cards,
/// 52 px controls, 12/16/24 radii, the six-level type scale) and adds the
/// component themes the seller experience needs. All values come from
/// [WorkspaceTokens] and the `Ws*` foundation classes — no literals.
///
/// `SalesAssociateTheme` is intentionally left as it is: the Sales
/// Associate app keeps its exact appearance, and screens can adopt
/// `context.ws` because its theme also carries [WorkspaceTokens].
abstract final class WorkspaceTheme {
  WorkspaceTheme._();

  static ThemeData build(WorkspaceBrand brand, Brightness brightness) {
    final t = WorkspaceTokens.forBrand(brand, brightness);
    final textTheme = _textTheme(t);

    final colorScheme = ColorScheme(
      brightness: brightness,
      primary: t.primary,
      onPrimary: t.onPrimary,
      primaryContainer: t.primarySubtle,
      onPrimaryContainer: t.primary,
      secondary: t.primary,
      onSecondary: t.onPrimary,
      secondaryContainer: t.primaryMuted,
      onSecondaryContainer: t.textPrimary,
      tertiary: t.infoFg,
      onTertiary: t.surface,
      error: t.errorFg,
      onError: t.surface,
      errorContainer: t.errorBg,
      onErrorContainer: t.errorFg,
      surface: t.surface,
      onSurface: t.textPrimary,
      onSurfaceVariant: t.textSecondary,
      surfaceContainerLowest: t.surface,
      surfaceContainerLow: t.pageBackground,
      surfaceContainer: t.surfaceSunken,
      surfaceContainerHigh: t.surfaceElevated,
      surfaceContainerHighest: t.surfaceElevated,
      outline: t.inputBorder,
      outlineVariant: t.divider,
      scrim: t.scrim,
      shadow: t.scrim,
      inverseSurface: t.textPrimary,
      onInverseSurface: t.surface,
      inversePrimary: t.primaryMuted,
    );

    final inputRadius = BorderRadius.circular(WsRadius.input);
    final labelStyle = textTheme.labelLarge!;
    final buttonTextStyle = TextStyle(
      fontFamily: WsType.fontFamily,
      fontSize: WsType.fsBody,
      fontWeight: WsType.semibold,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      fontFamily: WsType.fontFamily,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: t.pageBackground,
      canvasColor: t.pageBackground,
      textTheme: textTheme,
      primaryColor: t.primary,
      dividerColor: t.divider,
      splashFactory: InkSparkle.splashFactory,
      visualDensity: VisualDensity.standard,
      materialTapTargetSize: MaterialTapTargetSize.padded,
      cardTheme: CardThemeData(
        color: t.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(WsRadius.card),
          side: BorderSide(color: t.divider, width: WsSize.hairline),
        ),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: t.surface,
        foregroundColor: t.textPrimary,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: textTheme.headlineMedium,
        iconTheme: IconThemeData(color: t.textPrimary, size: WsIconSize.nav),
        actionsIconTheme: IconThemeData(color: t.textPrimary, size: WsIconSize.nav),
      ),
      iconTheme: IconThemeData(color: t.textPrimary, size: WsIconSize.nav),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          minimumSize: const Size.fromHeight(WsSize.controlHeight),
          backgroundColor: t.primary,
          foregroundColor: t.onPrimary,
          disabledBackgroundColor: t.disabledContainer,
          disabledForegroundColor: t.disabledContent,
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: inputRadius),
          textStyle: buttonTextStyle,
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size.fromHeight(WsSize.controlHeight),
          backgroundColor: t.primary,
          foregroundColor: t.onPrimary,
          disabledBackgroundColor: t.disabledContainer,
          disabledForegroundColor: t.disabledContent,
          shape: RoundedRectangleBorder(borderRadius: inputRadius),
          textStyle: buttonTextStyle,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size.fromHeight(WsSize.controlHeight),
          foregroundColor: t.primary,
          disabledForegroundColor: t.disabledContent,
          side: BorderSide(color: t.primary, width: WsSize.outline),
          shape: RoundedRectangleBorder(borderRadius: inputRadius),
          textStyle: buttonTextStyle,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          minimumSize: const Size(WsSize.minTouchTarget, WsSize.minTouchTarget),
          foregroundColor: t.primary,
          disabledForegroundColor: t.disabledContent,
          shape: RoundedRectangleBorder(borderRadius: inputRadius),
          textStyle: labelStyle.copyWith(fontWeight: WsType.semibold),
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          minimumSize: const Size(WsSize.minTouchTarget, WsSize.minTouchTarget),
          foregroundColor: t.textPrimary,
          iconSize: WsIconSize.nav,
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: t.primary,
        foregroundColor: t.onPrimary,
        elevation: 0,
        focusElevation: 0,
        hoverElevation: 0,
        highlightElevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(WsRadius.card)),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: t.surface,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: WsSpace.s16,
          vertical: WsSpace.s12 + WsSpace.s2,
        ),
        hintStyle: textTheme.bodyLarge!.copyWith(color: t.textSecondary),
        labelStyle: labelStyle.copyWith(color: t.textSecondary),
        floatingLabelStyle: labelStyle.copyWith(color: t.primary),
        helperStyle: textTheme.bodySmall,
        errorStyle: textTheme.bodySmall!.copyWith(color: t.errorFg),
        prefixIconColor: t.textSecondary,
        suffixIconColor: t.textSecondary,
        border: OutlineInputBorder(borderRadius: inputRadius, borderSide: BorderSide(color: t.divider)),
        enabledBorder: OutlineInputBorder(borderRadius: inputRadius, borderSide: BorderSide(color: t.divider)),
        disabledBorder: OutlineInputBorder(
          borderRadius: inputRadius,
          borderSide: BorderSide(color: t.disabledContainer),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: inputRadius,
          borderSide: BorderSide(color: t.primary, width: WsSize.focusRing),
        ),
        errorBorder: OutlineInputBorder(borderRadius: inputRadius, borderSide: BorderSide(color: t.errorFg)),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: inputRadius,
          borderSide: BorderSide(color: t.errorFg, width: WsSize.focusRing),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: t.surface,
        selectedColor: t.primaryMuted,
        disabledColor: t.disabledContainer,
        side: BorderSide(color: t.divider),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(WsRadius.pill)),
        labelStyle: labelStyle.copyWith(color: t.textPrimary),
        secondaryLabelStyle: labelStyle.copyWith(color: t.primary),
        padding: const EdgeInsets.symmetric(horizontal: WsSpace.s12),
        checkmarkColor: t.primary,
        showCheckmark: false,
      ),
      navigationBarTheme: NavigationBarThemeData(
        height: WsSize.bottomBarHeight,
        backgroundColor: t.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        indicatorColor: t.primaryMuted,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        iconTheme: WidgetStateProperty.resolveWith(
          (states) => IconThemeData(
            size: WsIconSize.nav,
            color: states.contains(WidgetState.selected) ? t.primary : t.textSecondary,
          ),
        ),
        labelTextStyle: WidgetStateProperty.resolveWith(
          (states) => textTheme.bodySmall!.copyWith(
            fontWeight: states.contains(WidgetState.selected) ? WsType.semibold : WsType.medium,
            color: states.contains(WidgetState.selected) ? t.primary : t.textSecondary,
          ),
        ),
      ),
      navigationRailTheme: NavigationRailThemeData(
        backgroundColor: t.surface,
        minWidth: WsSize.railWidth,
        minExtendedWidth: WsSize.railWidthExpanded,
        indicatorColor: t.primaryMuted,
        selectedIconTheme: IconThemeData(color: t.primary, size: WsIconSize.nav),
        unselectedIconTheme: IconThemeData(color: t.textSecondary, size: WsIconSize.nav),
        selectedLabelTextStyle: textTheme.bodySmall!.copyWith(color: t.primary, fontWeight: WsType.semibold),
        unselectedLabelTextStyle: textTheme.bodySmall!.copyWith(color: t.textSecondary),
      ),
      tabBarTheme: TabBarThemeData(
        labelColor: t.primary,
        unselectedLabelColor: t.textSecondary,
        indicatorColor: t.primary,
        dividerColor: t.divider,
        labelStyle: labelStyle.copyWith(fontWeight: WsType.semibold),
        unselectedLabelStyle: labelStyle,
        indicatorSize: TabBarIndicatorSize.label,
        tabAlignment: TabAlignment.start,
      ),
      listTileTheme: ListTileThemeData(
        iconColor: t.textSecondary,
        textColor: t.textPrimary,
        titleTextStyle: textTheme.bodyLarge,
        subtitleTextStyle: textTheme.bodySmall,
        contentPadding: const EdgeInsets.symmetric(horizontal: WsSpace.s16),
        minVerticalPadding: WsSpace.s12,
        shape: RoundedRectangleBorder(borderRadius: inputRadius),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected) ? t.onPrimary : t.surface,
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected) ? t.primary : t.disabledContainer,
        ),
        trackOutlineColor: WidgetStateProperty.all(Colors.transparent),
      ),
      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected) ? t.primary : Colors.transparent,
        ),
        checkColor: WidgetStateProperty.all(t.onPrimary),
        side: BorderSide(color: t.inputBorder, width: WsSize.focusRing),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(WsSpace.s4)),
      ),
      radioTheme: RadioThemeData(
        fillColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected) ? t.primary : t.inputBorder,
        ),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: t.primary,
        linearTrackColor: t.primaryMuted,
        circularTrackColor: t.primaryMuted,
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: t.textPrimary,
        contentTextStyle: textTheme.bodyMedium!.copyWith(color: t.surface),
        actionTextColor: t.isDark ? t.primarySubtle : t.primaryMuted,
        behavior: SnackBarBehavior.floating,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: inputRadius),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: t.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(WsRadius.card)),
        titleTextStyle: textTheme.titleMedium,
        contentTextStyle: textTheme.bodyLarge!.copyWith(color: t.textSecondary),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: t.surface,
        surfaceTintColor: Colors.transparent,
        modalBarrierColor: t.scrim,
        elevation: 0,
        showDragHandle: true,
        dragHandleColor: t.divider,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(WsRadius.sheet)),
        ),
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: t.surfaceElevated,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        textStyle: textTheme.bodyLarge,
        shape: RoundedRectangleBorder(
          borderRadius: inputRadius,
          side: BorderSide(color: t.divider),
        ),
      ),
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(color: t.textPrimary, borderRadius: BorderRadius.circular(WsRadius.small)),
        textStyle: textTheme.bodySmall!.copyWith(color: t.surface),
      ),
      dividerTheme: DividerThemeData(color: t.divider, thickness: WsSize.hairline, space: WsSize.hairline),
      extensions: <ThemeExtension<dynamic>>[t, _saCompat(t)],
    );
  }

  /// The shared `Sa*` widgets (SaLoadingButton, SaInfoBanner) read
  /// `context.saTokens`; without this they would paint Sales Associate blue
  /// inside a seller theme. Same roles, active brand's values.
  static SalesAssociateTokens _saCompat(WorkspaceTokens t) {
    return SalesAssociateTokens(
      primary: t.primary,
      primaryPressed: t.primaryPressed,
      primarySubtle: t.primarySubtle,
      pageBackground: t.pageBackground,
      surface: t.surface,
      textPrimary: t.textPrimary,
      textSecondary: t.textSecondary,
      divider: t.divider,
      inputBorder: t.inputBorder,
      successFg: t.successFg,
      successBg: t.successBg,
      warningFg: t.warningFg,
      warningBg: t.warningBg,
      errorFg: t.errorFg,
      errorBg: t.errorBg,
      disabledContainer: t.disabledContainer,
      disabledContent: t.disabledContent,
    );
  }

  static TextTheme _textTheme(WorkspaceTokens t) {
    TextStyle style(double size, double lineHeight, FontWeight weight, Color color, {double? tracking}) {
      return TextStyle(
        fontFamily: WsType.fontFamily,
        fontSize: size,
        height: lineHeight / size,
        fontWeight: weight,
        color: color,
        letterSpacing: tracking,
      );
    }

    return TextTheme(
      // Money and balances (32 / 40). Tabular figures: see WsType.tabularFigures.
      displayLarge: style(WsType.fsDisplayAmount, WsType.lhDisplayAmount, WsType.semibold, t.textPrimary,
          tracking: WsType.trackingDisplay),
      // Single hero KPI on desktop (40 / 48).
      displayMedium: style(WsType.fsDisplayHero, WsType.lhDisplayHero, WsType.semibold, t.textPrimary,
          tracking: WsType.trackingDisplay),
      // Screen title (24 / 32).
      headlineMedium: style(WsType.fsScreenTitle, WsType.lhScreenTitle, WsType.semibold, t.textPrimary,
          tracking: WsType.trackingTitle),
      // Section heading (18 / 26).
      titleMedium: style(WsType.fsSectionHeading, WsType.lhSectionHeading, WsType.semibold, t.textPrimary),
      // List-item title / order ID (16 / 24).
      titleSmall: style(WsType.fsTitleSmall, WsType.lhTitleSmall, WsType.semibold, t.textPrimary),
      // Body (16 / 24).
      bodyLarge: style(WsType.fsBody, WsType.lhBody, WsType.regular, t.textPrimary),
      // Label / button / field label (14 / 20).
      labelLarge: style(WsType.fsLabel, WsType.lhLabel, WsType.medium, t.textPrimary),
      bodyMedium: style(WsType.fsLabel, WsType.lhLabel, WsType.medium, t.textSecondary),
      // Caption (12 / 18).
      bodySmall: style(WsType.fsCaption, WsType.lhCaption, WsType.regular, t.textSecondary),
      labelMedium: style(WsType.fsCaption, WsType.lhCaption, WsType.medium, t.textSecondary),
      // Micro overline / axis / badge text (11 / 16); uppercase is applied by the widget.
      labelSmall: style(WsType.fsMicro, WsType.lhMicro, WsType.semibold, t.textSecondary,
          tracking: WsType.trackingMicro),
    );
  }
}
