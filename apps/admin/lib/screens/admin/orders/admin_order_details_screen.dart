// lib/screens/admin/orders/admin_order_details_screen.dart
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:timeline_tile/timeline_tile.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:pdf/pdf.dart';
import 'package:printing/printing.dart';
import 'package:path_provider/path_provider.dart';

import 'package:agrimore_ui/agrimore_ui.dart';
import '../../../app/themes/admin_colors.dart';
import '../../../app/app_router.dart' show AdminRoutes;
import '../../../providers/order_provider.dart';
import '../delivery/delivery_flags.dart';
import '../delivery/order_assignment_screen.dart';

import 'widgets/order_status_updater.dart';

// ADMR-27: the one width threshold this screen's responsive split turns
// on — a top-level const so it is directly testable without constructing
// the screen itself.
const double kOrder360WideBreakpoint = 900.0;

/// Pure, top-level, and unit-tested without an emulator — mirrors this
/// session's own established pattern for logic embedded in a screen that
/// otherwise cannot be constructed outside a real Firebase app.
bool isOrder360Wide(double width) => width >= kOrder360WideBreakpoint;

/// True exactly when the order carries real cancellation data (ADMR-25's
/// own fields) — the sole condition gating the new Cancellation card.
bool orderNeedsCancellationCard(OrderModel order) => order.cancelledBy != null;

/// True once a real delivery-confirmation has actually happened (ADMR-28)
/// — deliberately keyed on `deliveredAt`, not the CURRENT `orderStatus`,
/// so the section stays visible even if the order was later cancelled/
/// returned (ADMR-26 already allows delivered->cancelled) rather than
/// silently hiding real delivery history.
bool orderHasDeliveryVerification(OrderModel order) => order.deliveredAt != null;

/// True when this order is attributed to a Sales Associate (ADMR-29) — the
/// sole condition gating the new Associate Commission card, since an
/// unattributed order can never carry commission data.
bool orderHasCommissionAttribution(OrderModel order) =>
    order.employeeUid != null && order.employeeUid!.trim().isNotEmpty;

/// ADMR-36: `order.codSettlementStatus == 'collected'` means exactly one
/// thing — functions/src/delivery/riderMoney.ts's recordDeliveryEarningCore
/// has recorded this order's cash against the rider's own account. It is
/// never written to mean AgriMore has received or reconciled that cash.
/// The label must say only what is actually known, never "settled".
String codLiabilityLabel({required bool isCod, required bool collected}) {
  if (!isCod) return 'Not applicable — paid online, no cash liability';
  if (collected) {
    return 'Cash collected by rider — held as their liability, not yet AgriMore\'s';
  }
  return 'Cash on delivery — not yet collected by rider';
}

/// ADMR-37: true only for a delivered order cancelled after the fact —
/// restoreStockOnCancellation.ts defers auto-restoration for exactly this
/// transition (the customer already had physical possession), setting
/// `stockRestorePending` instead of silently assuming a return happened.
bool orderNeedsReturnConfirmation(OrderModel order) =>
    order.deliveredAt != null && order.stockRestorePending == true;

/// True once stock has been restored for a delivered-then-cancelled order —
/// either an admin confirmed the return via confirmOrderReturnReceived, or
/// (for an order cancelled under the pre-ADMR-37 behavior) it was restored
/// automatically. Never true at the same time as
/// orderNeedsReturnConfirmation above.
bool orderShowsStockRestoredNote(OrderModel order) =>
    order.deliveredAt != null &&
    order.stockRestorePending != true &&
    order.stockRestored == true;

/// ADMR-42: `createOrder.ts` sets `paymentStatus` purely from
/// `paymentMethod` at creation time — `'cod' ? 'pending' : 'paid'` — and
/// never updates it again for a COD order (confirmed by repo-wide grep:
/// no writer anywhere ever sets a COD order's paymentStatus to 'paid').
/// riderMoney.ts's own `codSettlementStatus` is the real, separate signal
/// for whether COD cash was actually collected — already shown honestly
/// by the Delivery Verification card (ADMR-36). Showing this permanent,
/// by-design 'pending' with the SAME alarming color/label a genuinely
/// stuck non-COD payment would get conflates two very different
/// situations: a normal COD order awaiting delivery, and a real payment
/// problem.
enum PaymentCardState { paidOnline, cod, paymentIssue }

PaymentCardState paymentCardState(OrderModel order) {
  final isCod = order.paymentMethod.toLowerCase() == 'cod' ||
      order.paymentMethod.toLowerCase().contains('cash');
  if (isCod) return PaymentCardState.cod;
  return order.paymentStatus.toLowerCase() == 'paid'
      ? PaymentCardState.paidOnline
      : PaymentCardState.paymentIssue;
}

/// Maps the raw `updatedBy` role string (written by adminUpdateOrderStatus
/// today; sellerTransitionOrder.ts does not yet populate this field at all,
/// a separate, disclosed gap) to a human-readable actor label.
String friendlyActorLabel(String updatedBy) {
  switch (updatedBy.toLowerCase()) {
    case 'admin':
      return 'Admin';
    case 'seller':
      return 'Seller';
    case 'rider':
    case 'delivery_partner':
      return 'Delivery Partner';
    case 'system':
      return 'System';
    default:
      return updatedBy;
  }
}

class AdminOrderDetailsScreen extends StatefulWidget {
  final String orderId;

  const AdminOrderDetailsScreen({Key? key, required this.orderId})
      : super(key: key);

  @override
  State<AdminOrderDetailsScreen> createState() =>
      _AdminOrderDetailsScreenState();
}

