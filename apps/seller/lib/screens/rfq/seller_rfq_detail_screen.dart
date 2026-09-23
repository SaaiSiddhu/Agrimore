import 'package:agrimore_core/agrimore_core.dart';
import 'package:agrimore_ui/agrimore_ui.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../l10n/app_localizations.dart';
import '../../providers/rfq_provider.dart';
import '../../providers/seller_order_provider.dart';
import '../orders/seller_order_detail_screen.dart';
import 'widgets/quote_copy.dart';
import 'widgets/quote_counter_sheet.dart';
import 'widgets/quote_decline_sheet.dart';

/// Q-02 Quote thread (ADR §10.4, SELLER-RFQ-2): what the buyer asked for,
/// every offer in order, the offer on the table with its expiry, and —
/// when it is the seller's turn — Counter · Accept · Decline.
class SellerRfqDetailScreen extends StatelessWidget {
  const SellerRfqDetailScreen({super.key, required this.rfqId, this.now});
  final String rfqId;
  final DateTime? now;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final quote = context.watch<RfqProvider>().byId(rfqId);
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          tooltip: l10n.back,
          icon: const Icon(AgIcons.arrowLeft),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        title: Text(quote == null ? l10n.quoteDetailTitle : l10n.productOf(quote)),
      ),
      body: quote == null
          ? Padding(
              padding: const EdgeInsets.all(WsSpace.page),
              child: SaInfoBanner(variant: SaBannerVariant.info, message: l10n.quoteNotFound),
            )
          : _QuoteBody(quote: quote, now: now ?? DateTime.now()),
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
    final yes = await wsConfirm(
      context,
      title: l10n.quoteAcceptTitle,
      message: l10n.quoteAcceptBody(AgFormat.count(offer.quantity), AgFormat.rupees(offer.price), AgFormat.rupees(offer.total)),
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
    WsToast.show(context, ok ? success : l10n.quoteError(error), tone: ok ? WsToastTone.success : WsToastTone.error);
  }

  void _openOrder(BuildContext context, String orderId) {
    OrderModel? order;
    for (final o in context.read<SellerOrderProvider>().allOrders) {
      if (o.id == orderId) order = o;
    }
    if (order == null) return;
    final found = order;
    Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => SellerOrderDetailScreen(order: found)));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final t = context.ws;
    final text = context.wsText;
    final offer = quote.lastOffer;
    final expired = offer?.isExpired(now) ?? false;
    final submitting = context.watch<RfqProvider>().isSubmitting;
    final orderId = quote.consumedByOrderId;

    return Column(children: [
      Expanded(
        child: ListView(
          padding: const EdgeInsets.all(WsSpace.page),
          children: [
            // Header: what was asked, by whom, against the listed B2B terms.
            Card(
              child: Padding(
                padding: const EdgeInsets.all(WsSpace.s16),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    Expanded(child: Text(l10n.buyerOf(quote), style: text.titleSmall)),
                    QuoteStatusPill(quote: quote, now: now),
                  ]),
                  const SizedBox(height: WsSpace.s4),
                  Text(l10n.quoteRequested(AgFormat.date(quote.createdAt)),
                      style: text.bodySmall!.copyWith(color: t.textSecondary)),
                  if (quote.listedB2bPrice != null || quote.listedB2bMoq != null) ...[
                    const SizedBox(height: WsSpace.s8),
                    Wrap(spacing: WsSpace.s16, children: [
                      if (quote.listedB2bPrice != null)
                        Text(l10n.quoteListedB2b(AgFormat.rupees(quote.listedB2bPrice!)), style: text.bodyMedium),
                      if (quote.listedB2bMoq != null)
                        Text(l10n.quoteMoq(AgFormat.count(quote.listedB2bMoq!)), style: text.bodyMedium),
                    ]),
                  ],
                ]),
              ),
            ),
            if (offer != null) ...[
              const SizedBox(height: WsSpace.s12),
              _CurrentOffer(quote: quote, offer: offer, now: now),
            ],
            const SizedBox(height: WsSpace.s12),
            if (quote.status == RfqStatus.accepted)
              SaInfoBanner(
                variant: SaBannerVariant.success,
                message: orderId != null
                    ? l10n.quoteOrderedBanner
                    : l10n.quoteAcceptedBanner(
                        AgFormat.rupees(quote.finalPrice ?? 0), AgFormat.count(quote.finalQuantity ?? 0)),
                actionLabel: orderId != null ? l10n.quoteViewOrder : null,
                onAction: orderId != null ? () => _openOrder(context, orderId) : null,
              )
            else if (quote.status == RfqStatus.rejected)
              SaInfoBanner(variant: SaBannerVariant.info, message: l10n.quoteDeclinedBanner)
            else if (!_myTurn)
              SaInfoBanner(variant: SaBannerVariant.info, message: l10n.quoteWaitingBanner)
            else if (expired)
              SaInfoBanner(variant: SaBannerVariant.warning, message: l10n.quoteAcceptExpiredHint),
            const SizedBox(height: WsSpace.s24),
            Text(l10n.quoteHistoryTitle, style: text.titleMedium),
            const SizedBox(height: WsSpace.s8),
            for (final h in quote.history) _HistoryEntry(entry: h),
          ],
        ),
      ),
      if (_myTurn)
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(WsSpace.page, WsSpace.s8, WsSpace.page, WsSpace.s12),
            child: Row(children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: submitting ? null : () => _decline(context),
                  child: Text(l10n.quoteDecline),
                ),
              ),
              const SizedBox(width: WsSpace.s8),
              Expanded(
                child: OutlinedButton(
                  onPressed: submitting ? null : () => _counter(context),
                  child: Text(l10n.quoteCounter),
                ),
              ),
              const SizedBox(width: WsSpace.s8),
              Expanded(
                child: FilledButton(
                  onPressed: submitting || offer == null || expired ? null : () => _accept(context),
                  child: Text(l10n.quoteAccept),
                ),
              ),
            ]),
          ),
        ),
    ]);
  }
}

