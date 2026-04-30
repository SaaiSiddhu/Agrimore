import 'package:flutter/material.dart';

class LanguageScreen extends StatefulWidget {
  const LanguageScreen({Key? key}) : super(key: key);

  @override
  State<LanguageScreen> createState() => _LanguageScreenState();
}

class _LanguageScreenState extends State<LanguageScreen> {
  String _selected = 'en';

  static const List<Map<String, String>> _languages = [
    {'code': 'en', 'name': 'English', 'native': 'English', 'flag': '🇬🇧'},
    {'code': 'ta', 'name': 'Tamil', 'native': 'தமிழ்', 'flag': '🇮🇳'},
  ];

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
              bottom: 20, left: 16, right: 16,
            ),
            decoration: const BoxDecoration(
              color: Color(0xFF145A32),
              borderRadius: BorderRadius.only(bottomLeft: Radius.circular(36), bottomRight: Radius.circular(36)),
              boxShadow: [BoxShadow(color: Color(0x40145A32), blurRadius: 16, offset: Offset(0, 8))],
            ),
            child: Row(
              children: [
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: const Padding(padding: EdgeInsets.all(8), child: Icon(Icons.arrow_back, color: Color(0xFFD4A843), size: 22)),
                ),
                const Expanded(
                  child: Text('Language', textAlign: TextAlign.center,
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
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Choose your preferred language',
                      style: TextStyle(fontSize: 16, color: Color(0xFF4B5563))),
                  const SizedBox(height: 24),
                  ..._languages.map((lang) {
                    final isActive = _selected == lang['code'];
                    return GestureDetector(
                      onTap: () => setState(() => _selected = lang['code']!),
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: isActive ? const Color(0x0FD4A843) : Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: isActive ? const Color(0xFFD4A843) : const Color(0xFFF3F4F6),
                            width: 1.5,
                          ),
                          boxShadow: const [BoxShadow(color: Color(0x08000000), blurRadius: 6, offset: Offset(0, 2))],
                        ),
                        child: Row(
                          children: [
                            Text(lang['flag']!, style: const TextStyle(fontSize: 28)),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(lang['name']!,
                                      style: TextStyle(
                                        fontSize: 16, fontWeight: FontWeight.w900,
                                        color: isActive ? const Color(0xFF145A32) : const Color(0xFF1F2937),
                                      )),
                                  const SizedBox(height: 2),
                                  Text(lang['native']!, style: const TextStyle(fontSize: 14, color: Color(0xFF9CA3AF))),
                                ],
                              ),
                            ),
                            Container(
                              width: 28, height: 28,
                              decoration: BoxDecoration(
                                color: isActive ? const Color(0xFFD4A843) : Colors.transparent,
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                  color: isActive ? const Color(0xFFD4A843) : const Color(0xFFD1D5DB),
                                  width: 2,
                                ),
                              ),
                              child: isActive
                                  ? const Icon(Icons.check, color: Colors.white, size: 14)
                                  : null,
                            ),
                          ],
                        ),
                      ),
                    );
                  }),
                  const SizedBox(height: 16),
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 18),
                      decoration: BoxDecoration(
                        color: const Color(0xFFD4A843),
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: const [BoxShadow(color: Color(0x4DD4A843), blurRadius: 8, offset: Offset(0, 4))],
                      ),
                      alignment: Alignment.center,
                      child: const Text('Apply Language',
                          style: TextStyle(color: Color(0xFF145A32), fontSize: 16, fontWeight: FontWeight.w900, letterSpacing: 1)),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
