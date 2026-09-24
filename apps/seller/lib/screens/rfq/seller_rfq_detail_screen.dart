import 'package:agrimore_core/agrimore_core.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../design_system/design_system.dart';
import '../../l10n/app_localizations.dart';
import '../../providers/rfq_provider.dart';
import '../../providers/seller_order_provider.dart';
import '../orders/seller_order_detail_screen.dart';
import 'widgets/quote_copy.dart';
import 'widgets/quote_counter_sheet.dart';
import 'widgets/quote_decline_sheet.dart';

/// Q-02 Quote detail (boards 20-02…20-08, SELLER-RFQ-2): buyer and product,
/// the offer on the table with its expiry and comparison, the negotiation
/// history, and — when it is the seller's turn — Decline · Counter · Accept.
class SellerRfqDetailScreen extends StatelessWidget {
  const SellerRfqDetailScreen({super.key, required this.rfqId, this.now});
  final String rfqId;
  final DateTime? now;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final quote = context.watch<RfqProvider>().byId(rfqId);
    final clock = now ?? DateTime.now();
    return Scaffold(
      appBar: SellerAppBar.detail(
        context,
        title: quote == null ? l10n.quoteDetailTitle : l10n.productOf(quote),
        status: quote == null ? null : QuoteStatusPill(quote: quote, now: clock),
      ),
      body: quote == null
          ? SellerEmptyState(icon: SellerIcons.quote, title: l10n.quoteNotFound)
          : _QuoteBody(quote: quote, now: clock),
    );
  }
}

class _QuoteBody extends StatelessWidget {
  const _QuoteBody({required this.quote, required this.now});
  final RfqModel quote;
  final DateTime now;

  bool get _myTurn =>
      (quote.status == RfqStatus.pending || quote.status == RfqStatus.negotiating) &&
      quote.awaitingResponseFrom == RfqRole.seller;

  Future<void> _counter(BuildContext context) async {
    final offer = await showQuoteCounterSheet(context, quote);
    if (offer == null || !context.mounted) return;
    final provider = context.read<RfqProvider>();
    final ok = await provider.submitOffer(
      rfqId: quote.id,
      price: offer.price,
      quantity: offer.quantity,
      validForDays: offer.validForDays,
      notes: offer.note,
    );
    if (context.mounted) _toast(context, ok, AppLocalizations.of(context).quoteSent, provider.lastError);
  }

  Future<void> _accept(BuildContext context) async {
    final l10n = AppLocalizations.of(context);
    final offer = quote.lastOffer!;
    final yes = await sellerConfirm(
      context,
      icon: SellerIcons.success,
      title: l10n.quoteAcceptTitle,
      message: l10n.quoteAcceptBody(SellerFormat.count(offer.quantity), SellerFormat.money(offer.price), SellerFormat.money(offer.total)),
      confirmLabel: l10n.quoteAccept,
      cancelLabel: l10n.cancel,
    );
    if (!yes || !context.mounted) return;
    final provider = context.read<RfqProvider>();
    final ok = await provider.accept(quote.id);
    if (context.mounted) _toast(context, ok, l10n.quoteAcceptedToast, provider.lastError);
  }

  Future<void> _decline(BuildContext context) async {
    final reason = await showQuoteDeclineSheet(context);
    if (reason == null || !context.mounted) return;
    final l10n = AppLocalizations.of(context);
    final provider = context.read<RfqProvider>();
    final ok = await provider.decline(quote.id, reason: reason);
    if (context.mounted) _toast(context, ok, l10n.quoteDeclinedToast, provider.lastError);
  }

  void _toast(BuildContext context, bool ok, String success, QuoteActionError? error) {
    final l10n = AppLocalizations.of(context);
    SellerToast.show(context, ok ? success : l10n.quoteError(error), tone: ok ? SellerToastTone.success : SellerToastTone.danger);
  }