class _AdminOrderDetailsScreenState extends State<AdminOrderDetailsScreen> {
  bool _loadingInvoice = false;
  bool _confirmingReturn = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        Provider.of<OrderProvider>(context, listen: false)
            .loadOrderById(widget.orderId);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: Consumer<OrderProvider>(
        builder: (context, orderProvider, child) {
          if (orderProvider.isLoading) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(color: AdminColors.primary),
                  const SizedBox(height: 16),
                  Text('Loading order...', style: TextStyle(color: Colors.grey.shade600)),
                ],
              ),
            );
          }

          final OrderModel? order = orderProvider.selectedOrder;
          if (order == null) return _emptyState();

          return CustomScrollView(
            slivers: [
              // Premium Header
              _buildSliverHeader(order),
              // Content — ADMR-27: a LayoutBuilder splits into a two-column
              // layout at >=900 logical px (a persistent Timeline/Cancellation
              // panel beside the main content, so an admin on a desk/tablet-
              // sized screen doesn't have to scroll past the full item list
              // to see the audit trail); below that, the exact same widgets
              // stack into one column, byte-for-byte the prior layout's order
              // plus the new Cancellation card.
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: LayoutBuilder(
                    key: const Key('order360_layout_builder'),
                    builder: (context, constraints) {
                      final isWide = isOrder360Wide(constraints.maxWidth);
                      final mainColumn = _buildMainColumn(order);
                      final sideColumn = _buildSideColumn(order, orderProvider);

                      if (!isWide) {
                        return Column(
                          key: const Key('order360_compact_layout'),
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [...mainColumn, ...sideColumn],
                        );
                      }

                      return Row(
                        key: const Key('order360_wide_layout'),
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            flex: 2,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: mainColumn,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            flex: 1,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: sideColumn,
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),
              ),
            ],
          ).animate().fadeIn(duration: 300.ms);
        },
      ),
    );
  }

  // =========================
  // Responsive column content (ADMR-27)
  // =========================
  // Every widget below is unchanged from before this phase except the new
  // Cancellation card, which is inserted right after Payment (only when
  // the order actually has cancellation data) — the same relative order
  // the compact layout always rendered these sections in.
  List<Widget> _buildMainColumn(OrderModel order) {
    final isCancelled = orderNeedsCancellationCard(order);
    return [
      OrderStatusUpdater(order: order),
      const SizedBox(height: 12),
      if (order.orderStatus.toLowerCase() == 'processing' ||
          order.orderStatus.toLowerCase() == 'confirmed')
        _buildAssignPartnerButton(order),
      const SizedBox(height: 16),
      _buildQuickStats(order),
      const SizedBox(height: 16),
      DeliveryFlagsCard(orderId: order.id),
      _buildSectionTitle('Customer & Delivery', Icons.person_rounded),
      const SizedBox(height: 12),
      _buildCustomerCard(order),
      const SizedBox(height: 16),
      _buildSectionTitle('Order Items', Icons.shopping_bag_rounded),
      const SizedBox(height: 12),
      _buildItemsCard(order),
      const SizedBox(height: 16),
      _buildSectionTitle('Price Breakdown', Icons.receipt_long_rounded),
      const SizedBox(height: 12),
      _buildPricingCard(order),
      const SizedBox(height: 16),
      _buildSectionTitle('Payment Details', Icons.payment_rounded),
      const SizedBox(height: 12),
      _buildPaymentCard(order),
      if (isCancelled) ...[
        const SizedBox(height: 16),
        _buildSectionTitle('Cancellation & Refund', Icons.cancel_rounded),
        const SizedBox(height: 12),
        _buildCancellationCard(order),
      ],
      const SizedBox(height: 16),
    ];
  }

  List<Widget> _buildSideColumn(OrderModel order, OrderProvider orderProvider) {
    return [
      _buildSectionTitle('Dispatch & Assignment History', Icons.route_rounded),
      const SizedBox(height: 12),
      _buildDispatchHistoryCard(orderProvider),
      const SizedBox(height: 16),
      if (orderHasDeliveryVerification(order)) ...[
        _buildSectionTitle('Delivery Verification & Settlement', Icons.verified_rounded),
        const SizedBox(height: 12),
        _buildDeliveryVerificationCard(order, orderProvider),
        const SizedBox(height: 16),
      ],
      _buildSectionTitle('Rider Earnings', Icons.payments_rounded),
      const SizedBox(height: 12),
      _buildRiderEarningsCard(orderProvider),
      const SizedBox(height: 16),
      if (orderHasCommissionAttribution(order)) ...[
        _buildSectionTitle('Associate Commission', Icons.percent_rounded),
        const SizedBox(height: 12),
        _buildCommissionCard(order, orderProvider),
        const SizedBox(height: 16),
      ],
      _buildSectionTitle('Related Support Tickets', Icons.support_agent_rounded),
      const SizedBox(height: 12),
      _buildSupportTicketsCard(orderProvider),
      const SizedBox(height: 16),
      _buildSectionTitle('Delivery Exceptions', Icons.report_problem_rounded),
      const SizedBox(height: 12),
      _buildDeliveryExceptionsCard(orderProvider),
      const SizedBox(height: 16),
      _buildSectionTitle('Rider Incidents', Icons.sos_rounded),
      const SizedBox(height: 12),
      _buildRiderIncidentsCard(orderProvider),
      const SizedBox(height: 16),
      _buildSectionTitle('Seller Settlement', Icons.storefront_rounded),
      const SizedBox(height: 12),
      _buildSellerSettlementCard(orderProvider),
      const SizedBox(height: 16),
      _buildSectionTitle('Order Timeline', Icons.timeline_rounded),
      const SizedBox(height: 12),
      _buildTimelineCard(orderProvider),
      const SizedBox(height: 24),
      _buildActionButtons(order),
      const SizedBox(height: 32),
    ];
  }

  // =========================
  // Dispatch & Assignment History Card (ADMR-28)
  // =========================
  Widget _buildDispatchHistoryCard(OrderProvider orderProvider) {
    final isLoading = orderProvider.isLoadingDispatchOffers;
    final error = orderProvider.dispatchOffersError;
    final offers = orderProvider.selectedOrderDispatchOffers;

    Widget content;
    if (isLoading) {
      content = const Padding(
        padding: EdgeInsets.symmetric(vertical: 24),
        child: Center(child: CircularProgressIndicator()),
      );
    } else if (error != null) {
      content = Padding(
        padding: const EdgeInsets.symmetric(vertical: 20),
        child: Center(
          child: Column(
            children: [
              Icon(Icons.error_outline_rounded, color: Colors.red.shade300, size: 32),
              const SizedBox(height: 8),
              Text('Could not load dispatch history', style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
            ],
          ),
        ),
      );
    } else if (offers.isEmpty) {
      content = Padding(
        padding: const EdgeInsets.symmetric(vertical: 24),
        child: Center(
          child: Column(
            children: [
              Icon(Icons.route_outlined, size: 32, color: Colors.grey.shade300),
              const SizedBox(height: 8),
              Text('No rider has been offered this order yet', style: TextStyle(color: Colors.grey.shade500, fontSize: 12)),
            ],
          ),
        ),
      );
    } else {
      content = Column(
        children: offers.map((o) => _dispatchOfferRow(o)).toList(),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      padding: const EdgeInsets.all(16),
      child: content,
    );
  }

  Widget _dispatchOfferRow(DispatchOfferRecord offer) {
    final color = _dispatchStatusColor(offer.status);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 8,
            height: 8,
            margin: const EdgeInsets.only(top: 5),
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Rider ${offer.riderId.length > 8 ? offer.riderId.substring(0, 8) : offer.riderId}',
                        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(color: color.withOpacity(0.12), borderRadius: BorderRadius.circular(6)),
                      child: Text(
                        offer.statusDisplayName,
                        style: TextStyle(color: color, fontWeight: FontWeight.w700, fontSize: 10),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  'Wave ${offer.wave}'
                  '${offer.pickupDistanceKm != null ? ' • ${offer.pickupDistanceKm!.toStringAsFixed(1)} km' : ''}'
                  '${offer.estimatedPay != null ? ' • Est. ₹${offer.estimatedPay!.toStringAsFixed(0)}' : ''}',
                  style: TextStyle(color: Colors.grey.shade500, fontSize: 11),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Color _dispatchStatusColor(String status) {
    switch (status) {
      case 'accepted':
        return Colors.green;
      case 'declined':
      case 'expired':
        return Colors.red;
      case 'withdrawn':
        return Colors.grey;
      case 'offered':
      case 'dispatching':
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }

  // =========================
  // Delivery Verification & COD Settlement Card (ADMR-28, honest labels ADMR-36)
  // =========================
  Widget _buildDeliveryVerificationCard(OrderModel order, OrderProvider orderProvider) {
    final isCod = order.paymentMethod.toLowerCase() == 'cod' ||
        order.paymentMethod.toLowerCase().contains('cash');
    // ADMR-36: "collected" only ever means the rider now personally holds
    // this cash as their own liability (functions/src/delivery/riderMoney.ts's
    // recordDeliveryEarningCore) — it is never set, and never meant, to imply
    // AgriMore has received or reconciled it. The old label here claimed
    // "& settled", which this field cannot support.
    final collected = order.codSettlementStatus?.toLowerCase() == 'collected';
    final cashAccount = orderProvider.selectedOrderRiderCashAccount;
    final isLoadingCashAccount = orderProvider.isLoadingRiderCashAccount;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.check_circle_rounded, color: Colors.green.shade600, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  order.deliveredAt != null
                      ? 'Delivered ${DateFormat('MMM d, yyyy • hh:mm a').format(order.deliveredAt!)}'
                      : 'Delivered',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                ),
              ),
            ],
          ),
          if (order.deliveryConfirmedVia != null) ...[
            const SizedBox(height: 6),
            Text(
              'Confirmed via ${order.deliveryConfirmedVia == 'confirmDelivery' ? "customer's delivery code" : order.deliveryConfirmedVia}',
              style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
            ),
          ],
          // ADMR-39: riderExceptions.ts's attachProofCore already writes
          // this photo's path — no client ever read it until now.
          if (order.deliveryProofPath != null) ...[
            const SizedBox(height: 10),
            _DeliveryProofTile(order: order),
          ],
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: (isCod ? (collected ? Colors.green : Colors.orange) : Colors.grey).withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  !isCod
                      ? Icons.credit_card_rounded
                      : (collected ? Icons.check_circle_rounded : Icons.hourglass_top_rounded),
                  size: 14,
                  color: !isCod ? Colors.grey.shade600 : (collected ? Colors.green.shade700 : Colors.orange.shade700),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    codLiabilityLabel(isCod: isCod, collected: collected),
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: !isCod ? Colors.grey.shade700 : (collected ? Colors.green.shade800 : Colors.orange.shade800),
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (isCod && collected) ...[
            const SizedBox(height: 8),
            Text(
              'See Rider Earnings below for this order\'s own collected amount and whether it has been included in a payout statement.',
              style: TextStyle(color: Colors.grey.shade500, fontSize: 11),
            ),
            const SizedBox(height: 10),
            if (isLoadingCashAccount)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: SizedBox(
                  height: 16,
                  width: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              )
            else if (cashAccount != null)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.blueGrey.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Rider\'s outstanding cash liability (all orders): ₹${cashAccount.cashHeld.toStringAsFixed(2)}',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.blueGrey.shade800),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'This is the rider\'s combined running balance, not an amount tracked per order.',
                      style: TextStyle(color: Colors.grey.shade500, fontSize: 11),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 4),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: () => context.push(AdminRoutes.riderPayouts),
                icon: const Icon(Icons.account_balance_wallet_outlined, size: 16),
                label: const Text('Open Rider Cash & Payouts', style: TextStyle(fontSize: 12)),
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 0),
                  minimumSize: const Size(0, 32),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  // =========================
  // Rider Earnings Card (ADMR-29)
  // =========================
  Widget _buildRiderEarningsCard(OrderProvider orderProvider) {
    final isLoading = orderProvider.isLoadingRiderEarning;
    final error = orderProvider.riderEarningError;
    final earning = orderProvider.selectedOrderRiderEarning;

    Widget content;
    if (isLoading) {
      content = const Padding(
        padding: EdgeInsets.symmetric(vertical: 24),
        child: Center(child: CircularProgressIndicator()),
      );
    } else if (error != null) {
      content = Padding(
        padding: const EdgeInsets.symmetric(vertical: 20),
        child: Center(
          child: Column(
            children: [
              Icon(Icons.error_outline_rounded, color: Colors.red.shade300, size: 32),
              const SizedBox(height: 8),
              Text('Could not load rider earnings', style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
            ],
          ),
        ),
      );
    } else if (earning == null) {
      content = Padding(
        padding: const EdgeInsets.symmetric(vertical: 24),
        child: Center(
          child: Column(
            children: [
              Icon(Icons.payments_outlined, size: 32, color: Colors.grey.shade300),
              const SizedBox(height: 8),
              Text('No earnings recorded yet for this order', style: TextStyle(color: Colors.grey.shade500, fontSize: 12)),
            ],
          ),
        ),
      );
    } else {
      content = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ...earning.lines.map((line) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 3),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      line.label +
                          (line.km != null ? ' (${line.km!.toStringAsFixed(1)} km)' : '') +
                          (line.minutes != null ? ' (${line.minutes} min)' : ''),
                      style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                    ),
                    Text('₹${line.amount.toStringAsFixed(2)}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                  ],
                ),
              )),
          const Divider(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Total pay', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
              Text('₹${earning.total.toStringAsFixed(2)}',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.green)),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Distance source: ${earning.kmSource}${earning.waitMinutes > 0 ? ' • ${earning.waitMinutes} min wait' : ''}',
            style: TextStyle(color: Colors.grey.shade500, fontSize: 11),
          ),
          if (earning.codCollected > 0) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(color: Colors.blue.withOpacity(0.08), borderRadius: BorderRadius.circular(8)),
              child: Text(
                'Cash collected: ₹${earning.codCollected.toStringAsFixed(2)}',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.blue.shade800),
              ),
            ),
          ],
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: (earning.isSettled ? Colors.green : Colors.orange).withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              earning.isSettled ? 'Included in a weekly payout statement' : 'Not yet included in a payout statement',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: earning.isSettled ? Colors.green.shade800 : Colors.orange.shade800,
              ),
            ),
          ),
        ],
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      padding: const EdgeInsets.all(16),
      child: content,
    );
  }

  // =========================
  // Associate Commission Card (ADMR-29)
  // =========================
  Widget _buildCommissionCard(OrderModel order, OrderProvider orderProvider) {
    final paid = order.commissionPaid == true;
    final reversed = order.commissionReversed == true;
    final exceptions = orderProvider.selectedOrderCommissionExceptions;
    final isLoadingExceptions = orderProvider.isLoadingCommissionExceptions;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                paid ? Icons.check_circle_rounded : Icons.hourglass_top_rounded,
                color: paid ? Colors.green.shade600 : Colors.orange.shade600,
                size: 18,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  paid
                      ? 'Commission paid${order.commissionAmount != null ? ' — ₹${order.commissionAmount!.toStringAsFixed(2)}' : ''}'
                      : 'Commission not yet paid',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                ),
              ),
            ],
          ),
          if (paid && order.commissionPaidAt != null) ...[
            const SizedBox(height: 6),
            Text(
              'Paid ${DateFormat('MMM d, yyyy • hh:mm a').format(order.commissionPaidAt!)}',
              style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
            ),
          ],
          if (reversed) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(color: Colors.red.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
              child: Text(
                'Reversed${order.commissionReversedAt != null ? ' ${DateFormat('MMM d, yyyy').format(order.commissionReversedAt!)}' : ''} — clawed back from the associate\'s wallet',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.red.shade800),
              ),
            ),
          ],
          if (!paid) ...[
            const SizedBox(height: 10),
            if (isLoadingExceptions)
              const Center(child: Padding(padding: EdgeInsets.symmetric(vertical: 8), child: CircularProgressIndicator()))
            else if (exceptions.isNotEmpty)
              ...exceptions.map((ex) => Container(
                    margin: const EdgeInsets.only(bottom: 6),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(color: Colors.orange.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                    child: Text(
                      'Unresolved: ${ex.reason}',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.orange.shade800),
                    ),
                  ))
            else
              Text(
                'No commission has been recorded for this order yet',
                style: TextStyle(color: Colors.grey.shade500, fontSize: 12),
              ),
          ],
        ],
      ),
    );
  }

  // =========================
  // Related Support Tickets Card (ADMR-29)
  // =========================
  Widget _buildSupportTicketsCard(OrderProvider orderProvider) {
    final isLoading = orderProvider.isLoadingSupportTickets;
    final error = orderProvider.supportTicketsError;
    final tickets = orderProvider.selectedOrderSupportTickets;

    Widget content;
    if (isLoading) {
      content = const Padding(
        padding: EdgeInsets.symmetric(vertical: 24),
        child: Center(child: CircularProgressIndicator()),
      );
    } else if (error != null) {
      content = Padding(
        padding: const EdgeInsets.symmetric(vertical: 20),
        child: Center(
          child: Column(
            children: [
              Icon(Icons.error_outline_rounded, color: Colors.red.shade300, size: 32),
              const SizedBox(height: 8),
              Text('Could not load support tickets', style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
            ],
          ),
        ),
      );
    } else if (tickets.isEmpty) {
      content = Padding(
        padding: const EdgeInsets.symmetric(vertical: 24),
        child: Center(
          child: Column(
            children: [
              Icon(Icons.support_agent_outlined, size: 32, color: Colors.grey.shade300),
              const SizedBox(height: 8),
              Text('No support tickets reference this order', style: TextStyle(color: Colors.grey.shade500, fontSize: 12)),
            ],
          ),
        ),
      );
    } else {
      content = Column(
        children: tickets.map((t) => _supportTicketRow(t)).toList(),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          content,
          _viewAllLink('Open Rider Support', Icons.support_agent_outlined, AdminRoutes.riderSupport),
        ],
      ),
    );
  }

  Widget _supportTicketRow(RiderSupportTicketRecord ticket) {
    final color = _ticketStatusColor(ticket.status);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 8,
            height: 8,
            margin: const EdgeInsets.only(top: 5),
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        ticket.categoryLabel,
                        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(color: color.withOpacity(0.12), borderRadius: BorderRadius.circular(6)),
                      child: Text(
                        ticket.statusLabel,
                        style: TextStyle(color: color, fontWeight: FontWeight.w700, fontSize: 10),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  ticket.message,
                  style: TextStyle(color: Colors.grey.shade500, fontSize: 11),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Color _ticketStatusColor(String status) {
    switch (status) {
      case 'submitted':
        return Colors.orange;
      case 'seen':
        return Colors.blue;
      case 'closed':
        return Colors.green;
      default:
        return Colors.grey;
    }
  }

  // ADMR-40: shared by DeliveryExceptionRecord and RiderIncidentRecord —
  // both use this exact reported/acknowledged/resolved vocabulary
  // (functions/src/delivery/riderExceptions.ts's/riderIncidents.ts's own
  // updateExceptionCore/updateIncidentCore), distinct from support
  // tickets' own submitted/seen/closed above.
  Color _reportStatusColor(String status) {
    switch (status) {
      case 'reported':
        return Colors.red;
      case 'acknowledged':
        return Colors.orange;
      case 'resolved':
        return Colors.green;
      default:
        return Colors.grey;
    }
  }

  // ADMR-40, ADMR-36: none of rider_support_screen.dart/
  // delivery_problems_screen.dart/rider_incidents_screen.dart supports a
  // per-case deep link today (confirmed: all three take no constructor
  // params) — a plain link to the right screen, not a new per-case
  // navigation mechanism, is the honest, reuse-not-reinvent action this
  // card can actually offer.
  Widget _viewAllLink(String label, IconData icon, String route) {
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Align(
        alignment: Alignment.centerLeft,
        child: TextButton.icon(
          onPressed: () => context.push(route),
          icon: Icon(icon, size: 16),
          label: Text(label, style: const TextStyle(fontSize: 12)),
          style: TextButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 0),
            minimumSize: const Size(0, 32),
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
        ),
      ),
    );
  }

  // =========================
  // Delivery Exceptions Card (ADMR-40)
  // =========================
  Widget _buildDeliveryExceptionsCard(OrderProvider orderProvider) {
    final isLoading = orderProvider.isLoadingDeliveryExceptions;
    final error = orderProvider.deliveryExceptionsError;
    final exceptions = orderProvider.selectedOrderDeliveryExceptions;

    Widget content;
    if (isLoading) {
      content = const Padding(
        padding: EdgeInsets.symmetric(vertical: 24),
        child: Center(child: CircularProgressIndicator()),
      );
    } else if (error != null) {
      content = Padding(
        padding: const EdgeInsets.symmetric(vertical: 20),
        child: Center(
          child: Column(
            children: [
              Icon(Icons.error_outline_rounded, color: Colors.red.shade300, size: 32),
              const SizedBox(height: 8),
              Text('Could not load delivery exceptions', style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
            ],
          ),
        ),
      );
    } else if (exceptions.isEmpty) {
      content = Padding(
        padding: const EdgeInsets.symmetric(vertical: 24),
        child: Center(
          child: Column(
            children: [
              Icon(Icons.report_problem_outlined, size: 32, color: Colors.grey.shade300),
              const SizedBox(height: 8),
              Text('No failed delivery attempts reported for this order', style: TextStyle(color: Colors.grey.shade500, fontSize: 12)),
            ],
          ),
        ),
      );
    } else {
      content = Column(
        children: exceptions.map((e) => _deliveryExceptionRow(e)).toList(),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          content,
          _viewAllLink('Open Delivery Problems', Icons.report_problem_outlined, AdminRoutes.deliveryProblems),
        ],
      ),
    );
  }

  Widget _deliveryExceptionRow(DeliveryExceptionRecord exception) {
    final color = _reportStatusColor(exception.status);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 8,
            height: 8,
            margin: const EdgeInsets.only(top: 5),
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        exception.reasonLabel,
                        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(color: color.withOpacity(0.12), borderRadius: BorderRadius.circular(6)),
                      child: Text(
                        exception.statusLabel,
                        style: TextStyle(color: color, fontWeight: FontWeight.w700, fontSize: 10),
                      ),
                    ),
                  ],
                ),
                if (exception.note != null && exception.note!.isNotEmpty) ...[
                  const SizedBox(height: 3),
                  Text(
                    exception.note!,
                    style: TextStyle(color: Colors.grey.shade500, fontSize: 11),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
                if (exception.resolution != null && exception.resolution!.isNotEmpty) ...[
                  const SizedBox(height: 3),
                  Text(
                    'Resolution: ${exception.resolution}',
                    style: TextStyle(color: Colors.grey.shade600, fontSize: 11, fontStyle: FontStyle.italic),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  // =========================
  // Rider Incidents Card (ADMR-40)
  // =========================
  Widget _buildRiderIncidentsCard(OrderProvider orderProvider) {
    final isLoading = orderProvider.isLoadingRiderIncidents;
    final error = orderProvider.riderIncidentsError;
    final incidents = orderProvider.selectedOrderRiderIncidents;

    Widget content;
    if (isLoading) {
      content = const Padding(
        padding: EdgeInsets.symmetric(vertical: 24),
        child: Center(child: CircularProgressIndicator()),
      );
    } else if (error != null) {
      content = Padding(
        padding: const EdgeInsets.symmetric(vertical: 20),
        child: Center(
          child: Column(
            children: [
              Icon(Icons.error_outline_rounded, color: Colors.red.shade300, size: 32),
              const SizedBox(height: 8),
              Text('Could not load rider incidents', style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
            ],
          ),
        ),
      );
    } else if (incidents.isEmpty) {
      content = Padding(
        padding: const EdgeInsets.symmetric(vertical: 24),
        child: Center(
          child: Column(
            children: [
              Icon(Icons.sos_outlined, size: 32, color: Colors.grey.shade300),
              const SizedBox(height: 8),
              Text('No rider safety incidents named this order', style: TextStyle(color: Colors.grey.shade500, fontSize: 12)),
            ],
          ),
        ),
      );
    } else {
      content = Column(
        children: incidents.map((i) => _riderIncidentRow(i)).toList(),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          content,
          _viewAllLink('Open Rider Incidents', Icons.sos_outlined, AdminRoutes.riderIncidents),
        ],
      ),
    );
  }

  Widget _riderIncidentRow(RiderIncidentRecord incident) {
    final color = _reportStatusColor(incident.status);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 8,
            height: 8,
            margin: const EdgeInsets.only(top: 5),
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        '${incident.kindLabel}${incident.riderName != null ? ' — ${incident.riderName}' : ''}',
                        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(color: color.withOpacity(0.12), borderRadius: BorderRadius.circular(6)),
                      child: Text(
                        incident.statusLabel,
                        style: TextStyle(color: color, fontWeight: FontWeight.w700, fontSize: 10),
                      ),
                    ),
                  ],
                ),
                if (incident.note != null && incident.note!.isNotEmpty) ...[
                  const SizedBox(height: 3),
                  Text(
                    incident.note!,
                    style: TextStyle(color: Colors.grey.shade500, fontSize: 11),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
                if (incident.activeOrderIds.length > 1) ...[
                  const SizedBox(height: 3),
                  Text(
                    'Also named ${incident.activeOrderIds.length - 1} other active order${incident.activeOrderIds.length - 1 == 1 ? '' : 's'} at report time',
                    style: TextStyle(color: Colors.grey.shade500, fontSize: 11),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  // =========================
  // Seller Settlement Card (ADMR-30)
  // =========================
  Widget _buildSellerSettlementCard(OrderProvider orderProvider) {
    final isLoading = orderProvider.isLoadingSellerPayouts;
    final error = orderProvider.sellerPayoutsError;
    final payouts = orderProvider.selectedOrderSellerPayouts;

    Widget content;
    if (isLoading) {
      content = const Padding(
        padding: EdgeInsets.symmetric(vertical: 24),
        child: Center(child: CircularProgressIndicator()),
      );
    } else if (error != null) {
      content = Padding(
        padding: const EdgeInsets.symmetric(vertical: 20),
        child: Center(
          child: Column(
            children: [
              Icon(Icons.error_outline_rounded, color: Colors.red.shade300, size: 32),
              const SizedBox(height: 8),
              Text('Could not load seller settlement', style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
            ],
          ),
        ),
      );
    } else if (payouts.isEmpty) {
      content = Padding(
        padding: const EdgeInsets.symmetric(vertical: 24),
        child: Center(
          child: Column(
            children: [
              Icon(Icons.storefront_outlined, size: 32, color: Colors.grey.shade300),
              const SizedBox(height: 8),
              Text('No settlement recorded yet for this order', style: TextStyle(color: Colors.grey.shade500, fontSize: 12)),
            ],
          ),
        ),
      );
    } else {
      content = Column(
        children: payouts
            .map((p) => _sellerPayoutRow(p))
            .expand((row) => [row, const Divider(height: 20)])
            .toList()
          ..removeLast(),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      padding: const EdgeInsets.all(16),
      child: content,
    );
  }

  Widget _sellerPayoutRow(SellerPayoutRecord payout) {
    final color = _payoutStatusColor(payout.status);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                'Seller ${payout.sellerId.length > 8 ? payout.sellerId.substring(0, 8) : payout.sellerId}',
                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(color: color.withOpacity(0.12), borderRadius: BorderRadius.circular(6)),
              child: Text(
                payout.statusLabel,
                style: TextStyle(color: color, fontWeight: FontWeight.w700, fontSize: 10),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Gross', style: TextStyle(color: Colors.grey.shade500, fontSize: 11)),
            Text('₹${payout.grossAmount.toStringAsFixed(2)}', style: const TextStyle(fontSize: 12)),
          ],
        ),
        const SizedBox(height: 2),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Commission (${payout.commissionRate.toStringAsFixed(1)}%)',
                style: TextStyle(color: Colors.grey.shade500, fontSize: 11)),
            Text('-₹${payout.commissionAmount.toStringAsFixed(2)}', style: const TextStyle(fontSize: 12)),
          ],
        ),
        const SizedBox(height: 2),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('Net to seller', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
            Text('₹${payout.netAmount.toStringAsFixed(2)}',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.green)),
          ],
        ),
        if (payout.status == 'paid' && payout.paidAt != null) ...[
          const SizedBox(height: 6),
          Text(
            'Paid ${DateFormat('MMM d, yyyy').format(payout.paidAt!)}'
            '${payout.paymentReference != null ? ' • Ref ${payout.paymentReference}' : ''}',
            style: TextStyle(color: Colors.grey.shade500, fontSize: 11),
          ),
        ],
      ],
    );
  }

  Color _payoutStatusColor(String status) {
    switch (status) {
      case 'paid':
        return Colors.green;
      case 'requested':
        return Colors.blue;
      case 'pending':
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }

  // =========================
  // Sliver Header
  // =========================
  Widget _buildSliverHeader(OrderModel order) {
    final statusColor = _statusColor(order.orderStatus);
    
    return SliverAppBar(
      expandedHeight: 200,
      pinned: true,
      elevation: 0,
      backgroundColor: AdminColors.primary,
      leading: IconButton(
        icon: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.2),
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Icon(Icons.arrow_back_rounded, color: Colors.white, size: 20),
        ),
        onPressed: () => Navigator.pop(context),
      ),
      actions: [
        IconButton(
          icon: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.refresh_rounded, color: Colors.white, size: 20),
          ),
          onPressed: () {
            Provider.of<OrderProvider>(context, listen: false)
                .loadOrderById(widget.orderId);
          },
        ),
        const SizedBox(width: 8),
      ],
      flexibleSpace: FlexibleSpaceBar(
        background: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                AdminColors.primary,
                AdminColors.primaryDark,
              ],
            ),
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 60, 20, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Order #${order.orderNumber ?? order.id.substring(0, 8)}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              DateFormat('EEEE, MMMM d, yyyy • hh:mm a').format(order.createdAt),
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.8),
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                      // Status badge
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(
                          color: statusColor.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: Colors.white.withOpacity(0.3)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 8,
                              height: 8,
                              decoration: BoxDecoration(
                                color: Colors.white,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              order.orderStatus.toUpperCase(),
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  // Copy order ID
                  GestureDetector(
                    onTap: () {
                      Clipboard.setData(ClipboardData(text: order.id));
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: const Text('Order ID copied'),
                          backgroundColor: AdminColors.primary,
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.copy_rounded, color: Colors.white.withOpacity(0.8), size: 14),
                          const SizedBox(width: 8),
                          Text(
                            'ID: ${order.id}',
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.9),
                              fontSize: 12,
                              fontFamily: 'monospace',
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // =========================
  // Quick Stats Row
  // =========================
  Widget _buildQuickStats(OrderModel order) {
    // ADMR-42: see paymentCardState's own header — a COD order's
    // permanent, by-design paymentStatus 'pending' is not the same
    // situation as a genuinely stuck non-COD payment.
    final state = paymentCardState(order);
    final paymentLabel = switch (state) {
      PaymentCardState.cod => 'COD',
      _ => order.paymentStatus.toUpperCase(),
    };
    final paymentIcon = switch (state) {
      PaymentCardState.paidOnline => Icons.check_circle_outline_rounded,
      PaymentCardState.cod => Icons.payments_outlined,
      PaymentCardState.paymentIssue => Icons.pending_outlined,
    };
    final paymentColor = switch (state) {
      PaymentCardState.paidOnline => Colors.green,
      PaymentCardState.cod => Colors.blue,
      PaymentCardState.paymentIssue => Colors.orange,
    };
    return Row(
      children: [
        Expanded(child: _statTile(
          '${order.items.length}',
          'Items',
          Icons.shopping_bag_outlined,
          AdminColors.primary,
        )),
        const SizedBox(width: 12),
        Expanded(child: _statTile(
          '₹${order.total.toStringAsFixed(0)}',
          'Total',
          Icons.currency_rupee_rounded,
          Colors.green,
        )),
        const SizedBox(width: 12),
        Expanded(child: _statTile(
          paymentLabel,
          'Payment',
          paymentIcon,
          paymentColor,
        )),
      ],
    );
  }

  Widget _statTile(String value, String label, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(height: 10),
          Text(
            value,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: color,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey.shade600,
            ),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 300.ms).slideY(begin: 0.1, end: 0);
  }

  // =========================
  // Section Title
  // =========================
  Widget _buildSectionTitle(String title, IconData icon) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: AdminColors.primary.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: AdminColors.primary, size: 18),
        ),
        const SizedBox(width: 12),
        Text(
          title,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Color(0xFF1E293B),
          ),
        ),
      ],
    );
  }

  // =========================
  // Assign Partner Button
  // =========================
  Widget _buildAssignPartnerButton(OrderModel order) {
    final hasPartner = order.deliveryPartnerId != null && order.deliveryPartnerId!.isNotEmpty;
    
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: hasPartner 
            ? [Colors.green.shade400, Colors.green.shade600]
            : [Colors.orange.shade400, Colors.orange.shade600],
        ),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: (hasPartner ? Colors.green : Colors.orange).withOpacity(0.3),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => OrderAssignmentScreen(order: order),
            ),
          ),
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    hasPartner ? Icons.check_circle_rounded : Icons.delivery_dining_rounded,
                    color: Colors.white,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        hasPartner ? 'Delivery Partner Assigned' : 'Assign Delivery Partner',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        hasPartner 
                          ? 'Tap to reassign or view partner'
                          : 'Choose an online partner for this order',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.85),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.arrow_forward_ios_rounded,
                  color: Colors.white.withOpacity(0.8),
                  size: 16,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // =========================
  // Customer Card
  // =========================
  Widget _buildCustomerCard(OrderModel order) {
    final a = order.deliveryAddress;
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          // Customer info
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [AdminColors.primary, AdminColors.primaryDark],
                    ),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Center(
                    child: Text(
                      a.name.isNotEmpty ? a.name[0].toUpperCase() : 'U',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        a.name,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(Icons.phone_outlined, size: 14, color: Colors.grey.shade600),
                          const SizedBox(width: 6),
                          Text(
                            a.phone,
                            style: TextStyle(
                              color: Colors.grey.shade700,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                // Quick actions
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _quickActionButton(Icons.phone_rounded, Colors.green, () => _callCustomer(a.phone)),
                    const SizedBox(width: 8),
                    _quickActionButton(FontAwesomeIcons.whatsapp.data, Colors.green.shade600, () => _openWhatsApp(a.phone)),
                    const SizedBox(width: 8),
                    _quickActionButton(Icons.copy_rounded, Colors.grey, () {
                      Clipboard.setData(ClipboardData(text: a.phone));
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: const Text('Phone copied'), backgroundColor: AdminColors.primary),
                      );
                    }),
                  ],
                ),
              ],
            ),
          ),
          // Divider
          Divider(height: 1, color: Colors.grey.shade100),
          // Delivery address
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.red.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.location_on_rounded, color: Colors.red, size: 20),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Delivery Address',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF64748B),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        a.fullAddress,
                        style: TextStyle(
                          color: Colors.grey.shade800,
                          fontSize: 14,
                          height: 1.5,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => _launchGoogleMaps(order),
                  icon: const Icon(Icons.map_rounded, color: Colors.blue),
                  tooltip: 'Open in Maps',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _quickActionButton(IconData icon, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: color, size: 18),
      ),
    );
  }

  // =========================
  // Items Card
  // =========================
  Widget _buildItemsCard(OrderModel order) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          ...order.items.asMap().entries.map((entry) {
            final i = entry.key;
            final item = entry.value;
            return Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(14),
                  child: Row(
                    children: [
                      // Product image
                      Container(
                        width: 64,
                        height: 64,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          color: Colors.grey.shade100,
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: item.productImage != null && item.productImage.isNotEmpty
                              ? Image.network(
                                  item.productImage,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) => Icon(
                                    Icons.shopping_bag_rounded,
                                    color: Colors.grey.shade400,
                                  ),
                                )
                              : Icon(
                                  Icons.shopping_bag_rounded,
                                  color: Colors.grey.shade400,
                                ),
                        ),
                      ),
                      const SizedBox(width: 14),
                      // Product details
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              item.productName,
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 14,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            // ✅ NEW: Display variant if present
                            if (item.variant != null && item.variant!.isNotEmpty) ...[
                              const SizedBox(height: 4),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: Colors.purple.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(4),
                                  border: Border.all(color: Colors.purple.withOpacity(0.3)),
                                ),
                                child: Text(
                                  item.variant!,
                                  style: TextStyle(
                                    color: Colors.purple.shade700,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 11,
                                  ),
                                ),
                              ),
                            ],
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: AdminColors.primary.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    'Qty: ${item.quantity}',
                                    style: TextStyle(
                                      color: AdminColors.primary,
                                      fontWeight: FontWeight.w600,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Text(
                                  '₹${item.price.toStringAsFixed(0)} each',
                                  style: TextStyle(
                                    color: Colors.grey.shade600,
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      // Item total
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            '₹${(item.price * item.quantity).toStringAsFixed(0)}',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                if (i < order.items.length - 1)
                  Divider(height: 1, color: Colors.grey.shade100),
              ],
            );
          }).toList(),
        ],
      ),
    );
  }

  // =========================
  // Pricing Card
  // =========================
  Widget _buildPricingCard(OrderModel order) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _priceRow('Subtotal', order.subtotal),
            const SizedBox(height: 12),
            _priceRow('Delivery Charges', order.deliveryCharge),
            const SizedBox(height: 12),
            _priceRow('Tax', order.tax),
            if ((order.discount ?? 0) > 0) ...[
              const SizedBox(height: 12),
              _priceRow('Discount', -(order.discount ?? 0), isDiscount: true),
            ],
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AdminColors.primary.withOpacity(0.08),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Total Amount',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    '₹${order.total.toStringAsFixed(2)}',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: AdminColors.primary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _priceRow(String label, double amount, {bool isDiscount = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            color: Colors.grey.shade700,
            fontSize: 14,
          ),
        ),
        Text(
          '${isDiscount ? '-' : ''}₹${amount.abs().toStringAsFixed(2)}',
          style: TextStyle(
            fontWeight: FontWeight.w600,
            color: isDiscount ? Colors.green.shade700 : Colors.grey.shade900,
          ),
        ),
      ],
    );
  }

  // =========================
  // Payment Card
  // =========================
  Widget _buildPaymentCard(OrderModel order) {
    final state = paymentCardState(order);
    final MaterialColor color = switch (state) {
      PaymentCardState.paidOnline => Colors.green,
      PaymentCardState.cod => Colors.blue,
      PaymentCardState.paymentIssue => Colors.orange,
    };
    final String headline = switch (state) {
      PaymentCardState.paidOnline => 'Payment Received',
      PaymentCardState.cod => 'Cash on Delivery',
      PaymentCardState.paymentIssue => 'Payment Pending',
    };
    final IconData icon = switch (state) {
      PaymentCardState.paidOnline => Icons.check_circle_rounded,
      PaymentCardState.cod => Icons.payments_rounded,
      PaymentCardState.paymentIssue => Icons.pending_rounded,
    };
    // ADMR-42: the badge shows a real, distinct label for COD ("COD") —
    // never the raw paymentStatus string ("PENDING"), which is this
    // field's own permanent, by-design value for every COD order and
    // reads as an alarm, not a normal state.
    final String badgeText = switch (state) {
      PaymentCardState.cod => 'COD',
      _ => order.paymentStatus.toUpperCase(),
    };

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Payment status banner
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: color.withOpacity(0.3),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      icon,
                      color: color.shade700,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          headline,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: color.shade800,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _friendlyPaymentMethod(order.paymentMethod),
                          style: TextStyle(
                            fontSize: 12,
                            color: color.shade600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: color,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      badgeText,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 11,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            if (order.razorpayOrderId != null && order.razorpayOrderId!.isNotEmpty) ...[
              const SizedBox(height: 14),
              Row(
                children: [
                  const Icon(Icons.tag_rounded, size: 16, color: Colors.grey),
                  const SizedBox(width: 8),
                  Text(
                    'Razorpay ID:',
                    style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      order.razorpayOrderId ?? '',
                      style: const TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 12,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.copy_rounded, size: 18),
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: order.razorpayOrderId ?? ''));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Razorpay ID copied')),
                      );
                    },
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  // =========================
  // Cancellation & Refund Card (ADMR-27)
  // =========================
  // Shown only when the order actually carries cancellation data —
  // ADMR-25 started writing cancelledBy/cancelledAt/cancellationReason/
  // refundStatus, but nothing displayed them until this phase.
  Widget _buildCancellationCard(OrderModel order) {
    final hasRefund = order.refundStatus != null && order.refundStatus!.isNotEmpty;
    final refundPending = order.refundStatus?.toLowerCase() == 'pending';

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.red.withOpacity(0.15)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.cancel_rounded, color: Colors.red.shade600, size: 18),
                const SizedBox(width: 8),
                const Text(
                  'Cancelled',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                ),
                const Spacer(),
                if (order.cancelledAt != null)
                  Text(
                    DateFormat('MMM d, yyyy • hh:mm a').format(order.cancelledAt!),
                    style: TextStyle(color: Colors.grey.shade500, fontSize: 11),
                  ),
              ],
            ),
            if (order.cancelledBy != null) ...[
              const SizedBox(height: 10),
              Text(
                'Cancelled by ${friendlyActorLabel(order.cancelledBy!)}',
                style: TextStyle(color: Colors.grey.shade700, fontSize: 13, fontWeight: FontWeight.w600),
              ),
            ],
            if (order.cancellationReason != null && order.cancellationReason!.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(
                order.cancellationReason!,
                style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
              ),
            ],
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: (hasRefund ? (refundPending ? Colors.orange : Colors.green) : Colors.grey)
                    .withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    hasRefund
                        ? (refundPending ? Icons.hourglass_top_rounded : Icons.check_circle_rounded)
                        : Icons.money_off_rounded,
                    size: 14,
                    color: hasRefund ? (refundPending ? Colors.orange.shade700 : Colors.green.shade700) : Colors.grey.shade600,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    hasRefund
                        ? 'Refund ${order.refundStatus!.toUpperCase()}'
                        : 'No refund due (unpaid or cash on delivery)',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: hasRefund ? (refundPending ? Colors.orange.shade800 : Colors.green.shade800) : Colors.grey.shade700,
                    ),
                  ),
                ],
              ),
            ),
            // ADMR-37: a delivered order's stock is never auto-restored on
            // cancellation (see restoreStockOnCancellation.ts's own header)
            // — the customer already had physical possession, so this is
            // the ONLY place that fact is ever true. Non-delivered
            // cancellations (the overwhelming majority) are unaffected and
            // show nothing new here.
            if (orderNeedsReturnConfirmation(order)) ...[
              const SizedBox(height: 12),
              _buildReturnConfirmationPrompt(order),
            ] else if (orderShowsStockRestoredNote(order)) ...[
              const SizedBox(height: 12),
              _buildStockAlreadyRestoredNote(),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildReturnConfirmationPrompt(OrderModel order) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.orange.withOpacity(0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.orange.withOpacity(0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.inventory_2_outlined, size: 16, color: Colors.orange.shade700),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Cancelled after delivery — stock has NOT been restored automatically.',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.orange.shade800),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Confirm only once the returned item has actually been received back — this cannot be undone.',
            style: TextStyle(color: Colors.grey.shade600, fontSize: 11),
          ),
          const SizedBox(height: 10),
          Align(
            alignment: Alignment.centerLeft,
            child: ElevatedButton.icon(
              onPressed: _confirmingReturn ? null : () => _confirmReturnReceived(order.id),
              icon: _confirmingReturn
                  ? const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.inventory_2_rounded, size: 16),
              label: const Text('Confirm Return Received'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange.shade600,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStockAlreadyRestoredNote() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(color: Colors.blueGrey.withOpacity(0.08), borderRadius: BorderRadius.circular(8)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.inventory_2_rounded, size: 14, color: Colors.blueGrey.shade700),
          const SizedBox(width: 8),
          Text(
            'Stock has been restored for this order',
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.blueGrey.shade800),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmReturnReceived(String orderId) async {
    setState(() => _confirmingReturn = true);
    try {
      final result = await context.read<OrderProvider>().confirmOrderReturnReceived(orderId);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result.isSuccess
              ? 'Stock restored for this order.'
              : (result.message ?? 'Could not confirm the return.')),
          backgroundColor: result.isSuccess ? Colors.green : Colors.red,
        ),
      );
    } finally {
      if (mounted) setState(() => _confirmingReturn = false);
    }
  }

  // =========================
  // Timeline Card
  // =========================
  Widget _buildTimelineCard(OrderProvider orderProvider) {
    final timeline = orderProvider.selectedOrderTimeline ?? [];

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: timeline.isEmpty
            ? Padding(
                padding: const EdgeInsets.symmetric(vertical: 30),
                child: Center(
                  child: Column(
                    children: [
                      Icon(Icons.timeline_rounded, size: 40, color: Colors.grey.shade300),
                      const SizedBox(height: 12),
                      Text(
                        'No timeline events yet',
                        style: TextStyle(color: Colors.grey.shade500),
                      ),
                    ],
                  ),
                ),
              )
            : ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: timeline.length,
                itemBuilder: (context, i) {
                  final ev = timeline[i];
                  final isFirst = i == 0;
                  final isLast = i == timeline.length - 1;
                  
                  return TimelineTile(
                    isFirst: isFirst,
                    isLast: isLast,
                    beforeLineStyle: LineStyle(
                      color: AdminColors.primary.withOpacity(0.2),
                      thickness: 2,
                    ),
                    afterLineStyle: LineStyle(
                      color: AdminColors.primary.withOpacity(0.2),
                      thickness: 2,
                    ),
                    indicatorStyle: IndicatorStyle(
                      width: 36,
                      height: 36,
                      indicator: Container(
                        decoration: BoxDecoration(
                          color: isFirst ? AdminColors.primary : Colors.white,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: isFirst ? AdminColors.primary : AdminColors.primary.withOpacity(0.3),
                            width: 2,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.05),
                              blurRadius: 6,
                            ),
                          ],
                        ),
                        child: Center(
                          child: Icon(
                            _timelineIcon(ev.status),
                            color: isFirst ? Colors.white : AdminColors.primary,
                            size: 16,
                          ),
                        ),
                      ),
                    ),
                    endChild: Padding(
                      padding: const EdgeInsets.only(left: 14, bottom: 20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  ev.title,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                  ),
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: AdminColors.primary.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  ev.statusDisplayName,
                                  style: TextStyle(
                                    color: AdminColors.primary,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 11,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(
                            ev.description,
                            style: TextStyle(
                              color: Colors.grey.shade600,
                              fontSize: 13,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              Text(
                                DateFormat('MMM d, yyyy • hh:mm a').format(ev.timestamp),
                                style: TextStyle(
                                  color: Colors.grey.shade400,
                                  fontSize: 11,
                                ),
                              ),
                              // ADMR-27: actor attribution — only shown
                              // when the writer actually populated it
                              // (today: adminUpdateOrderStatus only;
                              // sellerTransitionOrder.ts's own entries
                              // don't yet, a disclosed, separate gap).
                              if (ev.updatedBy != null && ev.updatedBy!.isNotEmpty) ...[
                                Text(
                                  '  •  ',
                                  style: TextStyle(color: Colors.grey.shade300, fontSize: 11),
                                ),
                                Text(
                                  'By ${friendlyActorLabel(ev.updatedBy!)}',
                                  style: TextStyle(
                                    color: Colors.grey.shade500,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
      ),
    );
  }

  // =========================
  // Action Buttons
  // =========================
  Widget _buildActionButtons(OrderModel order) {
    return Row(
      children: [
        Expanded(
          child: ElevatedButton.icon(
            onPressed: _loadingInvoice
                ? null
                : () => _exportInvoice(order, preview: true, share: false),
            icon: _loadingInvoice
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : const Icon(Icons.visibility_rounded, size: 20),
            label: const Text('Preview Invoice'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AdminColors.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              elevation: 0,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: OutlinedButton.icon(
            onPressed: _loadingInvoice
                ? null
                : () => _exportInvoice(order, preview: false, share: true),
            icon: const Icon(Icons.download_rounded, size: 20),
            label: const Text('Download'),
            style: OutlinedButton.styleFrom(
              foregroundColor: AdminColors.primary,
              side: BorderSide(color: AdminColors.primary),
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ),
      ],
    );
  }

  // =========================
  // Empty State
  // =========================
  Widget _emptyState() => Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.error_outline_rounded, size: 60, color: Colors.grey.shade400),
            ),
            const SizedBox(height: 20),
            const Text(
              'Order not found',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
            const SizedBox(height: 8),
            Text(
              'The order may have been deleted',
              style: TextStyle(color: Colors.grey.shade600),
            ),
          ],
        ),
      );

  // =========================
  // Utilities
  // =========================
  Color _statusColor(String s) {
    switch (s.toLowerCase()) {
      case 'pending':
        return Colors.orange;
      case 'confirmed':
        return Colors.blue;
      case 'processing':
        return Colors.deepPurple;
      case 'shipped':
        return Colors.teal;
      case 'delivered':
      case 'completed':
        return Colors.green;
      case 'cancelled':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  IconData _timelineIcon(dynamic status) {
    final s = (status ?? '').toString().toLowerCase();
    switch (s) {
      case 'pending':
        return Icons.schedule_rounded;
      case 'confirmed':
        return Icons.check_circle_outline_rounded;
      case 'processing':
        return Icons.autorenew_rounded;
      case 'shipped':
        return Icons.local_shipping_outlined;
      case 'outfordelivery':
      case 'out_for_delivery':
        return Icons.delivery_dining_rounded;
      case 'delivered':
        return Icons.check_circle_rounded;
      case 'cancelled':
        return Icons.cancel_outlined;
      default:
        return Icons.info_outline_rounded;
    }
  }


  String _friendlyPaymentMethod(String method) {
    switch (method.toLowerCase()) {
      case 'cod':
        return 'Cash on Delivery';
      case 'upi':
        return 'UPI Payment';
      case 'card':
        return 'Credit/Debit Card';
      case 'netbanking':
        return 'Net Banking';
      default:
        return method.toUpperCase();
    }
  }

  Future<void> _callCustomer(String phone) async {
    final uri = Uri.parse('tel:$phone');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  Future<void> _openWhatsApp(String phone) async {
    final uri = Uri.parse('https://wa.me/$phone');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  Future<void> _launchGoogleMaps(OrderModel order) async {
    final a = order.deliveryAddress;
    Uri uri;
    if (a.latitude != null && a.longitude != null) {
      uri = Uri.parse('https://www.google.com/maps/search/?api=1&query=${a.latitude},${a.longitude}');
    } else {
      uri = Uri.parse('https://www.google.com/maps/search/?api=1&query=${Uri.encodeComponent(a.fullAddress)}');
    }
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  // =========================
  // Invoice Export (kept from original)
  // =========================
  Future<void> _exportInvoice(OrderModel order, {bool preview = false, bool share = false}) async {
    setState(() => _loadingInvoice = true);

    try {
      final pdf = pw.Document();
      final font = await PdfGoogleFonts.nunitoRegular();
      final fontBold = await PdfGoogleFonts.nunitoBold();

      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(32),
          build: (context) => [
            // Header
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text('INVOICE', style: pw.TextStyle(font: fontBold, fontSize: 28)),
                    pw.SizedBox(height: 4),
                    pw.Text('Agrimore', style: pw.TextStyle(font: fontBold, fontSize: 16)),
                  ],
                ),
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    pw.Text('Order #${order.orderNumber ?? order.id.substring(0, 8)}',
                        style: pw.TextStyle(font: fontBold, fontSize: 12)),
                    pw.SizedBox(height: 4),
                    pw.Text(DateFormat('dd MMM yyyy').format(order.createdAt),
                        style: pw.TextStyle(font: font, fontSize: 11)),
                  ],
                ),
              ],
            ),
            pw.SizedBox(height: 30),
            // Customer info
            pw.Container(
              padding: const pw.EdgeInsets.all(16),
              decoration: pw.BoxDecoration(
                color: PdfColors.grey100,
                borderRadius: pw.BorderRadius.circular(8),
              ),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text('Bill To:', style: pw.TextStyle(font: fontBold, fontSize: 12)),
                  pw.SizedBox(height: 8),
                  pw.Text(order.deliveryAddress.name, style: pw.TextStyle(font: fontBold, fontSize: 14)),
                  pw.SizedBox(height: 4),
                  pw.Text(order.deliveryAddress.phone, style: pw.TextStyle(font: font, fontSize: 11)),
                  pw.SizedBox(height: 4),
                  pw.Text(order.deliveryAddress.fullAddress, style: pw.TextStyle(font: font, fontSize: 11)),
                ],
              ),
            ),
            pw.SizedBox(height: 24),
            // Items table
            pw.Table(
              border: pw.TableBorder.all(color: PdfColors.grey300),
              columnWidths: {
                0: const pw.FlexColumnWidth(3),
                1: const pw.FlexColumnWidth(1),
                2: const pw.FlexColumnWidth(1.5),
                3: const pw.FlexColumnWidth(1.5),
              },
              children: [
                pw.TableRow(
                  decoration: const pw.BoxDecoration(color: PdfColors.grey200),
                  children: [
                    pw.Padding(padding: const pw.EdgeInsets.all(8), child: pw.Text('Item', style: pw.TextStyle(font: fontBold, fontSize: 11))),
                    pw.Padding(padding: const pw.EdgeInsets.all(8), child: pw.Text('Qty', style: pw.TextStyle(font: fontBold, fontSize: 11))),
                    pw.Padding(padding: const pw.EdgeInsets.all(8), child: pw.Text('Price', style: pw.TextStyle(font: fontBold, fontSize: 11))),
                    pw.Padding(padding: const pw.EdgeInsets.all(8), child: pw.Text('Total', style: pw.TextStyle(font: fontBold, fontSize: 11))),
                  ],
                ),
                ...order.items.map((item) => pw.TableRow(
                      children: [
                        pw.Padding(padding: const pw.EdgeInsets.all(8), child: pw.Text(item.productName, style: pw.TextStyle(font: font, fontSize: 10))),
                        pw.Padding(padding: const pw.EdgeInsets.all(8), child: pw.Text('${item.quantity}', style: pw.TextStyle(font: font, fontSize: 10))),
                        pw.Padding(padding: const pw.EdgeInsets.all(8), child: pw.Text('Rs.${item.price.toStringAsFixed(0)}', style: pw.TextStyle(font: font, fontSize: 10))),
                        pw.Padding(padding: const pw.EdgeInsets.all(8), child: pw.Text('Rs.${(item.price * item.quantity).toStringAsFixed(0)}', style: pw.TextStyle(font: font, fontSize: 10))),
                      ],
                    )),
              ],
            ),
            pw.SizedBox(height: 20),
            // Totals
            pw.Align(
              alignment: pw.Alignment.centerRight,
              child: pw.Container(
                width: 200,
                child: pw.Column(
                  children: [
                    pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
                      pw.Text('Subtotal:', style: pw.TextStyle(font: font, fontSize: 11)),
                      pw.Text('Rs.${order.subtotal.toStringAsFixed(2)}', style: pw.TextStyle(font: font, fontSize: 11)),
                    ]),
                    pw.SizedBox(height: 6),
                    pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
                      pw.Text('Delivery:', style: pw.TextStyle(font: font, fontSize: 11)),
                      pw.Text('Rs.${order.deliveryCharge.toStringAsFixed(2)}', style: pw.TextStyle(font: font, fontSize: 11)),
                    ]),
                    pw.SizedBox(height: 6),
                    pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
                      pw.Text('Tax:', style: pw.TextStyle(font: font, fontSize: 11)),
                      pw.Text('Rs.${order.tax.toStringAsFixed(2)}', style: pw.TextStyle(font: font, fontSize: 11)),
                    ]),
                    pw.Divider(),
                    pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
                      pw.Text('TOTAL:', style: pw.TextStyle(font: fontBold, fontSize: 14)),
                      pw.Text('Rs.${order.total.toStringAsFixed(2)}', style: pw.TextStyle(font: fontBold, fontSize: 14)),
                    ]),
                  ],
                ),
              ),
            ),
          ],
        ),
      );

      final bytes = await pdf.save();

      if (preview) {
        await Printing.layoutPdf(onLayout: (_) => bytes);
      } else if (share) {
        await Printing.sharePdf(bytes: bytes, filename: 'invoice_${order.orderNumber ?? order.id}.pdf');
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error generating invoice: $e')),
      );
    } finally {
      setState(() => _loadingInvoice = false);
    }
  }
}

