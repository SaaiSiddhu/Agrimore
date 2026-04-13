import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../../app/themes/app_colors.dart';
import '../../../../app/themes/app_text_styles.dart';

class ProfileHeader extends StatelessWidget {
  final String name;
  final String email;
  final String? photoUrl;

  const ProfileHeader({
    Key? key,
    required this.name,
    required this.email,
    this.photoUrl,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.primary, AppColors.secondary],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(30),
          bottomRight: Radius.circular(30),
        ),
      ),
      child: Column(
        children: [
          // Profile Picture
          Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 4),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.2),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: CircleAvatar(
              radius: 50,
              backgroundColor: Colors.white,
              backgroundImage: photoUrl != null
                  ? CachedNetworkImageProvider(photoUrl!)
                  : null,
              child: photoUrl == null
                  ? const Icon(
                      Icons.person,
                      size: 50,
                      color: AppColors.primary,
                    )
                  : null,
            ),
          ),
          
          const SizedBox(height: 16),
          
          // Name
          Text(
            name,
            style: AppTextStyles.displaySmall.copyWith(
              color: Colors.white,
              fontSize: 24,
            ),
            textAlign: TextAlign.center,
          ),
          
          const SizedBox(height: 4),
          
          // Email
          Text(
            email,
            style: AppTextStyles.bodyLarge.copyWith(
              color: Colors.white.withOpacity(0.9),
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