  OrderModel? _order(BuildContext context, String orderId) =>
      context.watch<SellerOrderProvider>().allOrders.where((o) => o.id == orderId).firstOrNull;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final c = context.colors;
    final text = context.text;
    final offer = quote.lastOffer;
    final expired = offer?.isExpired(now) ?? false;
    final submitting = context.watch<RfqProvider>().isSubmitting;
    final orderId = quote.consumedByOrderId;
    final open = quote.status == RfqStatus.pending || quote.status == RfqStatus.negotiating;
    final order = orderId == null ? null : _order(context, orderId);

    final header = SellerCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          SellerAvatar(name: l10n.buyerOf(quote)),
          const SizedBox(width: SellerSpace.s12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(l10n.buyerOf(quote), style: text.titleSmall),
              Text(l10n.quoteRequested(SellerFormat.date(quote.createdAt)), style: text.bodyMedium),
            ]),
          ),
        ]),
        const Divider(height: SellerSpace.s24),
        Row(children: [
          SellerImage(url: quote.productImageUrl, size: SellerSize.thumbMd),
          const SizedBox(width: SellerSpace.s12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(l10n.productOf(quote), style: text.titleSmall),
              if (quote.listedB2bPrice != null) Text(l10n.quoteListedB2b(SellerFormat.money(quote.listedB2bPrice!)), style: text.bodyMedium),
              if (quote.listedB2bMoq != null) Text(l10n.quoteMoq(SellerFormat.count(quote.listedB2bMoq!)), style: text.bodyMedium),
            ]),
          ),
        ]),
      ]),
    );

    final Widget offerCard;
    if (offer == null) {
      offerCard = SellerEmptyState(icon: SellerIcons.quote, title: l10n.quoteNoPriceTitle, message: l10n.quoteNoPriceBody, compact: true);
    } else {
      final vs = l10n.vsListed(offer.price, quote.listedB2bPrice);
      final fromBuyer = offer.by == RfqRole.buyer;
      offerCard = SellerCard(
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(children: [
            Expanded(child: Semantics(header: true, child: Text(open ? l10n.quoteCurrentOffer : l10n.quoteAgreedTerms, style: text.titleSmall))),
            SellerStatusBadge(
              label: fromBuyer ? l10n.quoteFromBuyer : l10n.quoteFromYou,
              tone: fromBuyer ? SellerTone.info : SellerTone.brand,
              icon: fromBuyer ? SellerIcons.business : SellerIcons.store,
            ),
          ]),
          const SizedBox(height: SellerSpace.s8),
          SellerKeyValueRow(label: l10n.quoteQuantity, value: SellerFormat.count(offer.quantity), tabular: true),
          SellerKeyValueRow(label: l10n.quotePricePerUnit, value: SellerFormat.money(offer.price), tabular: true),
          const Divider(height: SellerSpace.s16),
          SellerKeyValueRow(label: l10n.quoteTotalValue, value: SellerFormat.money(offer.total), emphasis: true, valueColor: c.primary, tabular: true),
          if (vs != null) ...[
            const SizedBox(height: SellerSpace.s8),
            Align(alignment: AlignmentDirectional.centerStart, child: SellerStatusBadge(label: vs, tone: SellerTone.neutral, icon: SellerIcons.percent)),
          ],
          if (open && offer.expiresAt != null) ...[
            const SizedBox(height: SellerSpace.s8),
            QuoteExpiryText(offer: offer, now: now),
          ],
          if ((offer.notes ?? '').trim().isNotEmpty) ...[
            const SizedBox(height: SellerSpace.s12),
            SellerCard(
              tone: SellerCardTone.sunken,
              padding: const EdgeInsets.all(SellerSpace.s12),
              child: MergeSemantics(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(l10n.quoteBuyerNote, style: text.labelLarge),
                  Text(offer.notes!.trim(), style: text.bodyMedium!.copyWith(color: c.textPrimary)),
                ]),
              ),
            ),
          ],
        ]),
      );
    }

    Widget? banner;
    if (quote.status == RfqStatus.accepted) {
      banner = SellerBanner(
        tone: SellerTone.success,
        icon: SellerIcons.success,
        message: orderId != null
            ? l10n.quoteOrderedBanner
            : l10n.quoteAcceptedBanner(SellerFormat.money(quote.finalPrice ?? 0), SellerFormat.count(quote.finalQuantity ?? 0)),
      );
    } else if (quote.status == RfqStatus.rejected) {
      banner = SellerBanner(tone: SellerTone.neutral, icon: SellerIcons.cancelled, message: l10n.quoteDeclinedBanner);
    } else if (!_myTurn) {
      banner = SellerBanner(tone: SellerTone.info, icon: SellerIcons.hourglass, message: l10n.quoteWaitingBanner);
    } else if (expired) {
      banner = SellerBanner(
        tone: SellerTone.warning,
        icon: SellerIcons.timer,
        title: offer?.expiresAt == null ? null : l10n.quoteExpiredOn(SellerFormat.date(offer!.expiresAt!)),
        message: l10n.quoteAcceptExpiredHint,
      );
    }

    final history = [
      for (final h in quote.history)
        SellerTimelineStep(
          title: l10n.quoteHistoryHeader(h.actor == RfqRole.seller ? l10n.quoteByYou : l10n.quoteByBuyer, switch (h.action) {
            'create' => l10n.quoteActionCreate,
            'offer' => l10n.quoteActionOffer,
            'accept' => l10n.quoteActionAccept,
            'reject' => l10n.quoteActionReject,
            _ => h.action,
          }),
          subtitle: SellerFormat.dateTime(h.at),
          state: SellerStepState.done,
          detail: (h.price == null || h.quantity == null) && (h.notes ?? '').isEmpty
              ? null
              : Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  if (h.price != null && h.quantity != null)
                    Text(
                      l10n.quoteTermsLine(SellerFormat.count(h.quantity!), SellerFormat.money(h.price!), SellerFormat.money(h.price! * h.quantity!)),
                      style: text.bodyMedium!.copyWith(color: c.textPrimary).tabular,
                    ),
                  if ((h.notes ?? '').isNotEmpty) Text(h.notes!, style: text.bodyMedium),
                ]),
        ),
      if (_myTurn) SellerTimelineStep(title: l10n.quoteNotResponded, subtitle: l10n.quoteAwaitingYou, state: SellerStepState.current),
    ];

    final footer = !_myTurn
        ? null
        : offer == null
            ? SellerButton(label: l10n.quoteCounter, icon: SellerIcons.counter, expand: true, onPressed: submitting ? null : () => _counter(context))
            : SellerButtonBar(stackBelow: 300, children: [
                SellerButton.dangerOutline(label: l10n.quoteDecline, icon: SellerIcons.cancelled, onPressed: submitting ? null : () => _decline(context)),
                SellerButton.secondary(label: l10n.quoteCounter, icon: SellerIcons.counter, onPressed: submitting ? null : () => _counter(context)),
                SellerButton(
                  label: l10n.quoteAccept,
                  icon: SellerIcons.check,
                  loading: submitting,
                  // The server refuses to accept an expired offer.
                  onPressed: expired ? null : () => _accept(context),
                ),
              ]);

    return SellerPage(
      gap: SellerSpace.s16,
      footer: footer,
      children: [
        header,
        offerCard,
        if (banner != null) banner,
        if (orderId != null)
          SellerMenuGroup(children: [
            SellerListRow(
              icon: SellerIcons.document,
              title: order == null ? l10n.quoteViewOrder : l10n.paymentsForOrder(order.orderNumber),
              subtitle: l10n.quoteLinkedOrderSub,
              trailing: order == null ? null : Text(l10n.quoteViewOrder, style: text.labelLarge!.copyWith(color: c.primary)),
              onTap: order == null
                  ? null
                  : () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => SellerOrderDetailScreen(order: order))),
            ),
          ]),
        if (quote.status == RfqStatus.accepted && orderId == null)
          Text(l10n.quoteAcceptNotOrder, style: text.bodyMedium),
        if (history.isNotEmpty)
          SellerCard(
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Semantics(header: true, child: Text(l10n.quoteHistoryTitle, style: text.titleSmall)),
              const SizedBox(height: SellerSpace.s12),
              SellerTimeline(steps: history, showCurrentPill: false),
            ]),
          ),
      ],
    );
  }
}
