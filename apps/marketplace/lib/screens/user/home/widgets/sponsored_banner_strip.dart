// HOME-10: renders the admin-configured SponsoredBannerModel documents on
// Home -- mirrors section_banner_carousel.dart's own visual polish (PageView
// carousel, auto-scroll, page indicators) with two differences: every
// banner always shows a "Sponsored" label (this content is by definition
// sponsored, unlike SectionBannerModel's own optional showAdBadge), and
// tapping one navigates straight to its own linked product.
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:provider/provider.dart';
import 'package:agrimore_core/agrimore_core.dart';
import 'package:agrimore_ui/agrimore_ui.dart';
import '../../../../providers/sponsored_banner_provider.dart';
import '../../../../providers/theme_provider.dart';

class SponsoredBannerStrip extends StatefulWidget {
  const SponsoredBannerStrip({super.key});

  @override
  State<SponsoredBannerStrip> createState() => _SponsoredBannerStripState();
}

class _SponsoredBannerStripState extends State<SponsoredBannerStrip> {
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

  void _handleBannerTap(SponsoredBannerModel banner) {
    if (banner.productId.isEmpty) return;
    HapticFeedback.lightImpact();
    Navigator.pushNamed(context, '/product/${banner.productId}');
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Provider.of<ThemeProvider>(context).isDarkMode;

    return Consumer<SponsoredBannerProvider>(
      builder: (context, provider, _) {
        final banners = provider.activeSponsoredBanners;

        if (banners.isEmpty) return const SizedBox.shrink();

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
              ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: SizedBox(
                  height: 160,
                  child: PageView.builder(
                    controller: _pageController,
                    physics: const ClampingScrollPhysics(),
                    onPageChanged: (page) => setState(() => _currentPage = page),
                    itemCount: banners.length,
                    itemBuilder: (context, index) {
                      final banner = banners[index];
                      return _SponsoredBannerItem(
                        banner: banner,
                        isDark: isDark,
                        onTap: () => _handleBannerTap(banner),
                      );
                    },
                  ),
                ),
              ),
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

class _SponsoredBannerItem extends StatelessWidget {
  final SponsoredBannerModel banner;
  final bool isDark;
  final VoidCallback onTap;

  const _SponsoredBannerItem({
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
          CachedNetworkImage(
            imageUrl: banner.imageUrl,
            fit: BoxFit.cover,
            memCacheWidth: 800,
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

          if (banner.title.isNotEmpty || banner.subtitle.isNotEmpty)
            Positioned(
              left: 16,
              bottom: 12,
              right: 60,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (banner.title.isNotEmpty)
                    Text(
                      banner.title,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                        shadows: [Shadow(color: Colors.black45, blurRadius: 4)],
                      ),
                    ),
                  if (banner.subtitle.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        banner.subtitle,
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

          // Always-shown disclosure -- every document in this collection is
          // by definition sponsored content, unlike SectionBannerModel's own
          // optional showAdBadge.
          Positioned(
            right: 8,
            top: 8,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: Colors.black54,
                borderRadius: BorderRadius.circular(4),
              ),
              child: const Text(
                'Sponsored',
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
