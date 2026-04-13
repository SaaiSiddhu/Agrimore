// lib/screens/user/home/widgets/banner_slider.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:carousel_slider/carousel_slider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:agrimore_ui/agrimore_ui.dart';
import 'package:agrimore_ui/agrimore_ui.dart';
import '../../../../providers/banner_provider.dart';
import '../../../../app/routes.dart';
import 'package:agrimore_core/agrimore_core.dart';

class BannerSlider extends StatefulWidget {
  const BannerSlider({Key? key}) : super(key: key);

  @override
  State<BannerSlider> createState() => _BannerSliderState();
}

class _BannerSliderState extends State<BannerSlider> {
  int _currentBanner = 0;

  @override
  Widget build(BuildContext context) {
    return Consumer<BannerProvider>(
      builder: (context, bannerProvider, child) {
        if (bannerProvider.isLoading) {
          return _buildLoadingSkeleton();
        }

        final List<BannerModel> banners = bannerProvider.activeBanners;

        if (banners.isEmpty) {
          return const SizedBox.shrink();
        }

        return Stack(
          children: [
            CarouselSlider.builder(
              itemCount: banners.length,
              itemBuilder: (context, index, realIndex) {
                final banner = banners[index];
                return _buildBannerCard(context, banner);
              },
              options: CarouselOptions(
                height: 240,
                viewportFraction: 1.0, // Full width
                autoPlay: banners.length > 1,
                autoPlayInterval: const Duration(seconds: 4),
                autoPlayAnimationDuration: const Duration(milliseconds: 800),
                autoPlayCurve: Curves.fastOutSlowIn,
                enlargeCenterPage: false, // No enlargement for full-width
                enableInfiniteScroll: banners.length > 1,
                onPageChanged: (index, reason) {
                  if (!mounted) return;
                  setState(() => _currentBanner = index);
                },
              ),
            ),
            // Indicators on banner
            if (banners.length > 1)
              Positioned(
                bottom: 12,
                left: 0,
                right: 0,
                child: _buildIndicators(banners.length),
              ),
          ],
        );
      },
    );
  }

  Widget _buildBannerCard(BuildContext context, BannerModel banner) {
    final color = _hexToColor(banner.colorHex);

    return GestureDetector(
      onTap: () {
        if (banner.targetRoute != null && banner.targetRoute!.isNotEmpty) {
          AppRoutes.navigateTo(context, banner.targetRoute!);
        }
      },
      child: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(0), // Edge-to-edge
          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha: 0.2),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(0),
          child: Stack(
            fit: StackFit.expand,
            children: [
              // Background image
              CachedNetworkImage(
                imageUrl: banner.imageUrl,
                fit: BoxFit.cover,
                placeholder: (context, url) => Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [color.withOpacity(0.2), color.withOpacity(0.4)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                  child: const Center(
                    child: SizedBox(
                      width: 28,
                      height: 28,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ),
                ),
                errorWidget: (context, url, error) => Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [color, color.withOpacity(0.7)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                  child: const Center(
                    child: Icon(Icons.error_outline, color: Colors.white, size: 36),
                  ),
                ),
              ),

              // Gradient overlay
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.black.withOpacity(0.7),
                      Colors.transparent,
                    ],
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                  ),
                ),
              ),

              // Text content
              Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    if (banner.iconName.isNotEmpty)
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.25),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          _getIconData(banner.iconName),
                          size: 30,
                          color: Colors.white,
                        ),
                      ),
                    const SizedBox(height: 12),
                    Text(
                      banner.title,
                      style: AppTextStyles.headlineMedium.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        shadows: [
                          Shadow(
                            color: Colors.black.withOpacity(0.5),
                            blurRadius: 4,
                          ),
                        ],
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      banner.subtitle,
                      style: AppTextStyles.bodyMedium.copyWith(
                        color: Colors.white.withOpacity(0.95),
                        shadows: [
                          Shadow(
                            color: Colors.black.withOpacity(0.5),
                            blurRadius: 4,
                          ),
                        ],
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildIndicators(int count) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(
        count,
        (index) => AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          width: _currentBanner == index ? 24 : 8,
          height: 8,
          margin: const EdgeInsets.symmetric(horizontal: 4),
          decoration: BoxDecoration(
            color: _currentBanner == index
                ? AppColors.primary
                : AppColors.border,
            borderRadius: BorderRadius.circular(4),
          ),
        ),
      ),
    );
  }

  Widget _buildLoadingSkeleton() {
    return Container(
      height: 200,
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.grey[300],
        borderRadius: BorderRadius.circular(20),
      ),
      child: const Center(
        child: CircularProgressIndicator(),
      ),
    );
  }

  IconData _getIconData(String iconName) {
    switch (iconName) {
      case 'eco':
        return Icons.eco;
      case 'local_shipping':
        return Icons.local_shipping;
      case 'local_offer':
        return Icons.local_offer;
      case 'spa':
        return Icons.spa;
      case 'flash_on':
        return Icons.flash_on;
      case 'new_releases':
        return Icons.new_releases;
      case 'star':
        return Icons.star;
      case 'shopping_bag':
        return Icons.shopping_bag;
      case 'info':
        return Icons.info;
      default:
        return Icons.info_outline;
    }
  }

  Color _hexToColor(String hex) {
    try {
      hex = hex.replaceAll('#', '');
      if (hex.length == 6) {
        hex = 'FF$hex';
      }
      return Color(int.parse(hex, radix: 16));
    } catch (_) {
      return Colors.grey;
    }
  }
}