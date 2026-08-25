// ============================================================
//  AGRIMORE - ENABLE NOTIFICATIONS SCREEN
//  Shown once per device, right after the first successful login, before
//  the OS permission dialog is triggered — so the ask has context.
// ============================================================

import 'package:flutter/material.dart';
import 'package:agrimore_ui/agrimore_ui.dart';
import 'package:agrimore_services/agrimore_services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../app/routes.dart';

class EnableNotificationsScreen extends StatefulWidget {
  final bool isNewUser;
  const EnableNotificationsScreen({Key? key, required this.isNewUser}) : super(key: key);

  @override
  State<EnableNotificationsScreen> createState() => _EnableNotificationsScreenState();
}

class _EnableNotificationsScreenState extends State<EnableNotificationsScreen> {
  bool _isProcessing = false;

  Future<void> _markPrimed({required bool enabled}) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(StorageConstants.keyNotificationsPrimed, true);
    await prefs.setBool(StorageConstants.keyNotificationsEnabled, enabled);
  }

  Future<void> _handleEnable() async {
    setState(() => _isProcessing = true);
    try {
      await NotificationService.initialize();
    } catch (_) {
      // Permission setup failing shouldn't block the user from entering the app
    }
    await _markPrimed(enabled: true);
    if (mounted) _proceed();
  }

  Future<void> _handleNotNow() async {
    await _markPrimed(enabled: false);
    if (mounted) _proceed();
  }

  void _proceed() {
    Navigator.of(context).pushNamedAndRemoveUntil(
      widget.isNewUser ? AppRoutes.onboardingAddress : AppRoutes.main,
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            children: [
              const SizedBox(height: 24),
              const Text(
                'Enable notifications to get updates\nabout offers, order status and more',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: AppColors.textPrimary, height: 1.4),
              ),
              Expanded(
                child: Center(
                  child: Image.asset(
                    'assets/images/notification_illustration.png',
                    fit: BoxFit.contain,
                    errorBuilder: (_, __, ___) => const Icon(Icons.notifications_active_rounded, size: 96, color: AppColors.primary),
                  ),
                ),
              ),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: _isProcessing ? null : _handleEnable,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: _isProcessing
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white),
                        )
                      : const Text('Enable Notifications', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: OutlinedButton(
                  onPressed: _isProcessing ? null : _handleNotNow,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.primary,
                    side: const BorderSide(color: AppColors.primary),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('Not now', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}
