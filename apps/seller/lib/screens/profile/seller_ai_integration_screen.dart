import 'package:agrimore_ui/agrimore_ui.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';

// Phase AI-4C — the SAME conditional-import idiom
// apps/marketplace/lib/screens/employee/onboarding/widgets/onboarding_payment_step.dart
// already uses, so the web JS-interop implementation (dart:js_interop) is
// compiled out of every non-web build entirely (D-SELLER-AI-WEB-ONLY,
// mirroring D2). This screen's own payment button is ALSO kIsWeb-gated
// below -- belt and suspenders, not either/or.
import '../../services/razorpay_web.dart' if (dart.library.io) '../../services/razorpay_stub.dart';
import '../../providers/seller_ai_connection_provider.dart';

String _asString(dynamic v) => v is String ? v : '';

enum _Phase {
  idle, // not connected, showing the pay-to-activate CTA
  creatingOrder,
  awaitingModal,
  verifying,
  connecting, // has a verified paymentId, showing the provider/API-key form
  moneyTakenNotConnected,
  error,
  connected,
}

/// Phase AI-4C — apps/seller's own AI Assistant settings screen. Reached
/// from SellerProfileScreen's own menu (a new "AI Integration" item),
/// matching that screen's OWN convention of pushing a dedicated screen for
/// a stateful, multi-step feature (like 'Quote Requests' -> SellerRfqInboxScreen)
/// rather than a simple info dialog.
///
/// Chain: `createSellerAiActivationOrder` (server prices the ₹50 fee, NEVER
/// a client-supplied amount) -> Razorpay modal for that already-created
/// order via `RazorpayWebService.openCheckoutForExistingOrder` -> the SAME
/// generic `verifyRazorpayPayment` the onboarding-fee flow uses -> only a
/// `verified: true` response lets the provider/API-key form appear, which
/// then calls `connectSellerAiProvider`. The modal's own success callback
/// is NEVER treated as proof of payment by itself, mirroring
/// onboarding_payment_step.dart's own documented S4 rule exactly.
class SellerAiIntegrationScreen extends StatefulWidget {
  const SellerAiIntegrationScreen({super.key});

  @override
  State<SellerAiIntegrationScreen> createState() => _SellerAiIntegrationScreenState();
}

class _SellerAiIntegrationScreenState extends State<SellerAiIntegrationScreen> {
  static const _accentColor = Color(0xFF2D7D3C);

  final _connectionProvider = SellerAiConnectionProvider();
  final _apiKeyController = TextEditingController();
  String _selectedProvider = 'gemini';

  _Phase _phase = _Phase.idle;
  String? _errorMessage;
  String? _verifiedPaymentId;
  RazorpayWebService? _razorpayWeb;

  bool get _busy =>
      _phase == _Phase.creatingOrder ||
      _phase == _Phase.awaitingModal ||
      _phase == _Phase.verifying;

  @override
  void initState() {
    super.initState();
    _connectionProvider.addListener(_onConnectionChanged);
    _connectionProvider.loadStatus();
  }

  void _onConnectionChanged() {
    if (!mounted) return;
    setState(() {
      if (_connectionProvider.connected && _phase != _Phase.connecting) {
        _phase = _Phase.connected;
      }
    });
  }

  @override
  void dispose() {
    _connectionProvider.removeListener(_onConnectionChanged);
    _connectionProvider.dispose();
    _razorpayWeb?.dispose();
    _apiKeyController.dispose();
    super.dispose();
  }

  Future<void> _startPayment() async {
    // Defense-in-depth alongside the kIsWeb check in build() below.
    if (!kIsWeb) return;

    setState(() {
      _phase = _Phase.creatingOrder;
      _errorMessage = null;
    });

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      setState(() {
        _phase = _Phase.error;
        _errorMessage = 'Please sign in again and retry.';
      });
      return;
    }

