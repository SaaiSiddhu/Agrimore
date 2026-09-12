import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:agrimore_ui/agrimore_ui.dart';

// Phase 16B-2, Workstream 3c — the SAME conditional-import idiom
// razorpay_service.dart already uses, so the web JS-interop implementation
// (dart:js_interop) is compiled out of every non-web build entirely
// (Play-safety, D2). This screen's own payment button is ALSO kIsWeb-gated
// below — belt and suspenders, not either/or.
import '../../../../services/razorpay_web.dart' if (dart.library.io) '../../../../services/razorpay_stub.dart';
import '../../../../app/routes.dart' show AppRoutes;
import 'onboarding_fee_text.dart';

Map<String, dynamic>? _asMap(dynamic v) => v is Map<String, dynamic> ? v : null;
String _asString(dynamic v) => v is String ? v : '';

enum _PaymentPhase {
  idle,
  creatingOrder,
  awaitingModal,
  verifying,
  activating,
  moneyTakenNotActivated,
  error,
  // Phase ONBOARD-1 — mobile-only: minting the handoff code before opening
  // the external browser.
  creatingHandoff,
}

/// Phase 16B-2, Workstream 3 — the ₹500 payment step.
///
/// Chain (S4): `createAssociateOnboardingPayment` (server prices the fee —
/// S1, NEVER `createRazorpayOrder`) → Razorpay modal, opened for that
/// already-created order via `RazorpayWebService.openCheckoutForExistingOrder`
/// (razorpay_web.dart) → `verifyRazorpayPayment` → `activateAssociateOnboarding`.
/// The modal's own success callback is NEVER treated as proof of payment by
/// itself — only a `verified: true` response from `verifyRazorpayPayment`
/// causes `activateAssociateOnboarding` to be called at all.
class OnboardingPaymentStep extends StatefulWidget {
  final Map<String, dynamic> copy;
  // Phase 16B-3, Defect 1 fix: the authoritative top-level fee fields —
  // discovered missing here during Workstream 5 eye-verification. This CTA
  // button is the literal control a visitor taps to pay; it must never
  // show a figure the server will not actually charge.
  final num? feeAmount;
  final String? currency;
  const OnboardingPaymentStep({super.key, required this.copy, this.feeAmount, this.currency});

  @override
  State<OnboardingPaymentStep> createState() => _OnboardingPaymentStepState();
}

class _OnboardingPaymentStepState extends State<OnboardingPaymentStep> {
  _PaymentPhase _phase = _PaymentPhase.idle;
  String? _errorMessage;
  String? _stuckPaymentId;
  RazorpayWebService? _razorpayWeb;

  bool get _busy =>
      _phase == _PaymentPhase.creatingOrder ||
      _phase == _PaymentPhase.awaitingModal ||
      _phase == _PaymentPhase.verifying ||
      _phase == _PaymentPhase.activating ||
      _phase == _PaymentPhase.creatingHandoff;

  @override
  void dispose() {
    _razorpayWeb?.dispose();
    super.dispose();
  }

  Future<void> _startPayment() async {
    // Defense-in-depth alongside the kIsWeb check in build() below (D2) —
    // this method must never run a payment on a non-web build even if
    // reached some other way.
    if (!kIsWeb) return;

    setState(() {
      _phase = _PaymentPhase.creatingOrder;
      _errorMessage = null;
    });

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      setState(() {
        _phase = _PaymentPhase.error;
        _errorMessage = 'Please sign in again and retry.';
      });
      return;
    }

