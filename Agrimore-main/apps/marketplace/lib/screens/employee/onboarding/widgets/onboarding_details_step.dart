import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import 'package:agrimore_ui/agrimore_ui.dart';
import '../../../../services/associate_application_service.dart';

/// Phase 16B-2, Workstream 2 — collects name/phone/email and creates
/// `employees/{uid}` via the SAME shared write `employee_apply_screen.dart`
/// now also calls (`associate_application_service.dart`'s
/// `submitAssociateApplication`) — see that file's header for why a shared
/// function, not a second copy, was the right call (2a).
class OnboardingDetailsStep extends StatefulWidget {
  final String uid;
  const OnboardingDetailsStep({super.key, required this.uid});

  @override
  State<OnboardingDetailsStep> createState() => _OnboardingDetailsStepState();
}

class _OnboardingDetailsStepState extends State<OnboardingDetailsStep> {
  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  bool _prefilled = false;
  bool _submitting = false;
  String? _error;
  // Phase 16B-3, Defect 4: true only when the users/{uid} read failed and
  // we fell back to an empty, manually-fillable form — shown as a small,
  // non-blocking note rather than silently pretending prefill succeeded.
  bool _prefillFailed = false;

  @override
  void initState() {
    super.initState();
    _prefillFromUserProfile();
  }

  /// Mirrors `employee_apply_screen.dart`'s `_loadUserData` — prefilling
  /// from `users/{uid}` so a visitor who already has a marketplace profile
  /// does not have to retype it.
  ///
  /// Phase 16B-3, Defect 4 fix: this read had no try/catch — a failure
  /// (offline, permission, transient) left `_prefilled` false forever, and
  /// `build()` returns a bare spinner while `!_prefilled`, so the visitor
  /// was stuck with no error and no way forward. On failure, `_prefilled`
  /// is now still set true (with empty controllers) so the form always
  /// becomes usable; `_prefillFailed` drives a small, non-blocking note.
  Future<void> _prefillFromUserProfile() async {
    try {
      final userDoc = await FirebaseFirestore.instance.collection('users').doc(widget.uid).get();
      if (!mounted) return;
      final data = userDoc.data() ?? {};
      setState(() {
        _nameCtrl.text = (data['name'] as String?) ?? '';
        _phoneCtrl.text = (data['phone'] as String?) ?? '';
        _emailCtrl.text = (data['email'] as String?) ?? '';
        _prefilled = true;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _prefilled = true;
        _prefillFailed = true;
      });
    }
  }

  Future<void> _submit() async {
    if (_nameCtrl.text.trim().isEmpty) return setState(() => _error = 'Name is required');
    if (_phoneCtrl.text.trim().isEmpty) return setState(() => _error = 'Mobile number is required');
    if (_emailCtrl.text.trim().isEmpty) return setState(() => _error = 'Email is required');

    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      await submitAssociateApplication(
        uid: widget.uid,
        name: _nameCtrl.text.trim(),
        email: _emailCtrl.text.trim(),
        phone: _phoneCtrl.text.trim(),
      );
      // No further navigation needed: the parent `_EmployeeStateGate`
      // (associate_onboarding_screen.dart) is a StreamBuilder on
      // employees/{uid} — this write causes it to rebuild into the payment
      // step automatically.
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = 'Could not save your details. Please try again.');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _emailCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_prefilled) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 24),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Your details', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
          const SizedBox(height: 4),
          const Text(
            'This creates your associate profile. You will pay the one-time onboarding fee on the next step.',
            style: TextStyle(fontSize: 12, color: Color(0xFF6B7280), height: 1.4),
          ),
          if (_prefillFailed) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFFFFFBEB),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text(
                'We could not pre-fill your details. Please enter them below.',
                style: TextStyle(fontSize: 11, color: Color(0xFF92400E), fontWeight: FontWeight.w600),
              ),
            ),
          ],
          const SizedBox(height: 14),
          _field('Full Name', _nameCtrl, Icons.person_outline),
          const SizedBox(height: 10),
          _field('Mobile Number', _phoneCtrl, Icons.phone_outlined, keyboard: TextInputType.phone),
          const SizedBox(height: 10),
          _field('Email', _emailCtrl, Icons.email_outlined, keyboard: TextInputType.emailAddress),
          if (_error != null) ...[
            const SizedBox(height: 10),
            Text(_error!, style: const TextStyle(color: Colors.red, fontSize: 12, fontWeight: FontWeight.w600)),
          ],
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _submitting ? null : _submit,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              child: _submitting
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white),
                    )
                  : const Text('Continue', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _field(String label, TextEditingController ctrl, IconData icon, {TextInputType? keyboard}) {
    return TextField(
      controller: ctrl,
      keyboardType: keyboard,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, size: 20),
        isDense: true,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }
}
