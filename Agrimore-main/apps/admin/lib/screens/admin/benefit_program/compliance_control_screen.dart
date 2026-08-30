import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:agrimore_core/agrimore_core.dart';
import 'package:agrimore_ui/agrimore_ui.dart';

import '../../../providers/benefit_compliance_provider.dart';

class _StatusFieldInfo {
  final String key;
  final String label;

  const _StatusFieldInfo(this.key, this.label);
}

const List<_StatusFieldInfo> _kStatusFields = [
  _StatusFieldInfo('legalReviewStatus', 'Legal Review Status'),
  _StatusFieldInfo('complianceApprovalStatus', 'Compliance Approval Status'),
  _StatusFieldInfo('budsActReviewStatus', 'Banning of Unregulated Deposit Schemes Act Review'),
  _StatusFieldInfo('rbiReviewStatus', 'RBI Review Status'),
];

class _TextFieldInfo {
  final String key;
  final String label;

  const _TextFieldInfo(this.key, this.label);
}

const List<_TextFieldInfo> _kTextFields = [
  _TextFieldInfo('reviewer', 'Reviewer'),
  _TextFieldInfo('jurisdiction', 'Jurisdiction'),
  _TextFieldInfo('approvedMarketingCopyVersion', 'Approved Marketing Copy Version'),
  _TextFieldInfo('approvedBenefitStructure', 'Approved Benefit Structure'),
  _TextFieldInfo('approvedProductTerms', 'Approved Product Terms'),
  _TextFieldInfo('legalOpinionDocumentRef', 'Legal Opinion Document Reference'),
  _TextFieldInfo('internalNotes', 'Internal Notes'),
];