    Map<String, dynamic> orderResult;
    try {
      // S1 — the fee amount is never sent from this client. The server
      // reads it from settings/associate_onboarding.
      final result = await FirebaseFunctions.instance
          .httpsCallable('createAssociateOnboardingPayment')
          .call<Map<String, dynamic>>();
      orderResult = result.data;
    } on FirebaseFunctionsException catch (e) {
      // Workstream 3g — distinct human message per code. The server's own
      // HttpsError messages here are already plain-language and
      // S7-compliant (no earnings claims); this switch decides tone/retry
      // affordance, and passes the server's own wording through rather than
      // inventing a second copy of it that could drift.
      if (!mounted) return;
      setState(() {
        _phase = _PaymentPhase.error;
        _errorMessage = e.message ?? 'Could not start payment. Please try again.';
      });
      return;
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _phase = _PaymentPhase.error;
        _errorMessage = 'Could not start payment. Please try again.';
      });
      return;
    }

    final keyId = _asString(orderResult['keyId']);
    final orderId = _asString(orderResult['orderId']);
    final amountPaise = orderResult['amount'] is num ? (orderResult['amount'] as num).toInt() : 0;

    setState(() => _phase = _PaymentPhase.awaitingModal);

    _razorpayWeb = RazorpayWebService();
    _razorpayWeb!.initialize(
      onSuccess: (paymentId, returnedOrderId, signature) {
        _handleModalSuccess(paymentId: paymentId, orderId: returnedOrderId ?? orderId, signature: signature);
      },
      onFailure: (error) {
        if (!mounted) return;
        if (error.toLowerCase().contains('cancel')) {
          // Modal dismissed / cancelled before any success — no money
          // moved, reset to idle silently (no scary error for a user who
          // just changed their mind).
          setState(() => _phase = _PaymentPhase.idle);
        } else {
          setState(() {
            _phase = _PaymentPhase.error;
            _errorMessage = error;
          });
        }
      },
    );

    await _razorpayWeb!.openCheckoutForExistingOrder(
      keyId: keyId,
      orderId: orderId,
      amountPaise: amountPaise,
      userName: user.displayName ?? '',
      userEmail: user.email ?? '',
      userPhone: user.phoneNumber ?? '',
      description: 'AgriMore Sales Associate — One-Time Onboarding Fee',
    );
  }

  /// Phase ONBOARD-1 — mobile-only. Mints a short-lived, single-use handoff
  /// code and opens it in the phone's SYSTEM browser (never an in-app
  /// WebView — `LaunchMode.externalApplication`, the same idiom already
  /// used for payment/maps links elsewhere in this app), landing the
  /// visitor on the exact same onboarding page, already signed in.
  Future<void> _startWebHandoff() async {
    if (kIsWeb) return; // defense-in-depth, mirrors _startPayment's own guard
    setState(() {
      _phase = _PaymentPhase.creatingHandoff;
      _errorMessage = null;
    });

    try {
      final result = await FirebaseFunctions.instance
          .httpsCallable('createOnboardingWebHandoff')
          .call<Map<String, dynamic>>();
      final code = _asString(result.data['code']);
      if (code.isEmpty) {
        throw Exception('empty handoff code');
      }

      final uri = Uri.parse('${AppRoutes.baseUrl}${AppRoutes.associateOnboarding}?handoff=$code');
      final launched =
          await canLaunchUrl(uri) && await launchUrl(uri, mode: LaunchMode.externalApplication);

      if (!mounted) return;
      if (!launched) {
        setState(() {
          _phase = _PaymentPhase.error;
          _errorMessage = 'Could not open the browser. Please visit agrimore.in manually and sign in to continue.';
        });
        return;
      }
      setState(() => _phase = _PaymentPhase.idle);
    } on FirebaseFunctionsException catch (e) {
      if (!mounted) return;
      setState(() {
        _phase = _PaymentPhase.error;
        _errorMessage = e.message ?? 'Could not open the payment page. Please try again.';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _phase = _PaymentPhase.error;
        _errorMessage = 'Could not open the payment page. Please try again.';
      });
    }
  }

  /// The Razorpay modal reporting success is NEVER, by itself, treated as
  /// proof of payment (S4) — it only triggers server-side verification.
  Future<void> _handleModalSuccess({
    required String paymentId,
    required String? orderId,
    required String? signature,
  }) async {
    if (!mounted) return;
    setState(() => _phase = _PaymentPhase.verifying);

    bool verified;
    try {
      final result = await FirebaseFunctions.instance
          .httpsCallable('verifyRazorpayPayment')
          .call<Map<String, dynamic>>({
        'paymentId': paymentId,
        'orderId': orderId ?? '',
        'signature': signature ?? '',
      });
      verified = result.data['verified'] == true;
    } catch (_) {
      verified = false;
    }

    if (!mounted) return;

    if (!verified) {
      // Workstream 3f — the Razorpay modal already reported success, so
      // from the payer's point of view money may have moved. Never show a
      // bare failure here: the webhook (razorpayOnboardingWebhook) and the
      // scheduled reconciler independently finish activation server-side.
      setState(() {
        _phase = _PaymentPhase.moneyTakenNotActivated;
        _stuckPaymentId = paymentId;
      });
      return;
    }

    setState(() => _phase = _PaymentPhase.activating);
    try {
      final result = await FirebaseFunctions.instance
          .httpsCallable('activateAssociateOnboarding')
          .call<Map<String, dynamic>>({'paymentId': paymentId, 'razorpayOrderId': orderId});
      // Workstream 3e — alreadyActive is SUCCESS, not an error. Either way,
      // this widget does not need to render a distinct "success" state: the
      // parent _EmployeeStateGate is a StreamBuilder on employees/{uid} and
      // will swap this whole step out for OnboardingConfirmationStep as
      // soon as the write it just caused lands. We simply stay in
      // `activating` (a spinner) rather than a bespoke success screen that
      // would be immediately replaced anyway.
      if (result.data['success'] != true) {
        setState(() {
          _phase = _PaymentPhase.moneyTakenNotActivated;
          _stuckPaymentId = paymentId;
        });
      }
      // else: leave _phase == activating; the StreamBuilder swap handles
      // the rest. If it never arrives (e.g. offline), the spinner simply
      // persists — acceptable, since the server-side webhook/reconciler
      // still complete the activation independently of this session.
    } catch (_) {
      // Workstream 3f again — verification succeeded (payment IS real and
      // captured) but activation itself failed to confirm client-side. Same
      // reassurance framing: the payment is real, completion is automatic.
      setState(() {
        _phase = _PaymentPhase.moneyTakenNotActivated;
        _stuckPaymentId = paymentId;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final summary = _asMap(widget.copy['summaryCard']);
    // Phase 16B-4, Workstream 4: summary['ctaLabel'] (e.g. "Complete
    // Registration — ₹500") is NEVER read here at all, in either branch.
    // Verified reachable pre-fix: loadOnboardingConfig accepts any
    // 3-character string as a valid `currency`, so
    // {feeAmount:100, currency:'USD', isEnabled:true} is a fully enabled
    // config for which authoritativeFeeText correctly returns null (it is
    // INR-only) — the OLD code then fell back to the copy-sourced label,
    // which (as of Phase 16B-4) is now server-interpolated but still
    // COULD carry a currency literal if an admin's override ever slipped
    // one past the server-side mismatch guard for a currency this pattern
    // doesn't scan (findFeeMismatches only recognises ₹/Rs/INR literals,
    // not USD-style ones — see that function's own scope note). Rather
    // than depend on the server guard to keep this button truthful, the
    // button itself now simply never renders a copy-sourced amount: no
    // authoritative figure means no figure at all, ever.
    final feeText = authoritativeFeeText(widget.feeAmount, widget.currency);
    final ctaLabel = feeText != null ? 'Complete Registration — $feeText' : 'Complete Registration';
    final ctaSubtext = _asString(summary?['ctaSubtext']);

    // D2 / Workstream 3c — the Razorpay payment surface itself still never
    // exists on a non-web build (no in-app charge is ever possible here).
    // Phase ONBOARD-1: mobile instead gets a real button that opens the
    // SAME onboarding page in the phone's external browser, already
    // signed in, via a one-time handoff code — see _startWebHandoff.
    if (!kIsWeb) {
      final handoffCtaLabel = feeText != null ? 'Pay $feeText on Web' : 'Pay Onboarding Fee on Web';
      return Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE5E7EB)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Complete your registration', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
            const SizedBox(height: 6),
            const Text(
              'This opens agrimore.in in your browser, already signed in, to '
              'complete the one-time onboarding fee securely.',
              style: TextStyle(fontSize: 12, color: Color(0xFF6B7280), height: 1.4),
            ),
            if (_phase == _PaymentPhase.error && _errorMessage != null) ...[
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: const Color(0xFFFEE2E2), borderRadius: BorderRadius.circular(8)),
                child: Text(_errorMessage!, style: const TextStyle(color: Color(0xFF991B1B), fontSize: 12)),
              ),
            ],
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _busy ? null : _startWebHandoff,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  disabledBackgroundColor: AppColors.primary.withValues(alpha: 0.5),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                child: _busy
                    ? Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white),
                          ),
                          const SizedBox(width: 10),
                          Text(_phaseLabel(), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
                        ],
                      )
                    : Text(handoffCtaLabel, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_phase == _PaymentPhase.moneyTakenNotActivated) ...[
            _buildMoneyTakenNotice(),
          ] else ...[
            const Text('Complete your registration', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
            if (ctaSubtext.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(ctaSubtext, style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280))),
            ],
            if (_phase == _PaymentPhase.error && _errorMessage != null) ...[
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: const Color(0xFFFEE2E2), borderRadius: BorderRadius.circular(8)),
                child: Text(_errorMessage!, style: const TextStyle(color: Color(0xFF991B1B), fontSize: 12)),
              ),
            ],
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                // Workstream 3h — disabled for the entire in-flight window,
                // not just the network call, so a double-tap cannot fire a
                // second createAssociateOnboardingPayment before the first
                // resolves.
                onPressed: _busy ? null : _startPayment,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  disabledBackgroundColor: AppColors.primary.withValues(alpha: 0.5),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                child: _busy
                    ? Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white),
                          ),
                          const SizedBox(width: 10),
                          Text(_phaseLabel(), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
                        ],
                      )
                    : Text(ctaLabel, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _phaseLabel() {
    return switch (_phase) {
      _PaymentPhase.creatingOrder => 'Preparing payment…',
      _PaymentPhase.awaitingModal => 'Opening payment…',
      _PaymentPhase.verifying => 'Verifying payment…',
      _PaymentPhase.activating => 'Activating your account…',
      _PaymentPhase.creatingHandoff => 'Opening browser…',
      _ => 'Please wait…',
    };
  }

  /// Workstream 3f, worded exactly as required: never a bare failure when
  /// money was taken. States plainly that the payment was received, that
  /// activation is completing automatically, and gives a support contact
  /// with the payment id for tracing.
  Widget _buildMoneyTakenNotice() {
    final support = _asMap(widget.copy['supportContact']);
    final email = _asString(support?['email']);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFEFF6FF),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFBFDBFE)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.check_circle_outline_rounded, color: Color(0xFF1D4ED8)),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Payment received',
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: Color(0xFF1E3A8A)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            'We received your payment. Your account is being activated automatically — '
            'this can take a few minutes and does not need any action from you. If your '
            'associate code is not visible after a while, please contact support with the '
            'payment reference below.',
            style: TextStyle(color: Color(0xFF1E3A8A), fontSize: 13, height: 1.5),
          ),
          if (_stuckPaymentId != null) ...[
            const SizedBox(height: 10),
            SelectableText(
              'Payment reference: $_stuckPaymentId',
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF1E3A8A)),
            ),
          ],
          if (email.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text('Support: $email', style: const TextStyle(fontSize: 12, color: Color(0xFF1E3A8A))),
          ],
        ],
      ),
    );
  }
}