    Map<String, dynamic> orderResult;
    try {
      orderResult = await _connectionProvider.createActivationOrder();
    } on FirebaseFunctionsException catch (e) {
      if (!mounted) return;
      setState(() {
        _phase = _Phase.error;
        _errorMessage = e.message ?? 'Could not start payment. Please try again.';
      });
      return;
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _phase = _Phase.error;
        _errorMessage = 'Could not start payment. Please try again.';
      });
      return;
    }

    final keyId = _asString(orderResult['keyId']);
    final orderId = _asString(orderResult['orderId']);
    final amountPaise = orderResult['amount'] is num ? (orderResult['amount'] as num).toInt() : 0;

    setState(() => _phase = _Phase.awaitingModal);

    _razorpayWeb = RazorpayWebService();
    _razorpayWeb!.initialize(
      onSuccess: (paymentId, returnedOrderId, signature) {
        _handleModalSuccess(paymentId: paymentId, orderId: returnedOrderId ?? orderId, signature: signature);
      },
      onFailure: (error) {
        if (!mounted) return;
        if (error.toLowerCase().contains('cancel')) {
          setState(() => _phase = _Phase.idle);
        } else {
          setState(() {
            _phase = _Phase.error;
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
      description: 'AgriMore AI Assistant — One-Time Activation Fee',
    );
  }

  /// The Razorpay modal reporting success is NEVER, by itself, treated as
  /// proof of payment -- it only triggers server-side verification, exactly
  /// like onboarding_payment_step.dart's own _handleModalSuccess.
  Future<void> _handleModalSuccess({
    required String paymentId,
    required String? orderId,
    required String? signature,
  }) async {
    if (!mounted) return;
    setState(() => _phase = _Phase.verifying);

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
      // The Razorpay modal already reported success, so from the payer's
      // point of view money may have moved, even though connectSellerAiProvider
      // was never called. Never show a bare failure here.
      setState(() {
        _phase = _Phase.moneyTakenNotConnected;
        _verifiedPaymentId = paymentId;
      });
      return;
    }

    setState(() {
      _phase = _Phase.connecting;
      _verifiedPaymentId = paymentId;
    });
  }

  Future<void> _submitConnect() async {
    final apiKey = _apiKeyController.text.trim();
    if (apiKey.isEmpty || _verifiedPaymentId == null) return;

    try {
      await _connectionProvider.connect(
        provider: _selectedProvider,
        apiKey: apiKey,
        paymentId: _verifiedPaymentId!,
      );
      // _connected flips via the Firestore listener; _onConnectionChanged
      // moves _phase to .connected once it lands.
    } on FirebaseFunctionsException catch (e) {
      if (!mounted) return;
      // The payment IS verified at this point -- a connect failure here is
      // a key-validation or transient error, not a lost payment, so this
      // does NOT go to moneyTakenNotConnected (the payment is still
      // available to retry connectSellerAiProvider with the same paymentId).
      setState(() {
        _errorMessage = e.message ?? 'Could not connect. Please check your API key and try again.';
      });
    }
  }

  Future<void> _disconnect() async {
    try {
      await _connectionProvider.disconnect();
      if (!mounted) return;
      setState(() {
        _phase = _Phase.idle;
        _verifiedPaymentId = null;
        _apiKeyController.clear();
      });
    } on FirebaseFunctionsException catch (e) {
      if (!mounted) return;
      setState(() => _errorMessage = e.message ?? 'Could not disconnect. Please try again.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF121212) : const Color(0xFFF5F7FA),
      appBar: AppBar(title: const Text('AI Integration')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: _buildBody(isDark),
      ),
    );
  }

  Widget _buildBody(bool isDark) {
    if (_connectionProvider.isLoading) {
      return const Center(child: Padding(padding: EdgeInsets.all(32), child: CircularProgressIndicator()));
    }
    if (_phase == _Phase.connected || (_connectionProvider.connected && _phase != _Phase.connecting)) {
      return _buildConnectedCard(isDark);
    }
    if (_phase == _Phase.connecting) {
      return _buildConnectForm(isDark);
    }
    if (_phase == _Phase.moneyTakenNotConnected) {
      return _buildMoneyTakenNotice(isDark);
    }
    return _buildActivationCard(isDark);
  }

  Widget _buildActivationCard(bool isDark) {
    // D-SELLER-AI-WEB-ONLY -- the payment surface itself does not exist on
    // a non-web build. This branch is the ONLY thing rendered on Android;
    // no payment button, no code path that can initiate a charge.
    if (!kIsWeb) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.info.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.info.withValues(alpha: 0.4)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.laptop_mac_rounded, color: AppColors.infoDark),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'AI Assistant activation is available on the AgriMore seller website '
                '(agrimore.in) — the app does not process this payment.',
                style: TextStyle(color: AppColors.infoDark, fontSize: 13, height: 1.4, fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: isDark ? Colors.grey[900] : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDark ? Colors.grey[800]! : const Color(0xFFE5E7EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Activate your AI Assistant',
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: isDark ? Colors.white : Colors.black87)),
          const SizedBox(height: 4),
          Text(
            'Connect your own ChatGPT or Gemini API key for sales analysis, pricing insights, and business questions.',
            style: TextStyle(fontSize: 12, color: isDark ? Colors.grey[400] : const Color(0xFF6B7280)),
          ),
          if (_phase == _Phase.error && _errorMessage != null) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: AppColors.error.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
              child: Text(_errorMessage!, style: TextStyle(color: AppColors.errorDark, fontSize: 12)),
            ),
          ],
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _busy ? null : _startPayment,
              style: ElevatedButton.styleFrom(
                backgroundColor: _accentColor,
                disabledBackgroundColor: _accentColor.withValues(alpha: 0.5),
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
                  : const Text('Activate — ₹50', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildConnectForm(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: isDark ? Colors.grey[900] : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDark ? Colors.grey[800]! : const Color(0xFFE5E7EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.check_circle_outline_rounded, color: _accentColor),
              const SizedBox(width: 8),
              Text('Payment received',
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: isDark ? Colors.white : Colors.black87)),
            ],
          ),
          const SizedBox(height: 4),
          Text('Now add your AI provider details to finish connecting.',
              style: TextStyle(fontSize: 12, color: isDark ? Colors.grey[400] : const Color(0xFF6B7280))),
          const SizedBox(height: 14),
          Text('Provider',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: isDark ? Colors.white : Colors.black87)),
          const SizedBox(height: 6),
          DropdownButtonFormField<String>(
            initialValue: _selectedProvider,
            decoration: const InputDecoration(border: OutlineInputBorder()),
            items: const [
              DropdownMenuItem(value: 'gemini', child: Text('Google Gemini')),
              DropdownMenuItem(value: 'chatgpt', child: Text('ChatGPT (OpenAI)')),
            ],
            onChanged: (v) => setState(() => _selectedProvider = v ?? _selectedProvider),
          ),
          const SizedBox(height: 14),
          Text('API Key',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: isDark ? Colors.white : Colors.black87)),
          const SizedBox(height: 6),
          TextField(
            controller: _apiKeyController,
            obscureText: true,
            decoration: const InputDecoration(border: OutlineInputBorder(), hintText: 'Paste your API key'),
          ),
          if (_errorMessage != null) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: AppColors.error.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
              child: Text(_errorMessage!, style: TextStyle(color: AppColors.errorDark, fontSize: 12)),
            ),
          ],
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _connectionProvider.isSubmitting ? null : _submitConnect,
              style: ElevatedButton.styleFrom(
                backgroundColor: _accentColor,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              child: _connectionProvider.isSubmitting
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white))
                  : const Text('Connect', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildConnectedCard(bool isDark) {
    final providerLabel = _connectionProvider.provider == 'chatgpt' ? 'ChatGPT (OpenAI)' : 'Google Gemini';
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: isDark ? Colors.grey[900] : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDark ? Colors.grey[800]! : const Color(0xFFE5E7EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: _accentColor.withValues(alpha: 0.1),
                child: const Icon(Icons.smart_toy_outlined, color: _accentColor),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('AI Assistant connected',
                        style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: isDark ? Colors.white : Colors.black87)),
                    Text(providerLabel, style: TextStyle(fontSize: 12, color: isDark ? Colors.grey[400] : const Color(0xFF6B7280))),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: _connectionProvider.isSubmitting ? null : _disconnect,
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.red,
                side: const BorderSide(color: Colors.red),
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
              child: _connectionProvider.isSubmitting
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2.5))
                  : const Text('Disconnect'),
            ),
          ),
        ],
      ),
    );
  }

  /// Worded like onboarding_payment_step.dart's own _buildMoneyTakenNotice:
  /// never a bare failure when money was taken. The seller can simply retry
  /// connecting with the same, still-verified paymentId (connectSellerAiProvider
  /// checks verified_payments, not a one-shot consumption at this stage).
  Widget _buildMoneyTakenNotice(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.info.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.info.withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.check_circle_outline_rounded, color: AppColors.infoDark),
              const SizedBox(width: 8),
              Expanded(
                child: Text('Payment received', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: AppColors.infoDark)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'We received your payment, but could not confirm it just now. Please try connecting again — '
            'you will not be charged twice for the same payment.',
            style: TextStyle(color: AppColors.infoDark, fontSize: 13, height: 1.5),
          ),
          if (_verifiedPaymentId != null) ...[
            const SizedBox(height: 10),
            SelectableText('Payment reference: $_verifiedPaymentId',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.infoDark)),
          ],
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: () => setState(() {
                _phase = _Phase.connecting;
                _errorMessage = null;
              }),
              child: const Text('Try connecting again'),
            ),
          ),
        ],
      ),
    );
  }

  String _phaseLabel() {
    return switch (_phase) {
      _Phase.creatingOrder => 'Preparing payment…',
      _Phase.awaitingModal => 'Opening payment…',
      _Phase.verifying => 'Verifying payment…',
      _ => 'Please wait…',
    };
  }
}
