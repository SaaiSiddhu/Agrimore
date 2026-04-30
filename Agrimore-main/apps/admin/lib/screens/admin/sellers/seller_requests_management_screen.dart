import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:agrimore_ui/agrimore_ui.dart';

/// Review `sellerRequests` and approve / reject (updates `users` + optional `sellers`).
class SellerRequestsManagementScreen extends StatelessWidget {
  const SellerRequestsManagementScreen({Key? key}) : super(key: key);

  Future<void> _approve(BuildContext context, String uid, Map<String, dynamic> data) async {
    HapticFeedback.mediumImpact();
    try {
      final batch = FirebaseFirestore.instance.batch();
      final reqRef = FirebaseFirestore.instance.collection('sellerRequests').doc(uid);
      final userRef = FirebaseFirestore.instance.collection('users').doc(uid);
      final sellerRef = FirebaseFirestore.instance.collection('sellers').doc(uid);

      batch.set(
        userRef,
        {
          'sellerStatus': 'approved',
          'role': 'seller',
        },
        SetOptions(merge: true),
      );

      batch.set(
        reqRef,
        {
          'status': 'approved',
          'reviewedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );

      batch.set(
        sellerRef,
        {
          'userId': uid,
          'status': 'approved',
          'name': data['name'],
          'mobile': data['mobile'],
          'email': data['email'],
          'shopName': data['shopName'],
          'shopAddress': data['shopAddress'],
          'bankName': data['bankName'],
          'accountNumber': data['accountNumber'],
          'ifsc': data['ifsc'],
          'updatedAt': FieldValue.serverTimestamp(),
          'createdAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );

      await batch.commit();
      if (context.mounted) {
        SnackbarHelper.showSuccess(context, 'Seller approved');
      }
    } catch (e) {
      if (context.mounted) {
        SnackbarHelper.showError(context, 'Failed: $e');
      }
    }
  }

  Future<void> _reject(BuildContext context, String uid) async {
    HapticFeedback.selectionClick();
    try {
      final batch = FirebaseFirestore.instance.batch();
      batch.set(
        FirebaseFirestore.instance.collection('sellerRequests').doc(uid),
        {'status': 'rejected', 'reviewedAt': FieldValue.serverTimestamp()},
        SetOptions(merge: true),
      );
      batch.set(
        FirebaseFirestore.instance.collection('users').doc(uid),
        {'sellerStatus': 'rejected'},
        SetOptions(merge: true),
      );
      await batch.commit();
      if (context.mounted) SnackbarHelper.showInfo(context, 'Request rejected');
    } catch (e) {
      if (context.mounted) SnackbarHelper.showError(context, 'Failed: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: const Text('Seller requests'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream:
            FirebaseFirestore.instance.collection('sellerRequests').snapshots(),
        builder: (context, snap) {
          if (snap.hasError) {
            return Center(child: Text('Error: ${snap.error}'));
          }
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final docs = snap.data!.docs.toList()
            ..sort((a, b) {
              final ta = a.data()['appliedAt'];
              final tb = b.data()['appliedAt'];
              if (ta is Timestamp && tb is Timestamp) {
                return tb.toDate().compareTo(ta.toDate());
              }
              return 0;
            });
          if (docs.isEmpty) {
            return const Center(child: Text('No seller requests yet'));
          }
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: docs.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (context, i) {
              final doc = docs[i];
              final d = doc.data();
              final status = (d['status'] ?? 'pending').toString();
              final uid = doc.id;

              return Card(
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              d['shopName']?.toString() ?? 'Shop',
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 16,
                              ),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: status == 'approved'
                                  ? Colors.green.shade50
                                  : status == 'rejected'
                                      ? Colors.red.shade50
                                      : Colors.amber.shade50,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              status.toUpperCase(),
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                color: status == 'approved'
                                    ? Colors.green.shade800
                                    : status == 'rejected'
                                        ? Colors.red.shade800
                                        : Colors.amber.shade900,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text('${d['name'] ?? ''} · ${d['email'] ?? ''} · ${d['mobile'] ?? ''}'),
                      if ((d['shopAddress'] ?? '').toString().isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            d['shopAddress'].toString(),
                            style: TextStyle(color: Colors.grey.shade700, fontSize: 13),
                          ),
                        ),
                      if (status == 'pending') ...[
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            FilledButton(
                              onPressed: () => _approve(context, uid, d),
                              style: FilledButton.styleFrom(backgroundColor: Colors.green.shade700),
                              child: const Text('Approve'),
                            ),
                            const SizedBox(width: 10),
                            OutlinedButton(
                              onPressed: () => _reject(context, uid),
                              child: const Text('Reject'),
                            ),
                          ],
                        ),
                      ],
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