/// ADMR-39: resolves the delivery-proof Storage PATH riderExceptions.ts's
/// attachProofCore writes into a short-lived download URL, only when
/// shown — mirrors rider_review_sheet.dart's own `_KycTile` pattern
/// exactly (the established way this app already handles a stored
/// Storage path that needs admin's own read permission to resolve).
class _DeliveryProofTile extends StatefulWidget {
  const _DeliveryProofTile({required this.order});
  final OrderModel order;

  @override
  State<_DeliveryProofTile> createState() => _DeliveryProofTileState();
}

class _DeliveryProofTileState extends State<_DeliveryProofTile> {
  late final Future<String> _url = _resolve();

  Future<String> _resolve() async {
    final path = widget.order.deliveryProofPath;
    if (path == null) return '';
    try {
      return await FirebaseStorage.instance.ref(path).getDownloadURL();
    } catch (e) {
      debugPrint('Delivery proof unavailable: $e');
      return '';
    }
  }

  Future<void> _open(String url) async {
    await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    final order = widget.order;
    return FutureBuilder<String>(
      future: _url,
      builder: (context, snap) {
        final loading = snap.connectionState != ConnectionState.done;
        final url = snap.data ?? '';
        return InkWell(
          onTap: url.isEmpty ? null : () => _open(url),
          borderRadius: BorderRadius.circular(10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  width: 64,
                  height: 64,
                  color: Colors.grey.shade100,
                  child: loading
                      ? const Center(
                          child: SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        )
                      : url.isEmpty
                          ? Center(child: Icon(Icons.image_not_supported_outlined, color: Colors.grey.shade400, size: 20))
                          : Image.network(
                              url,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => Center(
                                child: Icon(Icons.broken_image_outlined, color: Colors.grey.shade400, size: 20),
                              ),
                            ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Delivery proof photo',
                        style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12, color: Colors.grey.shade800)),
                    if (order.deliveryProofAttachedAt != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        'Attached ${DateFormat('MMM d, yyyy • hh:mm a').format(order.deliveryProofAttachedAt!)}'
                        '${order.deliveryProofAttachedBy != null ? ' by rider ${order.deliveryProofAttachedBy!.length > 8 ? order.deliveryProofAttachedBy!.substring(0, 8) : order.deliveryProofAttachedBy}' : ''}',
                        style: TextStyle(color: Colors.grey.shade500, fontSize: 11),
                      ),
                    ],
                    if (!loading && url.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      const Text('Tap to view full size',
                          style: TextStyle(color: AdminColors.primary, fontSize: 11, fontWeight: FontWeight.w600)),
                    ],
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}