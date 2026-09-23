import 'package:agrimore_ui/agrimore_ui.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

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
    Widget scaffold(Widget body) => Scaffold(
          appBar: AppBar(
            leading: IconButton(
              tooltip: l10n.back,
              icon: const Icon(AgIcons.arrowLeft),
              onPressed: () => Navigator.of(context).maybePop(),
            ),
            title: Text(l10n.reviewsTitle),
          ),
          body: body,
        );
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
          return Padding(
            padding: const EdgeInsets.all(WsSpace.page),
            child: SaInfoBanner(variant: SaBannerVariant.error, message: l10n.reviewsLoadFailed),
          );
        }
        if (!snap.hasData) return const Center(child: CircularProgressIndicator());
        return _body([for (final d in snap.data!.docs) SellerReview.fromDoc(d.id, d.data())]);
      },
    ));
  }

  Widget _body(List<SellerReview> all) {
    final l10n = AppLocalizations.of(context);
    final t = context.ws;
    final text = context.wsText;
    final now = widget.now ?? DateTime.now();
    final summary = ReviewSummary.of(all);
    final shown = all.where(_filter.matches).toList();

    Widget chip(String label, ReviewFilter f) => Padding(
          padding: const EdgeInsets.only(right: WsSpace.s8),
          child: ChoiceChip(
            label: Text(label),
            selected: _filter.stars == f.stars && _filter.unansweredOnly == f.unansweredOnly,
            onSelected: (_) => setState(() => _filter = f),
          ),
        );

    final notice = _notice;
    return ListView(
      padding: const EdgeInsets.symmetric(vertical: WsSpace.s16),
      children: [
        if (notice != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(WsSpace.page, 0, WsSpace.page, WsSpace.s12),
            child: SaInfoBanner(
              variant: notice.$2 ? SaBannerVariant.error : SaBannerVariant.success,
              message: notice.$1,
            ),
          ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: WsSpace.page),
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(WsSpace.s16),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(summary.total == 0 ? '—' : summary.average.toStringAsFixed(1),
                      style: text.headlineMedium!.copyWith(fontFeatures: WsType.tabularFigures)),
                  _Stars(rating: summary.average.round()),
                  const SizedBox(height: WsSpace.s4),
                  Text(l10n.reviewsCount(summary.total), style: text.bodySmall!.copyWith(color: t.textSecondary)),
                ]),
                const SizedBox(width: WsSpace.s24),
                Expanded(
                  child: Column(children: [
                    for (var s = 5; s >= 1; s--)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: WsSpace.s2),
                        child: Semantics(
                          label: l10n.reviewsBarLabel(s, summary.counts[s]),
                          excludeSemantics: true,
                          child: Row(children: [
                            SizedBox(width: WsSpace.s16, child: Text(AgFormat.count(s), style: text.bodySmall)),
                            Expanded(
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(WsRadius.pill),
                                child: LinearProgressIndicator(
                                  value: summary.total == 0 ? 0 : summary.counts[s] / summary.total,
                                  minHeight: WsSpace.s8,
                                  backgroundColor: t.surfaceSunken,
                                  color: t.primary,
                                ),
                              ),
                            ),
                            const SizedBox(width: WsSpace.s8),
                            SizedBox(
                              width: WsSpace.s32,
                              child: Text(AgFormat.count(summary.counts[s]), style: text.bodySmall, textAlign: TextAlign.end),
                            ),
                          ]),
                        ),
                      ),
                  ]),
                ),
              ]),
            ),
          ),
        ),
        SizedBox(
          height: WsSize.chipHeight + WsSpace.s24,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: WsSpace.page, vertical: WsSpace.s12),
            children: [
              chip(l10n.reviewsAll, const ReviewFilter()),
              chip(l10n.reviewsUnanswered(summary.unanswered), const ReviewFilter(unansweredOnly: true)),
              for (var s = 5; s >= 1; s--) chip(l10n.reviewsStars(s), ReviewFilter(stars: s)),
            ],
          ),
        ),
        if (shown.isEmpty)
          Padding(
            padding: const EdgeInsets.all(WsSpace.s32),
            child: Column(children: [
              Icon(AgIcons.star, size: WsIconSize.empty, color: t.textTertiary),
              const SizedBox(height: WsSpace.s12),
              Text(all.isEmpty ? l10n.reviewsEmpty : l10n.reviewsNoneMatch, style: text.bodyMedium, textAlign: TextAlign.center),
            ]),
          )
        else
          for (final r in shown)
            Padding(
              padding: const EdgeInsets.fromLTRB(WsSpace.page, 0, WsSpace.page, WsSpace.s8),
              child: _ReviewCard(review: r, canReply: r.canReply(now), onReply: () => _reply(r)),
            ),
      ],
    );
  }
}

