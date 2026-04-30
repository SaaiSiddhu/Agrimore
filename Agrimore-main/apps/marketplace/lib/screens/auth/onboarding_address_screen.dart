// ============================================================
//  ONBOARDING ADDRESS ENTRY SCREEN
//  Step 3 in new-user flow: enter / pin delivery address
//  Saved as DEFAULT delivery address → redirects to Home
//  Also reused from profile for add/edit address
// ============================================================

import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'package:agrimore_core/agrimore_core.dart';
import '../../providers/address_provider.dart';

class OnboardingAddressScreen extends StatefulWidget {
  /// When [isOnboarding] = true:  save as default → push to /main
  /// When [isOnboarding] = false: used from profile → pop after save
  final bool isOnboarding;

  /// If editing an existing address, pass it here
  final AddressModel? existingAddress;

  const OnboardingAddressScreen({
    Key? key,
    this.isOnboarding = true,
    this.existingAddress,
  }) : super(key: key);

  @override
  State<OnboardingAddressScreen> createState() =>
      _OnboardingAddressScreenState();
}

class _OnboardingAddressScreenState extends State<OnboardingAddressScreen>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();

  // Controllers
  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _line1Ctrl = TextEditingController();
  final _line2Ctrl = TextEditingController();
  final _cityCtrl = TextEditingController();
  final _stateCtrl = TextEditingController();
  final _pinCtrl = TextEditingController();
  final _landmarkCtrl = TextEditingController();

  String _addressType = 'home'; // home | work | other
  bool _isLoading = false;
  String? _errorMessage;

  late AnimationController _animCtrl;
  late Animation<double> _fadeAnim;
  late Animation<Offset> _slideAnim;

  bool get _isEditing => widget.existingAddress != null;

  @override
  void initState() {
    super.initState();

    _animCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _fadeAnim = CurvedAnimation(parent: _animCtrl, curve: Curves.easeOut);
    _slideAnim = Tween<Offset>(
      begin: const Offset(0, 0.10),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _animCtrl, curve: Curves.easeOutCubic));
    _animCtrl.forward();

    // Pre-fill if editing
    if (_isEditing) {
      final a = widget.existingAddress!;
      _nameCtrl.text = a.name;
      _phoneCtrl.text = a.phone.replaceAll('+91', '');
      _line1Ctrl.text = a.addressLine1;
      _line2Ctrl.text = a.addressLine2;
      _cityCtrl.text = a.city;
      _stateCtrl.text = a.state;
      _pinCtrl.text = a.zipcode;
      _landmarkCtrl.text = a.landmark ?? '';
      _addressType = a.addressType ?? 'home';
    } else {
      // Pre-fill name & phone from Firebase user
      _prefillFromFirebase();
    }
  }

  Future<void> _prefillFromFirebase() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      if (!mounted) return;
      final data = doc.data();
      if (data != null) {
        if (mounted) {
          setState(() {
            _nameCtrl.text = data['name'] ?? '';
            final raw = (data['phone'] ?? '') as String;
            _phoneCtrl.text = raw.replaceAll('+91', '').trim();
          });
        }
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _line1Ctrl.dispose();
    _line2Ctrl.dispose();
    _cityCtrl.dispose();
    _stateCtrl.dispose();
    _pinCtrl.dispose();
    _landmarkCtrl.dispose();
    _animCtrl.dispose();
    super.dispose();
  }

  // ── Validators ──────────────────────────────────────────────
  String? _req(String? v, String field) =>
      (v == null || v.trim().isEmpty) ? '$field is required' : null;

  String? _validatePhone(String? v) {
    if (v == null || v.trim().isEmpty) return 'Phone is required';
    if (!RegExp(r'^[6-9]\d{9}$').hasMatch(v.trim())) {
      return 'Enter valid 10-digit Indian mobile number';
    }
    return null;
  }

  String? _validatePin(String? v) {
    if (v == null || v.trim().isEmpty) return 'PIN code is required';
    if (v.trim().length != 6) return 'Enter valid 6-digit PIN code';
    return null;
  }

  // ── Save ─────────────────────────────────────────────────────
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

      final addressProvider =
          context.read<AddressProvider>();

      // In onboarding: first address → always default
      final makeDefault = widget.isOnboarding || _isEditing
          ? widget.existingAddress?.isDefault ?? false
          : addressProvider.addresses.isEmpty;

      final address = AddressModel(
        id: _isEditing ? widget.existingAddress!.id : '',
        userId: user.uid,
        name: _nameCtrl.text.trim(),
        phone: '+91${_phoneCtrl.text.trim()}',
        addressLine1: _line1Ctrl.text.trim(),
        addressLine2: _line2Ctrl.text.trim(),
        city: _cityCtrl.text.trim(),
        state: _stateCtrl.text.trim(),
        zipcode: _pinCtrl.text.trim(),
        landmark: _landmarkCtrl.text.trim().isEmpty
            ? null
            : _landmarkCtrl.text.trim(),
        addressType: _addressType,
        isDefault: widget.isOnboarding ? true : makeDefault,
        country: 'India',
      );

      if (_isEditing) {
        await addressProvider.updateAddress(
            address.id, address.toMap());
      } else {
        await addressProvider.addAddress(address);
      }

      debugPrint('✅ Address saved. isOnboarding=${widget.isOnboarding}');

      if (!mounted) return;

      if (widget.isOnboarding) {
        // Clear entire stack → Home
        Navigator.pushNamedAndRemoveUntil(
          context,
          '/main',
          (route) => false,
        );
      } else {
        Navigator.pop(context, true); // return true = saved
      }
    } catch (e) {
      setState(() {
        _errorMessage = e.toString().replaceAll('Exception: ', '');
      });
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ════════════════════════════════════════════════════════════
  // BUILD
  // ════════════════════════════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final size = MediaQuery.of(context).size;

    return Scaffold(
      resizeToAvoidBottomInset: true,
      backgroundColor:
          isDark ? const Color(0xFF121212) : const Color(0xFFF7FAF8),
      body: Stack(
        children: [
          // ── gradient bg ──
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: isDark
                      ? [
                          const Color(0xFF1A6B3A).withOpacity(0.15),
                          const Color(0xFF121212)
                        ]
                      : [
                          const Color(0xFF1A6B3A).withOpacity(0.06),
                          const Color(0xFFF7FAF8)
                        ],
                ),
              ),
            ),
          ),

          // ── decorative circles ──
          Positioned(
            top: -60,
            right: -50,
            child: Container(
              width: 180,
              height: 180,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFF1A6B3A).withOpacity(0.07),
              ),
            ),
          ),

          // ── Content ──
          SafeArea(
            child: FadeTransition(
              opacity: _fadeAnim,
              child: SlideTransition(
                position: _slideAnim,
                child: CustomScrollView(
                  keyboardDismissBehavior:
                      ScrollViewKeyboardDismissBehavior.onDrag,
                  slivers: [
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal:
                              size.width > 600 ? size.width * 0.15 : 20,
                          vertical: 24,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // ── Step indicator (only during onboarding) ──
                            if (widget.isOnboarding) ...[
                              _buildStepIndicator(),
                              const SizedBox(height: 28),
                            ] else ...[
                              _buildBackBar(isDark),
                              const SizedBox(height: 20),
                            ],

                            // ── Header ──
                            _buildHeader(isDark),

                            const SizedBox(height: 28),

                            // ── Form ──
                            Form(
                              key: _formKey,
                              child: Column(
                                children: [
                                  // Address type chips
                                  _buildAddressTypePicker(isDark),

                                  const SizedBox(height: 20),

                                  // Contact info card
                                  _buildCard(
                                    isDark: isDark,
                                    title: 'Contact Details',
                                    icon: Icons.person_rounded,
                                    children: [
                                      _buildField(
                                        ctrl: _nameCtrl,
                                        label: 'Full Name',
                                        hint: 'e.g. Ravi Kumar',
                                        icon: Icons.person_outline,
                                        isDark: isDark,
                                        validator: (v) => _req(v, 'Name'),
                                        capitalization:
                                            TextCapitalization.words,
                                      ),
                                      const SizedBox(height: 14),
                                      _buildPhoneField(isDark),
                                    ],
                                  ),

                                  const SizedBox(height: 16),

                                  // Address details card
                                  _buildCard(
                                    isDark: isDark,
                                    title: 'Address Details',
                                    icon: Icons.location_on_rounded,
                                    children: [
                                      _buildField(
                                        ctrl: _line1Ctrl,
                                        label: 'House / Flat / Building',
                                        hint: 'e.g. Door No. 12, Nehru St.',
                                        icon: Icons.home_outlined,
                                        isDark: isDark,
                                        validator: (v) =>
                                            _req(v, 'Address line 1'),
                                      ),
                                      const SizedBox(height: 14),
                                      _buildField(
                                        ctrl: _line2Ctrl,
                                        label: 'Area / Street / Locality',
                                        hint: 'e.g. Velachery, Anna Nagar',
                                        icon: Icons.map_outlined,
                                        isDark: isDark,
                                        validator: (v) =>
                                            _req(v, 'Area / Locality'),
                                      ),
                                      const SizedBox(height: 14),
                                      _buildField(
                                        ctrl: _landmarkCtrl,
                                        label: 'Landmark (Optional)',
                                        hint: 'e.g. Near Big Bazaar',
                                        icon: Icons.pin_drop_outlined,
                                        isDark: isDark,
                                        isOptional: true,
                                      ),
                                      const SizedBox(height: 14),
                                      Row(
                                        children: [
                                          Expanded(
                                            child: _buildField(
                                              ctrl: _cityCtrl,
                                              label: 'City',
                                              hint: 'Chennai',
                                              icon: Icons.location_city_outlined,
                                              isDark: isDark,
                                              validator: (v) =>
                                                  _req(v, 'City'),
                                              capitalization:
                                                  TextCapitalization.words,
                                            ),
                                          ),
                                          const SizedBox(width: 12),
                                          Expanded(
                                            child: _buildField(
                                              ctrl: _pinCtrl,
                                              label: 'PIN Code',
                                              hint: '600001',
                                              icon: Icons.numbers_rounded,
                                              isDark: isDark,
                                              validator: _validatePin,
                                              keyboardType:
                                                  TextInputType.number,
                                              formatters: [
                                                FilteringTextInputFormatter
                                                    .digitsOnly,
                                                LengthLimitingTextInputFormatter(
                                                    6),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 14),
                                      _buildField(
                                        ctrl: _stateCtrl,
                                        label: 'State',
                                        hint: 'Tamil Nadu',
                                        icon: Icons.flag_outlined,
                                        isDark: isDark,
                                        validator: (v) => _req(v, 'State'),
                                        capitalization: TextCapitalization.words,
                                      ),
                                    ],
                                  ),

                                  const SizedBox(height: 16),

                                  // Error
                                  if (_errorMessage != null) _buildError(),

                                  const SizedBox(height: 20),

                                  // CTA
                                  _buildSaveButton(isDark),

                                  const SizedBox(height: 40),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Step indicator ───────────────────────────────────────────
  Widget _buildStepIndicator() {
    return Row(
      children: [
        _stepDot(1, done: true),
        _stepLine(done: true),
        _stepDot(2, done: true),
        _stepLine(done: true),
        _stepDot(3, active: true),
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
        boxShadow: active
            ? [
                BoxShadow(
                    color: const Color(0xFF1A6B3A).withOpacity(0.3),
                    blurRadius: 8)
              ]
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

  // ── Back bar (non-onboarding) ────────────────────────────────
  Widget _buildBackBar(bool isDark) {
    return GestureDetector(
      onTap: () => Navigator.pop(context),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: isDark
                  ? Colors.white.withOpacity(0.08)
                  : Colors.grey.shade100,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(Icons.arrow_back_rounded,
                size: 20,
                color: isDark ? Colors.white70 : const Color(0xFF1A1A1A)),
          ),
          const SizedBox(width: 12),
          Text(
            _isEditing ? 'Edit Address' : 'Add New Address',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: isDark ? Colors.white : const Color(0xFF1A1A1A),
            ),
          ),
        ],
      ),
    );
  }

  // ── Header ───────────────────────────────────────────────────
  Widget _buildHeader(bool isDark) {
    if (!widget.isOnboarding) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: const [
            Text('📍', style: TextStyle(fontSize: 36)),
            SizedBox(width: 14),
            Expanded(
              child: Text(
                'Delivery Address',
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF1A1A1A),
                  letterSpacing: -0.5,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          'Where should we deliver your orders?\nThis will be your default delivery address.',
          style: TextStyle(
            fontSize: 15,
            color: isDark ? Colors.white60 : Colors.grey.shade600,
            height: 1.5,
          ),
        ),
      ],
    );
  }

  // ── Address type chips ───────────────────────────────────────
  Widget _buildAddressTypePicker(bool isDark) {
    final types = [
      {'value': 'home', 'label': 'Home', 'icon': '🏠'},
      {'value': 'work', 'label': 'Work', 'icon': '🏢'},
      {'value': 'other', 'label': 'Other', 'icon': '📍'},
    ];
    return Row(
      children: types.map((t) {
        final selected = _addressType == t['value'];
        return Expanded(
          child: GestureDetector(
            onTap: () {
              HapticFeedback.selectionClick();
              setState(() => _addressType = t['value'] as String);
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              margin: const EdgeInsets.only(right: 10),
              padding: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: selected
                    ? const Color(0xFF1A6B3A)
                    : isDark
                        ? Colors.white.withOpacity(0.06)
                        : Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: selected
                      ? const Color(0xFF1A6B3A)
                      : isDark
                          ? Colors.white.withOpacity(0.1)
                          : Colors.grey.shade200,
                  width: selected ? 1.5 : 1,
                ),
                boxShadow: selected
                    ? [
                        BoxShadow(
                          color: const Color(0xFF1A6B3A).withOpacity(0.25),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        )
                      ]
                    : null,
              ),
              child: Column(
                children: [
                  Text(t['icon']!,
                      style: const TextStyle(fontSize: 20)),
                  const SizedBox(height: 4),
                  Text(
                    t['label']!,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: selected
                          ? Colors.white
                          : isDark
                              ? Colors.white70
                              : Colors.grey.shade700,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  // ── Glassmorphism card ───────────────────────────────────────
  Widget _buildCard({
    required bool isDark,
    required String title,
    required IconData icon,
    required List<Widget> children,
  }) {
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
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 14,
                      offset: const Offset(0, 5),
                    )
                  ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(icon,
                      size: 18, color: const Color(0xFF1A6B3A)),
                  const SizedBox(width: 8),
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: isDark
                          ? Colors.white
                          : const Color(0xFF1A1A1A),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              ...children,
            ],
          ),
        ),
      ),
    );
  }

  // ── Generic text field ───────────────────────────────────────
  Widget _buildField({
    required TextEditingController ctrl,
    required String label,
    required String hint,
    required IconData icon,
    required bool isDark,
    String? Function(String?)? validator,
    TextInputType keyboardType = TextInputType.text,
    TextCapitalization capitalization = TextCapitalization.none,
    List<TextInputFormatter>? formatters,
    bool isOptional = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white54 : Colors.grey.shade600,
              ),
            ),
            if (isOptional) ...[
              const SizedBox(width: 4),
              Text(
                '(Optional)',
                style: TextStyle(
                  fontSize: 11,
                  color: isDark ? Colors.white38 : Colors.grey.shade400,
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 6),
        Container(
          decoration: BoxDecoration(
            color: isDark
                ? Colors.white.withOpacity(0.05)
                : const Color(0xFFF5F9F6),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isDark
                  ? Colors.white.withOpacity(0.1)
                  : Colors.grey.shade200,
            ),
          ),
          child: TextFormField(
            controller: ctrl,
            keyboardType: keyboardType,
            textCapitalization: capitalization,
            inputFormatters: formatters,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w500,
              color: isDark ? Colors.white : const Color(0xFF1A1A1A),
            ),
            decoration: InputDecoration(
              prefixIcon: Icon(icon,
                  size: 18,
                  color: isDark
                      ? Colors.white38
                      : Colors.grey.shade500),
              hintText: hint,
              hintStyle: TextStyle(
                fontSize: 14,
                color: isDark ? Colors.white24 : Colors.grey.shade400,
                fontWeight: FontWeight.w400,
              ),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12, vertical: 14),
            ),
            validator: validator,
          ),
        ),
      ],
    );
  }

  // ── Phone field with +91 prefix ──────────────────────────────
  Widget _buildPhoneField(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Mobile Number',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: isDark ? Colors.white54 : Colors.grey.shade600,
          ),
        ),
        const SizedBox(height: 6),
        Container(
          decoration: BoxDecoration(
            color: isDark
                ? Colors.white.withOpacity(0.05)
                : const Color(0xFFF5F9F6),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isDark
                  ? Colors.white.withOpacity(0.1)
                  : Colors.grey.shade200,
            ),
          ),
          child: Row(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 14),
                child: Row(
                  children: [
                    const Text('🇮🇳',
                        style: TextStyle(fontSize: 18)),
                    const SizedBox(width: 6),
                    Text(
                      '+91',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: isDark
                            ? Colors.white
                            : const Color(0xFF1A1A1A),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Container(
                      height: 18,
                      width: 1,
                      color: isDark
                          ? Colors.white24
                          : Colors.grey.shade300,
                    ),
                  ],
                ),
              ),
              Expanded(
                child: TextFormField(
                  controller: _phoneCtrl,
                  keyboardType: TextInputType.phone,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(10),
                  ],
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    color: isDark ? Colors.white : const Color(0xFF1A1A1A),
                  ),
                  decoration: InputDecoration(
                    hintText: '98765 43210',
                    hintStyle: TextStyle(
                      color: isDark
                          ? Colors.white24
                          : Colors.grey.shade400,
                      fontWeight: FontWeight.w400,
                    ),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 4, vertical: 14),
                  ),
                  validator: _validatePhone,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ── Error ────────────────────────────────────────────────────
  Widget _buildError() {
    return Container(
      padding: const EdgeInsets.all(14),
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.red.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.red.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline_rounded,
              color: Colors.red, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              _errorMessage!,
              style: const TextStyle(
                  color: Colors.red,
                  fontSize: 13,
                  fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }

  // ── Save button ──────────────────────────────────────────────
  Widget _buildSaveButton(bool isDark) {
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
                    valueColor:
                        AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                )
              : Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      widget.isOnboarding
                          ? Icons.home_rounded
                          : (_isEditing
                              ? Icons.save_rounded
                              : Icons.add_location_alt_rounded),
                      size: 20,
                    ),
                    const SizedBox(width: 10),
                    Text(
                      widget.isOnboarding
                          ? 'Save & Go to Home'
                          : (_isEditing
                              ? 'Update Address'
                              : 'Save Address'),
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.3,
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}
