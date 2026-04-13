import 'dart:async';
import 'dart:typed_data';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:firebase_auth/firebase_auth.dart' as auth;
import 'package:agrimore_ui/agrimore_ui.dart';
import '../../../providers/auth_provider.dart' as app_auth;
import '../../../providers/theme_provider.dart';

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({Key? key}) : super(key: key);

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen>
    with TickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();

  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  late AnimationController _avatarController;
  late Animation<double> _avatarScale;

  XFile? _pickedImage;
  String? _photoUrl;
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
      _photoUrl = user.photoUrl;
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

  String? _validatePhone(String? value) {
    if (value == null || value.isEmpty) {
      return 'Please enter your phone number';
    }
    if (value.length < 10) {
      return 'Please enter a valid phone number';
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

      // Step 1: Upload photo if selected
      if (_pickedImage != null) {
        photoUrl = await _uploadPhotoToFirebase(_pickedImage!);
        if (photoUrl == null) {
          setState(() => _isLoading = false);
          return;
        }
      }

      // Step 2: Update profile via AuthProvider
      final authProvider =
          Provider.of<app_auth.AuthProvider>(context, listen: false);

      final success = await authProvider.updateUserProfile(
        name: _nameController.text.trim(),
        phone: _phoneController.text.trim(),
        photoUrl: photoUrl,
      );

      if (!mounted) return;

      if (success) {
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

  Future<void> _pickImage(bool isDark) async {
    final ImagePicker picker = ImagePicker();
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

  Widget _buildDefaultAvatar(bool isDark) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDark
              ? [const Color(0xFF2D3A2D), const Color(0xFF3A4D3A)]
              : [const Color(0xFF2D7D3C), const Color(0xFF3DA34E)],
        ),
      ),
      child: const Center(
        child: Icon(
          Icons.person_rounded,
          size: 60,
          color: Colors.white,
        ),
      ),
    );
  }

  // --- New Widgets matching Profile Screen ---

  Widget _buildCompactHeader(bool isDark) {
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
                  if (!_isLoading && !_isUploadingImage) {
                    HapticFeedback.lightImpact();
                    Navigator.pop(context);
                  }
                },
                borderRadius: BorderRadius.circular(10),
                child: const Padding(
                  padding: EdgeInsets.all(10),
                  child: Icon(Icons.arrow_back_rounded, color: Colors.white, size: 20),
                ),
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              'Edit Profile',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 19,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAvatarSection(bool isDark) {
    return ScaleTransition(
      scale: _avatarScale,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 20),
          child: Stack(
            children: [
              Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: isDark ? AppColors.primaryLight.withOpacity(0.5) : const Color(0xFF2D7D3C).withOpacity(0.5), 
                    width: 2
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(isDark ? 0.3 : 0.1),
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
                            color: (isDark ? AppColors.primaryLight : const Color(0xFF2D7D3C)).withOpacity(0.4),
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
      ),
    );
  }

  Widget _buildTextFormCard({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
    String? Function(String?)? validator,
    required bool isDark,
  }) {
    final tileColor = isDark ? AppColors.primaryLight : const Color(0xFF2D7D3C);

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
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 8, 14, 8),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: tileColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: tileColor, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: TextFormField(
                controller: controller,
                keyboardType: keyboardType,
                validator: validator,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: isDark ? Colors.white : Colors.black87,
                ),
                decoration: InputDecoration(
                  labelText: label,
                  labelStyle: TextStyle(
                    fontSize: 12,
                    color: isDark ? Colors.grey[400] : Colors.grey[600],
                    fontWeight: FontWeight.w500,
                  ),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(vertical: 4),
                  errorStyle: const TextStyle(height: 0.1, fontSize: 10),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- End New Widgets ---

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDark = themeProvider.isDarkMode;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF121212) : Colors.grey[50],
      body: Stack(
        children: [
          FadeTransition(
            opacity: _fadeAnimation,
            child: SlideTransition(
              position: _slideAnimation,
              child: CustomScrollView(
                physics: const BouncingScrollPhysics(),
                slivers: [
                  SliverToBoxAdapter(child: _buildCompactHeader(isDark)),
                  
                  SliverToBoxAdapter(child: _buildAvatarSection(isDark)),

                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                      child: Form(
                        key: _formKey,
                        autovalidateMode: AutovalidateMode.onUserInteraction,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Your Information',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
                                color: isDark ? Colors.grey[400] : Colors.grey[700],
                                letterSpacing: 0.5,
                              ),
                            ),
                            const SizedBox(height: 10),
                            _buildTextFormCard(
                              controller: _nameController,
                              label: 'Full Name',
                              icon: Icons.person_outline_rounded,
                              validator: _validateName,
                              isDark: isDark,
                            ),
                            _buildTextFormCard(
                              controller: _phoneController,
                              label: 'Phone Number',
                              icon: Icons.phone_outlined,
                              keyboardType: TextInputType.phone,
                              validator: _validatePhone,
                              isDark: isDark,
                            ),
                            const SizedBox(height: 24),

                            // Save Button
                            Container(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    (isDark ? AppColors.primaryLight : const Color(0xFF2D7D3C)).withOpacity(_isLoading || _isUploadingImage ? 0.7 : 1.0),
                                    (isDark ? AppColors.primaryLight : const Color(0xFF2D7D3C)).withOpacity(_isLoading || _isUploadingImage ? 0.5 : 0.8),
                                  ],
                                ),
                                borderRadius: BorderRadius.circular(14),
                                boxShadow: [
                                  BoxShadow(
                                    color: (isDark ? AppColors.primaryLight : const Color(0xFF2D7D3C)).withOpacity(0.25),
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
                                        if (_isLoading || _isUploadingImage)
                                          const SizedBox(
                                            width: 18, 
                                            height: 18, 
                                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)
                                          )
                                        else
                                          const Icon(Icons.check_circle_outline_rounded, color: Colors.white, size: 18),
                                        
                                        const SizedBox(width: 10),
                                        
                                        Text(
                                          _isUploadingImage ? 'Uploading...' : (_isLoading ? 'Saving...' : 'Save Changes'),
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 15,
                                            fontWeight: FontWeight.w800,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
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
                          colors: [_toastColor, _toastColor.withOpacity(0.9)],
                        ),
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: _toastColor.withOpacity(0.4),
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
                              color: Colors.white.withOpacity(0.2),
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