import 'package:flutter/cupertino.dart' show CupertinoPageTransitionsBuilder;
import 'package:flutter/material.dart';

import '../tokens/seller_colors.dart';
import '../tokens/seller_tokens.dart';
import '../tokens/seller_typography.dart';
import 'seller_focus.dart';

/// The seller app's theme — its own design system (decisions D0).
///
/// Every Material control that can take keyboard focus shows it with the
/// single-border rule (seller_focus.dart); Material's focus overlays and halos
/// are switched off. Controls are 48 dp, radius 8; cards radius 12; sheets 20.
abstract final class SellerTheme {
  static ThemeData get light => build(SellerColors.light);
  static ThemeData get dark => build(SellerColors.dark);

  static ThemeData build(SellerColors c) {
    final text = SellerType.textTheme(c);
    final dark = c.isDark;
    final controlRadius = BorderRadius.circular(SellerRadius.control);
    final controlShape = RoundedRectangleBorder(borderRadius: controlRadius);
    final buttonText = text.titleSmall!.copyWith(color: null);

    final scheme = ColorScheme(
      brightness: c.brightness,
      primary: c.primary,
      onPrimary: c.onPrimary,
      primaryContainer: c.primaryContainer,
      onPrimaryContainer: c.onPrimaryContainer,
      secondary: c.primary,
      onSecondary: c.onPrimary,
      secondaryContainer: c.primaryContainer,
      onSecondaryContainer: c.onPrimaryContainer,
      tertiary: c.info,
      onTertiary: c.surface,
      error: c.danger,
      onError: c.onDangerFill,
      errorContainer: c.dangerContainer,
      onErrorContainer: c.danger,
      surface: c.surface,
      onSurface: c.textPrimary,
      onSurfaceVariant: c.textSecondary,
      surfaceContainerLowest: c.surface,
      surfaceContainerLow: c.canvas,
      surfaceContainer: c.surface,
      surfaceContainerHigh: c.raised,
      surfaceContainerHighest: c.sunken,
      surfaceDim: c.canvas,
      surfaceBright: c.raised,
      outline: c.controlBorder,
      outlineVariant: c.border,
      scrim: c.scrim,
      shadow: c.scrim,
      inverseSurface: c.toast,
      onInverseSurface: c.onToast,
      inversePrimary: c.primaryContainer,
    );

    // ── Focus-aware button styling ─────────────────────────────────────────
    WidgetStateProperty<Color?> overlay(Color on) => WidgetStateProperty.resolveWith((s) {
          if (s.contains(WidgetState.pressed)) return on.withValues(alpha: SellerOpacity.pressed);
          if (s.contains(WidgetState.hovered)) return on.withValues(alpha: SellerOpacity.hover);
          return Colors.transparent; // focus is shown by the outline, never a tint
        });

    WidgetStateProperty<BorderSide?> filledSide(Color rest, Color focus) => WidgetStateProperty.resolveWith((s) {
          if (s.contains(WidgetState.disabled)) return BorderSide.none;
          if (sellerShowsFocus(s)) {
            return BorderSide(color: focus, width: SellerSize.focusStrong, strokeAlign: BorderSide.strokeAlignInside);
          }
          return BorderSide(color: rest, width: SellerSize.hairline, strokeAlign: BorderSide.strokeAlignInside);
        });

    final filledStyle = ButtonStyle(
      minimumSize: const WidgetStatePropertyAll(Size(SellerSize.touchTarget, SellerSize.control)),
      padding: const WidgetStatePropertyAll(EdgeInsets.symmetric(horizontal: SellerSpace.s20, vertical: SellerSpace.s12)),
      shape: WidgetStatePropertyAll(controlShape),
      textStyle: WidgetStatePropertyAll(buttonText),
      elevation: const WidgetStatePropertyAll(0),
      backgroundColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.disabled)
          ? c.disabledFill
          : s.contains(WidgetState.pressed)
              ? c.primaryStrong
              : c.primary),
      foregroundColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.disabled) ? c.disabledText : c.onPrimary),
      overlayColor: overlay(c.onPrimary),
      side: filledSide(c.primaryStrong, c.focusOnFill),
      tapTargetSize: MaterialTapTargetSize.padded,
    );

    final outlinedStyle = ButtonStyle(
      minimumSize: const WidgetStatePropertyAll(Size(SellerSize.touchTarget, SellerSize.control)),
      padding: const WidgetStatePropertyAll(EdgeInsets.symmetric(horizontal: SellerSpace.s20, vertical: SellerSpace.s12)),
      shape: WidgetStatePropertyAll(controlShape),
      textStyle: WidgetStatePropertyAll(buttonText),
      backgroundColor: const WidgetStatePropertyAll(Colors.transparent),
      foregroundColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.disabled) ? c.disabledText : c.primary),
      overlayColor: overlay(c.primary),
      side: WidgetStateProperty.resolveWith((s) {
        if (s.contains(WidgetState.disabled)) {
          return BorderSide(color: c.disabledFill, width: SellerSize.outline, strokeAlign: BorderSide.strokeAlignInside);
        }
        if (sellerShowsFocus(s)) {
          return BorderSide(color: c.focus, width: SellerSize.focusStrong, strokeAlign: BorderSide.strokeAlignInside);
        }
        return BorderSide(color: c.primary, width: SellerSize.outline, strokeAlign: BorderSide.strokeAlignInside);
      }),
      tapTargetSize: MaterialTapTargetSize.padded,
    );

    // Text buttons and icon buttons have no visible outline at rest; their own
    // shape boundary is drawn on focus (the "existing" outline of the control).
    WidgetStateProperty<BorderSide?> ghostSide() => WidgetStateProperty.resolveWith((s) => sellerShowsFocus(s)
        ? BorderSide(color: c.focus, width: SellerSize.focus, strokeAlign: BorderSide.strokeAlignInside)
        : BorderSide.none);

    final textStyle = ButtonStyle(
      minimumSize: const WidgetStatePropertyAll(Size(SellerSize.touchTarget, SellerSize.touchTarget)),
      padding: const WidgetStatePropertyAll(EdgeInsets.symmetric(horizontal: SellerSpace.s12, vertical: SellerSpace.s8)),
      shape: WidgetStatePropertyAll(controlShape),
      textStyle: WidgetStatePropertyAll(text.labelLarge),
      foregroundColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.disabled) ? c.disabledText : c.primary),
      overlayColor: overlay(c.primary),
      side: ghostSide(),
      tapTargetSize: MaterialTapTargetSize.padded,
    );

    final iconStyle = ButtonStyle(
      minimumSize: const WidgetStatePropertyAll(Size(SellerSize.touchTarget, SellerSize.touchTarget)),
      iconSize: const WidgetStatePropertyAll(SellerIconSize.lg),
      shape: WidgetStatePropertyAll(controlShape),
      foregroundColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.disabled) ? c.disabledText : c.textPrimary),
      overlayColor: overlay(c.textPrimary),
      side: ghostSide(),
      tapTargetSize: MaterialTapTargetSize.padded,
    );

    // ── Fields ─────────────────────────────────────────────────────────────
    OutlineInputBorder field(Color color, double width) => OutlineInputBorder(
          borderRadius: controlRadius,
          borderSide: BorderSide(color: color, width: width),
        );

    final inputs = InputDecorationThemeData(
      filled: true,
      fillColor: c.surface,
      isDense: false,
      contentPadding: const EdgeInsets.symmetric(horizontal: SellerSpace.s16, vertical: SellerSpace.s12),
      hintStyle: text.bodyLarge!.copyWith(color: c.textTertiary),
      labelStyle: text.labelLarge!.copyWith(color: c.textSecondary),
      floatingLabelStyle: text.labelLarge!.copyWith(color: c.primary),
      helperStyle: text.bodySmall,
      helperMaxLines: 3,
      errorStyle: text.bodySmall!.copyWith(color: c.danger),
      errorMaxLines: 3,
      prefixIconColor: c.textSecondary,
      suffixIconColor: c.textSecondary,
      border: field(c.controlBorder, SellerSize.hairline),
      enabledBorder: field(c.controlBorder, SellerSize.hairline),
      disabledBorder: field(c.disabledFill, SellerSize.hairline),
      focusedBorder: field(c.focus, SellerSize.focus),
      errorBorder: field(c.danger, SellerSize.hairline),
      focusedErrorBorder: field(c.danger, SellerSize.focus),
    );

    // ── Selection controls: focus = heavier outline, no halo ───────────────
    final noHalo = WidgetStateProperty.resolveWith<Color?>((s) {
      if (s.contains(WidgetState.pressed)) return c.primary.withValues(alpha: SellerOpacity.pressed);
      return Colors.transparent;
    });

    return ThemeData(
      useMaterial3: true,
      brightness: c.brightness,
      fontFamily: SellerType.fontFamily,
      colorScheme: scheme,
      textTheme: text,
      primaryTextTheme: text,
      scaffoldBackgroundColor: c.canvas,
      canvasColor: c.canvas,
      cardColor: c.surface,
      dividerColor: c.border,
      disabledColor: c.disabledText,
      hintColor: c.textTertiary,
      focusColor: Colors.transparent,
      hoverColor: c.primary.withValues(alpha: SellerOpacity.hover),
      highlightColor: Colors.transparent,
      splashColor: c.primary.withValues(alpha: SellerOpacity.pressed),
      splashFactory: InkRipple.splashFactory,
      visualDensity: VisualDensity.standard,
      materialTapTargetSize: MaterialTapTargetSize.padded,
      iconTheme: IconThemeData(color: c.textPrimary, size: SellerIconSize.lg),
      primaryIconTheme: IconThemeData(color: c.onPrimary, size: SellerIconSize.lg),
      appBarTheme: AppBarTheme(
        backgroundColor: c.canvas,
        foregroundColor: c.textPrimary,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleSpacing: SellerSpace.s4,
        titleTextStyle: text.titleLarge,
        iconTheme: IconThemeData(color: c.textPrimary, size: SellerIconSize.lg),
        actionsIconTheme: IconThemeData(color: c.textPrimary, size: SellerIconSize.lg),
      ),
      cardTheme: CardThemeData(
        color: c.surface,
        surfaceTintColor: Colors.transparent,
        shadowColor: Colors.transparent,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(SellerRadius.card),
          side: BorderSide(color: c.border, width: SellerSize.hairline),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(style: filledStyle),
      elevatedButtonTheme: ElevatedButtonThemeData(style: filledStyle),
      outlinedButtonTheme: OutlinedButtonThemeData(style: outlinedStyle),
      textButtonTheme: TextButtonThemeData(style: textStyle),
      iconButtonTheme: IconButtonThemeData(style: iconStyle),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: ButtonStyle(
          minimumSize: const WidgetStatePropertyAll(Size(SellerSize.touchTarget, SellerSize.control)),
          shape: WidgetStatePropertyAll(controlShape),
          textStyle: WidgetStatePropertyAll(text.labelLarge),
          backgroundColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? c.primary : c.surface),
          foregroundColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? c.onPrimary : c.textPrimary),
          overlayColor: overlay(c.primary),
          side: WidgetStateProperty.resolveWith((s) => sellerShowsFocus(s)
              ? BorderSide(color: c.focus, width: SellerSize.focus, strokeAlign: BorderSide.strokeAlignInside)
              : BorderSide(color: c.border, width: SellerSize.hairline, strokeAlign: BorderSide.strokeAlignInside)),
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: c.primary,
        foregroundColor: c.onPrimary,
        elevation: dark ? 0 : 2,
        focusElevation: dark ? 0 : 2,
        hoverElevation: dark ? 0 : 3,
        highlightElevation: dark ? 0 : 3,
        focusColor: Colors.transparent,
        shape: const StadiumBorder(),
      ),
      inputDecorationTheme: inputs,
      chipTheme: ChipThemeData(
        backgroundColor: c.surface,
        selectedColor: c.primaryContainer,
        disabledColor: c.disabledFill,
        side: WidgetStateBorderSide.resolveWith((s) => sellerShowsFocus(s)
            ? BorderSide(color: c.focus, width: SellerSize.focus, strokeAlign: BorderSide.strokeAlignInside)
            : BorderSide(color: s.contains(WidgetState.selected) ? c.primaryContainer : c.border, width: SellerSize.hairline)),
        shape: const StadiumBorder(),
        labelStyle: text.labelLarge,
        secondaryLabelStyle: text.labelLarge!.copyWith(color: c.onPrimaryContainer),
        padding: const EdgeInsets.symmetric(horizontal: SellerSpace.s8),
        checkmarkColor: c.onPrimaryContainer,
        showCheckmark: true,
        pressElevation: 0,
        elevation: 0,
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((s) {
          if (s.contains(WidgetState.disabled)) return c.disabledText;
          return s.contains(WidgetState.selected) ? c.onPrimary : c.controlBorder;
        }),
        trackColor: WidgetStateProperty.resolveWith((s) {
          if (s.contains(WidgetState.disabled)) return c.disabledFill;
          return s.contains(WidgetState.selected) ? c.primary : c.surface;
        }),
        trackOutlineColor: WidgetStateProperty.resolveWith((s) {
          if (sellerShowsFocus(s)) return s.contains(WidgetState.selected) ? c.focusOnFill : c.focus;
          if (s.contains(WidgetState.selected)) return Colors.transparent;
          return c.controlBorder;
        }),
        trackOutlineWidth: WidgetStateProperty.resolveWith((s) => sellerShowsFocus(s) ? SellerSize.focusStrong : SellerSize.focus),
        overlayColor: noHalo,
      ),
      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith((s) {
          if (s.contains(WidgetState.disabled)) return s.contains(WidgetState.selected) ? c.disabledText : Colors.transparent;
          return s.contains(WidgetState.selected) ? c.primary : Colors.transparent;
        }),
        checkColor: WidgetStatePropertyAll(c.onPrimary),
        side: WidgetStateBorderSide.resolveWith((s) {
          if (sellerShowsFocus(s)) {
            return BorderSide(
              color: s.contains(WidgetState.selected) ? c.focusOnFill : c.focus,
              width: SellerSize.focusStrong,
            );
          }
          if (s.contains(WidgetState.selected)) return BorderSide(color: c.primary, width: SellerSize.focus);
          return BorderSide(color: s.contains(WidgetState.disabled) ? c.disabledText : c.controlBorder, width: SellerSize.focus);
        }),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(SellerRadius.xs)),
        overlayColor: noHalo,
        materialTapTargetSize: MaterialTapTargetSize.padded,
      ),
      radioTheme: RadioThemeData(
        fillColor: WidgetStateProperty.resolveWith((s) {
          if (s.contains(WidgetState.disabled)) return c.disabledText;
          return s.contains(WidgetState.selected) ? c.primary : c.controlBorder;
        }),
        overlayColor: noHalo,
        materialTapTargetSize: MaterialTapTargetSize.padded,
      ),
      sliderTheme: SliderThemeData(
        activeTrackColor: c.primary,
        inactiveTrackColor: c.primaryContainer,
        thumbColor: c.primary,
        overlayColor: Colors.transparent,
        valueIndicatorColor: c.primaryStrong,
        valueIndicatorTextStyle: text.labelLarge!.copyWith(color: c.onPrimary),
        trackHeight: SellerSpace.s6,
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: c.primary,
        linearTrackColor: c.primaryContainer,
        circularTrackColor: Colors.transparent,
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: dark ? c.raised : c.surface,
        surfaceTintColor: Colors.transparent,
        modalBackgroundColor: dark ? c.raised : c.surface,
        modalBarrierColor: c.scrim,
        elevation: 0,
        modalElevation: 0,
        showDragHandle: true,
        dragHandleColor: c.controlBorder,
        dragHandleSize: const Size(SellerSize.handleWidth, SellerSize.handle),
        constraints: const BoxConstraints(maxWidth: SellerSize.formMaxWidth),
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(SellerRadius.sheet))),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: dark ? c.raised : c.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        barrierColor: c.scrim,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(SellerRadius.dialog)),
        titleTextStyle: text.titleLarge,
        contentTextStyle: text.bodyLarge!.copyWith(color: c.textSecondary),
        insetPadding: const EdgeInsets.symmetric(horizontal: SellerSpace.s24, vertical: SellerSpace.s24),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: c.toast,
        contentTextStyle: text.bodyLarge!.copyWith(color: c.onToast),
        actionTextColor: c.toastSuccess,
        closeIconColor: c.onToast,
        behavior: SnackBarBehavior.floating,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: controlRadius,
          side: dark ? BorderSide(color: c.border) : BorderSide.none,
        ),
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: c.raised,
        surfaceTintColor: Colors.transparent,
        elevation: dark ? 0 : 3,
        shadowColor: c.scrim,
        textStyle: text.bodyLarge,
        labelTextStyle: WidgetStatePropertyAll(text.bodyLarge),
        shape: RoundedRectangleBorder(borderRadius: controlRadius, side: BorderSide(color: c.border)),
      ),
      menuTheme: MenuThemeData(
        style: MenuStyle(
          backgroundColor: WidgetStatePropertyAll(c.raised),
          surfaceTintColor: const WidgetStatePropertyAll(Colors.transparent),
          shape: WidgetStatePropertyAll(RoundedRectangleBorder(borderRadius: controlRadius, side: BorderSide(color: c.border))),
        ),
      ),
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(color: c.toast, borderRadius: BorderRadius.circular(SellerRadius.control)),
        textStyle: text.bodySmall!.copyWith(color: c.onToast),
      ),
      dividerTheme: DividerThemeData(color: c.border, thickness: SellerSize.hairline, space: SellerSize.hairline),
      listTileTheme: ListTileThemeData(
        iconColor: c.textSecondary,
        textColor: c.textPrimary,
        titleTextStyle: text.bodyLarge,
        subtitleTextStyle: text.bodyMedium,
        contentPadding: const EdgeInsets.symmetric(horizontal: SellerSpace.s16),
        minVerticalPadding: SellerSpace.s12,
        shape: controlShape,
      ),
      badgeTheme: BadgeThemeData(
        backgroundColor: c.primaryStrong,
        textColor: c.onPrimary,
        textStyle: text.labelSmall,
      ),
      textSelectionTheme: TextSelectionThemeData(
        cursorColor: c.primary,
        selectionColor: c.primary.withValues(alpha: SellerOpacity.selection),
        selectionHandleColor: c.primary,
      ),
      datePickerTheme: DatePickerThemeData(
        backgroundColor: dark ? c.raised : c.surface,
        surfaceTintColor: Colors.transparent,
        headerBackgroundColor: dark ? c.raised : c.surface,
        headerForegroundColor: c.textPrimary,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(SellerRadius.dialog)),
        dayForegroundColor: WidgetStateProperty.resolveWith((s) {
          if (s.contains(WidgetState.selected)) return c.onPrimary;
          if (s.contains(WidgetState.disabled)) return c.disabledText;
          return c.textPrimary;
        }),
        dayBackgroundColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? c.primary : null),
        todayForegroundColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? c.onPrimary : c.primary),
        todayBorder: BorderSide(color: c.primary),
        dayOverlayColor: noHalo,
        cancelButtonStyle: textStyle,
        confirmButtonStyle: textStyle,
      ),
      timePickerTheme: TimePickerThemeData(
        backgroundColor: dark ? c.raised : c.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(SellerRadius.dialog)),
        dialBackgroundColor: c.sunken,
        hourMinuteColor: WidgetStateColor.resolveWith((s) => s.contains(WidgetState.selected) ? c.primaryContainer : c.sunken),
        hourMinuteTextColor: WidgetStateColor.resolveWith((s) => s.contains(WidgetState.selected) ? c.onPrimaryContainer : c.textPrimary),
        dayPeriodColor: WidgetStateColor.resolveWith((s) => s.contains(WidgetState.selected) ? c.primaryContainer : Colors.transparent),
        dayPeriodTextColor: WidgetStateColor.resolveWith((s) => s.contains(WidgetState.selected) ? c.onPrimaryContainer : c.textPrimary),
        dayPeriodBorderSide: BorderSide(color: c.controlBorder),
        cancelButtonStyle: textStyle,
        confirmButtonStyle: textStyle,
      ),
      scrollbarTheme: ScrollbarThemeData(thumbColor: WidgetStatePropertyAll(c.controlBorder)),
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: <TargetPlatform, PageTransitionsBuilder>{
          TargetPlatform.android: SellerReducedMotionTransitions(PredictiveBackPageTransitionsBuilder()),
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
          TargetPlatform.macOS: CupertinoPageTransitionsBuilder(),
          TargetPlatform.linux: SellerReducedMotionTransitions(FadeForwardsPageTransitionsBuilder()),
          TargetPlatform.windows: SellerReducedMotionTransitions(FadeForwardsPageTransitionsBuilder()),
          TargetPlatform.fuchsia: SellerReducedMotionTransitions(FadeForwardsPageTransitionsBuilder()),
        },
      ),
      extensions: <ThemeExtension<dynamic>>[c],
    );
  }
}

/// Page transitions that step aside when the device asks for reduced motion
/// (board 24-05: "avoid sliding and zooming transitions"). iOS keeps its native
/// Cupertino route (swipe-back gesture); the system handles its motion there.
class SellerReducedMotionTransitions extends PageTransitionsBuilder {
  const SellerReducedMotionTransitions(this.inner);
  final PageTransitionsBuilder inner;

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    if (MediaQuery.maybeDisableAnimationsOf(context) ?? false) return child;
    return inner.buildTransitions(route, context, animation, secondaryAnimation, child);
  }
}
