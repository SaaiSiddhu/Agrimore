import 'package:agrimore_ui/agrimore_ui.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../../../services/checkout_recovery_service.dart';
import '../../../../services/mobile_checkout_flow.dart';

/// Composite checkout status, using the shared theme and button.
class SavedCheckoutCard extends StatelessWidget {
  const SavedCheckoutCard(
      {super.key,
      required this.request,
      required this.isBusy,
      required this.onContinue});
  final PendingCheckoutRequest request;
  final bool isBusy;
  final VoidCallback onContinue;

  @override
  Widget build(BuildContext context) {
    final unpaidDraft =
        request.stage == 'draft' && request.intent['paymentMethod'] != 'cod';
    final message = switch (request.stage) {
      'draft' when unpaidDraft =>
        'No payment window was opened for this draft. Review your cart to continue.',
      'completed' =>
        'Your order confirmation is saved. Continue to finish checkout.',
      'ready' => 'Continue to confirm your order.',
      _ => 'Check the payment outcome and continue this checkout.',
    };
    final theme = Theme.of(context);
    return Card(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Saved checkout', style: theme.textTheme.titleMedium),
          const SizedBox(height: 6),
          Text(message, style: theme.textTheme.bodyMedium),
          const SizedBox(height: 12),
          CustomButton(
              text: unpaidDraft ? 'Review cart' : 'Continue checkout',
              isLoading: isBusy,
              onPressed: onContinue),
        ]),
      ),
    );
  }
}

Future<void> continueSavedCheckout(
    BuildContext context, MobileCheckoutFlow flow) async {
  final request = flow.pending;
  if (request == null || flow.isBusy) {
    return;
  }
  if (request.stage == 'draft' && request.intent['paymentMethod'] != 'cod') {
    final confirmed = await DialogHelper.showConfirmation(context,
        title: 'Review checkout draft?',
        message:
            'This draft has no payment window. Remove the draft and review your current cart before starting checkout again.',
        confirmText: 'Review cart');
    if (!context.mounted ||
        confirmed != true ||
        flow.pending?.requestId != request.requestId ||
        flow.pending?.ownerId != request.ownerId) {
      return;
    }
    await flow.discardDraft();
    return;
  }
  final address = request.intent['deliveryAddress'];
  await flow.resume(
      customer: MobileCheckoutCustomer(
    name: address is Map ? (address['name'] as String? ?? '') : '',
    phone: address is Map ? (address['phone'] as String? ?? '') : '',
    email: FirebaseAuth.instance.currentUser?.email ?? '',
  ));
}
