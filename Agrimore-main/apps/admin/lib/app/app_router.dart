// lib/app/app_router.dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:agrimore_ui/agrimore_ui.dart';
import '../providers/auth_provider.dart';
import '../providers/seller_provider.dart';

// Screens
import '../screens/auth/auth_screen.dart';
import '../screens/admin/admin_shell.dart';
import '../screens/admin/admin_dashboard.dart';
import '../screens/admin/products/product_management_screen.dart';
import '../screens/admin/products/product_form_screen.dart';
import '../screens/admin/orders/order_management_screen.dart';
import '../screens/admin/delivery/delivery_partner_management_screen.dart';
import '../screens/admin/users/user_management_screen.dart';
import '../screens/admin/coupon/coupon_management_screen.dart';
import '../screens/admin/banners/banner_management_screen.dart';
import '../screens/admin/sponsored_banners/sponsored_banner_management_screen.dart';
import '../screens/admin/bestsellers/bestseller_management_screen.dart';
import '../screens/admin/category_sections/category_section_management_screen.dart';
import '../screens/admin/category_sections/edit_category_section_screen.dart';
import '../screens/admin/notifications/send_notification_screen.dart';
import '../screens/admin/analytics/analytics_screen.dart';
import '../screens/admin/settings/admin_settings_screen.dart';
import '../screens/admin/settings/delivery_time_slots_management_screen.dart';
import '../screens/admin/sellers/seller_requests_management_screen.dart';
import '../screens/admin/sellers/add_seller_screen.dart';
import '../screens/admin/section_banners/section_banner_management_screen.dart';
import '../screens/admin/vendors/vendors_list_screen.dart';
import '../screens/admin/subscriptions/subscription_management_screen.dart';
import '../screens/admin/rewards/rewards_management_screen.dart';
import '../screens/admin/reviews/review_management_screen.dart';
import '../screens/seller/seller_panel_screen.dart';
import '../screens/seller/seller_apply_screen.dart';

class AdminRoutes {
  // Auth
  static const String auth = '/auth';
  static const String login = '/login';
  
  // Dashboard
  static const String dashboard = '/dashboard';
  
  // Products
  static const String products = '/products';
  static const String productNew = '/products/new';
  static const String productEdit = '/products/:id/edit';
  
  // Orders
  static const String orders = '/orders';
  static const String orderDetail = '/orders/:id';
  
  // Delivery Partners
  static const String deliveryPartners = '/delivery-partners';
  
  // Users
  static const String users = '/users';
  static const String userDetail = '/users/:id';
  
  // Custom Modules
  static const String subscriptions = '/subscriptions';
  static const String rewards = '/rewards';
  static const String reviews = '/reviews';
  
  // Vendors
  static const String vendors = '/vendors';
  
  // Coupons
  static const String coupons = '/coupons';
  
  // Media
  static const String banners = '/banners';
  static const String sponsored = '/sponsored';
  static const String sectionBanners = '/section-banners';
  
  // Featured
  static const String bestsellers = '/bestsellers';
  static const String sections = '/sections';
  static const String sectionNew = '/sections/new';
  static const String sectionEdit = '/sections/:id';
  
  // System
  static const String notifications = '/notifications';
  static const String analytics = '/analytics';
  static const String settings = '/settings';

  /// Checkout delivery windows (Firestore `settings/delivery`)
  static const String deliveryTimeSlots = '/delivery-time-slots';

  static const String sellerRequests = '/seller-requests';

  /// Admin creates an approved seller (callable `createSellerByAdmin`).
  static const String addSeller = '/add-seller';

  // Seller App Routes
  static const String sellerPanel = '/seller/panel';
  static const String sellerApply = '/seller/apply';
}

/// App router configuration using go_router
class AppRouter {
  static final GlobalKey<NavigatorState> _rootNavigatorKey = GlobalKey<NavigatorState>();
  static final GlobalKey<NavigatorState> _shellNavigatorKey = GlobalKey<NavigatorState>();

