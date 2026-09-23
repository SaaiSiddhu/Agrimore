// lib/screens/admin/delivery/delivery_partner_management_screen.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:agrimore_ui/agrimore_ui.dart';
import '../../../app/themes/admin_colors.dart';
import 'add_delivery_partner_dialog.dart';
import 'rider_review_sheet.dart';

/// Phase DLV-1B: which onboarding tab a partner belongs in.
enum _ReviewTab { pending, approved, blocked }

/// A partner as listed here: the model for display, plus the RAW document —
/// DeliveryPartnerModel.fromMap defaults a missing `status` to 'approved',
/// while the delivery app and roleClaims.ts treat it as pending. The raw
/// value (via RiderKycStatus) decides the tab.
class _PartnerEntry {
  _PartnerEntry(this.id, this.data)
      : model = DeliveryPartnerModel.fromMap(data, id),
        status = RiderKycStatus.fromWire(data['status'] as String?),
        statusMissing = (data['status'] as String?)?.trim().isEmpty ?? true;

  final String id;
  final Map<String, dynamic> data;
  final DeliveryPartnerModel model;
  final RiderKycStatus status;
  final bool statusMissing;

  _ReviewTab get tab => switch (status) {
        RiderKycStatus.pending => _ReviewTab.pending,
        RiderKycStatus.approved => _ReviewTab.approved,
        _ => _ReviewTab.blocked,
      };
}

class DeliveryPartnerManagementScreen extends StatefulWidget {
  const DeliveryPartnerManagementScreen({super.key});

  @override
  State<DeliveryPartnerManagementScreen> createState() =>
      _DeliveryPartnerManagementScreenState();
}

