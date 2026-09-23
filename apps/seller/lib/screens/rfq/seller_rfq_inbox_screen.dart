import 'package:agrimore_core/agrimore_core.dart';
import 'package:agrimore_ui/agrimore_ui.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../l10n/app_localizations.dart';
import '../../providers/rfq_provider.dart';
import 'quote_rules.dart';
import 'seller_rfq_detail_screen.dart';
import 'widgets/quote_copy.dart';
import 'widgets/quote_tile.dart';

/// Q-01 Quotes inbox (ADR §10.4, SELLER-RFQ-2): quote requests from business
/// buyers, split into Needs response · Negotiating · Accepted · Closed.
class SellerRfqInboxScreen extends StatefulWidget {
  const SellerRfqInboxScreen({super.key, this.now});

  /// Fixed clock for tests.
  final DateTime? now;

  @override
  State<SellerRfqInboxScreen> createState() => _SellerRfqInboxScreenState();
}

class _SellerRfqInboxScreenState extends State<SellerRfqInboxScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<RfqProvider>().loadMyRfqs();
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final provider = context.watch<RfqProvider>();
    final now = widget.now ?? DateTime.now();
    final quotes = provider.myRfqs;
    final counts = quoteCounts(quotes, now);
    return DefaultTabController(
      length: QuoteBucket.values.length,
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(
            tooltip: l10n.back,
            icon: const Icon(AgIcons.arrowLeft),
            onPressed: () => Navigator.of(context).maybePop(),
          ),
          title: Text(l10n.quotesTitle),
          bottom: TabBar(
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            tabs: [
              for (final b in QuoteBucket.values)
                Tab(text: l10n.quotesTabWithCount(l10n.bucketLabel(b), counts[b]!)),
            ],
          ),
        ),
        body: provider.loadFailed
            ? Padding(
                padding: const EdgeInsets.all(WsSpace.page),
                child: SaInfoBanner(variant: SaBannerVariant.error, message: l10n.quotesLoadFailed),
              )
            : provider.isLoading && quotes.isEmpty
                ? const Center(child: CircularProgressIndicator())
                : TabBarView(children: [
                    for (final b in QuoteBucket.values)
                      _QuoteList(
                        bucket: b,
                        now: now,
                        quotes: quotes.where((q) => quoteBucketOf(q, now) == b).toList(),
                      ),
                  ]),
      ),
    );
  }
}

class _QuoteList extends StatelessWidget {
  const _QuoteList({required this.bucket, required this.quotes, required this.now});
  final QuoteBucket bucket;
  final List<RfqModel> quotes;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final t = context.ws;
    if (quotes.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(WsSpace.s32),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(AgIcons.quote, size: WsIconSize.empty, color: t.textTertiary),
            const SizedBox(height: WsSpace.s12),
            Text(
              bucket == QuoteBucket.needsResponse ? l10n.quotesEmptyNeedsResponse : l10n.quotesEmptyOther,
              style: context.wsText.bodyMedium,
              textAlign: TextAlign.center,
            ),
          ]),
        ),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.all(WsSpace.page),
      itemCount: quotes.length,
      separatorBuilder: (_, __) => const SizedBox(height: WsSpace.s8),
      itemBuilder: (context, i) => QuoteTile(
        quote: quotes[i],
        now: now,
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute<void>(builder: (_) => SellerRfqDetailScreen(rfqId: quotes[i].id, now: now)),
        ),
      ),
    );
  }
}
