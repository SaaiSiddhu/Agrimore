// ============================================================
//  AGRIMORE - ENABLE NOTIFICATIONS SCREEN
//  Shown once per device, right after the first successful login, before
//  the OS permission dialog is triggered — so the ask has context.
// ============================================================

import 'package:flutter/material.dart';
import 'package:agrimore_ui/agrimore_ui.dart';
import 'package:agrimore_services/agrimore_services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../providers/auth_provider.dart';
import 'package:provider/provider.dart';
import 'post_auth_router.dart';

class EnableNotificationsScreen extends StatefulWidget {
  final bool isNewUser;
  final String phone;
  const EnableNotificationsScreen({Key? key, required this.isNewUser, required this.phone})
      : super(key: key);

  @override
  State<EnableNotificationsScreen> createState() => _EnableNotificationsScreenState();
}

class _EnableNotificationsScreenState extends State<EnableNotificationsScreen> {
  bool _isProcessing = false;
  bool _bound = false;
  bool _retired = false;
  AuthProvider? _auth;
  String? _owner;
  int? _epoch;
  ModalRoute<dynamic>? _route;
  int _actionVersion = 0;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final auth = context.watch<AuthProvider>();
    if (!_bound) {
      _bound = true;
      _auth = auth;
      _owner = auth.sessionOwner;
      _epoch = auth.sessionVersion;
      _route = ModalRoute.of(context);
    } else if (!identical(auth, _auth) || _owner == null ||
        !auth.isSessionCurrent(_owner!, _epoch!)) {
      _retired = true;
      _actionVersion++;
      _isProcessing = false;
    }
  }

  bool _current(int ticket) => mounted && !_retired &&
      ticket == _actionVersion && _route?.isCurrent == true &&
      identical(context.read<AuthProvider>(), _auth) && _owner != null &&
      _auth!.isSessionCurrent(_owner!, _epoch!) &&
      _auth!.userUid == _owner && _auth!.currentUser != null;

  @override
  void dispose() {
    _retired = true;
    _actionVersion++;
    super.dispose();
  }

  Future<void> _markPrimed(int ticket, {required bool enabled}) async {
    final prefs = await SharedPreferences.getInstance();
    if (!_current(ticket)) return;
    await prefs.setBool(StorageConstants.keyNotificationsPrimed, true);
    if (!_current(ticket)) return;
    await prefs.setBool(StorageConstants.keyNotificationsEnabled, enabled);
  }

  Future<void> _handleEnable() => _run(enable: true);
  Future<void> _handleNotNow() => _run(enable: false);

  Future<void> _run({required bool enable}) async {
    if (_isProcessing || !_current(_actionVersion)) return;
    final ticket = ++_actionVersion;
    setState(() => _isProcessing = true);
    try {
      bool enabled = false;
      if (enable) {
        try {
          enabled = await NotificationService.initializeWithPermissionResult();
        } catch (_) {
          // Permission/setup failure does not undo the confirmed login.
        }
      }
      if (!mounted || !_current(ticket)) return;
      try {
        await _markPrimed(ticket, enabled: enabled);
      } catch (_) {
        // Local convenience flags must not prevent entry to the app.
      }
      if (!mounted || !_current(ticket)) return;
      PostAuthRouter.routeAfterAuth(context,
          phone: widget.phone, isNewUser: widget.isNewUser);
    } finally {
      if (mounted && ticket == _actionVersion) {
        setState(() => _isProcessing = false);
      }
    }
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