class _DeliveryPartnerManagementScreenState
    extends State<DeliveryPartnerManagementScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final TextEditingController _searchController = TextEditingController();

  List<_PartnerEntry> _partners = [];
  bool _isLoading = true;
  bool _loadFailed = false;
  String _filter = 'all'; // all, online, offline — Approved tab only
  // Open on Pending when anyone is waiting (set once, on first load).
  _ReviewTab _tab = _ReviewTab.approved;
  bool _tabChosen = false;
  StreamSubscription? _subscription;

  @override
  void initState() {
    super.initState();
    _loadPartners();
  }

  void _loadPartners() {
    _subscription?.cancel();
    _subscription = _firestore
        .collection('delivery_partners')
        .orderBy('name')
        .snapshots()
        .listen((snapshot) {
      if (!mounted) return;
      setState(() {
        _partners = snapshot.docs
            .map((doc) => _PartnerEntry(doc.id, doc.data()))
            .toList();
        _isLoading = false;
        _loadFailed = false;
        if (!_tabChosen) {
          _tabChosen = true;
          if (_partners.any((p) => p.tab == _ReviewTab.pending)) {
            _tab = _ReviewTab.pending;
          }
        }
      });
    }, onError: (Object e) {
      debugPrint('Delivery partners load failed: $e');
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _loadFailed = true;
      });
    });
  }

  int _count(_ReviewTab tab) => _partners.where((p) => p.tab == tab).length;

  List<_PartnerEntry> get _filteredPartners {
    var list = _partners.where((p) => p.tab == _tab).toList();

    // Search filter
    if (_searchController.text.isNotEmpty) {
      final query = _searchController.text.toLowerCase();
      list = list
          .where((p) =>
              p.model.name.toLowerCase().contains(query) ||
              p.model.phone.contains(query) ||
              p.model.vehicleNumber.toLowerCase().contains(query))
          .toList();
    }

    // Online filter (only meaningful for approved partners)
    if (_tab == _ReviewTab.approved) {
      if (_filter == 'online') {
        list = list.where((p) => p.model.isOnline).toList();
      } else if (_filter == 'offline') {
        list = list.where((p) => !p.model.isOnline).toList();
      }
    }

    return list;
  }

  @override
  void dispose() {
    _subscription?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final onlineCount = _partners
        .where((p) => p.tab == _ReviewTab.approved && p.model.isOnline)
        .length;

    return Scaffold(
      backgroundColor: AdminColors.background,
      body: Column(
        children: [
          // Header
          _buildHeader(onlineCount),

          // Search & Filter
          _buildSearchRow(),

          // Partner List
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _loadFailed
                    ? _buildLoadFailed()
                    : _filteredPartners.isEmpty
                        ? _buildEmptyState()
                        : _buildPartnerList(),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddPartnerDialog,
        backgroundColor: AdminColors.primary,
        icon: const Icon(Icons.person_add_rounded, color: Colors.white),
        label: const Text('Add Partner',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
      ),
    );
  }

  Widget _buildHeader(int onlineCount) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AdminColors.cardBackground,
        border: Border(bottom: BorderSide(color: AdminColors.border)),
      ),
      child: Row(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Delivery Partners',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  color: AdminColors.textPrimary,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '${_partners.length} total • ${_count(_ReviewTab.pending)} awaiting review • $onlineCount online',
                style: TextStyle(
                  fontSize: 13,
                  color: AdminColors.textSecondary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSearchRow() {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Search
          TextField(
            controller: _searchController,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              hintText: 'Search by name, phone, or vehicle...',
              prefixIcon: const Icon(Icons.search),
              filled: true,
              fillColor: AdminColors.cardBackground,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: AdminColors.border),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: AdminColors.border),
              ),
            ),
          ),
          const SizedBox(height: 12),
          // Onboarding tabs (DLV-1B)
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _buildTabChip('Pending', _ReviewTab.pending),
              _buildTabChip('Approved', _ReviewTab.approved),
              _buildTabChip('Rejected / Suspended', _ReviewTab.blocked),
            ],
          ),
          if (_tab == _ReviewTab.approved) ...[
            const SizedBox(height: 8),
            // Filter Chips
            Wrap(
              spacing: 8,
              children: [
                _buildFilterChip('All', 'all'),
                _buildFilterChip('Online', 'online'),
                _buildFilterChip('Offline', 'offline'),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildTabChip(String label, _ReviewTab tab) {
    final isSelected = _tab == tab;
    return ChoiceChip(
      label: Text('$label (${_count(tab)})'),
      selected: isSelected,
      onSelected: (_) => setState(() => _tab = tab),
      selectedColor: AdminColors.primary,
      labelStyle: TextStyle(
        fontWeight: FontWeight.w700,
        color: isSelected ? AdminColors.white : AdminColors.textSecondary,
      ),
      showCheckmark: false,
    );
  }

  Widget _buildLoadFailed() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.cloud_off_rounded,
              size: 56, color: AdminColors.textSecondary),
          const SizedBox(height: 12),
          const Text('Could not load delivery partners',
              style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AdminColors.textPrimary)),
          const SizedBox(height: 12),
          OutlinedButton(
              onPressed: _loadPartners, child: const Text('Try again')),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, String value) {
    final isSelected = _filter == value;
    return FilterChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (_) => setState(() => _filter = value),
      selectedColor: AdminColors.primary.withValues(alpha: 0.2),
      checkmarkColor: AdminColors.primary,
      labelStyle: TextStyle(
        fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
        color: isSelected ? AdminColors.primary : AdminColors.textSecondary,
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.delivery_dining_rounded,
              size: 64, color: AdminColors.textSecondary),
          const SizedBox(height: 16),
          Text(
            switch (_tab) {
              _ReviewTab.pending => 'No applications waiting',
              _ReviewTab.approved => 'No approved delivery partners',
              _ReviewTab.blocked => 'No rejected or suspended partners',
            },
            style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: AdminColors.textPrimary),
          ),
          const SizedBox(height: 8),
          Text(
            _tab == _ReviewTab.pending
                ? 'New sign-ups from the delivery app appear here for review'
                : 'Add partners to start assigning orders',
            style: TextStyle(color: AdminColors.textSecondary),
          ),
        ],
      ),
    );
  }

  Widget _buildPartnerList() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _filteredPartners.length,
      itemBuilder: (context, index) {
        final entry = _filteredPartners[index];
        return _PartnerCard(
          partner: entry.model,
          status: entry.status,
          statusMissing: entry.statusMissing,
          onTap: () => _openReview(entry),
          onDelete: () => _deletePartner(entry.id),
        );
      },
    );
  }

  void _openReview(_PartnerEntry entry) {
    DialogHelper.showBottomSheet<void>(
      context,
      child: RiderReviewSheet(uid: entry.id, data: entry.data),
    );
  }

  void _showAddPartnerDialog() {
    showDialog(
      context: context,
      builder: (context) => const AddDeliveryPartnerDialog(),
    );
  }

  void _deletePartner(String id) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Partner'),
        content: const Text(
            'Are you sure you want to delete this delivery partner?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await _firestore.collection('delivery_partners').doc(id).delete();
              // Also update user role
              await _firestore
                  .collection('users')
                  .doc(id)
                  .update({'role': 'user'});
            },
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}

