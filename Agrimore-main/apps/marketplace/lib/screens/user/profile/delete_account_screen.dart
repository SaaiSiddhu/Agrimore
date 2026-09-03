// lib/screens/user/profile/delete_account_screen.dart
//
// Phase 17, Workstream 2 — the account-deletion entry point Google Play
// requires and this app never had. Reachable from ProfileScreen's "Other
// information" section, visually subordinate to (and below) "Log out".
//
// Full disclosure BEFORE the destructive action, not a bare "Are you
// sure?": what gets permanently deleted, what gets kept (with personal
// details stripped) and why, and that none of it can be undone. The
// confirm button stays disabled until the user has explicitly
// acknowledged that — see _acknowledged below.

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../app/routes.dart';
import '../../../providers/auth_provider.dart' as app_auth;

class DeleteAccountScreen extends StatefulWidget {
  const DeleteAccountScreen({super.key});

  @override
  State<DeleteAccountScreen> createState() => _DeleteAccountScreenState();
}

enum _DeletionState { idle, submitting, refused, failed }

class _DeleteAccountScreenState extends State<DeleteAccountScreen> {
  bool _acknowledged = false;
  _DeletionState _state = _DeletionState.idle;
  String? _errorMessage;

  static const _deletedItems = [
    'Your profile — name, phone, email, date of birth',
    'Your saved addresses',
    'Your cart and wishlist',
    'Your notifications and recently viewed items',
    'Your Sales Associate profile, if you have one',
  ];

  static const _keptItems = [
    'Past orders — kept for sellers\' financial and tax records, with your '
        'name, phone, and delivery address removed from them',
    'Wallet and commission transaction history — kept intact so any seller '
        'or associate accounting that depends on it stays correct',
  ];

  // authProvider.deleteAccount() catches everything internally (see
  // AuthProvider.deleteAccount()) and always returns a bool rather than
  // throwing — so this method has exactly one success path and one
  // failure path, both read off the provider afterward, never a caught
  // exception here.
  Future<void> _submit() async {
    setState(() {
      _state = _DeletionState.submitting;
      _errorMessage = null;
    });

    final navigator = Navigator.of(context);
    final authProvider = context.read<app_auth.AuthProvider>();
    final ok = await authProvider.deleteAccount();
    if (!mounted) return;

    if (ok) {
      // Clean, full-stack replacement with the signed-out route — never
      // leaves this pushed screen (or anything below it) reachable via
      // back, the same "don't strand the user on a dead route after
      // sign-out" lesson apps/employee's ProfileScreen already proved,
      // taken one step further since there is no session left to return
      // to at all.
      navigator.pushNamedAndRemoveUntil(AppRoutes.login, (route) => false);
      return;
    }

    // authProvider.errorCode carries the original
    // FirebaseFunctionsException.code through AuthException — a
    // 'failed-precondition' is one of deleteUserData's three refusal
    // cases (each with its own specific, actionable message already
    // written server-side); anything else (network failure, a genuine
    // server error) is a plain failure with a generic retry banner.
    final message = authProvider.error;
    final isRefusal = authProvider.errorCode == 'failed-precondition';
    setState(() {
      _state = isRefusal ? _DeletionState.refused : _DeletionState.failed;
      _errorMessage = (message == null || message.isEmpty)
          ? 'Something went wrong. Please try again.'
          : message;
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final submitting = _state == _DeletionState.submitting;

    return Scaffold(
      appBar: AppBar(title: const Text('Delete Account')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Icon(Icons.warning_amber_rounded, size: 48, color: Colors.red.shade600),
            const SizedBox(height: 16),
            const Text(
              'This will permanently delete your account',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 20),

            _DisclosureSection(
              title: 'Deleted permanently',
              icon: Icons.delete_forever_rounded,
              color: Colors.red.shade600,
              items: _deletedItems,
              isDark: isDark,
            ),
            const SizedBox(height: 16),
            _DisclosureSection(
              title: 'Kept, with your personal details removed',
              icon: Icons.shield_outlined,
              color: Colors.blueGrey,
              items: _keptItems,
              isDark: isDark,
            ),
            const SizedBox(height: 16),

            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.red.shade200),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.info_outline_rounded, size: 18, color: Colors.red.shade700),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'This cannot be undone. Once deleted, your account and '
                      'profile cannot be recovered.',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: Colors.red.shade700,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            if (_state == _DeletionState.refused) ...[
              const SizedBox(height: 16),
              _MessageBanner(
                icon: Icons.pause_circle_outline_rounded,
                color: Colors.amber.shade800,
                background: Colors.amber.shade50,
                message: _errorMessage ?? '',
              ),
            ],
            if (_state == _DeletionState.failed) ...[
              const SizedBox(height: 16),
              _MessageBanner(
                icon: Icons.error_outline_rounded,
                color: Colors.red.shade700,
                background: Colors.red.shade50,
                message: _errorMessage ?? '',
              ),
            ],

            const SizedBox(height: 20),
            CheckboxListTile(
              value: _acknowledged,
              onChanged: submitting
                  ? null
                  : (v) => setState(() => _acknowledged = v ?? false),
              controlAffinity: ListTileControlAffinity.leading,
              contentPadding: EdgeInsets.zero,
              title: const Text(
                'I understand this permanently deletes my account and cannot '
                'be undone.',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: (_acknowledged && !submitting) ? _submit : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red.shade600,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: submitting
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : const Text(
                        'Delete my account',
                        style: TextStyle(fontWeight: FontWeight.w800),
                      ),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: submitting ? null : () => Navigator.of(context).pop(),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text('Cancel'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DisclosureSection extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color color;
  final List<String> items;
  final bool isDark;

  const _DisclosureSection({
    required this.title,
    required this.icon,
    required this.color,
    required this.items,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: color),
              const SizedBox(width: 8),
              Text(
                title,
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: color),
              ),
            ],
          ),
          const SizedBox(height: 10),
          for (final item in items)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('•  ', style: TextStyle(color: color, fontWeight: FontWeight.w800)),
                  Expanded(
                    child: Text(
                      item,
                      style: TextStyle(
                        fontSize: 13,
                        height: 1.4,
                        color: isDark ? Colors.grey[300] : Colors.black87,
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _MessageBanner extends StatelessWidget {
  final IconData icon;
  final Color color;
  final Color background;
  final String message;

  const _MessageBanner({
    required this.icon,
    required this.color,
    required this.background,
    required this.message,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: color),
            ),
          ),
        ],
      ),
    );
  }
}
