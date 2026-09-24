import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:seller/design_system/design_system.dart';

/// WCAG 2.2 contrast of every pairing the seller components actually draw
/// (brief §5: 4.5:1 text, 3:1 large text / controls / focus indicators).
double contrast(Color a, Color b) {
  final la = a.computeLuminance(), lb = b.computeLuminance();
  return (math.max(la, lb) + 0.05) / (math.min(la, lb) + 0.05);
}

void main() {
  for (final (name, c) in [('light', SellerColors.light), ('dark', SellerColors.dark)]) {
    group('$name palette', () {
      void atLeast(Color fg, Color bg, double ratio, String what) {
        final r = contrast(fg, bg);
        expect(r, greaterThanOrEqualTo(ratio), reason: '$what is ${r.toStringAsFixed(2)}:1, needs $ratio:1');
      }

      test('body text on every neutral surface ≥ 4.5:1', () {
        final surfaces = {'canvas': c.canvas, 'surface': c.surface, 'raised': c.raised, 'sunken': c.sunken, 'primarySubtle': c.primarySubtle};
        final texts = {'textPrimary': c.textPrimary, 'textSecondary': c.textSecondary, 'textTertiary': c.textTertiary};
        for (final t in texts.entries) {
          for (final s in surfaces.entries) {
            atLeast(t.value, s.value, 4.5, '${t.key} on ${s.key}');
          }
        }
      });

      test('text on tinted containers ≥ 4.5:1 (tertiary text is kept off tints)', () {
        for (final bg in [c.primaryContainer, c.successContainer, c.warningContainer, c.dangerContainer, c.infoContainer]) {
          atLeast(c.textPrimary, bg, 4.5, 'textPrimary on tint');
          atLeast(c.textSecondary, bg, 4.5, 'textSecondary on tint');
        }
        atLeast(c.onPrimaryContainer, c.primaryContainer, 4.5, 'onPrimaryContainer');
      });

      test('status colours on their own tint and on the surface ≥ 4.5:1', () {
        for (final tone in SellerTone.values) {
          final pair = c.tone(tone);
          atLeast(pair.foreground, pair.container, 4.5, '$tone on its container');
          atLeast(pair.foreground, c.surface, 4.5, '$tone on surface');
        }
      });

      test('filled buttons: label ≥ 4.5:1, focus stroke on the fill ≥ 3:1', () {
        atLeast(c.onPrimary, c.primary, 4.5, 'onPrimary on primary');
        atLeast(c.onDangerFill, c.dangerFill, 4.5, 'onDangerFill on dangerFill');
        atLeast(c.focusOnFill, c.primary, 3, 'focusOnFill on primary');
        atLeast(c.focusOnDanger, c.dangerFill, 3, 'focusOnDanger on dangerFill');
      });

      test('control borders and the focus border ≥ 3:1 against the page', () {
        for (final bg in [c.canvas, c.surface, c.raised]) {
          atLeast(c.controlBorder, bg, 3, 'controlBorder');
          atLeast(c.focus, bg, 3, 'focus');
          atLeast(c.primary, bg, 3, 'primary (outlined button border)');
        }
        atLeast(c.focus, c.primarySubtle, 3, 'focus on an open FAQ row');
      });

      test('toast text and icons', () {
        atLeast(c.onToast, c.toast, 4.5, 'onToast');
        atLeast(c.toastSuccess, c.toast, 3, 'toastSuccess icon');
        atLeast(c.toastDanger, c.toast, 3, 'toastDanger icon');
      });

      test('chart series are distinguishable from the card ≥ 3:1', () {
        expect(c.chart, hasLength(6));
        for (final series in c.chart) {
          atLeast(series, c.surface, 3, 'chart series $series');
        }
        atLeast(c.textSecondary, c.surface, 3, 'comparison (hatched/dashed) series');
      });
    });
  }

  test('themes carry the palette and the right brightness', () {
    expect(SellerTheme.light.extension<SellerColors>(), SellerColors.light);
    expect(SellerTheme.dark.extension<SellerColors>(), SellerColors.dark);
    expect(SellerTheme.light.brightness, Brightness.light);
    expect(SellerTheme.dark.brightness, Brightness.dark);
    expect(SellerTheme.light.colorScheme.primary, SellerColors.light.primary);
    expect(SellerTheme.dark.colorScheme.primary, SellerColors.dark.primary);
  });

  test('focus never adds a halo: overlay and focus colours are transparent', () {
    for (final theme in [SellerTheme.light, SellerTheme.dark]) {
      expect(theme.focusColor.a, 0);
      const focused = {WidgetState.focused};
      for (final style in [
        theme.filledButtonTheme.style,
        theme.outlinedButtonTheme.style,
        theme.textButtonTheme.style,
        theme.elevatedButtonTheme.style,
      ]) {
        final overlay = style?.overlayColor?.resolve(focused);
        expect(overlay == null || overlay.a == 0, isTrue, reason: 'focused overlay must be transparent');
      }
    }
  });

  test('lerp is stable at the ends', () {
    expect(SellerColors.light.lerp(SellerColors.dark, 0).primary, SellerColors.light.primary);
    expect(SellerColors.light.lerp(SellerColors.dark, 1).primary, SellerColors.dark.primary);
  });
}
