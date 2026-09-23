import 'package:agrimore_ui/agrimore_ui.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../l10n/app_localizations.dart';
import '../../providers/seller_application_provider.dart';
import 'steps/business_step.dart';
import 'steps/documents_step.dart';
import 'steps/location_step.dart';
import 'steps/payout_step.dart';
import 'steps/review_step.dart';
import 'widgets/application_copy.dart';

/// A-05 Application stepper (ADR §10.1, ADR-S12). Hosts the five steps over
/// one [SellerApplicationProvider]; each step saves the draft before moving on.
class ApplicationScreen extends StatelessWidget {
  const ApplicationScreen({super.key, this.provider});

  /// Injected in tests; defaults to a Firebase-backed provider.
  final SellerApplicationProvider? provider;

  @override
  Widget build(BuildContext context) {
    final injected = provider;
    return injected != null
        ? ChangeNotifierProvider<SellerApplicationProvider>.value(value: injected, child: const _Stepper())
        : ChangeNotifierProvider<SellerApplicationProvider>(
            create: (_) => SellerApplicationProvider()..loadOrStart(),
            child: const _Stepper(),
          );
  }
}

class _Stepper extends StatelessWidget {
  const _Stepper();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final app = context.watch<SellerApplicationProvider>();

    if (!app.isLoaded) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final step = app.step;
    final Widget body = switch (step) {
      0 => const BusinessStep(),
      1 => const LocationStep(),
      2 => const DocumentsStep(),
      3 => const PayoutStep(),
      _ => const ReviewStep(),
    };

    return PopScope(
      canPop: step == 0,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) app.back();
      },
      child: Scaffold(
        body: SafeArea(
          bottom: false,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(WsSpace.page, WsSpace.s16, WsSpace.page, WsSpace.s8),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: WsSize.formMaxWidth),
                    child: WsStepHeader(
                      stepLabel: l10n.stepOf(step + 1, SellerApplicationProvider.stepCount),
                      title: ApplicationCopy.stepTitle(l10n, step),
                      current: step,
                      total: SellerApplicationProvider.stepCount,
                    ),
                  ),
                ),
              ),
              // Each step owns its scroll body and its StepFooter.
              Expanded(child: KeyedSubtree(key: ValueKey(step), child: body)),
            ],
          ),
        ),
      ),
    );
  }
}

/// Shared scaffold of a step: scrolling, width-capped form + sticky footer.
class StepBody extends StatelessWidget {
  const StepBody({super.key, required this.children, required this.footer});

  final List<Widget> children;
  final Widget footer;

  @override
  Widget build(BuildContext context) {
    final app = context.watch<SellerApplicationProvider>();
    final l10n = AppLocalizations.of(context);
    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(WsSpace.page, WsSpace.s16, WsSpace.page, WsSpace.s32),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: WsSize.formMaxWidth),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (app.lastActionFailed) ...[
                      SaInfoBanner(variant: SaBannerVariant.error, message: l10n.saveFailed),
                      const SizedBox(height: WsSpace.s16),
                    ],
                    ...children,
                  ],
                ),
              ),
            ),
          ),
        ),
        footer,
      ],
    );
  }
}
