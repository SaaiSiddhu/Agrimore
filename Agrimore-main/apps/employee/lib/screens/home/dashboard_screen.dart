import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
// agrimore_ui re-exports agrimore_core, so this single import supplies both
// AppColors and EmployeeModel (importing agrimore_core as well trips
// unnecessary_import, and this app's analyze baseline is zero issues).
import 'package:agrimore_ui/agrimore_ui.dart';
import '../wallet/wallet_screen.dart';
import '../wallet/payout_screen.dart';
import '../profile/profile_screen.dart';
import '../orders/order_detail_screen.dart';

/// Employee sales dashboard. Lists orders attributed to this employee
/// (orders.employeeUid == currentUid — OrderModel already has this field,
/// no new shared-model work needed) and shows a commission summary read
/// directly from wallets/{uid}.lifetimeEarnings (simpler and already kept
/// accurate by payEmployeeCommissionOnDelivery's own increment, rather than
/// re-summing commissionAmount across delivered orders client-side).
class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  // Phase 19: this stream previously had NO limit — an unbounded realtime
  // listener on a collection that only grows with an associate's tenure is
  // a real, avoidable cost (locked decision 6), not a hypothetical one, on
  // the screen every associate opens most often. Mirrors wallet_screen.dart's
  // _pageSize exactly: starts at a sensible page size, grows on request via
  // "Load more" rather than fetching the whole order history up front.
  int _pageSize = 20;

  static String _formatMoney(double value) => 'Rs ${value.toStringAsFixed(0)}';

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;

    if (uid == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text('My Sales'),
        actions: [
          IconButton(
            icon: const Icon(Icons.account_balance_wallet_outlined),
            tooltip: 'Wallet',
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const WalletScreen()),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.payments_outlined),
            tooltip: 'Payouts',
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const PayoutScreen()),
            ),
          ),
          // Phase 16C, Workstream 2: the old bare, unlabelled logout icon
          // here signed a user out on a single mis-tap, with no
          // confirmation. Sign-out now lives in ProfileScreen, labelled and
          // behind a confirmation dialog — this button just navigates.
          IconButton(
            icon: const Icon(Icons.person_outline_rounded),
            tooltip: 'Profile',
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const ProfileScreen()),
            ),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {},
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Phase 16B, Workstream 3b: first thing on the screen. This is
            // how an associate is attributed at all, so it outranks the
            // wallet figures below it.
            //
            // Phase 16C, Workstream 1: the associate-code card and the new
            // onboarding-fee-status card both read nothing but
            // employees/{uid} — so they now share ONE StreamBuilder/
            // listener on that document instead of each opening its own.
            // Two independent `.snapshots()` calls on the same document is
            // a real, avoidable doubling of ongoing read cost for a screen
            // every associate opens regularly (locked decision 6). Placed
            // directly below the code card: both describe the same
            // "employees/{uid}" facts (the code, then the fee gate behind
            // it), before the screen moves on to a different document
            // (wallets/{uid}) for the money summary below.
            _buildAssociateSection(uid),
            const SizedBox(height: 16),
            _buildCommissionSummary(uid),
            const SizedBox(height: 16),
            const Text(
              'Orders Attributed To You',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            _buildOrdersList(uid),
          ],
        ),
      ),
    );
  }

  Widget _buildAssociateSection(String uid) {
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream:
          FirebaseFirestore.instance.collection('employees').doc(uid).snapshots(),
      builder: (context, snap) {
        return Column(
          children: [
            _AssociateCodeCard(snapshot: snap),
            const SizedBox(height: 12),
            _OnboardingFeeStatusCard(snapshot: snap),
          ],
        );
      },
    );
  }

  Widget _buildCommissionSummary(String uid) {
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance.collection('wallets').doc(uid).snapshots(),
      builder: (context, snap) {
        final data = snap.data?.data();
        final balance = (data?['balance'] as num?)?.toDouble() ?? 0.0;
        final lifetimeEarnings =
            (data?['lifetimeEarnings'] as num?)?.toDouble() ?? 0.0;

        return Row(
          children: [
            Expanded(
              child: _SummaryCard(
                icon: Icons.account_balance_wallet_rounded,
                label: 'Wallet Balance',
                value: _formatMoney(balance),
                color: const Color(0xFF16A34A),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _SummaryCard(
                icon: Icons.trending_up_rounded,
                label: 'Total Commission',
                value: _formatMoney(lifetimeEarnings),
                color: const Color(0xFF2563EB),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildOrdersList(String uid) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      // Phase 19: bounded by _pageSize (see field comment), mirroring
      // wallet_screen.dart's _buildTransactionsList exactly. orderBy +
      // limit rather than the previous unbounded .where(...) stream —
      // sorting client-side after an unbounded fetch was the old shape;
      // sorting server-side lets the limit actually bound the read.
      // Requires the new orders(employeeUid ASC, createdAt DESC) composite
      // index added in this same phase — see firestore.indexes.json.
      stream: FirebaseFirestore.instance
          .collection('orders')
          .where('employeeUid', isEqualTo: uid)
          .orderBy('createdAt', descending: true)
          .limit(_pageSize)
          .snapshots(),
      builder: (context, snap) {
        if (snap.hasError) {
          return Padding(
            padding: const EdgeInsets.all(16),
            child: Text('Error: ${snap.error}'),
          );
        }
        if (!snap.hasData) {
          return const Padding(
            padding: EdgeInsets.all(24),
            child: Center(child: CircularProgressIndicator()),
          );
        }
        // Already ordered by the query itself (createdAt desc) — no
        // client-side re-sort needed.
        final docs = snap.data!.docs;

        if (docs.isEmpty) {
          return const Padding(
            padding: EdgeInsets.all(24),
            child: Center(child: Text('No orders attributed to you yet')),
          );
        }

        final reachedPageLimit = docs.length >= _pageSize;

        return Column(
          children: [
            ...docs.map((doc) {
            final d = doc.data();
            final orderNumber = d['orderNumber']?.toString() ?? doc.id;
            final total = (d['total'] as num?)?.toDouble() ?? 0.0;
            final status = (d['orderStatus'] ?? 'pending').toString();
            // Phase 16C-0: `orderMode` is already present on every fetched
            // order document (createOrder.ts writes it as "B2C" | "B2B" on
            // every order, no legacy documents predate the field) — this is
            // the same document already streamed by the query above, so
            // reading it here adds no Firestore read. Anything other than
            // an exact (case-normalised) "B2B"/"B2C" renders no badge at
            // all, rather than guessing or printing "null".
            final rawMode = d['orderMode'];
            final normalizedMode =
                rawMode is String ? rawMode.trim().toUpperCase() : null;
            final modeLabel = normalizedMode == 'B2B'
                ? 'B2B'
                : normalizedMode == 'B2C'
                    ? 'Retail'
                    : null;

            return Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                // Phase 16C, Workstream 3: passes the SAME already-fetched
                // document straight into OrderDetailScreen — no re-query by
                // id, no second read (locked decision 6).
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => OrderDetailScreen(orderId: doc.id, orderData: d),
                  ),
                ),
                title: Text('#$orderNumber'),
                // Wrap (not Row) so a long order total plus the mode badge
                // reflow onto their own line on a narrow screen instead of
                // overflowing horizontally — dropping to a second line
                // costs nothing here, but clipping either piece of text
                // would (apps/marketplace has shipped a product-card
                // overflow bug from exactly this kind of fixed-width Row).
                subtitle: Wrap(
                  spacing: 8,
                  runSpacing: 2,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(_formatMoney(total)),
                    if (modeLabel != null)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade200,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          modeLabel,
                          style: TextStyle(
                            fontSize: 9.5,
                            fontWeight: FontWeight.w700,
                            color: Colors.grey.shade700,
                          ),
                        ),
                      ),
                  ],
                ),
                trailing: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: status == 'delivered' || status == 'completed'
                        ? Colors.green.shade50
                        : Colors.amber.shade50,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    status.toUpperCase(),
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: status == 'delivered' || status == 'completed'
                          ? Colors.green.shade800
                          : Colors.amber.shade900,
                    ),
                  ),
                ),
              ),
            );
            }),
            if (reachedPageLimit) ...[
              const SizedBox(height: 8),
              Center(
                child: TextButton(
                  onPressed: () => setState(() => _pageSize += 20),
                  child: const Text('Load more'),
                ),
              ),
            ],
          ],
        );
      },
    );
  }
}