  static GoRouter router(BuildContext context) {
    final authProvider = context.read<AuthProvider>();
    
    return GoRouter(
      navigatorKey: _rootNavigatorKey,
      initialLocation: '/splash',
      debugLogDiagnostics: true,

      
      // Redirect logic for auth
      redirect: (context, state) {
        if (state.matchedLocation == '/splash') return null;

        final isLoggedIn = authProvider.isLoggedIn;
        final isAuthRoute = state.matchedLocation == AdminRoutes.auth ||
            state.matchedLocation == AdminRoutes.login ||
            state.matchedLocation == '/';
        final isSellerRoute = state.matchedLocation.startsWith('/seller');

        if (!isLoggedIn && !isAuthRoute) {
          return AdminRoutes.auth;
        }

        if (isLoggedIn) {
          if (authProvider.isAdmin) {
             // Admin goes to dashboard
             if (isAuthRoute || state.matchedLocation == '/') return AdminRoutes.dashboard;
          } else {
             // Non-admin (User/Seller) must be blocked (AuthProvider handles sign out)
             // We can just keep them on auth route to see the error message
             if (!isAuthRoute) return AdminRoutes.auth;
          }
        }

        return null;
      },
      
      // Refresh when auth state changes
      refreshListenable: authProvider,
      
      routes: [
        // Splash Screen
        GoRoute(
          path: '/splash',
          name: 'splash',
          builder: (context, state) => PremiumSplashScreen(
            appName: 'Agrimore Admin',
            tagline: 'Control Panel',
            logoPath: 'packages/agrimore_ui/assets/icons/admin_logo.png',
            animationType: SplashAnimationType.admin,
            onNavigation: (ctx) async {
              final auth = ctx.read<AuthProvider>();
              int waitCount = 0;
              while (auth.isInitializing && waitCount < 30) {
                await Future.delayed(const Duration(milliseconds: 100));
                waitCount++;
              }
              if (!ctx.mounted) return;
              if (!auth.isLoggedIn) {
                ctx.go(AdminRoutes.auth);
              } else if (auth.isAdmin) {
                ctx.go(AdminRoutes.dashboard);
              } else {
                ctx.go(AdminRoutes.auth);
              }
            },
          ),
        ),

        // Auth Screen
        GoRoute(
          path: AdminRoutes.auth,
          name: 'auth',
          builder: (context, state) => const AuthScreen(),
        ),
        GoRoute(
          path: AdminRoutes.login,
          name: 'login',
          redirect: (_, __) => AdminRoutes.auth,
        ),
        // Root redirect
        GoRoute(
          path: '/',
          redirect: (context, state) {
            final authProvider = context.read<AuthProvider>();
            if (!authProvider.isLoggedIn) return AdminRoutes.auth;
            return authProvider.isAdmin ? AdminRoutes.dashboard : AdminRoutes.auth;
          },
        ),

        // ============================================
        // SELLER ROUTES (NO SHELL)
        // ============================================
        GoRoute(
          path: AdminRoutes.sellerPanel,
          name: 'seller-panel',
          parentNavigatorKey: _rootNavigatorKey,
          builder: (context, state) => const SellerPanelScreen(),
        ),
        GoRoute(
          path: AdminRoutes.sellerApply,
          name: 'seller-apply',
          parentNavigatorKey: _rootNavigatorKey,
          builder: (context, state) => const SellerApplyScreen(),
        ),

        // ============================================
        // FULL-SCREEN ROUTES (NO SHELL)
        // These screens don't show the sidebar/header
        // ============================================
        
        // Product Add/Edit (full screen)
        GoRoute(
          path: AdminRoutes.productNew,
          name: 'product-new',
          parentNavigatorKey: _rootNavigatorKey,
          builder: (context, state) => const ProductFormScreen(),
        ),
        GoRoute(
          path: '/products/:id/edit',
          name: 'product-edit',
          parentNavigatorKey: _rootNavigatorKey,
          builder: (context, state) {
            final productId = state.pathParameters['id']!;
            return ProductFormScreen(productId: productId);
          },
        ),
        
        // Section Add/Edit (full screen)
        GoRoute(
          path: AdminRoutes.sectionNew,
          name: 'section-new',
          builder: (context, state) => const EditCategorySectionScreen(section: null),
        ),
        GoRoute(
          path: '/sections/:id/edit',
          name: 'section-edit',
          builder: (context, state) {
            // Note: Section data needs to be passed or fetched by ID
            return const EditCategorySectionScreen(section: null);
          },
        ),
        
        // ============================================
        // SHELL ROUTES (WITH SIDEBAR)
        // ============================================
        ShellRoute(
          navigatorKey: _shellNavigatorKey,
          builder: (context, state, child) => AdminShell(
            currentPath: state.matchedLocation,
            child: child,
          ),
          routes: [
            // Dashboard
            GoRoute(
              path: AdminRoutes.dashboard,
              name: 'dashboard',
              pageBuilder: (context, state) => _buildPage(
                const AdminDashboard(),
                state,
              ),
            ),
            
            // Products List
            GoRoute(
              path: AdminRoutes.products,
              name: 'products',
              pageBuilder: (context, state) => _buildPage(
                const ProductManagementScreen(),
                state,
              ),
            ),

            
            // Orders
            GoRoute(
              path: AdminRoutes.orders,
              name: 'orders',
              pageBuilder: (context, state) => _buildPage(
                const OrderManagementScreen(),
                state,
              ),
            ),
            
            // Users
            GoRoute(
              path: AdminRoutes.users,
              name: 'users',
              pageBuilder: (context, state) => _buildPage(
                const UserManagementScreen(),
                state,
              ),
            ),
            
            // Subscriptions
            GoRoute(
              path: AdminRoutes.subscriptions,
              name: 'subscriptions',
              pageBuilder: (context, state) => _buildPage(
                const SubscriptionManagementScreen(),
                state,
              ),
            ),
            
            // Rewards
            GoRoute(
              path: AdminRoutes.rewards,
              name: 'rewards',
              pageBuilder: (context, state) => _buildPage(
                const RewardsManagementScreen(),
                state,
              ),
            ),
            
            // Reviews
            GoRoute(
              path: AdminRoutes.reviews,
              name: 'reviews',
              pageBuilder: (context, state) => _buildPage(
                const ReviewManagementScreen(),
                state,
              ),
            ),
            
            // Vendors
            GoRoute(
              path: AdminRoutes.vendors,
              name: 'vendors',
              pageBuilder: (context, state) => _buildPage(
                const VendorsListScreen(),
                state,
              ),
            ),
            
            // Delivery Partners
            GoRoute(
              path: AdminRoutes.deliveryPartners,
              name: 'delivery-partners',
              pageBuilder: (context, state) => _buildPage(
                const DeliveryPartnerManagementScreen(),
                state,
              ),
            ),
            
            // Coupons
            GoRoute(
              path: AdminRoutes.coupons,
              name: 'coupons',
              pageBuilder: (context, state) => _buildPage(
                const CouponManagementScreen(),
                state,
              ),
            ),
            
            // Banners
            GoRoute(
              path: AdminRoutes.banners,
              name: 'banners',
              pageBuilder: (context, state) => _buildPage(
                const BannerManagementScreen(),
                state,
              ),
            ),
            
            // Sponsored
            GoRoute(
              path: AdminRoutes.sponsored,
              name: 'sponsored',
              pageBuilder: (context, state) => _buildPage(
                const SponsoredBannerManagementScreen(),
                state,
              ),
            ),
            
            // Section Banners
            GoRoute(
              path: AdminRoutes.sectionBanners,
              name: 'section-banners',
              pageBuilder: (context, state) => _buildPage(
                const SectionBannerManagementScreen(),
                state,
              ),
            ),
            
            // Bestsellers
            GoRoute(
              path: AdminRoutes.bestsellers,
              name: 'bestsellers',
              pageBuilder: (context, state) => _buildPage(
                const BestsellerManagementScreen(),
                state,
              ),
            ),
            
            // Category Sections List
            GoRoute(
              path: AdminRoutes.sections,
              name: 'sections',
              pageBuilder: (context, state) => _buildPage(
                const CategorySectionManagementScreen(),
                state,
              ),
            ),
            
            // Notifications
            GoRoute(
              path: AdminRoutes.notifications,
              name: 'notifications',
              pageBuilder: (context, state) => _buildPage(
                const SendNotificationScreen(),
                state,
              ),
            ),
            
            // Analytics
            GoRoute(
              path: AdminRoutes.analytics,
              name: 'analytics',
              pageBuilder: (context, state) => _buildPage(
                const AnalyticsScreen(),
                state,
              ),
            ),
            
            // Settings
            GoRoute(
              path: AdminRoutes.settings,
              name: 'settings',
              pageBuilder: (context, state) => _buildPage(
                const AdminSettingsScreen(),
                state,
              ),
            ),

            GoRoute(
              path: AdminRoutes.deliveryTimeSlots,
              name: 'delivery-time-slots',
              pageBuilder: (context, state) => _buildPage(
                const DeliveryTimeSlotsManagementScreen(),
                state,
              ),
            ),

            GoRoute(
              path: AdminRoutes.sellerRequests,
              name: 'seller-requests',
              pageBuilder: (context, state) => _buildPage(
                const SellerRequestsManagementScreen(),
                state,
              ),
            ),

            GoRoute(
              path: AdminRoutes.addSeller,
              name: 'add-seller',
              pageBuilder: (context, state) => _buildPage(
                const AddSellerScreen(),
                state,
              ),
            ),
          ],
        ),
      ],
      
      // Error handling
      errorBuilder: (context, state) => Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 64, color: Colors.red),
              const SizedBox(height: 16),
              Text(
                'Page not found: ${state.matchedLocation}',
                style: const TextStyle(fontSize: 18),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () => context.go(AdminRoutes.dashboard),
                child: const Text('Go to Dashboard'),
              ),
            ],
          ),
        ),
      ),
    );
  }
  
  /// Build a page with custom transition
  static CustomTransitionPage _buildPage(Widget child, GoRouterState state) {
    return CustomTransitionPage(
      key: state.pageKey,
      child: child,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        return FadeTransition(
          opacity: CurveTween(curve: Curves.easeInOut).animate(animation),
          child: child,
        );
      },
    );
  }
}

/// Extension for easy navigation
extension GoRouterExtension on BuildContext {
  /// Navigate to a route
  void navigateTo(String path) => go(path);
  
  /// Push a route on stack
  void pushTo(String path) => push(path);
  
  /// Replace current route
  void replaceTo(String path) => pushReplacement(path);
}
