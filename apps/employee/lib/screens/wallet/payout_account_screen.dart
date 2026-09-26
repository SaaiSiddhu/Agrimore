import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:agrimore_ui/agrimore_ui.dart';
import '../../utils/sa_formatters.dart';

enum _AccountType { bank, upi }

/// Refusals from requestEmployeePayoutChange/cancelEmployeePayoutChange, in
/// associate-facing words. Mirrors seller_wallet_admin.dart's own refusal
/// pattern (functions/src/employee/employeePayoutAccount.ts).
String _payoutChangeRefusal(String code, String? reason) => switch (reason) {
      'already_pending' => 'A change is already waiting for review.',
      'not_pending' => 'This request has already been reviewed.',
      'invalid_accountHolder' => 'Enter the account holder name (2–100 characters).',
      'invalid_bankName' => 'Enter a valid bank name.',
      'invalid_accountNumber' => 'Enter a valid account number.',
      'invalid_ifsc' => 'Enter a valid 11-character IFSC code.',
      'invalid_upiId' => 'Enter a valid UPI ID (e.g. name@bank).',
      _ => code == 'unauthenticated'
          ? 'Sign in again to continue.'
          : (code == 'unavailable' || code == 'deadline-exceeded')
              ? 'No connection. Try again.'
              : 'Could not submit that. Please try again.',
    };

/// Screen allowing a Sales Associate to manage and register their payout destination.
///
/// Supports Bank Account details (Account Number, IFSC, Bank Name) and UPI ID.
///
/// Phase ADMR-5: previously wrote straight to `employees/{uid}` with no
/// review step at all — an associate could redirect their own payout
/// destination the instant before an admin paid them out. Now submits a
/// request via `requestEmployeePayoutChange`; an admin must approve it
/// (`reviewEmployeePayoutChange`) before it takes effect. While a request is
/// pending (`employee_wallets/{uid}.payoutChangePending`), the associate sees
/// its status instead of the edit form and may cancel it.
class PayoutAccountScreen extends StatefulWidget {
  final String? employeeUid;
  final Stream<DocumentSnapshot<Map<String, dynamic>>>? employeeStream;

  const PayoutAccountScreen({
    super.key,
    this.employeeUid,
    this.employeeStream,
  });

  @override
  State<PayoutAccountScreen> createState() => _PayoutAccountScreenState();
}

class _PayoutAccountScreenState extends State<PayoutAccountScreen> {
  final _bankFormKey = GlobalKey<FormState>();
  final _upiFormKey = GlobalKey<FormState>();

  final _holderNameController = TextEditingController();
  final _accountNumberController = TextEditingController();
  final _confirmAccountController = TextEditingController();
  final _ifscController = TextEditingController();
  final _bankNameController = TextEditingController();

  final _upiHolderController = TextEditingController();
  final _upiIdController = TextEditingController();

  _AccountType _accountType = _AccountType.bank;
  bool _isSaving = false;
  bool _initializedFromDb = false;

  @override
  void dispose() {
    _holderNameController.dispose();
    _accountNumberController.dispose();
    _confirmAccountController.dispose();
    _ifscController.dispose();
    _bankNameController.dispose();
    _upiHolderController.dispose();
    _upiIdController.dispose();
    super.dispose();
  }

  void _populateFromData(Map<String, dynamic>? data) {
    if (_initializedFromDb || data == null) return;
    _initializedFromDb = true;

    final method = data['payoutMethod']?.toString().toLowerCase();
    if (method == 'upi') {
      _accountType = _AccountType.upi;
    } else {
      _accountType = _AccountType.bank;
    }

    _holderNameController.text = data['accountHolderName']?.toString() ?? '';
    _accountNumberController.text = data['accountNumber']?.toString() ?? '';
    _confirmAccountController.text = data['accountNumber']?.toString() ?? '';
    _ifscController.text = data['ifscCode']?.toString() ?? '';
    _bankNameController.text = data['bankName']?.toString() ?? '';

    _upiHolderController.text = data['accountHolderName']?.toString() ?? '';
    _upiIdController.text = data['upiId']?.toString() ?? '';
  }