/// Phase 16B, Workstream 3 — the associate's own attribution code.
///
/// Until this phase the dashboard showed an associate their wallet balance
/// and their attributed orders, but never the one thing they need in order
/// to be attributed at all: their own `employeeCode`. They had no way to
/// tell a customer what to type at checkout.
///
/// Reads `employees/{uid}` directly, which firestore.rules already permits
/// and nothing more —
///   allow read: if isAuthenticated() && (isOwner(employeeId) || isAdmin());
/// (firestore.rules:718). An associate can read their own document and no
/// one else's; this phase adds no rule and widens none (S3/S6). No associate
/// list, and no other associate's code, is reachable from anywhere in this
/// widget.
///
/// Copy constraint (3e): this card explains the mechanism only. It states no
/// figure, makes no promise, and implies no guaranteed income.
///
/// Phase 16C, Workstream 1: takes the employees/{uid} snapshot from the
/// dashboard's own shared StreamBuilder (see _buildAssociateSection) rather
/// than opening its own — the exact same state branching as before, just no
/// longer opening a second listener on a document _OnboardingFeeStatusCard
/// (below) reads too.
class _AssociateCodeCard extends StatelessWidget {
  final AsyncSnapshot<DocumentSnapshot<Map<String, dynamic>>> snapshot;

