import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:agrimore_ui/agrimore_ui.dart';
import '../../auth/login_screen.dart';
import '../../../providers/auth_provider.dart' as app_auth;
import 'widgets/onboarding_info_sections.dart';
import 'widgets/onboarding_details_step.dart';
import 'widgets/onboarding_payment_step.dart';
import 'widgets/onboarding_confirmation_step.dart';

/// Phase 16B-2 — the ₹500 Sales Associate onboarding page.
///
/// Deliberately NOT wrapped in `AuthGuard` (see routes.dart's comment at
/// this route's registration). `AuthGuard` on web unconditionally replaces
/// its child with `LandingScreen` when signed out — which would make the
/// info deck (fee, benefits, mandatory disclosures) unreachable for exactly
/// the signed-out visitor Workstream 1f says must be able to read it, since
/// `getAssociateOnboardingConfig` itself requires no auth.
///
/// RETURN-PATH DESIGN NOTE (Workstream 2b), read before changing this file:
/// this codebase's ONLY sign-in flow (`login_screen.dart` → phone OTP →
/// `otp_verification_screen.dart`) calls
/// `Navigator.pushAndRemoveUntil(..., (route) => false)` on success — it
/// unconditionally clears the ENTIRE navigation stack and lands on a fixed
/// destination, regardless of how the login screen was reached. No screen
/// in this app (not `sellerApply`, not `wallet`, not anything reachable via
/// `AuthGuard`) survives that pop chain — this is a structural property of
/// the shared auth flow, not something specific to this page, and touching
/// `otp_verification_screen.dart`/`PostAuthRouter` to add a return-route
/// parameter is out of this phase's scope (it is not in Section 8's reading
/// list and would change behaviour for every other login in the app).
/// Given that, "return them here afterwards" is implemented as STATE
/// RESUMPTION rather than a preserved Navigator stack: every time this
/// screen builds, it re-derives which step to show from the CURRENT sign-in
/// state and the CURRENT `employees/{uid}` document (see `_resolveStep`
/// below) — so a visitor who signs in and then taps back into this page
/// (one tap from Profile → "Become a Sales Associate", per Workstream 1h)
/// lands on the correct next step automatically, never back at square one.
class AssociateOnboardingScreen extends StatefulWidget {
  // Phase ONBOARD-1: present only when this page was opened via the mobile
  // app's "Pay on Web" handoff button (routes.dart parses it off the URL's
  // `?handoff=` query string). Null on every normal, direct visit.
  final String? handoffCode;
  const AssociateOnboardingScreen({super.key, this.handoffCode});

  @override
  State<AssociateOnboardingScreen> createState() =>
      _AssociateOnboardingScreenState();
}

enum _LoadState { loading, loaded, error }