/// Admin screen for the Customer Product Benefit Program's compliance
/// record (compliance_config/benefit_program). Every field here is
/// read-only in Firestore for this app — all writes go through the
/// `setComplianceStatus` callable via [BenefitComplianceProvider], which
/// requires a non-empty reason and audit-logs every change.
class ComplianceControlScreen extends StatelessWidget {
  const ComplianceControlScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text('Benefit Program — Compliance Control'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Consumer<BenefitComplianceProvider>(
        builder: (context, provider, _) {
          if (provider.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }
          final compliance = provider.compliance;
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _buildLaunchabilityBanner(provider),
              const SizedBox(height: 16),
              _buildSectionCard(
                title: 'Review Statuses',
                icon: Icons.gavel_rounded,
                children: _kStatusFields
                    .map((f) => _buildStatusRow(context, provider, f))
                    .toList(),
              ),
              const SizedBox(height: 16),
              _buildSectionCard(
                title: 'Approved Documentation',
                icon: Icons.description_rounded,
                children: _kTextFields
                    .map((f) => _buildTextRow(context, provider, f))
                    .toList(),
              ),
              const SizedBox(height: 16),
              _buildSectionCard(
                title: 'Approval Date',
                icon: Icons.event_available_rounded,
                children: [_buildApprovalDateRow(context, provider)],
              ),
              const SizedBox(height: 16),
              Text(
                'Last updated: ${compliance.updatedAt.year == 1970 ? 'never' : compliance.updatedAt.toString()} '
                '${compliance.updatedBy != null ? 'by ${compliance.updatedBy}' : ''}',
                style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
              ),
              const SizedBox(height: 24),
              _buildAuditTrail(provider),
            ],
          );
        },
      ),
    );
  }

  Widget _buildLaunchabilityBanner(BenefitComplianceProvider provider) {
    final launchable = provider.isLaunchable;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: launchable
            ? AppColors.success.withOpacity(0.12)
            : AppColors.warning.withOpacity(0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: launchable
              ? AppColors.success.withOpacity(0.4)
              : AppColors.warning.withOpacity(0.4),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            launchable ? Icons.check_circle_rounded : Icons.warning_amber_rounded,
            color: launchable ? AppColors.success : AppColors.warningDark,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  launchable ? 'Program is launchable' : 'Program is not launchable',
                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                ),
                if (!launchable)
                  ...provider.launchBlockedReasons.map(
                    (r) => Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text('• $r', style: const TextStyle(fontSize: 13)),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionCard({
    required String title,
    required IconData icon,
    required List<Widget> children,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
            child: Row(
              children: [
                Icon(icon, size: 20, color: AppColors.primary),
                const SizedBox(width: 10),
                Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
              ],
            ),
          ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(children: children),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusRow(
    BuildContext context,
    BenefitComplianceProvider provider,
    _StatusFieldInfo info,
  ) {
    final currentValue = _statusValue(provider.compliance, info.key);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: Text(info.label, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
          ),
          Expanded(
            flex: 2,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: _statusColor(currentValue).withOpacity(0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                currentValue,
                style: TextStyle(color: _statusColor(currentValue), fontWeight: FontWeight.w700, fontSize: 12),
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.edit, size: 18),
            onPressed: provider.isMutating
                ? null
                : () => _showStatusEditDialog(context, provider, info, currentValue),
          ),
        ],
      ),
    );
  }

  Widget _buildTextRow(
    BuildContext context,
    BenefitComplianceProvider provider,
    _TextFieldInfo info,
  ) {
    final currentValue = _textValue(provider.compliance, info.key);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: Text(info.label, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
          ),
          Expanded(
            flex: 2,
            child: Text(
              currentValue?.isNotEmpty == true ? currentValue! : '—',
              style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          IconButton(
            icon: const Icon(Icons.edit, size: 18),
            onPressed: provider.isMutating
                ? null
                : () => _showTextEditDialog(context, provider, info, currentValue),
          ),
        ],
      ),
    );
  }

  Widget _buildApprovalDateRow(BuildContext context, BenefitComplianceProvider provider) {
    final date = provider.compliance.approvalDate;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: const Text('Approval Date', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
          ),
          Expanded(
            flex: 2,
            child: Text(
              date != null ? '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}' : '—',
              style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.edit, size: 18),
            onPressed: provider.isMutating
                ? null
                : () => _showDateEditDialog(context, provider, date),
          ),
        ],
      ),
    );
  }

  Widget _buildAuditTrail(BenefitComplianceProvider provider) {
    final entries = provider.auditLog;
    return _buildSectionCard(
      title: 'Compliance Audit Trail',
      icon: Icons.history_rounded,
      children: entries.isEmpty
          ? [
              Padding(
                padding: const EdgeInsets.all(8),
                child: Text('No changes recorded yet', style: TextStyle(color: Colors.grey.shade600)),
              )
            ]
          : entries.map((e) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${e.action} → ${e.target}',
                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                    ),
                    Text(
                      '${e.previousValue} → ${e.newValue}',
                      style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                    ),
                    Text(
                      '${e.actorEmail ?? e.actorUid} · ${e.reason ?? ''} · ${e.createdAt ?? ''}',
                      style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                    ),
                    const Divider(),
                  ],
                ),
              );
            }).toList(),
    );
  }

  String _statusValue(BenefitComplianceModel compliance, String key) {
    switch (key) {
      case 'legalReviewStatus':
        return compliance.legalReviewStatus;
      case 'complianceApprovalStatus':
        return compliance.complianceApprovalStatus;
      case 'budsActReviewStatus':
        return compliance.budsActReviewStatus;
      case 'rbiReviewStatus':
        return compliance.rbiReviewStatus;
      default:
        return BenefitReviewStatus.notStarted;
    }
  }

  String? _textValue(BenefitComplianceModel compliance, String key) {
    switch (key) {
      case 'reviewer':
        return compliance.reviewer;
      case 'jurisdiction':
        return compliance.jurisdiction;
      case 'approvedMarketingCopyVersion':
        return compliance.approvedMarketingCopyVersion;
      case 'approvedBenefitStructure':
        return compliance.approvedBenefitStructure;
      case 'approvedProductTerms':
        return compliance.approvedProductTerms;
      case 'legalOpinionDocumentRef':
        return compliance.legalOpinionDocumentRef;
      case 'internalNotes':
        return compliance.internalNotes;
      default:
        return null;
    }
  }

  Color _statusColor(String status) {
    switch (status) {
      case BenefitReviewStatus.approved:
        return AppColors.success;
      case BenefitReviewStatus.rejected:
        return AppColors.error;
      case BenefitReviewStatus.inReview:
        return AppColors.warningDark;
      default:
        return Colors.grey.shade600;
    }
  }

  Future<void> _showStatusEditDialog(
    BuildContext context,
    BenefitComplianceProvider provider,
    _StatusFieldInfo info,
    String currentValue,
  ) async {
    String selected = currentValue;
    final reasonController = TextEditingController();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          final canConfirm = reasonController.text.trim().isNotEmpty;
          return AlertDialog(
            title: Text('Update ${info.label}'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                DropdownButtonFormField<String>(
                  initialValue: selected,
                  items: BenefitReviewStatus.values
                      .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                      .toList(),
                  onChanged: (v) => setDialogState(() => selected = v ?? selected),
                  decoration: const InputDecoration(labelText: 'Status', border: OutlineInputBorder()),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: reasonController,
                  decoration: const InputDecoration(labelText: 'Reason (required)', border: OutlineInputBorder()),
                  onChanged: (_) => setDialogState(() {}),
                  maxLines: 2,
                ),
              ],
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
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
    final success = await provider.setComplianceField(
      field: info.key,
      value: selected,
      reason: reasonController.text.trim(),
    );
    _showResultSnackBar(context, provider, success, info.label);
  }

  Future<void> _showTextEditDialog(
    BuildContext context,
    BenefitComplianceProvider provider,
    _TextFieldInfo info,
    String? currentValue,
  ) async {
    final valueController = TextEditingController(text: currentValue ?? '');
    final reasonController = TextEditingController();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          final canConfirm = reasonController.text.trim().isNotEmpty;
          return AlertDialog(
            title: Text('Update ${info.label}'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: valueController,
                  decoration: InputDecoration(labelText: info.label, border: const OutlineInputBorder()),
                  maxLines: info.key == 'internalNotes' ? 4 : 1,
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: reasonController,
                  decoration: const InputDecoration(labelText: 'Reason (required)', border: OutlineInputBorder()),
                  onChanged: (_) => setDialogState(() {}),
                  maxLines: 2,
                ),
              ],
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
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
    final success = await provider.setComplianceField(
      field: info.key,
      value: valueController.text.trim().isEmpty ? null : valueController.text.trim(),
      reason: reasonController.text.trim(),
    );
    _showResultSnackBar(context, provider, success, info.label);
  }

  Future<void> _showDateEditDialog(
    BuildContext context,
    BenefitComplianceProvider provider,
    DateTime? currentDate,
  ) async {
    DateTime? selectedDate = currentDate;
    final reasonController = TextEditingController();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          final canConfirm = reasonController.text.trim().isNotEmpty;
          return AlertDialog(
            title: const Text('Update Approval Date'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        selectedDate != null
                            ? '${selectedDate!.year}-${selectedDate!.month.toString().padLeft(2, '0')}-${selectedDate!.day.toString().padLeft(2, '0')}'
                            : 'No date set',
                      ),
                    ),
                    TextButton(
                      onPressed: () async {
                        final picked = await showDatePicker(
                          context: ctx,
                          initialDate: selectedDate ?? DateTime.now(),
                          firstDate: DateTime(2020),
                          lastDate: DateTime(2100),
                        );
                        if (picked != null) setDialogState(() => selectedDate = picked);
                      },
                      child: const Text('Pick date'),
                    ),
                    if (selectedDate != null)
                      TextButton(
                        onPressed: () => setDialogState(() => selectedDate = null),
                        child: const Text('Clear'),
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: reasonController,
                  decoration: const InputDecoration(labelText: 'Reason (required)', border: OutlineInputBorder()),
                  onChanged: (_) => setDialogState(() {}),
                  maxLines: 2,
                ),
              ],
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
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
    final success = await provider.setComplianceField(
      field: 'approvalDate',
      value: selectedDate,
      reason: reasonController.text.trim(),
    );
    _showResultSnackBar(context, provider, success, 'Approval Date');
  }

  void _showResultSnackBar(
    BuildContext context,
    BenefitComplianceProvider provider,
    bool success,
    String label,
  ) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(success ? '$label updated' : (provider.error ?? 'Update failed')),
        backgroundColor: success ? AppColors.success : AppColors.error,
      ),
    );
    if (!success) provider.clearError();
  }
}
