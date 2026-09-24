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
import '../../design_system/design_system.dart';
import '../../l10n/app_localizations.dart';
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
        _errorMessage = AppLocalizations.of(context).aiSignInAgain;
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
        _errorMessage = e.code == 'unauthenticated' ? AppLocalizations.of(context).aiSignInAgain : AppLocalizations.of(context).aiStartFailed;
      });
      return;
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _phase = _Phase.error;
        _errorMessage = AppLocalizations.of(context).aiStartFailed;
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
            _errorMessage = AppLocalizations.of(context).aiStartFailed;
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
      debugPrint('connectSellerAiProvider failed: ${e.code}');
      setState(() {
        _errorMessage = AppLocalizations.of(context).aiConnectFailed;
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
      debugPrint('disconnect failed: ${e.code}');
      setState(() => _errorMessage = AppLocalizations.of(context).aiDisconnectFailed);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: SellerAppBar.detail(context, title: l10n.aiConnectionTitle),
      body: SellerPage(gap: SellerSpace.s16, children: [_buildBody()]),
    );
  }

  Widget _buildBody() {
    final l10n = AppLocalizations.of(context);
    if (_connectionProvider.isLoading) return SellerLoadingView(label: l10n.dsLoading);
    if (_phase == _Phase.connected || (_connectionProvider.connected && _phase != _Phase.connecting)) {
      return _buildConnectedCard();
    }
    if (_phase == _Phase.connecting) return _buildConnectForm();
    if (_phase == _Phase.moneyTakenNotConnected) return _buildMoneyTakenNotice();
    return _buildActivationCard();
  }

  Widget _card(List<Widget> children) => SellerCard(child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: children));

  /// Board 23-01 "not activated": sparkles, what it does, and — on the
  /// phone — the website-only notice (D-SELLER-AI-WEB-ONLY: no payment
  /// surface exists in a non-web build).
  Widget _buildActivationCard() {
    final l10n = AppLocalizations.of(context);
    final text = context.text;
    final header = [
      const Center(child: SellerIconTile(icon: SellerIcons.ai, circle: true, size: SellerSize.avatarXl)),
      const SizedBox(height: SellerSpace.s12),
      Text(l10n.aiActivateTitle, style: text.titleLarge, textAlign: TextAlign.center),
      const SizedBox(height: SellerSpace.s4),
      Text(l10n.aiActivateBody, style: text.bodyLarge!.copyWith(color: context.colors.textSecondary), textAlign: TextAlign.center),
      const SizedBox(height: SellerSpace.s16),
    ];
    if (!kIsWeb) {
      return _card([...header, SellerBanner(tone: SellerTone.info, message: l10n.aiWebOnly)]);
    }
    return _card([
      ...header,
      if (_phase == _Phase.error && _errorMessage != null) ...[
        SellerBanner(tone: SellerTone.danger, message: _errorMessage!, announce: true),
        const SizedBox(height: SellerSpace.s12),
      ],
      SellerButton(label: l10n.aiActivateCta, loading: _busy, loadingLabel: _phaseLabel(l10n), onPressed: _startPayment),
    ]);
  }

  Widget _buildConnectForm() {
    final l10n = AppLocalizations.of(context);
    final text = context.text;
    return _card([
      Row(children: [
        const SellerIconTile(icon: SellerIcons.success, tone: SellerTone.success, circle: true),
        const SizedBox(width: SellerSpace.s12),
        Expanded(child: Text(l10n.aiPaymentReceived, style: text.titleMedium)),
      ]),
      const SizedBox(height: SellerSpace.s8),
      Text(l10n.aiConnectHint, style: text.bodyMedium),
      const SizedBox(height: SellerSpace.s16),
      SellerSelectField<String>(
        label: l10n.aiProvider,
        value: _selectedProvider,
        options: [SellerOption('gemini', l10n.aiProviderGemini), SellerOption('chatgpt', l10n.aiProviderChatgpt)],
        onChanged: (v) => setState(() => _selectedProvider = v ?? _selectedProvider),
      ),
      const SizedBox(height: SellerSpace.s16),
      SellerTextField(
        label: l10n.aiApiKey,
        hint: l10n.aiApiKeyHint,
        controller: _apiKeyController,
        obscure: true,
        helper: l10n.aiKeyNeverShown,
      ),
      if (_errorMessage != null) ...[
        const SizedBox(height: SellerSpace.s12),
        SellerBanner(tone: SellerTone.danger, message: _errorMessage!, announce: true),
      ],
      const SizedBox(height: SellerSpace.s16),
      SellerButton(label: l10n.aiConnect, loading: _connectionProvider.isSubmitting, loadingLabel: l10n.aiConnecting, onPressed: _submitConnect),
    ]);
  }

  Widget _buildConnectedCard() {
    final l10n = AppLocalizations.of(context);
    final text = context.text;
    final providerLabel = _connectionProvider.provider == 'chatgpt' ? l10n.aiProviderChatgpt : l10n.aiProviderGemini;
    return _card([
      const Center(child: SellerIconTile(icon: SellerIcons.success, tone: SellerTone.success, circle: true, size: SellerSize.avatarXl)),
      const SizedBox(height: SellerSpace.s12),
      Text(l10n.aiConnected, style: text.titleLarge, textAlign: TextAlign.center),
      Text(l10n.aiConnectedBody, style: text.bodyLarge!.copyWith(color: context.colors.textSecondary), textAlign: TextAlign.center),
      const SizedBox(height: SellerSpace.s16),
      SellerKeyValueRow(label: l10n.aiProvider, value: providerLabel),
      Text(l10n.aiKeyNeverShown, style: text.bodySmall),
      if (_errorMessage != null) ...[
        const SizedBox(height: SellerSpace.s12),
        SellerBanner(tone: SellerTone.danger, message: _errorMessage!, announce: true),
      ],
      const SizedBox(height: SellerSpace.s16),
      SellerButton.dangerOutline(
        label: l10n.aiDisconnect,
        icon: SellerIcons.logOut,
        loading: _connectionProvider.isSubmitting,
        onPressed: _confirmDisconnect,
      ),
    ]);
  }

  Future<void> _confirmDisconnect() async {
    final l10n = AppLocalizations.of(context);
    final yes = await sellerConfirm(
      context,
      title: l10n.aiDisconnectTitle,
      message: l10n.aiDisconnectBody,
      confirmLabel: l10n.aiDisconnect,
      cancelLabel: l10n.cancel,
      destructive: true,
    );
    if (yes) await _disconnect();
  }

  /// Never a bare failure when money was taken: the seller can retry
  /// connecting with the same, still-verified payment.
  Widget _buildMoneyTakenNotice() {
    final l10n = AppLocalizations.of(context);
    final text = context.text;
    return _card([
      SellerBanner(tone: SellerTone.info, title: l10n.aiPaymentReceived, message: l10n.aiMoneyTaken),
      if (_verifiedPaymentId != null) ...[
        const SizedBox(height: SellerSpace.s12),
        SelectableText(l10n.aiPaymentReference(_verifiedPaymentId!), style: text.labelLarge!.tabular),
      ],
      const SizedBox(height: SellerSpace.s12),
      SellerButton.secondary(
        label: l10n.aiRetryConnect,
        icon: SellerIcons.refresh,
        onPressed: () => setState(() {
          _phase = _Phase.connecting;
          _errorMessage = null;
        }),
      ),
    ]);
  }

  String _phaseLabel(AppLocalizations l10n) => switch (_phase) {
        _Phase.creatingOrder => l10n.aiPreparingPayment,
        _Phase.awaitingModal => l10n.aiOpeningPayment,
        _Phase.verifying => l10n.aiVerifyingPayment,
        _ => l10n.aiPleaseWait,
      };
}
