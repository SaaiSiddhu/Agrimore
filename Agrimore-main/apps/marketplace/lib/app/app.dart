// lib/app/app.dart

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:agrimore_ui/agrimore_ui.dart';
import 'routes.dart';
import '../providers/theme_provider.dart';
import '../utils/web_url_helper.dart';
import '../screens/not_found_screen.dart';

// Alias for backward compatibility
typedef MarketplaceApp = AgrimoreApp;

// Global navigator key to preserve navigation state across widget rebuilds
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

class AgrimoreApp extends StatefulWidget {
  const AgrimoreApp({Key? key}) : super(key: key);

  @override
  State<AgrimoreApp> createState() => _AgrimoreAppState();
}

class _AgrimoreAppState extends State<AgrimoreApp> {
  @override
  void initState() {
    super.initState();
    
    // Setup browser back button listener for web
    if (kIsWeb) {
      setupPopStateListener(_handlePopState);
    }
  }
  
  /// Handle browser back/forward button navigation
  void _handlePopState(String path) {
    debugPrint('🔙 Browser back/forward to: $path');
    // Use addPostFrameCallback to avoid navigator lock
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (navigatorKey.currentState != null) {
        navigatorKey.currentState!.pushReplacementNamed(path);
      }
    });
  }
  
  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeProvider>(
      builder: (context, themeProvider, child) {
        return MaterialApp(
          // Navigator key preserves navigation state across rebuilds
          navigatorKey: navigatorKey,
          
          title: 'Agrimore - Smart Agriculture E-commerce',
          debugShowCheckedModeBanner: false,

          // Theme Configuration
          theme: AppTheme.lightTheme,
          darkTheme: AppTheme.darkTheme,
          themeMode: themeProvider.themeMode,

          // ROUTING: Routes.dart handles web vs mobile
          initialRoute: '/',  // '/' maps to Landing on web, Splash on mobile
          onGenerateRoute: AppRoutes.onGenerateRoute,

          // Unknown route handler - Advanced 404 page
          onUnknownRoute: (settings) {
            debugPrint('⚠️ Unknown route: ${settings.name}');
            return MaterialPageRoute(
              builder: (_) => const NotFoundScreen(),
            );
          },

          // Navigation observer for debugging
          navigatorObservers: [_NavigationObserver()],
        );
      },
    );
  }
}

// ✅ Navigation Observer - Logs all route changes
class _NavigationObserver extends NavigatorObserver {
  @override
  void didPush(Route route, Route? previousRoute) {
    debugPrint(
      '📍 PUSH: ${route.settings.name} (from ${previousRoute?.settings.name})',
    );
  }

  @override
  void didPop(Route route, Route? previousRoute) {
    debugPrint(
      '⬅️ POP: ${route.settings.name} (to ${previousRoute?.settings.name})',
    );
  }

  @override
  void didReplace({Route? newRoute, Route? oldRoute}) {
    debugPrint(
      '🔄 REPLACE: ${oldRoute?.settings.name} → ${newRoute?.settings.name}',
    );
  }

  @override
  void didRemove(Route route, Route? previousRoute) {
    debugPrint(
      '🗑️ REMOVE: ${route.settings.name}',
    );
  }
}
