import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:agrimore_ui/agrimore_ui.dart';
import 'package:agrimore_core/agrimore_core.dart';
import '../../../providers/rfq_provider.dart';
import '../../../providers/theme_provider.dart';
import '../../../app/routes.dart';

/// "My Quotes" — the buyer's own RFQ list (Phase RFQ-2). Mirrors the
/// existing My Orders / My Subscriptions screens' place in the app: reached
/// from profile_screen.dart, shows every RFQ the caller has ever created.
class MyRfqsScreen extends StatefulWidget {
  const MyRfqsScreen({Key? key}) : super(key: key);

  @override
  State<MyRfqsScreen> createState() => _MyRfqsScreenState();
}

class _MyRfqsScreenState extends State<MyRfqsScreen> {
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
    final isDark = context.watch<ThemeProvider>().isDarkMode;
    final rfqProvider = context.watch<RfqProvider>();

    return Scaffold(
      backgroundColor: isDark ? AppColors.backgroundDark : AppColors.surfaceVariant,
      appBar: AppBar(
        title: const Text('My Quotes'),
        backgroundColor: isDark ? AppColors.surfaceDark : AppColors.primary,
        foregroundColor: Colors.white,
      ),
      body: rfqProvider.isLoading && rfqProvider.myRfqs.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : rfqProvider.myRfqs.isEmpty
              ? EmptyState(
                  icon: Icons.request_quote_outlined,
                  title: 'No quote requests yet',
                  message:
                      'Request a bulk quote from a product page to start negotiating a price with a seller.',
                )
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
}

class _RfqCard extends StatelessWidget {
  final RfqModel rfq;
  final bool isDark;

  const _RfqCard({required this.rfq, required this.isDark});

  Color _statusColor() {
    switch (rfq.status) {
      case RfqStatus.accepted:
        return AppColors.success;
      case RfqStatus.rejected:
        return AppColors.error;
      case RfqStatus.negotiating:
        return AppColors.warning;
      case RfqStatus.pending:
        return AppColors.info;
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
        return 'Awaiting seller';
    }
  }

  @override
  Widget build(BuildContext context) {
    final offer = rfq.lastOffer;
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: () => Navigator.pushNamed(context, AppRoutes.rfqDetail, arguments: rfq.id),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isDark ? AppColors.surfaceDark : AppColors.surface,
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
                    style: AppTextStyles.bodyLarge.copyWith(fontWeight: FontWeight.w700),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: _statusColor().withValues(alpha: 0.12),
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
                '${PriceFormatter.formatPrice(offer.price)} x ${offer.quantity}',
                style: AppTextStyles.bodyMedium,
              )
            else
              Text('Awaiting a price from the seller', style: AppTextStyles.bodyMedium),
            if (_isMyTurn(context))
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  'Your turn to respond',
                  style: TextStyle(color: AppColors.warning, fontWeight: FontWeight.w700, fontSize: 12),
                ),
              ),
          ],
        ),
      ),
    );
  }

  bool _isMyTurn(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return false;
    return rfq.canActNow(uid);
  }
}
