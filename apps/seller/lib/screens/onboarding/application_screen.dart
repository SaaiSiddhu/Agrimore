import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../design_system/design_system.dart';
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

    if (!app.isLoaded) return Scaffold(body: SellerLoadingView(label: l10n.dsLoading));

    final step = app.step;
    final Widget body = switch (step) {
      0 => const BusinessStep(),
      1 => const LocationStep(),
      2 => const DocumentsStep(),
      3 => const PayoutStep(),
      _ => const ReviewStep(),
    };

    // Board 16-03: back + centred "Seller application", "Step N of 5" with
    // connected dots, then the step's title and what it needs.
    return PopScope(
      canPop: step == 0,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) app.back();
      },
      child: Scaffold(
        appBar: SellerAppBar.detail(context, title: l10n.applicationTitle, centerTitle: true, showBack: step > 0, onBack: app.back),
        body: Column(children: [
          // Each step owns its scroll body and its StepFooter.
          Expanded(child: KeyedSubtree(key: ValueKey(step), child: body)),
        ]),
      ),
    );
  }
}

/// Shared scaffold of a step: scrolling, width-capped form + sticky footer
/// (kept in the body so it rises above the keyboard).
class StepBody extends StatelessWidget {
  const StepBody({super.key, required this.children, required this.footer});

  static String? _help(AppLocalizations l10n, int step) => switch (step) {
        0 => l10n.stepBusinessHelp,
        1 => l10n.stepLocationHelp,
        _ => null,
      };

  final List<Widget> children;
  final Widget footer;

  @override
  Widget build(BuildContext context) {
    final app = context.watch<SellerApplicationProvider>();
    final l10n = AppLocalizations.of(context);
    return Column(children: [
      Expanded(
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(context.pageInset, SellerSpace.s8, context.pageInset, SellerSpace.s32),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: SellerSize.formMaxWidth),
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                // Board 16-03: "Step N of 5" with connected dots, then the
                // step's title and what it needs. It scrolls with the form
                // so large text never squeezes the fields.
                SellerStepProgress(
                  current: app.step + 1,
                  total: SellerApplicationProvider.stepCount,
                  stepTitle: ApplicationCopy.stepTitle(l10n, app.step),
                  style: app.step == SellerApplicationProvider.stepCount - 1 ? SellerStepProgressStyle.segments : SellerStepProgressStyle.dots,
                ),
                const SizedBox(height: SellerSpace.s16),
                Semantics(header: true, child: Text(ApplicationCopy.stepTitle(l10n, app.step), style: context.text.headlineMedium)),
                if (_help(l10n, app.step) != null) Text(_help(l10n, app.step)!, style: context.text.bodyLarge!.copyWith(color: context.colors.textSecondary)),
                const SizedBox(height: SellerSpace.s16),
                if (app.lastActionFailed) ...[
                  SellerBanner(tone: SellerTone.danger, message: l10n.saveFailed, announce: true),
                  const SizedBox(height: SellerSpace.s16),
                ],
                ...children,
              ]),
            ),
          ),
        ),
      ),
      footer,
    ]);
  }
}
