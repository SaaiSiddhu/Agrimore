import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:agrimore_ui/agrimore_ui.dart';
import 'package:agrimore_core/agrimore_core.dart';
import 'package:intl/intl.dart';

class SellerProductApprovalScreen extends StatefulWidget {
  const SellerProductApprovalScreen({Key? key}) : super(key: key);

  @override
  State<SellerProductApprovalScreen> createState() => _SellerProductApprovalScreenState();
}

class _SellerProductApprovalScreenState extends State<SellerProductApprovalScreen> {
  Future<void> _updateProductVerification(BuildContext context, String productId, bool isVerified) async {
    try {
      await FirebaseFirestore.instance.collection('products').doc(productId).update({
        'isVerified': isVerified,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      if (context.mounted) {
        SnackbarHelper.showSuccess(context, isVerified ? 'Product Approved' : 'Product Disapproved');
      }
    } catch (e) {
      if (context.mounted) {
        SnackbarHelper.showError(context, 'Failed to update product: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: const Text('Seller Products Approval'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('products')
            .where('sellerId', isNotEqualTo: '') // Only fetch products that have a sellerId
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final products = snapshot.data!.docs
              .map((doc) => ProductModel.fromFirestore(doc))
              .where((p) => p.sellerId.isNotEmpty)
              .toList();
              
          products.sort((a, b) => b.createdAt.compareTo(a.createdAt));

          if (products.isEmpty) {
            return const Center(child: Text('No seller products found.'));
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: products.length,
            itemBuilder: (context, index) {
              final product = products[index];
              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(8),
                          color: Colors.grey.shade200,
                          image: product.primaryImage.isNotEmpty
                              ? DecorationImage(
                                  image: NetworkImage(product.primaryImage),
                                  fit: BoxFit.cover,
                                )
                              : null,
                        ),
                        child: product.primaryImage.isEmpty
                            ? const Icon(Icons.image_not_supported, color: Colors.grey)
                            : null,
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              product.name,
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Seller ID: ${product.sellerId}',
                              style: const TextStyle(fontSize: 12, color: Colors.grey),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '₹${product.salePrice.toStringAsFixed(2)} • Stock: ${product.stock}',
                              style: TextStyle(
                                fontSize: 13,
                                color: AppColors.primary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Location: ${product.location.isNotEmpty ? product.location : "Not specified"}',
                              style: const TextStyle(fontSize: 12, color: Colors.grey),
                            ),
                          ],
                        ),
                      ),
                      Column(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: product.isVerified ? Colors.green.shade50 : Colors.orange.shade50,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              product.isVerified ? 'APPROVED' : 'PENDING',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: product.isVerified ? Colors.green.shade700 : Colors.orange.shade700,
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Switch(
                            value: product.isVerified,
                            activeColor: Colors.green,
                            onChanged: (val) => _updateProductVerification(context, product.id, val),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
