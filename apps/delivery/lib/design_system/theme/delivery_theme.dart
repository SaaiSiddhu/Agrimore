import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../tokens/delivery_colors.dart';
import '../tokens/delivery_tokens.dart';
import '../tokens/delivery_typography.dart';
import 'delivery_focus.dart';

/// Persists and notifies the rider's appearance choice (`System`, `Light`, `Dark`)
/// (Phases 03, 14, 31).
class DeliveryAppearanceController extends ChangeNotifier {
  DeliveryAppearanceController([this._mode = ThemeMode.system]);

  static const String prefKey = 'delivery.appearance';

  ThemeMode _mode;
  ThemeMode get mode => _mode;

  Future<void> load([SharedPreferences? prefs]) async {
    final p = prefs ?? await SharedPreferences.getInstance();
    final raw = p.getString(prefKey);
    final next = switch (raw) {
      'light' => ThemeMode.light,
      'dark' => ThemeMode.dark,
      _ => ThemeMode.system,
    };
    if (next != _mode) {
      _mode = next;
      notifyListeners();
    }
  }

  Future<void> setMode(ThemeMode next, [SharedPreferences? prefs]) async {
    if (_mode == next) return;
    _mode = next;
    notifyListeners();
    final p = prefs ?? await SharedPreferences.getInstance();
    await p.setString(
      prefKey,
      switch (next) {
        ThemeMode.light => 'light',
        ThemeMode.dark => 'dark',
        ThemeMode.system => 'system',
      },
    );
  }
}

/// Inherited scope exposing [DeliveryAppearanceController] down the widget tree.
class DeliveryAppearanceScope
    extends InheritedNotifier<DeliveryAppearanceController> {
  const DeliveryAppearanceScope({
    super.key,
    required DeliveryAppearanceController controller,
    required super.child,
  }) : super(notifier: controller);

  static DeliveryAppearanceController? maybeOf(BuildContext context) =>
      context
          .dependOnInheritedWidgetOfExactType<DeliveryAppearanceScope>()
          ?.notifier;

  static DeliveryAppearanceController of(BuildContext context) =>
      maybeOf(context) ?? DeliveryAppearanceController();
}

/// Builds the light and dark [ThemeData] for the AgriMore Delivery Partner app
/// (Phases 01–14, 32).
abstract final class DeliveryTheme {
  static ThemeData light() => of(Brightness.light);
  static ThemeData dark() => of(Brightness.dark);

