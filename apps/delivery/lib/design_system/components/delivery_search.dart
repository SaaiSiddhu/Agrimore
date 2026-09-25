import 'package:flutter/material.dart';

import '../icons/delivery_icons.dart';
import '../tokens/delivery_colors.dart';
import '../tokens/delivery_tokens.dart';
import '../tokens/delivery_typography.dart';

/// Search bar with leading search icon and instant clear button.
class DeliverySearchField extends StatelessWidget {
  const DeliverySearchField({
    super.key,
    required this.controller,
    required this.hintText,
    this.onChanged,
    this.onClear,
    this.clearTooltip = 'Clear search',
  });

  final TextEditingController controller;
  final String hintText;
  final ValueChanged<String>? onChanged;
  final VoidCallback? onClear;
  final String clearTooltip;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final t = context.text;

    return ValueListenableBuilder<TextEditingValue>(
      valueListenable: controller,
      builder: (context, value, _) {
        return TextField(
          controller: controller,
          onChanged: onChanged,
          style: t.bodyMedium.copyWith(color: c.textPrimary),
          textInputAction: TextInputAction.search,
          decoration: InputDecoration(
            hintText: hintText,
            prefixIcon: Icon(
              DeliveryIcons.search,
              size: DeliveryIconSize.md,
              color: c.iconMuted,
            ),
            suffixIcon: value.text.isNotEmpty
                ? IconButton(
                    tooltip: clearTooltip,
                    onPressed: () {
                      controller.clear();
                      onChanged?.call('');
                      onClear?.call();
                    },
                    icon: Icon(
                      DeliveryIcons.close,
                      size: DeliveryIconSize.sm,
                      color: c.iconMuted,
                    ),
                  )
                : null,
          ),
        );
      },
    );
  }
}
