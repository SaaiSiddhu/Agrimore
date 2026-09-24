import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../design_system/design_system.dart';
import '../../l10n/app_localizations.dart';
import '../../providers/rfq_provider.dart';
import 'quote_rules.dart';
import 'seller_rfq_detail_screen.dart';
import 'widgets/quote_copy.dart';
import 'widgets/quote_tile.dart';

/// Q-01 Quotes inbox (board 20-01, SELLER-RFQ-2): quote requests from
/// business buyers, split by chip tabs with counts into Needs response ·
/// Negotiating · Accepted · Closed.
class SellerRfqInboxScreen extends StatefulWidget {
  const SellerRfqInboxScreen({super.key, this.now});

  /// Fixed clock for tests.
  final DateTime? now;

  @override
  State<SellerRfqInboxScreen> createState() => _SellerRfqInboxScreenState();
}

class _SellerRfqInboxScreenState extends State<SellerRfqInboxScreen> {
  QuoteBucket _bucket = QuoteBucket.needsResponse;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  void _load() {
    if (mounted) context.read<RfqProvider>().loadMyRfqs();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final provider = context.watch<RfqProvider>();
    final now = widget.now ?? DateTime.now();
    final quotes = provider.myRfqs;
    final counts = quoteCounts(quotes, now);
    final shown = quotes.where((q) => quoteBucketOf(q, now) == _bucket).toList();

    Widget body;
    if (provider.loadFailed) {
      body = SellerErrorState(title: l10n.quotesLoadFailed, onRetry: _load);
    } else if (provider.isLoading && quotes.isEmpty) {
      body = SellerSkeletonList(label: l10n.dsLoading);
    } else if (shown.isEmpty) {
      body = SellerEmptyState(
        icon: _bucket == QuoteBucket.needsResponse ? SellerIcons.success : SellerIcons.quote,
        title: _bucket == QuoteBucket.needsResponse ? l10n.quotesEmptyNeedsResponse : l10n.quotesEmptyOther,
      );
    } else {
      body = RefreshIndicator(
        onRefresh: () async => _load(),
        child: ListView.separated(
          padding: EdgeInsets.fromLTRB(context.pageInset, SellerSpace.s4, context.pageInset, SellerSpace.s24),
          itemCount: shown.length,
          separatorBuilder: (_, __) => const SizedBox(height: SellerSpace.s12),
          itemBuilder: (context, i) => QuoteTile(
            quote: shown[i],
            now: now,
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => SellerRfqDetailScreen(rfqId: shown[i].id, now: now)),
            ),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: SellerAppBar.detail(context, title: l10n.quotesTitle),
      body: Column(children: [
        SellerChipBar(padding: EdgeInsets.fromLTRB(context.pageInset, 0, context.pageInset, SellerSpace.s4), children: [
          for (final b in QuoteBucket.values)
            SellerChip(
              label: l10n.bucketLabel(b),
              count: counts[b],
              selected: _bucket == b,
              onSelected: (_) => setState(() => _bucket = b),
            ),
        ]),
        Expanded(child: body),
      ]),
    );
  }
}
