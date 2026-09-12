import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:firebase_auth/firebase_auth.dart' as auth;
import 'package:agrimore_ui/agrimore_ui.dart';
import '../../../providers/auth_provider.dart' as app_auth;
import '../../../providers/theme_provider.dart';
import 'change_phone_screen.dart';
import 'change_email_screen.dart';

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({Key? key}) : super(key: key);

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen>
    with TickerProviderStateMixin, StickyHeaderCollapseMixin<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  // Phone/email are shown read-only here, not free-text editable — see
  // _buildCompactRow's CHANGE-trailing rows below. Editing either now goes through
  // ChangePhoneScreen/ChangeEmailScreen, which require a fresh OTP verified
  // server-side (changePhoneNumber.ts / changeEmailAddress.ts). This
  // screen's Save button used to write _phoneController's text straight to
  // Firestore with no verification of any kind — the same account-takeover
  // shape closed elsewhere in this codebase this session, reachable through
  // the primary Edit Profile screen every time it was opened.
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();

  // PROFILE-8: date of birth and gender were collected once at profile
  // completion (complete_profile_screen.dart) with no edit path anywhere in
  // the app afterward. Gender mirrors that screen's own options list
  // exactly (same values/labels) since firestore.rules already allows a
  // plain owner write to it — no server change needed. Date of birth is
  // different in kind: firestore.rules blanket-blocks any client write to
  // it regardless of value (Phase 16 Workstream 5), so it saves immediately
  // through the new changeDateOfBirth callable the moment a new date is
  // picked, the same "changes on its own, not on the big Save button"
  // pattern phone/email already use — not through _saveProfile below.
  DateTime? _dateOfBirth;
  String? _gender;
  bool _isSavingDateOfBirth = false;
  static const List<Map<String, String>> _genderOptions = [
    {'value': 'male', 'label': 'Male'},
    {'value': 'female', 'label': 'Female'},
    {'value': 'non_binary', 'label': 'Non-binary'},
    {'value': 'prefer_not_to_say', 'label': 'Prefer not to say'},
  ];

  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  late AnimationController _avatarController;
  late Animation<double> _avatarScale;

  XFile? _pickedImage;
  String? _photoUrl;
  // PROFILE-13: mirrors how a newly-picked photo already stages locally
  // until Save Changes — "Remove Photo" stages the same way rather than
  // writing immediately. Needed as its own flag (not just null-checking
  // _photoUrl) because updateUserProfile's photoUrl: photoUrl ??
  // _currentUser!.photoUrl treats null as "no change, keep existing" —
  // only an explicit empty string actually clears it, and _saveProfile
  // has no other way to know "the user cleared it" versus "never touched
  // it this session".
  bool _photoRemoved = false;
  bool _isLoading = false;
  bool _isUploadingImage = false;

  // --- Toast ---
  bool _showToast = false;
  String _toastMessage = '';
  IconData _toastIcon = Icons.check_circle;
  Color _toastColor = const Color(0xFF2D7D3C);
  Timer? _toastTimer;
  late AnimationController _toastAnimationController;
  late Animation<Offset> _toastSlideAnimation;
  late Animation<double> _toastFadeAnimation;
  late Animation<double> _toastScaleAnimation;
  // --- End Toast ---

  @override
  void initState() {
    super.initState();

    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600), // Matched profile
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOut),
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.1), // Matched profile
      end: Offset.zero,
    ).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOutCubic),
    );

    _avatarController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000), // Slightly faster
    );

    _avatarScale = Tween<double>(begin: 0.5, end: 1.0).animate(
      CurvedAnimation(
        parent: _avatarController,
        curve: Curves.elasticOut,
      ),
    );

    // --- Toast Animations ---
    _toastAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );

    _toastSlideAnimation = Tween<Offset>(
      begin: const Offset(0, -1.5),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _toastAnimationController,
        curve: Curves.easeOutCubic,
      ),
    );

    _toastFadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _toastAnimationController, curve: Curves.easeOut),
    );

    _toastScaleAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(parent: _toastAnimationController, curve: Curves.elasticOut),
    );
    // --- End Toast Animations ---

    _loadUserData();
    _animationController.forward();
    Future.delayed(const Duration(milliseconds: 200), () {
      _avatarController.forward();
    });
  }

  void _loadUserData() {
    final authProvider =
        Provider.of<app_auth.AuthProvider>(context, listen: false);
    final user = authProvider.currentUser;

    if (user != null) {
      _nameController.text = user.name ?? '';
      _phoneController.text = user.phone ?? '';
      _emailController.text = user.email ?? '';
      _photoUrl = user.photoUrl;
      _dateOfBirth = user.dateOfBirth;
      _gender = user.gender;
      debugPrint('✅ Loaded user data: ${user.name}');
    }
  }

  void _showToastMessage(String message, {bool isSuccess = true}) {
    if (!mounted) return;
    _toastTimer?.cancel();

    setState(() {
      _toastMessage = message;
      _toastIcon = isSuccess ? Icons.check_circle_rounded : Icons.error_rounded;
      _toastColor = isSuccess ? const Color(0xFF2D7D3C) : Colors.red;
      _showToast = true;
    });

    _toastAnimationController.forward();

    _toastTimer = Timer(const Duration(milliseconds: 2800), () {
      if (mounted) {
        _toastAnimationController.reverse().then((_) {
          if (mounted) setState(() => _showToast = false);
        });
      }
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _animationController.dispose();
    _avatarController.dispose();
    _toastAnimationController.dispose();
    _toastTimer?.cancel();
    super.dispose();
  }

  Future<String?> _uploadPhotoToFirebase(XFile imageFile) async {
    try {
      final userId = auth.FirebaseAuth.instance.currentUser?.uid;

      if (userId == null) {
        _showToastMessage('❌ User ID not found', isSuccess: false);
        return null;
      }

      debugPrint('📸 Uploading profile photo for user: $userId');

      setState(() => _isUploadingImage = true);

      final fileName =
          'profile_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final ref = FirebaseStorage.instance.ref('users/$userId/$fileName');

      // Use bytes for web compatibility
      final Uint8List bytes = await imageFile.readAsBytes();
      final uploadTask = ref.putData(bytes, SettableMetadata(contentType: 'image/jpeg'));

      await uploadTask;
      final downloadUrl = await ref.getDownloadURL();
      debugPrint('✅ Photo uploaded: $downloadUrl');

      setState(() => _isUploadingImage = false);
      _showToastMessage('✅ Photo uploaded successfully');

      return downloadUrl;
    } catch (e) {
      debugPrint('❌ Upload error: $e');
      setState(() => _isUploadingImage = false);
      _showToastMessage('❌ Failed to upload photo', isSuccess: false);
      return null;
    }
  }

  String? _validateName(String? value) {
    if (value == null || value.isEmpty) {
      return 'Please enter your name';
    }
    if (value.length < 3) {
      return 'Name must be at least 3 characters';
    }
    return null;
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) {
      _showToastMessage('⚠️ Please fix the errors in the form', isSuccess: false);
      return;
    }

    setState(() => _isLoading = true);
    HapticFeedback.mediumImpact();

    try {
      String? photoUrl;

      // Step 1: upload a newly-picked photo, or resolve a staged removal
      // to an explicit empty string (see _photoRemoved's own comment for
      // why null can't represent "cleared").
      if (_pickedImage != null) {
        photoUrl = await _uploadPhotoToFirebase(_pickedImage!);
        if (photoUrl == null) {
          setState(() => _isLoading = false);
          return;
        }
      } else if (_photoRemoved) {
        photoUrl = '';
      }

      if (!mounted) return;

      // Step 2: Update profile via AuthProvider
      final authProvider =
          Provider.of<app_auth.AuthProvider>(context, listen: false);

      // phone/dateOfBirth are deliberately NOT sent here — phone is
      // read-only on this screen (ChangePhoneScreen's verified flow only),
      // and dateOfBirth saves immediately through its own picker (see
      // _changeDateOfBirth) since firestore.rules blocks it from this
      // plain profile-edit write regardless of value.
      final success = await authProvider.updateUserProfile(
        name: _nameController.text.trim(),
        photoUrl: photoUrl,
        gender: _gender,
      );

      if (!mounted) return;

      if (success) {
        _photoRemoved = false;
        _showToastMessage('✅ Profile updated successfully!');
        Future.delayed(const Duration(milliseconds: 800), () {
          if (mounted) {
            Navigator.pop(context);
          }
        });
      } else {
        _showToastMessage('❌ ${authProvider.error ?? 'Failed to update profile'}', isSuccess: false);
        setState(() => _isLoading = false);
      }
    } catch (e) {
      debugPrint('❌ Save profile error: $e');
      if (mounted) {
        _showToastMessage('❌ Error: ${e.toString()}', isSuccess: false);
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _pickDateOfBirth() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _dateOfBirth ??
          DateTime(now.year - kMinimumProfileAgeYears, now.month, now.day),
      firstDate: DateTime(now.year - 120),
      // Same 18+ bound complete_profile_screen.dart's own picker enforces,
      // and changeDateOfBirth.ts re-checks server-side regardless.
      lastDate: DateTime(now.year - kMinimumProfileAgeYears, now.month, now.day),
      helpText: 'Select your date of birth',
    );
    if (picked == null || !mounted) return;
    if (_dateOfBirth != null &&
        picked.year == _dateOfBirth!.year &&
        picked.month == _dateOfBirth!.month &&
        picked.day == _dateOfBirth!.day) {
      return;
    }

    setState(() => _isSavingDateOfBirth = true);
    HapticFeedback.mediumImpact();

    final authProvider = Provider.of<app_auth.AuthProvider>(context, listen: false);
    final success = await authProvider.changeDateOfBirth(dateOfBirth: picked);

    if (!mounted) return;
    setState(() => _isSavingDateOfBirth = false);

    if (success) {
      setState(() => _dateOfBirth = picked);
      _showToastMessage('✅ Date of birth updated');
    } else {
      _showToastMessage(
        '❌ ${authProvider.error ?? 'Failed to update date of birth'}',
        isSuccess: false,
      );
    }
  }

  Future<void> _pickGender(bool isDark) async {
    final selected = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: const EdgeInsets.all(20),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: isDark ? Colors.grey[700] : Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'Select Gender',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
              const SizedBox(height: 16),
              for (final option in _genderOptions)
                RadioListTile<String>(
                  value: option['value']!,
                  groupValue: _gender,
                  onChanged: (value) => Navigator.pop(context, value),
                  title: Text(
                    option['label']!,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                  ),
                  activeColor: isDark ? AppColors.primaryLight : const Color(0xFF2D7D3C),
                  contentPadding: EdgeInsets.zero,
                ),
            ],
          ),
        ),
      ),
    );
    if (selected != null && mounted) {
      setState(() => _gender = selected);
    }
  }

  Future<void> _pickImage(bool isDark) async {
    final ImagePicker picker = ImagePicker();
    final hasExistingPhoto =
        _pickedImage != null || (_photoUrl != null && _photoUrl!.isNotEmpty);
    try {
      HapticFeedback.lightImpact();

      showModalBottomSheet(
        context: context,
        backgroundColor: Colors.transparent,
        isScrollControlled: true,
        builder: (context) => Container(
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          padding: const EdgeInsets.all(20),
          child: SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: isDark ? Colors.grey[700] : Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  'Change Photo',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: _buildPhotoSourceButton(
                        icon: Icons.camera_alt_outlined,
                        label: 'Camera',
                        onTap: () async {
                          Navigator.pop(context);
                          final XFile? image = await picker.pickImage(
                            source: ImageSource.camera,
                            maxWidth: 1024,
                            maxHeight: 1024,
                            imageQuality: 85,
                          );

                          if (image != null) {
                            setState(() {
                              _pickedImage = image;
                            });
                          }
                        },
                        isDark: isDark
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildPhotoSourceButton(
                        icon: Icons.image_outlined,
                        label: 'Gallery',
                        onTap: () async {
                          Navigator.pop(context);
                          final XFile? image = await picker.pickImage(
                            source: ImageSource.gallery,
                            maxWidth: 1024,
                            maxHeight: 1024,
                            imageQuality: 85,
                          );

                          if (image != null) {
                            setState(() {
                              _pickedImage = image;
                            });
                          }
                        },
                        isDark: isDark
                      ),
                    ),
                  ],
                ),
                if (hasExistingPhoto) ...[
                  const SizedBox(height: 12),
                  _buildRemovePhotoButton(isDark),
                ],
              ],
            ),
          ),
        ),
      );
    } catch (e) {
      _showToastMessage('❌ Error picking image', isSuccess: false);
      debugPrint('Image picker error: $e');
    }
  }

  // PROFILE-13: full-width, distinct from the two square Camera/Gallery
  // tiles above since a destructive list-row reads better than a third
  // square tile the same size as "take a new photo". Stages the removal
  // the same way a newly-picked photo stages (see _photoRemoved) — nothing
  // is actually cleared server-side until Save Changes.
  Widget _buildRemovePhotoButton(bool isDark) {
    return SizedBox(
      width: double.infinity,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            Navigator.pop(context);
            setState(() {
              _pickedImage = null;
              _photoUrl = null;
              _photoRemoved = true;
            });
          },
          borderRadius: BorderRadius.circular(14),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF3B1E1E) : const Color(0xFFFEF2F2),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: isDark ? const Color(0xFF7F1D1D) : const Color(0xFFFECACA)),
            ),
            child: Row(
              children: [
                Icon(Icons.delete_outline_rounded, size: 20, color: isDark ? const Color(0xFFFCA5A5) : const Color(0xFFDC2626)),
                const SizedBox(width: 10),
                Text(
                  'Remove Photo',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: isDark ? const Color(0xFFFCA5A5) : const Color(0xFFDC2626),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPhotoSourceButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    required bool isDark
  }) {
    final color = isDark ? AppColors.primaryLight : const Color(0xFF2D7D3C);

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDark ? Colors.grey[800]! : Colors.grey.shade200,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.02),
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
            padding: const EdgeInsets.symmetric(vertical: 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: color, size: 24),
                ),
                const SizedBox(height: 12),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // PROFILE-13: was a generic person icon on a gradient; now the same
  // Avatar_Icon.png fallback profile_screen.dart's own _buildAvatarImage
  // already uses, so a signed-in user with no photo sees the same
  // placeholder on both screens rather than two different ones.
  Widget _buildDefaultAvatar(bool isDark) {
    return Image.asset(
      'assets/images/Profile/Avatar_Icon.png',
      fit: BoxFit.cover,
    );
  }

  // --- New Widgets matching Profile Screen ---

  // PROFILE-13: swapped the photo-hero background for the owner's new
  // transparent leafy asset (profile-detail_bg.png, distinct from
  // profile_bg.png — this one carries its own soft translucent circle,
  // drawn specifically for an avatar to sit over) and folded the avatar +
  // name into heroContent itself, so the whole "who you are, and how to
  // change it" block is one compact unit instead of two separate slivers.
  // Still the same canonical packages/agrimore_ui StickyPhotoHeaderSliver
  // (PROFILE-12) underneath — only backgroundImage, expandedHeight and
  // heroContent are this screen's own.
  //
  // PROFILE-14: the hero's own title/subtitle now cross-fades OUT (fade +
  // a small downward slide) as the header collapses, complementing the
  // pinned title/subtitle fading IN via the same `collapse` value —
  // there's never a moment with both fully visible. collapsedSubtitle is
  // new on the shared widget (PROFILE-14 too); Profile screen doesn't pass
  // it and keeps its own single-line collapsed title unchanged.
  Widget _buildHeaderSliver(bool isDark) {
    return StickyPhotoHeaderSliver(
      collapse: headerCollapse,
      collapsedTitle: 'Edit Profile',
      collapsedSubtitle: 'Keep your information up to date',
      backgroundImage: 'assets/images/Profile/profile-detail_bg.png',
      isDark: isDark,
      expandedHeight: 296,
      onBack: (_isLoading || _isUploadingImage) ? null : () => Navigator.pop(context),
      heroContent: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Opacity(
            opacity: 1 - headerCollapse,
            child: Transform.translate(
              offset: Offset(0, headerCollapse * 6),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Edit Profile',
                    style: TextStyle(
                      color: isDark ? Colors.white : Colors.black87,
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Keep your information up to date',
                    style: TextStyle(
                      color: isDark ? Colors.white70 : Colors.black54,
                      fontSize: 12.5,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),
          Center(
            child: ScaleTransition(
              scale: _avatarScale,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildAvatarStack(isDark),
                  const SizedBox(height: 10),
                  // Live, not a snapshot: _nameController is the same
                  // controller the Full Name field below edits, so typing
                  // there updates this label immediately rather than only
                  // after Save Changes.
                  AnimatedBuilder(
                    animation: _nameController,
                    builder: (context, _) {
                      final name = _nameController.text.trim();
                      return Text(
                        name.isEmpty ? 'Your Name' : name,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: isDark ? Colors.white : Colors.black87,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAvatarStack(bool isDark) {
    return Center(
      child: SizedBox(
        width: 120,
        height: 120,
        child: Stack(
            children: [
              Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: isDark ? AppColors.primaryLight.withValues(alpha: 0.5) : const Color(0xFF2D7D3C).withValues(alpha: 0.5),
                    width: 2
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.1),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: ClipOval(
                  child: _pickedImage != null
                      ? FutureBuilder<Uint8List>(
                          future: _pickedImage!.readAsBytes(),
                          builder: (context, snapshot) {
                            if (snapshot.hasData) {
                              return Image.memory(
                                snapshot.data!,
                                fit: BoxFit.cover,
                              );
                            }
                            return Center(
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: isDark ? AppColors.primaryLight : const Color(0xFF2D7D3C),
                              ),
                            );
                          },
                        )
                      : (_photoUrl != null && _photoUrl!.isNotEmpty
                          ? Image.network(
                              _photoUrl!,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) {
                                return _buildDefaultAvatar(isDark);
                              },
                              loadingBuilder: (context, child, progress) {
                                if (progress == null) return child;
                                return Center(child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: isDark ? AppColors.primaryLight : const Color(0xFF2D7D3C),
                                ));
                              },
                            )
                          : _buildDefaultAvatar(isDark)),
                ),
              ),
              Positioned(
                bottom: 0,
                right: 0,
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: (_isUploadingImage || _isLoading)
                        ? null
                        : () => _pickImage(isDark),
                    borderRadius: BorderRadius.circular(50),
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: isDark ? AppColors.primaryLight : const Color(0xFF2D7D3C),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: isDark ? const Color(0xFF121212) : Colors.grey[50]!,
                          width: 3,
                        ),
                        boxShadow: [
                           BoxShadow(
                            color: (isDark ? AppColors.primaryLight : const Color(0xFF2D7D3C)).withValues(alpha: 0.4),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: _isUploadingImage
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                valueColor:
                                    AlwaysStoppedAnimation(Colors.white),
                                strokeWidth: 2,
                              ),
                            )
                          : const Icon(
                              Icons.edit_outlined,
                              color: Colors.white,
                              size: 18,
                            ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
  }

  // PROFILE-15: replaces _buildTextFormCard/_buildVerifiedFieldCard/
  // _buildEditableFieldCard's three-separate-cards-per-field layout with
  // one continuous card per section (Personal Information, Personal
  // Details), each row sharing this same compact icon+content+trailing
  // frame with a subtle inset divider between rows instead of a card gap
  // + shadow per field. `child` overrides the label/value column entirely
  // (used for Full Name's real TextFormField — every other row uses the
  // plain label/value/helperText text column).
  Widget _buildCompactRow({
    required IconData icon,
    required bool isDark,
    String? label,
    String? value,
    String? placeholder,
    String? helperText,
    Widget? child,
    Widget? trailing,
    VoidCallback? onTap,
  }) {
    final tileColor = isDark ? AppColors.primaryLight : const Color(0xFF2D7D3C);
    final hasValue = value != null && value.trim().isNotEmpty;

    final content = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: tileColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(9),
            ),
            child: Icon(icon, color: tileColor, size: 16),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: child ??
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      label!,
                      style: TextStyle(
                        fontSize: 10.5,
                        color: isDark ? Colors.grey[400] : Colors.grey[600],
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    Text(
                      hasValue ? value : (placeholder ?? ''),
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: hasValue
                            ? (isDark ? Colors.white : Colors.black87)
                            : (isDark ? Colors.grey[600] : Colors.grey[400]),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (helperText != null)
                      Text(
                        helperText,
                        style: TextStyle(
                          fontSize: 9.5,
                          color: isDark ? Colors.grey[500] : Colors.grey[500],
                        ),
                      ),
                  ],
                ),
          ),
          if (trailing != null) ...[const SizedBox(width: 6), trailing],
        ],
      ),
    );

    return onTap != null
        ? Material(
            color: Colors.transparent,
            child: InkWell(onTap: onTap, child: content),
          )
        : content;
  }

  // A thin inset divider between rows in the same compact card — indented
  // to align with where each row's own label/value text starts (past the
  // icon), not full-bleed, matching the "subtle dividers" ask.
  Widget _buildRowDivider(bool isDark) {
    return Padding(
      padding: const EdgeInsets.only(left: 57),
      child: Container(height: 1, color: isDark ? Colors.grey[800] : Colors.grey.shade200),
    );
  }

  // One card, N rows, dividers between (not after the last). Same
  // card-level shadow/border every field used to carry individually.
  Widget _buildCompactCard({required bool isDark, required List<Widget> rows}) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDark ? Colors.grey[800]! : Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          for (var i = 0; i < rows.length; i++) ...[
            rows[i],
            if (i < rows.length - 1) _buildRowDivider(isDark),
          ],
        ],
      ),
    );
  }

  Widget _buildCompactChangeButton(bool isDark, VoidCallback onTap) {
    final tileColor = isDark ? AppColors.primaryLight : const Color(0xFF2D7D3C);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: tileColor.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            'CHANGE',
            style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800, color: tileColor, letterSpacing: 0.3),
          ),
        ),
      ),
    );
  }

  String _formatDate(DateTime d) {
    const months = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December',
    ];
    return '${d.day} ${months[d.month - 1]} ${d.year}';
  }

  String _genderLabel(String? value) {
    if (value == null) return '';
    return _genderOptions
        .firstWhere((o) => o['value'] == value, orElse: () => const {'label': ''})['label']!;
  }

  // Icon-in-circle + title + subtitle section header, matching the
  // reference mockup's "Personal Information"/"Personal Details" cards.
  // [trailingBadge] renders the mockup's "✓ Verified" pill on the second
  // section only.
  Widget _buildSectionHeader({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool isDark,
    bool trailingBadge = false,
  }) {
    final tileColor = isDark ? AppColors.primaryLight : const Color(0xFF2D7D3C);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(color: tileColor, shape: BoxShape.circle),
            child: Icon(icon, color: Colors.white, size: 17),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 10.5,
                    color: isDark ? Colors.grey[400] : Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
          if (trailingBadge)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
              decoration: BoxDecoration(
                color: tileColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.verified_rounded, size: 12.5, color: tileColor),
                  const SizedBox(width: 4),
                  Text(
                    'Verified',
                    style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800, color: tileColor),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  // --- End New Widgets ---

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDark = themeProvider.isDarkMode;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF121212) : const Color(0xFFF5F5F5),
      body: Stack(
        children: [
          FadeTransition(
            opacity: _fadeAnimation,
            child: SlideTransition(
              position: _slideAnimation,
              child: CustomScrollView(
                controller: stickyHeaderScrollController,
                physics: const ClampingScrollPhysics(),
                slivers: [
                  _buildHeaderSliver(isDark),

                  SliverToBoxAdapter(
                    child: Padding(
                      // PROFILE-13: top inset restored — the avatar/name
                      // block that used to sit in its own sliver (with its
                      // own vertical padding) now ends flush with the
                      // hero's own expandedHeight, so this section needs
                      // its own breathing room again.
                      padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
                      child: Form(
                        key: _formKey,
                        autovalidateMode: AutovalidateMode.onUserInteraction,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildSectionHeader(
                              icon: Icons.person_outline_rounded,
                              title: 'Personal Information',
                              subtitle: 'Manage your basic account details',
                              isDark: isDark,
                            ),
                            _buildCompactCard(
                              isDark: isDark,
                              rows: [
                                _buildCompactRow(
                                  icon: Icons.person_outline_rounded,
                                  isDark: isDark,
                                  child: TextFormField(
                                    controller: _nameController,
                                    validator: _validateName,
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w700,
                                      color: isDark ? Colors.white : Colors.black87,
                                    ),
                                    decoration: InputDecoration(
                                      labelText: 'Full Name',
                                      labelStyle: TextStyle(
                                        fontSize: 10.5,
                                        color: isDark ? Colors.grey[400] : Colors.grey[600],
                                        fontWeight: FontWeight.w500,
                                      ),
                                      border: InputBorder.none,
                                      isDense: true,
                                      contentPadding: EdgeInsets.zero,
                                      errorStyle: const TextStyle(height: 0.1, fontSize: 9),
                                    ),
                                  ),
                                ),
                                _buildCompactRow(
                                  icon: Icons.phone_outlined,
                                  isDark: isDark,
                                  label: 'Phone Number',
                                  value: _phoneController.text,
                                  placeholder: 'Add mobile number',
                                  trailing: _buildCompactChangeButton(isDark, () async {
                                    final newPhone = await Navigator.push<String>(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => ChangePhoneScreen(
                                          currentPhone: _phoneController.text.trim(),
                                        ),
                                      ),
                                    );
                                    if (newPhone != null && newPhone.isNotEmpty && mounted) {
                                      setState(() => _phoneController.text = newPhone);
                                      _showToastMessage('Mobile number updated to $newPhone');
                                    }
                                  }),
                                ),
                                _buildCompactRow(
                                  icon: Icons.email_outlined,
                                  isDark: isDark,
                                  label: 'Email Address',
                                  value: _emailController.text,
                                  placeholder: 'Add email address',
                                  trailing: _buildCompactChangeButton(isDark, () async {
                                    final newEmail = await Navigator.push<String>(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => ChangeEmailScreen(
                                          currentEmail: _emailController.text.trim(),
                                        ),
                                      ),
                                    );
                                    if (newEmail != null && newEmail.isNotEmpty && mounted) {
                                      setState(() => _emailController.text = newEmail);
                                      _showToastMessage('Email updated to $newEmail');
                                    }
                                  }),
                                ),
                              ],
                            ),
                            const SizedBox(height: 14),

                            _buildSectionHeader(
                              icon: Icons.badge_outlined,
                              title: 'Personal Details',
                              subtitle: 'Collected when you completed your profile',
                              isDark: isDark,
                              trailingBadge: true,
                            ),
                            _buildCompactCard(
                              isDark: isDark,
                              rows: [
                                _buildCompactRow(
                                  icon: Icons.cake_outlined,
                                  isDark: isDark,
                                  label: 'Date of Birth',
                                  value: _dateOfBirth != null ? _formatDate(_dateOfBirth!) : '',
                                  placeholder: 'Add date of birth',
                                  helperText: 'Tap to update your date of birth',
                                  onTap: _isSavingDateOfBirth ? null : _pickDateOfBirth,
                                  trailing: _isSavingDateOfBirth
                                      ? SizedBox(
                                          width: 14,
                                          height: 14,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            color: isDark ? AppColors.primaryLight : const Color(0xFF2D7D3C),
                                          ),
                                        )
                                      : Icon(Icons.chevron_right_rounded, size: 18, color: isDark ? Colors.grey[600] : Colors.grey[400]),
                                ),
                                _buildCompactRow(
                                  icon: Icons.wc_rounded,
                                  isDark: isDark,
                                  label: 'Gender',
                                  value: _genderLabel(_gender),
                                  placeholder: 'Add gender',
                                  helperText: 'Tap to update your gender',
                                  onTap: () => _pickGender(isDark),
                                  trailing: Icon(Icons.chevron_right_rounded, size: 18, color: isDark ? Colors.grey[600] : Colors.grey[400]),
                                ),
                              ],
                            ),
                            const SizedBox(height: 20),

                            // Save Button
                            Container(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    (isDark ? AppColors.primaryLight : const Color(0xFF2D7D3C)).withValues(alpha: _isLoading || _isUploadingImage ? 0.7 : 1.0),
                                    (isDark ? AppColors.primaryLight : const Color(0xFF2D7D3C)).withValues(alpha: _isLoading || _isUploadingImage ? 0.5 : 0.8),
                                  ],
                                ),
                                borderRadius: BorderRadius.circular(14),
                                boxShadow: [
                                  BoxShadow(
                                    color: (isDark ? AppColors.primaryLight : const Color(0xFF2D7D3C)).withValues(alpha: 0.25),
                                    blurRadius: 12,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: Material(
                                color: Colors.transparent,
                                child: InkWell(
                                  onTap: (_isLoading || _isUploadingImage)
                                      ? null
                                      : _saveProfile,
                                  borderRadius: BorderRadius.circular(14),
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(vertical: 14),
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Text(
                                          _isUploadingImage ? 'Uploading...' : (_isLoading ? 'Saving...' : 'Save Changes'),
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 15,
                                            fontWeight: FontWeight.w800,
                                          ),
                                        ),
                                        const SizedBox(width: 8),

                                        if (_isLoading || _isUploadingImage)
                                          const SizedBox(
                                            width: 18,
                                            height: 18,
                                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)
                                          )
                                        else
                                          const Icon(Icons.arrow_forward_rounded, color: Colors.white, size: 18),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 10),
                            Text(
                              'Name and gender are saved when you tap Save Changes. '
                              'Phone, email, and date of birth update immediately and require verification.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 11,
                                height: 1.4,
                                color: isDark ? Colors.grey[500] : Colors.grey[600],
                              ),
                            ),
                            const SizedBox(height: 12),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Enhanced Toast (from Profile Screen)
          if (_showToast)
            SafeArea(
              bottom: false,
              child: SlideTransition(
                position: _toastSlideAnimation,
                child: FadeTransition(
                  opacity: _toastFadeAnimation,
                  child: ScaleTransition(
                    scale: _toastScaleAnimation,
                    child: Container(
                      margin: const EdgeInsets.all(16),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [_toastColor, _toastColor.withValues(alpha: 0.9)],
                        ),
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: _toastColor.withValues(alpha: 0.4),
                            blurRadius: 20,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.2),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(_toastIcon, color: Colors.white, size: 18),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              _toastMessage,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
