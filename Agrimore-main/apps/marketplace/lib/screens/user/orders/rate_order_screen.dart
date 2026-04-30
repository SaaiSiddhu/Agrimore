import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class RateOrderScreen extends StatefulWidget {
  final String orderId;
  const RateOrderScreen({Key? key, required this.orderId}) : super(key: key);

  @override
  State<RateOrderScreen> createState() => _RateOrderScreenState();
}

class _RateOrderScreenState extends State<RateOrderScreen> with SingleTickerProviderStateMixin {
  int _rating = 0;
  final Set<String> _selectedTags = {};
  final TextEditingController _noteCtrl = TextEditingController();
  bool _submitted = false;
  bool _submitting = false;

  static const List<String> _tags = [
    'Fast Delivery', 'Fresh Items', 'Good Packaging',
    'Great Value', 'Polite Driver', 'On Time',
  ];
  static const List<String> _labels = ['', 'Terrible', 'Poor', 'Okay', 'Good', 'Excellent'];

  Future<void> _handleSubmit() async {
    if (_rating == 0 || _submitting) return;
    setState(() => _submitting = true);

    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid != null) {
        await FirebaseFirestore.instance
            .collection('orders')
            .doc(widget.orderId)
            .collection('reviews')
            .add({
          'userId': uid,
          'rating': _rating,
          'tags': _selectedTags.toList(),
          'note': _noteCtrl.text.trim(),
          'createdAt': FieldValue.serverTimestamp(),
        });

        // Update order with rating
        await FirebaseFirestore.instance
            .collection('orders')
            .doc(widget.orderId)
            .update({'rating': _rating, 'isRated': true});
      }
      setState(() => _submitted = true);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
      );
    }
    setState(() => _submitting = false);
  }

  @override
  void dispose() {
    _noteCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_submitted) return _buildCelebration();

    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      body: Column(
        children: [
          // Header
          Container(
            padding: EdgeInsets.only(
              top: MediaQuery.of(context).padding.top + 12,
              bottom: 20, left: 16, right: 16,
            ),
            decoration: const BoxDecoration(
              color: Color(0xFF145A32),
              borderRadius: BorderRadius.only(
                bottomLeft: Radius.circular(36), bottomRight: Radius.circular(36),
              ),
              boxShadow: [BoxShadow(color: Color(0x40145A32), blurRadius: 16, offset: Offset(0, 8))],
            ),
            child: Row(
              children: [
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: const Padding(padding: EdgeInsets.all(8), child: Icon(Icons.arrow_back, color: Color(0xFFD4A843), size: 22)),
                ),
                const Expanded(
                  child: Text('Rate Order', textAlign: TextAlign.center,
                    style: TextStyle(color: Color(0xFFD4A843), fontSize: 24, fontWeight: FontWeight.w900)),
                ),
                const SizedBox(width: 38),
              ],
            ),
          ),

          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
              child: Column(
                children: [
                  // Order ID pill
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                    decoration: BoxDecoration(
                      color: const Color(0x14145A32),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      'Order #${widget.orderId.substring(0, 8).toUpperCase()}',
                      style: const TextStyle(color: Color(0xFF145A32), fontSize: 13, fontWeight: FontWeight.w700),
                    ),
                  ),
                  const SizedBox(height: 28),

                  // Star Rating
                  const Text('How was your experience?',
                      style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: Color(0xFF1F2937))),
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(5, (i) {
                      final starVal = i + 1;
                      return GestureDetector(
                        onTap: () => setState(() => _rating = starVal),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 6),
                          child: Icon(
                            starVal <= _rating ? Icons.star : Icons.star_border,
                            color: const Color(0xFFD4A843),
                            size: 44,
                          ),
                        ),
                      );
                    }),
                  ),
                  if (_rating > 0) ...[
                    const SizedBox(height: 12),
                    Text(_labels[_rating],
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: Color(0xFFD4A843))),
                  ],
                  const SizedBox(height: 28),

                  // Tags
                  const Align(
                    alignment: Alignment.centerLeft,
                    child: Text('What did you like?',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: Color(0xFF145A32))),
                  ),
                  const SizedBox(height: 14),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: _tags.map((tag) {
                      final isActive = _selectedTags.contains(tag);
                      return GestureDetector(
                        onTap: () => setState(() {
                          isActive ? _selectedTags.remove(tag) : _selectedTags.add(tag);
                        }),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                          decoration: BoxDecoration(
                            color: isActive ? const Color(0x26D4A843) : Colors.white,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: isActive ? const Color(0xFFD4A843) : const Color(0xFFE5E7EB),
                              width: 1.5,
                            ),
                          ),
                          child: Text(tag,
                              style: TextStyle(
                                fontSize: 13,
                                color: isActive ? const Color(0xFFD4A843) : const Color(0xFF6B7280),
                                fontWeight: isActive ? FontWeight.w900 : FontWeight.w600,
                              )),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 24),

                  // Note
                  const Align(
                    alignment: Alignment.centerLeft,
                    child: Text('Add a note (optional)',
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Color(0xFF4B5563))),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _noteCtrl,
                    maxLines: 4,
                    decoration: InputDecoration(
                      hintText: 'Tell us more about your experience...',
                      hintStyle: const TextStyle(color: Color(0xFF9CA3AF)),
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: const BorderSide(color: Color(0xFFF3F4F6)),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: const BorderSide(color: Color(0xFFF3F4F6)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: const BorderSide(color: Color(0xFFD4A843)),
                      ),
                    ),
                  ),
                  const SizedBox(height: 28),

                  // Submit
                  GestureDetector(
                    onTap: _rating > 0 ? _handleSubmit : null,
                    child: AnimatedOpacity(
                      opacity: _rating > 0 ? 1.0 : 0.5,
                      duration: const Duration(milliseconds: 200),
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 18),
                        decoration: BoxDecoration(
                          color: const Color(0xFFD4A843),
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: const [
                            BoxShadow(color: Color(0x4DD4A843), blurRadius: 8, offset: Offset(0, 4)),
                          ],
                        ),
                        alignment: Alignment.center,
                        child: _submitting
                            ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Color(0xFF145A32), strokeWidth: 2.5))
                            : const Text('Submit Rating',
                                style: TextStyle(color: Color(0xFF145A32), fontSize: 16, fontWeight: FontWeight.w900, letterSpacing: 1)),
                      ),
                    ),
                  ),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCelebration() {
    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(40),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text('🎉', style: TextStyle(fontSize: 72)),
              const SizedBox(height: 20),
              const Text('Thank You!',
                  style: TextStyle(fontSize: 32, fontWeight: FontWeight.w900, color: Color(0xFF145A32))),
              const SizedBox(height: 8),
              const Text('Your feedback helps us improve our service',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 15, color: Color(0xFF6B7280))),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(5, (i) => Icon(
                  i < _rating ? Icons.star : Icons.star_border,
                  color: const Color(0xFFD4A843), size: 36,
                )),
              ),
              const SizedBox(height: 20),
              GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 16),
                  decoration: BoxDecoration(
                    color: const Color(0xFF145A32),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Text('Done',
                      style: TextStyle(color: Color(0xFFD4A843), fontSize: 16, fontWeight: FontWeight.w900)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
