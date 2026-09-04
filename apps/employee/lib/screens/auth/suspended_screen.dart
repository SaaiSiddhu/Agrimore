import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:agrimore_core/agrimore_core.dart';
import '../../providers/auth_provider.dart';

/// Phase 16C, Workstream 5 — the honest state for a suspended associate.
///
/// Until this phase, a suspended associate saw the EXACT SAME "pending
/// approval... under review" message as a brand-new applicant (see
/// EmployeeAuthProvider._loadUserData) — false for anyone who had
/// previously been approved and working. This screen states plainly that
/// the account is suspended and points to support, without inventing a
/// reason or an appeals process that doesn't exist server-side (nothing in
/// functions/src/employee knows WHY an admin suspended an account, so this
/// screen doesn't guess).
class SuspendedScreen extends StatelessWidget {
  const SuspendedScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.pause_circle_outline_rounded,
                    size: 56,
                    color: Colors.red.shade700,
                  ),
                ),
                const SizedBox(height: 32),
                Text(
                  'Account Suspended',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                    color: colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Your Sales Associate account has been suspended by an '
                  'administrator.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 16,
                    color: colorScheme.onSurfaceVariant,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Contact support at ${AppConstants.supportEmail} or '
                  '${AppConstants.supportPhone} if you have questions.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    color: colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
                  ),
                ),
                const SizedBox(height: 48),
                FilledButton.icon(
                  onPressed: () {
                    context.read<EmployeeAuthProvider>().signOut();
                  },
                  icon: const Icon(Icons.logout_rounded),
                  label: const Text('Sign Out'),
                  style: FilledButton.styleFrom(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                    backgroundColor: colorScheme.error,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
