import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../app/themes/app_colors.dart';
import '../../../../app/themes/app_text_styles.dart';
import '../../../../providers/theme_provider.dart';

class SpecificationList extends StatelessWidget {
  final Map<String, String> specifications;
  final bool isDark; // ✅ ADDED

  const SpecificationList({
    Key? key,
    required this.specifications,
    this.isDark = false, // ✅ ADDED
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // This allows the widget to work even if isDark is not passed
    final themeProvider = Provider.of<ThemeProvider>(context, listen: false);
    final bool dark = isDark || themeProvider.isDarkMode; 
    
    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: specifications.entries.map((entry) {
          final isLast = entry == specifications.entries.last;
          return Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              border: !isLast
                  ? Border(
                      bottom: BorderSide(
                        color: dark ? Colors.grey[800]! : Colors.grey[200]!,
                        width: 1,
                      ),
                    )
                  : null,
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 2,
                  child: Text(
                    entry.key,
                    style: AppTextStyles.bodyMedium.copyWith(
                      color: dark ? Colors.grey[400] : AppColors.textSecondary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  flex: 3,
                  child: Text(
                    entry.value,
                    style: AppTextStyles.bodyMedium.copyWith(
                      fontWeight: FontWeight.w600,
                      color: dark ? Colors.white70 : AppColors.textPrimary,
                    ),
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }
}