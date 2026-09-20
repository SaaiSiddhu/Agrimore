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
    final tokens = context.saTokens;

    final items = d['items'];
    final itemList = items is List ? items : const [];

    return Scaffold(
      backgroundColor: tokens.pageBackground,
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
            tokens: tokens,
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
          _buildCommissionCard(context, tokens, d, isDelivered, isCancelled),
          const SizedBox(height: SaTokens.space16),

          // 3. Line Items Card
          if (itemList.isNotEmpty) ...[
            _buildItemsCard(context, tokens, itemList),
            const SizedBox(height: SaTokens.space16),
          ],
        ],
      ),
    );
  }

  Widget _buildSummaryCard(
    BuildContext context, {
    required SalesAssociateTokens tokens,
    required String orderNumber,
    required DateTime? placedAt,
    required String status,
    required bool isDelivered,
    required bool isCancelled,
    required String modeLabel,
    required double total,
  }) {
    Color statusBg = tokens.warningBg;
    Color statusFg = tokens.warningFg;

    if (isDelivered) {
      statusBg = tokens.successBg;
      statusFg = tokens.successFg;
    } else if (isCancelled) {
      statusBg = tokens.errorBg;
      statusFg = tokens.errorFg;
    }

    return Container(
      padding: const EdgeInsets.all(SaTokens.space16),
      decoration: BoxDecoration(
        color: tokens.surface,
        borderRadius: BorderRadius.circular(SaTokens.radiusCard),
        border: Border.all(color: tokens.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Text(
                  'Order Summary',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: tokens.textPrimary,
                      ),
                ),
              ),
              const SizedBox(width: 8),
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
          _buildDetailRow(tokens, 'Order Number', '#$orderNumber'),
          if (placedAt != null)
            _buildDetailRow(tokens, 'Placed on', SaFormatters.formatDate(placedAt)),
          _buildDetailRow(tokens, 'Order Channel', modeLabel),
          Divider(height: 24, color: tokens.divider),
          _buildDetailRow(
            tokens,
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
    SalesAssociateTokens tokens,
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
          color: tokens.errorBg,
          borderRadius: BorderRadius.circular(SaTokens.radiusCard),
          border: Border.all(color: tokens.errorFg.withValues(alpha: 0.3)),
        ),
        child: Row(
          children: [
            Icon(SaIcons.circleAlert, color: tokens.errorFg, size: 20),
            const SizedBox(width: SaTokens.space12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'No Commission Applicable',
                    style: TextStyle(
                      fontSize: SaTokens.fsBody,
                      fontWeight: FontWeight.w700,
                      color: tokens.errorFg,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'This order was cancelled and did not accrue sales commission.',
                    style: TextStyle(
                      fontSize: SaTokens.fsLabel,
                      color: tokens.errorFg.withValues(alpha: 0.9),
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
          color: tokens.successBg,
          borderRadius: BorderRadius.circular(SaTokens.radiusCard),
          border: Border.all(color: tokens.successFg.withValues(alpha: 0.3)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(SaIcons.circleCheck, color: tokens.successFg, size: 20),
                const SizedBox(width: SaTokens.space8),
                Expanded(
                  child: Text(
                    'Commission Credited',
                    style: TextStyle(
                      fontSize: SaTokens.fsBody,
                      fontWeight: FontWeight.w700,
                      color: tokens.successFg,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: SaTokens.space12),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                SaFormatters.formatCurrency(commissionAmount),
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w900,
                  color: tokens.successFg,
                ),
              ),
            ),
            const SizedBox(height: SaTokens.space4),
            Text(
              paidAt != null
                  ? 'Credited to your wallet on ${SaFormatters.formatDate(paidAt)}'
                  : 'Credited directly to your wallet balance',
              style: TextStyle(
                fontSize: SaTokens.fsCaption,
                color: tokens.successFg.withValues(alpha: 0.9),
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(SaTokens.space16),
      decoration: BoxDecoration(
        color: tokens.surface,
        borderRadius: BorderRadius.circular(SaTokens.radiusCard),
        border: Border.all(color: tokens.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.schedule_rounded,
                color: tokens.primary,
                size: 20,
              ),
              const SizedBox(width: SaTokens.space8),
              Expanded(
                child: Text(
                  'Commission Pending',
                  style: TextStyle(
                    fontSize: SaTokens.fsBody,
                    fontWeight: FontWeight.w700,
                    color: tokens.textPrimary,
                  ),
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
                  color: tokens.textSecondary,
                  height: 1.4,
                ),
          ),
        ],
      ),
    );
  }

  Widget _buildItemsCard(
    BuildContext context,
    SalesAssociateTokens tokens,
    List itemList,
  ) {
    return Container(
      padding: const EdgeInsets.all(SaTokens.space16),
      decoration: BoxDecoration(
        color: tokens.surface,
        borderRadius: BorderRadius.circular(SaTokens.radiusCard),
        border: Border.all(color: tokens.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Order Items (${itemList.length})',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: tokens.textPrimary,
                ),
          ),
          const SizedBox(height: SaTokens.space12),
          ...itemList.whereType<Map>().map((raw) {
            final item = Map<String, dynamic>.from(raw);
            final name = (item['productName'] ?? item['title'] ?? item['name'] ?? 'Product').toString();
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
                          style: TextStyle(
                            fontSize: SaTokens.fsBody,
                            fontWeight: FontWeight.w600,
                            color: tokens.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${SaFormatters.formatCurrency(price)} × $quantity',
                          style: TextStyle(
                            fontSize: SaTokens.fsCaption,
                            color: tokens.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: SaTokens.space8),
                  Flexible(
                    child: Text(
                      SaFormatters.formatCurrency(lineTotal),
                      textAlign: TextAlign.end,
                      style: TextStyle(
                        fontSize: SaTokens.fsBody,
                        fontWeight: FontWeight.w700,
                        color: tokens.textPrimary,
                      ),
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
    SalesAssociateTokens tokens,
    String label,
    String value, {
    bool isBold = false,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontSize: SaTokens.fsLabel,
                color: isBold ? tokens.textPrimary : tokens.textSecondary,
                fontWeight: isBold ? FontWeight.w700 : FontWeight.w400,
              ),
            ),
          ),
          const SizedBox(width: SaTokens.space8),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: TextStyle(
                fontSize: SaTokens.fsLabel,
                color: tokens.textPrimary,
                fontWeight: isBold ? FontWeight.w700 : FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
