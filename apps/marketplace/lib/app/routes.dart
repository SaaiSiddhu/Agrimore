import 'package:flutter/material.dart';

// Splash & Onboarding
import '../screens/auth/auth_wrapper.dart';
import '../screens/auth/auth_guard.dart';
import '../screens/onboarding/onboarding_screen.dart';

// Auth
import '../screens/auth/login_screen.dart';
import '../screens/auth/signup_screen.dart';
import '../screens/auth/complete_profile_screen.dart';
import '../screens/auth/mobile_number_screen.dart';
import '../screens/auth/onboarding_address_screen.dart';

// Landing
import '../screens/landing/landing_screen.dart';

// Legal
import '../screens/legal/terms_screen.dart';
import '../screens/legal/privacy_policy_screen.dart';

// User Screens
import '../screens/user/main_screen.dart';
import '../screens/user/home/search/search_screen.dart';
import '../screens/user/home/search/search_results_screen.dart';
import '../screens/user/shop/shop_screen.dart';
import '../screens/user/shop/product_details_screen.dart';
import '../screens/user/wishlist/wishlist_screen.dart';
import '../screens/business/business_profile_screen.dart';
import '../screens/business/business_feed_screen.dart';

// AI Chat
import '../screens/chat/ai_chat_screen.dart';
import '../screens/chat/chat_history_screen.dart';

// Checkout
import '../screens/user/checkout/checkout_screen.dart';
import '../screens/user/checkout/order_success_screen.dart';
import '../screens/user/checkout/payment_method_screen.dart';

// Orders
import '../screens/user/orders/orders_screen.dart';
import '../screens/user/orders/order_details_screen.dart';
import '../screens/user/orders/order_tracking_screen.dart';

// Profile
import '../screens/user/profile/edit_profile_screen.dart';
import '../screens/user/profile/change_password_screen.dart';
import '../screens/user/profile/saved_addresses_screen.dart';
import '../screens/user/profile/settings_screen.dart';

// Cart
import '../screens/user/cart/coupon_selection_screen.dart';

// Wallet
import '../screens/user/wallet/wallet_screen.dart';
import '../screens/user/wallet/add_money_screen.dart';
import '../screens/user/wallet/transaction_history_screen.dart';
import '../screens/user/wallet/referral_screen.dart';
import '../screens/user/wallet/product_credit_screen.dart';

// Notifications
import '../screens/user/notifications/notifications_screen.dart';

// Offers & Flash Sale
import '../screens/user/offers/offers_screen.dart';
import '../screens/user/flash_sale/flash_sale_screen.dart';

// Rewards
import '../screens/user/rewards/rewards_screen.dart';

// Rate Order
import '../screens/user/orders/rate_order_screen.dart';

// Subscriptions
import '../screens/user/subscriptions/my_subscriptions_screen.dart';
import '../screens/user/subscriptions/subscription_setup_screen.dart';

// RFQ (Phase RFQ-2)
import '../screens/user/rfq/my_rfqs_screen.dart';
import '../screens/user/rfq/rfq_detail_screen.dart';

// Language
import '../screens/user/settings/language_screen.dart';

// Seller
import '../screens/seller/seller_apply_screen.dart';
import '../screens/seller/seller_dashboard_screen.dart';
import '../screens/seller/seller_panel_screen.dart';

// Employee
import '../screens/employee/employee_apply_screen.dart';
import '../screens/employee/onboarding/associate_onboarding_screen.dart';

// Models
import 'package:agrimore_core/agrimore_core.dart';

// 404 Screen
import '../screens/not_found_screen.dart';

class AppRoutes {
  // ============================================
  // BASE CONFIGURATION
  // ============================================
  static const String baseUrl = 'https://agrimore.in';
  static const String appScheme = 'agrimore';

  // ============================================
  // ROUTE CONSTANTS - ✅ SPLASH MUST BE ROOT '/'
  // ============================================
  static const String splash = '/'; // ✅ Splash is the root route
  static const String main = '/main'; // ✅ Main screen after splash
  static const String home = '/home';
  static const String search = '/search';
  static const String searchResults = '/search/results';
  static const String wishlist = '/wishlist';
  static const String businessFeed = '/business-feed';
  // AI Chat
  static const String aiChat = '/ai-chat';
  static const String chatHistory = '/chat-history';
  static const String profile = '/profile';

