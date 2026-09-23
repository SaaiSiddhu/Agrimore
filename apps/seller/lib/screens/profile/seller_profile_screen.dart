// lib/screens/profile/seller_profile_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:agrimore_ui/agrimore_ui.dart' show AgIcons;
import '../../providers/seller_auth_provider.dart';
import '../../providers/seller_product_provider.dart';
import '../../providers/seller_order_provider.dart';
import '../rfq/seller_rfq_inbox_screen.dart';
import '../ai/seller_ai_chat_screen.dart';
import 'delivery_fee_sheet.dart';
import 'seller_ai_integration_screen.dart';
import '../onboarding/application_rules.dart';
import '../storefront/storefront_editor_screen.dart';
import '../reviews/reviews_screen.dart';
import '../account/settings_screen.dart';
import '../../l10n/app_localizations.dart';

class SellerProfileScreen extends StatefulWidget {
  const SellerProfileScreen({super.key});

  @override
  State<SellerProfileScreen> createState() => _SellerProfileScreenState();
}

class _SellerProfileScreenState extends State<SellerProfileScreen> {
  Map<String, dynamic>? _sellerData;
  bool _isLoading = true;
  // Phase FIX-2 (finding F-1, raised by this phase's own feedback lane).
  // Payout fields moved to seller_payout_details/{uid}, a document that — unlike
  // the seller's own profile — can fail to load on its own (denied read, offline,
  // not yet created by an admin). Without this flag the Bank Details card falls
  // back to "Not added" for all three cases, telling a seller who HAS bank
  // details that they have none. feedback.md §2: a read failure must not
  // masquerade as an empty state.
  bool _payoutUnavailable = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadSellerProfile());
  }

  Future<void> _loadSellerProfile() async {
    final uid = context.read<SellerAuthProvider>().currentUser?.uid;
    if (uid == null) return;

    try {
      final doc =
          await FirebaseFirestore.instance.collection('sellers').doc(uid).get();
      final userDoc =
          await FirebaseFirestore.instance.collection('users').doc(uid).get();

      // Phase FIX-2 (finding N-2, P0): bankName/accountNumber/ifsc no longer
      // live in the publicly readable `sellers/{uid}` document — they moved to
      // `seller_payout_details/{uid}`, which only the owner and an admin can
      // read. Fetched in its OWN try so that a payout-read failure degrades the
      // Bank Details card to "Not added" instead of failing the whole profile
      // load: this screen also renders business details, hours and delivery
      // radius, none of which should disappear because one read was denied.
      Map<String, dynamic> payoutData = {};
      bool payoutUnavailable = false;
      try {
        final payoutDoc = await FirebaseFirestore.instance
            .collection('seller_payout_details')
            .doc(uid)
            .get();
        payoutData = payoutDoc.data() ?? {};
      } catch (e) {
        // Detail to the log only — never to the card (feedback.md §2).
        debugPrint('⚠️ Could not load seller payout details: $e');
        payoutUnavailable = true;
      }

      if (mounted) {
        setState(() {
          _sellerData = {
            ...(doc.data() ?? {}),
            ...(userDoc.data() ?? {}),
            ...payoutData,
          };
          _payoutUnavailable = payoutUnavailable;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('❌ Error loading seller profile: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final auth = context.watch<SellerAuthProvider>();

    return Scaffold(
      backgroundColor:
          isDark ? const Color(0xFF121212) : const Color(0xFFF5F7FA),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFF2D7D3C)))
          : CustomScrollView(
              slivers: [
                // Seller profile header
                SliverToBoxAdapter(child: _buildProfileHeader(auth, isDark)),
                // Stats
                SliverToBoxAdapter(child: _buildStatsCards(isDark)),
                // Menu items
                SliverToBoxAdapter(child: _buildMenuSection(isDark)),
                // Logout
                SliverToBoxAdapter(child: _buildLogoutButton(auth, isDark)),
                const SliverToBoxAdapter(child: SizedBox(height: 100)),
              ],
            ),
    );
  }

  Widget _buildProfileHeader(SellerAuthProvider auth, bool isDark) {
    final user = auth.currentUser;
    final name = _sellerData?['businessName'] ??
        _sellerData?['name'] ??
        user?.displayName ??
        'Seller';
    final email = user?.email ?? '';
    final phone = _sellerData?['phone'] ?? '';
    final photoUrl = _sellerData?['photoUrl'] ?? user?.photoUrl;
    final rating = (_sellerData?['rating'] ?? 0).toDouble();
    final reviewCount = _sellerData?['reviewCount'] ?? 0;

    return Container(
      padding: const EdgeInsets.fromLTRB(24, 60, 24, 24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1A365D), Color(0xFF2B6CB0)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(24)),
        boxShadow: [
          BoxShadow(
              color: const Color(0xFF1A365D).withOpacity(0.3),
              blurRadius: 16,
              offset: const Offset(0, 4)),
        ],
      ),
      child: Column(
        children: [
          // App bar row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('My Profile',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold)),
              IconButton(
                onPressed: () => _showEditDialog(),
                icon: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.edit, color: Colors.white, size: 16),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Avatar
          CircleAvatar(
            radius: 42,
            backgroundColor: Colors.white.withOpacity(0.2),
            backgroundImage: photoUrl != null ? NetworkImage(photoUrl) : null,
            child: photoUrl == null
                ? Text(name.isNotEmpty ? name[0].toUpperCase() : 'S',
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 28,
                        fontWeight: FontWeight.bold))
                : null,
          ),
          const SizedBox(height: 14),
          Text(name,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text(email,
              style: const TextStyle(color: Colors.white70, fontSize: 13)),
          if (phone.isNotEmpty) ...[
            const SizedBox(height: 2),
            Text(phone,
                style: const TextStyle(color: Colors.white70, fontSize: 13)),
          ],
          const SizedBox(height: 12),
          // Rating
          if (rating > 0)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.15),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.star, color: Colors.amber, size: 16),
                  const SizedBox(width: 4),
                  Text(rating.toStringAsFixed(1),
                      style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 14)),
                  Text(' ($reviewCount reviews)',
                      style:
                          const TextStyle(color: Colors.white70, fontSize: 12)),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildStatsCards(bool isDark) {
    final products = context.read<SellerProductProvider>();
    final orders = context.read<SellerOrderProvider>();

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
      child: Row(
        children: [
          _buildStatCard('Products', products.totalProducts.toString(),
              Icons.inventory_2, Colors.blue, isDark),
          const SizedBox(width: 10),
          _buildStatCard('Orders', orders.totalOrders.toString(),
              Icons.receipt_long, Colors.green, isDark),
          const SizedBox(width: 10),
          _buildStatCard(
              'Revenue',
              '₹${orders.totalRevenue.toStringAsFixed(0)}',
              Icons.currency_rupee,
              Colors.orange,
              isDark),
        ],
      ),
    );
  }

  Widget _buildStatCard(
      String label, String value, IconData icon, Color color, bool isDark) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isDark ? Colors.grey[900] : Colors.white,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 10,
                offset: const Offset(0, 2)),
          ],
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(height: 6),
            Text(value,
                style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: isDark ? Colors.white : Colors.black87)),
            Text(label,
                style: TextStyle(fontSize: 11, color: Colors.grey[500])),
          ],
        ),
      ),
    );
  }

  Widget _buildMenuSection(bool isDark) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
      child: Container(
        decoration: BoxDecoration(
          color: isDark ? Colors.grey[900] : Colors.white,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 10,
                offset: const Offset(0, 2)),
          ],
        ),
        child: Column(
          children: [
            _buildMenuItem(Icons.store_outlined, 'Business Details',
                'Name, GST, location', isDark, () => _showEditDialog()),
            _buildDivider(isDark),
            _buildMenuItem(AgIcons.store, AppLocalizations.of(context).storefrontMenu,
                AppLocalizations.of(context).storefrontMenuSubtitle, isDark, () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const StorefrontEditorScreen()),
              );
            }),
            _buildDivider(isDark),
            _buildMenuItem(AgIcons.star, AppLocalizations.of(context).reviewsMenu,
                AppLocalizations.of(context).reviewsMenuSubtitle, isDark, () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const SellerReviewsScreen()),
              );
            }),
            _buildDivider(isDark),
            _buildMenuItem(AgIcons.settings, AppLocalizations.of(context).settingsTitle,
                AppLocalizations.of(context).settingsMenuSubtitle, isDark, () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const SellerSettingsScreen()),
              );
            }),
            _buildDivider(isDark),
            _buildMenuItem(Icons.request_quote_outlined, 'Quote Requests',
                'Respond to bulk quote requests', isDark, () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const SellerRfqInboxScreen()),
              );
            }),
            _buildDivider(isDark),
            _buildMenuItem(Icons.account_balance_outlined, 'Bank Details',
                'Payout account settings', isDark, () {
              // F-1: three distinct states, never conflated. A failed read says
              // so; it does not claim the seller has no bank details.
              _showDetailsDialog(
                'Bank Details',
                _payoutUnavailable
                    ? const [
                        'We could not load your bank details right now.',
                        'Please reopen this screen, or contact support if it keeps happening.',
                      ]
                    : [
                        'Bank: ${_sellerData?['bankName'] ?? 'Not added'}',
                        'Account: ${_sellerData?['accountNumber'] ?? 'Not added'}',
                        'IFSC: ${_sellerData?['ifsc'] ?? 'Not added'}',
                      ],
              );
            }),
            _buildDivider(isDark),
            _buildMenuItem(Icons.access_time, 'Business Hours',
                'Operating schedule', isDark, () {
              _showDetailsDialog('Business Hours', [
                'Open: ${_sellerData?['openingTime'] ?? '9:00 AM'}',
                'Close: ${_sellerData?['closingTime'] ?? '9:00 PM'}',
                'Delivery radius: ${_sellerData?['deliveryRadiusKm'] ?? 10} km',
              ]);
            }),
            _buildDivider(isDark),
            _buildMenuItem(
              Icons.local_shipping_outlined,
              'Delivery Fee',
              describeDeliveryFeeSchedule(
                  _sellerData?['deliveryFeeSchedule'] as Map<String, dynamic>?),
              isDark,
              () {
                final uid = context.read<SellerAuthProvider>().currentUser?.uid;
                if (uid == null) return;
                showDeliveryFeeSheet(
                  context,
                  uid: uid,
                  initialSchedule:
                      _sellerData?['deliveryFeeSchedule'] as Map<String, dynamic>?,
                  onSaved: _loadSellerProfile,
                );
              },
            ),
            _buildDivider(isDark),
            // Phase AI-4D: the actual usable chat feature -- placed above
            // 'AI Integration' (the connect/settings screen) since it's the
            // primary reason a seller would look for this menu at all; the
            // chat screen itself gates on connection status and routes to
            // AI Integration below when not yet connected.
            _buildMenuItem(Icons.chat_bubble_outline_rounded, 'AI Assistant',
                'Ask about your sales, products, and orders', isDark, () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const SellerAiChatScreen()),
              );
            }),
            _buildDivider(isDark),
            // Phase AI-4C: a genuinely stateful, multi-step feature (payment
            // -> connect -> status -> disconnect), so this pushes a
            // dedicated screen, matching 'Quote Requests' above rather than
            // a _showDetailsDialog/_showEditDialog like the simpler items.
            _buildMenuItem(Icons.smart_toy_outlined, 'AI Integration',
                'Connect your ChatGPT or Gemini key', isDark, () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const SellerAiIntegrationScreen()),
              );
            }),
            _buildDivider(isDark),
            _buildMenuItem(Icons.notifications_outlined, 'Notifications',
                'Manage alerts', isDark, () {
              _showDetailsDialog('Notifications', [
                'Order updates: Enabled',
                'Low stock alerts: Enabled',
                'Payout updates: Enabled',
              ]);
            }),
            _buildDivider(isDark),
            _buildMenuItem(Icons.help_outline, 'Help & Support',
                'FAQs, contact support', isDark, () {
              _showDetailsDialog('Help & Support', [
                'Email: support@agrimore.in',
                'For urgent order issues, contact the admin team from your registered mobile number.',
              ]);
            }),
            _buildDivider(isDark),
            _buildMenuItem(Icons.privacy_tip_outlined, 'Privacy & Terms',
                'Legal documents', isDark, () {
              _showDetailsDialog('Privacy & Terms', [
                'Keep product details accurate.',
                'Orders must be packed on time.',
                'Payouts are processed against delivered orders.',
              ]);
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildMenuItem(IconData icon, String title, String subtitle,
      bool isDark, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFF2D7D3C).withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: const Color(0xFF2D7D3C), size: 20),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: const TextStyle(
                          fontWeight: FontWeight.w600, fontSize: 14)),
                  Text(subtitle,
                      style: TextStyle(fontSize: 12, color: Colors.grey[500])),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: Colors.grey[400], size: 20),
          ],
        ),
      ),
    );
  }

  void _showDetailsDialog(String title, List<String> lines) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(title),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: lines
              .map((line) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Text(line),
                  ))
              .toList(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _buildDivider(bool isDark) {
    return Divider(
        height: 1,
        indent: 58,
        color: isDark ? Colors.grey[800] : Colors.grey[200]);
  }

  Widget _buildLogoutButton(SellerAuthProvider auth, bool isDark) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
      child: SizedBox(
        width: double.infinity,
        height: 50,
        child: OutlinedButton.icon(
          onPressed: () => _confirmLogout(auth),
          icon: const Icon(Icons.logout_rounded, color: Colors.red),
          label: const Text('Logout',
              style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
          style: OutlinedButton.styleFrom(
            side: const BorderSide(color: Colors.red),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          ),
        ),
      ),
    );
  }

  void _confirmLogout(SellerAuthProvider auth) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Logout?'),
        content: const Text(
            'Are you sure you want to logout from your seller account?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await FirebaseAuth.instance.signOut();
              auth.signOut();
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Logout'),
          ),
        ],
      ),
    );
  }

  void _showEditDialog() {
    final nameController = TextEditingController(
        text: _sellerData?['businessName'] ?? _sellerData?['name'] ?? '');
    final phoneController =
        TextEditingController(text: _sellerData?['phone'] ?? '');
    // SELLER-ACCOUNT-1a: `gstin` is canonical (approval + invoices);
    // `gstNumber` is the legacy key this dialog used to write.
    final gstController = TextEditingController(
        text: _sellerData?['gstin'] ?? _sellerData?['gstNumber'] ?? '');
    final cityController =
        TextEditingController(text: _sellerData?['city'] ?? '');
    final stateController =
        TextEditingController(text: _sellerData?['state'] ?? '');
    final openingTimeController =
        TextEditingController(text: _sellerData?['openingTime'] ?? '9:00 AM');
    final closingTimeController =
        TextEditingController(text: _sellerData?['closingTime'] ?? '9:00 PM');
    final radiusController = TextEditingController(
        text: (_sellerData?['deliveryRadiusKm'] ?? 10).toString());

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => Padding(
        padding: EdgeInsets.fromLTRB(
            24, 24, 24, MediaQuery.of(ctx).viewInsets.bottom + 24),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Edit Profile',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 20),
              TextField(
                  controller: nameController,
                  decoration: const InputDecoration(
                      labelText: 'Business Name',
                      border: OutlineInputBorder())),
              const SizedBox(height: 12),
              TextField(
                  controller: phoneController,
                  decoration: const InputDecoration(
                      labelText: 'Phone', border: OutlineInputBorder())),
              const SizedBox(height: 12),
              TextField(
                  controller: gstController,
                  decoration: const InputDecoration(
                      labelText: 'GST Number', border: OutlineInputBorder())),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                      child: TextField(
                          controller: cityController,
                          decoration: const InputDecoration(
                              labelText: 'City',
                              border: OutlineInputBorder()))),
                  const SizedBox(width: 12),
                  Expanded(
                      child: TextField(
                          controller: stateController,
                          decoration: const InputDecoration(
                              labelText: 'State',
                              border: OutlineInputBorder()))),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                      child: TextField(
                          controller: openingTimeController,
                          decoration: const InputDecoration(
                              labelText: 'Opening Time',
                              border: OutlineInputBorder()))),
                  const SizedBox(width: 12),
                  Expanded(
                      child: TextField(
                          controller: closingTimeController,
                          decoration: const InputDecoration(
                              labelText: 'Closing Time',
                              border: OutlineInputBorder()))),
                ],
              ),
              const SizedBox(height: 12),
              TextField(
                controller: radiusController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Delivery Radius (km)',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: FilledButton(
                  onPressed: () async {
                    final uid =
                        context.read<SellerAuthProvider>().currentUser?.uid;
                    if (uid == null) return;
                    final l10n = AppLocalizations.of(context);
                    final gst = gstController.text.trim().toUpperCase();
                    String? problem;
                    if (gst.isNotEmpty && !ApplicationRules.gstin.hasMatch(gst)) {
                      problem = l10n.errGstin;
                    }
                    if (problem == null) {
                    try {

                    await FirebaseFirestore.instance
                        .collection('sellers')
                        .doc(uid)
                        .set({
                      'businessName': nameController.text.trim(),
                      'phone': phoneController.text.trim(),
                      // Both keys, so every reader sees the edit.
                      'gstin': gst,
                      'gstNumber': gst,
                      'city': cityController.text.trim(),
                      'state': stateController.text.trim(),
                      'openingTime': openingTimeController.text.trim(),
                      'closingTime': closingTimeController.text.trim(),
                      'deliveryRadiusKm':
                          int.tryParse(radiusController.text.trim()) ?? 10,
                      'updatedAt': FieldValue.serverTimestamp(),
                    }, SetOptions(merge: true));

                    // Sync name to users collection
                    await FirebaseFirestore.instance
                        .collection('users')
                        .doc(uid)
                        .update({
                      'name': nameController.text.trim(),
                    });
                    } catch (e) {
                      debugPrint('Profile save failed: $e');
                      problem = l10n.profileSaveFailed;
                    }
                    }

                    if (mounted) {
                      if (problem == null) {
                        Navigator.pop(ctx);
                        _loadSellerProfile();
                      }
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                            content: Text(problem ?? 'Profile updated!'),
                            backgroundColor: problem == null ? Colors.green : null),
                      );
                    }
                  },
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF2D7D3C),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('Save Changes',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
