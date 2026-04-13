import 'package:flutter/material.dart';

// Splash & Onboarding
import '../screens/splash/splash_screen.dart';
import '../screens/onboarding/onboarding_screen.dart';

// Auth
import '../screens/auth/auth_screen.dart';

// User Screens
import '../screens/user/main_screen.dart';
import '../screens/user/home/home_screen.dart';
import '../screens/user/home/search/search_screen.dart';
import '../screens/user/home/search/search_results_screen.dart';
import '../screens/user/shop/shop_screen.dart';
import '../screens/user/shop/product_details_screen.dart';
import '../screens/user/cart/cart_screen.dart';
import '../screens/user/wishlist/wishlist_screen.dart';
import '../screens/user/profile/profile_screen.dart';

// AI Chat
import '../screens/chat/ai_chat_screen.dart';
import '../screens/chat/chat_history_screen.dart';

// Checkout
import '../screens/user/checkout/checkout_screen.dart';
import '../screens/user/checkout/order_success_screen.dart';

// Orders
import '../screens/user/orders/orders_screen.dart';
import '../screens/user/orders/order_details_screen.dart';
import '../screens/user/orders/order_tracking_screen.dart';

// Models
import '../models/order_model.dart';

// Admin
import '../screens/admin/admin_main_screen.dart';
import '../screens/admin/admin_dashboard.dart';
import '../screens/admin/notifications/send_notification_screen.dart';

// Import banner management screen for admin
import '../screens/admin/banners/banner_management_screen.dart';
// Import coupon management screen (new path)
import '../screens/admin/coupon/coupon_management_screen.dart';
// ✅ Import sponsored banner management
import '../screens/admin/sponsored_banners/sponsored_banner_management_screen.dart';

// Policy Screens
import '../screens/user/policies/terms_and_conditions_screen.dart';
import '../screens/user/policies/privacy_policy_screen.dart';
import '../screens/user/policies/shipping_policy_screen.dart';
import '../screens/user/policies/contact_us_screen.dart';
import '../screens/user/policies/cancellation_refund_screen.dart';

class AppRoutes {
  // ============================================
  // BASE CONFIGURATION
  // ============================================
  static const String baseUrl = 'https://agrimore.in';
  static const String appScheme = 'agroconnect';

  // ============================================
  // ROUTE CONSTANTS - ✅ SPLASH MUST BE ROOT '/'
  // ============================================
  static const String splash = '/';  // ✅ Splash is the root route
  static const String main = '/main';  // ✅ Main screen after splash
  static const String home = '/home';
  static const String search = '/search';
  static const String searchResults = '/search/results';
  static const String wishlist = '/wishlist';
  static const String aiChat = '/ai-chat';
  static const String chatHistory = '/chat-history';
  static const String profile = '/profile';

  // Auth Routes
  static const String onboarding = '/onboarding';
  static const String auth = '/auth';  // ✅ Unified auth screen
  static const String login = '/login';
  static const String register = '/register';
  static const String forgotPassword = '/forgot-password';

  // Shop Routes
  static const String shop = '/shop';
  static const String productDetails = '/product-details';
  static const String productDetail = '/product/:id';
  static const String categoryProducts = '/category/:id';
  static const String categories = '/categories';
  static const String recentlyViewed = '/recently-viewed';
  static const String deals = '/deals';

  // Cart & Checkout
  static const String cart = '/cart';
  static const String checkout = '/checkout';
  static const String orderSuccess = '/order-success';

  // Order Routes
  static const String orders = '/orders';
  static const String orderDetails = '/order-details';
  static const String orderTracking = '/order-tracking';
  static const String myOrders = '/my-orders';

  // Admin Routes
  static const String adminMain = '/admin-main';
  static const String adminDashboard = '/admin-dashboard';
  static const String sendNotification = '/admin/send-notification';
  
  // Added banner management admin route
  static const String bannerManagement = '/admin/banners';
  // Added coupon management admin route (new)
  static const String couponManagement = '/admin/coupons';
  // ✅ Added sponsored banner management admin route
  static const String sponsoredBannerManagement = '/admin/sponsored-banners';

  static const String notifications = '/notifications';

  // Policy Routes
  static const String termsAndConditions = '/terms-and-conditions';
  static const String privacyPolicy = '/privacy-policy';
  static const String shippingPolicy = '/shipping-policy';
  static const String contactUs = '/contact-us';
  static const String cancellationRefund = '/cancellation-refund';

