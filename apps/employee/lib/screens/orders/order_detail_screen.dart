import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:agrimore_ui/agrimore_ui.dart';
import '../../utils/sa_formatters.dart';

/// Screen displaying full details of an attributed order for a Sales Associate.
///
/// Grounded strictly in the already-fetched [orderData] map from the dashboard
/// or orders list, performing zero additional queries.
class OrderDetailScreen extends StatelessWidget {
  final String orderId;
  final Map<String, dynamic> orderData;

  const OrderDetailScreen({
    super.key,
    required this.orderId,
    required this.orderData,
  });

  @override
  Widget build(BuildContext context) {
    final d = orderData;
    final orderNumber = d['orderNumber']?.toString() ?? orderId;
    final total = (d['total'] as num?)?.toDouble() ?? 0.0;
    final status = (d['orderStatus'] ?? 'pending').toString().toLowerCase();

    DateTime? placedAt;
    final createdVal = d['createdAt'];
    if (createdVal is Timestamp) {
      placedAt = createdVal.toDate();
    }

    final rawMode = d['orderMode'];
    final normMode = rawMode is String ? rawMode.trim().toUpperCase() : null;
    final modeLabel = normMode == 'B2B'
        ? 'B2B Wholesale'
        : normMode == 'B2C'
            ? 'Retail Order'
            : 'Standard';

    final isDelivered = status == 'delivered' || status == 'completed';
    final isCancelled = status == 'cancelled';

    final items = d['items'];
    final itemList = items is List ? items : const [];

    return Scaffold(
      backgroundColor: SaTokens.pageBackground,
      appBar: AppBar(
        title: Text('Order #$orderNumber'),
        leading: IconButton(
          icon: const Icon(SaIcons.arrowLeft),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(SaTokens.space16),
        children: [
          // 1. Order Summary Card
          _buildSummaryCard(
            context,
            orderNumber: orderNumber,
            placedAt: placedAt,
            status: status,
            isDelivered: isDelivered,
            isCancelled: isCancelled,
            modeLabel: modeLabel,
            total: total,
          ),
          const SizedBox(height: SaTokens.space16),

          // 2. Commission Card
          _buildCommissionCard(context, d, isDelivered, isCancelled),
          const SizedBox(height: SaTokens.space16),

          // 3. Line Items Card
          if (itemList.isNotEmpty) ...[
            _buildItemsCard(context, itemList),
            const SizedBox(height: SaTokens.space16),
          ],
        ],
      ),
    );
  }

  Widget _buildSummaryCard(
    BuildContext context, {
    required String orderNumber,
    required DateTime? placedAt,
    required String status,
    required bool isDelivered,
    required bool isCancelled,
    required String modeLabel,
    required double total,
  }) {
    Color statusBg = SaTokens.warningBg;
    Color statusFg = SaTokens.warningFg;

    if (isDelivered) {
      statusBg = SaTokens.successBg;
      statusFg = SaTokens.successFg;
    } else if (isCancelled) {
      statusBg = SaTokens.errorBg;
      statusFg = SaTokens.errorFg;
    }

    return Container(
      padding: const EdgeInsets.all(SaTokens.space16),
      decoration: BoxDecoration(
        color: SaTokens.surface,
        borderRadius: BorderRadius.circular(SaTokens.radiusCard),
        border: Border.all(color: SaTokens.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Order Summary',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 3,
                ),
                decoration: BoxDecoration(
                  color: statusBg,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  status.toUpperCase(),
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: statusFg,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: SaTokens.space16),
          _buildDetailRow('Order Number', '#$orderNumber'),
          if (placedAt != null)
            _buildDetailRow('Placed on', SaFormatters.formatDate(placedAt)),
          _buildDetailRow('Order Channel', modeLabel),
          const Divider(height: 24, color: SaTokens.divider),
          _buildDetailRow(
            'Order Total',
            SaFormatters.formatCurrency(total),
            isBold: true,
          ),
        ],
      ),
    );
  }