  // Auth Routes
  static const String onboarding = '/onboarding';
  static const String landing = '/landing'; // ✅ Web landing page
  static const String login = '/login'; // ✅ Email/Password login
  static const String signup = '/signup'; // ✅ New user registration
  static const String completeProfile =
      '/complete-profile'; // ✅ After Google login for profile completion
  static const String forgotPassword = '/forgot-password';

  // ── NEW USER ONBOARDING ──
  static const String mobileNumber = '/mobile-number'; // Step 2: collect phone
  static const String onboardingAddress =
      '/onboarding-address'; // Step 3: set default address
  static const String profileAddAddress =
      '/profile/add-address'; // From profile: add new address
  static const String profileEditAddress =
      '/profile/edit-address'; // From profile: edit existing

  // Legal Routes
  static const String terms = '/terms'; // ✅ Terms and Conditions
  static const String privacyPolicy = '/privacy-policy'; // ✅ Privacy Policy

  // Shop Routes
  static const String shop = '/shop';
  static const String shopWithSearch = '/shop/search';
  static const String productDetails = '/product-details';
  static const String productDetail = '/product/:id';
  static const String categoryProducts = '/category/:id';
  static const String businessProfile = '/business/:id';
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
  // NOTE: there is deliberately no '/order/track' route. It was unreachable —
  // the dynamic `/order/` handler in onGenerateRoute consumed it first, reading
  // the literal word "track" as an order id — and TrackOrderScreen duplicated
  // LiveTrackingScreen, which is what order_details_screen and orders_screen
  // actually use. Both the route and the screen were removed in Phase M1.
  static const String myOrders = '/my-orders';

  // Profile Routes
  static const String editProfile = '/profile/edit';
  static const String changePassword = '/profile/change-password';
  static const String savedAddresses = '/profile/addresses';
  static const String appSettings = '/settings';

  // Checkout Flow Routes
  static const String addAddress = '/checkout/add-address';
  static const String paymentMethod = '/checkout/payment';
  static const String couponSelection = '/cart/coupons';

  static const String notifications = '/notifications';
  static const String support = '/support';

  // Offers & Flash Sale
  static const String offers = '/offers';
  static const String flashSale = '/flash-sale';

  // Rewards
  static const String rewards = '/rewards';

  // Rate Order
  static const String rateOrder = '/rate-order';

  // RFQ (Phase RFQ-2)
  static const String myRfqs = '/my-rfqs';
  static const String rfqDetail = '/rfq-detail';

  // Subscriptions
  static const String mySubscriptions = '/my-subscriptions';
  static const String subscriptionSetup = '/subscription-setup';

  // Language
  static const String language = '/language';

  // Seller Routes
  static const String sellerApply = '/seller/apply';
  static const String sellerPanel = '/seller/panel';
  static const String sellerDashboard = '/seller/dashboard';

  // Employee Routes
  static const String employeeApply = '/employee/apply';
  // Phase 16B-2: the ₹500 Sales Associate onboarding page. Deliberately NOT
  // wrapped in AuthGuard (unlike every route below it) — Workstream 1f
  // requires the fee/benefits/disclosures to render for a signed-out
  // visitor, since getAssociateOnboardingConfig itself requires no auth.
  static const String associateOnboarding = '/employee/onboarding';

  // Wallet Routes
  static const String wallet = '/wallet';
  static const String addMoney = '/wallet/add-money';
  static const String transactionHistory = '/wallet/history';
  static const String referral = '/wallet/referral';
  // Phase E: AgriMore Product Credit history — a separate route from
  // transactionHistory above, deliberately, since credit history is
  // never interleaved into the cash transaction list.
  static const String productCredit = '/wallet/product-credit';

  // ============================================
  // ARGUMENT / SEGMENT RESOLUTION
  // ============================================

  /// Path segments under `/order/` that name a STATIC route rather than an
  /// order id.
  ///
  /// Without this, the dynamic `/order/` handler in [onGenerateRoute] swallows
  /// them: `/order/track` was read as "the order whose id is the word track", so
  /// the static case further down could never execute and the user was shown an
  /// order-detail screen for an order that does not exist. The `/order/track`
  /// route has since been removed as redundant (LiveTrackingScreen already
  /// serves live tracking), but the guard stays — if you ever add a static
  /// `/order/<word>` route, add that word here or it will be shadowed the same way.
  ///
  /// Matching is whole-segment equality on purpose: an order id that merely
  /// *contains* a reserved word (e.g. `track123`) must still resolve normally.
  static const Set<String> _reservedOrderSegments = {'track'};