  const _AssociateCodeCard({required this.snapshot});

  static const String _guidance =
      'Share this code with your customers. When someone enters it at '
      'checkout, that order is recorded against you. Commission applies to '
      'eligible orders once they are completed, in line with your programme '
      'terms.';

  /// Shown when the associate has not cleared the ₹500 onboarding gate.
  /// Scoped to RETAIL deliberately: `createOrder.ts` drops B2C attribution
  /// for an associate whose gate is not cleared, but B2B attribution has
  /// never required it — so "no retail orders" is the accurate statement and
  /// "your code does not work" would not be.
  static const String _onboardingNote =
      'Complete your onboarding so retail orders that use your code can be '
      'recorded against you.';

  @override
  Widget build(BuildContext context) {
    // State: the read failed (offline, or rules denied it).
    if (snapshot.hasError) {
      return _shell(
        child: _message('Could not load your associate code right now.'),
      );
    }

    // State: still loading.
    if (!snapshot.hasData) {
      return _shell(child: _message('Loading your code…'));
    }

    // State: employees/{uid} is missing. EmployeeAuthProvider signs a
    // user out when this document is absent at login, so reaching this
    // branch means it vanished mid-session — rare, but it must not
    // render a blank card.
    final doc = snapshot.data!;
    if (!doc.exists || doc.data() == null) {
      return _shell(
        child: _message(
          'We could not find your associate profile. Please sign out and '
          'sign in again, or contact support.',
        ),
      );
    }

    final employee = EmployeeModel.fromMap(doc.data()!, doc.id);
    final code = employee.employeeCode.trim();

    // State: the document exists but carries no code.
    if (code.isEmpty) {
      return _shell(
        child: _message(
          'No associate code has been assigned to your account yet. '
          'Please contact support.',
        ),
      );
    }

    // State: code present. Shown whether or not the onboarding gate is
    // cleared — hiding it would be wrong, because a B2B order attributes
    // on this code regardless of the gate; an uncleared gate only stops
    // RETAIL attribution, which the note below says plainly.
    return _shell(
      child: _codeBody(context, code, employee.hasClearedOnboardingGate),
    );
  }

