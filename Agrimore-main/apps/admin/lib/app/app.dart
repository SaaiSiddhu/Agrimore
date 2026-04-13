// lib/app/app.dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../providers/theme_provider.dart';
import 'app_router.dart';
import 'themes/admin_theme.dart';

class AdminApp extends StatefulWidget {
  const AdminApp({super.key});

  @override
  State<AdminApp> createState() => _AdminAppState();
}

class _AdminAppState extends State<AdminApp> {
  GoRouter? _router;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Create router only once
    _router ??= AppRouter.router(context);
  }

  @override
  Widget build(BuildContext context) {
    // Ensure router exists
    if (_router == null) {
      return const MaterialApp(
        home: Scaffold(
          body: Center(child: CircularProgressIndicator()),
        ),
      );
    }

    return Consumer<ThemeProvider>(
      builder: (context, themeProvider, child) {
        return MaterialApp.router(
          title: 'Agrimore Admin',
          debugShowCheckedModeBanner: false,
          theme: AdminTheme.lightTheme,
          darkTheme: AdminTheme.darkTheme,
          themeMode: themeProvider.isDarkMode ? ThemeMode.dark : ThemeMode.light,
          routerConfig: _router!,
        );
      },
    );
  }
}
