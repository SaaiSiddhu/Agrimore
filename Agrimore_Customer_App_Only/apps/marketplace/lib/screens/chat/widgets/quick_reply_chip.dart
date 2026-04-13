// lib/screens/chat/widgets/quick_reply_chip.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class QuickReplyChip extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const QuickReplyChip({
    Key? key,
    required this.label,
    required this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          HapticFeedback.lightImpact();
          onTap();
        },
        borderRadius: BorderRadius.circular(24),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                const Color(0xFF2E7D32).withOpacity(isDark ? 0.3 : 0.12),
                const Color(0xFF43A047).withOpacity(isDark ? 0.2 : 0.08),
              ],
            ),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: const Color(0xFF2E7D32).withOpacity(isDark ? 0.5 : 0.4),
              width: 1.2,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.auto_awesome_rounded,
                size: 14,
                color: isDark ? const Color(0xFF81C784) : const Color(0xFF2E7D32),
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  color: isDark ? const Color(0xFF81C784) : const Color(0xFF2E7D32),
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}