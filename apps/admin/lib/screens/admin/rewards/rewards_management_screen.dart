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
                  // ADMR-9: this configuration is not yet read by any
                  // automated issuance process — grepped fresh across
                  // functions/src/** and apps/**: zero consumers of
                  // scratchMinOrder/scratchWinProbability/scratchMaxReward
                  // anywhere. scratchCards/{cardId} documents are
                  // admin-seeded only (firestore.rules: allow create: if
                  // false) and claimScratchCard.ts only ever CLAIMS an
                  // already-existing card — nothing in this codebase creates
                  // one. Saving these values changes nothing live yet; this
                  // banner says so honestly rather than implying a working
                  // "X% of orders over ₹Y win a card" mechanic that does not
                  // exist. Building that mechanic is a real, undecided
                  // product/timing question (per-order? per-day? interaction
                  // with benefit_program?) out of scope for this phase.
                  Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.amber.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.amber.shade700, width: 1),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.info_outline_rounded, size: 18, color: Colors.amber.shade900),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Not yet connected to live behaviour: no automated process currently issues scratch cards to orders. These values are saved but have no effect until that is built.',
                            style: TextStyle(fontSize: 12, color: Colors.amber.shade900),
                          ),
                        ),
                      ],
                    ),
                  ),
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

                  // ADMR-9: this screen used to have its own "Referral Bonus
                  // Structure" section here, writing a referrer/referee coin
                  // pair into settings/rewards — a full duplicate of
                  // Settings > Wallet Settings, which writes the differently
                  // -named fields functions/src/customer/wallet.ts's
                  // applyReferralCode actually reads, into a different
                  // document (settings/wallet_config, confirmed by reading
                  // that function directly). The duplicate wrote to a
                  // document nothing consumed, so editing it here had zero
                  // effect on real referral bonuses while looking exactly
                  // like it
                  // worked. Removed rather than fixed in place, since a
                  // correct, working editor for this exact value already
                  // exists — this note replaces it so an admin who
                  // remembers this section still finds the real one.
                  Container(
                    margin: const EdgeInsets.only(bottom: 24),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.blue.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.blue.shade200, width: 1),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.groups_outlined, size: 18, color: Colors.blue.shade800),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Referral bonus amounts are configured in Settings → Wallet Settings, not here.',
                            style: TextStyle(fontSize: 12, color: Colors.blue.shade800),
                          ),
                        ),
                      ],
                    ),
                  ),

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
