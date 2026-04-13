// lib/widgets/auth_gate.dart
// Professional auth gate widget for protected screens

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../app/routes.dart';
import '../providers/auth_provider.dart' as app_auth;

/// A widget that wraps screens requiring authentication.
/// Shows the child if authenticated, otherwise prompts to login.
class AuthGate extends StatelessWidget {
  final Widget child;
  final String? redirectTo;
  final String featureName;

  const AuthGate({
    super.key,
    required this.child,
    required this.featureName,
    this.redirectTo,
  });

  @override
  Widget build(BuildContext context) {
    return Consumer<app_auth.AuthProvider>(
      builder: (context, authProvider, _) {
        if (authProvider.isLoggedIn) {
          return child;
        }
        return _buildLoginPrompt(context);
      },
    );
  }

  Widget _buildLoginPrompt(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: isDark
                ? [const Color(0xFF1A1A2E), const Color(0xFF0F0F1A)]
                : [Colors.green.shade50, Colors.white],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // App Bar
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                child: Row(
                  children: [
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: Icon(
                        Icons.arrow_back_ios_rounded,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                    ),
                    Text(
                      featureName,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                    ),
                  ],
                ),
              ),
              
              // Content
              Expanded(
                child: Center(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // Icon
                        Container(
                          width: 120,
                          height: 120,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                Colors.green.shade400,
                                Colors.green.shade600,
                              ],
                            ),
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.green.withOpacity(0.3),
                                blurRadius: 20,
                                offset: const Offset(0, 10),
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.lock_person_rounded,
                            size: 56,
                            color: Colors.white,
                          ),
                        ),
                        
                        const SizedBox(height: 32),
                        
                        // Title
                        Text(
                          'Login Required',
                          style: TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                            color: isDark ? Colors.white : Colors.black87,
                          ),
                        ),
                        
                        const SizedBox(height: 12),
                        
                        // Description
                        Text(
                          'Please sign in to access $featureName and enjoy a personalized experience.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 16,
                            color: isDark ? Colors.grey[400] : Colors.grey[600],
                            height: 1.5,
                          ),
                        ),
                        
                        const SizedBox(height: 40),
                        
                        // Benefits
                        _buildBenefitsList(isDark),
                        
                        const SizedBox(height: 40),
                        
                        // Login Button
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: () {
                              Navigator.pushNamed(context, AppRoutes.login);
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green.shade600,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                              elevation: 4,
                            ),
                            child: const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.login_rounded, size: 22),
                                SizedBox(width: 10),
                                Text(
                                  'Sign In',
                                  style: TextStyle(
                                    fontSize: 17,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        
                        const SizedBox(height: 16),
                        
                        // Create Account
                        TextButton(
                          onPressed: () {
                            Navigator.pushNamed(context, AppRoutes.signup);
                          },
                          child: RichText(
                            text: TextSpan(
                              text: "Don't have an account? ",
                              style: TextStyle(
                                color: isDark ? Colors.grey[400] : Colors.grey[600],
                                fontSize: 14,
                              ),
                              children: [
                                TextSpan(
                                  text: 'Create one',
                                  style: TextStyle(
                                    color: Colors.green.shade600,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        
                        const SizedBox(height: 16),
                        
                        // Continue Browsing
                        TextButton.icon(
                          onPressed: () => Navigator.pop(context),
                          icon: Icon(
                            Icons.arrow_back_rounded,
                            color: isDark ? Colors.grey[400] : Colors.grey[600],
                            size: 18,
                          ),
                          label: Text(
                            'Continue Browsing',
                            style: TextStyle(
                              color: isDark ? Colors.grey[400] : Colors.grey[600],
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
        ),
      ),
    );
  }

  Widget _buildBenefitsList(bool isDark) {
    final benefits = [
      ('Save your favorites', Icons.favorite_rounded),
      ('Track your orders', Icons.local_shipping_rounded),
      ('Faster checkout', Icons.flash_on_rounded),
      ('Exclusive offers', Icons.card_giftcard_rounded),
    ];

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark 
            ? Colors.white.withOpacity(0.05) 
            : Colors.green.withOpacity(0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark 
              ? Colors.white.withOpacity(0.1) 
              : Colors.green.withOpacity(0.1),
        ),
      ),
      child: Column(
        children: benefits.map((benefit) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.green.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    benefit.$2,
                    color: Colors.green.shade600,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 14),
                Text(
                  benefit.$1,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }
}
