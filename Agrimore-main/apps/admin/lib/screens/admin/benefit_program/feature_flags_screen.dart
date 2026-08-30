import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:agrimore_ui/agrimore_ui.dart';

import '../../../providers/benefit_compliance_provider.dart';

class _FlagInfo {
  final String key;
  final String label;
  final String subtitle;
  final bool hardBlocked;

  const _FlagInfo({
    required this.key,
    required this.label,
    required this.subtitle,
    this.hardBlocked = false,
  });
}

const List<_FlagInfo> _kFlags = [
  _FlagInfo(
    key: 'BENEFIT_PROGRAM_ENABLED',
    label: 'Benefit Program Enabled',
    subtitle: 'Master switch. Requires both legal and compliance approval.',
  ),
  _FlagInfo(
    key: 'NEW_ENROLLMENT_ENABLED',
    label: 'New Enrollment Enabled',
    subtitle: 'Allows new customers to join the Benefit Plan. Requires both legal and compliance approval.',
  ),
  _FlagInfo(
    key: 'MONTHLY_CREDIT_ENABLED',
    label: 'Monthly Credit Enabled',
    subtitle: 'Monthly Product Credit disbursement to enrolled customers.',
  ),
  _FlagInfo(
    key: 'PERCENTAGE_BENEFIT_ENABLED',
    label: 'Percentage Benefit Enabled',
    subtitle: 'Percentage-based Benefit Allocation calculation.',
  ),
  _FlagInfo(
    key: 'BENEFIT_EXAMPLES_ENABLED',
    label: 'Benefit Examples Enabled',
    subtitle: 'Shows illustrative Eligible Benefit examples in marketing copy.',
  ),
  _FlagInfo(
    key: 'PRODUCT_CREDIT_REDEMPTION_ENABLED',
    label: 'Product Credit Redemption Enabled',
    subtitle: 'Allows Product Credit to be redeemed against AgriMore products.',
  ),
  _FlagInfo(
    key: 'BENEFIT_ACCUMULATION_ENABLED',
    label: 'Benefit Accumulation Enabled',
    subtitle: 'Allows unused Product Credit to accumulate across periods.',
  ),
  _FlagInfo(
    key: 'COMPOUNDING_ENABLED',
    label: 'Compounding Enabled',
    subtitle: 'Not implemented in this codebase yet — cannot be enabled by any admin action.',
    hardBlocked: true,
  ),
  _FlagInfo(
    key: 'CASH_REDEMPTION_ENABLED',
    label: 'Cash Redemption Enabled',
    subtitle: 'Not implemented in this codebase yet — cannot be enabled by any admin action.',
    hardBlocked: true,
  ),
  _FlagInfo(
    key: 'PRINCIPAL_INTAKE_ENABLED',
    label: 'Principal Intake Enabled',
    subtitle: 'Not implemented in this codebase yet — legally blocked pending regulatory review.',
    hardBlocked: true,
  ),
  _FlagInfo(
    key: 'PRINCIPAL_RETURN_ENABLED',
    label: 'Principal Return Enabled',
    subtitle: 'Not implemented in this codebase yet — legally blocked pending regulatory review.',
    hardBlocked: true,
  ),
];

