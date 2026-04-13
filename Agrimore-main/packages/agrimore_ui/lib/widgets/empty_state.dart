import 'package:flutter/material.dart';
import '../themes/app_text_styles.dart';

class EmptyState extends StatelessWidget {
  final String title;
  final String? message;
  final IconData icon;

  const EmptyState({
    Key? key,
    required this.title,
    this.message,
    this.icon = Icons.inbox,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 64, color: Colors.grey),
          const SizedBox(height: 16),
          Text(title, style: AppTextStyles.bodyLarge.copyWith(fontWeight: FontWeight.bold)),
          if (message != null) ...[
            const SizedBox(height: 8),
            Text(message!, style: AppTextStyles.bodyMedium, textAlign: TextAlign.center),
          ],
        ],
      ),
    );
  }
}
