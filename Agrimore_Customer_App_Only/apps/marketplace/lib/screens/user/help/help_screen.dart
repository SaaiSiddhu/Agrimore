// lib/screens/user/help/help_screen.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:agrimore_ui/agrimore_ui.dart';
import '../../../providers/theme_provider.dart';
// You might need to add imports for url_launcher to make contact buttons work

class HelpScreen extends StatefulWidget {
  const HelpScreen({Key? key}) : super(key: key);

  @override
  State<HelpScreen> createState() => _HelpScreenState();
}

class _HelpScreenState extends State<HelpScreen> with TickerProviderStateMixin {
  // --- Animation ---
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();

    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOut),
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.1),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOutCubic),
    );

    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Widget _buildHeader(bool isDark) {
    final double topPadding = MediaQuery.of(context).padding.top;

    return Container(
      padding: EdgeInsets.fromLTRB(16, 16 + topPadding, 16, 16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDark
              ? [
                  const Color(0xFF1E1E1E),
                  const Color(0xFF2D3A2D),
                  const Color(0xFF3A4D3A),
                ]
              : [
                  const Color(0xFF2D7D3C),
                  const Color(0xFF3DA34E),
                  const Color(0xFF4DB85F),
                ],
          stops: const [0.0, 0.5, 1.0],
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Container(
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () {
                  HapticFeedback.lightImpact();
                  Navigator.pop(context);
                },
                borderRadius: BorderRadius.circular(10),
                child: const Padding(
                  padding: EdgeInsets.all(10),
                  child: Icon(Icons.arrow_back_rounded, color: Colors.white, size: 20),
                ),
              ),
            ),
          ),
          const Text(
            'Help Center',
            style: TextStyle(
              fontSize: 19,
              fontWeight: FontWeight.w900,
              color: Colors.white,
            ),
          ),
          Container(
            width: 40,
            height: 40,
            decoration: const BoxDecoration(
              color: Colors.transparent,
              shape: BoxShape.circle,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar(bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF2C2C2C) : Colors.grey[100],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isDark ? Colors.grey[700]! : Colors.grey[200]!)
      ),
      child: Row(
        children: [
          Icon(Icons.search_rounded, color: isDark ? Colors.grey[400] : Colors.grey[600], size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: TextField(
              style: TextStyle(color: isDark ? Colors.white : Colors.black87),
              decoration: InputDecoration(
                hintText: 'Search for help...',
                hintStyle: TextStyle(color: isDark ? Colors.grey[500] : Colors.grey[500]),
                border: InputBorder.none,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title, bool isDark) {
    return Padding(
      padding: const EdgeInsets.only(top: 24, bottom: 10, left: 4),
      child: Text(
        title.toUpperCase(),
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w800,
          color: isDark ? Colors.grey[400] : Colors.grey[700],
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _buildHelpTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool isDark,
    required VoidCallback onTap,
  }) {
    final accentColor = isDark ? AppColors.primaryLight : const Color(0xFF2D7D3C);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDark ? Colors.grey[800]! : Colors.grey.shade200,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.3 : 0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: accentColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: accentColor, size: 22),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: isDark ? Colors.white : Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: TextStyle(
                          fontSize: 11,
                          color: isDark ? Colors.grey[400] : Colors.grey[600],
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.arrow_forward_ios_rounded,
                  size: 14,
                  color: isDark ? Colors.grey[600] : Colors.grey[400],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDark = themeProvider.isDarkMode;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF121212) : Colors.grey[50],
      body: Stack(
        children: [
          Column(
            children: [
              _buildHeader(isDark),
              Expanded(
                child: FadeTransition(
                  opacity: _fadeAnimation,
                  child: SlideTransition(
                    position: _slideAnimation,
                    child: CustomScrollView(
                      physics: const BouncingScrollPhysics(),
                      slivers: [
                        SliverToBoxAdapter(
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _buildSearchBar(isDark),
                                _buildSectionTitle("Common Topics", isDark),
                                _buildHelpTile(
                                  icon: Icons.question_answer_outlined,
                                  title: "FAQs",
                                  subtitle: "Find answers to common questions",
                                  isDark: isDark,
                                  onTap: () {
                                    // Navigate to FAQ screen
                                  },
                                ),
                                _buildHelpTile(
                                  icon: Icons.local_shipping_outlined,
                                  title: "Shipping & Returns",
                                  subtitle: "Info on delivery and returns",
                                  isDark: isDark,
                                  onTap: () {
                                    // Navigate to Shipping screen
                                  },
                                ),
                                _buildHelpTile(
                                  icon: Icons.payment_outlined,
                                  title: "Payment Options",
                                  subtitle: "View supported payment methods",
                                  isDark: isDark,
                                  onTap: () {
                                    // Navigate to Payment screen
                                  },
                                ),
                                _buildSectionTitle("Contact Us", isDark),
                                _buildHelpTile(
                                  icon: Icons.alternate_email_rounded,
                                  title: "Email Support",
                                  subtitle: "support@agrimore.com",
                                  isDark: isDark,
                                  onTap: () {
                                    // Launch email
                                  },
                                ),
                                _buildHelpTile(
                                  icon: Icons.phone_outlined,
                                  title: "Call Center",
                                  subtitle: "+91-123-456-7890",
                                  isDark: isDark,
                                  onTap: () {
                                    // Launch phone
                                  },
                                ),
                                _buildHelpTile(
                                  icon: Icons.policy_outlined,
                                  title: "Privacy Policy",
                                  subtitle: "Read our terms and conditions",
                                  isDark: isDark,
                                  onTap: () {
                                    // Navigate to Policy screen
                                  },
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}