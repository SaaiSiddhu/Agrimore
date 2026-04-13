import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../../app/themes/app_colors.dart';
import '../../../../../app/themes/app_text_styles.dart';

class SearchBarWidget extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final Function(String) onSubmitted;
  final VoidCallback onClear;
  final VoidCallback onBack;

  const SearchBarWidget({
    Key? key,
    required this.controller,
    required this.focusNode,
    required this.onSubmitted,
    required this.onClear,
    required this.onBack,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          // Back Button
          GestureDetector(
            onTap: () {
              HapticFeedback.lightImpact();
              onBack();
            },
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.lightGrey,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                Icons.arrow_back_rounded,
                color: AppColors.textPrimary,
                size: 24,
              ),
            ),
          ),
          const SizedBox(width: 12),

          // Search Input
          Expanded(
            child: Container(
              height: 50,
              decoration: BoxDecoration(
                color: AppColors.lightGrey,
                borderRadius: BorderRadius.circular(12),
              ),
              child: TextField(
                controller: controller,
                focusNode: focusNode,
                style: AppTextStyles.bodyLarge,
                textInputAction: TextInputAction.search,
                decoration: InputDecoration(
                  hintText: 'Search products...',
                  hintStyle: AppTextStyles.bodyLarge.copyWith(
                    color: AppColors.textSecondary,
                  ),
                  prefixIcon: Icon(
                    Icons.search_rounded,
                    color: AppColors.primary,
                  ),
                  suffixIcon: controller.text.isNotEmpty
                      ? IconButton(
                          icon: Icon(
                            Icons.clear_rounded,
                            color: AppColors.grey,
                          ),
                          onPressed: () {
                            HapticFeedback.lightImpact();
                            onClear();
                          },
                        )
                      : null,
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                ),
                onSubmitted: (value) {
                  HapticFeedback.lightImpact();
                  onSubmitted(value);
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}