  /// The card chrome, shared by every state so the surface never jumps size
  /// or colour as the stream resolves. Emerald per the brand identity
  /// (AppColors.primary), matching _SummaryCard's rounded/elevated shape.
  Widget _shell({required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.primary, AppColors.primaryDark],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.25),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: child,
    );
  }

  Widget _message(String text) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Icon(Icons.badge_outlined, color: Colors.white, size: 20),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 13,
              height: 1.4,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }

  Widget _codeBody(BuildContext context, String code, bool gateCleared) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.badge_outlined, color: AppColors.accent, size: 20),
            const SizedBox(width: 8),
            const Text(
              'Your Associate Code',
              style: TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.3,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),

        // The code itself — tap anywhere on it to copy (3c).
        Row(
          children: [
            Expanded(
              child: InkWell(
                onTap: () => _copy(context, code),
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.16),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: AppColors.accent.withValues(alpha: 0.55),
                    ),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              code,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 26,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 3,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Tap to copy',
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.75),
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Icon(Icons.copy_rounded,
                          color: AppColors.accent, size: 20),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            _ActionButton(
              icon: Icons.ios_share_rounded,
              label: 'Share',
              onTap: () => _share(code),
            ),
          ],
        ),

        const SizedBox(height: 14),
        Text(
          _guidance,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.92),
            fontSize: 12,
            height: 1.45,
            fontWeight: FontWeight.w500,
          ),
        ),

        if (!gateCleared) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: AppColors.accent.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(10),
              border:
                  Border.all(color: AppColors.accent.withValues(alpha: 0.5)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.info_outline_rounded,
                    color: AppColors.accent, size: 16),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _onboardingNote,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11.5,
                      height: 1.4,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  /// 3c — Flutter's built-in clipboard; no dependency added for this.
  Future<void> _copy(BuildContext context, String code) async {
    final messenger = ScaffoldMessenger.of(context);
    await Clipboard.setData(ClipboardData(text: code));
    HapticFeedback.selectionClick();
    messenger.showSnackBar(
      const SnackBar(
        content: Text('Associate code copied'),
        behavior: SnackBarBehavior.floating,
        duration: Duration(seconds: 2),
      ),
    );
  }

  Future<void> _share(String code) async {
    await Share.share('Use my AgriMore Sales Associate code $code at checkout.');
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _ActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          color: AppColors.accent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 18, color: AppColors.primaryDarker),
            const SizedBox(height: 3),
            Text(
              label,
              style: const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w900,
                color: AppColors.primaryDarker,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Phase 16C, Workstream 1 — the ₹500 onboarding fee's gate status, made
/// visible in the associate's own app for the first time. Every one of
/// these facts (onboardingPaid, onboardingWaived, onboardingFeeAmount,
/// onboardingPaidAt, onboardingRefundedAt) already exists on
/// employees/{uid}, written only by functions/src/employee/activationCore.ts
/// and adminOnboardingActions.ts (S4) — this widget only ever reads them.
///
/// Deliberately separate from _AssociateCodeCard's own onboarding-gate note
/// above: that note is a short "why your code might not work for retail"
/// nudge; this card is the full, honest breakdown of which of the five real
/// states applies. Deliberately says nothing about `status`/approval
/// anywhere — clearing this gate is not approval (locked decision 4), and
/// the two must stay visually and textually separate.
///
/// No payment affordance anywhere in this widget, in any state (locked
/// decision 2) — "not yet cleared" is informational prose only.
class _OnboardingFeeStatusCard extends StatelessWidget {
  final AsyncSnapshot<DocumentSnapshot<Map<String, dynamic>>> snapshot;

  const _OnboardingFeeStatusCard({required this.snapshot});

  @override
  Widget build(BuildContext context) {
    // Loading, error, and missing-document states are already explained in
    // full, directly above, by _AssociateCodeCard reading this exact same
    // snapshot — repeating a second near-identical banner here would be
    // noise, not honesty, so this card simply doesn't render until there is
    // a real employee document to describe.
    if (snapshot.hasError || !snapshot.hasData) {
      return const SizedBox.shrink();
    }
    final doc = snapshot.data!;
    if (!doc.exists || doc.data() == null) {
      return const SizedBox.shrink();
    }

    final employee = EmployeeModel.fromMap(doc.data()!, doc.id);
    final state = _resolveState(employee);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(state.icon, color: state.color, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Onboarding Fee',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: Colors.black54,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  state.message,
                  style: const TextStyle(
                    fontSize: 13,
                    height: 1.4,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Order matters: a refund reverses a prior paid/waived clearance, so it
  // must be checked FIRST — mirrors EmployeeModel.hasClearedOnboardingGate's
  // own precedence ((paid || waived) && refundedAt == null).
  _FeeStatusInfo _resolveState(EmployeeModel employee) {
    if (employee.onboardingRefundedAt != null) {
      return _FeeStatusInfo(
        icon: Icons.undo_rounded,
        color: Colors.orange.shade700,
        message: 'Your onboarding fee was refunded. If you have questions, '
            'please contact support.',
      );
    }

    if (employee.onboardingPaid) {
      final amount = employee.onboardingFeeAmount;
      // A legacy or malformed document can carry onboardingPaid:true with
      // no usable amount — never fall back to a hardcoded figure (a
      // hardcoded "₹500" would be a guess, not a fact, and could be wrong).
      final amountIsUsable = amount != null && amount.isFinite && amount > 0;
      return _FeeStatusInfo(
        icon: Icons.check_circle_rounded,
        color: Colors.green.shade700,
        message: amountIsUsable
            ? 'Onboarding fee paid: ${PriceFormatter.formatPrice(amount)}.'
            : 'Your onboarding fee has been received.',
      );
    }

    if (employee.onboardingWaived) {
      return const _FeeStatusInfo(
        icon: Icons.verified_outlined,
        color: Color(0xFF2563EB),
        message: 'Your onboarding fee was waived.',
      );
    }

    return const _FeeStatusInfo(
      icon: Icons.info_outline_rounded,
      color: Colors.black54,
      message: "You haven't completed the onboarding fee yet.",
    );
  }
}

class _FeeStatusInfo {
  final IconData icon;
  final Color color;
  final String message;

  const _FeeStatusInfo({
    required this.icon,
    required this.color,
    required this.message,
  });
}

class _SummaryCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _SummaryCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
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
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(height: 10),
          Text(
            label,
            style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
          ),
        ],
      ),
    );
  }
}
