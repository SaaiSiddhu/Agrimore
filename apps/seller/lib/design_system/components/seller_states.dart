import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../icons/seller_icons.dart';
import '../tokens/seller_colors.dart';
import '../tokens/seller_motion.dart';
import '../tokens/seller_tokens.dart';
import '../tokens/seller_typography.dart';
import 'seller_button.dart';

/// Indeterminate progress. With reduced motion it is a static hourglass
/// (board 24-05: progress stays clear without animation).
class SellerSpinner extends StatelessWidget {
  const SellerSpinner({super.key, this.size = SellerIconSize.lg, this.color, this.semanticLabel});

  final double size;
  final Color? color;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final tint = color ?? c.primary;
    final Widget body = context.reduceMotion
        ? Icon(SellerIcons.hourglass, size: size, color: tint)
        : SizedBox.square(
            dimension: size,
            child: CircularProgressIndicator(strokeWidth: size / 10, color: tint, backgroundColor: Colors.transparent),
          );
    if (semanticLabel == null) return ExcludeSemantics(child: body);
    return Semantics(label: semanticLabel, liveRegion: true, child: ExcludeSemantics(child: body));
  }
}

/// Spinner + message, e.g. "Loading your seller account", "Refreshing…".
class SellerProgressLabel extends StatelessWidget {
  const SellerProgressLabel({super.key, required this.label, this.center = true});

  final String label;
  final bool center;

  @override
  Widget build(BuildContext context) {
    final row = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const SellerSpinner(size: SellerIconSize.md),
        const SizedBox(width: SellerSpace.s12),
        Flexible(child: Text(label, style: context.text.bodyMedium)),
      ],
    );
    return Semantics(
      liveRegion: true,
      label: label,
      child: ExcludeSemantics(child: center ? Center(child: row) : row),
    );
  }
}

/// A whole-area loading state for first loads.
class SellerLoadingView extends StatelessWidget {
  const SellerLoadingView({super.key, this.label});
  final String? label;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(SellerSpace.s24),
        child: SellerProgressLabel(label: label ?? AppLocalizations.of(context).dsLoading),
      ),
    );
  }
}

/// A placeholder block for loading content. Pulses gently; static with
/// reduced motion ("replace shimmer with static placeholders").
class SellerSkeleton extends StatefulWidget {
  const SellerSkeleton({super.key, this.width, this.height = SellerSpace.s12, this.radius = SellerRadius.xs});

  final double? width;
  final double height;
  final double radius;

  @override
  State<SellerSkeleton> createState() => _SellerSkeletonState();
}

class _SellerSkeletonState extends State<SellerSkeleton> with SingleTickerProviderStateMixin {
  late final AnimationController _pulse = AnimationController(vsync: this, duration: SellerMotion.slow * 3);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (context.reduceMotion) {
      _pulse.stop();
      _pulse.value = 0;
    } else if (!_pulse.isAnimating) {
      _pulse.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return AnimatedBuilder(
      animation: _pulse,
      builder: (context, _) => Container(
        width: widget.width,
        height: widget.height,
        decoration: BoxDecoration(
          color: Color.lerp(c.sunken, c.border, _pulse.value * 0.6),
          borderRadius: BorderRadius.circular(widget.radius),
        ),
      ),
    );
  }
}

/// Skeleton rows shaped like list items (thumbnail + two lines), board 13.
class SellerSkeletonList extends StatelessWidget {
  const SellerSkeletonList({super.key, this.count = 4, this.thumbnail = true, this.label});

  final int count;
  final bool thumbnail;

