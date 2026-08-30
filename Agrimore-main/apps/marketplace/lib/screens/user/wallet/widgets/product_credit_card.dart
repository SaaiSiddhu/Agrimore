import 'package:flutter/material.dart';
import 'package:agrimore_ui/agrimore_ui.dart';

/// AgriMore Product Credit summary card — deliberately visually DISTINCT
/// from WalletBalanceCard (different gradient, different iconography,
/// different section label) so a customer never mistakes this for cash.
/// See wallet_screen.dart's header comment: cash and Product Credit are
/// legally different instruments and must never be summed or rendered as
/// one figure. This widget renders ONLY what the balance already has —
/// no enrolment, no "add credit," no principal/deposit/maturity language.
class ProductCreditCard extends StatelessWidget {
  final double available;
  final double onHold;
  final double pending;
  final bool isDark;
  final bool hasLedgerError;
  final VoidCallback onViewHistory;

  const ProductCreditCard({
    Key? key,
    required this.available,
    required this.onHold,
    required this.pending,
    required this.isDark,
    required this.hasLedgerError,
    required this.onViewHistory,
  }) : super(key: key);

  String _money(double v) => '₹${v.toStringAsFixed(2)}';

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.primaryDark, AppColors.primary],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withOpacity(0.35),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.eco_outlined,
                  color: Colors.white,
                  size: 20,
                ),
              ),
              const SizedBox(width: 10),
              const Text(
                'AGRIMORE PRODUCT CREDIT',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 1.2,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Main available figure — the only number given visual weight,
          // deliberately labelled "Available Credit" (never "Balance"
          // alone) to keep it distinct from the cash wallet above.
          Text(
            _money(available),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 32,
              fontWeight: FontWeight.bold,
              letterSpacing: -1,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Available Credit',
            style: TextStyle(
              color: Colors.white70,
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),

          // onHold/pending only when non-zero, each with a plain-language
          // one-liner — a HOLD is a reservation, not a spend; pending is
          // accrued but not yet available. Never implied to be part of
          // the headline figure above.
          if (onHold > 0 || pending > 0) ...[
            const SizedBox(height: 16),
            Container(height: 1, color: Colors.white.withOpacity(0.2)),
            const SizedBox(height: 16),
            if (onHold > 0)
              _StatusRow(
                icon: Icons.lock_clock_outlined,
                label: 'Reserved for checkout',
                value: _money(onHold),
              ),
            if (onHold > 0 && pending > 0) const SizedBox(height: 10),
            if (pending > 0)
              _StatusRow(
                icon: Icons.schedule_outlined,
                label: 'Accrued, not yet available',
                value: _money(pending),
              ),
          ],

          const SizedBox(height: 16),
          Text(
            'Redeemable towards AgriMore products at checkout. Cannot be withdrawn as cash.',
            style: TextStyle(
              color: Colors.white.withOpacity(0.85),
              fontSize: 12,
              height: 1.4,
            ),
          ),

          if (hasLedgerError) ...[
            const SizedBox(height: 8),
            Text(
              'History is temporarily unavailable.',
              style: TextStyle(
                color: Colors.white.withOpacity(0.7),
                fontSize: 11,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],

          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: onViewHistory,
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.white,
                side: const BorderSide(color: Colors.white54),
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text(
                'View Credit History',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _StatusRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            Icon(icon, color: Colors.white70, size: 16),
            const SizedBox(width: 8),
            Text(
              label,
              style: const TextStyle(color: Colors.white70, fontSize: 13),
            ),
          ],
        ),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}
