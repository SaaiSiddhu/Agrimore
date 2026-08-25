import 'package:flutter/material.dart';
import 'package:agrimore_services/agrimore_services.dart';
import 'cart_provider.dart';

/// B2C/B2B ordering mode toggle. A simple bool (isB2B) was chosen over a
/// richer enum since there are only ever two modes and every call site reads
/// it as a boolean check anyway.
///
/// Persisted directly via SharedPreferencesService.setBool/getBool with an
/// inline key rather than a new StorageConstants entry — adding one would
/// touch packages/agrimore_core, outside this phase's explicit scope
/// (packages/agrimore_core was not listed in the completion standard's
/// allowed-diff footprint).
class MarketModeProvider with ChangeNotifier {
  static const String _prefsKey = 'market_mode_b2b';

  bool _isB2B = false;

  MarketModeProvider() {
    _isB2B = SharedPreferencesService.getBool(_prefsKey) ?? false;
  }

  bool get isB2B => _isB2B;

  Future<void> setB2B(bool value) async {
    if (_isB2B == value) return;
    _isB2B = value;
    await SharedPreferencesService.setBool(_prefsKey, value);
    notifyListeners();
  }

  Future<void> toggle() => setB2B(!_isB2B);
}

/// Locked decision: an order is fully B2C or fully B2B, never mixed —
/// switching mode with items already in the cart must prompt to clear it.
/// Call this at every add-to-cart entry point before calling
/// CartProvider.addItem, per the requirement that CartProvider itself must
/// not silently swallow the conflict — the UI layer owns the prompt.
///
/// Returns true if the caller should proceed with the add (cart was empty,
/// modes already matched, or the user confirmed clearing it) — false if the
/// user cancelled.
Future<bool> confirmCartModeSwitch({
  required BuildContext context,
  required CartProvider cart,
  required bool wantsB2B,
}) async {
  final currentMode = cart.cartMode;
  if (currentMode == null || cart.items.isEmpty) return true;

  final wantedMode = wantsB2B ? 'B2B' : 'B2C';
  if (currentMode == wantedMode) return true;

  final confirmed = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Switch order mode?'),
      content: Text(
        'Your cart has $currentMode items. Adding a $wantedMode item '
        'requires clearing your cart first — an order must be fully '
        '$currentMode or fully $wantedMode, never mixed.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(ctx, true),
          child: const Text('Clear Cart & Continue'),
        ),
      ],
    ),
  );

  if (confirmed != true) return false;
  await cart.clearCart();
  return true;
}
