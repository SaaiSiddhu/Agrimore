import 'package:agrimore_ui/agrimore_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Sales Associate Theme Isolation & Integrity', () {
    test('SalesAssociateTheme provides blue primary palette and tokens', () {
      final saTheme = SalesAssociateTheme.lightTheme;

      // Primary color must be canonical blue (#2563EB)
      expect(saTheme.colorScheme.primary, equals(const Color(0xFF2563EB)));
      expect(saTheme.primaryColor, equals(const Color(0xFF2563EB)));
      expect(saTheme.scaffoldBackgroundColor, equals(const Color(0xFFF8FAFC)));

      // ThemeExtension must be present and match canonical tokens
      final ext = saTheme.extension<SalesAssociateTokens>();
      expect(ext, isNotNull);
      expect(ext!.primary, equals(const Color(0xFF2563EB)));
      expect(ext.primaryPressed, equals(const Color(0xFF1D4ED8)));
      expect(ext.primarySubtle, equals(const Color(0xFFEFF6FF)));
      expect(ext.pageBackground, equals(const Color(0xFFF8FAFC)));
      expect(ext.surface, equals(const Color(0xFFFFFFFF)));
      expect(ext.textPrimary, equals(const Color(0xFF0F172A)));
      expect(ext.textSecondary, equals(const Color(0xFF475569)));
      expect(ext.divider, equals(const Color(0xFFE2E8F0)));
      expect(ext.inputBorder, equals(const Color(0xFF64748B)));
      expect(ext.successFg, equals(const Color(0xFF15803D)));
      expect(ext.successBg, equals(const Color(0xFFF0FDF4)));
      expect(ext.warningFg, equals(const Color(0xFFB45309)));
      expect(ext.warningBg, equals(const Color(0xFFFFFBEB)));
      expect(ext.errorFg, equals(const Color(0xFFB91C1C)));
      expect(ext.errorBg, equals(const Color(0xFFFEF2F2)));
    });

    test('INVARIANT: AppTheme.lightTheme remains emerald green and unaffected', () {
      final sharedTheme = AppTheme.lightTheme;

      // AppTheme.lightTheme MUST remain emerald green (0xFF0D9B5C)
      expect(sharedTheme.colorScheme.primary, equals(const Color(0xFF0D9B5C)));
      expect(AppColors.primary, equals(const Color(0xFF0D9B5C)));

      // SalesAssociateTokens must NOT be attached to AppTheme by default
      final ext = sharedTheme.extension<SalesAssociateTokens>();
      expect(ext, isNull);
    });

    test('SalesAssociateTheme dimensions match canonical specifications', () {
      final saTheme = SalesAssociateTheme.lightTheme;

      // Card radius 16px
      final cardShape = saTheme.cardTheme.shape as RoundedRectangleBorder;
      expect(cardShape.borderRadius, equals(BorderRadius.circular(16)));

      // Input border radius 12px
      final inputBorder =
          saTheme.inputDecorationTheme.border as OutlineInputBorder;
      expect(inputBorder.borderRadius, equals(BorderRadius.circular(12)));

      // ElevatedButton min height 52px
      final btnStyle = saTheme.elevatedButtonTheme.style;
      expect(btnStyle?.minimumSize?.resolve({}), equals(const Size.fromHeight(52)));
    });
  });
}
