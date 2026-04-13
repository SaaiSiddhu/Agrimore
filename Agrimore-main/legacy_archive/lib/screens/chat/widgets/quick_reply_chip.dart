// lib/screens/chat/widgets/quick_reply_chip.dart
import 'package:flutter/material.dart';

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
    final theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: theme.colorScheme.primaryContainer.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: theme.colorScheme.primary.withValues(alpha: 0.3),
            width: 1.5,
          ),
        ),
        child: Text(
          label,
          style: theme.textTheme.labelMedium?.copyWith(
            color: theme.colorScheme.primary,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}