import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:url_launcher/url_launcher.dart';
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
      // Phase FIX-2 (finding N-2, P0). `sellers/{uid}` is `allow read: if true`
      // in firestore.rules — deliberately public, because the marketplace
      // storefront shows seller profiles to logged-out visitors. Copying the
      // payout fields into it, as this screen used to, published every approved
      // seller's bank account number and IFSC to anyone who knew the project id.
      // They go here instead: read owner-or-admin, write admin-only.
      final payoutRef =
          FirebaseFirestore.instance.collection('seller_payout_details').doc(uid);

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

      // SELLER-AUTH-1b: the in-app application carries more than the old
      // form — copy the public business fields (never payout/KYC) into the
      // public profile. Fields absent on legacy requests are simply skipped.
      const publicFields = [
        'businessCategory', 'gstin', 'city', 'state', 'pincode',
        'deliveryRadiusKm', 'latitude', 'longitude',
      ];
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
          for (final f in publicFields)
            if (data[f] != null && data[f] != '') f: data[f],
          'updatedAt': FieldValue.serverTimestamp(),
          'createdAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );

      // Payout data, in the non-public collection. Written in the SAME batch as
      // the approval itself so a seller can never end up approved without their
      // payout details, or vice versa — the two writes commit atomically or not
      // at all, exactly as they did when both lived in `sellers/{uid}`.
      batch.set(
        payoutRef,
        {
          'sellerId': uid,
          'payoutMethod': data['payoutMethod'] ?? 'bank',
          'accountHolder': data['accountHolder'],
          'bankName': data['bankName'],
          'accountNumber': data['accountNumber'],
          'ifsc': data['ifsc'],
          'upiId': data['upiId'],
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
          // SELLER-AUTH-1b: drafts are unfinished applications — not for review.
          final docs = snap.data!.docs.where((d) => d.data()['status'] != 'draft').toList()
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
                      _ApplicationDetails(uid: uid, data: d),
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

/// SELLER-AUTH-1b: the extra application fields and KYC photos an admin needs
/// before approving. Photos open via a short-lived download URL (storage.rules:
/// seller_documents/{uid}/ is owner + admin read only).
class _ApplicationDetails extends StatelessWidget {
  const _ApplicationDetails({required this.uid, required this.data});
  final String uid;
  final Map<String, dynamic> data;

  Future<void> _openDocument(BuildContext context, String path) async {
    try {
      final url = await FirebaseStorage.instance.ref(path).getDownloadURL();
      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    } catch (e) {
      if (context.mounted) SnackbarHelper.showError(context, 'Could not open document: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final lines = <String>[
      if ((data['businessCategory'] ?? '').toString().isNotEmpty) 'Sells: ${data['businessCategory']}',
      if ((data['gstin'] ?? '').toString().isNotEmpty) 'GSTIN: ${data['gstin']}',
      if ((data['city'] ?? '').toString().isNotEmpty)
        '${data['city']}, ${data['state'] ?? ''} ${data['pincode'] ?? ''}',
      if (data['deliveryRadiusKm'] != null) 'Delivery radius: ${data['deliveryRadiusKm']} km',
      if (data['payoutMethod'] == 'upi') 'Payout: UPI ${data['upiId'] ?? ''}',
      if (data['payoutMethod'] == 'bank')
        'Payout: ${data['bankName'] ?? ''} · ${data['ifsc'] ?? ''} · ${data['accountHolder'] ?? ''}',
    ];
    final docs = (data['documents'] as Map?)?.cast<String, dynamic>() ?? const {};
    if (lines.isEmpty && docs.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final l in lines) Text(l, style: TextStyle(color: Colors.grey.shade800, fontSize: 13)),
          if (docs.isNotEmpty)
            Wrap(
              spacing: 8,
              children: [
                for (final e in docs.entries)
                  if (e.value is String)
                    TextButton.icon(
                      onPressed: () => _openDocument(context, e.value as String),
                      icon: const Icon(Icons.image_outlined, size: 18),
                      label: Text(e.key),
                    ),
              ],
            ),
        ],
      ),
    );
  }
}
