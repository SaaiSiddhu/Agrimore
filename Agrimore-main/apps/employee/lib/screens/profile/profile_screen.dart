import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:agrimore_ui/agrimore_ui.dart';
import '../../providers/auth_provider.dart';

/// Phase 16C, Workstream 2 — the associate's own account/profile screen.
///
/// Until this phase this app had no profile screen at all: an associate
/// could not see their own registered name/phone/email, could not find a
/// support contact, and could only sign out via an unlabelled app-bar icon.
///
/// Sourced entirely from employees/{uid} — that single document already
/// carries name, email, phone, employeeCode AND status (see EmployeeModel),
/// so this screen needs exactly one read, no second document, and writes
/// nothing anywhere.
class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(title: const Text('My Profile')),
      body: uid == null
          ? const Center(child: CircularProgressIndicator())
          : StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
              stream: FirebaseFirestore.instance
                  .collection('employees')
                  .doc(uid)
                  .snapshots(),
              builder: (context, snap) {
                if (snap.hasError) {
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.all(24),
                      child: Text('Could not load your profile right now.'),
                    ),
                  );
                }
                if (!snap.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                final doc = snap.data!;
                if (!doc.exists || doc.data() == null) {
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.all(24),
                      child: Text(
                        'We could not find your associate profile. Please '
                        'sign out and sign in again, or contact support.',
                      ),
                    ),
                  );
                }

                final employee = EmployeeModel.fromMap(doc.data()!, doc.id);

                return ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    _ProfileHeader(name: employee.name),
                    const SizedBox(height: 20),
                    _InfoCard(
                      title: 'Account Details',
                      rows: [
                        _InfoRow(
                            icon: Icons.phone_outlined,
                            label: 'Phone',
                            value: employee.phone.isNotEmpty
                                ? employee.phone
                                : 'Not on file'),
                        _InfoRow(
                            icon: Icons.email_outlined,
                            label: 'Email',
                            value: employee.email.isNotEmpty
                                ? employee.email
                                : 'Not on file'),
                        _InfoRow(
                            icon: Icons.badge_outlined,
                            label: 'Associate Code',
                            value: employee.employeeCode.isNotEmpty
                                ? employee.employeeCode
                                : 'Not yet assigned'),
                        _InfoRow(
                          icon: Icons.verified_user_outlined,
                          label: 'Approval Status',
                          value: _statusLabel(employee.status),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    _SupportCard(),
                    const SizedBox(height: 24),
                    _SignOutButton(),
                  ],
                );
              },
            ),
    );
  }

  // Plain status vocabulary, kept separate from any onboarding-fee wording
  // (locked decision 4 — clearing the fee gate is not approval).
  String _statusLabel(String status) {
    switch (status) {
      case 'approved':
        return 'Approved';
      case 'suspended':
        return 'Suspended';
      case 'pending':
        return 'Pending Approval';
      default:
        return status;
    }
  }
}

class _ProfileHeader extends StatelessWidget {
  final String name;

  const _ProfileHeader({required this.name});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 72,
          height: 72,
          decoration: const BoxDecoration(
            color: AppColors.primary,
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.person_rounded, color: Colors.white, size: 36),
        ),
        const SizedBox(height: 12),
        Text(
          name.isNotEmpty ? name : 'Sales Associate',
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
        ),
      ],
    );
  }
}

class _InfoCard extends StatelessWidget {
  final String title;
  final List<_InfoRow> rows;

  const _InfoCard({required this.title, required this.rows});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 12),
          for (var i = 0; i < rows.length; i++) ...[
            rows[i],
            if (i != rows.length - 1) const Divider(height: 20),
          ],
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _InfoRow({required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: Colors.grey.shade600),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
              ),
              const SizedBox(height: 2),
              // SelectableText — an associate reading their own phone/email
              // off the screen to relay it (e.g. to support) is exactly the
              // kind of thing that shouldn't require retyping.
              SelectableText(
                value,
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Plain, selectable contact details only — no url_launcher, no mailto:/
/// tel: link, no dependency added (locked decision 2 keeps this app's
/// outbound surface deliberately narrow). AppConstants.supportEmail/
/// supportPhone are the same values already shown elsewhere in this
/// product (e.g. apps/marketplace's help screen) — not invented here.
class _SupportCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Need Help?',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 4),
          Text(
            'Contact support with any questions about your account, your '
            'onboarding fee, or your commission.',
            style: TextStyle(fontSize: 12, color: Colors.grey.shade600, height: 1.4),
          ),
          const SizedBox(height: 12),
          _InfoRow(
            icon: Icons.email_outlined,
            label: 'Support Email',
            value: AppConstants.supportEmail,
          ),
          const Divider(height: 20),
          _InfoRow(
            icon: Icons.phone_outlined,
            label: 'Support Phone',
            value: AppConstants.supportPhone,
          ),
        ],
      ),
    );
  }
}

class _SignOutButton extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        style: OutlinedButton.styleFrom(
          foregroundColor: Colors.red.shade700,
          side: BorderSide(color: Colors.red.shade200),
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
        icon: const Icon(Icons.logout_rounded),
        label: const Text('Sign Out', style: TextStyle(fontWeight: FontWeight.w700)),
        onPressed: () async {
          final confirmed = await DialogHelper.showConfirmation(
            context,
            title: 'Sign Out',
            message: 'Are you sure you want to sign out of your associate account?',
            confirmText: 'Sign Out',
            isDangerous: true,
          );
          if (confirmed == true && context.mounted) {
            final navigator = Navigator.of(context);
            await context.read<EmployeeAuthProvider>().signOut();
            // ProfileScreen is a PUSHED route on top of the dashboard.
            // Signing out swaps what _AuthGate renders at the base of the
            // stack (LoginScreen instead of DashboardScreen), but does not
            // by itself pop THIS pushed route — without this, the associate
            // is left stranded on a broken, now-erroring Profile screen
            // instead of landing back on the login screen. popUntil(first)
            // rather than a single pop() so this is correct even if more
            // than one route is ever pushed on top of the dashboard later.
            if (navigator.mounted) {
              navigator.popUntil((route) => route.isFirst);
            }
          }
        },
      ),
    );
  }
}
