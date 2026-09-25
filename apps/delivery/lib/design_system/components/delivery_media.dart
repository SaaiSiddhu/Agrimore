import 'package:flutter/material.dart';

import '../icons/delivery_icons.dart';
import '../tokens/delivery_colors.dart';
import '../tokens/delivery_tokens.dart';
import '../tokens/delivery_typography.dart';
import 'delivery_badge.dart';
import 'delivery_button.dart';
import 'delivery_card.dart';

enum DeliveryPhotoSlotState { empty, uploading, ready, error }

/// Document / KYC / Proof-of-delivery upload slot with clear status badge,
/// progress indicator, and accessible capture/retake button.
class DeliveryDocUploadTile extends StatelessWidget {
  const DeliveryDocUploadTile({
    super.key,
    required this.title,
    this.subtitle,
    required this.state,
    required this.onTap,
    this.buttonKey,
    this.addLabel = 'Upload photo',
    this.replaceLabel = 'Replace photo',
    this.uploadingLabel = 'Uploading…',
    this.readyLabel = 'Uploaded',
    this.errorText,
    this.icon = DeliveryIcons.camera,
  });

  final String title;
  final String? subtitle;
  final DeliveryPhotoSlotState state;
  final VoidCallback? onTap;
  final Key? buttonKey;
  final String addLabel;
  final String replaceLabel;
  final String uploadingLabel;
  final String readyLabel;
  final String? errorText;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final t = context.text;
    final isReady = state == DeliveryPhotoSlotState.ready;
    final isUploading = state == DeliveryPhotoSlotState.uploading;
    final isError = state == DeliveryPhotoSlotState.error ||
        (errorText != null && errorText!.isNotEmpty);

    final tone = isError
        ? DeliveryTone.danger
        : isReady
            ? DeliveryTone.success
            : DeliveryTone.brand;
    final pair = c.tone(tone);

    return DeliveryCard(
      variant: isReady ? DeliveryCardVariant.standard : DeliveryCardVariant.muted,
      padding: const EdgeInsets.all(DeliverySpace.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: pair.container,
                  borderRadius: DeliveryRadius.rMd,
                  border: Border.all(color: pair.border),
                ),
                alignment: Alignment.center,
                child: isUploading
                    ? SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: pair.icon,
                        ),
                      )
                    : Icon(
                        isReady ? DeliveryIcons.verified : icon,
                        size: DeliveryIconSize.md,
                        color: pair.icon,
                      ),
              ),
              const SizedBox(width: DeliverySpace.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: t.titleSmall),
                    if (subtitle != null && subtitle!.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        subtitle!,
                        style: t.caption.copyWith(color: c.textSecondary),
                      ),
                    ],
                  ],
                ),
              ),
              if (isReady)
                DeliveryBadge(
                  label: readyLabel,
                  tone: DeliveryTone.success,
                  icon: DeliveryIcons.check,
                ),
            ],
          ),
          if (errorText != null && errorText!.isNotEmpty) ...[
            const SizedBox(height: DeliverySpace.xs),
            Text(
              errorText!,
              style: t.caption.copyWith(color: c.danger.onContainer),
            ),
          ],
          const SizedBox(height: DeliverySpace.md),
          DeliveryButton(
            key: buttonKey,
            label: isUploading
                ? uploadingLabel
                : isReady
                    ? replaceLabel
                    : addLabel,
            icon: isReady ? DeliveryIcons.refresh : DeliveryIcons.camera,
            variant: isReady
                ? DeliveryButtonVariant.secondary
                : DeliveryButtonVariant.tonal,
            size: DeliveryButtonSize.sm,
            loading: isUploading,
            expand: true,
            onPressed: isUploading ? null : onTap,
          ),
        ],
      ),
    );
  }
}
