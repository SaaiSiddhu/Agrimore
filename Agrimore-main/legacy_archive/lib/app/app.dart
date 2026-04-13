// lib/app/app.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'themes/app_theme.dart';
import 'routes.dart';
import '../providers/theme_provider.dart';

class AgrimoreApp extends StatelessWidget {
  const AgrimoreApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeProvider>(
      builder: (context, themeProvider, child) {
        return MaterialApp(
          title: 'Agrimore - Smart Agriculture E-commerce',
          debugShowCheckedModeBanner: false,

          // ✅ Theme Configuration
          theme: AppTheme.lightTheme,
          darkTheme: AppTheme.darkTheme,
          themeMode: themeProvider.themeMode,

          // ✅ ROUTING CONFIGURATION - SPLASH FIRST, THEN MAIN
          initialRoute: AppRoutes.splash, // ✅ FIXED: Show splash first
          onGenerateRoute: AppRoutes.onGenerateRoute,

          // ✅ Unknown route handler
          onUnknownRoute: (settings) {
            debugPrint('⚠️ Unknown route: ${settings.name}');
            return MaterialPageRoute(
              builder: (_) => Scaffold(
                appBar: AppBar(title: const Text('404 - Page Not Found')),
                body: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.error_outline, size: 80, color: Colors.red),
                      const SizedBox(height: 20),
                      const Text('Page not found', style: TextStyle(fontSize: 18)),
                      const SizedBox(height: 20),
                      ElevatedButton(
                        onPressed: () => Navigator.pushNamedAndRemoveUntil(
                          _,
                          AppRoutes.main,
                          (route) => false,
                        ),
                        child: const Text('Go Home'),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },

          // ✅ Navigation observer for debugging
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
