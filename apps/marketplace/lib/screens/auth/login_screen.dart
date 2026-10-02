// ============================================================
//  AGRIMORE - LOGIN / SIGNUP SCREEN (Mobile Number + OTP)
//  One hero + bottom-sheet shell. AUTH-2: the sheet's CONTENT switches
//  internally between phone entry and OTP entry (an AnimatedSwitcher)
//  instead of pushing a second screen — the reference's own "same hero,
//  same sheet, smooth internal transition" over a separate page. Every
//  AuthProvider call below is unchanged from the pre-AUTH-2 two-screen
//  version; only the widget tree and navigation are restructured.
// ============================================================

import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:agrimore_ui/agrimore_ui.dart';
import 'package:agrimore_services/agrimore_services.dart'
    show PendingGoogleIdentity;
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../providers/auth_provider.dart';
import 'enable_notifications_screen.dart';
import 'post_auth_router.dart';

enum _AuthSheetState { phoneEntry, otpEntry }

const int _kOtpLength = 6;
const int _kResendCooldownSeconds = 30;

/// A screen action owns one observed session; a login may establish it once.
class _LoginAction {
  _LoginAction(
      this.auth, this.route, this.version, this.generation, this.signIn)
      : owner = auth.sessionOwner,
        epoch = auth.sessionVersion {
    auth.addListener(_observe);
  }
  final AuthProvider auth;
  final ModalRoute<dynamic>? route;
  final int version;
  final int generation;
  bool signIn;
  String? owner;
  int epoch;
  bool _retired = false;
  bool _invalid = false;
  void _observe() {
    if (_retired || _invalid) return;
    final next = auth.sessionOwner;
    final nextEpoch = auth.sessionVersion;
    if (signIn && owner == null && next != null) {
      owner = next;
      epoch = nextEpoch;
    } else if (owner != next || epoch != nextEpoch) {
      _invalid = true;
    }
  }

  bool get current {
    _observe();
    return !_retired &&
        !_invalid &&
        (owner == null
            ? auth.hasSignedOutSession
            : auth.isSessionCurrent(owner!, epoch));
  }

  void retire() {
    if (_retired) return;
    _retired = true;
    auth.removeListener(_observe);
  }
}

class LoginScreen extends StatefulWidget {
  const LoginScreen({Key? key}) : super(key: key);

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  _AuthSheetState _sheetState = _AuthSheetState.phoneEntry;

  // ── Phone entry ──
  final _phoneController = TextEditingController();
  final _phoneFocusNode = FocusNode();
  final _formKey = GlobalKey<FormState>();
  List<String> _recentNumbers = [];
  bool _autofillSheetShown = false;
  bool _isSubmitting = false;

  // ── OTP entry — same fields/logic _OtpVerificationScreenState used to
  // own, now living alongside the phone-entry fields in one State. ──
  final List<TextEditingController> _otpControllers =
      List.generate(_kOtpLength, (_) => TextEditingController());
  final List<FocusNode> _otpFocusNodes =
      List.generate(_kOtpLength, (_) => FocusNode());
  Timer? _resendTimer;
  int _resendSecondsLeft = _kResendCooldownSeconds;
  bool _isVerifying = false;
  bool _isResending = false;
  bool _isRequestingVoice = false;
  String? _otpErrorMessage;
  String? _activeTestOtp;
  String _channel = 'sms';
  // The phone number the current/last OTP was sent to — set once
  // sendPhoneOTP succeeds, replacing the old OtpVerificationScreen's
  // required constructor argument.
  String _pendingPhone = '';
  bool get _isVoiceChannel => _channel == 'voice';

  // ── AUTH-3: Google as a phone-verification-gated linked provider ──
  // Non-null only between "Google returned an unlinked identity" and
  // "phone verification for that identity finished (or was cancelled)".
  // Ephemeral — never persisted; cleared on link, cancel, or dispose.
  // Its presence is what turns the SAME phone/OTP states above into the
  // "verify your mobile to connect Google" framing, per this screen's own
  // build() — no separate sheet state needed, only the copy changes.
  PendingGoogleIdentity? _pendingGoogleIdentity;
  bool _isGoogleLoading = false;

  @override
  void initState() {
    super.initState();
    _loadRecentNumbers();
    _phoneFocusNode.addListener(_onPhoneFocusChange);
  }

  @override
  void dispose() {
    _retireActions();
    _phoneFocusNode.removeListener(_onPhoneFocusChange);
    _phoneController.dispose();
    _phoneFocusNode.dispose();
    _resendTimer?.cancel();
    for (final c in _otpControllers) {
      c.dispose();
    }
    for (final f in _otpFocusNodes) {
      f.dispose();
    }
    super.dispose();
  }

