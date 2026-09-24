import 'dart:typed_data';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../format/seller_format.dart';
import '../icons/seller_icons.dart';
import '../theme/seller_focus.dart';
import '../tokens/seller_colors.dart';
import '../tokens/seller_tokens.dart';
import '../tokens/seller_typography.dart';
import 'seller_states.dart';

/// A product/store image with intentional states (board 06): loading
/// (skeleton), no image (image icon) and failed (image-off icon), all in the
/// same frame size. Decoded at the displayed size ([memCacheWidth]).
class SellerImage extends StatelessWidget {
  const SellerImage({
    super.key,
    required this.url,
    required this.size,
    this.height,
    this.radius = SellerRadius.control,
    this.fit = BoxFit.cover,
    this.semanticLabel,
    this.bytes,
  });

  final String? url;

  /// Width (and height when [height] is null).
  final double size;
  final double? height;
  final double radius;
  final BoxFit fit;

  /// Null = decorative (the row around it already names the product).
  final String? semanticLabel;

  /// A local image not uploaded yet.
  final Uint8List? bytes;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final h = height ?? size;
    final dpr = MediaQuery.devicePixelRatioOf(context);
    Widget placeholder(IconData icon) => ColoredBox(
          color: c.sunken,
          child: Center(child: Icon(icon, size: SellerIconSize.lg, color: c.textTertiary)),
        );
    Widget body;
    if (bytes != null) {
      body = Image.memory(bytes!, fit: fit, width: size, height: h, cacheWidth: (size * dpr).round());
    } else if (url == null || url!.trim().isEmpty) {
      body = placeholder(SellerIcons.image);
    } else {
      body = CachedNetworkImage(
        imageUrl: url!,
        fit: fit,
        width: size,
        height: h,
        memCacheWidth: size.isFinite ? (size * dpr).round() : null,
        placeholder: (_, __) => SellerSkeleton(width: size, height: h, radius: 0),
        errorWidget: (_, __, ___) => placeholder(SellerIcons.imageOff),
      );
    }
    final framed = ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: SizedBox(width: size, height: h, child: body),
    );
    return semanticLabel == null
        ? ExcludeSemantics(child: framed)
        : Semantics(image: true, label: semanticLabel, child: ExcludeSemantics(child: framed));
  }
}

/// Store avatar with the board 06 fallback chain: logo → initials on mint →
/// store icon.
class SellerAvatar extends StatelessWidget {
  const SellerAvatar({super.key, this.imageUrl, this.name, this.size = SellerSize.avatarMd, this.icon = SellerIcons.store});

  final String? imageUrl;
  final String? name;
  final double size;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final initials = SellerFormat.initials(name ?? '');
    final fallback = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: c.primaryContainer, shape: BoxShape.circle),
      alignment: Alignment.center,
      child: initials.isNotEmpty
          ? Text(
              initials,
              style: (size >= SellerSize.avatarLg ? context.text.titleLarge : context.text.labelLarge)!.copyWith(color: c.onPrimaryContainer),
            )
          : Icon(icon, size: size / 2, color: c.onPrimaryContainer),
    );
    final url = imageUrl;
    final Widget body = url == null || url.trim().isEmpty
        ? fallback
        : ClipOval(
            child: CachedNetworkImage(
              imageUrl: url,
              width: size,
              height: size,
              fit: BoxFit.cover,
              memCacheWidth: (size * MediaQuery.devicePixelRatioOf(context)).round(),
              placeholder: (_, __) => fallback,
              errorWidget: (_, __, ___) => fallback,
            ),
          );
    return ExcludeSemantics(child: body);
  }
}

/// State of an upload tile (board 15).
enum SellerUploadState { empty, uploading, uploaded, failed }

/// A photo slot: empty (dashed, "Add a photo"), uploading (spinner),
/// uploaded (thumbnail + "Uploaded"), failed ("Upload failed" + Retry).
/// "Uploaded" means received, not approved (board 16-04).
class SellerPhotoTile extends StatelessWidget {
  const SellerPhotoTile({
    super.key,
    required this.label,
    required this.state,
    required this.onTap,
    this.imageUrl,
    this.bytes,
    this.size = SellerSize.thumbLg,
    this.statusLabel,
  });

  final String label;
  final SellerUploadState state;
  final VoidCallback? onTap;
  final String? imageUrl;
  final Uint8List? bytes;
  final double size;

  /// Localised state text ("Uploading…", "Uploaded", "Upload failed").
  final String? statusLabel;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final hasImage = (imageUrl != null && imageUrl!.isNotEmpty) || bytes != null;
    return SellerFocusTracker(
      builder: (context, focused, node) {
        final shape = RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(SellerRadius.control),
          side: sellerOutline(
            c,
            focused: focused,
            rest: state == SellerUploadState.failed ? c.danger : c.border,
          ),
        );
        return Semantics(
          button: onTap != null,
          label: statusLabel == null ? label : '$label, $statusLabel',
          excludeSemantics: true,
          onTap: onTap,
          child: Material(
            color: c.sunken,
            shape: shape,
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              focusNode: node,
              onTap: onTap,
              customBorder: shape,
              child: SizedBox(
                width: size,
                height: size,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    if (hasImage)
                      SellerImage(url: imageUrl, bytes: bytes, size: size, radius: 0)
                    else
                      Center(child: Icon(SellerIcons.imageAdd, size: SellerIconSize.lg, color: c.textSecondary)),
                    if (state == SellerUploadState.uploading)
                      ColoredBox(color: c.scrim, child: Center(child: SellerSpinner(color: c.onPrimary))),
                    if (state == SellerUploadState.failed)
                      ColoredBox(
                        color: c.dangerContainer.withValues(alpha: 0.9),
                        child: Center(child: Icon(SellerIcons.warning, color: c.danger)),
                      ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Decorative helper: text for "no image" / "failed" states for screens that
/// show a caption under a tile.
String sellerImageStateLabel(BuildContext context, SellerUploadState state) {
  final l10n = AppLocalizations.of(context);
  return switch (state) {
    SellerUploadState.failed => l10n.dsImageFailed,
    _ => l10n.dsNoImage,
  };
}
