import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart'; // ✅ FIXED: Added missing import
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:agrimore_ui/agrimore_ui.dart';
import 'package:agrimore_ui/agrimore_ui.dart';
import '../../../providers/address_provider.dart';
import '../../../providers/theme_provider.dart';
import '../checkout/add_address_screen.dart';

class SavedAddressesScreen extends StatefulWidget {
  const SavedAddressesScreen({Key? key}) : super(key: key);

  @override
  State<SavedAddressesScreen> createState() => _SavedAddressesScreenState();
}

class _SavedAddressesScreenState extends State<SavedAddressesScreen>
    with TickerProviderStateMixin {
  // ============================================
  // ANIMATIONS
  // ============================================
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

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

    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AddressProvider>().loadAddresses();
      _animationController.forward();
    });
  }

  @override
  void dispose() {
    _animationController.dispose();
    _toastAnimationController.dispose();
    _toastTimer?.cancel();
    super.dispose();
  }

  // ============================================
  // SHOW TOAST MESSAGE
  // ============================================
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

  // ============================================
  // DELETE ADDRESS WITH THEME-AWARE DIALOG
  // ============================================
  Future<void> _deleteAddress(String addressId, bool isDark) async {
    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: true,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          margin: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(isDark ? 0.4 : 0.15),
                blurRadius: 30,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // ✅ HEADER
              Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  children: [
                    Container(
                      width: 60,
                      height: 60,
                      decoration: BoxDecoration(
                        color: Colors.red.shade50,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.delete_outline_rounded,
                        size: 30,
                        color: Colors.red.shade600,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Delete Address?',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'This action cannot be undone and will be permanently deleted.',
                      style: TextStyle(
                        color: isDark ? Colors.grey[400] : Colors.grey[600],
                        fontSize: 14,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
              // ✅ ACTIONS
              Container(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(context, false),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          side: BorderSide(
                            color: isDark ? Colors.grey[700]! : Colors.grey[300]!,
                          ),
                        ),
                        child: Text(
                          'Cancel',
                          style: TextStyle(
                            color: isDark ? Colors.white : Colors.black87,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () => Navigator.pop(context, true),
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          backgroundColor: Colors.red,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text(
                          'Delete',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );

    if (confirmed == true && mounted) {
      final success =
          await context.read<AddressProvider>().deleteAddress(addressId);

      if (mounted) {
        _showToastMessage(
          success ? '✅ Address deleted successfully' : '❌ Failed to delete address',
          isSuccess: success,
        );
      }
    }
  }

  // ============================================
  // COMPACT HEADER
  // ============================================
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
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              'Saved Addresses',
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
                  // ============================================
                  // COMPACT HEADER
                  // ============================================
                  SliverToBoxAdapter(child: _buildCompactHeader(isDark)),

                  // ============================================
                  // CONTENT
                  // ============================================
                  Consumer<AddressProvider>(
                    builder: (context, addressProvider, child) {
                      if (addressProvider.isLoading && addressProvider.addresses.isEmpty) {
                        return SliverFillRemaining(
                          child: Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                CircularProgressIndicator(
                                  color: isDark ? AppColors.primaryLight : const Color(0xFF2D7D3C),
                                  strokeWidth: 3,
                                ),
                                const SizedBox(height: 20),
                                Text(
                                  'Loading addresses...',
                                  style: TextStyle(
                                    color: isDark ? Colors.grey[400] : Colors.grey[600],
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      }

                      if (addressProvider.addresses.isEmpty) {
                        return SliverFillRemaining(
                          hasScrollBody: false,
                          child: _buildEmptyState(isDark: isDark)
                        );
                      }

                      return SliverPadding(
                        padding: const EdgeInsets.all(16),
                        sliver: SliverList(
                          delegate: SliverChildBuilderDelegate(
                            (context, index) {
                              final address = addressProvider.addresses[index];
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 12.0),
                                child: _buildAddressCard(
                                  address: address,
                                  isDark: isDark,
                                  onDelete: () => _deleteAddress(address.id, isDark),
                                  onSetDefault: () async {
                                    HapticFeedback.selectionClick();
                                    final success = await addressProvider
                                        .setDefaultAddress(address.id);
                                    if (mounted) {
                                      _showToastMessage(
                                        success ? '✅ Default address updated' : '❌ Failed to update',
                                        isSuccess: success
                                      );
                                    }
                                  },
                                ),
                              );
                            },
                            childCount: addressProvider.addresses.length,
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),

          // ============================================
          // TOAST NOTIFICATION
          // ============================================
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

      // ============================================
      // THEME-AWARE FLOATING ACTION BUTTON
      // ============================================
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          HapticFeedback.mediumImpact();
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const AddAddressScreen(),
            ),
          ).then((result) {
            if (result == true && mounted) {
              context.read<AddressProvider>().loadAddresses();
              _showToastMessage('✅ Address added successfully');
            }
          });
        },
        icon: const Icon(Icons.add_location_alt_outlined),
        label: const Text('Add Address', style: TextStyle(fontWeight: FontWeight.w700)),
        backgroundColor: isDark ? AppColors.primaryLight : const Color(0xFF2D7D3C),
        foregroundColor: Colors.white,
        elevation: 8,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),
    );
  }

  // ============================================
  // BUILD THEME-AWARE ADDRESS CARD
  // ============================================
  Widget _buildAddressCard({
    required dynamic address,
    required VoidCallback onDelete,
    required VoidCallback onSetDefault,
    required bool isDark,
  }) {
    final accentColor = isDark ? AppColors.primaryLight : const Color(0xFF2D7D3C);
    
    return Container(
      decoration: BoxDecoration(
        gradient: address.isDefault
            ? LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  accentColor.withValues(alpha: 0.1),
                  accentColor.withOpacity(0.05),
                ],
              )
            : null,
        color: address.isDefault ? null : (isDark ? const Color(0xFF1E1E1E) : Colors.white),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: address.isDefault
              ? accentColor.withOpacity(0.3)
              : (isDark ? Colors.grey[800]! : Colors.grey[200]!),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: address.isDefault
                ? accentColor.withOpacity(0.1)
                : Colors.black.withOpacity(isDark ? 0.3 : 0.04),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ✅ HEADER
            Row(
              children: [
                // Address Type Badge
                if (address.addressType != null)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: accentColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: accentColor.withOpacity(0.2),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          address.addressType == 'home'
                              ? Icons.home_rounded
                              : address.addressType == 'work'
                                  ? Icons.work_rounded
                                  : Icons.location_on_rounded,
                          size: 14,
                          color: accentColor,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          address.addressType!.toUpperCase(),
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            color: accentColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                const Spacer(),
                // Default Badge
                if (address.isDefault)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: accentColor,
                      borderRadius: BorderRadius.circular(8),
                      boxShadow: [
                        BoxShadow(
                          color: accentColor.withOpacity(0.3),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.check_circle_rounded,
                          size: 12,
                          color: Colors.white,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'DEFAULT',
                          style: TextStyle(
                            color: isDark ? const Color(0xFF121212) : Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),

            const SizedBox(height: 14),

            // ✅ NAME
            Text(
              address.name,
              style: TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 15,
                color: isDark ? Colors.white : Colors.black87,
              ),
            ),

            const SizedBox(height: 10),

            // ✅ PHONE
            Row(
              children: [
                Icon(
                  Icons.phone_outlined,
                  size: 16,
                  color: isDark ? Colors.grey[400] : Colors.grey[600],
                ),
                const SizedBox(width: 10),
                Text(
                  address.phone,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.grey[300] : Colors.grey[700],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 10),

            // ✅ ADDRESS
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.location_on_outlined,
                  size: 16,
                  color: isDark ? Colors.grey[400] : Colors.grey[600],
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    address.fullAddress,
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.grey[300] : Colors.grey[700],
                      height: 1.4
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 18),

            // ✅ ACTION BUTTONS
            Row(
              children: [
                if (!address.isDefault)
                  Expanded(
                    child: OutlinedButton(
                      onPressed: onSetDefault,
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 11),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        side: BorderSide(
                          color: accentColor.withOpacity(0.5),
                          width: 1.5,
                        ),
                      ),
                      child: Text(
                        'Set Default',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          color: accentColor,
                        ),
                      ),
                    ),
                  ),
                if (!address.isDefault) const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton(
                    onPressed: onDelete,
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 11),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      side: BorderSide(
                        color: Colors.red.withOpacity(0.5),
                        width: 1.5,
                      ),
                    ),
                    child: Text(
                      'Delete',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: Colors.red,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ============================================
  // EMPTY STATE
  // ============================================
  Widget _buildEmptyState({required bool isDark}) {
    final accentColor = isDark ? AppColors.primaryLight : const Color(0xFF2D7D3C);

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: 32,
        vertical: 40,
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Icon
          Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  accentColor.withValues(alpha: 0.1),
                  accentColor.withOpacity(0.05),
                ],
              ),
              shape: BoxShape.circle,
              border: Border.all(
                color: accentColor.withOpacity(0.2),
                width: 2,
              ),
            ),
            child: Icon(
              Icons.location_off_outlined,
              size: 50,
              color: accentColor,
            ),
          ),

          const SizedBox(height: 32),

          // Title
          Text(
            'No Saved Addresses',
            style: TextStyle(
              fontWeight: FontWeight.w900,
              fontSize: 20,
              color: isDark ? Colors.white : Colors.black87,
            ),
          ),

          const SizedBox(height: 12),

          // Description
          Text(
            'Add your first delivery address to get started with faster checkout.',
            style: TextStyle(
              color: isDark ? Colors.grey[400] : Colors.grey[600],
              height: 1.5,
              fontSize: 14,
              fontWeight: FontWeight.w500
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 100), // Pushes content up, leaves room for FAB
        ],
      ),
    );
  }
}