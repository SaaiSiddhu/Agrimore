import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class RewardsScreen extends StatefulWidget {
  const RewardsScreen({Key? key}) : super(key: key);

  @override
  State<RewardsScreen> createState() => _RewardsScreenState();
}

class _RewardsScreenState extends State<RewardsScreen> {
  List<Map<String, dynamic>> _cards = [];
  bool _loading = true;
  Map<String, dynamic>? _activeCard;
  bool _scratched = false;
  bool _claiming = false;

  @override
  void initState() {
    super.initState();
    _listenCards();
  }

  void _listenCards() {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      setState(() => _loading = false);
      return;
    }
    FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('scratchCards')
        .snapshots()
        .listen((snap) {
      final data = snap.docs.map((d) => {'id': d.id, ...d.data()}).toList();
      data.sort((a, b) {
        final aS = a['isScratched'] == true ? 1 : 0;
        final bS = b['isScratched'] == true ? 1 : 0;
        return aS.compareTo(bS);
      });
      setState(() {
        _cards = data;
        _loading = false;
      });
    }, onError: (e) {
      debugPrint('Scratch cards error: $e');
      setState(() => _loading = false);
    });
  }

  List<Map<String, dynamic>> get _pendingCards => _cards.where((c) => c['isScratched'] != true).toList();
  List<Map<String, dynamic>> get _claimedCards => _cards.where((c) => c['isScratched'] == true).toList();

  Future<void> _handleClaim() async {
    if (_activeCard == null || _claiming) return;
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    setState(() => _claiming = true);
    try {
      final cardRef = FirebaseFirestore.instance
          .collection('users').doc(uid).collection('scratchCards').doc(_activeCard!['id']);
      await cardRef.update({'isScratched': true});

      final userRef = FirebaseFirestore.instance.collection('users').doc(uid);
      final userSnap = await userRef.get();
      final bal = (userSnap.data()?['walletBalance'] as num?)?.toDouble() ?? 0;
      final amt = (_activeCard!['amount'] as num?)?.toDouble() ?? 0;
      await userRef.update({'walletBalance': bal + amt});

      await FirebaseFirestore.instance
          .collection('users').doc(uid).collection('transactions')
          .add({
        'type': 'credit',
        'title': 'Scratch Card Reward 🎁',
        'amount': amt,
        'createdAt': FieldValue.serverTimestamp(),
        'status': 'success',
      });

      setState(() {
        _activeCard = null;
        _scratched = false;
      });
    } catch (e) {
      debugPrint('Claim error: $e');
    }
    setState(() => _claiming = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      body: Column(
        children: [
          // Header
          Container(
            padding: EdgeInsets.only(
              top: MediaQuery.of(context).padding.top + 12,
              bottom: 20, left: 20, right: 20,
            ),
            decoration: const BoxDecoration(
              color: Color(0xFF145A32),
              borderRadius: BorderRadius.only(
                bottomLeft: Radius.circular(36), bottomRight: Radius.circular(36),
              ),
              boxShadow: [BoxShadow(color: Color(0x40145A32), blurRadius: 16, offset: Offset(0, 8))],
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: const Padding(padding: EdgeInsets.all(4), child: Icon(Icons.chevron_left, color: Color(0xFFD4A843), size: 28)),
                    ),
                    const Expanded(
                      child: Text('My Rewards', textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w900)),
                    ),
                    const SizedBox(width: 40),
                  ],
                ),
                const SizedBox(height: 20),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: const Color(0x4DD4A843)),
                  ),
                  child: Column(
                    children: [
                      Text('You have', style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 14, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 4),
                      Text('${_pendingCards.length} Reward${_pendingCards.length != 1 ? "s" : ""}',
                          style: const TextStyle(color: Color(0xFFD4A843), fontSize: 32, fontWeight: FontWeight.w900)),
                      const SizedBox(height: 4),
                      const Text('waiting to be scratched!', style: TextStyle(color: Colors.white, fontSize: 12)),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Body
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator(color: Color(0xFF145A32)))
                : _cards.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: const [
                            Text('😔', style: TextStyle(fontSize: 60)),
                            SizedBox(height: 10),
                            Text('No rewards yet', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: Color(0xFF111827))),
                            SizedBox(height: 8),
                            Text('Place an order to win scratch cards!', style: TextStyle(fontSize: 14, color: Color(0xFF6B7280))),
                          ],
                        ),
                      )
                    : ListView(
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
                        children: [
                          if (_pendingCards.isNotEmpty) ...[
                            const Text('Tap to Reveal 🎁',
                                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Color(0xFF145A32))),
                            const SizedBox(height: 16),
                            Wrap(
                              spacing: 16,
                              runSpacing: 16,
                              children: _pendingCards.map((c) {
                                return GestureDetector(
                                  onTap: () {
                                    setState(() {
                                      _activeCard = c;
                                      _scratched = false;
                                    });
                                    _showScratchDialog(c);
                                  },
                                  child: Container(
                                    width: (MediaQuery.of(context).size.width - 56) / 2,
                                    height: (MediaQuery.of(context).size.width - 56) / 2,
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFD4A843),
                                      borderRadius: BorderRadius.circular(20),
                                      boxShadow: const [BoxShadow(color: Color(0x66D4A843), blurRadius: 10, offset: Offset(0, 4))],
                                    ),
                                    padding: const EdgeInsets.all(6),
                                    child: Container(
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFF59E0B),
                                        borderRadius: BorderRadius.circular(16),
                                        border: Border.all(color: const Color(0xFFFEF3C7), width: 2, style: BorderStyle.solid),
                                      ),
                                      child: Column(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: const [
                                          Icon(Icons.card_giftcard, color: Colors.white, size: 32),
                                          SizedBox(height: 10),
                                          Text('Tap to scratch', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                                        ],
                                      ),
                                    ),
                                  ),
                                );
                              }).toList(),
                            ),
                          ],
                          if (_claimedCards.isNotEmpty) ...[
                            const SizedBox(height: 24),
                            const Text('Claimed Rewards History',
                                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Color(0xFF1F2937))),
                            const SizedBox(height: 16),
                            Wrap(
                              spacing: 16,
                              runSpacing: 16,
                              children: _claimedCards.map((c) {
                                final amt = (c['amount'] as num?)?.toInt() ?? 0;
                                String dateStr = 'Claimed';
                                if (c['createdAt'] is Timestamp) {
                                  final dt = (c['createdAt'] as Timestamp).toDate();
                                  dateStr = '${dt.day}/${dt.month}/${dt.year}';
                                }
                                return Container(
                                  width: (MediaQuery.of(context).size.width - 56) / 2,
                                  height: (MediaQuery.of(context).size.width - 56) / 2,
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(color: const Color(0xFFF3F4F6)),
                                    boxShadow: const [BoxShadow(color: Color(0x0D000000), blurRadius: 6, offset: Offset(0, 2))],
                                  ),
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      const Text('You Won', style: TextStyle(fontSize: 13, color: Color(0xFF6B7280), fontWeight: FontWeight.bold)),
                                      const SizedBox(height: 6),
                                      Text('₹$amt', style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: Color(0xFF145A32))),
                                      const SizedBox(height: 6),
                                      Text(dateStr, style: const TextStyle(fontSize: 11, color: Color(0xFF9CA3AF))),
                                    ],
                                  ),
                                );
                              }).toList(),
                            ),
                          ],
                        ],
                      ),
          ),
        ],
      ),
    );
  }

  void _showScratchDialog(Map<String, dynamic> card) {
    final amt = (card['amount'] as num?)?.toInt() ?? 0;
    showDialog(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black87,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text("It's a Reward! 🎉",
                      style: TextStyle(fontSize: 32, fontWeight: FontWeight.w900, color: Colors.white, decoration: TextDecoration.none)),
                  const SizedBox(height: 10),
                  const Text('Tap the card to reveal your prize',
                      style: TextStyle(fontSize: 14, color: Color(0xFFD1D5DB), decoration: TextDecoration.none)),
                  const SizedBox(height: 40),
                  GestureDetector(
                    onTap: () {
                      setDialogState(() => _scratched = true);
                      setState(() => _scratched = true);
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 500),
                      width: 200,
                      height: 200,
                      decoration: BoxDecoration(
                        color: _scratched ? Colors.white : const Color(0xFFD4A843),
                        borderRadius: BorderRadius.circular(24),
                        boxShadow: [BoxShadow(
                          color: (_scratched ? const Color(0xFF145A32) : const Color(0xFFD4A843)).withOpacity(0.4),
                          blurRadius: 20,
                          offset: const Offset(0, 8),
                        )],
                      ),
                      child: _scratched
                          ? Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Text('🎁', style: TextStyle(fontSize: 40, decoration: TextDecoration.none)),
                                const SizedBox(height: 8),
                                Text('₹$amt',
                                    style: const TextStyle(fontSize: 36, fontWeight: FontWeight.w900, color: Color(0xFF145A32), decoration: TextDecoration.none)),
                                const Text('Cashback!',
                                    style: TextStyle(fontSize: 14, color: Color(0xFF6B7280), fontWeight: FontWeight.w600, decoration: TextDecoration.none)),
                              ],
                            )
                          : const Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.card_giftcard, color: Colors.white, size: 48),
                                SizedBox(height: 12),
                                Text('TAP ME!',
                                    style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w900, decoration: TextDecoration.none)),
                              ],
                            ),
                    ),
                  ),
                  const SizedBox(height: 40),
                  if (_scratched)
                    GestureDetector(
                      onTap: () {
                        Navigator.pop(ctx);
                        _handleClaim();
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 18),
                        decoration: BoxDecoration(
                          color: const Color(0xFFD4A843),
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: const [BoxShadow(color: Color(0x80D4A843), blurRadius: 10, offset: Offset(0, 6))],
                        ),
                        child: _claiming
                            ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Color(0xFF111827), strokeWidth: 2.5))
                            : const Text('Claim to Wallet',
                                style: TextStyle(color: Color(0xFF111827), fontSize: 18, fontWeight: FontWeight.w900, decoration: TextDecoration.none)),
                      ),
                    ),
                  const SizedBox(height: 20),
                  GestureDetector(
                    onTap: () {
                      Navigator.pop(ctx);
                      setState(() => _activeCard = null);
                    },
                    child: const Text('Cancel',
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14, decoration: TextDecoration.none)),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}