  Widget _buildCommissionCard(
    BuildContext context,
    Map<String, dynamic> data,
    bool isDelivered,
    bool isCancelled,
  ) {
    final commissionPaid = data['commissionPaid'] == true;
    final commissionAmount = (data['commissionAmount'] as num?)?.toDouble();

    DateTime? paidAt;
    final rawPaidAt = data['commissionPaidAt'];
    if (rawPaidAt is Timestamp) {
      paidAt = rawPaidAt.toDate();
    }

    if (isCancelled) {
      return Container(
        padding: const EdgeInsets.all(SaTokens.space16),
        decoration: BoxDecoration(
          color: SaTokens.errorBg,
          borderRadius: BorderRadius.circular(SaTokens.radiusCard),
          border: Border.all(color: SaTokens.errorFg.withValues(alpha: 0.3)),
        ),
        child: Row(
          children: [
            const Icon(SaIcons.circleAlert, color: SaTokens.errorFg, size: 20),
            const SizedBox(width: SaTokens.space12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'No Commission Applicable',
                    style: TextStyle(
                      fontSize: SaTokens.fsBody,
                      fontWeight: FontWeight.w700,
                      color: SaTokens.errorFg,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'This order was cancelled and did not accrue sales commission.',
                    style: TextStyle(
                      fontSize: SaTokens.fsLabel,
                      color: SaTokens.errorFg.withValues(alpha: 0.9),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    if (commissionPaid && commissionAmount != null) {
      return Container(
        padding: const EdgeInsets.all(SaTokens.space16),
        decoration: BoxDecoration(
          color: SaTokens.successBg,
          borderRadius: BorderRadius.circular(SaTokens.radiusCard),
          border: Border.all(color: SaTokens.successFg.withValues(alpha: 0.3)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(SaIcons.circleCheck, color: SaTokens.successFg, size: 20),
                const SizedBox(width: SaTokens.space8),
                const Text(
                  'Commission Credited',
                  style: TextStyle(
                    fontSize: SaTokens.fsBody,
                    fontWeight: FontWeight.w700,
                    color: SaTokens.successFg,
                  ),
                ),
              ],
            ),
            const SizedBox(height: SaTokens.space12),
            Text(
              SaFormatters.formatCurrency(commissionAmount),
              style: const TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.w900,
                color: SaTokens.successFg,
              ),
            ),
            const SizedBox(height: SaTokens.space4),
            Text(
              paidAt != null
                  ? 'Credited to your wallet on ${SaFormatters.formatDate(paidAt)}'
                  : 'Credited directly to your wallet balance',
              style: TextStyle(
                fontSize: SaTokens.fsCaption,
                color: SaTokens.successFg.withValues(alpha: 0.9),
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(SaTokens.space16),
      decoration: BoxDecoration(
        color: SaTokens.surface,
        borderRadius: BorderRadius.circular(SaTokens.radiusCard),
        border: Border.all(color: SaTokens.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.schedule_rounded,
                color: SaTokens.primary,
                size: 20,
              ),
              const SizedBox(width: SaTokens.space8),
              const Text(
                'Commission Pending',
                style: TextStyle(
                  fontSize: SaTokens.fsBody,
                  fontWeight: FontWeight.w700,
                  color: SaTokens.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: SaTokens.space8),
          Text(
            isDelivered
                ? 'The order is marked delivered. Commission processing will complete shortly.'
                : 'Commission is automatically calculated and credited to your wallet once this order is marked delivered.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: SaTokens.textSecondary,
                  height: 1.4,
                ),
          ),
        ],
      ),
    );
  }

  Widget _buildItemsCard(BuildContext context, List itemList) {
    return Container(
      padding: const EdgeInsets.all(SaTokens.space16),
      decoration: BoxDecoration(
        color: SaTokens.surface,
        borderRadius: BorderRadius.circular(SaTokens.radiusCard),
        border: Border.all(color: SaTokens.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Order Items (${itemList.length})',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: SaTokens.space12),
          ...itemList.whereType<Map>().map((raw) {
            final item = Map<String, dynamic>.from(raw);
            final name = (item['productName'] ?? item['title'] ?? 'Product').toString();
            final quantity = (item['quantity'] as num?)?.toInt() ?? 1;
            final price = (item['price'] as num?)?.toDouble() ?? 0.0;
            final lineTotal = price * quantity;

            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          name,
                          style: const TextStyle(
                            fontSize: SaTokens.fsBody,
                            fontWeight: FontWeight.w600,
                            color: SaTokens.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${SaFormatters.formatCurrency(price)} × $quantity',
                          style: const TextStyle(
                            fontSize: SaTokens.fsCaption,
                            color: SaTokens.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    SaFormatters.formatCurrency(lineTotal),
                    style: const TextStyle(
                      fontSize: SaTokens.fsBody,
                      fontWeight: FontWeight.w700,
                      color: SaTokens.textPrimary,
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildDetailRow(
    String label,
    String value, {
    bool isBold = false,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: SaTokens.fsLabel,
              color: isBold ? SaTokens.textPrimary : SaTokens.textSecondary,
              fontWeight: isBold ? FontWeight.w700 : FontWeight.w400,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: SaTokens.fsLabel,
              color: SaTokens.textPrimary,
              fontWeight: isBold ? FontWeight.w700 : FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
