// lib/screens/user/home/widgets/section_banner_carousel.dart
// Carousel banner that appears between product sections
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:provider/provider.dart';
import 'package:agrimore_core/agrimore_core.dart';
import 'package:agrimore_ui/agrimore_ui.dart';
import '../../../../providers/section_banner_provider.dart';
import '../../../../providers/theme_provider.dart';

class SectionBannerCarousel extends StatefulWidget {
  final int afterSection; // Which section this carousel appears after
  
  const SectionBannerCarousel({
    super.key,
    required this.afterSection,
  });

  @override
  State<SectionBannerCarousel> createState() => _SectionBannerCarouselState();
}

class _SectionBannerCarouselState extends State<SectionBannerCarousel> {
  late PageController _pageController;
  Timer? _autoScrollTimer;
  int _currentPage = 0;
  
  @override
  void initState() {
    super.initState();
    _pageController = PageController();
  }

  void _startAutoScroll(int bannerCount) {
    _autoScrollTimer?.cancel();
    if (bannerCount <= 1) return;
    
    _autoScrollTimer = Timer.periodic(const Duration(seconds: 4), (timer) {
      if (mounted && _pageController.hasClients) {
        final nextPage = (_currentPage + 1) % bannerCount;
        _pageController.animateToPage(
          nextPage,
          duration: const Duration(milliseconds: 400),
          curve: Curves.easeInOut,
        );
      }
    });
  }

  @override
  void dispose() {
    _autoScrollTimer?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  void _handleBannerTap(SectionBannerModel banner) {
    if (banner.shopNowUrl != null && banner.shopNowUrl!.isNotEmpty) {
      HapticFeedback.lightImpact();
      // Check if it's an internal route or external URL
      final url = banner.shopNowUrl!;
      if (url.startsWith('/')) {
        // Internal route
        Navigator.pushNamed(context, url);
      } else if (url.startsWith('http')) {
        // External URL - could use url_launcher
        debugPrint('Open external URL: $url');
      } else {
        // Assume it's an internal route
        Navigator.pushNamed(context, '/$url');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Provider.of<ThemeProvider>(context).isDarkMode;
    
    return Consumer<SectionBannerProvider>(
      builder: (context, provider, _) {
        final banners = provider.getBannersAfterSection(widget.afterSection);
        
        if (banners.isEmpty) return const SizedBox.shrink();
        
        // Start auto-scroll after build
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (_autoScrollTimer == null || !_autoScrollTimer!.isActive) {
            _startAutoScroll(banners.length);
          }
        });
        
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Banner Carousel
              ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: SizedBox(
                  height: 240,
                  child: PageView.builder(
                    controller: _pageController,
                    physics: const ClampingScrollPhysics(),
                    onPageChanged: (page) => setState(() => _currentPage = page),
                    itemCount: banners.length,
                    itemBuilder: (context, index) {
                      final banner = banners[index];
                      return _BannerItem(
                        banner: banner,
                        isDark: isDark,
                        onTap: () => _handleBannerTap(banner),
                      );
                    },
                  ),
                ),
              ),
              
              // Page Indicators
              if (banners.length > 1)
                Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(banners.length, (index) {
                      final isActive = index == _currentPage;
                      return AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        margin: const EdgeInsets.symmetric(horizontal: 3),
                        width: isActive ? 20 : 6,
                        height: 6,
                        decoration: BoxDecoration(
                          color: isActive 
                              ? AppColors.primary 
                              : (isDark ? Colors.grey[700] : Colors.grey[300]),
                          borderRadius: BorderRadius.circular(3),
                        ),
                      );
                    }),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

class _BannerItem extends StatelessWidget {
  final SectionBannerModel banner;
  final bool isDark;
  final VoidCallback onTap;
  
  const _BannerItem({
    required this.banner,
    required this.isDark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Banner Image
          CachedNetworkImage(
            imageUrl: banner.imageUrl,
            fit: BoxFit.cover,
            placeholder: (_, __) => Container(
              color: isDark ? Colors.grey[900] : Colors.grey[200],
              child: const Center(
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
            errorWidget: (_, __, ___) => Container(
              color: isDark ? Colors.grey[900] : Colors.grey[200],
              child: const Icon(Icons.image_outlined, size: 40, color: Colors.grey),
            ),
          ),
          
          // Optional Text Overlay (if title/subtitle exists)
          if (banner.hasTextOverlay)
            Positioned(
              left: 16,
              bottom: 50,
              right: 120,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (banner.title != null && banner.title!.isNotEmpty)
                    Text(
                      banner.title!,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                        shadows: [Shadow(color: Colors.black45, blurRadius: 4)],
                      ),
                    ),
                  if (banner.subtitle != null && banner.subtitle!.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        banner.subtitle!,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.white.withValues(alpha: 0.9),
                          shadows: const [Shadow(color: Colors.black45, blurRadius: 4)],
                        ),
                      ),
                    ),
                ],
              ),
            ),
          
          // Shop Now Button (if URL exists)
          if (banner.hasShopButton)
            Positioned(
              left: 16,
              bottom: 12,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.black87,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  banner.buttonText ?? 'Shop now',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          
          // Ad Badge (if enabled)
          if (banner.showAdBadge)
            Positioned(
              right: 8,
              bottom: 8,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Text(
                  'Ad',
                  style: TextStyle(
                    fontSize: 10,
                    color: Colors.white70,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