  /// Resolves an id passed as a route argument, accepting BOTH shapes this app
  /// has historically used: a bare [String] (what every in-app call site passes)
  /// and a [Map] carrying [mapKey] (the shape notification payloads were
  /// forwarded in). Returns null for any other shape, or for a blank id.
  ///
  /// Deliberately type-checked rather than cast. A failed `as` here throws into
  /// [onGenerateRoute]'s outer try/catch, which silently converts the failure
  /// into the 404 screen — and that swallowing is exactly what hid the broken
  /// notification routing. This must not be able to throw.
  static String? _idArgument(Object? arguments, String mapKey) {
    if (arguments is String) {
      final trimmed = arguments.trim();
      return trimmed.isEmpty ? null : trimmed;
    }
    if (arguments is Map) {
      final value = arguments[mapKey];
      if (value is String) {
        final trimmed = value.trim();
        return trimmed.isEmpty ? null : trimmed;
      }
    }
    return null;
  }

  // ============================================
  // ROUTE GENERATOR
  // ============================================
  static Route<dynamic> onGenerateRoute(RouteSettings settings) {
    try {
      debugPrint('🔄 Navigating to: ${settings.name}');

      // ✅ DYNAMIC ROUTES FIRST
      if (settings.name?.startsWith('/product/') == true) {
        final productId = settings.name!
            .replaceFirst('/product/', '')
            .split('?')[0]
            .split('#')[0];
        if (productId.isNotEmpty && productId != ':id') {
          return _buildRoute(
              ProductDetailsScreen(productId: productId), settings);
        }
      }

      // ✅ FIXED: Handle /product without ID - redirect to main
      if (settings.name == '/product' || settings.name == '/product/') {
        return _buildRoute(const MainScreen(initialIndex: 0), settings);
      }

      if (settings.name?.startsWith('/business/') == true) {
        final sellerId = settings.name!
            .replaceFirst('/business/', '')
            .split('?')[0]
            .split('#')[0];
        if (sellerId.isNotEmpty && sellerId != ':id') {
          return _buildRoute(
              BusinessProfileScreen(sellerId: sellerId), settings);
        }
      }

      if (settings.name?.startsWith('/category/') == true) {
        final categoryId = settings.name!
            .replaceFirst('/category/', '')
            .split('?')[0]
            .split('#')[0];
        if (categoryId.isNotEmpty && categoryId != ':id') {
          return _buildRoute(ShopScreen(categoryId: categoryId), settings);
        }
      }

      if (settings.name?.startsWith('/order/') == true) {
        final orderId = settings.name!
            .replaceFirst('/order/', '')
            .split('?')[0]
            .split('#')[0];
        // The reserved-segment check keeps this dynamic handler from swallowing
        // a static `/order/<word>` route — see [_reservedOrderSegments].
        if (orderId.isNotEmpty &&
            orderId != ':id' &&
            !_reservedOrderSegments.contains(orderId)) {
          return _buildRoute(OrderDetailsScreen(orderId: orderId), settings);
        }
      }

      // ✅ STATIC ROUTES
      switch (settings.name) {
        // ✅ ROOT ROUTE - AuthWrapper for all platforms.
        // `splash` IS '/', so a separate `case '/'` here was dead — the analyzer
        // flagged it as unreachable_switch_case.
        case splash:
          // AuthWrapper handles auth persistence and redirects
          return _buildRoute(const AuthWrapper(), settings);

        // Main Navigation - Protected Routes
        case main:
          return _buildRoute(
              const AuthGuard(child: MainScreen(initialIndex: 0)), settings);
        case home:
          return _buildRoute(
              const AuthGuard(child: MainScreen(initialIndex: 0)), settings);
        case shop:
          {
            String? cid;
            String? cname;
            final args = settings.arguments;
            if (args is Map<String, dynamic>) {
              cid = args['categoryId'] as String?;
              cname = args['categoryName'] as String?;
            }
            return _buildRoute(
              AuthGuard(
                child: MainScreen(
                  initialIndex: 1,
                  categoryId: cid,
                  categoryName: cname,
                ),
              ),
              settings,
            );
          }
        case shopWithSearch:
          final searchQuery = settings.arguments as String?;
          return _buildRoute(
            AuthGuard(
                child: MainScreen(initialIndex: 1, searchQuery: searchQuery)),
            settings,
          );
        case cart:
          return _buildRoute(
              const AuthGuard(child: MainScreen(initialIndex: 3)), settings);
        case wishlist:
          return _buildRoute(
              const AuthGuard(child: WishlistScreen()), settings);
        case businessFeed:
          return _buildRoute(
              const AuthGuard(child: BusinessFeedScreen()), settings);
        case profile:
          return _buildRoute(
              const AuthGuard(child: MainScreen(initialIndex: 4)), settings);

        // Onboarding
        case onboarding:
          return _buildRoute(const OnboardingScreen(), settings);

        // Landing Page (Web)
        case landing:
          return _buildRoute(const LandingScreen(), settings);

        // Auth Routes - Email/Password Authentication
        case login:
          return _buildRoute(const LoginScreen(), settings);
        case signup:
          final args = settings.arguments as Map<String, dynamic>?;
          final emailArg = args?['email'] as String?;
          final fromGoogle = args?['fromGoogle'] as bool? ?? false;
          return _buildRoute(
            SignupScreen(
              initialEmail: emailArg,
              fromGoogle: fromGoogle,
            ),
            settings,
          );
        case completeProfile:
          final args = settings.arguments as Map<String, dynamic>?;
          final phoneArg = args?['phone'] as String?;
          if (phoneArg == null || phoneArg.isEmpty) {
            return _buildRoute(const LoginScreen(), settings);
          }
          return _buildRoute(CompleteProfileScreen(phone: phoneArg), settings);
        case forgotPassword:
          return _buildRoute(const LoginScreen(), settings);

        // ── New-user onboarding ──
        case mobileNumber:
          return _buildRoute(const MobileNumberScreen(), settings);
        case onboardingAddress:
          return _buildRoute(
            const OnboardingAddressScreen(isOnboarding: true),
            settings,
          );

        // ── Add / Edit address (from profile) ──
        case profileAddAddress:
          return _buildRoute(
            const OnboardingAddressScreen(isOnboarding: false),
            settings,
          );
        case profileEditAddress:
          final existingAddr = settings.arguments as AddressModel?;
          return _buildRoute(
            OnboardingAddressScreen(
              isOnboarding: false,
              existingAddress: existingAddr,
            ),
            settings,
          );

        // Legal
        case terms:
          return _buildRoute(const TermsScreen(), settings);
        case privacyPolicy:
          return _buildRoute(const PrivacyPolicyScreen(), settings);

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
        // Accepts a bare String id or a {'productId': ...} Map — see
        // [_idArgument] for why both, and why it must not cast.
        case productDetails:
          final productId = _idArgument(settings.arguments, 'productId');
          if (productId == null) {
            return _buildErrorRoute('Product ID is required', settings);
          }
          return _buildRoute(
              ProductDetailsScreen(productId: productId), settings);
        case categoryProducts:
          final categoryId = settings.arguments as String?;
          if (categoryId == null || categoryId.isEmpty) {
            return _buildErrorRoute('Category ID is required', settings);
          }
          return _buildRoute(
            AuthGuard(
              child: MainScreen(
                initialIndex: 1,
                categoryId: categoryId,
              ),
            ),
            settings,
          );
        case categories:
          return _buildRoute(
              const AuthGuard(child: MainScreen(initialIndex: 2)), settings);
        case recentlyViewed:
          return _buildRoute(
              const ShopScreen(showRecentlyViewed: true), settings);
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
        // Accepts a bare String id or an {'orderId': ...} Map — see
        // [_idArgument] for why both, and why it must not cast.
        case orderDetails:
          final orderId = _idArgument(settings.arguments, 'orderId');
          if (orderId == null) {
            return _buildErrorRoute('Order ID is required', settings);
          }
          return _buildRoute(OrderDetailsScreen(orderId: orderId), settings);
        case orderTracking:
          final order = settings.arguments as OrderModel?;
          if (order == null) {
            return _buildErrorRoute('Order data is required', settings);
          }
          return _buildRoute(OrderTrackingScreen(order: order), settings);

        // Profile Routes
        case editProfile:
          return _buildRoute(
              const AuthGuard(child: EditProfileScreen()), settings);
        case changePassword:
          return _buildRoute(
              const AuthGuard(child: ChangePasswordScreen()), settings);
        case savedAddresses:
          return _buildRoute(
              const AuthGuard(child: SavedAddressesScreen()), settings);
        case appSettings:
          return _buildRoute(
              const AuthGuard(child: SettingsScreen()), settings);

        // Checkout Flow Routes
        case addAddress:
          return _buildRoute(
              const AuthGuard(
                  child: OnboardingAddressScreen(isOnboarding: false)),
              settings);
        case paymentMethod:
          final paymentArgs = settings.arguments as Map<String, dynamic>?;
          final address = paymentArgs?['address'] as AddressModel?;
          final total = paymentArgs?['total'] as double? ?? 0.0;
          if (address == null) {
            return _buildErrorRoute(
                'Address is required for payment', settings);
          }
          return _buildRoute(
            AuthGuard(
                child: PaymentMethodScreen(
                    selectedAddress: address, total: total)),
            settings,
          );
        case couponSelection:
          return _buildRoute(
              const AuthGuard(child: CouponSelectionScreen()), settings);

        case notifications:
          return _buildRoute(
              const AuthGuard(child: NotificationsScreen()), settings);
        // AI Chat
        case support:
          return _buildRoute(const AuthGuard(child: AIChatScreen()), settings);

        // Offers & Flash Sale
        case offers:
          return _buildRoute(const AuthGuard(child: OffersScreen()), settings);
        case flashSale:
          return _buildRoute(
              const AuthGuard(child: FlashSaleScreen()), settings);

        // Rewards
        case rewards:
          return _buildRoute(const AuthGuard(child: RewardsScreen()), settings);

        // Rate Order
        case rateOrder:
          final rateOrderId = settings.arguments as String?;
          if (rateOrderId == null || rateOrderId.isEmpty) {
            return _buildErrorRoute(
                'Order ID is required for rating', settings);
          }
          return _buildRoute(
              AuthGuard(child: RateOrderScreen(orderId: rateOrderId)),
              settings);

        // Subscriptions
        case myRfqs:
          return _buildRoute(const AuthGuard(child: MyRfqsScreen()), settings);
        case rfqDetail:
          final rfqId = _idArgument(settings.arguments, 'rfqId');
          if (rfqId == null) {
            return _buildErrorRoute('Quote request ID is required', settings);
          }
          return _buildRoute(
              AuthGuard(child: RfqDetailScreen(rfqId: rfqId)), settings);
        case mySubscriptions:
          return _buildRoute(
              const AuthGuard(child: MySubscriptionsScreen()), settings);
        case subscriptionSetup:
          final subArgs = settings.arguments as Map<String, dynamic>?;
          if (subArgs == null) {
            return _buildErrorRoute('Product data is required', settings);
          }
          return _buildRoute(
            AuthGuard(
              child: SubscriptionSetupScreen(
                product: subArgs['product'] as Map<String, dynamic>,
                qty: subArgs['qty'] as int? ?? 1,
                variant: subArgs['variant'] as Map<String, dynamic>?,
              ),
            ),
            settings,
          );

        // Language
        case language:
          return _buildRoute(const LanguageScreen(), settings);

        // Seller Routes
        case sellerApply:
          return _buildRoute(
              const AuthGuard(child: SellerApplyScreen()), settings);
        case sellerPanel:
          return _buildRoute(
              const AuthGuard(child: SellerPanelScreen()), settings);
        case sellerDashboard:
          return _buildRoute(
              const AuthGuard(child: SellerDashboardScreen()), settings);

        // Employee Routes
        case employeeApply:
          return _buildRoute(
              const AuthGuard(child: EmployeeApplyScreen()), settings);
        // Phase 16B-2, Workstream 1f: deliberately NOT wrapped in AuthGuard.
        // AssociateOnboardingScreen itself decides, per-section, what a
        // signed-out visitor may see (the full info deck) versus what
        // requires auth (the details/payment/confirmation steps) — see its
        // own header comment for why AuthGuard's web-only "swap to
        // LandingScreen" behaviour would defeat that requirement outright.
        case associateOnboarding:
          return _buildRoute(const AssociateOnboardingScreen(), settings);

        // Wallet Routes
        case wallet:
          return _buildRoute(const AuthGuard(child: WalletScreen()), settings);
        case addMoney:
          return _buildRoute(
              const AuthGuard(child: AddMoneyScreen()), settings);
        case transactionHistory:
          return _buildRoute(
              const AuthGuard(child: TransactionHistoryScreen()), settings);
        case referral:
          return _buildRoute(
              const AuthGuard(child: ReferralScreen()), settings);
        case productCredit:
          return _buildRoute(
              const AuthGuard(child: ProductCreditScreen()), settings);

        // Default
        default:
          if (settings.name?.startsWith('/search?') == true) {
            final uri = Uri.parse(settings.name!);
            final query = uri.queryParameters['q'];
            if (query != null && query.isNotEmpty) {
              return _buildRoute(SearchResultsScreen(query: query), settings);
            }
          }
          // Phase ONBOARD-1: the ₹500 onboarding page carrying a
          // `?handoff=<code>` query string (opened from the mobile app's
          // external-browser handoff button) -- `case associateOnboarding:`
          // above only matches the bare path, since Dart's switch is exact
          // string equality. Mirrors the `/search?` special case above.
          if (settings.name?.startsWith('$associateOnboarding?') == true) {
            final uri = Uri.parse(settings.name!);
            final handoffCode = uri.queryParameters['handoff'];
            return _buildRoute(
                AssociateOnboardingScreen(handoffCode: handoffCode), settings);
          }
          return _buildErrorRoute(
              'No route defined for ${settings.name}', settings);
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

  static MaterialPageRoute _buildErrorRoute(
      String message, RouteSettings settings) {
    debugPrint('❌ Route error: $message');
    return MaterialPageRoute(
      settings: settings,
      builder: (context) => const NotFoundScreen(),
    );
  }

  // ============================================
  // NAVIGATION HELPERS
  // ============================================
  static Future<dynamic> navigateTo(BuildContext context, String routeName,
      {dynamic arguments}) {
    try {
      debugPrint('➡️ Navigating to: $routeName');
      return Navigator.pushNamed(context, routeName, arguments: arguments);
    } catch (e) {
      debugPrint('❌ Navigation error: $e');
      return Future.value();
    }
  }

  static Future<dynamic> navigateAndReplace(
      BuildContext context, String routeName,
      {dynamic arguments}) {
    try {
      debugPrint('🔄 Replacing with: $routeName');
      return Navigator.pushReplacementNamed(context, routeName,
          arguments: arguments);
    } catch (e) {
      debugPrint('❌ Replace error: $e');
      return Future.value();
    }
  }

  static Future<dynamic> navigateAndRemoveUntil(
      BuildContext context, String routeName,
      {dynamic arguments}) {
    try {
      debugPrint('🔄 Clearing stack to: $routeName');
      return Navigator.pushNamedAndRemoveUntil(
          context, routeName, (route) => false,
          arguments: arguments);
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
  static Future<dynamic> navigateToSearch(BuildContext context,
      {String? initialQuery}) {
    return navigateTo(context, search, arguments: initialQuery);
  }

  static Future<dynamic> navigateToSearchResults(
      BuildContext context, String query) {
    return navigateTo(context, searchResults, arguments: query);
  }

  static Future<dynamic> navigateToProductDetails(
      BuildContext context, String productId) {
    return navigateTo(context, '/product/$productId');
  }

  static Future<dynamic> navigateToCategoryProducts(
    BuildContext context,
    String categoryId, {
    String? categoryName,
  }) {
    final cleanName = categoryName?.trim();
    return navigateTo(
      context,
      shop,
      arguments: {
        'categoryId': categoryId,
        if (cleanName != null && cleanName.isNotEmpty)
          'categoryName': cleanName,
      },
    );
  }

  static Future<dynamic> navigateToOrders(BuildContext context) {
    return navigateTo(context, orders);
  }

  static Future<dynamic> navigateToOrderDetails(
      BuildContext context, String orderId) {
    return navigateTo(context, orderDetails, arguments: orderId);
  }

  static Future<dynamic> navigateToOrderTracking(
      BuildContext context, OrderModel order) {
    return navigateTo(context, orderTracking, arguments: order);
  }

  // ============================================
  // URL GENERATION & DEEP LINKING
  // ============================================
  static String generateProductUrl(String productId) =>
      '$baseUrl/product/$productId';
  static String generateCategoryUrl(String categoryId) =>
      '$baseUrl/category/$categoryId';
  static String generateSearchUrl(String query) =>
      '$baseUrl/search?q=${Uri.encodeComponent(query)}';
  static String generateOrderUrl(String orderId) => '$baseUrl/order/$orderId';
  static String generateOrdersUrl() => '$baseUrl/orders';

  static Future<dynamic> navigateFromUrl(BuildContext context, String url) {
    try {
      debugPrint('🌐 Navigating from URL: $url');
      final uri = Uri.parse(url);
      final path = uri.path;

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
          return navigateTo(context, '/product/$productId');
        }
      } else if (path.contains('/category/')) {
        final segments = path.split('/');
        if (segments.length >= 3) {
          final categoryId = segments[2];
          debugPrint('📂 Category deep link detected: $categoryId');
          return navigateTo(context, '/category/$categoryId');
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
