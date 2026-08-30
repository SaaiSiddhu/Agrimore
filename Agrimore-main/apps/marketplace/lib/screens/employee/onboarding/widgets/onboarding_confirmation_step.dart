import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:agrimore_ui/agrimore_ui.dart';

/// Phase 16B-2, Workstream 4 — shown once `employees/{uid}` has
/// `hasClearedOnboardingGate == true` (checked by the caller,
/// `_EmployeeStateGate` in associate_onboarding_screen.dart).
///
/// D6 is the whole point of this screen: paying the fee is NOT admin
/// approval. `status` (pending/approved/suspended) is shown as its own,
/// separate fact — never folded into "you're all set, start selling".
///
/// Wording standard for the code card (4c) is read from
/// apps/employee/lib/screens/home/dashboard_screen.dart's
/// `_AssociateCodeCard` (Phase 16B) — same "share the code, commission
/// applies to eligible completed orders" framing, same refusal to state a
/// figure (S7).
///
/// 4d (show the support contact) is satisfied by the caller: the parent
/// screen's `OnboardingSupportContactSection` renders unconditionally below
/// every step, including this one — so it is not duplicated here.
class OnboardingConfirmationStep extends StatelessWidget {
  final String employeeCode;
  final String status;

  const OnboardingConfirmationStep({
    super.key,
    required this.employeeCode,
    required this.status,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [AppColors.primary, AppColors.primaryDark],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(Icons.check_circle_rounded, color: Colors.white, size: 22),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Onboarding fee received',
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 17),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              const Text(
                'Your one-time ₹500 Registration & Onboarding Fee has been received and your '
                'account is activated.',
                style: TextStyle(color: Colors.white, fontSize: 13, height: 1.5),
              ),
              const SizedBox(height: 14),
              _buildStatusBadge(),
            ],
          ),
        ),
        const SizedBox(height: 14),
        if (employeeCode.isNotEmpty) _buildCodeCard(),
        const SizedBox(height: 14),
        _buildApprovalNote(),
      ],
    );
  }

  Widget _buildStatusBadge() {
    final (label, bg, fg) = switch (status) {
      'approved' => ('Approved', Colors.white, AppColors.primaryDark),
      'suspended' => ('Suspended', const Color(0xFFFCA5A5), const Color(0xFF7F1D1D)),
      _ => ('Pending admin approval', const Color(0xFFFDE68A), const Color(0xFF92400E)),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(100)),
      child: Text(label, style: TextStyle(color: fg, fontWeight: FontWeight.w800, fontSize: 12)),
    );
  }

  /// D6 — plain, unambiguous: paying is not approval, selling does not
  /// start immediately. This is the load-bearing sentence of this whole
  /// screen.
  Widget _buildApprovalNote() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFBEB),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFFDE68A)),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline_rounded, color: Color(0xFFB45309), size: 18),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              'Paying the onboarding fee does not approve your account. An AgriMore '
              'admin still needs to review and approve your registration, and complete '
              'your training, before you can start receiving customer orders.',
              style: TextStyle(color: Color(0xFF92400E), fontSize: 12.5, height: 1.5),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCodeCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Your Associate Code', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13)),
          const SizedBox(height: 10),
          Builder(builder: (context) {
            return InkWell(
              borderRadius: BorderRadius.circular(10),
              onTap: () async {
                await Clipboard.setData(ClipboardData(text: employeeCode));
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Associate code copied'), duration: Duration(seconds: 2)),
                );
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF0FDF4),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFBBF7D0)),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        employeeCode,
                        style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 20, letterSpacing: 2, color: AppColors.primaryDark),
                      ),
                    ),
                    const Icon(Icons.copy_rounded, size: 18, color: AppColors.primary),
                  ],
                ),
              ),
            );
          }),
          const SizedBox(height: 10),
          // Wording standard matches apps/employee's _AssociateCodeCard
          // (Phase 16B) — mechanism only, no figure, no guarantee (S7).
          const Text(
            'Share this code with your customers. When someone enters it at checkout, '
            'that order is recorded against you. Commission applies to eligible orders '
            'once they are completed, in line with AgriMore\'s current commission policy.',
            style: TextStyle(fontSize: 12, color: Color(0xFF6B7280), height: 1.5),
          ),
        ],
      ),
    );
  }
}
