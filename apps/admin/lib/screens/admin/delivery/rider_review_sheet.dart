// lib/screens/admin/delivery/rider_review_sheet.dart
//
// Phase DLV-1B — the review sheet an admin opens from a delivery partner's
// card: KYC photos, masked identity and bank details, vehicle, current status
// and reason, and the actions that status allows (rider_review.dart).
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:agrimore_ui/agrimore_ui.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../app/themes/admin_colors.dart';
import 'rider_review.dart';

/// Colour and label for an onboarding status, shared by the card and sheet.
({Color color, String label}) riderStatusStyle(RiderKycStatus s,
    {bool missing = false}) {
  if (missing) {
    return (color: AdminColors.warning, label: 'Pending · status missing');
  }
  return switch (s) {
    RiderKycStatus.pending => (
        color: AdminColors.warning,
        label: 'Pending review'
      ),
    RiderKycStatus.approved => (color: AdminColors.success, label: 'Approved'),
    RiderKycStatus.rejected => (color: AdminColors.error, label: 'Rejected'),
    RiderKycStatus.suspended => (color: AdminColors.error, label: 'Suspended'),
    RiderKycStatus.deactivated => (
        color: AdminColors.textSecondary,
        label: 'Deactivated'
      ),
  };
}

class RiderStatusBadge extends StatelessWidget {
  const RiderStatusBadge(
      {super.key, required this.status, this.missing = false});
  final RiderKycStatus status;
  final bool missing;

  @override
  Widget build(BuildContext context) {
    final style = riderStatusStyle(status, missing: missing);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: style.color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        style.label,
        style: TextStyle(
            fontSize: 11, fontWeight: FontWeight.w700, color: style.color),
      ),
    );
  }
}

class RiderReviewSheet extends StatefulWidget {
  const RiderReviewSheet({super.key, required this.uid, required this.data});

  final String uid;

  /// The raw delivery_partners document. Read raw on purpose:
  /// DeliveryPartnerModel.fromMap defaults a missing `status` to 'approved',
  /// which is exactly the admin-created-rider bug this phase fixes.
  final Map<String, dynamic> data;

  @override
  State<RiderReviewSheet> createState() => _RiderReviewSheetState();
}

class _RiderReviewSheetState extends State<RiderReviewSheet> {
  bool _busy = false;

  Map<String, dynamic> get d => widget.data;
  String _s(String key) => (d[key] as String?)?.trim() ?? '';

  Future<void> _run(RiderReviewAction action) async {
    String? reason;
    if (action.needsReason) {
      reason = await DialogHelper.showInput(
        context,
        title: action == RiderReviewAction.reject
            ? 'Why is this application rejected?'
            : 'Why is this partner suspended?',
        hint: 'The delivery partner will see this',
        confirmText: action.label,
        maxLength: 200,
        validator: (v) => (v == null || v.trim().length < 5)
            ? 'Give a reason of at least 5 characters'
            : null,
      );
      if (reason == null || !mounted) return;
    } else {
      final ok = await DialogHelper.showConfirmation(
        context,
        title:
            '${action.label} ${_s('name').isEmpty ? 'this partner' : _s('name')}?',
        message: action == RiderReviewAction.approve
            ? 'They will be able to go online and accept delivery orders.'
            : 'They will be able to go online again.',
        confirmText: action.label,
      );
      if (ok != true || !mounted) return;
    }

    final adminUid = FirebaseAuth.instance.currentUser?.uid;
    if (adminUid == null) {
      SnackbarHelper.showError(
          context, 'Your admin session has expired. Sign in again.');
      return;
    }

    setState(() => _busy = true);
    try {
      await applyRiderReview(
        firestore: FirebaseFirestore.instance,
        uid: widget.uid,
        action: action,
        adminUid: adminUid,
        reason: reason,
      );
      if (!mounted) return;
      Navigator.of(context).pop();
      SnackbarHelper.showSuccess(context, action.successMessage);
    } catch (e) {
      debugPrint('Rider review ${action.name} failed for ${widget.uid}: $e');
      if (!mounted) return;
      setState(() => _busy = false);
      SnackbarHelper.showError(
          context, 'Could not update this partner. Please try again.');
    }
  }