  // ============================================
  // ROUTE GENERATOR
  // ============================================
  static Route<dynamic> onGenerateRoute(RouteSettings settings) {
    try {
      debugPrint('🔄 Navigating to: ${settings.name}');

      // ✅ DYNAMIC ROUTES FIRST
      if (settings.name?.startsWith('/product/') == true) {
        final productId = settings.name!.replaceFirst('/product/', '').split('?')[0].split('#')[0];
        if (productId.isNotEmpty && productId != ':id') {
          return _buildRoute(ProductDetailsScreen(productId: productId), settings);
        }
      }

      if (settings.name?.startsWith('/category/') == true) {
        final categoryId = settings.name!.replaceFirst('/category/', '').split('?')[0].split('#')[0];
        if (categoryId.isNotEmpty && categoryId != ':id') {
          return _buildRoute(ShopScreen(categoryId: categoryId), settings);
        }
      }

      if (settings.name?.startsWith('/order/') == true) {
        final orderId = settings.name!.replaceFirst('/order/', '').split('?')[0].split('#')[0];
        if (orderId.isNotEmpty && orderId != ':id') {
          return _buildRoute(OrderDetailsScreen(orderId: orderId), settings);
        }
      }

      // ✅ STATIC ROUTES
      switch (settings.name) {
        // ✅ SPLASH SCREEN - ROOT ROUTE
        case splash:
        case '/':
          return _buildRoute(const SplashScreen(), settings);

        // Main Navigation
        case main:
          return _buildRoute(const MainScreen(initialIndex: 0), settings);
        case home:
          return _buildRoute(const MainScreen(initialIndex: 0), settings);
        case shop:
          return _buildRoute(const MainScreen(initialIndex: 1), settings);
        case cart:
          return _buildRoute(const MainScreen(initialIndex: 2), settings);
        case wishlist:
          return _buildRoute(const MainScreen(initialIndex: 3), settings);
        case aiChat:
          return _buildRoute(const MainScreen(initialIndex: 4), settings);
        case profile:
          return _buildRoute(const MainScreen(initialIndex: 5), settings);

        // Onboarding
        case onboarding:
          return _buildRoute(const OnboardingScreen(), settings);

        // Auth Routes - All use AuthScreen
        case auth:
        case login:
        case register:
        case forgotPassword:
          return _buildRoute(const AuthScreen(), settings);

        // Search
        case search:
          return _buildRoute(const SearchScreen(), settings);
        case searchResults:
          final query = settings.arguments as String?;
          if (query == null || query.isEmpty) {
            return _buildErrorRoute('Search query is required', settings);
          }
          return _buildRoute(SearchResultsScreen(query: query), settings);

        // Products & Categories
        case productDetails:
          final productId = settings.arguments as String?;
          if (productId == null || productId.isEmpty) {
            return _buildErrorRoute('Product ID is required', settings);
          }
          return _buildRoute(ProductDetailsScreen(productId: productId), settings);
        case categoryProducts:
          final categoryId = settings.arguments as String?;
          if (categoryId == null || categoryId.isEmpty) {
            return _buildErrorRoute('Category ID is required', settings);
          }
          return _buildRoute(ShopScreen(categoryId: categoryId), settings);
        case categories:
          return _buildRoute(const ShopScreen(), settings);
        case recentlyViewed:
          return _buildRoute(const ShopScreen(showRecentlyViewed: true), settings);
        case deals:
          return _buildRoute(const ShopScreen(showDeals: true), settings);

        // Chat
        case chatHistory:
          return _buildRoute(const ChatHistoryScreen(), settings);

        // Checkout
        case checkout:
          return _buildRoute(const CheckoutScreen(), settings);
        case orderSuccess:
          final order = settings.arguments as OrderModel?;
          if (order == null) {
            return _buildErrorRoute('Order data is required', settings);
          }
          return _buildRoute(OrderSuccessScreen(order: order), settings);

        // Orders
        case orders:
        case myOrders:
          return _buildRoute(const OrdersScreen(), settings);
        case orderDetails:
          final orderId = settings.arguments as String?;
          if (orderId == null || orderId.isEmpty) {
            return _buildErrorRoute('Order ID is required', settings);
          }
          return _buildRoute(OrderDetailsScreen(orderId: orderId), settings);
        case orderTracking:
          final order = settings.arguments as OrderModel?;
          if (order == null) {
            return _buildErrorRoute('Order data is required', settings);
          }
          return _buildRoute(OrderTrackingScreen(order: order), settings);

        // Admin
        case adminMain:
          return _buildRoute(const AdminMainScreen(), settings);
        case adminDashboard:
          return _buildRoute(const AdminDashboard(), settings);
        case sendNotification:
          return _buildRoute(const SendNotificationScreen(), settings);
          
        case bannerManagement:
          return _buildRoute(const BannerManagementScreen(), settings);

        case couponManagement:
          return _buildRoute(const CouponManagementScreen(), settings);

        // ✅ Sponsored Banner Management
        case sponsoredBannerManagement:
          return _buildRoute(const SponsoredBannerManagementScreen(), settings);

        // Policy Screens
        case termsAndConditions:
          return _buildRoute(const TermsAndConditionsScreen(), settings);
        case privacyPolicy:
          return _buildRoute(const PrivacyPolicyScreen(), settings);
        case shippingPolicy:
          return _buildRoute(const ShippingPolicyScreen(), settings);
        case contactUs:
          return _buildRoute(const ContactUsScreen(), settings);
        case cancellationRefund:
          return _buildRoute(const CancellationRefundScreen(), settings);
          
        case notifications:
          return _buildRoute(
            const Scaffold(
              body: Center(child: Text('Notifications', style: TextStyle(fontSize: 24))),
            ),
            settings,
          );

        // Default
        default:
          if (settings.name?.startsWith('/search?') == true) {
            final uri = Uri.parse(settings.name!);
            final query = uri.queryParameters['q'];
            if (query != null && query.isNotEmpty) {
              return _buildRoute(SearchResultsScreen(query: query), settings);
            }
          }
          return _buildErrorRoute('No route defined for ${settings.name}', settings);
      }
    } catch (e) {
      debugPrint('❌ Route generation error: $e');
      return _buildErrorRoute('Route Error: $e', settings);
    }
  }