class _AssociateOnboardingScreenState
    extends State<AssociateOnboardingScreen> {
  _LoadState _loadState = _LoadState.loading;
  Map<String, dynamic>? _config;
  String? _loadError;
  bool _handoffAttempted = false;

  @override
  void initState() {
    super.initState();
    _tryRedeemHandoff();
    _loadConfig();
  }

  /// Phase ONBOARD-1 — a code past this point is worthless (server-side
  /// single-use, transactionally enforced), so any failure here is silent:
  /// the visitor simply lands on the ordinary signed-out "Sign In" prompt
  /// this page already shows, never a dead end. Never overwrites an
  /// ALREADY signed-in session (e.g. a page reload after redeeming once).
  Future<void> _tryRedeemHandoff() async {
    if (_handoffAttempted) return;
    final code = widget.handoffCode;
    if (!kIsWeb || code == null || code.isEmpty) return;
    if (FirebaseAuth.instance.currentUser != null) return;
    _handoffAttempted = true;
    try {
      final result = await FirebaseFunctions.instance
          .httpsCallable('redeemOnboardingWebHandoff')
          .call<Map<String, dynamic>>({'code': code});
      final token = result.data['customToken'];
      if (token is String && token.isNotEmpty) {
        await FirebaseAuth.instance.signInWithCustomToken(token);
      }
    } catch (e) {
      debugPrint('Onboarding handoff redemption failed: $e');
    }
  }

  /// Workstream 1e — network/error resilience with a retry affordance, no
  /// crash. `getAssociateOnboardingConfig` needs no auth (Section 4), so
  /// this call is made unconditionally, before we know whether the visitor
  /// is signed in.
  Future<void> _loadConfig() async {
    setState(() => _loadState = _LoadState.loading);
    try {
      final result = await FirebaseFunctions.instance
          .httpsCallable('getAssociateOnboardingConfig')
          .call<Map<String, dynamic>>();
      if (!mounted) return;
      setState(() {
        _config = _deepMap(result.data);
        _loadState = _LoadState.loaded;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loadError = e.toString();
        _loadState = _LoadState.error;
      });
    }
  }

  /// Cloud Functions callable results decode as nested `Map<Object?,
  /// Object?>` on Flutter — normalised here, once, so every section widget
  /// below can assume plain `Map<String, dynamic>` / `List<dynamic>`.
  static Map<String, dynamic> _deepMap(dynamic v) {
    if (v is Map) {
      return v.map((k, value) => MapEntry(k.toString(), _deepValue(value)));
    }
    return {};
  }

  static dynamic _deepValue(dynamic v) {
    if (v is Map) return _deepMap(v);
    if (v is List) return v.map(_deepValue).toList();
    return v;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        foregroundColor: const Color(0xFF111827),
        title: const Text(
          'Sales Associate Registration',
          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
        ),
      ),
      body: SafeArea(
        child: switch (_loadState) {
          _LoadState.loading => const Center(child: CircularProgressIndicator()),
          _LoadState.error => _buildErrorState(),
          _LoadState.loaded => _buildLoaded(),
        },
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.wifi_off_rounded, size: 48, color: Color(0xFF9CA3AF)),
            const SizedBox(height: 16),
            const Text(
              'Could not load the associate registration page.',
              textAlign: TextAlign.center,
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
            ),
            const SizedBox(height: 8),
            Text(
              _loadError ?? '',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 12, color: Color(0xFF9CA3AF)),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _loadConfig,
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
              child: const Text('Retry', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoaded() {
    final config = _config!;
    final copy = _deepMap(config['copy']);
    final isEnabled = config['isEnabled'] == true;
    final unavailableReason = config['unavailableReason'] as String?;
    final disclosures = (config['mandatoryDisclosures'] as List? ?? [])
        .map((e) => e.toString())
        .toList();
    // Phase 16B-3, Defect 1: the top-level, AUTHORITATIVE fee fields —
    // never the copy deck's own static fee strings — passed into the two
    // sections that render a rupee figure.
    final feeAmount = config['feeAmount'] is num ? config['feeAmount'] as num : null;
    final currency = config['currency'] as String?;

    final auth = context.watch<app_auth.AuthProvider>();
    final isSignedIn = auth.isLoggedIn;
    final uid = auth.userUid;

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Workstream 1a — the info deck, in the specified order, entirely
          // config-driven (1b). Renders regardless of sign-in state (1f).
          OnboardingHeaderSection(copy: copy, feeAmount: feeAmount, currency: currency),
          const SizedBox(height: 16),
          OnboardingWhyFeeSection(copy: copy),
          const SizedBox(height: 16),
          OnboardingBenefitGroupsSection(copy: copy),
          const SizedBox(height: 16),
          OnboardingEarningsExplainerSection(copy: copy),
          const SizedBox(height: 16),
          OnboardingJourneyStepsSection(copy: copy),
          const SizedBox(height: 16),
          OnboardingSummaryCardSection(copy: copy, feeAmount: feeAmount, currency: currency),
          const SizedBox(height: 16),
          // Workstream 1c/D5 — mandatory disclosures, ABOVE the CTA below.
          OnboardingDisclosuresSection(disclosures: disclosures),
          const SizedBox(height: 20),

          // The interactive step. Everything below this line is the "CTA"
          // referenced by 1a's ordering — disclosures above are guaranteed
          // to render before any of it.
          if (!isEnabled)
            _buildUnavailable(unavailableReason)
          else if (!isSignedIn)
            _buildSignInPrompt()
          else
            _EmployeeStateGate(uid: uid!, copy: copy, feeAmount: feeAmount, currency: currency),

          const SizedBox(height: 20),
          OnboardingSupportContactSection(copy: copy),
        ],
      ),
    );
  }

  /// Workstream 1d — isEnabled:false or a present unavailableReason: show
  /// the information with the CTA disabled and a plain explanation.
  Widget _buildUnavailable(String? reason) {
    final message = switch (reason) {
      'config_missing' || 'config_invalid' =>
        'Associate registration is being set up. Please check back soon.',
      'disabled' => 'Associate registration is temporarily paused. Please check back soon.',
      _ => 'Associate registration is not available right now. Please check back soon.',
    };
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFEF3C7),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFFDE68A)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.info_outline_rounded, color: Color(0xFFB45309)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(color: Color(0xFF92400E), fontWeight: FontWeight.w600, height: 1.4),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSignInPrompt() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE5E7EB)),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 12, offset: const Offset(0, 4)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Sign in to continue', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
          const SizedBox(height: 8),
          const Text(
            'Registration details and the onboarding fee require an AgriMore account. '
            'After signing in, come back to Profile → "Become a Sales Associate" to '
            'pick up where you left off.',
            style: TextStyle(color: Color(0xFF6B7280), fontSize: 13, height: 1.5),
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const LoginScreen()),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              child: const Text('Sign In', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
            ),
          ),
        ],
      ),
    );
  }
}

