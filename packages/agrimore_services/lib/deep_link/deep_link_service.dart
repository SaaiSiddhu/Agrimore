import 'dart:async';
import 'package:flutter/material.dart';
import 'package:app_links/app_links.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// Callback type for handling deep links
typedef DeepLinkHandler = void Function(String path, Map<String, String> params);

class DeepLinkService {
  static AppLinks? _appLinks;
  static StreamSubscription<Uri>? _deepLinkSubscription;
  static DeepLinkHandler? _handler;

  /// Initialize deep link service with a custom handler
  static void initialize(BuildContext context, {DeepLinkHandler? handler}) {
    _handler = handler;
    try {
      _appLinks = AppLinks();
      _deepLinkSubscription = _appLinks!.uriLinkStream.listen(
        (uri) {
          debugPrint('🔗 Deep link received: $uri');
          handleDeepLink(uri, context);
        },
        onError: (err) {
          debugPrint('❌ Deep link error: $err');
        },
      );

      _appLinks!.getInitialLink().then((uri) {
        if (uri != null) {
          debugPrint('🔗 Initial deep link: $uri');
          handleDeepLink(uri, context);
        }
      });
    } catch (e) {
      debugPrint('❌ Error initializing deep links: $e');
    }
  }

  static void handleDeepLink(Uri uri, BuildContext context) {
    final String path = uri.path;
    final Map<String, String> params = uri.queryParameters;
    debugPrint('🔍 Deep link path: $path');
    debugPrint('🔍 Deep link params: $params');

    // Handle password reset link internally
    if (path.contains('reset-password') || path.contains('resetPassword')) {
      final String? oobCode = params['oobCode'];
      final String? email = params['email'];
      if (oobCode != null) {
        debugPrint('🔐 Password reset link detected: $oobCode');
        navigateToPasswordReset(context, oobCode, email);
      }
      return;
    }

    // Delegate to handler for app-specific routes
    if (_handler != null) {
      _handler!(path, params);
    } else {
      // Default navigation using Navigator
      if (path == '/orders' || path == '/my-orders') {
        Navigator.pushNamed(context, '/orders');
      } else if (path.startsWith('/order/')) {
        final segments = path.split('/');
        if (segments.length >= 3 && segments[2].isNotEmpty) {
          Navigator.pushNamed(context, '/order/${segments[2]}');
        }
      } else if (path.contains('/product/')) {
        final segments = path.split('/');
        if (segments.length >= 3) {
          Navigator.pushNamed(context, '/product/${segments[2]}');
        }
      } else if (path.contains('/category/')) {
        final segments = path.split('/');
        if (segments.length >= 3) {
          Navigator.pushNamed(context, '/category/${segments[2]}');
        }
      } else {
        debugPrint('⚠️ No matching deep link handler for: $path');
      }
    }
  }

  static void navigateToPasswordReset(BuildContext context, String oobCode, String? email) {
    final TextEditingController newPasswordController = TextEditingController();
    final TextEditingController confirmPasswordController = TextEditingController();

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) => AlertDialog(
        title: const Text('Reset Password'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (email != null)
              Text('Email: $email', style: const TextStyle(fontSize: 12, color: Colors.grey)),
            const SizedBox(height: 16),
            const Text('Enter your new password:'),
            const SizedBox(height: 12),
            TextField(
              controller: newPasswordController,
              decoration: InputDecoration(
                labelText: 'New Password',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                prefixIcon: const Icon(Icons.lock),
              ),
              obscureText: true,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: confirmPasswordController,
              decoration: InputDecoration(
                labelText: 'Confirm Password',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                prefixIcon: const Icon(Icons.lock),
              ),
              obscureText: true,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              newPasswordController.dispose();
              confirmPasswordController.dispose();
              Navigator.pop(dialogContext);
            },
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              final newPass = newPasswordController.text.trim();
              final confirmPass = confirmPasswordController.text.trim();

              if (newPass.isEmpty || confirmPass.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Please fill all fields')),
                );
                return;
              }

              if (newPass != confirmPass) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Passwords do not match')),
                );
                return;
              }

              try {
                await FirebaseAuth.instance.confirmPasswordReset(
                  code: oobCode,
                  newPassword: newPass,
                );
                newPasswordController.dispose();
                confirmPasswordController.dispose();
                Navigator.pop(dialogContext);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('✅ Password reset successful!'),
                    backgroundColor: Colors.green,
                  ),
                );
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('❌ Error: $e'),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            },
            child: const Text('Reset'),
          ),
        ],
      ),
    );
  }

  static void dispose() {
    _deepLinkSubscription?.cancel();
  }
}