  /// Announced to screen readers once ("Loading orders").
  final String? label;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: label ?? AppLocalizations.of(context).dsLoading,
      liveRegion: true,
      child: ExcludeSemantics(
        child: Column(
          children: [
            for (var i = 0; i < count; i++)
              Padding(
                padding: const EdgeInsets.only(bottom: SellerSpace.s12),
                child: Row(
                  children: [
                    if (thumbnail) ...[
                      const SellerSkeleton(width: SellerSize.thumbMd, height: SellerSize.thumbMd, radius: SellerRadius.control),
                      const SizedBox(width: SellerSpace.s12),
                    ],
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          FractionallySizedBox(widthFactor: 0.7, child: SellerSkeleton(height: SellerSpace.s16)),
                          SizedBox(height: SellerSpace.s8),
                          FractionallySizedBox(widthFactor: 0.45, child: SellerSkeleton()),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// "Nothing here yet" (board 13: empty ≠ no-match — callers pass different copy
/// and actions for the two).
class SellerEmptyState extends StatelessWidget {
  const SellerEmptyState({
    super.key,
    required this.title,
    this.message,
    this.icon = SellerIcons.packageOpen,
    this.actionLabel,
    this.onAction,
    this.actionIcon,
    this.secondaryActionLabel,
    this.onSecondaryAction,
    this.compact = false,
  });

  final String title;
  final String? message;
  final IconData icon;
  final String? actionLabel;
  final VoidCallback? onAction;
  final IconData? actionIcon;
  final String? secondaryActionLabel;
  final VoidCallback? onSecondaryAction;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final text = context.text;
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: SellerSpace.s24, vertical: compact ? SellerSpace.s16 : SellerSpace.s32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ExcludeSemantics(
            child: Container(
              width: compact ? SellerSize.avatarLg : SellerSize.avatarXl,
              height: compact ? SellerSize.avatarLg : SellerSize.avatarXl,
              decoration: BoxDecoration(color: c.primaryContainer, shape: BoxShape.circle),
              child: Icon(icon, size: compact ? SellerIconSize.lg : SellerIconSize.xl, color: c.onPrimaryContainer),
            ),
          ),
          const SizedBox(height: SellerSpace.s16),
          Semantics(header: true, child: Text(title, style: text.titleMedium, textAlign: TextAlign.center)),
          if (message != null) ...[
            const SizedBox(height: SellerSpace.s8),
            Text(message!, style: text.bodyMedium, textAlign: TextAlign.center),
          ],
          if (actionLabel != null && onAction != null) ...[
            const SizedBox(height: SellerSpace.s20),
            SellerButton(label: actionLabel!, onPressed: onAction, icon: actionIcon, expand: false),
          ],
          if (secondaryActionLabel != null && onSecondaryAction != null) ...[
            const SizedBox(height: SellerSpace.s8),
            SellerButton.tertiary(label: secondaryActionLabel!, onPressed: onSecondaryAction),
          ],
        ],
      ),
    );
  }
}

/// A block that failed to load: what happened and a way to try again (board 13).
class SellerErrorState extends StatelessWidget {
  const SellerErrorState({super.key, required this.title, this.message, this.onRetry, this.retryLabel});

  final String title;
  final String? message;
  final VoidCallback? onRetry;
  final String? retryLabel;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final text = context.text;
    return Semantics(
      liveRegion: true,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: SellerSpace.s24, vertical: SellerSpace.s32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ExcludeSemantics(
              child: Container(
                width: SellerSize.avatarXl,
                height: SellerSize.avatarXl,
                decoration: BoxDecoration(color: c.dangerContainer, shape: BoxShape.circle),
                child: Icon(SellerIcons.error, size: SellerIconSize.xl, color: c.danger),
              ),
            ),
            const SizedBox(height: SellerSpace.s16),
            Text(title, style: text.titleMedium, textAlign: TextAlign.center),
            if (message != null) ...[
              const SizedBox(height: SellerSpace.s8),
              Text(message!, style: text.bodyMedium, textAlign: TextAlign.center),
            ],
            if (onRetry != null) ...[
              const SizedBox(height: SellerSpace.s20),
              SellerButton(
                label: retryLabel ?? AppLocalizations.of(context).dsTryAgain,
                onPressed: onRetry,
                icon: SellerIcons.refresh,
                expand: false,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
