import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:agrimore_ui/agrimore_ui.dart';
import '../../../providers/auth_provider.dart';
import '../../../services/order_rating_service.dart';

class RateOrderScreen extends StatefulWidget {
  final String orderId;
  final Future<int> Function(String, String, int, List<String>, String, bool Function())? submitRating;
  const RateOrderScreen({super.key, required this.orderId, this.submitRating});

  @override
  State<RateOrderScreen> createState() => _RateOrderScreenState();
}

class _RateOrderScreenState extends State<RateOrderScreen> {
  late final AuthProvider _openingAuth;
  late final String? _openingOwner;
  late final int _openingVersion;
  late final String _openingOrderId;
  bool get _ownsScreen => mounted && _openingOwner != null &&
      _openingOrderId.isNotEmpty && !_openingOrderId.contains('/') &&
      identical(context.read<AuthProvider>(), _openingAuth) &&
      _openingAuth.isSessionCurrent(_openingOwner, _openingVersion) &&
      widget.orderId == _openingOrderId;

  @override
  void initState() {
    super.initState();
    _openingAuth = context.read<AuthProvider>();
    _openingOwner = _openingAuth.currentUser?.uid;
    _openingVersion = _openingAuth.sessionVersion;
    _openingOrderId = widget.orderId;
  }
  void _chooseRating(int value) {
    if (_ownsScreen && !_submitting && !_submitted) setState(() => _rating = value);
  }
  void _toggleTag(String tag) {
    if (!_ownsScreen || _submitting || _submitted) return;
    setState(() { _selectedTags.contains(tag) ? _selectedTags.remove(tag) : _selectedTags.add(tag); });
  }
  void _done() {
    if (_ownsScreen) Navigator.of(context).maybePop();
  }
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
    if (!_ownsScreen || _rating == 0 || _submitting || _submitted) return;
    final rating = _rating;
    final tags = List<String>.unmodifiable(_selectedTags);
    final note = _noteCtrl.text.trim();
    if (note.length > 2000) {
      SnackbarHelper.showError(context, 'Keep your note within 2,000 characters.');
      return;
    }
    setState(() => _submitting = true);
    try {
      final submit = widget.submitRating ?? OrderRatingService().submit;
      final confirmed = await submit(_openingOrderId, _openingOwner!, rating,
          tags, note, () => _ownsScreen);
      if (!_ownsScreen) return;
      if (confirmed < 1 || confirmed > 5) throw StateError('Invalid rating receipt');
      setState(() { _rating = confirmed; _submitted = true; });
    } catch (_) {
      if (mounted && _ownsScreen) {
        SnackbarHelper.showError(context, 'Unable to save your rating. Please try again.');
      }
    } finally {
      if (_ownsScreen) setState(() => _submitting = false);
    }
  }

  @override
  void dispose() {
    _noteCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    context.watch<AuthProvider>();
    if (!_ownsScreen) {
      return const Scaffold(body: Center(child: Text(
          'Your session changed. Reopen this order to continue.')));
    }
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
                  onTap: _done,
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
                      'Order #${_openingOrderId.substring(0, _openingOrderId.length < 8 ? _openingOrderId.length : 8).toUpperCase()}',
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
                        onTap: !_submitting && _ownsScreen ? () => _chooseRating(starVal) : null,
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
                        onTap: !_submitting && _ownsScreen ? () => _toggleTag(tag) : null,
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
                    enabled: !_submitting,
                    maxLength: 2000,
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
                    onTap: _rating > 0 && !_submitting ? _handleSubmit : null,
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
                onTap: _done,
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
