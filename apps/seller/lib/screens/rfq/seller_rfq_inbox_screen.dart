import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:agrimore_core/agrimore_core.dart';
import '../../providers/rfq_provider.dart';
import 'seller_rfq_detail_screen.dart';

const _kAccentColor = Color(0xFF2D7D3C);

/// "Quote Requests" — the seller's own RFQ inbox (Phase RFQ-2B). Mirrors
/// apps/marketplace's MyRfqsScreen (Phase RFQ-2) in structure, restyled to
/// apps/seller's own established inline-color convention rather than
/// migrated to agrimore_ui's theme tokens (uiux.md's explicit carve-out for
/// this app).
class SellerRfqInboxScreen extends StatefulWidget {
  const SellerRfqInboxScreen({super.key});

  @override
  State<SellerRfqInboxScreen> createState() => _SellerRfqInboxScreenState();
}

class _SellerRfqInboxScreenState extends State<SellerRfqInboxScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<RfqProvider>().loadMyRfqs();
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final rfqProvider = context.watch<RfqProvider>();

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF121212) : Colors.grey[50],
      appBar: AppBar(
        title: const Text('Quote Requests'),
        backgroundColor: isDark ? const Color(0xFF1A1A1A) : Colors.white,
        foregroundColor: isDark ? Colors.white : Colors.black87,
        elevation: 0,
      ),
      body: rfqProvider.isLoading && rfqProvider.myRfqs.isEmpty
          ? const Center(child: CircularProgressIndicator(color: _kAccentColor))
          : rfqProvider.myRfqs.isEmpty
              ? _buildEmptyState()
              : ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: rfqProvider.myRfqs.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final rfq = rfqProvider.myRfqs[index];
                    return _RfqCard(rfq: rfq, isDark: isDark);
                  },
                ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.request_quote_outlined, size: 64, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text(
            'No quote requests yet',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.grey[600]),
          ),
          const SizedBox(height: 8),
          Text(
            'Bulk quote requests from buyers will appear here',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: Colors.grey[500]),
          ),
        ],
      ),
    );
  }
}

class _RfqCard extends StatelessWidget {
  final RfqModel rfq;
  final bool isDark;

  const _RfqCard({required this.rfq, required this.isDark});

  Color _statusColor() {
    switch (rfq.status) {
      case RfqStatus.accepted:
        return Colors.green;
      case RfqStatus.rejected:
        return Colors.red;
      case RfqStatus.negotiating:
        return Colors.orange;
      case RfqStatus.pending:
        return Colors.blue;
    }
  }

  String _statusLabel() {
    switch (rfq.status) {
      case RfqStatus.accepted:
        return 'Accepted';
      case RfqStatus.rejected:
        return 'Rejected';
      case RfqStatus.negotiating:
        return 'Negotiating';
      case RfqStatus.pending:
        return 'Awaiting your response';
    }
  }

  @override
  Widget build(BuildContext context) {
    final offer = rfq.lastOffer;
    final isMyTurn = () {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      return uid != null && rfq.canActNow(uid);
    }();

    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => SellerRfqDetailScreen(rfqId: rfq.id)),
      ),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isDark ? Colors.grey[900] : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: isDark ? Colors.grey[800]! : Colors.grey.shade200),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    'Quote request',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: _statusColor().withOpacity(0.12),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    _statusLabel(),
                    style: TextStyle(color: _statusColor(), fontWeight: FontWeight.w700, fontSize: 12),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (offer != null)
              Text(
                '${PriceFormatter.formatPriceInt(offer.price)} x ${offer.quantity}',
                style: TextStyle(fontSize: 14, color: isDark ? Colors.grey[300] : Colors.grey[700]),
              )
            else
              Text(
                'Awaiting your price',
                style: TextStyle(fontSize: 14, color: isDark ? Colors.grey[300] : Colors.grey[700]),
              ),
            if (isMyTurn)
              const Padding(
                padding: EdgeInsets.only(top: 8),
                child: Text(
                  'Your turn to respond',
                  style: TextStyle(color: Colors.orange, fontWeight: FontWeight.w700, fontSize: 12),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
