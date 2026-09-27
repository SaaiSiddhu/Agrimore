import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:go_router/go_router.dart';
import 'package:agrimore_ui/agrimore_ui.dart';
import '../../../app/app_router.dart';

/// Browse approved sellers and open one's Seller 360 (ADMR-57).
/// Query matches the existing `sellers(status ASC, createdAt ASC)` composite
/// index (firestore.indexes.json) — no index change needed.
class ManageSellersScreen extends StatelessWidget {
  const ManageSellersScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: const Text('Manage sellers'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance
            .collection('sellers')
            .where('status', isEqualTo: 'approved')
            .orderBy('createdAt', descending: true)
            .snapshots(),
        builder: (context, snap) {
          if (snap.hasError) {
            return Center(child: Text('Error: ${snap.error}'));
          }
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final docs = snap.data!.docs;
          if (docs.isEmpty) {
            return const Center(child: Text('No approved sellers yet'));
          }
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: docs.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (context, i) {
              final doc = docs[i];
              final d = doc.data();
              final logoUrl = (d['logoUrl'] as String?)?.trim();
              return Card(
                child: ListTile(
                  contentPadding: const EdgeInsets.all(12),
                  leading: CircleAvatar(
                    radius: 24,
                    backgroundColor: AppColors.primary.withOpacity(0.1),
                    backgroundImage:
                        (logoUrl != null && logoUrl.isNotEmpty) ? NetworkImage(logoUrl) : null,
                    child: (logoUrl == null || logoUrl.isEmpty)
                        ? const Icon(Icons.storefront_rounded, color: AppColors.primary)
                        : null,
                  ),
                  title: Text(
                    d['shopName']?.toString() ?? 'Shop',
                    style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
                  ),
                  subtitle: Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('${d['name'] ?? ''} · ${d['email'] ?? ''} · ${d['mobile'] ?? ''}'),
                        if ((d['shopAddress'] ?? '').toString().isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 2),
                            child: Text(
                              d['shopAddress'].toString(),
                              style: TextStyle(color: Colors.grey.shade700, fontSize: 12),
                            ),
                          ),
                      ],
                    ),
                  ),
                  isThreeLine: (d['shopAddress'] ?? '').toString().isNotEmpty,
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () =>
                      context.push(AdminRoutes.sellerDetail.replaceFirst(':id', doc.id)),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