class _PartnerCard extends StatelessWidget {
  final DeliveryPartnerModel partner;
  final RiderKycStatus status;
  final bool statusMissing;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const _PartnerCard({
    required this.partner,
    required this.status,
    required this.statusMissing,
    required this.onTap,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AdminColors.cardBackground,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AdminColors.border),
        ),
        child: Row(
          children: [
            // Avatar with online indicator
            Stack(
              children: [
                CircleAvatar(
                  radius: 24,
                  backgroundColor: AdminColors.primary.withValues(alpha: 0.1),
                  backgroundImage: partner.photoUrl != null
                      ? NetworkImage(partner.photoUrl!)
                      : null,
                  child: partner.photoUrl == null
                      ? Text(
                          partner.name.isNotEmpty
                              ? partner.name[0].toUpperCase()
                              : 'P',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            color: AdminColors.primary,
                          ),
                        )
                      : null,
                ),
                Positioned(
                  right: 0,
                  bottom: 0,
                  child: Container(
                    width: 14,
                    height: 14,
                    decoration: BoxDecoration(
                      color: partner.isOnline ? Colors.green : Colors.grey,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(width: 16),

            // Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Text(
                        partner.name,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: AdminColors.textPrimary,
                        ),
                      ),
                      RiderStatusBadge(status: status, missing: statusMissing),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(Icons.phone_outlined,
                          size: 14, color: AdminColors.textSecondary),
                      const SizedBox(width: 4),
                      Text(partner.phone,
                          style: TextStyle(
                              fontSize: 12, color: AdminColors.textSecondary)),
                      const SizedBox(width: 16),
                      Icon(
                        partner.vehicleType == 'ev'
                            ? Icons.electric_moped
                            : Icons.two_wheeler,
                        size: 14,
                        color: AdminColors.textSecondary,
                      ),
                      const SizedBox(width: 4),
                      Text(partner.vehicleNumber,
                          style: TextStyle(
                              fontSize: 12, color: AdminColors.textSecondary)),
                    ],
                  ),
                ],
              ),
            ),

            // Stats
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Row(
                  children: [
                    Icon(Icons.star_rounded, size: 16, color: Colors.amber),
                    const SizedBox(width: 4),
                    Text(
                      partner.formattedRating,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ],
                ),
                Text(
                  '${partner.totalDeliveries} deliveries',
                  style:
                      TextStyle(fontSize: 11, color: AdminColors.textSecondary),
                ),
              ],
            ),

            const SizedBox(width: 12),

            // Delete button
            IconButton(
              onPressed: onDelete,
              icon: const Icon(Icons.delete_outline, color: Colors.red),
              tooltip: 'Delete Partner',
            ),
          ],
        ),
      ),
    );
  }
}
