// lib/app/app.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../screens/auth/login_screen.dart';
import '../screens/home/dashboard_screen.dart';

class App extends StatelessWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Agrimore Delivery',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF2D7D3C),
          brightness: Brightness.light,
        ),
        useMaterial3: true,
        appBarTheme: const AppBarTheme(
          centerTitle: true,
          elevation: 0,
        ),
      ),
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF4DB85F),
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      themeMode: ThemeMode.system,
      home: Consumer<DeliveryAuthProvider>(
        builder: (context, authProvider, _) {
          if (authProvider.isLoading) {
            return const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            );
          }
          
          if (authProvider.isAuthenticated && authProvider.isDeliveryPartner) {
            return const DashboardScreen();
          }
          
          return const LoginScreen();
        },
      ),
    );
  }
}
