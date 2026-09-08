import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:agrimore_core/agrimore_core.dart';
import 'package:agrimore_ui/agrimore_ui.dart';
import '../../providers/theme_provider.dart';
import '../user/shop/widgets/product_grid.dart';

/// BUSINESS-NETWORK-1 (slice 1 of 2): a customer-facing public profile for a
/// seller -- name/shop details + their product list. The seller's own
/// "Mini Portal" (SellerPanelScreen, apps/marketplace) is a stub with no
/// bearing on this; this is the customer's VIEW of a seller, not the
/// seller's own management UI (that lives in apps/seller).
///
/// Reads `sellers/{sellerId}` directly (firestore.rules: `allow read: if
/// true`, confirmed at claim time -- no rules change needed for this
/// screen) and `products` filtered by `sellerId`. Follow/unfollow is
/// BUSINESS-NETWORK-1's own WS2, not yet wired here.
class BusinessProfileScreen extends StatefulWidget {
  final String sellerId;

  const BusinessProfileScreen({Key? key, required this.sellerId})
      : super(key: key);

  @override
  State<BusinessProfileScreen> createState() => _BusinessProfileScreenState();
}

class _BusinessProfileScreenState extends State<BusinessProfileScreen> {
  Map<String, dynamic>? _seller;
  List<ProductModel> _products = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final sellerDoc = await FirebaseFirestore.instance
          .collection('sellers')
          .doc(widget.sellerId)
          .get();

      final productsSnap = await FirebaseFirestore.instance
          .collection('products')
          .where('sellerId', isEqualTo: widget.sellerId)
          .limit(60)
          .get();

      if (!mounted) return;
      setState(() {
        _seller = sellerDoc.exists ? sellerDoc.data() : null;
        _products =
            productsSnap.docs.map((d) => ProductModel.fromFirestore(d)).toList();
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDark = themeProvider.isDarkMode;
    final accentColor = isDark ? AppColors.primaryLight : AppColors.primary;
    final shopName = (_seller?['shopName'] as String?)?.trim();
    final shopAddress = (_seller?['shopAddress'] as String?)?.trim();

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF121212) : Colors.grey[50],
      appBar: AppBar(
        title: Text(shopName?.isNotEmpty == true ? shopName! : 'Business Profile'),
        backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        foregroundColor: isDark ? Colors.white : Colors.black87,
        elevation: 0,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      'Could not load this business profile.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: isDark ? Colors.white70 : Colors.black54),
                    ),
                  ),
                )
              : _seller == null
                  ? Center(
                      child: Text(
                        'This business could not be found.',
                        style: TextStyle(color: isDark ? Colors.white70 : Colors.black54),
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: _load,
                      child: ListView(
                        children: [
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(20),
                            color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    CircleAvatar(
                                      radius: 28,
                                      backgroundColor: accentColor.withValues(alpha: 0.1),
                                      child: Icon(Icons.storefront, color: accentColor, size: 28),
                                    ),
                                    const SizedBox(width: 14),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            shopName?.isNotEmpty == true ? shopName! : 'Business Profile',
                                            style: TextStyle(
                                              fontSize: 18,
                                              fontWeight: FontWeight.w800,
                                              color: isDark ? Colors.white : Colors.black87,
                                            ),
                                          ),
                                          if (shopAddress?.isNotEmpty == true) ...[
                                            const SizedBox(height: 4),
                                            Text(
                                              shopAddress!,
                                              style: TextStyle(
                                                fontSize: 13,
                                                color: isDark ? Colors.grey[400] : Colors.grey[600],
                                              ),
                                            ),
                                          ],
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 12),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            child: Text(
                              'Products (${_products.length})',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                color: isDark ? Colors.white : Colors.black87,
                              ),
                            ),
                          ),
                          if (_products.isEmpty)
                            Padding(
                              padding: const EdgeInsets.all(32),
                              child: Center(
                                child: Text(
                                  'No products yet.',
                                  style: TextStyle(color: isDark ? Colors.white54 : Colors.black45),
                                ),
                              ),
                            )
                          else
                            ProductGrid(products: _products),
                          const SizedBox(height: 24),
                        ],
                      ),
                    ),
    );
  }
}
