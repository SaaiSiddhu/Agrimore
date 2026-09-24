import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../design_system/design_system.dart';
import '../../l10n/app_localizations.dart';
import '../../providers/seller_auth_provider.dart';
import 'review_rules.dart';

/// Sends a reply; injected in tests. Returns null on success or an error key.
typedef ReviewReplier = Future<String?> Function(SellerReview review, String text);

/// M-03 Reviews (ADR §10.6, SELLER-ACCOUNT-1a): rating summary with
/// distribution, filters by stars / unanswered, one public reply per review
/// (editable for 24 h). Ratings are computed server-side.
class SellerReviewsScreen extends StatefulWidget {
  const SellerReviewsScreen({super.key, this.reviews, this.replier, this.now});

  final List<SellerReview>? reviews;
  final ReviewReplier? replier;
  final DateTime? now;

  @override
  State<SellerReviewsScreen> createState() => _SellerReviewsScreenState();
}

class _SellerReviewsScreenState extends State<SellerReviewsScreen> {
  static const int _limit = 200;
  ReviewFilter _filter = const ReviewFilter();

  /// Outcome of the last reply: (message, isError); shown inline.
  (String, bool)? _notice;

  Future<String?> _defaultReply(SellerReview r, String text) async {
    try {
      await FirebaseFunctions.instance
          .httpsCallable('replyToReview')
          .call<Map<String, dynamic>>({'productId': r.productId, 'reviewId': r.id, 'text': text});
      return null;
    } on FirebaseFunctionsException catch (e) {
      debugPrint('replyToReview failed: ${e.code} ${e.message}');
      return e.code == 'failed-precondition' ? 'locked' : 'failed';
    } catch (e) {
      debugPrint('replyToReview failed: $e');
      return 'failed';
    }
  }

  Future<void> _reply(SellerReview r) async {
    final l10n = AppLocalizations.of(context);
    final text = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => _ReplySheet(review: r),
    );
    if (text == null || !mounted) return;
    final err = await (widget.replier ?? _defaultReply)(r, text);
    if (!mounted) return;
    setState(() => _notice = err == null
        ? (l10n.reviewReplySent, false)
        : (err == 'locked' ? l10n.reviewReplyLocked : l10n.reviewReplyFailed, true));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final injected = widget.reviews;
    Widget scaffold(Widget body) => Scaffold(appBar: SellerAppBar.detail(context, title: l10n.reviewsTitle), body: body);
    if (injected != null) return scaffold(_body(injected));
    final uid = context.read<SellerAuthProvider>().currentUser?.uid;
    if (uid == null) return scaffold(const SizedBox.shrink());
    return scaffold(StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collectionGroup('reviews')
          .where('sellerId', isEqualTo: uid)
          .orderBy('createdAt', descending: true)
          .limit(_limit)
          .snapshots(),
      builder: (context, snap) {
        if (snap.hasError) {
          debugPrint('Reviews failed: ${snap.error}');
          return SellerErrorState(title: l10n.reviewsLoadFailed);
        }
        if (!snap.hasData) return SellerSkeletonList(label: l10n.dsLoading, thumbnail: false);
        return _body([
          for (final d in snap.data!.docs)
            if (d.data()['supersededBy'] == null) SellerReview.fromDoc(d.id, d.data()),
        ]);
      },
    ));
  }

  Widget _body(List<SellerReview> all) {
    final l10n = AppLocalizations.of(context);
    final text = context.text;
    final now = widget.now ?? DateTime.now();
    final summary = ReviewSummary.of(all);
    final shown = all.where(_filter.matches).toList();
    bool on(ReviewFilter f) => _filter.stars == f.stars && _filter.unansweredOnly == f.unansweredOnly;
    final notice = _notice;

    return SellerPage(
      gap: SellerSpace.s16,
      children: [
        if (notice != null)
          SellerBanner(tone: notice.$2 ? SellerTone.danger : SellerTone.success, message: notice.$1, announce: true),
        SellerCard(
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Text(summary.total == 0 ? '—' : summary.average.toStringAsFixed(1), style: text.displayLarge!.tabular),
              const SizedBox(width: SellerSpace.s8),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  SellerStars(rating: summary.average),
                  Text(l10n.reviewsCount(summary.total), style: text.bodyMedium),
                ]),
              ),
            ]),
            const SizedBox(height: SellerSpace.s12),
            SellerBarList(
              max: summary.total == 0 ? 1 : summary.total.toDouble(),
              items: [
                for (var s = 5; s >= 1; s--)
                  SellerBarItem(
                    label: l10n.reviewsStars(s),
                    caption: l10n.reviewsCount(summary.counts[s]),
                    value: summary.counts[s].toDouble(),
                    valueLabel: SellerFormat.percent(summary.total == 0 ? 0 : summary.counts[s] / summary.total),
                    tone: SellerTone.brand,
                  ),
              ],
            ),
          ]),
        ),
        SellerChipBar(padding: EdgeInsets.zero, children: [
          SellerChip(label: l10n.reviewsAll, selected: on(const ReviewFilter()), onSelected: (_) => setState(() => _filter = const ReviewFilter())),
          SellerChip(
            label: l10n.reviewsUnanswered(summary.unanswered),
            selected: on(const ReviewFilter(unansweredOnly: true)),
            onSelected: (_) => setState(() => _filter = const ReviewFilter(unansweredOnly: true)),
          ),
          for (var s = 5; s >= 1; s--)
            SellerChip(label: l10n.reviewsStars(s), selected: on(ReviewFilter(stars: s)), onSelected: (_) => setState(() => _filter = ReviewFilter(stars: s))),
        ]),
        if (shown.isEmpty)
          SellerEmptyState(icon: SellerIcons.star, title: all.isEmpty ? l10n.reviewsEmpty : l10n.reviewsNoneMatch)
        else
          for (final r in shown) _ReviewCard(review: r, canReply: r.canReply(now), onReply: () => _reply(r)),
        Text(l10n.reviewsReplyRule, style: text.bodySmall, textAlign: TextAlign.center),
      ],
    );
  }
}

