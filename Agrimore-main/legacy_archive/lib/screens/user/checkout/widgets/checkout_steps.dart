import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:provider/provider.dart';
import '../../../../app/themes/app_colors.dart';
import '../../../../providers/theme_provider.dart';

class CheckoutSteps extends StatelessWidget {
  final int currentStep;

  const CheckoutSteps({
    Key? key,
    required this.currentStep,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final isDark = context.watch<ThemeProvider>().isDarkMode;
    final accentColor = isDark ? AppColors.primaryLight : AppColors.primary;
    final cardColor = isDark ? const Color(0xFF1E1E1E) : Colors.white;

    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? Colors.grey[800]! : Colors.grey[200]!,
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.3 : 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          _buildStep(
            context,
            step: 1,
            icon: FontAwesomeIcons.locationDot,
            label: 'Address',
            isActive: currentStep >= 1,
            isCompleted: currentStep > 1,
            isDark: isDark,
            accentColor: accentColor,
          ),
          _buildConnector(currentStep >= 2, isDark, accentColor),
          _buildStep(
            context,
            step: 2,
            icon: FontAwesomeIcons.creditCard,
            label: 'Payment',
            isActive: currentStep >= 2,
            isCompleted: currentStep > 2,
            isDark: isDark,
            accentColor: accentColor,
          ),
        ],
      ),
    );
  }

  Widget _buildStep(
    BuildContext context, {
    required int step,
    required IconData icon,
    required String label,
    required bool isActive,
    required bool isCompleted,
    required bool isDark,
    required Color accentColor,
  }) {
    return Expanded(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: isActive
                  ? accentColor
                  : (isDark ? Colors.grey[800] : Colors.grey[200]),
              shape: BoxShape.circle,
              boxShadow: isActive
                  ? [
                      BoxShadow(
                        color: accentColor.withValues(alpha: 0.1),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ]
                  : null,
            ),
            child: Center(
              child: isCompleted
                  ? Icon(
                      Icons.check_rounded,
                      color: isDark ? Colors.black : Colors.white,
                      size: 20,
                    )
                  : FaIcon(
                      icon,
                      color: isActive
                          ? (isDark ? Colors.black : Colors.white)
                          : (isDark ? Colors.grey[600] : Colors.grey[500]),
                      size: 16,
                    ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: isActive ? FontWeight.w800 : FontWeight.w600,
              color: isActive
                  ? accentColor
                  : (isDark ? Colors.grey[500] : Colors.grey[600]),
              letterSpacing: -0.2,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildConnector(bool isActive, bool isDark, Color accentColor) {
    return Expanded(
      child: Container(
        height: 2,
        margin: const EdgeInsets.only(bottom: 28, left: 8, right: 8),
        decoration: BoxDecoration(
          color: isActive
              ? accentColor
              : (isDark ? Colors.grey[800] : Colors.grey[300]),
          borderRadius: BorderRadius.circular(1),
        ),
      ),
    );
  }
}
