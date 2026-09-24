import 'dart:io';
import 'dart:math' as math;

import 'package:agrimore_ui/agrimore_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// WCAG 2.x relative luminance.
double _luminance(Color c) {
  double ch(double v) => v <= 0.03928 ? v / 12.92 : math.pow((v + 0.055) / 1.055, 2.4).toDouble();
  return 0.2126 * ch(c.r) + 0.7152 * ch(c.g) + 0.0722 * ch(c.b);
}

double contrast(Color a, Color b) {
  final la = _luminance(a);
  final lb = _luminance(b);
  final hi = math.max(la, lb);
  final lo = math.min(la, lb);
  return (hi + 0.05) / (lo + 0.05);
}

void main() {
  const allSeller = [WorkspaceTokens.sellerLight, WorkspaceTokens.sellerDark];

  group('Seller teal palette meets WCAG AA (ADR §5)', () {
    for (final t in allSeller) {
      final name = t.isDark ? 'dark' : 'light';
      test('$name: text on a primary fill ≥ 4.5', () {
        expect(contrast(t.onPrimary, t.primary), greaterThanOrEqualTo(4.5));
      });
      test('$name: primary as text on page and surface ≥ 4.5', () {
        expect(contrast(t.primary, t.pageBackground), greaterThanOrEqualTo(4.5));
        expect(contrast(t.primary, t.surface), greaterThanOrEqualTo(4.5));
      });
      test('$name: primary on its subtle container ≥ 4.5', () {
        expect(contrast(t.primary, t.primarySubtle), greaterThanOrEqualTo(4.5));
      });
      test('$name: body text roles on surface and page ≥ 4.5', () {
        for (final fg in [t.textPrimary, t.textSecondary, t.textTertiary]) {
          expect(contrast(fg, t.surface), greaterThanOrEqualTo(4.5));
          expect(contrast(fg, t.pageBackground), greaterThanOrEqualTo(4.5));
        }
      });
      test('$name: semantic foreground on its own background ≥ 4.5', () {
        expect(contrast(t.successFg, t.successBg), greaterThanOrEqualTo(4.5));
        expect(contrast(t.warningFg, t.warningBg), greaterThanOrEqualTo(4.5));
        expect(contrast(t.errorFg, t.errorBg), greaterThanOrEqualTo(4.5));
        expect(contrast(t.infoFg, t.infoBg), greaterThanOrEqualTo(4.5));
      });
      test('$name: chart series 1 is the brand; six distinct series', () {
        expect(t.dataViz.first, t.primary);
        expect(t.dataViz.toSet().length, 6);
      });
    }

    test('exact brand values from the ADR', () {
      expect(WorkspaceTokens.sellerLight.primary, const Color(0xFF0F766E));
      expect(WorkspaceTokens.sellerLight.primaryPressed, const Color(0xFF115E59));
      expect(WorkspaceTokens.sellerLight.primarySubtle, const Color(0xFFF0FDFA));
      expect(WorkspaceTokens.sellerDark.primary, const Color(0xFF2DD4BF));
      expect(WorkspaceTokens.sellerDark.primarySubtle, const Color(0xFF042F2E));
      expect(WorkspaceTokens.sellerDark.onPrimary, const Color(0xFF042F2E));
    });
  });

  group('Sales Associate is unchanged', () {
    test('Workspace SA tokens are the SaTokens values', () {
      const l = WorkspaceTokens.salesAssociateLight;
      const d = WorkspaceTokens.salesAssociateDark;
      expect(l.primary, SaTokens.primary);
      expect(l.pageBackground, SaTokens.pageBackground);
      expect(l.textSecondary, SaTokens.textSecondary);
      expect(l.errorFg, SaTokens.errorFg);
      expect(d.primary, SaTokens.darkPrimary);
      expect(d.surface, SaTokens.darkSurface);
      expect(d.divider, SaTokens.darkDivider);
    });

    test('SalesAssociateTheme keeps its colours and font, and now also carries WorkspaceTokens', () {
      final light = SalesAssociateTheme.lightTheme;
      final dark = SalesAssociateTheme.darkTheme;
      expect(light.colorScheme.primary, SaTokens.primary);
      expect(light.scaffoldBackgroundColor, SaTokens.pageBackground);
      expect(dark.colorScheme.primary, SaTokens.darkPrimary);
      expect(light.textTheme.bodyLarge!.fontFamily, SalesAssociateTheme.fontFamily);
      expect(light.extension<SalesAssociateTokens>(), SalesAssociateTokens.light);
      expect(light.extension<WorkspaceTokens>(), WorkspaceTokens.salesAssociateLight);
      expect(dark.extension<WorkspaceTokens>(), WorkspaceTokens.salesAssociateDark);
    });
  });

  // DLV-C1: every brand's primary must carry its on-primary text (WCAG AA).
  group('brand contrast', () {
    double lum(Color c) => c.computeLuminance();
    double ratio(Color a, Color b) {
      final x = lum(a), y = lum(b);
      return (x > y ? x + 0.05 : y + 0.05) / (x > y ? y + 0.05 : x + 0.05);
    }

    // Known, out of this phase: salesAssociate dark measures 3.68:1 (the
    // employee app's palette) — reported separately, asserted as-is so it
    // cannot get worse unnoticed.
    test('salesAssociate / dark (known finding) stays at its measured contrast', () {
      final t = WorkspaceTokens.forBrand(WorkspaceBrand.salesAssociate, Brightness.dark);
      expect(ratio(t.primary, t.onPrimary), greaterThanOrEqualTo(3.6));
    });

    for (final brand in WorkspaceBrand.values) {
      for (final b in Brightness.values) {
        if (brand == WorkspaceBrand.salesAssociate && b == Brightness.dark) continue;
        test('$brand / $b primary vs onPrimary ≥ 4.5:1', () {
          final t = WorkspaceTokens.forBrand(brand, b);
          expect(ratio(t.primary, t.onPrimary), greaterThanOrEqualTo(4.5));
          expect(ratio(t.primary, t.pageBackground), greaterThanOrEqualTo(3.0));
        });
      }
    }
  });

  group('WorkspaceTheme.build', () {
    for (final brand in WorkspaceBrand.values) {
      for (final b in Brightness.values) {
        test('$brand / $b wires tokens, font and components', () {
          final theme = WorkspaceTheme.build(brand, b);
          final t = WorkspaceTokens.forBrand(brand, b);
          expect(theme.brightness, b);
          expect(theme.extension<WorkspaceTokens>(), t);
          expect(theme.colorScheme.primary, t.primary);
          expect(theme.colorScheme.onPrimary, t.onPrimary);
          expect(theme.scaffoldBackgroundColor, t.pageBackground);
          expect(theme.textTheme.bodyLarge!.fontFamily, WsType.fontFamily);
          expect(theme.textTheme.displayLarge!.fontSize, WsType.fsDisplayAmount);
          expect(theme.textTheme.labelSmall!.fontSize, WsType.fsMicro);
          expect(theme.cardTheme.elevation, 0);
          expect(theme.navigationBarTheme.height, WsSize.bottomBarHeight);
          expect(theme.navigationRailTheme.minWidth, WsSize.railWidth);
          // shared Sa* widgets paint in the active brand
          expect(theme.extension<SalesAssociateTokens>()!.primary, t.primary);
        });
      }
    }

    testWidgets('context.ws returns the seller tokens inside a seller theme', (tester) async {
      late WorkspaceTokens seen;
      await tester.pumpWidget(MaterialApp(
        theme: WorkspaceTheme.build(WorkspaceBrand.seller, Brightness.light),
        home: Builder(builder: (context) {
          seen = context.ws;
          return const SizedBox.shrink();
        }),
      ));
      expect(seen.brand, WorkspaceBrand.seller);
      expect(seen.primary, const Color(0xFF0F766E));
    });

    testWidgets('context.ws fails loudly without Workspace tokens', (tester) async {
      Object? error;
      await tester.pumpWidget(MaterialApp(
        theme: ThemeData(),
        home: Builder(builder: (context) {
          try {
            context.ws;
          } catch (e) {
            error = e;
          }
          return const SizedBox.shrink();
        }),
      ));
      expect(error, isA<FlutterError>());
    });
  });

  testWidgets('SaLoadingButton text is readable on dark teal', (tester) async {
    await tester.pumpWidget(MaterialApp(
      theme: WorkspaceTheme.build(WorkspaceBrand.seller, Brightness.dark),
      home: Scaffold(body: SaLoadingButton(text: 'Continue', onPressed: () {})),
    ));
    final text = tester.widget<Text>(find.text('Continue'));
    final style = DefaultTextStyle.of(tester.element(find.text('Continue'))).style.merge(text.style);
    final fg = style.color ?? WorkspaceTokens.sellerDark.onPrimary;
    expect(contrast(fg, WorkspaceTokens.sellerDark.primary), greaterThanOrEqualTo(4.5));
  });

  group('Inter is bundled', () {
    test('four static TTFs and the OFL licence exist', () {
      for (final w in ['Regular', 'Medium', 'SemiBold', 'Bold']) {
        final f = File('assets/fonts/Inter-$w.ttf');
        expect(f.existsSync(), isTrue, reason: f.path);
        expect(f.lengthSync(), greaterThan(100000));
      }
      expect(File('assets/fonts/OFL.txt').existsSync(), isTrue);
    });

    test('pubspec declares family Inter with weights 400/500/600/700', () {
      final pubspec = File('pubspec.yaml').readAsStringSync();
      expect(pubspec, contains('family: Inter'));
      for (final w in ['400', '500', '600', '700']) {
        expect(pubspec, contains('weight: $w'));
      }
    });
  });

  group('AgFormat', () {
    test('rupees use Indian grouping', () {
      expect(AgFormat.rupees(123456), '₹1,23,456.00');
      expect(AgFormat.rupeesWhole(12345678), '₹1,23,45,678');
    });
    test('compact rupees use K / L / Cr', () {
      expect(AgFormat.rupeesCompact(999), '₹999');
      expect(AgFormat.rupeesCompact(45600), '₹45.6K');
      expect(AgFormat.rupeesCompact(120000), '₹1.2L');
      expect(AgFormat.rupeesCompact(34000000), '₹3.4Cr');
      expect(AgFormat.rupeesCompact(-120000), '-₹1.2L');
    });
    test('percent delta is signed', () {
      expect(AgFormat.percentDelta(0.125), '+12.5%');
      expect(AgFormat.percentDelta(-0.03), '-3%');
      expect(AgFormat.percentDelta(0), '0%');
    });
    test('phone and account masking never reveal the middle digits', () {
      expect(AgFormat.maskPhone('+91 98765 43321'), '+91\u00A098•••\u00A0••321');
      expect(AgFormat.maskPhone('+91 98765 43321'), isNot(contains(' ')), reason: 'never wraps mid-number');
      expect(AgFormat.maskPhone('123'), '••••••••••');
      expect(AgFormat.maskAccount('50100012344821'), '••••\u00A04821');
    });
  });

  test('layout classes follow the ADR breakpoints', () {
    expect(wsLayoutFor(390), WsLayout.compact);
    expect(wsLayoutFor(700), WsLayout.medium);
    expect(wsLayoutFor(1000), WsLayout.expanded);
    expect(wsLayoutFor(1440), WsLayout.large);
  });
}
