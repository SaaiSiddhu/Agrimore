// lib/screens/admin/reviews/review_management_screen.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:agrimore_ui/agrimore_ui.dart';

class ReviewManagementScreen extends StatefulWidget {
  const ReviewManagementScreen({Key? key}) : super(key: key);

  @override
  State<ReviewManagementScreen> createState() => _ReviewManagementScreenState();
}

class _ReviewManagementScreenState extends State<ReviewManagementScreen> {
  final _firestore = FirebaseFirestore.instance;
  int _filterStars = 0; // 0 = all
  String _sortBy = 'newest';

  Query _buildQuery() => _firestore.collectionGroup('reviews').limit(200);

  List<QueryDocumentSnapshot> _filterAndSortReviews(List<QueryDocumentSnapshot> docs) {
    final filtered = docs.where((doc) {
      if (_filterStars == 0) return true;
      final data = doc.data() as Map<String, dynamic>;
      return (data['rating'] as num?)?.toInt() == _filterStars;
    }).toList();

    DateTime createdAt(QueryDocumentSnapshot doc) {
      final data = doc.data() as Map<String, dynamic>;
      final raw = data['createdAt'];
      if (raw is Timestamp) return raw.toDate();
      if (raw is DateTime) return raw;
      if (raw is String) return DateTime.tryParse(raw) ?? DateTime.fromMillisecondsSinceEpoch(0);
      return DateTime.fromMillisecondsSinceEpoch(0);
    }

    int rating(QueryDocumentSnapshot doc) {
      final data = doc.data() as Map<String, dynamic>;
      return (data['rating'] as num?)?.toInt() ?? 0;
    }

    filtered.sort((a, b) {
      switch (_sortBy) {
        case 'oldest':
          return createdAt(a).compareTo(createdAt(b));
        case 'highest':
          return rating(b).compareTo(rating(a));
        case 'lowest':
          return rating(a).compareTo(rating(b));
        case 'newest':
        default:
          return createdAt(b).compareTo(createdAt(a));
      }
    });
    return filtered.take(50).toList();
  }

  void _showFilterSheet() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Filter Reviews', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 20),
              const Text('Star Rating', style: TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: [
                  _filterChip('All', 0, setModalState),
                  for (int i = 5; i >= 1; i--) _filterChip('$i ★', i, setModalState),
                ],
              ),
              const SizedBox(height: 20),
              const Text('Sort By', style: TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: [
                  _sortChip('Newest', 'newest', setModalState),
                  _sortChip('Oldest', 'oldest', setModalState),
                  _sortChip('Highest', 'highest', setModalState),
                  _sortChip('Lowest', 'lowest', setModalState),
                ],
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pop(ctx);
                    setState(() {}); // rebuild with new filters
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('Apply Filters', style: TextStyle(fontWeight: FontWeight.w700)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _filterChip(String label, int stars, StateSetter setModalState) {
    final isSelected = _filterStars == stars;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      selectedColor: AppColors.primary.withOpacity(0.2),
      onSelected: (_) => setModalState(() => _filterStars = stars),
    );
  }

  Widget _sortChip(String label, String value, StateSetter setModalState) {
    final isSelected = _sortBy == value;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      selectedColor: AppColors.primary.withOpacity(0.2),
      onSelected: (_) => setModalState(() => _sortBy = value),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Customer Feedback & Reviews'),
        backgroundColor: AppColors.primary,
        actions: [
          IconButton(
            icon: Badge(
              isLabelVisible: _filterStars > 0,
              child: const Icon(Icons.filter_list),
            ),
            onPressed: _showFilterSheet,
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: _buildQuery().snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final docs = snapshot.hasData ? _filterAndSortReviews(snapshot.data!.docs) : <QueryDocumentSnapshot>[];
          if (docs.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.rate_review_outlined, size: 100, color: Colors.grey.shade400),
                  const SizedBox(height: 16),
                  Text(
                    _filterStars > 0 ? 'No $_filterStars-star reviews found.' : 'No reviews yet.',
                    style: const TextStyle(fontSize: 16, color: Colors.grey),
                  ),
                ],
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: docs.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final doc = docs[index];
              final data = doc.data() as Map<String, dynamic>;
              final rating = (data['rating'] as num?)?.toInt() ?? 0;
              final comment = data['comment'] ?? '';
              final userName = data['userName'] ?? 'Anonymous';
              final productName = data['productName'] ?? 'Unknown Product';

              return Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10, offset: const Offset(0, 2))],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        CircleAvatar(
                          backgroundColor: AppColors.primary.withOpacity(0.1),
                          child: Text(userName.substring(0, 1).toUpperCase(), style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold)),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(userName, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
                              Text(productName, style: const TextStyle(fontSize: 12, color: Colors.grey)),
                            ],
                          ),
                        ),
                        Row(
                          children: List.generate(5, (i) => Icon(
                            i < rating ? Icons.star_rounded : Icons.star_border_rounded,
                            color: i < rating ? Colors.amber : Colors.grey.shade300,
                            size: 20,
                          )),
                        ),
                      ],
                    ),
                    if (comment.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      Text(comment, style: const TextStyle(fontSize: 14, color: Colors.black87, height: 1.4)),
                    ],
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}
