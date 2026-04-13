import 'package:flutter/material.dart';
import '../themes/app_colors.dart';
import '../themes/app_text_styles.dart';

enum ButtonType { filled, outlined, text }

class CustomButton extends StatelessWidget {
  final String text;
  final VoidCallback? onPressed;
  final ButtonType type;
  final bool isLoading;
  final bool isFullWidth;

  const CustomButton({
    Key? key,
    required this.text,
    this.onPressed,
    this.type = ButtonType.filled,
    this.isLoading = false,
    this.isFullWidth = true,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    Widget child = isLoading
        ? const SizedBox(
            height: 20,
            width: 20,
            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
          )
        : Text(text, style: AppTextStyles.bodyLarge.copyWith(fontWeight: FontWeight.bold, color: Colors.white));

    final button = switch (type) {
      ButtonType.filled => ElevatedButton(
          onPressed: isLoading ? null : onPressed,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
          child: child,
        ),
      ButtonType.outlined => OutlinedButton(
          onPressed: isLoading ? null : onPressed,
          style: OutlinedButton.styleFrom(
            foregroundColor: AppColors.primary,
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
            side: BorderSide(color: AppColors.primary),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
          child: child,
        ),
      ButtonType.text => TextButton(
          onPressed: isLoading ? null : onPressed,
          child: child,
        ),
    };

    return isFullWidth ? SizedBox(width: double.infinity, child: button) : button;
  }
}
