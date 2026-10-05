/// Returns the explicitly stored whole-unit count, preserving missing or
/// malformed raw stock as unknown instead of substituting ProductModel's
/// display default.
int? configuredStockCount(Object? raw) {
  if (raw is! num || !raw.isFinite || raw < 0 || raw > 9007199254740991) return null;
  if (raw.toDouble() != raw.toDouble().roundToDouble()) return null;
  return raw.toInt();
}