/// Admin screen listing every Customer Product Benefit Program feature
/// flag. Flags are read-only here except through
/// [BenefitComplianceProvider.setFlag], which forwards to the
/// `setBenefitFeatureFlag` callable — this screen never writes Firestore
/// directly (feature_flags/benefit_program is write:false for every
/// client).
class FeatureFlagsScreen extends StatelessWidget {
  const FeatureFlagsScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text('Benefit Program — Feature Flags'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Consumer<BenefitComplianceProvider>(
        builder: (context, provider, _) {
          if (provider.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              if (!provider.isLaunchable) _buildNotLaunchableBanner(provider),
              const SizedBox(height: 16),
              ..._kFlags.map((info) => _buildFlagTile(context, provider, info)),
            ],
          );
        },
      ),
    );
  }

  Widget _buildNotLaunchableBanner(BenefitComplianceProvider provider) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.warning.withOpacity(0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.warning.withOpacity(0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: AppColors.warningDark),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'Program is not launchable',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ...provider.launchBlockedReasons.map(
            (reason) => Padding(
              padding: const EdgeInsets.only(left: 32, top: 2),
              child: Text('• $reason', style: const TextStyle(fontSize: 13)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFlagTile(
    BuildContext context,
    BenefitComplianceProvider provider,
    _FlagInfo info,
  ) {
    final currentValue = _flagValue(provider, info.key);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: info.hardBlocked ? AppColors.error.withOpacity(0.3) : Colors.grey.shade200,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      info.label,
                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                    ),
                    if (info.hardBlocked) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.error.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          'BLOCKED',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            color: AppColors.error,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  info.subtitle,
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          if (info.hardBlocked)
            const Icon(Icons.block, color: Colors.grey, size: 22)
          else
            Switch(
              value: currentValue,
              activeColor: AppColors.primary,
              onChanged: provider.isMutating
                  ? null
                  : (newValue) => _confirmAndSetFlag(context, provider, info, newValue),
            ),
        ],
      ),
    );
  }

  bool _flagValue(BenefitComplianceProvider provider, String key) {
    final flags = provider.flags;
    switch (key) {
      case 'BENEFIT_PROGRAM_ENABLED':
        return flags.benefitProgramEnabled;
      case 'NEW_ENROLLMENT_ENABLED':
        return flags.newEnrollmentEnabled;
      case 'MONTHLY_CREDIT_ENABLED':
        return flags.monthlyCreditEnabled;
      case 'PERCENTAGE_BENEFIT_ENABLED':
        return flags.percentageBenefitEnabled;
      case 'BENEFIT_EXAMPLES_ENABLED':
        return flags.benefitExamplesEnabled;
      case 'PRODUCT_CREDIT_REDEMPTION_ENABLED':
        return flags.productCreditRedemptionEnabled;
      case 'BENEFIT_ACCUMULATION_ENABLED':
        return flags.benefitAccumulationEnabled;
      case 'COMPOUNDING_ENABLED':
        return flags.compoundingEnabled;
      case 'CASH_REDEMPTION_ENABLED':
        return flags.cashRedemptionEnabled;
      case 'PRINCIPAL_INTAKE_ENABLED':
        return flags.principalIntakeEnabled;
      case 'PRINCIPAL_RETURN_ENABLED':
        return flags.principalReturnEnabled;
      default:
        return false;
    }
  }

  Future<void> _confirmAndSetFlag(
    BuildContext context,
    BenefitComplianceProvider provider,
    _FlagInfo info,
    bool newValue,
  ) async {
    final reasonController = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          final canConfirm = reasonController.text.trim().isNotEmpty;
          return AlertDialog(
            title: Text('${newValue ? 'Enable' : 'Disable'} ${info.label}'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('This action is recorded in the compliance audit log.'),
                const SizedBox(height: 12),
                TextField(
                  controller: reasonController,
                  autofocus: true,
                  decoration: const InputDecoration(
                    labelText: 'Reason (required)',
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (_) => setDialogState(() {}),
                  maxLines: 2,
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: canConfirm ? () => Navigator.pop(ctx, true) : null,
                style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
                child: const Text('Confirm'),
              ),
            ],
          );
        },
      ),
    );

    if (confirmed != true || !context.mounted) return;

    final success = await provider.setFlag(
      flag: info.key,
      value: newValue,
      reason: reasonController.text.trim(),
    );

    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(success ? '${info.label} updated' : (provider.error ?? 'Update failed')),
        backgroundColor: success ? AppColors.success : AppColors.error,
      ),
    );
    if (!success) provider.clearError();
  }
}
