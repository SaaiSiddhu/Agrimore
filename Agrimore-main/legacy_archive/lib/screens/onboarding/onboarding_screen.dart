import 'package:flutter/material.dart';
import '../../app/themes/app_colors.dart';
import '../../app/themes/app_text_styles.dart';
import '../../app/routes.dart';
import '../../services/shared_preferences_service.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({Key? key}) : super(key: key);

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  final List<OnboardingPage> _pages = [
    OnboardingPage(
      title: 'Welcome to Agrimore',
      description: 'Your one-stop agricultural marketplace for fresh produce and farming supplies',
      icon: Icons.eco,
      color: AppColors.primary,
    ),
    OnboardingPage(
      title: 'Wide Range of Products',
      description: 'Browse through thousands of quality agricultural products at the best prices',
      icon: Icons.shopping_bag,
      color: AppColors.secondary,
    ),
    OnboardingPage(
      title: 'Fast & Secure Delivery',
      description: 'Get your orders delivered quickly and securely right to your doorstep',
      icon: Icons.local_shipping,
      color: AppColors.success,
    ),
    OnboardingPage(
      title: 'Easy Payment Options',
      description: 'Pay conveniently with multiple payment options including COD and online payments',
      icon: Icons.payment,
      color: AppColors.info,
    ),
  ];

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _onPageChanged(int page) {
    setState(() {
      _currentPage = page;
    });
  }

  Future<void> _completeOnboarding() async {
    await SharedPreferencesService.setOnboardingCompleted();
    if (mounted) {
      AppRoutes.navigateAndRemoveUntil(context, AppRoutes.login);
    }
  }

  void _skipOnboarding() {
    _completeOnboarding();
  }

  void _nextPage() {
    if (_currentPage < _pages.length - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    } else {
      _completeOnboarding();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // Skip button
            Align(
              alignment: Alignment.topRight,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: TextButton(
                  onPressed: _skipOnboarding,
                  child: Text(
                    'Skip',
                    style: AppTextStyles.titleMedium.copyWith(
                      color: AppColors.primary,
                    ),
                  ),
                ),
              ),
            ),

            // PageView
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                onPageChanged: _onPageChanged,
                itemCount: _pages.length,
                itemBuilder: (context, index) {
                  return _buildPage(_pages[index]);
                },
              ),
            ),

            // Indicators
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 20),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(
                  _pages.length,
                  (index) => _buildIndicator(index),
                ),
              ),
            ),

            // Next/Get Started button
            Padding(
              padding: const EdgeInsets.all(24.0),
              child: SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: _nextPage,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: Text(
                    _currentPage == _pages.length - 1 
                        ? 'Get Started' 
                        : 'Next',
                    style: AppTextStyles.buttonLarge.copyWith(
                      color: Colors.white,
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

  Widget _buildPage(OnboardingPage page) {
    return Padding(
      padding: const EdgeInsets.all(40.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Icon
          Container(
            width: 200,
            height: 200,
            decoration: BoxDecoration(
              color: page.color.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              page.icon,
              size: 100,
              color: page.color,
            ),
          ),

          const SizedBox(height: 50),

          // Title
          Text(
            page.title,
            style: AppTextStyles.displaySmall,
            textAlign: TextAlign.center,
          ),

          const SizedBox(height: 20),

          // Description
          Text(
            page.description,
            style: AppTextStyles.bodyLarge.copyWith(
              color: AppColors.textSecondary,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildIndicator(int index) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      margin: const EdgeInsets.symmetric(horizontal: 4),
      width: _currentPage == index ? 32 : 8,
      height: 8,
      decoration: BoxDecoration(
        color: _currentPage == index 
            ? AppColors.primary 
            : AppColors.border,
        borderRadius: BorderRadius.circular(4),
      ),
    );
  }
}

class OnboardingPage {
  final String title;
  final String description;
  final IconData icon;
  final Color color;

  OnboardingPage({
    required this.title,
    required this.description,
    required this.icon,
    required this.color,
  });
}
