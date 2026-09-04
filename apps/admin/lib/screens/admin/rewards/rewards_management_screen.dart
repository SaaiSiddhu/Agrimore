// lib/screens/admin/rewards/rewards_management_screen.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:agrimore_ui/agrimore_ui.dart';

class RewardsManagementScreen extends StatefulWidget {
  const RewardsManagementScreen({Key? key}) : super(key: key);

  @override
  State<RewardsManagementScreen> createState() => _RewardsManagementScreenState();
}

class _RewardsManagementScreenState extends State<RewardsManagementScreen> {
  final _firestore = FirebaseFirestore.instance;

  // Scratch card config
  double _scratchMinOrder = 200;
  double _scratchWinProbability = 30;
  double _scratchMaxReward = 50;

  // Referral config
  int _referrerCoins = 100;
  int _refereeCoins = 50;

  bool _isLoading = true;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _loadConfig();
  }

  Future<void> _loadConfig() async {
    try {
      final doc = await _firestore.collection('settings').doc('rewards').get();
      if (doc.exists) {
        final data = doc.data()!;
        setState(() {
          _scratchMinOrder = (data['scratchMinOrder'] as num?)?.toDouble() ?? 200;
          _scratchWinProbability = (data['scratchWinProbability'] as num?)?.toDouble() ?? 30;
          _scratchMaxReward = (data['scratchMaxReward'] as num?)?.toDouble() ?? 50;
          _referrerCoins = (data['referrerCoins'] as num?)?.toInt() ?? 100;
          _refereeCoins = (data['refereeCoins'] as num?)?.toInt() ?? 50;
        });
      }
    } catch (_) {}
    if (mounted) setState(() => _isLoading = false);
  }

  Future<void> _saveConfig() async {
    setState(() => _isSaving = true);
    try {
      await _firestore.collection('settings').doc('rewards').set({
        'scratchMinOrder': _scratchMinOrder,
        'scratchWinProbability': _scratchWinProbability,
        'scratchMaxReward': _scratchMaxReward,
        'referrerCoins': _referrerCoins,
        'refereeCoins': _refereeCoins,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Rewards configuration saved!'), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving: $e'), backgroundColor: Colors.red),
        );
      }
    }
    if (mounted) setState(() => _isSaving = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Gamification & Rewards'),
        backgroundColor: AppColors.primary,
        actions: [
          if (_isSaving)
            const Padding(
              padding: EdgeInsets.all(16),
              child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)),
            )
          else
            IconButton(icon: const Icon(Icons.save_rounded), onPressed: _saveConfig),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Scratch Card Section
                  _buildSectionHeader('Scratch Card Distribution', Icons.card_giftcard),
                  const SizedBox(height: 12),
                  _buildConfigCard([
                    _buildSliderTile(
                      'Minimum Order Value',
                      '₹${_scratchMinOrder.toInt()}',
                      _scratchMinOrder, 50, 1000,
                      (v) => setState(() => _scratchMinOrder = v),
                    ),
                    const Divider(height: 1),
                    _buildSliderTile(
                      'Winning Probability',
                      '${_scratchWinProbability.toInt()}%',
                      _scratchWinProbability, 5, 100,
                      (v) => setState(() => _scratchWinProbability = v),
                    ),
                    const Divider(height: 1),
                    _buildSliderTile(
                      'Max Reward Per Card',
                      '₹${_scratchMaxReward.toInt()}',
                      _scratchMaxReward, 5, 500,
                      (v) => setState(() => _scratchMaxReward = v),
                    ),
                  ]),
                  const SizedBox(height: 24),

                  // Referral Section
                  _buildSectionHeader('Referral Bonus Structure', Icons.groups),
                  const SizedBox(height: 12),
                  _buildConfigCard([
                    _buildNumberTile(
                      'Referrer Coins',
                      'Coins given to the person who refers',
                      _referrerCoins,
                      (v) => setState(() => _referrerCoins = v),
                    ),
                    const Divider(height: 1),
                    _buildNumberTile(
                      'Referee Coins',
                      'Coins given to the new user who was referred',
                      _refereeCoins,
                      (v) => setState(() => _refereeCoins = v),
                    ),
                  ]),
                  const SizedBox(height: 24),

                  // Active Campaigns (from Firestore)
                  _buildSectionHeader('Wallet Top-Up Activity', Icons.account_balance_wallet),
                  const SizedBox(height: 12),
                  _buildRecentWalletActivity(),
                  const SizedBox(height: 32),

                  // Save button
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton.icon(
                      onPressed: _isSaving ? null : _saveConfig,
                      icon: const Icon(Icons.save_rounded),
                      label: Text(_isSaving ? 'Saving...' : 'Save Configuration'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(color: AppColors.primary.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
          child: Icon(icon, color: AppColors.primary, size: 20),
        ),
        const SizedBox(width: 12),
        Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
      ],
    );
  }

  Widget _buildConfigCard(List<Widget> children) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 2))],
      ),
      child: Column(children: children),
    );
  }

  Widget _buildSliderTile(String title, String valueText, double value, double min, double max, ValueChanged<double> onChanged) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(color: AppColors.primary.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                child: Text(valueText, style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.primary)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Slider(
            value: value, min: min, max: max,
            activeColor: AppColors.primary,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }

  Widget _buildNumberTile(String title, String subtitle, int value, ValueChanged<int> onChanged) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
      subtitle: Text(subtitle, style: const TextStyle(fontSize: 12, color: Colors.grey)),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: const Icon(Icons.remove_circle_outline),
            color: Colors.red,
            onPressed: () { if (value > 0) onChanged(value - 10); },
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(color: AppColors.primary.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
            child: Text('$value', style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.primary, fontSize: 16)),
          ),
          IconButton(
            icon: const Icon(Icons.add_circle_outline),
            color: AppColors.primary,
            onPressed: () => onChanged(value + 10),
          ),
        ],
      ),
    );
  }

  Widget _buildRecentWalletActivity() {
    return StreamBuilder<QuerySnapshot>(
      stream: _firestore.collection('wallet_transactions').orderBy('createdAt', descending: true).limit(5).snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: Padding(padding: EdgeInsets.all(24), child: CircularProgressIndicator()));
        }
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
            child: const Center(child: Text('No recent wallet activity.', style: TextStyle(color: Colors.grey))),
          );
        }
        return Container(
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
          child: Column(
            children: snapshot.data!.docs.map((doc) {
              final d = doc.data() as Map<String, dynamic>;
              final type = d['type'] ?? 'unknown';
              final amount = (d['amount'] as num?)?.toDouble() ?? 0;
              return ListTile(
                leading: CircleAvatar(
                  backgroundColor: amount > 0 ? Colors.green.withOpacity(0.1) : Colors.red.withOpacity(0.1),
                  child: Icon(amount > 0 ? Icons.arrow_downward : Icons.arrow_upward, color: amount > 0 ? Colors.green : Colors.red, size: 18),
                ),
                title: Text(type.toString().toUpperCase(), style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                trailing: Text('${amount > 0 ? '+' : ''}₹${amount.abs().toStringAsFixed(0)}',
                    style: TextStyle(fontWeight: FontWeight.bold, color: amount > 0 ? Colors.green : Colors.red)),
              );
            }).toList(),
          ),
        );
      },
    );
  }
}
