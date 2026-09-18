import 'package:employee/utils/sa_formatters.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('SaFormatters Canonical Content Conventions', () {
    test('formatCurrency formats Indian rupee amounts with two decimals', () {
      expect(SaFormatters.formatCurrency(12500), equals('₹12,500.00'));
      expect(SaFormatters.formatCurrency(125000), equals('₹1,25,000.00'));
      expect(SaFormatters.formatCurrency(500), equals('₹500.00'));
      expect(SaFormatters.formatCurrency(0), equals('₹0.00'));
    });

    test('formatDate formats date with day-month-year and abbreviated month', () {
      final date = DateTime(2026, 9, 18);
      expect(SaFormatters.formatDate(date), equals('18 Sep 2026'));
    });

    test('formatMaskedPhone masks 10-digit mobile number with +91 country code', () {
      expect(
        SaFormatters.formatMaskedPhone('9876544321'),
        equals('+91 •••••• 4321'),
      );
      expect(
        SaFormatters.formatMaskedPhone('+919876544321'),
        equals('+91 •••••• 4321'),
      );
    });

    test('formatMaskedAccount formats account number showing only last 4 digits', () {
      expect(
        SaFormatters.formatMaskedAccount('5010043219874321'),
        equals('Account ending 4321'),
      );
      expect(
        SaFormatters.formatMaskedAccount('4321'),
        equals('Account ending 4321'),
      );
    });
  });
}
