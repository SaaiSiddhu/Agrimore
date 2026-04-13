import 'package:flutter/material.dart';
import 'package:agrimore_core/agrimore_core.dart';

/// Transaction tile for wallet history
class TransactionTile extends StatelessWidget {
  final WalletTransactionModel transaction;
  final bool isDark;

  const TransactionTile({
    Key? key,
    required this.transaction,
    required this.isDark,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final isCredit = transaction.type == TransactionType.credit;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: isDark ? Colors.white.withOpacity(0.1) : Colors.grey.withOpacity(0.1),
            width: 1,
          ),
        ),
      ),
      child: Row(
        children: [
          // Icon
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: transaction.color.withOpacity(0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              transaction.icon,
              color: transaction.color,
              size: 22,
            ),
          ),
          
          const SizedBox(width: 14),
          
          // Details
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  transaction.sourceLabel,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  transaction.description,
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark ? Colors.grey[400] : Colors.grey[600],
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          
          const SizedBox(width: 12),
          
          // Amount
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                transaction.formattedAmount,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: isCredit ? const Color(0xFF4CAF50) : const Color(0xFFE53935),
                ),
              ),
              const SizedBox(height: 3),
              Text(
                transaction.formattedDate,
                style: TextStyle(
                  fontSize: 11,
                  color: isDark ? Colors.grey[500] : Colors.grey[500],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