/// Five stars with halves; decorative — the number beside it is read.
class SellerStars extends StatelessWidget {
  const SellerStars({super.key, required this.rating, this.size = SellerIconSize.md});
  final double rating;
  final double size;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return ExcludeSemantics(
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        for (var i = 1; i <= 5; i++)
          Icon(
            rating >= i ? SellerIcons.starFilled : (rating >= i - 0.5 ? SellerIcons.starHalf : SellerIcons.star),
            size: size,
            color: rating >= i - 0.5 ? c.warning : c.controlBorder,
          ),
      ]),
    );
  }
}

class _ReviewCard extends StatelessWidget {
  const _ReviewCard({required this.review, required this.canReply, required this.onReply});
  final SellerReview review;
  final bool canReply;
  final VoidCallback onReply;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final c = context.colors;
    final text = context.text;
    final r = review;
    final name = r.userName.isEmpty ? l10n.reviewsAnonymous : r.userName;
    return SellerCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          SellerAvatar(name: name),
          const SizedBox(width: SellerSpace.s12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(name, style: text.titleSmall),
              if (r.createdAt != null) Text(SellerFormat.date(r.createdAt!), style: text.bodyMedium),
            ]),
          ),
          if (r.verified) SellerStatusBadge(label: l10n.reviewsVerified, tone: SellerTone.success, icon: SellerIcons.verified),
        ]),
        const SizedBox(height: SellerSpace.s8),
        Semantics(label: l10n.reviewsRatingLabel(r.rating), child: SellerStars(rating: r.rating.toDouble())),
        if (r.productName.isNotEmpty) Text(r.productName, style: text.labelLarge!.copyWith(color: c.textSecondary)),
        if (r.title.isNotEmpty) ...[const SizedBox(height: SellerSpace.s8), Text(r.title, style: text.titleSmall)],
        if (r.comment.isNotEmpty) ...[const SizedBox(height: SellerSpace.s4), Text(r.comment, style: text.bodyLarge)],
        if (r.answered) ...[
          const SizedBox(height: SellerSpace.s12),
          SellerCard(
            tone: SellerCardTone.subtle,
            padding: const EdgeInsets.all(SellerSpace.s12),
            child: MergeSemantics(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Icon(SellerIcons.store, size: SellerIconSize.sm, color: c.primary),
                  const SizedBox(width: SellerSpace.s6),
                  Text(l10n.reviewsYourReply, style: text.labelLarge),
                ]),
                const SizedBox(height: SellerSpace.s4),
                Text(r.replyText!, style: text.bodyLarge),
              ]),
            ),
          ),
        ],
        if (canReply) ...[
          const SizedBox(height: SellerSpace.s12),
          r.answered
              ? Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: SellerButton.tertiary(label: l10n.reviewsEditReply, icon: SellerIcons.edit, onPressed: onReply),
                )
              : SellerButton.secondary(label: l10n.reviewsReply, icon: SellerIcons.message, onPressed: onReply),
        ],
      ]),
    );
  }
}

class _ReplySheet extends StatefulWidget {
  const _ReplySheet({required this.review});
  final SellerReview review;

  @override
  State<_ReplySheet> createState() => _ReplySheetState();
}

class _ReplySheetState extends State<_ReplySheet> {
  late final TextEditingController _text = TextEditingController(text: widget.review.replyText ?? '');

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final text = context.text;
    final value = _text.text.trim();
    final r = widget.review;
    return SellerSheetFrame(
      title: l10n.reviewsReplyTitle,
      subtitle: l10n.reviewsReplyHint,
      body: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        if (r.comment.isNotEmpty)
          SellerCard(
            tone: SellerCardTone.sunken,
            padding: const EdgeInsets.all(SellerSpace.s12),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              SellerStars(rating: r.rating.toDouble(), size: SellerIconSize.sm),
              const SizedBox(height: SellerSpace.s4),
              Text(r.comment, style: text.bodyMedium!.copyWith(color: context.colors.textPrimary), maxLines: 4, overflow: TextOverflow.ellipsis),
            ]),
          ),
        const SizedBox(height: SellerSpace.s12),
        SellerTextField(
          fieldKey: const ValueKey('replyText'),
          label: l10n.reviewsReplyLabel,
          controller: _text,
          autofocus: true,
          minLines: 3,
          maxLines: 6,
          maxLength: kReplyMax,
          showCounter: true,
          helper: l10n.reviewsReplyLimit(kReplyMax),
          onChanged: (_) => setState(() {}),
        ),
      ]),
      footer: SellerButtonBar(children: [
        SellerButton.secondary(label: l10n.cancel, onPressed: () => Navigator.of(context).pop()),
        SellerButton(label: l10n.reviewsReplySend, icon: SellerIcons.send, onPressed: value.isEmpty ? null : () => Navigator.of(context).pop(value)),
      ]),
    );
  }
}