  static ThemeData of(Brightness brightness) {
    final c = brightness == Brightness.dark ? DeliveryColors.dark : DeliveryColors.light;
    final text = DeliveryType.textTheme(c);

    final scheme = ColorScheme(
      brightness: brightness,
      primary: c.primary,
      onPrimary: c.onPrimary,
      primaryContainer: c.primaryContainer,
      onPrimaryContainer: c.onPrimaryContainer,
      secondary: c.amber,
      onSecondary: c.onPrimary,
      secondaryContainer: c.primaryContainer,
      onSecondaryContainer: c.onPrimaryContainer,
      tertiary: c.infoColor,
      onTertiary: c.onPrimary,
      tertiaryContainer: c.infoContainer,
      onTertiaryContainer: c.infoColor,
      error: c.dangerColor,
      onError: c.onDangerFill,
      errorContainer: c.dangerContainer,
      onErrorContainer: c.dangerColor,
      surface: c.surface,
      onSurface: c.textPrimary,
      onSurfaceVariant: c.textSecondary,
      outline: c.controlBorder,
      outlineVariant: c.border,
      shadow: Colors.black,
      scrim: c.scrim,
      inverseSurface: c.toast,
      onInverseSurface: c.onToast,
      inversePrimary: c.amber,
    );

    final controlRadius = BorderRadius.circular(DeliveryRadius.control);
    OutlineInputBorder inputBorder(Color color, double width) => OutlineInputBorder(
          borderRadius: controlRadius,
          borderSide: BorderSide(color: color, width: width),
        );

    final overlayStyle = SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: c.isDark ? Brightness.light : Brightness.dark,
      statusBarBrightness: c.isDark ? Brightness.dark : Brightness.light,
      systemNavigationBarColor: c.surface,
      systemNavigationBarIconBrightness: c.isDark ? Brightness.light : Brightness.dark,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      scaffoldBackgroundColor: c.background,
      canvasColor: c.surface,
      dividerColor: c.border,
      fontFamily: DeliveryType.fontFamily,
      textTheme: text,
      extensions: [c],
      appBarTheme: AppBarTheme(
        backgroundColor: c.background,
        foregroundColor: c.textPrimary,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: text.titleLarge,
        systemOverlayStyle: overlayStyle,
      ),
      cardTheme: CardThemeData(
        color: c.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(DeliveryRadius.card),
          side: BorderSide(color: c.border, width: DeliverySize.hairline),
        ),
      ),
      dividerTheme: DividerThemeData(
        color: c.border,
        thickness: DeliverySize.hairline,
        space: DeliverySize.hairline,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: ButtonStyle(
          minimumSize: const WidgetStatePropertyAll(Size(DeliverySize.touchTarget, DeliverySize.control)),
          padding: const WidgetStatePropertyAll(
            EdgeInsets.symmetric(horizontal: DeliverySpace.s20, vertical: DeliverySpace.s12),
          ),
          textStyle: WidgetStatePropertyAll(text.labelLarge),
          elevation: const WidgetStatePropertyAll(0),
          backgroundColor: WidgetStateProperty.resolveWith(
            (s) => s.contains(WidgetState.disabled) ? c.disabledFill : c.primary,
          ),
          foregroundColor: WidgetStateProperty.resolveWith(
            (s) => s.contains(WidgetState.disabled) ? c.disabledText : c.onPrimary,
          ),
          overlayColor: WidgetStateProperty.resolveWith((s) {
            if (s.contains(WidgetState.pressed)) return c.onPrimary.withValues(alpha: DeliveryOpacity.pressed);
            if (s.contains(WidgetState.hovered)) return c.onPrimary.withValues(alpha: DeliveryOpacity.hover);
            return Colors.transparent;
          }),
          shape: WidgetStatePropertyAll(RoundedRectangleBorder(borderRadius: controlRadius)),
          side: WidgetStateProperty.resolveWith((s) {
            if (s.contains(WidgetState.disabled)) return BorderSide.none;
            if (deliveryShowsFocus(s)) {
              return BorderSide(
                color: c.focusOnFill,
                width: DeliverySize.focusStrong,
                strokeAlign: BorderSide.strokeAlignInside,
              );
            }
            return BorderSide.none;
          }),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: ButtonStyle(
          minimumSize: const WidgetStatePropertyAll(Size(DeliverySize.touchTarget, DeliverySize.control)),
          padding: const WidgetStatePropertyAll(
            EdgeInsets.symmetric(horizontal: DeliverySpace.s20, vertical: DeliverySpace.s12),
          ),
          textStyle: WidgetStatePropertyAll(text.labelLarge),
          foregroundColor: WidgetStateProperty.resolveWith(
            (s) => s.contains(WidgetState.disabled) ? c.disabledText : c.primary,
          ),
          overlayColor: WidgetStateProperty.resolveWith((s) {
            if (s.contains(WidgetState.pressed)) return c.primary.withValues(alpha: DeliveryOpacity.pressed);
            if (s.contains(WidgetState.hovered)) return c.primary.withValues(alpha: DeliveryOpacity.hover);
            return Colors.transparent;
          }),
          shape: WidgetStatePropertyAll(RoundedRectangleBorder(borderRadius: controlRadius)),
          side: WidgetStateProperty.resolveWith((s) {
            if (s.contains(WidgetState.disabled)) {
              return BorderSide(
                color: c.disabledFill,
                width: DeliverySize.outline,
                strokeAlign: BorderSide.strokeAlignInside,
              );
            }
            if (deliveryShowsFocus(s)) {
              return BorderSide(
                color: c.focus,
                width: DeliverySize.focusStrong,
                strokeAlign: BorderSide.strokeAlignInside,
              );
            }
            return BorderSide(
              color: c.controlBorder,
              width: DeliverySize.outline,
              strokeAlign: BorderSide.strokeAlignInside,
            );
          }),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: ButtonStyle(
          minimumSize: const WidgetStatePropertyAll(Size(DeliverySize.touchTarget, DeliverySize.controlCompact)),
          padding: const WidgetStatePropertyAll(
            EdgeInsets.symmetric(horizontal: DeliverySpace.s12, vertical: DeliverySpace.s8),
          ),
          textStyle: WidgetStatePropertyAll(text.labelLarge),
          foregroundColor: WidgetStateProperty.resolveWith(
            (s) => s.contains(WidgetState.disabled) ? c.disabledText : c.primary,
          ),
          shape: WidgetStatePropertyAll(RoundedRectangleBorder(borderRadius: controlRadius)),
          side: WidgetStateProperty.resolveWith((s) {
            if (deliveryShowsFocus(s)) {
              return BorderSide(
                color: c.focus,
                width: DeliverySize.focus,
                strokeAlign: BorderSide.strokeAlignInside,
              );
            }
            return BorderSide.none;
          }),
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: ButtonStyle(
          minimumSize: const WidgetStatePropertyAll(Size.square(DeliverySize.touchTarget)),
          foregroundColor: WidgetStatePropertyAll(c.textPrimary),
          shape: WidgetStatePropertyAll(RoundedRectangleBorder(borderRadius: controlRadius)),
          side: WidgetStateProperty.resolveWith((s) {
            if (deliveryShowsFocus(s)) {
              return BorderSide(
                color: c.focus,
                width: DeliverySize.focus,
                strokeAlign: BorderSide.strokeAlignInside,
              );
            }
            return BorderSide.none;
          }),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: c.surface,
        isDense: false,
        contentPadding: const EdgeInsets.symmetric(horizontal: DeliverySpace.s16, vertical: DeliverySpace.s12),
        hintStyle: text.bodyLarge!.copyWith(color: c.textTertiary),
        labelStyle: text.bodyLarge!.copyWith(color: c.textSecondary),
        floatingLabelStyle: text.labelLarge!.copyWith(color: c.primary),
        helperStyle: text.bodySmall!.copyWith(color: c.textSecondary),
        errorStyle: text.bodySmall!.copyWith(color: c.dangerColor),
        errorMaxLines: 3,
        border: inputBorder(c.controlBorder, DeliverySize.hairline),
        enabledBorder: inputBorder(c.controlBorder, DeliverySize.hairline),
        focusedBorder: inputBorder(c.focus, DeliverySize.focus),
        errorBorder: inputBorder(c.dangerColor, DeliverySize.hairline),
        focusedErrorBorder: inputBorder(c.dangerColor, DeliverySize.focus),
        disabledBorder: inputBorder(c.disabledFill, DeliverySize.hairline),
      ),
      navigationBarTheme: NavigationBarThemeData(
        height: DeliverySize.navBar,
        backgroundColor: c.surface,
        surfaceTintColor: Colors.transparent,
        indicatorColor: c.primaryContainer,
        indicatorShape: const StadiumBorder(),
        labelTextStyle: WidgetStateProperty.resolveWith((s) {
          final selected = s.contains(WidgetState.selected);
          return text.labelSmall!.copyWith(
            color: selected ? c.primary : c.textSecondary,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
          );
        }),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: c.surface,
        selectedColor: c.primary,
        disabledColor: c.disabledFill,
        labelStyle: text.labelLarge!,
        secondaryLabelStyle: text.labelLarge!.copyWith(color: c.onPrimary),
        padding: const EdgeInsets.symmetric(horizontal: DeliverySpace.s12, vertical: DeliverySpace.s6),
        shape: StadiumBorder(side: BorderSide(color: c.border)),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((s) {
          if (s.contains(WidgetState.disabled)) return c.disabledText;
          if (s.contains(WidgetState.selected)) return c.onPrimary;
          return c.textSecondary;
        }),
        trackColor: WidgetStateProperty.resolveWith((s) {
          if (s.contains(WidgetState.disabled)) return c.disabledFill;
          if (s.contains(WidgetState.selected)) return c.primary;
          return c.sunken;
        }),
        trackOutlineColor: WidgetStateProperty.resolveWith((s) {
          if (s.contains(WidgetState.selected)) return Colors.transparent;
          return c.controlBorder;
        }),
      ),
      checkboxTheme: CheckboxThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(DeliveryRadius.xs)),
        fillColor: WidgetStateProperty.resolveWith((s) {
          if (s.contains(WidgetState.selected)) return c.primary;
          return Colors.transparent;
        }),
        checkColor: WidgetStatePropertyAll(c.onPrimary),
        side: BorderSide(color: c.controlBorder, width: DeliverySize.focus),
      ),
      radioTheme: RadioThemeData(
        fillColor: WidgetStateProperty.resolveWith((s) {
          if (s.contains(WidgetState.selected)) return c.primary;
          return c.controlBorder;
        }),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: c.raised,
        surfaceTintColor: Colors.transparent,
        modalBackgroundColor: c.raised,
        showDragHandle: true,
        dragHandleColor: c.controlBorder,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(DeliveryRadius.sheet)),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: c.raised,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(DeliveryRadius.dialog),
          side: BorderSide(color: c.border, width: DeliverySize.hairline),
        ),
        titleTextStyle: text.titleLarge,
        contentTextStyle: text.bodyLarge!.copyWith(color: c.textSecondary),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: c.toast,
        contentTextStyle: text.bodyMedium!.copyWith(color: c.onToast),
        actionTextColor: c.toastSuccess,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(DeliveryRadius.control)),
      ),
    );
  }
}
