// ============================================================
//  MOBILE NUMBER SCREEN
//  Shown to NEW USERS after successful email/password login
//  Collects 10-digit Indian phone number, saves to Firestore
//  Then routes to → AddressEntryScreen → Home
// ============================================================

import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:agrimore_ui/agrimore_ui.dart';

class MobileNumberScreen extends StatefulWidget {
  const MobileNumberScreen({Key? key}) : super(key: key);

  @override
  State<MobileNumberScreen> createState() => _MobileNumberScreenState();
}

class _MobileNumberScreenState extends State<MobileNumberScreen>
    with SingleTickerProviderStateMixin {
  final _phoneController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;
  String? _errorMessage;

  late AnimationController _animController;
  late Animation<double> _fadeAnim;
  late Animation<Offset> _slideAnim;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _fadeAnim = CurvedAnimation(parent: _animController, curve: Curves.easeOut);
    _slideAnim = Tween<Offset>(
      begin: const Offset(0, 0.12),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _animController, curve: Curves.easeOutCubic));
    _animController.forward();
  }

  @override
  void dispose() {
    _phoneController.dispose();
    _animController.dispose();
    super.dispose();
  }

  String? _validatePhone(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Mobile number is required';
    }
    if (value.trim().length != 10) {
      return 'Enter a valid 10-digit mobile number';
    }
    if (!RegExp(r'^[6-9]\d{9}$').hasMatch(value.trim())) {
      return 'Enter a valid Indian mobile number';
    }
    return null;
  }

  Future<void> _handleSave() async {
    if (!_formKey.currentState!.validate()) return;
    HapticFeedback.mediumImpact();

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception('Session expired. Please login again.');

      final phone = '+91${_phoneController.text.trim()}';

      // Save phone to Firestore user document
      await FirebaseFirestore.instance.collection('users').doc(user.uid).update({
        'phone': phone,
        'phoneUpdatedAt': FieldValue.serverTimestamp(),
      });

      debugPrint('✅ Phone saved: $phone');

      // Navigate to address entry (replace so back doesn't come here)
      if (mounted) {
        Navigator.pushReplacementNamed(context, '/onboarding-address');
      }
    } catch (e) {
      setState(() {
        _errorMessage = e.toString().replaceAll('Exception: ', '');
      });
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final size = MediaQuery.of(context).size;

    return Scaffold(
      resizeToAvoidBottomInset: true,
      backgroundColor: isDark ? const Color(0xFF121212) : const Color(0xFFF7FAF8),
      body: Stack(
        children: [
          // ── Soft gradient background ──
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: isDark
                      ? [const Color(0xFF1A6B3A).withOpacity(0.18), const Color(0xFF121212)]
                      : [const Color(0xFF1A6B3A).withOpacity(0.07), const Color(0xFFF7FAF8)],
                ),
              ),
            ),
          ),

          // ── Decorative circles ──
          Positioned(
            top: -80,
            right: -60,
            child: Container(
              width: 220,
              height: 220,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFF1A6B3A).withOpacity(0.08),
              ),
            ),
          ),
          Positioned(
            bottom: -60,
            left: -40,
            child: Container(
              width: 160,
              height: 160,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFF1A6B3A).withOpacity(0.06),
              ),
            ),
          ),

          // ── Main content ──
          SafeArea(
            child: FadeTransition(
              opacity: _fadeAnim,
              child: SlideTransition(
                position: _slideAnim,
                child: SingleChildScrollView(
                  keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                  padding: EdgeInsets.symmetric(
                    horizontal: size.width > 600 ? size.width * 0.2 : 24,
                    vertical: 32,
                  ),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 16),

                        // ── Step indicator ──
                        _buildStepIndicator(),

                        const SizedBox(height: 32),

                        // ── Icon ──
                        Center(
                          child: Container(
                            width: 80,
                            height: 80,
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [Color(0xFF1A6B3A), Color(0xFF2E9957)],
                              ),
                              borderRadius: BorderRadius.circular(22),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFF1A6B3A).withOpacity(0.35),
                                  blurRadius: 20,
                                  offset: const Offset(0, 8),
                                ),
                              ],
                            ),
                            child: const Center(
                              child: Text('📱', style: TextStyle(fontSize: 38)),
                            ),
                          ),
                        ),

                        const SizedBox(height: 28),

                        // ── Title ──
                        Text(
                          'Your Mobile Number',
                          style: TextStyle(
                            fontSize: 26,
                            fontWeight: FontWeight.w800,
                            color: isDark ? Colors.white : const Color(0xFF1A1A1A),
                            letterSpacing: -0.5,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          'We\'ll use this to send order updates\nand delivery notifications.',
                          style: TextStyle(
                            fontSize: 15,
                            color: isDark ? Colors.white60 : const Color(0xFF666666),
                            height: 1.5,
                          ),
                        ),

                        const SizedBox(height: 36),

                        // ── Phone input card ──
                        _buildPhoneCard(isDark),

                        const SizedBox(height: 16),

                        // ── Error ──
                        if (_errorMessage != null) _buildError(),

                        const SizedBox(height: 28),

                        // ── CTA ──
                        _buildButton(),

                        const SizedBox(height: 20),

                        // ── Security note ──
                        Center(
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.lock_rounded,
                                  size: 13,
                                  color: isDark ? Colors.white38 : Colors.grey.shade400),
                              const SizedBox(width: 6),
                              Text(
                                'Your number is secure and never shared',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: isDark ? Colors.white38 : Colors.grey.shade500,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStepIndicator() {
    return Row(
      children: [
        _stepDot(1, done: true),  // Login - done
        _stepLine(done: true),
        _stepDot(2, active: true), // Phone - current
        _stepLine(),
        _stepDot(3),              // Address - upcoming
      ],
    );
  }

  Widget _stepDot(int step, {bool done = false, bool active = false}) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      width: active ? 32 : 28,
      height: active ? 32 : 28,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: done || active
            ? const Color(0xFF1A6B3A)
            : Colors.grey.withOpacity(0.2),
        border: active
            ? Border.all(color: const Color(0xFF1A6B3A), width: 2)
            : null,
        boxShadow: active
            ? [BoxShadow(
                color: const Color(0xFF1A6B3A).withOpacity(0.3),
                blurRadius: 8)]
            : null,
      ),
      child: Center(
        child: done
            ? const Icon(Icons.check, size: 14, color: Colors.white)
            : Text(
                '$step',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: active ? Colors.white : Colors.grey,
                ),
              ),
      ),
    );
  }

  Widget _stepLine({bool done = false}) {
    return Expanded(
      child: Container(
        height: 2,
        margin: const EdgeInsets.symmetric(horizontal: 4),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(2),
          color: done
              ? const Color(0xFF1A6B3A)
              : Colors.grey.withOpacity(0.25),
        ),
      ),
    );
  }

  Widget _buildPhoneCard(bool isDark) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: isDark
                ? Colors.white.withOpacity(0.07)
                : Colors.white.withOpacity(0.92),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: isDark
                  ? Colors.white.withOpacity(0.1)
                  : Colors.grey.shade200,
            ),
            boxShadow: isDark
                ? null
                : [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.06),
                      blurRadius: 16,
                      offset: const Offset(0, 6),
                    ),
                  ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Mobile Number',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.white70 : const Color(0xFF1A6B3A),
                ),
              ),
              const SizedBox(height: 12),
              Container(
                decoration: BoxDecoration(
                  color: isDark
                      ? Colors.white.withOpacity(0.05)
                      : const Color(0xFFF5F9F6),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isDark
                        ? Colors.white.withOpacity(0.1)
                        : Colors.grey.shade200,
                  ),
                ),
                child: Row(
                  children: [
                    // ── Country code prefix ──
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 16),
                      decoration: BoxDecoration(
                        border: Border(
                          right: BorderSide(
                            color: isDark
                                ? Colors.white.withOpacity(0.1)
                                : Colors.grey.shade200,
                          ),
                        ),
                      ),
                      child: Row(
                        children: [
                          const Text('🇮🇳',
                              style: TextStyle(fontSize: 20)),
                          const SizedBox(width: 8),
                          Text(
                            '+91',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: isDark
                                  ? Colors.white
                                  : const Color(0xFF1A1A1A),
                            ),
                          ),
                        ],
                      ),
                    ),
                    // ── Phone field ──
                    Expanded(
                      child: TextFormField(
                        controller: _phoneController,
                        keyboardType: TextInputType.phone,
                        autofocus: true,
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w600,
                          color:
                              isDark ? Colors.white : const Color(0xFF1A1A1A),
                          letterSpacing: 1.2,
                        ),
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                          LengthLimitingTextInputFormatter(10),
                        ],
                        decoration: InputDecoration(
                          hintText: '98765 43210',
                          hintStyle: TextStyle(
                            color: isDark
                                ? Colors.white30
                                : Colors.grey.shade400,
                            fontWeight: FontWeight.w400,
                            letterSpacing: 0,
                          ),
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 16),
                        ),
                        validator: _validatePhone,
                        onFieldSubmitted: (_) => _handleSave(),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildError() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.red.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.red.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline_rounded, color: Colors.red, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              _errorMessage!,
              style: const TextStyle(
                  color: Colors.red, fontSize: 13, fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildButton() {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF1A6B3A), Color(0xFF2E9957)],
          ),
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF1A6B3A).withOpacity(0.38),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: ElevatedButton(
          onPressed: _isLoading ? null : _handleSave,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.transparent,
            shadowColor: Colors.transparent,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14)),
            elevation: 0,
          ),
          child: _isLoading
              ? const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                )
              : const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'Continue',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.3,
                      ),
                    ),
                    SizedBox(width: 10),
                    Icon(Icons.arrow_forward_rounded, size: 20),
                  ],
                ),
        ),
      ),
    );
  }
}