  Future<void> _submitChange(Map<String, dynamic> payload) async {
    HapticFeedback.lightImpact();
    FocusScope.of(context).unfocus();

    setState(() => _isSaving = true);
    try {
      await FirebaseFunctions.instance
          .httpsCallable('requestEmployeePayoutChange')
          .call<Map<String, dynamic>>(payload);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Submitted for review. An admin will approve it before it takes effect.'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } on FirebaseFunctionsException catch (e) {
      debugPrint('requestEmployeePayoutChange: ${e.code} ${e.details}');
      final reason = e.details is Map ? (e.details as Map)['reason'] as String? : null;
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_payoutChangeRefusal(e.code, reason)), behavior: SnackBarBehavior.floating),
        );
      }
    } catch (e) {
      debugPrint('requestEmployeePayoutChange: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_payoutChangeRefusal('unknown', null)), behavior: SnackBarBehavior.floating),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _saveBankDetails(String uid) async {
    if (!_bankFormKey.currentState!.validate()) return;
    await _submitChange({
      'payoutMethod': 'bank',
      'accountHolder': _holderNameController.text.trim(),
      'accountNumber': _accountNumberController.text.trim(),
      'ifsc': _ifscController.text.trim().toUpperCase(),
      'bankName': _bankNameController.text.trim(),
    });
  }

  Future<void> _saveUpiDetails(String uid) async {
    if (!_upiFormKey.currentState!.validate()) return;
    await _submitChange({
      'payoutMethod': 'upi',
      'accountHolder': _upiHolderController.text.trim(),
      'upiId': _upiIdController.text.trim().toLowerCase(),
    });
  }

  Future<void> _cancelPendingRequest(String requestId) async {
    setState(() => _isSaving = true);
    try {
      await FirebaseFunctions.instance
          .httpsCallable('cancelEmployeePayoutChange')
          .call<Map<String, dynamic>>({'requestId': requestId});
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Request cancelled'), behavior: SnackBarBehavior.floating),
        );
      }
    } on FirebaseFunctionsException catch (e) {
      debugPrint('cancelEmployeePayoutChange: ${e.code} ${e.details}');
      final reason = e.details is Map ? (e.details as Map)['reason'] as String? : null;
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_payoutChangeRefusal(e.code, reason)), behavior: SnackBarBehavior.floating),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.saTokens;
    final uid = widget.employeeUid ?? FirebaseAuth.instance.currentUser?.uid;

    if (uid == null) {
      return Scaffold(
        backgroundColor: tokens.pageBackground,
        body: Center(
          child: Text(
            'Sign in to manage payout account',
            style: TextStyle(color: tokens.textSecondary),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: tokens.pageBackground,
      appBar: AppBar(
        title: const Text('Payout Account'),
        leading: IconButton(
          icon: const Icon(SaIcons.arrowLeft),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: widget.employeeStream ??
            FirebaseFirestore.instance
                .collection('employees')
                .doc(uid)
                .snapshots(),
        builder: (context, snap) {
          if (!snap.hasData) {
            return ListView(
              padding: const EdgeInsets.all(SaTokens.space16),
              children: [
                Container(
                  height: 140,
                  decoration: BoxDecoration(
                    color: tokens.surface,
                    borderRadius: BorderRadius.circular(SaTokens.radiusCard),
                    border: Border.all(color: tokens.divider),
                  ),
                ),
              ],
            );
          }

          final data = snap.data?.data();
          _populateFromData(data);

          final savedMethod = data?['payoutMethod']?.toString().toLowerCase();
          final hasSavedBank = savedMethod == 'bank' &&
              (data?['accountNumber']?.toString().isNotEmpty ?? false);
          final hasSavedUpi = savedMethod == 'upi' &&
              (data?['upiId']?.toString().isNotEmpty ?? false);

          // Phase ADMR-5: a pending bank/UPI change blocks the edit form —
          // the associate sees what they submitted and may cancel it, but
          // cannot submit a second one until this is resolved (the same
          // one-at-a-time rule requestEmployeePayoutChangeCore enforces
          // server-side; this is the honest reflection of that, not a
          // client-only convenience).
          return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
            stream: FirebaseFirestore.instance.collection('employee_wallets').doc(uid).snapshots(),
            builder: (context, walletSnap) {
              final pendingId = walletSnap.data?.data()?['payoutChangePending']?.toString();
              final hasPending = pendingId != null && pendingId.isNotEmpty;

              return SingleChildScrollView(
                padding: const EdgeInsets.all(SaTokens.space16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Active Account Card if already registered
                    if (hasSavedBank || hasSavedUpi) ...[
                      _buildRegisteredCard(tokens, data!),
                      const SizedBox(height: SaTokens.space24),
                    ],

                    if (hasPending) ...[
                      _buildPendingCard(tokens, pendingId),
                      const SizedBox(height: SaTokens.space24),
                    ] else ...[
                      Text(
                        'Payout Destination',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              color: tokens.textPrimary,
                            ),
                      ),
                      const SizedBox(height: SaTokens.space4),
                      Text(
                        'Select your preferred payout method. Payouts requested from your wallet will be sent here.',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: tokens.textSecondary,
                            ),
                      ),
                      const SizedBox(height: SaTokens.space16),

                      // Method Selector Toggle
                      _buildMethodToggle(tokens),
                      const SizedBox(height: SaTokens.space24),

                      // Form Container
                      Container(
                        padding: const EdgeInsets.all(SaTokens.space16),
                        decoration: BoxDecoration(
                          color: tokens.surface,
                          borderRadius: BorderRadius.circular(SaTokens.radiusCard),
                          border: Border.all(color: tokens.divider),
                        ),
                        child: _accountType == _AccountType.bank
                            ? _buildBankForm(uid)
                            : _buildUpiForm(uid),
                      ),
                      const SizedBox(height: SaTokens.space24),
                    ],

                    // Ownership disclaimer
                    const SaInfoBanner(
                      title: 'Account Verification Notice',
                      message:
                          'Saving account details does not verify ownership automatically. Ensure the account name matches your legal identity to avoid settlement delays.',
                      variant: SaBannerVariant.info,
                    ),
                    const SizedBox(height: SaTokens.space12),

                    // Security notice
                    const SaInfoBanner(
                      title: 'Security Notice',
                      message:
                          'Never enter your UPI PIN. Receiving payouts NEVER requires you to enter a PIN or authorise a payment.',
                      variant: SaBannerVariant.warning,
                    ),
                    const SizedBox(height: SaTokens.space32),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildRegisteredCard(SalesAssociateTokens tokens, Map<String, dynamic> data) {
    final method = data['payoutMethod']?.toString().toLowerCase();
    final isBank = method == 'bank';
    final holder = data['accountHolderName']?.toString() ?? 'Associate';
    final bankName = data['bankName']?.toString() ?? 'Registered Bank';
    final accNum = data['accountNumber']?.toString() ?? '';
    final upi = data['upiId']?.toString() ?? '';

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
                  'Active Payout Destination',
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
          Text(
            isBank ? bankName : 'UPI ID',
            style: TextStyle(
              fontSize: SaTokens.fsSectionHeading,
              fontWeight: FontWeight.w800,
              color: tokens.textPrimary,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            isBank
                ? SaFormatters.formatMaskedAccount(accNum)
                : upi,
            style: TextStyle(
              fontSize: SaTokens.fsBody,
              fontWeight: FontWeight.w600,
              color: tokens.textSecondary,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            'Name: $holder',
            style: TextStyle(
              fontSize: SaTokens.fsCaption,
              color: tokens.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  /// Phase ADMR-5: shown instead of the edit form while a submitted change
  /// waits for an admin to approve or reject it.
  Widget _buildPendingCard(SalesAssociateTokens tokens, String requestId) {
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
              Icon(Icons.hourglass_top_rounded, color: tokens.textSecondary, size: 20),
              const SizedBox(width: SaTokens.space8),
              Expanded(
                child: Text(
                  'Change Waiting For Review',
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
            'An admin needs to approve your new bank/UPI details before payouts move there. '
            'Your current payout destination (if any) still applies until then.',
            style: TextStyle(fontSize: SaTokens.fsCaption, color: tokens.textSecondary),
          ),
          const SizedBox(height: SaTokens.space16),
          SaLoadingButton(
            text: 'Cancel Request',
            isLoading: _isSaving,
            onPressed: () => _cancelPendingRequest(requestId),
          ),
        ],
      ),
    );
  }

  Widget _buildMethodToggle(SalesAssociateTokens tokens) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: tokens.surface,
        borderRadius: BorderRadius.circular(SaTokens.radiusInput),
        border: Border.all(color: tokens.divider),
      ),
      child: Row(
        children: [
          _buildMethodTab(
            tokens: tokens,
            label: 'Bank Account',
            type: _AccountType.bank,
            icon: Icons.account_balance_outlined,
          ),
          _buildMethodTab(
            tokens: tokens,
            label: 'UPI ID',
            type: _AccountType.upi,
            icon: Icons.qr_code_rounded,
          ),
        ],
      ),
    );
  }

  Widget _buildMethodTab({
    required SalesAssociateTokens tokens,
    required String label,
    required _AccountType type,
    required IconData icon,
  }) {
    final selected = _accountType == type;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() => _accountType = type);
        },
        behavior: HitTestBehavior.opaque,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: selected ? tokens.primarySubtle : Colors.transparent,
            borderRadius: BorderRadius.circular(SaTokens.radiusInput - 3),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 16,
                color: selected ? tokens.primary : tokens.textSecondary,
              ),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: SaTokens.fsLabel,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                    color: selected ? tokens.primary : tokens.textSecondary,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBankForm(String uid) {
    return Form(
      key: _bankFormKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Account Holder Name',
            style: Theme.of(context).textTheme.labelLarge,
          ),
          const SizedBox(height: SaTokens.space4),
          TextFormField(
            controller: _holderNameController,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(
              hintText: 'Full legal name on bank account',
            ),
            validator: (v) =>
                (v == null || v.trim().isEmpty) ? 'Enter account holder name' : null,
          ),
          const SizedBox(height: SaTokens.space16),

          Text(
            'Bank Name',
            style: Theme.of(context).textTheme.labelLarge,
          ),
          const SizedBox(height: SaTokens.space4),
          TextFormField(
            controller: _bankNameController,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(
              hintText: 'e.g. State Bank of India',
            ),
            validator: (v) =>
                (v == null || v.trim().isEmpty) ? 'Enter bank name' : null,
          ),
          const SizedBox(height: SaTokens.space16),

          Text(
            'Account Number',
            style: Theme.of(context).textTheme.labelLarge,
          ),
          const SizedBox(height: SaTokens.space4),
          TextFormField(
            controller: _accountNumberController,
            keyboardType: TextInputType.number,
            obscureText: true,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: const InputDecoration(
              hintText: 'Enter account number',
            ),
            validator: (v) {
              if (v == null || v.trim().length < 9) {
                return 'Enter a valid account number';
              }
              return null;
            },
          ),
          const SizedBox(height: SaTokens.space16),

          Text(
            'Confirm Account Number',
            style: Theme.of(context).textTheme.labelLarge,
          ),
          const SizedBox(height: SaTokens.space4),
          TextFormField(
            controller: _confirmAccountController,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: const InputDecoration(
              hintText: 'Re-enter account number',
            ),
            validator: (v) {
              if (v != _accountNumberController.text) {
                return 'Account numbers do not match';
              }
              return null;
            },
          ),
          const SizedBox(height: SaTokens.space16),

          Text(
            'IFSC Code',
            style: Theme.of(context).textTheme.labelLarge,
          ),
          const SizedBox(height: SaTokens.space4),
          TextFormField(
            controller: _ifscController,
            textCapitalization: TextCapitalization.characters,
            decoration: const InputDecoration(
              hintText: '11-character IFSC code',
            ),
            validator: (v) {
              final val = v?.trim().toUpperCase() ?? '';
              if (val.length != 11 || !RegExp(r'^[A-Z]{4}0[A-Z0-9]{6}$').hasMatch(val)) {
                return 'Enter a valid 11-character IFSC code';
              }
              return null;
            },
          ),
          const SizedBox(height: SaTokens.space24),

          SaLoadingButton(
            text: 'Save Bank Details',
            isLoading: _isSaving,
            onPressed: () => _saveBankDetails(uid),
          ),
        ],
      ),
    );
  }

  Widget _buildUpiForm(String uid) {
    return Form(
      key: _upiFormKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Account Holder Name',
            style: Theme.of(context).textTheme.labelLarge,
          ),
          const SizedBox(height: SaTokens.space4),
          TextFormField(
            controller: _upiHolderController,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(
              hintText: 'Full legal name registered with UPI',
            ),
            validator: (v) =>
                (v == null || v.trim().isEmpty) ? 'Enter account holder name' : null,
          ),
          const SizedBox(height: SaTokens.space16),

          Text(
            'UPI ID / VPA',
            style: Theme.of(context).textTheme.labelLarge,
          ),
          const SizedBox(height: SaTokens.space4),
          TextFormField(
            controller: _upiIdController,
            keyboardType: TextInputType.emailAddress,
            decoration: const InputDecoration(
              hintText: 'e.g. mobile@okhdfcbank or name@upi',
            ),
            validator: (v) {
              final val = v?.trim() ?? '';
              if (!val.contains('@') || val.length < 3) {
                return 'Enter a valid UPI ID (e.g. name@bank)';
              }
              return null;
            },
          ),
          const SizedBox(height: SaTokens.space24),

          SaLoadingButton(
            text: 'Save UPI Details',
            isLoading: _isSaving,
            onPressed: () => _saveUpiDetails(uid),
          ),
        ],
      ),
    );
  }
}