  // ============================================
  // ROUTE BUILDERS
  // ============================================
  static MaterialPageRoute _buildRoute(Widget screen, RouteSettings settings) {
    return MaterialPageRoute(
      settings: settings,
      builder: (_) => screen,
    );
  }

  static MaterialPageRoute _buildErrorRoute(String message, RouteSettings settings) {
    return MaterialPageRoute(
      settings: settings,
      builder: (context) => Scaffold(
        backgroundColor: Colors.grey[50],
        appBar: AppBar(
          title: const Text('Page Not Found'),
          backgroundColor: Colors.red,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => _handleErrorNavigation(context),
          ),
        ),
        body: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(40.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 200,
                  height: 200,
                  decoration: BoxDecoration(
                    color: Colors.red.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.error_outline, size: 100, color: Colors.red),
                ),
                const SizedBox(height: 40),
                const Text('404', style: TextStyle(fontSize: 72, fontWeight: FontWeight.bold, color: Colors.red, letterSpacing: -2)),
                const SizedBox(height: 16),
                const Text('Page Not Found', style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                Text(message, textAlign: TextAlign.center, style: TextStyle(fontSize: 16, color: Colors.grey[600])),
                const SizedBox(height: 40),
                Wrap(
                  spacing: 16,
                  runSpacing: 16,
                  alignment: WrapAlignment.center,
                  children: [
                    ElevatedButton.icon(
                      onPressed: () => navigateAndRemoveUntil(context, main),
                      icon: const Icon(Icons.home, size: 20),
                      label: const Text('Home'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                    OutlinedButton.icon(
                      onPressed: () => _handleErrorNavigation(context),
                      icon: const Icon(Icons.arrow_back, size: 20),
                      label: const Text('Back'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.red,
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                        side: const BorderSide(color: Colors.red),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  static void _handleErrorNavigation(BuildContext context) {
    try {
      if (Navigator.canPop(context)) {
        Navigator.pop(context);
      } else {
        Navigator.pushReplacementNamed(context, main);
      }
    } catch (e) {
      debugPrint('❌ Navigation error: $e');
      Navigator.pushReplacementNamed(context, main);
    }
  }

  // ============================================
  // NAVIGATION HELPERS
  // ============================================
  static Future<dynamic> navigateTo(BuildContext context, String routeName, {dynamic arguments}) {
    try {
      debugPrint('➡️ Navigating to: $routeName');
      return Navigator.pushNamed(context, routeName, arguments: arguments);
    } catch (e) {
      debugPrint('❌ Navigation error: $e');
      return Future.value();
    }
  }

  static Future<dynamic> navigateAndReplace(BuildContext context, String routeName, {dynamic arguments}) {
    try {
      debugPrint('🔄 Replacing with: $routeName');
      return Navigator.pushReplacementNamed(context, routeName, arguments: arguments);
    } catch (e) {
      debugPrint('❌ Replace error: $e');
      return Future.value();
    }
  }

  static Future<dynamic> navigateAndRemoveUntil(BuildContext context, String routeName, {dynamic arguments}) {
    try {
      debugPrint('🔄 Clearing stack to: $routeName');
      return Navigator.pushNamedAndRemoveUntil(context, routeName, (route) => false, arguments: arguments);
    } catch (e) {
      debugPrint('❌ RemoveUntil error: $e');
      return Future.value();
    }
  }

  static void goBack(BuildContext context, {dynamic result}) {
    try {
      if (Navigator.canPop(context)) {
        debugPrint('⬅️ Going back');
        Navigator.pop(context, result);
      } else {
        debugPrint('⚠️ Cannot pop, going to main');
        Navigator.pushReplacementNamed(context, main);
      }
    } catch (e) {
      debugPrint('❌ Go back error: $e');
    }
  }

  static bool canGoBack(BuildContext context) {
    try {
      return Navigator.canPop(context);
    } catch (e) {
      debugPrint('❌ CanGoBack error: $e');
      return false;
    }
  }

  // ============================================
  // QUICK NAVIGATION SHORTCUTS
  // ============================================
  static Future<dynamic> navigateToSearch(BuildContext context, {String? initialQuery}) {
    return navigateTo(context, search, arguments: initialQuery);
  }

  static Future<dynamic> navigateToSearchResults(BuildContext context, String query) {
    return navigateTo(context, searchResults, arguments: query);
  }

  static Future<dynamic> navigateToProductDetails(BuildContext context, String productId) {
    return navigateTo(context, '/product/$productId');
  }

  static Future<dynamic> navigateToCategoryProducts(BuildContext context, String categoryId) {
    return navigateTo(context, '/category/$categoryId');
  }

  static Future<dynamic> navigateToOrders(BuildContext context) {
    return navigateTo(context, orders);
  }

  static Future<dynamic> navigateToOrderDetails(BuildContext context, String orderId) {
    return navigateTo(context, orderDetails, arguments: orderId);
  }

  static Future<dynamic> navigateToOrderTracking(BuildContext context, OrderModel order) {
    return navigateTo(context, orderTracking, arguments: order);
  }

  // ============================================
  // URL GENERATION & DEEP LINKING
  // ============================================
  static String generateProductUrl(String productId) => '$baseUrl/product/$productId';
  static String generateCategoryUrl(String categoryId) => '$baseUrl/category/$categoryId';
  static String generateSearchUrl(String query) => '$baseUrl/search?q=${Uri.encodeComponent(query)}';
  static String generateOrderUrl(String orderId) => '$baseUrl/order/$orderId';
  static String generateOrdersUrl() => '$baseUrl/orders';

  static Future<dynamic> navigateFromUrl(BuildContext context, String url) {
    try {
      debugPrint('🌐 Navigating from URL: $url');
      final uri = Uri.parse(url);
      final path = uri.path;
      final queryParams = uri.queryParameters;

      if (path.startsWith('/product/')) {
        final segments = path.split('/');
        if (segments.length >= 3 && segments[2].isNotEmpty) {
          return navigateTo(context, '/product/${segments[2]}');
        }
      } else if (path.startsWith('/category/')) {
        final segments = path.split('/');
        if (segments.length >= 3 && segments[2].isNotEmpty) {
          return navigateTo(context, '/category/${segments[2]}');
        }
      } else if (path == '/orders' || path == '/my-orders') {
        return navigateToOrders(context);
      } else if (path.startsWith('/order/')) {
        final segments = path.split('/');
        if (segments.length >= 3 && segments[2].isNotEmpty) {
          return navigateToOrderDetails(context, segments[2]);
        }
      } else if (path.contains('/product/')) {
        final segments = path.split('/');
        if (segments.length >= 3) {
          final productId = segments[2];
          debugPrint('📦 Product deep link detected: $productId');
          return navigateFromUrl(context, uri.toString());
        }
      } else if (path.contains('/category/')) {
        final segments = path.split('/');
        if (segments.length >= 3) {
          final categoryId = segments[2];
          debugPrint('📂 Category deep link detected: $categoryId');
          return navigateFromUrl(context, uri.toString());
        }
      }

      debugPrint('⚠️ No matching deep link handler for: $path');
      return navigateTo(context, path);
    } catch (e) {
      debugPrint('❌ URL navigation error: $e');
      return navigateAndRemoveUntil(context, main);
    }
  }
}