class _CurrentOffer extends StatelessWidget {
  const _CurrentOffer({required this.quote, required this.offer, required this.now});
  final RfqModel quote;
  final RfqOffer offer;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final t = context.ws;
    final text = context.wsText;
    final open = quote.status == RfqStatus.pending || quote.status == RfqStatus.negotiating;
    final vs = l10n.vsListed(offer.price, quote.listedB2bPrice);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(WsSpace.s16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(open ? l10n.quoteCurrentOffer : l10n.quoteAgreedTerms, style: text.labelLarge),
          const SizedBox(height: WsSpace.s8),
          Text(
            AgFormat.rupees(offer.total),
            style: text.headlineMedium!.copyWith(fontFeatures: WsType.tabularFigures, color: t.primary),
          ),
          const SizedBox(height: WsSpace.s4),
          Text(l10n.quoteQtyAtPrice(AgFormat.count(offer.quantity), AgFormat.rupees(offer.price)),
              style: text.bodyMedium!.copyWith(fontFeatures: WsType.tabularFigures)),
          if (vs != null) ...[
            const SizedBox(height: WsSpace.s4),
            Text(vs, style: text.bodySmall!.copyWith(color: t.textSecondary)),
          ],
          if (open) ...[
            const SizedBox(height: WsSpace.s8),
            QuoteExpiryText(offer: offer, now: now),
          ],
        ]),
      ),
    );
  }
}

class _HistoryEntry extends StatelessWidget {
  const _HistoryEntry({required this.entry});
  final RfqHistoryEntry entry;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final t = context.ws;
    final text = context.wsText;
    final mine = entry.actor == RfqRole.seller;
    final action = switch (entry.action) {
      'create' => l10n.quoteActionCreate,
      'offer' => l10n.quoteActionOffer,
      'accept' => l10n.quoteActionAccept,
      'reject' => l10n.quoteActionReject,
      _ => entry.action,
    };
    final price = entry.price;
    final qty = entry.quantity;
    final notes = entry.notes;
    return Align(
      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: WsSize.formMaxWidth),
        child: Container(
          margin: const EdgeInsets.only(bottom: WsSpace.s8),
          padding: const EdgeInsets.all(WsSpace.s12),
          decoration: BoxDecoration(
            color: mine ? t.primarySubtle : t.surfaceSunken,
            borderRadius: BorderRadius.circular(WsRadius.card),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(l10n.quoteHistoryHeader(mine ? l10n.quoteByYou : l10n.quoteByBuyer, action), style: text.labelMedium),
            if (price != null && qty != null) ...[
              const SizedBox(height: WsSpace.s4),
              Text(
                '${l10n.quoteQtyAtPrice(AgFormat.count(qty), AgFormat.rupees(price))}  ·  ${AgFormat.rupees(price * qty)}',
                style: text.bodyMedium!.copyWith(fontFeatures: WsType.tabularFigures),
              ),
            ],
            if (notes != null && notes.isNotEmpty) ...[
              const SizedBox(height: WsSpace.s4),
              Text(notes, style: text.bodyMedium),
            ],
            const SizedBox(height: WsSpace.s4),
            Text(AgFormat.dateTime(entry.at), style: text.bodySmall!.copyWith(color: t.textTertiary)),
          ]),
        ),
      ),
    );
  }
}