class _Stars extends StatelessWidget {
  const _Stars({required this.rating});
  final int rating;

  @override
  Widget build(BuildContext context) {
    final t = context.ws;
    return ExcludeSemantics(
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        for (var i = 1; i <= 5; i++)
          Icon(AgIcons.star, size: WsIconSize.supporting, color: i <= rating ? t.warningFg : t.disabledContent),
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
    final t = context.ws;
    final text = context.wsText;
    final r = review;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(WsSpace.s16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Semantics(label: l10n.reviewsRatingLabel(r.rating), child: _Stars(rating: r.rating)),
          const SizedBox(height: WsSpace.s4),
          Text(
            l10n.reviewsByLine(r.userName.isEmpty ? l10n.reviewsAnonymous : r.userName,
                r.createdAt == null ? '' : AgFormat.date(r.createdAt!)),
            style: text.bodySmall!.copyWith(color: t.textSecondary),
          ),
          if (r.productName.isNotEmpty) Text(r.productName, style: text.labelMedium),
          if (r.verified) ...[
            const SizedBox(height: WsSpace.s4),
            Row(children: [
              Icon(AgIcons.badgeCheck, size: WsIconSize.supporting, color: t.successFg),
              const SizedBox(width: WsSpace.s4),
              Text(l10n.reviewsVerified, style: text.labelMedium!.copyWith(color: t.successFg)),
            ]),
          ],
          if (r.title.isNotEmpty) ...[const SizedBox(height: WsSpace.s8), Text(r.title, style: text.titleSmall)],
          if (r.comment.isNotEmpty) ...[const SizedBox(height: WsSpace.s4), Text(r.comment, style: text.bodyMedium)],
          if (r.answered) ...[
            const SizedBox(height: WsSpace.s12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(WsSpace.s12),
              decoration: BoxDecoration(color: t.primarySubtle, borderRadius: BorderRadius.circular(WsRadius.small)),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(l10n.reviewsYourReply, style: text.labelMedium),
                const SizedBox(height: WsSpace.s4),
                Text(r.replyText!, style: text.bodyMedium),
              ]),
            ),
          ],
          if (canReply) ...[
            const SizedBox(height: WsSpace.s8),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: onReply,
                icon: const Icon(AgIcons.chat),
                label: Text(r.answered ? l10n.reviewsEditReply : l10n.reviewsReply),
              ),
            ),
          ],
        ]),
      ),
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
    final text = context.wsText;
    final value = _text.text.trim();
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(WsSpace.page, 0, WsSpace.page, WsSpace.s24),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Text(l10n.reviewsReplyTitle, style: text.titleMedium),
            const SizedBox(height: WsSpace.s4),
            Text(l10n.reviewsReplyHint, style: text.bodySmall),
            const SizedBox(height: WsSpace.s12),
            TextField(
              key: const ValueKey('replyText'),
              controller: _text,
              autofocus: true,
              minLines: 3,
              maxLines: 6,
              maxLength: kReplyMax,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(labelText: l10n.reviewsReplyLabel, alignLabelWithHint: true),
            ),
            const SizedBox(height: WsSpace.s8),
            FilledButton(
              onPressed: value.isEmpty ? null : () => Navigator.of(context).pop(value),
              child: Text(l10n.reviewsReplySend),
            ),
          ]),
        ),
      ),
    );
  }
}
