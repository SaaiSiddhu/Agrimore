import 'package:flutter/material.dart';
import '../../app/themes/app_colors.dart';
import '../../app/themes/app_text_styles.dart';

enum ButtonType { primary, secondary, outlined, text }

class CustomButton extends StatelessWidget {
  final String text;
  final VoidCallback? onPressed;
  final ButtonType type;
  final bool isLoading;
  final IconData? icon;
  final Color? backgroundColor;
  final Color? textColor;
  final double? width;
  final double height;
  final EdgeInsetsGeometry? padding;

  const CustomButton({
    Key? key,
    required this.text,
    this.onPressed,
    this.type = ButtonType.primary,
    this.isLoading = false,
    this.icon,
    this.backgroundColor,
    this.textColor,
    this.width,
    this.height = 56,
    this.padding,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (type == ButtonType.outlined) {
      return _buildOutlinedButton(context);
    } else if (type == ButtonType.text) {
      return _buildTextButton(context);
    } else {
      return _buildElevatedButton(context);
    }
  }

  Widget _buildElevatedButton(BuildContext context) {
    return SizedBox(
      width: width ?? double.infinity,
      height: height,
      child: ElevatedButton(
        onPressed: isLoading ? null : onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: backgroundColor ?? 
              (type == ButtonType.secondary ? AppColors.secondary : AppColors.primary),
          foregroundColor: textColor ?? Colors.white,
          padding: padding ?? const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: 2,
        ),
        child: isLoading
            ? const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              )
            : icon != null
                ? Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(icon, size: 20),
                      const SizedBox(width: 8),
                      Text(
                        text,
                        style: AppTextStyles.buttonMedium.copyWith(
                          color: textColor ?? Colors.white,
                        ),
                      ),
                    ],
                  )
                : Text(
                    text,
                    style: AppTextStyles.buttonMedium.copyWith(
                      color: textColor ?? Colors.white,
                    ),
                  ),
      ),
    );
  }

  Widget _buildOutlinedButton(BuildContext context) {
    return SizedBox(
      width: width ?? double.infinity,
      height: height,
      child: OutlinedButton(
        onPressed: isLoading ? null : onPressed,
        style: OutlinedButton.styleFrom(
          foregroundColor: textColor ?? AppColors.primary,
          padding: padding ?? const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          side: BorderSide(
            color: backgroundColor ?? AppColors.primary,
            width: 1.5,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: isLoading
            ? const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
                ),
              )
            : icon != null
                ? Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(icon, size: 20),
                      const SizedBox(width: 8),
                      Text(
                        text,
                        style: AppTextStyles.buttonMedium.copyWith(
                          color: textColor ?? AppColors.primary,
                        ),
                      ),
                    ],
                  )
                : Text(
                    text,
                    style: AppTextStyles.buttonMedium.copyWith(
                      color: textColor ?? AppColors.primary,
                    ),
                  ),
      ),
    );
  }

  Widget _buildTextButton(BuildContext context) {
    return SizedBox(
      width: width,
      height: height,
      child: TextButton(
        onPressed: isLoading ? null : onPressed,
        style: TextButton.styleFrom(
          foregroundColor: textColor ?? AppColors.primary,
          padding: padding ?? const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
        child: isLoading
            ? const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
                ),
              )
            : icon != null
                ? Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(icon, size: 20),
                      const SizedBox(width: 8),
                      Text(
                        text,
                        style: AppTextStyles.buttonMedium.copyWith(
                          color: textColor ?? AppColors.primary,
                        ),
                      ),
                    ],
                  )
                : Text(
                    text,
                    style: AppTextStyles.buttonMedium.copyWith(
                      color: textColor ?? AppColors.primary,
                    ),
                  ),
      ),
    );
  }
}
