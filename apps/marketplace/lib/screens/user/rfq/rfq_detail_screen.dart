import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:agrimore_ui/agrimore_ui.dart';
import 'package:agrimore_core/agrimore_core.dart';
import '../../../providers/rfq_provider.dart';
import '../../../providers/theme_provider.dart';

/// The negotiation thread for a single RFQ (Phase RFQ-2). Shows the full
/// append-only history from functions/src/customer/rfq.ts (Phase RFQ-1),
/// the current lastOffer, and — only when it is the caller's turn
/// (rfq.canActNow, re-checked unconditionally server-side on every call) —
/// actions to counter, accept, or reject.
class RfqDetailScreen extends StatefulWidget {
  final String rfqId;

  const RfqDetailScreen({Key? key, required this.rfqId}) : super(key: key);

  @override
  State<RfqDetailScreen> createState() => _RfqDetailScreenState();
}

class _RfqDetailScreenState extends State<RfqDetailScreen> {
  final _priceController = TextEditingController();
  final _quantityController = TextEditingController();
  final _notesController = TextEditingController();

  @override
  void dispose() {
    _priceController.dispose();
    _quantityController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _submitCounter(RfqModel rfq) async {
    final price = double.tryParse(_priceController.text.trim());
    final quantity = int.tryParse(_quantityController.text.trim());
    if (price == null || price <= 0) {
      SnackbarHelper.showWarning(context, 'Enter a valid price');
      return;
    }
    if (quantity == null || quantity <= 0) {
      SnackbarHelper.showWarning(context, 'Enter a valid quantity');
      return;
    }
    try {
      await context.read<RfqProvider>().submitOffer(
            rfqId: rfq.id,
            price: price,
            quantity: quantity,
            notes: _notesController.text,
          );
      if (mounted) {
        _priceController.clear();
        _quantityController.clear();
        _notesController.clear();
        SnackbarHelper.showSuccess(context, 'Offer sent');
      }
    } catch (_) {
      if (mounted) {
        SnackbarHelper.showError(context, context.read<RfqProvider>().error ?? 'Failed to send your offer');
      }
    }
  }

  Future<void> _respond(RfqModel rfq, String action) async {
    if (action == 'accept') {
      final confirmed = await DialogHelper.showConfirmation(
        context,
        title: 'Accept this offer?',
        message: rfq.lastOffer != null
            ? 'You are agreeing to ${PriceFormatter.formatPrice(rfq.lastOffer!.price)} for ${rfq.lastOffer!.quantity} units. This cannot be undone.'
            : 'This cannot be undone.',
        confirmText: 'Accept',
      );
      if (confirmed != true) return;
    } else {
      final confirmed = await DialogHelper.showConfirmation(
        context,
        title: 'Reject this quote request?',
        message: 'This ends the negotiation. You can always request a new quote later.',
        confirmText: 'Reject',
        isDangerous: true,
      );
      if (confirmed != true) return;
    }
    try {
      await context.read<RfqProvider>().respond(rfqId: rfq.id, action: action);
      if (mounted) {
        SnackbarHelper.showSuccess(context, action == 'accept' ? 'Offer accepted' : 'Quote request rejected');
      }
    } catch (_) {
      if (mounted) {
        SnackbarHelper.showError(context, context.read<RfqProvider>().error ?? 'Failed to respond');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = context.watch<ThemeProvider>().isDarkMode;
    final uid = FirebaseAuth.instance.currentUser?.uid ?? '';

    return Scaffold(
      backgroundColor: isDark ? AppColors.backgroundDark : AppColors.surfaceVariant,
      appBar: AppBar(
        title: const Text('Quote Request'),
        backgroundColor: isDark ? AppColors.surfaceDark : AppColors.primary,
        foregroundColor: Colors.white,
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance.collection('rfqs').doc(widget.rfqId).snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || !snapshot.data!.exists) {
            return EmptyState(
              icon: Icons.error_outline,
              title: 'Quote request not found',
              message: 'This quote request may have been removed.',
            );
          }
          final rfq = RfqModel.fromFirestore(snapshot.data!);
          final canAct = rfq.canActNow(uid);

          return Column(
            children: [
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    for (final entry in rfq.history) _HistoryTile(entry: entry, isDark: isDark),
                  ],
                ),
              ),
              if (canAct) _ActionBar(
                rfq: rfq,
                isDark: isDark,
                priceController: _priceController,
                quantityController: _quantityController,
                notesController: _notesController,
                onSubmitCounter: () => _submitCounter(rfq),
                onAccept: () => _respond(rfq, 'accept'),
                onReject: () => _respond(rfq, 'reject'),
              )
              else
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    rfq.status == RfqStatus.accepted
                        ? 'Accepted — locked at ${rfq.finalPrice != null ? PriceFormatter.formatPrice(rfq.finalPrice!) : ''} x ${rfq.finalQuantity ?? ''}'
                        : rfq.status == RfqStatus.rejected
                            ? 'This quote request was rejected.'
                            : 'Waiting for the other party to respond.',
                    style: AppTextStyles.bodyMedium,
                    textAlign: TextAlign.center,
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _HistoryTile extends StatelessWidget {
  final RfqHistoryEntry entry;
  final bool isDark;

  const _HistoryTile({required this.entry, required this.isDark});

  String _label() {
    final who = entry.actor == RfqRole.buyer ? 'You' : 'Seller';
    switch (entry.action) {
      case 'create':
        return '$who requested a quote${entry.price != null ? ' at ${PriceFormatter.formatPrice(entry.price!)}' : ''} for ${entry.quantity} units';
      case 'offer':
        return '$who offered ${PriceFormatter.formatPrice(entry.price ?? 0)} for ${entry.quantity} units';
      case 'accept':
        return '$who accepted ${PriceFormatter.formatPrice(entry.price ?? 0)} for ${entry.quantity} units';
      case 'reject':
        return '$who rejected the quote request';
      default:
        return who;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark : AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isDark ? Colors.grey[800]! : Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(_label(), style: AppTextStyles.bodyMedium.copyWith(fontWeight: FontWeight.w600)),
          if (entry.notes != null && entry.notes!.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(entry.notes!, style: TextStyle(fontSize: 12, color: isDark ? Colors.grey[400] : Colors.grey[600])),
          ],
        ],
      ),
    );
  }
}

class _ActionBar extends StatelessWidget {
  final RfqModel rfq;
  final bool isDark;
  final TextEditingController priceController;
  final TextEditingController quantityController;
  final TextEditingController notesController;
  final VoidCallback onSubmitCounter;
  final VoidCallback onAccept;
  final VoidCallback onReject;

  const _ActionBar({
    required this.rfq,
    required this.isDark,
    required this.priceController,
    required this.quantityController,
    required this.notesController,
    required this.onSubmitCounter,
    required this.onAccept,
    required this.onReject,
  });

  @override
  Widget build(BuildContext context) {
    final hasOffer = rfq.lastOffer != null;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark : AppColors.surface,
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 8, offset: const Offset(0, -2))],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (hasOffer)
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: onAccept,
                    style: ElevatedButton.styleFrom(backgroundColor: AppColors.success, foregroundColor: Colors.white),
                    child: const Text('Accept'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton(
                    onPressed: onReject,
                    style: OutlinedButton.styleFrom(foregroundColor: AppColors.error),
                    child: const Text('Reject'),
                  ),
                ),
              ],
            ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: priceController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(labelText: 'Your price', isDense: true),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: quantityController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Quantity', isDense: true),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          TextField(
            controller: notesController,
            decoration: const InputDecoration(labelText: 'Notes (optional)', isDense: true),
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: onSubmitCounter,
              style: ElevatedButton.styleFrom(
                backgroundColor: isDark ? AppColors.primaryLight : AppColors.primary,
                foregroundColor: Colors.white,
              ),
              child: Text(hasOffer ? 'Send Counter-Offer' : 'Send Price'),
            ),
          ),
        ],
      ),
    );
  }
}