  Future<void> _loadRecentNumbers() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(StorageConstants.keyRecentPhoneNumbers);
      if (raw == null || raw.isEmpty) return;
      final list = (jsonDecode(raw) as List).cast<String>();
      if (mounted) setState(() => _recentNumbers = list);
    } catch (_) {
      // Ignore malformed local cache
    }
  }

  // Numbers previously used to sign in on THIS device are offered as quick-pick
  // suggestions, mirroring the OS "phone number hint" UX without needing any
  // SIM/telephony permissions.
  void _onPhoneFocusChange() {
    if (_phoneFocusNode.hasFocus &&
        !_autofillSheetShown &&
        _recentNumbers.isNotEmpty) {
      _autofillSheetShown = true;
      WidgetsBinding.instance.addPostFrameCallback((_) => _showAutofillSheet());
    }
  }

  Future<void> _showAutofillSheet() async {
    if (!mounted || _busy) return;
    final generation = _sheetGeneration;
    final auth = _observedAuth;
    final route = ModalRoute.of(context);
    _phoneFocusNode.unfocus();

    final selected = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => _AutofillNumberSheet(numbers: _recentNumbers),
    );

    if (!_sheetCurrent(generation, auth, route)) return;

    if (selected != null) {
      setState(() => _phoneController.text = selected);
    } else {
      _phoneFocusNode.requestFocus();
    }
  }

  String? _validatePhone(String? value) {
    final v = value?.trim() ?? '';
    if (v.isEmpty) return 'Enter your mobile number';
    if (v.length != 10) return 'Enter a valid 10-digit mobile number';
    if (!RegExp(r'^[6-9]\d{9}$').hasMatch(v)) {
      return 'Enter a valid Indian mobile number';
    }
    return null;
  }

  bool get _busy =>
      _isSubmitting ||
      _isGoogleLoading ||
      _isVerifying ||
      _isResending ||
      _isRequestingVoice;
  AuthProvider? _observedAuth;
  int? _observedEpoch;
  int _actionVersion = 0;
  int _sheetGeneration = 0;
  final Set<_LoginAction> _actions = {};

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final auth = context.watch<AuthProvider>();
    if (_observedAuth != null && !identical(_observedAuth, auth)) {
      _retireActions();
      _sheetState = _AuthSheetState.phoneEntry;
      _pendingPhone = '';
      _otpErrorMessage = null;
    }
    if (identical(_observedAuth, auth) && _observedEpoch != auth.sessionVersion &&
        !_actions.any((action) => action.signIn && action.current)) {
      _pendingGoogleIdentity = null;
    }
    _observedAuth = auth;
    _observedEpoch = auth.sessionVersion;
  }

  void _clearBusy() {
    _isSubmitting = _isGoogleLoading =
        _isVerifying = _isResending = _isRequestingVoice = false;
  }

  void _retireActions() {
    for (final action in _actions) {
      action.retire();
    }
    _actions.clear();
    _actionVersion++;
    _sheetGeneration++;
    _resendTimer?.cancel();
    _pendingGoogleIdentity = null;
    _clearBusy();
  }

  _LoginAction? _beginAction({bool signIn = false}) {
    if (!mounted || _busy || ModalRoute.of(context)?.isCurrent != true) {
      return null;
    }
    final auth = context.read<AuthProvider>();
    final action = _LoginAction(auth, ModalRoute.of(context), ++_actionVersion,
        _sheetGeneration, signIn);
    if (!action.current) {
      action.retire();
      return null;
    }
    _actions.add(action);
    return action;
  }

  bool _current(_LoginAction action) =>
      mounted &&
      identical(_observedAuth, action.auth) &&
      action.route?.isCurrent == true &&
      action.version == _actionVersion &&
      action.generation == _sheetGeneration &&
      action.current;

  void _finish(_LoginAction action) {
    action.retire();
    _actions.remove(action);
    if (mounted &&
        identical(_observedAuth, action.auth) &&
        action.version == _actionVersion) {
      setState(_clearBusy);
    }
  }

  bool _sheetCurrent(
          int generation, AuthProvider? auth, ModalRoute<dynamic>? route, [int? epoch]) =>
      mounted &&
      generation == _sheetGeneration &&
      identical(auth, _observedAuth) &&
      (epoch == null || auth?.sessionVersion == epoch) &&
      route?.isCurrent == true;

  Future<void> _handleContinue() async {
    if (_busy ||
        _sheetState != _AuthSheetState.phoneEntry ||
        _formKey.currentState?.validate() != true) {
      return;
    }
    final action = _beginAction();
    if (action == null) return;
    HapticFeedback.mediumImpact();
    FocusScope.of(context).unfocus();
    final phone = '+91${_phoneController.text.trim()}';
    setState(() => _isSubmitting = true);
    try {
      final result = await action.auth.sendPhoneOTP(phone);
      if (!mounted || !_current(action)) return;
      if (result == null) {
        SnackbarHelper.showError(
            context, 'Failed to send OTP. Please try again.');
        return;
      }
      _pendingPhone = phone;
      _enterOtpState(result.channel, autofillOtp: result.testOtp);
    } catch (_) {
      if (mounted && _current(action)) {
        SnackbarHelper.showError(
            context, 'Failed to send OTP. Please try again.');
      }
    } finally {
      _finish(action);
    }
  }

  void _enterOtpState(String channel, {String? autofillOtp}) {
    _sheetGeneration++;
    for (final c in _otpControllers) {
      c.clear();
    }
    setState(() {
      _channel = channel;
      _activeTestOtp = autofillOtp;
      _otpErrorMessage = null;
      _sheetState = _AuthSheetState.otpEntry;
    });
    _startResendCountdown();
    final generation = _sheetGeneration;
    final auth = _observedAuth;
    final epoch = auth?.sessionVersion;
    final route = ModalRoute.of(context);
    final autofill = autofillOtp != null && autofillOtp.length == _kOtpLength;
    if (autofill) {
      for (int i = 0; i < _kOtpLength; i++) {
        _otpControllers[i].text = autofillOtp[i];
      }
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_sheetCurrent(generation, auth, route, epoch)) return;
      (autofill ? _otpFocusNodes.last : _otpFocusNodes.first).requestFocus();
      if (autofill) {
        Future.delayed(const Duration(milliseconds: 350), () {
          if (_sheetCurrent(generation, auth, route, epoch) &&
              _sheetState == _AuthSheetState.otpEntry) {
            _handleVerify();
          }
        });
      }
    });
  }

  Future<void> _handleGoogleSignIn() async {
    if (_sheetState != _AuthSheetState.phoneEntry) return;
    final action = _beginAction();
    if (action == null) return;
    HapticFeedback.mediumImpact();
    FocusScope.of(context).unfocus();
    setState(() => _isGoogleLoading = true);
    try {
      final pending = await action.auth.acquireGoogleCredential();
      if (!mounted || !_current(action)) return;
      if (pending == null) {
        if (action.auth.error != null) {
          SnackbarHelper.showError(
              context, "Couldn't sign in with Google. Please try again.");
        }
        return;
      }
      final resolution = await action.auth.resolveGoogleIdentity(pending);
      if (!mounted || !_current(action)) return;
      if (resolution == null) {
        SnackbarHelper.showError(
            context, "Couldn't sign in with Google. Please try again.");
        return;
      }
      if (resolution.linked) {
        action.signIn = true;
        final success = await action.auth.signInWithLinkedGoogle(pending,
            expectedUid: resolution.expectedUid);
        if (!mounted || !_current(action)) return;
        if (!success) {
          SnackbarHelper.showError(
              context, "Couldn't sign in with Google. Please try again.");
          return;
        }
        await _proceedAfterLogin(action,
            phone: _pendingPhone, isNewUser: action.auth.isNewUser);
      } else {
        setState(() => _pendingGoogleIdentity = pending);
        final generation = _sheetGeneration;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (_sheetCurrent(generation, action.auth, action.route)) {
            _phoneFocusNode.requestFocus();
          }
        });
      }
    } catch (_) {
      if (mounted && _current(action)) {
        SnackbarHelper.showError(
            context, "Couldn't sign in with Google. Please try again.");
      }
    } finally {
      _finish(action);
    }
  }

  void _handleCancelGoogleLink() {
    setState(_retireActions);
  }

  void _handleChangeNumber() {
    setState(() {
      _retireActions();
      _sheetState = _AuthSheetState.phoneEntry;
      _activeTestOtp = null;
      _otpErrorMessage = null;
    });
    final generation = _sheetGeneration;
    final auth = _observedAuth;
    final route = ModalRoute.of(context);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_sheetCurrent(generation, auth, route)) {
        _phoneFocusNode.requestFocus();
      }
    });
  }

  void _startResendCountdown() {
    _resendSecondsLeft = _kResendCooldownSeconds;
    _resendTimer?.cancel();
    final generation = _sheetGeneration;
    _resendTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted ||
          generation != _sheetGeneration ||
          _sheetState != _AuthSheetState.otpEntry) {
        timer.cancel();
        return;
      }
      if (_resendSecondsLeft <= 1) {
        timer.cancel();
        setState(() => _resendSecondsLeft = 0);
      } else {
        setState(() => _resendSecondsLeft--);
      }
    });
  }

  void _onOtpDigitChanged(int index, String value) {
    if (value.isNotEmpty && index < _kOtpLength - 1) {
      _otpFocusNodes[index + 1].requestFocus();
    }
    final code = _otpControllers.map((c) => c.text).join();
    if (code.length == _kOtpLength && !code.contains(RegExp(r'\D'))) {
      _handleVerify();
    }
  }

  Future<void> _handleVerify() async {
    if (_busy || _sheetState != _AuthSheetState.otpEntry) return;
    final code = _otpControllers.map((c) => c.text).join();
    if (code.length != _kOtpLength || code.contains(RegExp(r'\D'))) return;
    final action = _beginAction(signIn: true);
    if (action == null) return;
    final phone = _pendingPhone;
    final pendingGoogle = _pendingGoogleIdentity;
    HapticFeedback.mediumImpact();
    setState(() {
      _isVerifying = true;
      _otpErrorMessage = null;
    });
    try {
      final success = await action.auth.verifyPhoneOTP(phone: phone, otp: code);
      if (!mounted || !_current(action)) return;
      if (!success) {
        final timeout = action.auth.errorCode == 'TIMEOUT';
        setState(() => _otpErrorMessage = timeout
            ? 'Verification is taking longer. Please try again.'
            : 'Invalid OTP. Please try again.');
        if (!timeout) {
          for (final c in _otpControllers) {
            c.clear();
          }
          _otpFocusNodes.first.requestFocus();
        }
        return;
      }
      if (action.owner == null || action.auth.userUid != action.owner) return;
      await _rememberPhoneNumber(action, phone);
      if (!mounted || !_current(action)) return;
      if (pendingGoogle != null) {
        bool linked = false;
        try {
          linked = await action.auth.linkGoogleToCurrentUser(pendingGoogle);
        } catch (_) {
          // A linking failure cannot undo the confirmed phone session.
        }
        if (!mounted || !_current(action)) return;
        _pendingGoogleIdentity = null;
        if (!linked) {
          SnackbarHelper.showWarning(context,
              'Signed in. Google could not be connected. Please try again later.');
        }
      }
      await _proceedAfterLogin(action,
          phone: phone, isNewUser: action.auth.isNewUser);
    } catch (_) {
      if (mounted && _current(action)) {
        setState(() => _otpErrorMessage =
            'Could not complete verification. Please try again.');
      }
    } finally {
      _finish(action);
    }
  }

  Future<void> _rememberPhoneNumber(_LoginAction action, String phone) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (!_current(action)) return;
      final raw = prefs.getString(StorageConstants.keyRecentPhoneNumbers);
      final list =
          raw != null ? (jsonDecode(raw) as List).cast<String>() : <String>[];
      final national = phone.replaceFirst('+91', '');
      list.remove(national);
      list.insert(0, national);
      if (!_current(action)) return;
      await prefs.setString(StorageConstants.keyRecentPhoneNumbers,
          jsonEncode(list.take(4).toList()));
    } catch (_) {/* Convenience cache failure does not undo login. */}
  }

  Future<void> _proceedAfterLogin(_LoginAction action,
      {required bool isNewUser, required String phone}) async {
    if (!_current(action) ||
        action.owner == null ||
        action.auth.userUid != action.owner) {
      return;
    }
    bool alreadyPrimed = false;
    try {
      final prefs = await SharedPreferences.getInstance();
      if (!_current(action)) return;
      alreadyPrimed =
          prefs.getBool(StorageConstants.keyNotificationsPrimed) ?? false;
    } catch (_) {/* Offer the primer when its local flag is unavailable. */}
    if (!mounted || !_current(action) || action.auth.userUid != action.owner) {
      return;
    }
    if (!alreadyPrimed) {
      Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(
              builder: (_) => EnableNotificationsScreen(
                  isNewUser: isNewUser, phone: phone)),
          (route) => false);
    } else {
      PostAuthRouter.routeAfterAuth(context,
          phone: phone, isNewUser: isNewUser);
    }
  }

  Future<void> _handleResend() => _redeliver(voice: false);
  Future<void> _handleVoiceResend() => _redeliver(voice: true);

  Future<void> _redeliver({required bool voice}) async {
    if (_busy ||
        _resendSecondsLeft > 0 ||
        _sheetState != _AuthSheetState.otpEntry) {
      return;
    }
    final action = _beginAction();
    if (action == null) return;
    final phone = _pendingPhone;
    setState(() {
      if (voice) {
        _isRequestingVoice = true;
      } else {
        _isResending = true;
      }
    });
    try {
      final result = await action.auth
          .sendPhoneOTP(phone, channel: voice ? 'voice' : 'sms');
      if (!mounted || !_current(action)) return;
      if (result == null) {
        SnackbarHelper.showError(
            context,
            voice
                ? 'Failed to place the call. Please try again.'
                : 'Failed to resend OTP. Please try again.');
        return;
      }
      if (voice) {
        setState(() => _channel = result.channel);
        _startResendCountdown();
        SnackbarHelper.showSuccess(
            context, "We're calling you now with your code");
      } else {
        _enterOtpState(result.channel, autofillOtp: result.testOtp);
      }
    } catch (_) {
      if (mounted && _current(action)) {
        SnackbarHelper.showError(
            context,
            voice
                ? 'Failed to place the call. Please try again.'
                : 'Failed to resend OTP. Please try again.');
      }
    } finally {
      _finish(action);
    }
  }

  // Masks the first half of the national number for display, matching the
  // reference design ("+91 ••••• 43210") — cosmetic only; every request
  // still uses the full, unmasked _pendingPhone value.
  String _maskedPhone() {
    final digits = _pendingPhone.replaceFirst('+91', '');
    if (digits.length != 10) return _pendingPhone;
    return '+91 ••••• ${digits.substring(5)}';
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark,
      child: PopScope(
        // System/OS back while on the OTP step returns to phone entry
        // first, instead of leaving the screen (and, pre-login, the app) —
        // the reference's own explicit requirement for this transition.
        canPop: _sheetState == _AuthSheetState.phoneEntry,
        onPopInvokedWithResult: (didPop, result) {
          if (!didPop && _sheetState == _AuthSheetState.otpEntry) {
            _handleChangeNumber();
          }
        },
        child: Scaffold(
          backgroundColor: Colors.white,
          resizeToAvoidBottomInset: true,
          // Stack, not a Column split into two adjacent regions: the hero
          // image is the full-screen background and the sheet floats OVER
          // its lower portion, overlapping — matching the reference
          // composition. The sheet sizes itself to its own content and is
          // capped at a fraction of the screen so the taller OTP state can
          // grow without ever swallowing the whole hero.
          body: GestureDetector(
            onTap: () => FocusScope.of(context).unfocus(),
            child: LayoutBuilder(
              builder: (context, constraints) {
                return Stack(
                  children: [
                    Positioned.fill(child: _buildHeroHeader()),
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: 0,
                      child: ConstrainedBox(
                        constraints: BoxConstraints(maxHeight: constraints.maxHeight * 0.72),
                        child: _buildSheet(),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  // Full-bleed image (edge-to-edge, no letterboxing), top-aligned so the
  // brand content baked into login_full_hero.png (wordmark, tagline, the
  // three value-prop icons) stays in frame across aspect ratios.
  Widget _buildHeroHeader() {
    return Semantics(
      label: 'AgriMore — Fresh from farms, faster to you',
      image: true,
      child: Image.asset(
        'assets/images/login_full_hero.png',
        fit: BoxFit.cover,
        alignment: Alignment.topCenter,
        excludeFromSemantics: true,
        errorBuilder: (_, __, ___) => const ColoredBox(color: AppColors.primaryDark),
      ),
    );
  }

  static const double _fieldHeight = 52;

  Widget _buildSheet() {
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
        // A floating shadow, not a border — the sheet sits ON TOP of the
        // hero image, so it needs to visually lift off the photo behind it.
        boxShadow: [
          BoxShadow(color: AppColors.shadowLight, blurRadius: 28, offset: Offset(0, -8)),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Decorative affordance matching the reference composition only —
            // this sheet is a fixed part of the screen layout, not an actual
            // drag-to-dismiss sheet, so it carries no gesture handler.
            const Padding(
              padding: EdgeInsets.only(top: 10, bottom: 4),
              child: SizedBox(
                width: 40,
                height: 4,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: AppColors.border,
                    borderRadius: BorderRadius.all(Radius.circular(2)),
                  ),
                ),
              ),
            ),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 20, 24, 20),
                // AnimatedSwitcher, not Navigator.push — the whole point of
                // AUTH-2 is one persistent sheet with an internal content
                // swap. Distinct ValueKeys per state are required so the
                // switcher treats phone/OTP content as different children.
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 220),
                  switchInCurve: Curves.easeOut,
                  switchOutCurve: Curves.easeIn,
                  transitionBuilder: (child, animation) => FadeTransition(
                    opacity: animation,
                    child: SlideTransition(
                      position: Tween<Offset>(begin: const Offset(0, 0.04), end: Offset.zero)
                          .animate(animation),
                      child: child,
                    ),
                  ),
                  child: _sheetState == _AuthSheetState.phoneEntry
                      ? _buildPhoneContent(key: const ValueKey('phone'))
                      : _buildOtpContent(key: const ValueKey('otp')),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPhoneContent({required Key key}) {
    final isGoogleLinking = _pendingGoogleIdentity != null;
    return Column(
      key: key,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                isGoogleLinking ? 'Verify your mobile number' : 'Login / Sign in',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
              ),
              const SizedBox(height: 6),
              Text(
                isGoogleLinking
                    ? 'To keep your AgriMore account secure and connect your orders, verify your mobile number once.'
                    : 'Enter your mobile number to receive an OTP',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 14, color: AppColors.textSecondary),
              ),
              const SizedBox(height: 20),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Flag-only box — the +91 code now lives inside the phone field itself.
                  Container(
                    height: _fieldHeight,
                    width: _fieldHeight,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      border: Border.all(color: AppColors.border),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(6),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: Image.asset(
                          'assets/icons/Login/India_Flag.png',
                          fit: BoxFit.contain,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: SizedBox(
                      height: _fieldHeight,
                      child: TextFormField(
                        controller: _phoneController,
                        focusNode: _phoneFocusNode,
                        keyboardType: TextInputType.phone,
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, letterSpacing: 0.5),
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                          LengthLimitingTextInputFormatter(10),
                        ],
                        decoration: InputDecoration(
                          prefixText: '+91  ',
                          prefixStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                          hintText: 'Enter Phone Number',
                          hintStyle: const TextStyle(color: AppColors.textHint, fontWeight: FontWeight.w400),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 14),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: const BorderSide(color: AppColors.border),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: const BorderSide(color: AppColors.border),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: const BorderSide(color: AppColors.primary, width: 2),
                          ),
                          errorBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: const BorderSide(color: AppColors.error),
                          ),
                        ),
                        validator: _validatePhone,
                        onFieldSubmitted: (_) => _handleContinue(),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              SizedBox(
                height: _fieldHeight,
                child: ElevatedButton(
                  onPressed: _busy ? null : _handleContinue,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: _isSubmitting
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white),
                        )
                      : const Text('Continue', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                ),
              ),
              if (isGoogleLinking) ...[
                const SizedBox(height: 14),
                Center(
                  child: TextButton(
                    onPressed: _handleCancelGoogleLink,
                    child: const Text('Not now',
                        style: TextStyle(color: AppColors.textSecondary, fontWeight: FontWeight.w600, fontSize: 13)),
                  ),
                ),
              ],
            ],
          ),
        ),
        if (!isGoogleLinking) ...[
          const SizedBox(height: 20),
          _buildGoogleDivider(),
          const SizedBox(height: 16),
          _buildGoogleButton(),
        ],
        const SizedBox(height: 16),
        _buildTermsText(),
      ],
    );
  }

  Widget _buildGoogleDivider() {
    return const Row(
      children: [
        Expanded(child: Divider(color: AppColors.border)),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 12),
          child: Text('or continue with', style: TextStyle(fontSize: 12, color: AppColors.textTertiary)),
        ),
        Expanded(child: Divider(color: AppColors.border)),
      ],
    );
  }

  // Secondary to the primary phone CTA by design: white surface, soft
  // border, the official multicolor Google "G" rather than a recolored or
  // hand-drawn substitute (Google's own brand guidelines require this).
  Widget _buildGoogleButton() {
    return SizedBox(
      height: _fieldHeight,
      child: OutlinedButton(
        onPressed: _busy ? null : _handleGoogleSignIn,
        style: OutlinedButton.styleFrom(
          backgroundColor: Colors.white,
          side: const BorderSide(color: AppColors.border),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
        child: _isGoogleLoading
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2.5, color: AppColors.primary),
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _GoogleLogo(size: 20),
                  const SizedBox(width: 12),
                  Text(
                    'Continue with Google',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _buildTermsText() {
    return Center(
      child: Wrap(
        alignment: WrapAlignment.center,
        children: [
          Text('By continuing, you agree to our ', style: TextStyle(fontSize: 12, color: AppColors.textTertiary)),
          GestureDetector(
            onTap: () => Navigator.pushNamed(context, '/terms'),
            child: const Text('Terms of Service',
                style: TextStyle(fontSize: 12, color: AppColors.primary, fontWeight: FontWeight.w600)),
          ),
          Text(' and ', style: TextStyle(fontSize: 12, color: AppColors.textTertiary)),
          GestureDetector(
            onTap: () => Navigator.pushNamed(context, '/privacy-policy'),
            child: const Text('Privacy Policy',
                style: TextStyle(fontSize: 12, color: AppColors.primary, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  Widget _buildOtpContent({required Key key}) {
    return Column(
      key: key,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text.rich(
          TextSpan(
            style: const TextStyle(fontSize: 14, color: AppColors.textSecondary),
            children: [
              TextSpan(
                text: _isVoiceChannel
                    ? "We're calling you now with your code, on\n"
                    : 'We have sent a verification code to\n',
              ),
              TextSpan(
                text: _maskedPhone(),
                style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.textPrimary),
              ),
            ],
          ),
          textAlign: TextAlign.center,
        ),
        if (_activeTestOtp != null) ...[
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              'Test mode code: $_activeTestOtp (autofilled)',
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppColors.primary,
              ),
            ),
          ),
        ],
        const SizedBox(height: 20),
        // Expanded per box (not a fixed width) so the row always fits exactly
        // within the screen width, on any device — no overflow possible.
        Row(
          children: List.generate(
            _kOtpLength,
            (index) => Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: _buildDigitBox(index),
              ),
            ),
          ),
        ),
        if (_otpErrorMessage != null) ...[
          const SizedBox(height: 14),
          Text(_otpErrorMessage!, style: const TextStyle(color: AppColors.error, fontSize: 13), textAlign: TextAlign.center),
        ],
        const SizedBox(height: 22),
        GestureDetector(
          onTap: _handleResend,
          child: Text.rich(
            TextSpan(
              style: const TextStyle(fontSize: 14, color: AppColors.textSecondary),
              children: [
                const TextSpan(text: "Didn't get the OTP? "),
                TextSpan(
                  text: _resendSecondsLeft > 0
                      ? 'Resend ${_isVoiceChannel ? 'call' : 'SMS'} in ${_resendSecondsLeft}s'
                      : (_isResending ? 'Resending...' : 'Resend ${_isVoiceChannel ? 'call' : 'SMS'}'),
                  style: TextStyle(
                    color: _resendSecondsLeft > 0 ? AppColors.textTertiary : AppColors.primary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ),
        // Voice fallback — only offered once the cooldown has elapsed, so
        // it's never shown as an option before the SMS has even had a
        // chance to arrive; meaningless (and hidden) when voice is already
        // the primary channel.
        if (_resendSecondsLeft == 0 && !_isVoiceChannel) ...[
          const SizedBox(height: 10),
          GestureDetector(
            onTap: _handleVoiceResend,
            child: Text(
              _isRequestingVoice ? 'Calling you...' : 'Call me instead',
              style: const TextStyle(fontSize: 13, color: AppColors.primary, fontWeight: FontWeight.w700),
            ),
          ),
        ],
        const SizedBox(height: 18),
        TextButton(
          onPressed: _handleChangeNumber,
          child: const Text('Change number',
              style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.w700, fontSize: 14)),
        ),
        if (_isVerifying) ...[
          const SizedBox(height: 4),
          const SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(strokeWidth: 2.5, color: AppColors.primary),
          ),
        ],
      ],
    );
  }

  Widget _buildDigitBox(int index) {
    return SizedBox(
      height: 56,
      child: TextField(
        controller: _otpControllers[index],
        focusNode: _otpFocusNodes[index],
        textAlign: TextAlign.center,
        keyboardType: TextInputType.number,
        maxLength: 1,
        style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        decoration: InputDecoration(
          counterText: '',
          contentPadding: EdgeInsets.zero,
          filled: true,
          fillColor: AppColors.surfaceVariant,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: AppColors.textTertiary, width: 1.4),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: AppColors.textTertiary, width: 1.4),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: AppColors.primary, width: 2),
          ),
        ),
        onChanged: (value) => _onOtpDigitChanged(index, value),
        onTap: () {
          _otpControllers[index].selection = TextSelection(
            baseOffset: 0,
            extentOffset: _otpControllers[index].text.length,
          );
        },
      ),
    );
  }
}

class _AutofillNumberSheet extends StatelessWidget {
  final List<String> numbers;
  const _AutofillNumberSheet({required this.numbers});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 20),
              child: Text('Continue with', style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
            ),
            const SizedBox(height: 8),
            ...numbers.map(
              (number) => ListTile(
                leading: CircleAvatar(
                  backgroundColor: AppColors.surfaceContainer,
                  child: const Icon(Icons.phone_outlined, color: AppColors.textSecondary),
                ),
                title: Text(number, style: const TextStyle(fontSize: 16)),
                onTap: () => Navigator.pop(context, number),
              ),
            ),
            const SizedBox(height: 4),
            ListTile(
              title: const Text(
                'NONE OF THE ABOVE',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.info, letterSpacing: 0.3),
              ),
              onTap: () => Navigator.pop(context),
            ),
          ],
        ),
      ),
    );
  }
}

