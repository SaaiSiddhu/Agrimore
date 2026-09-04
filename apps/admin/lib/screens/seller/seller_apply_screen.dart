import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class SellerApplyScreen extends StatefulWidget {
  const SellerApplyScreen({Key? key}) : super(key: key);

  @override
  State<SellerApplyScreen> createState() => _SellerApplyScreenState();
}

class _SellerApplyScreenState extends State<SellerApplyScreen> {
  final _nameCtrl = TextEditingController();
  final _mobileCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _bankNameCtrl = TextEditingController();
  final _accountCtrl = TextEditingController();
  final _ifscCtrl = TextEditingController();
  final _shopNameCtrl = TextEditingController();
  final _shopAddressCtrl = TextEditingController();
  bool _saving = false;
  String? _sellerStatus;
  Map<String, dynamic>? _sellerProfile;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    final doc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
    final data = doc.data() ?? {};
    setState(() {
      _sellerStatus = data['sellerStatus'] as String?;
      _sellerProfile = data['sellerProfile'] as Map<String, dynamic>?;
      _nameCtrl.text = data['name'] ?? '';
      _mobileCtrl.text = data['phone'] ?? '';
      _emailCtrl.text = data['email'] ?? '';
      if (_sellerProfile != null) {
        _bankNameCtrl.text = _sellerProfile!['bankName'] ?? '';
        _accountCtrl.text = _sellerProfile!['accountNumber'] ?? '';
        _ifscCtrl.text = _sellerProfile!['ifsc'] ?? '';
        _shopNameCtrl.text = _sellerProfile!['shopName'] ?? '';
        _shopAddressCtrl.text = _sellerProfile!['shopAddress'] ?? '';
      }
    });
  }

  Future<void> _handleSubmit() async {
    if (_nameCtrl.text.trim().isEmpty) return _showError('Name is required');
    if (_mobileCtrl.text.trim().isEmpty) return _showError('Mobile number is required');
    if (_emailCtrl.text.trim().isEmpty) return _showError('Email is required');
    if (_shopNameCtrl.text.trim().isEmpty) return _showError('Shop name is required');
    if (_shopAddressCtrl.text.trim().isEmpty) return _showError('Shop address is required');

    setState(() => _saving = true);
    try {
      final uid = FirebaseAuth.instance.currentUser!.uid;
      final profile = {
        'name': _nameCtrl.text.trim(),
        'mobile': _mobileCtrl.text.trim(),
        'email': _emailCtrl.text.trim(),
        'bankName': _bankNameCtrl.text.trim(),
        'accountNumber': _accountCtrl.text.trim(),
        'ifsc': _ifscCtrl.text.trim().toUpperCase(),
        'shopName': _shopNameCtrl.text.trim(),
        'shopAddress': _shopAddressCtrl.text.trim(),
        'appliedAt': DateTime.now().toIso8601String(),
      };

      await FirebaseFirestore.instance.collection('users').doc(uid).set({
        'sellerStatus': 'pending',
        'sellerProfile': profile,
      }, SetOptions(merge: true));

      await FirebaseFirestore.instance.collection('sellerRequests').doc(uid).set({
        'userId': uid,
        ...profile,
        'status': 'pending',
        'appliedAt': FieldValue.serverTimestamp(),
      });

      setState(() => _sellerStatus = 'pending');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('✅ Your seller application has been submitted!'), backgroundColor: Color(0xFF145A32)),
      );
    } catch (e) {
      _showError(e.toString());
    }
    setState(() => _saving = false);
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: Colors.red),
    );
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _mobileCtrl.dispose();
    _emailCtrl.dispose();
    _bankNameCtrl.dispose();
    _accountCtrl.dispose();
    _ifscCtrl.dispose();
    _shopNameCtrl.dispose();
    _shopAddressCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_sellerStatus == 'pending' || _sellerStatus == 'rejected') {
      return _buildStatusScreen();
    }
    return _buildFormScreen();
  }

  Widget _buildStatusScreen() {
    final isPending = _sellerStatus == 'pending';
    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      body: Column(
        children: [
          _buildHeader('Seller Application'),
          Expanded(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(32),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(28),
                        border: Border.all(
                          color: isPending ? const Color(0xFFF59E0B) : const Color(0xFFEF4444),
                          width: 2,
                        ),
                        boxShadow: const [BoxShadow(color: Color(0x14000000), blurRadius: 20, offset: Offset(0, 8))],
                      ),
                      child: Column(
                        children: [
                          Text(isPending ? '⏳' : '❌', style: const TextStyle(fontSize: 64)),
                          const SizedBox(height: 16),
                          Text(
                            isPending ? 'Application Pending' : 'Application Rejected',
                            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: Color(0xFF111827)),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            isPending
                                ? 'Your seller application is under review. Admin will approve it soon.'
                                : 'Your seller application was rejected. Please contact support.',
                            textAlign: TextAlign.center,
                            style: const TextStyle(fontSize: 14, color: Color(0xFF6B7280), height: 1.5),
                          ),
                          const SizedBox(height: 20),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFEF3C7),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              'Status: ${isPending ? "PENDING" : "REJECTED"}',
                              style: const TextStyle(color: Color(0xFFD97706), fontWeight: FontWeight.w900, fontSize: 14, letterSpacing: 1),
                            ),
                          ),
                          if (_sellerProfile?['shopName'] != null) ...[
                            const SizedBox(height: 16),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.store, color: Color(0xFF6B7280), size: 16),
                                const SizedBox(width: 8),
                                Text(_sellerProfile!['shopName'],
                                    style: const TextStyle(color: Color(0xFF6B7280), fontSize: 14)),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                    if (!isPending) ...[
                      const SizedBox(height: 24),
                      GestureDetector(
                        onTap: () async {
                          final uid = FirebaseAuth.instance.currentUser?.uid;
                          if (uid != null) {
                            await FirebaseFirestore.instance.collection('users').doc(uid).set(
                              {'sellerStatus': null},
                              SetOptions(merge: true),
                            );
                            setState(() => _sellerStatus = null);
                          }
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                          decoration: BoxDecoration(
                            color: const Color(0xFF3B82F6),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: const Text('Re-Apply',
                              style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 16)),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFormScreen() {
    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      body: Column(
        children: [
          _buildHeader('Become a Seller'),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Banner
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: const Color(0xFF145A32),
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: const [BoxShadow(color: Color(0x4D145A32), blurRadius: 12, offset: Offset(0, 6))],
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.store, color: Colors.white, size: 32),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: const [
                              Text('Start Selling', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w900)),
                              SizedBox(height: 4),
                              Text('Fill in your details below. Admin will review and approve.',
                                  style: TextStyle(color: Colors.white70, fontSize: 12)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Personal
                  const Text('👤 Personal Details', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Color(0xFF145A32))),
                  const SizedBox(height: 12),
                  _buildField('Full Name *', _nameCtrl, Icons.person),
                  _buildField('Mobile Number *', _mobileCtrl, Icons.phone, keyboard: TextInputType.phone),
                  _buildField('Email ID *', _emailCtrl, Icons.email, keyboard: TextInputType.emailAddress),

                  const SizedBox(height: 24),
                  const Text('🏦 Bank Details', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Color(0xFF145A32))),
                  const SizedBox(height: 12),
                  _buildField('Bank Name *', _bankNameCtrl, Icons.account_balance),
                  _buildField('Account Number *', _accountCtrl, Icons.credit_card, keyboard: TextInputType.number),
                  _buildField('IFSC Code *', _ifscCtrl, Icons.tag),

                  const SizedBox(height: 24),
                  const Text('🏪 Shop Details', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Color(0xFF145A32))),
                  const SizedBox(height: 12),
                  _buildField('Shop Name *', _shopNameCtrl, Icons.store),
                  _buildField('Shop Address *', _shopAddressCtrl, Icons.location_on, maxLines: 3),

                  const SizedBox(height: 32),
                  GestureDetector(
                    onTap: _saving ? null : _handleSubmit,
                    child: AnimatedOpacity(
                      opacity: _saving ? 0.6 : 1.0,
                      duration: const Duration(milliseconds: 200),
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 18),
                        decoration: BoxDecoration(
                          color: const Color(0xFFD4A843),
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: const [BoxShadow(color: Color(0x66D4A843), blurRadius: 12, offset: Offset(0, 6))],
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            if (_saving)
                              const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
                            else ...[
                              const Icon(Icons.send, color: Colors.white, size: 20),
                              const SizedBox(width: 10),
                              const Text('Submit Application', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w900)),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 100),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(String title) {
    return Container(
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 12,
        bottom: 20, left: 20, right: 20,
      ),
      decoration: const BoxDecoration(
        color: Color(0xFF145A32),
        borderRadius: BorderRadius.only(bottomLeft: Radius.circular(28), bottomRight: Radius.circular(28)),
      ),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              width: 40, height: 40,
              decoration: BoxDecoration(color: Colors.white.withOpacity(0.15), borderRadius: BorderRadius.circular(14)),
              child: const Icon(Icons.arrow_back, color: Color(0xFFD4A843), size: 24),
            ),
          ),
          Expanded(
            child: Text(title, textAlign: TextAlign.center,
                style: const TextStyle(color: Color(0xFFD4A843), fontSize: 22, fontWeight: FontWeight.w900)),
          ),
          const SizedBox(width: 40),
        ],
      ),
    );
  }

  Widget _buildField(String label, TextEditingController ctrl, IconData icon,
      {TextInputType keyboard = TextInputType.text, int maxLines = 1}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 12, bottom: 6),
          child: Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF374151))),
        ),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFE5E7EB)),
            boxShadow: const [BoxShadow(color: Color(0x08000000), blurRadius: 6, offset: Offset(0, 2))],
          ),
          child: Row(
            crossAxisAlignment: maxLines > 1 ? CrossAxisAlignment.start : CrossAxisAlignment.center,
            children: [
              Padding(
                padding: EdgeInsets.only(left: 16, top: maxLines > 1 ? 16 : 0),
                child: Icon(icon, color: const Color(0xFF9CA3AF), size: 18),
              ),
              Expanded(
                child: TextField(
                  controller: ctrl,
                  keyboardType: keyboard,
                  maxLines: maxLines,
                  textCapitalization: label.contains('IFSC') ? TextCapitalization.characters : TextCapitalization.none,
                  decoration: const InputDecoration(
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                  ),
                  style: const TextStyle(fontSize: 15, color: Color(0xFF111827)),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