  Future<void> _openImage(String url) async {
    try {
      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    } catch (e) {
      debugPrint('Could not open KYC image: $e');
      if (mounted) {
        SnackbarHelper.showError(context, 'Could not open this document.');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final rawStatus = d['status'] as String?;
    final status = RiderKycStatus.fromWire(rawStatus);
    final missing = rawStatus == null || rawStatus.trim().isEmpty;
    final actions = availableRiderActions(status);
    final reason = status == RiderKycStatus.rejected
        ? _s('rejectionReason')
        : status == RiderKycStatus.suspended
            ? _s('suspensionReason')
            : '';
    final vehicle = VehicleType.fromWire(d['vehicleType'] as String?);

    final docs = <(String, String)>[
      ('Aadhaar front', _s('aadhaarFrontImage')),
      ('Aadhaar back', _s('aadhaarBackImage')),
      ('Selfie', _s('selfieImage')),
      ('Licence', _s('licenseImage')),
    ];

    return SafeArea(
      child: ConstrainedBox(
        constraints:
            BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.9),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AdminColors.border,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      _s('name').isEmpty ? 'Unnamed partner' : _s('name'),
                      style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          color: AdminColors.textPrimary),
                    ),
                  ),
                  RiderStatusBadge(status: status, missing: missing),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                [_s('phone'), _s('email')]
                    .where((v) => v.isNotEmpty)
                    .join(' · '),
                style: const TextStyle(color: AdminColors.textSecondary),
              ),
              if (missing) ...[
                const SizedBox(height: 12),
                _note(
                  'This account has no onboarding status (created before it was recorded), '
                  'so the delivery app treats it as pending. Approve it to let the partner work.',
                  AdminColors.warning,
                ),
              ],
              if (reason.isNotEmpty) ...[
                const SizedBox(height: 12),
                _note('Reason given: $reason', AdminColors.error),
              ],
              const SizedBox(height: 20),
              _section('Identity documents'),
              const SizedBox(height: 8),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  for (final (label, url) in docs) _docTile(label, url)
                ],
              ),
              const SizedBox(height: 20),
              _section('Details'),
              _row('Aadhaar', maskTail(_s('aadhaarNumber'))),
              _row(
                  'Licence no.',
                  _s('licenseNumber').isEmpty
                      ? 'Not provided'
                      : _s('licenseNumber')),
              _row(
                  'Vehicle',
                  vehicleLabel(vehicle) +
                      (_s('vehicleNumber').isEmpty
                          ? ''
                          : ' · ${_s('vehicleNumber')}')),
              _row(
                  'Area',
                  [_s('city'), _s('pincode')]
                      .where((v) => v.isNotEmpty)
                      .join(' · ')
                      .ifEmpty('Not provided')),
              _row('Bank account', maskTail(_s('bankAccountNumber'))),
              _row('IFSC',
                  _s('ifscCode').isEmpty ? 'Not provided' : _s('ifscCode')),
              _row('UPI', _s('upiId').isEmpty ? 'Not provided' : 'Provided'),
              const SizedBox(height: 24),
              if (actions.isEmpty)
                const Text('No review actions are available for this status.',
                    style: TextStyle(color: AdminColors.textSecondary))
              else
                Row(
                  children: [
                    for (final a in actions) ...[
                      Expanded(child: _actionButton(a)),
                      if (a != actions.last) const SizedBox(width: 12),
                    ],
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _actionButton(RiderReviewAction a) {
    final destructive =
        a == RiderReviewAction.reject || a == RiderReviewAction.suspend;
    final child = _busy
        ? const SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(strokeWidth: 2))
        : Text(a.label, style: const TextStyle(fontWeight: FontWeight.w700));
    return destructive
        ? OutlinedButton(
            onPressed: _busy ? null : () => _run(a),
            style: OutlinedButton.styleFrom(
              foregroundColor: AdminColors.error,
              side: const BorderSide(color: AdminColors.error),
              minimumSize: const Size.fromHeight(48),
            ),
            child: child,
          )
        : FilledButton(
            onPressed: _busy ? null : () => _run(a),
            style: FilledButton.styleFrom(
              backgroundColor: AdminColors.success,
              minimumSize: const Size.fromHeight(48),
            ),
            child: child,
          );
  }

  Widget _docTile(String label, String url) {
    return InkWell(
      onTap: url.isEmpty ? null : () => _openImage(url),
      borderRadius: BorderRadius.circular(10),
      child: SizedBox(
        width: 120,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: Container(
                width: 120,
                height: 84,
                color: AdminColors.surfaceContainer,
                child: url.isEmpty
                    ? const Center(
                        child: Icon(Icons.image_not_supported_outlined,
                            color: AdminColors.textTertiary))
                    : Image.network(
                        url,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => const Center(
                            child: Icon(Icons.broken_image_outlined,
                                color: AdminColors.textTertiary)),
                      ),
              ),
            ),
            const SizedBox(height: 4),
            Text(url.isEmpty ? '$label · missing' : label,
                style: const TextStyle(
                    fontSize: 12, color: AdminColors.textSecondary)),
          ],
        ),
      ),
    );
  }

  Widget _section(String title) => Text(title,
      style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w800,
          color: AdminColors.textPrimary));

  Widget _row(String label, String value) => Padding(
        padding: const EdgeInsets.only(top: 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 110,
              child: Text(label,
                  style: const TextStyle(color: AdminColors.textSecondary)),
            ),
            Expanded(
              child: Text(value,
                  style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      color: AdminColors.textPrimary)),
            ),
          ],
        ),
      );

  Widget _note(String text, Color color) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Text(text,
            style: TextStyle(
                color: color, fontWeight: FontWeight.w600, height: 1.4)),
      );
}

extension on String {
  String ifEmpty(String fallback) => isEmpty ? fallback : this;
}
