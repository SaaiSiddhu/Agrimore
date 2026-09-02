import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/// Phase 16C, Workstream 3 — order detail for an associate's own
/// attributed order.
///
/// Takes the order's data straight from the dashboard's ALREADY-FETCHED
/// order document (locked decision 6) — this screen performs NO Firestore
/// read of its own, ever. `orderId` is passed only for display; nothing
/// here re-queries by it.
class OrderDetailScreen extends StatelessWidget {
  final String orderId;
  final Map<String, dynamic> orderData;

  const OrderDetailScreen({
    super.key,
    required this.orderId,
    required this.orderData,
  });

  static const _deliveredEquivalent = {'delivered', 'completed'};

  static String _formatMoney(num value) => 'Rs ${value.toStringAsFixed(0)}';

  static String? _formatTimestamp(dynamic value) {
    if (value is! Timestamp) return null;
    return DateFormat('d MMM yyyy, h:mm a').format(value.toDate());
  }

  @override
  Widget build(BuildContext context) {
    final d = orderData;
    final orderNumber = d['orderNumber']?.toString() ?? orderId;
    final total = (d['total'] as num?) ?? 0;
    final status = (d['orderStatus'] ?? 'pending').toString();
    final placedAt = _formatTimestamp(d['createdAt']);

    final rawMode = d['orderMode'];
    final normalizedMode = rawMode is String ? rawMode.trim().toUpperCase() : null;
    final modeLabel = normalizedMode == 'B2B'
        ? 'B2B'
        : normalizedMode == 'B2C'
            ? 'Retail'
            : null;

    final items = d['items'];
    final itemList = items is List ? items : const [];

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(title: Text('Order #$orderNumber')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _SectionCard(
            title: 'Order Summary',
            children: [
              _DetailRow(label: 'Order Number', value: '#$orderNumber'),
              if (placedAt != null) _DetailRow(label: 'Placed', value: placedAt),
              _DetailRow(
                label: 'Status',
                value: status.toUpperCase(),
                valueColor: _deliveredEquivalent.contains(status.toLowerCase())
                    ? Colors.green.shade800
                    : Colors.amber.shade900,
              ),
              if (modeLabel != null) _DetailRow(label: 'Order Type', value: modeLabel),
              _DetailRow(label: 'Total', value: _formatMoney(total)),
            ],
          ),
          const SizedBox(height: 16),
          _CommissionCard(orderStatus: status, orderData: d),
          if (itemList.isNotEmpty) ...[
            const SizedBox(height: 16),
            _SectionCard(
              title: 'Items',
              children: itemList.whereType<Map>().map((raw) {
                final item = Map<String, dynamic>.from(raw);
                final name = (item['productName'] ?? '').toString();
                final quantity = (item['quantity'] as num?)?.toInt() ?? 0;
                final price = (item['price'] as num?) ?? 0;
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          name.isNotEmpty ? name : 'Item',
                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                        ),
                      ),
                      Text(
                        '×$quantity',
                        style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        _formatMoney(price),
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ],
        ],
      ),
    );
  }
}

/// Commission state, read directly off the SAME already-fetched order
/// document — commissionPaid/commissionAmount/commissionPaidAt are exactly
/// the fields functions/src/customer/employeeCommission.ts writes, and
/// ONLY on the transition into a delivered-equivalent status (never at
/// order-creation time). A pending order therefore never implies money is
/// owed yet, and an unresolved-rate exception (written to
/// commission_exceptions, never onto the order itself) is described in
/// plain, non-alarming terms rather than a guessed figure.
class _CommissionCard extends StatelessWidget {
  final String orderStatus;
  final Map<String, dynamic> orderData;

  const _CommissionCard({required this.orderStatus, required this.orderData});

  @override
  Widget build(BuildContext context) {
    final commissionPaid = orderData['commissionPaid'] == true;
    final message = <Widget>[];

    if (commissionPaid) {
      final amount = (orderData['commissionAmount'] as num?) ?? 0;
      final paidAt = OrderDetailScreen._formatTimestamp(orderData['commissionPaidAt']);
      message.add(_DetailRow(
        label: 'Commission Paid',
        value: OrderDetailScreen._formatMoney(amount),
        valueColor: Colors.green.shade800,
      ));
      if (paidAt != null) {
        message.add(_DetailRow(label: 'Paid On', value: paidAt));
      }
    } else {
      final isDeliveredEquivalent = OrderDetailScreen._deliveredEquivalent
          .contains(orderStatus.toLowerCase());
      message.add(Text(
        isDeliveredEquivalent
            ? 'Commission for this order has not been finalised yet.'
            : 'Commission is calculated once this order is delivered.',
        style: TextStyle(fontSize: 13, color: Colors.grey.shade700, height: 1.4),
      ));
    }

    return _SectionCard(title: 'Commission', children: message);
  }
}

class _SectionCard extends StatelessWidget {
  final String title;
  final List<Widget> children;

  const _SectionCard({required this.title, required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800)),
          const SizedBox(height: 10),
          ...children,
        ],
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;
  final Color? valueColor;

  const _DetailRow({required this.label, required this.value, this.valueColor});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
            ),
          ),
          const SizedBox(width: 12),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: valueColor ?? Colors.black87,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
