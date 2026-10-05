import 'package:flutter_test/flutter_test.dart';
import 'package:seller/screens/products/stock_count_validation.dart';

void main() {
  test('keeps an explicitly stored zero', () => expect(configuredStockCount(0), 0));
  test('accepts integer numeric encodings', () {
    expect(configuredStockCount(18), 18);
    expect(configuredStockCount(18.0), 18);
  });
  test('does not treat absent stock as the model default', () {
    expect(configuredStockCount(null), isNull);
  });
  test('rejects nonnumeric, fractional, negative and unsafe stock', () {
    expect(configuredStockCount('999'), isNull);
    expect(configuredStockCount(1.5), isNull);
    expect(configuredStockCount(-1), isNull);
    expect(configuredStockCount(double.infinity), isNull);
    expect(configuredStockCount(9007199254740992), isNull);
  });
}