/// Workstream 2d — routes a signed-in visitor by `employees/{uid}` state.
/// A `StreamBuilder` (not a one-shot `get()`) so state changes made
/// elsewhere (an admin approval, a webhook activation racing the client
/// callback) are reflected without the visitor needing to refresh.
class _EmployeeStateGate extends StatelessWidget {
  final String uid;
  final Map<String, dynamic> copy;
  final num? feeAmount;
  final String? currency;

  const _EmployeeStateGate({
    required this.uid,
    required this.copy,
    this.feeAmount,
    this.currency,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance.collection('employees').doc(uid).snapshots(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting && !snap.hasData) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 24),
            child: Center(child: CircularProgressIndicator()),
          );
        }
        if (snap.hasError) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Text('Could not load your registration status. Please try again.'),
          );
        }

        final doc = snap.data;
        final data = doc?.data();

        // State: no employees/{uid} document yet → details step (2a/2b).
        if (data == null) {
          return OnboardingDetailsStep(uid: uid);
        }

        final onboardingRefundedAt = data['onboardingRefundedAt'];
        final onboardingPaid = data['onboardingPaid'] == true;
        final onboardingWaived = data['onboardingWaived'] == true;
        final gateCleared = (onboardingPaid || onboardingWaived) && onboardingRefundedAt == null;
        final status = (data['status'] as String?) ?? 'pending';
        final employeeCode = (data['employeeCode'] as String?) ?? '';

        // State: refunded (2d) — createAssociateOnboardingPayment will
        // itself refuse to re-charge; show the same message up front so the
        // visitor never even reaches that failure.
        if (onboardingRefundedAt != null) {
          return _buildRefundedNotice(copy);
        }

        // State: gate cleared → confirmation (Workstream 4), regardless of
        // admin-approval `status` — D6, paying is not approval, so this is
        // shown whether status is pending, approved, or suspended.
        if (gateCleared) {
          // Phase 16B-3, Defect 2: onboardingPaid and onboardingWaived are
          // mutually exclusive by server-side design
          // (waiveAssociateOnboardingFee explicitly refuses to waive an
          // already-paid associate — adminOnboardingActions.ts line 72-77),
          // so this data should never show both true. If it somehow does,
          // a real charge outranks a waiver flag: treat as PAID. Data
          // source for the truthful figure is onboardingFeeAmount — the
          // amount ACTUALLY charged at payment time (activationCore.ts line
          // 166), never the current config, which may have changed since.
          final rawFeeAmount = data['onboardingFeeAmount'];
          final paidAmount = rawFeeAmount is num ? rawFeeAmount : null;
          return OnboardingConfirmationStep(
            employeeCode: employeeCode,
            status: status,
            wasWaived: onboardingWaived && !onboardingPaid,
            paidAmount: paidAmount,
          );
        }

        // State: details submitted, fee not yet paid → payment step.
        return OnboardingPaymentStep(copy: copy, feeAmount: feeAmount, currency: currency);
      },
    );
  }

  Widget _buildRefundedNotice(Map<String, dynamic> copy) {
    final support = copy['supportContact'] as Map<String, dynamic>?;
    final email = support?['email'] as String? ?? '';
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFEE2E2),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFFCA5A5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Your onboarding fee was refunded.',
            style: TextStyle(fontWeight: FontWeight.w800, color: Color(0xFF991B1B)),
          ),
          const SizedBox(height: 6),
          Text(
            'Please contact support if you would like to re-activate your account'
            '${email.isNotEmpty ? ' ($email)' : ''}.',
            style: const TextStyle(color: Color(0xFF991B1B), fontSize: 13, height: 1.4),
          ),
        ],
      ),
    );
  }
}