// The official multicolor Google "G" mark, drawn from the standard 18x18
// path data Google publishes for exactly this purpose (Sign-In button
// branding guidelines require the unmodified mark — never recolored,
// never a substitute). No new asset/package dependency: apps/marketplace
// has neither flutter_svg nor font_awesome_flutter as a direct dependency
// today, and adding one for a single icon was judged disproportionate.
class _GoogleLogo extends StatelessWidget {
  final double size;
  const _GoogleLogo({this.size = 20});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(painter: _GoogleLogoPainter()),
    );
  }
}

class _GoogleLogoPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final scale = size.width / 18.0;
    canvas.save();
    canvas.scale(scale, scale);

    final blue = Paint()..color = const Color(0xFF4285F4);
    final green = Paint()..color = const Color(0xFF34A853);
    final yellow = Paint()..color = const Color(0xFFFBBC05);
    final red = Paint()..color = const Color(0xFFEA4335);

    final bluePath = Path()
      ..moveTo(17.64, 9.2045)
      ..cubicTo(17.64, 8.5664, 17.5827, 7.9527, 17.4764, 7.3636)
      ..lineTo(9, 7.3636)
      ..lineTo(9, 10.845)
      ..lineTo(13.8436, 10.845)
      ..cubicTo(13.635, 11.97, 13.0009, 12.9232, 12.0477, 13.5614)
      ..lineTo(12.0477, 15.8195)
      ..lineTo(14.9564, 15.8195)
      ..cubicTo(16.6582, 14.2527, 17.64, 11.9455, 17.64, 9.2045)
      ..close();
    canvas.drawPath(bluePath, blue);

    final greenPath = Path()
      ..moveTo(9, 18)
      ..cubicTo(11.43, 18, 13.4673, 17.1941, 14.9564, 15.8195)
      ..lineTo(12.0477, 13.5614)
      ..cubicTo(11.2418, 14.1014, 10.2109, 14.4205, 9, 14.4205)
      ..cubicTo(6.6564, 14.4205, 4.6718, 12.8373, 3.964, 10.71)
      ..lineTo(0.9573, 10.71)
      ..lineTo(0.9573, 13.0418)
      ..cubicTo(2.4382, 15.9832, 5.4818, 18, 9, 18)
      ..close();
    canvas.drawPath(greenPath, green);

    final yellowPath = Path()
      ..moveTo(3.964, 10.71)
      ..cubicTo(3.784, 10.17, 3.6818, 9.5932, 3.6818, 9)
      ..cubicTo(3.6818, 8.4068, 3.784, 7.83, 3.964, 7.29)
      ..lineTo(3.964, 4.9582)
      ..lineTo(0.9573, 4.9582)
      ..cubicTo(0.3477, 6.1732, 0, 7.5477, 0, 9)
      ..cubicTo(0, 10.4523, 0.3477, 11.8268, 0.9573, 13.0418)
      ..lineTo(3.964, 10.71)
      ..close();
    canvas.drawPath(yellowPath, yellow);

    final redPath = Path()
      ..moveTo(9, 3.5795)
      ..cubicTo(10.3214, 3.5795, 11.5077, 4.0336, 12.4405, 4.9255)
      ..lineTo(15.0218, 2.3441)
      ..cubicTo(13.4636, 0.891, 11.4259, 0, 9, 0)
      ..cubicTo(5.4818, 0, 2.4382, 2.0168, 0.9573, 4.9582)
      ..lineTo(3.964, 7.2895)
      ..cubicTo(4.6718, 5.1636, 6.6564, 3.5795, 9, 3.5795)
      ..close();
    canvas.drawPath(redPath, red);

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
