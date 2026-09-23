// lib/main.dart
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/services.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:provider/provider.dart';
import 'package:agrimore_core/agrimore_core.dart';
import 'package:agrimore_services/agrimore_services.dart'
    hide DefaultFirebaseOptions;
import 'app/app.dart';
import 'providers/seller_auth_provider.dart';
import 'providers/seller_product_provider.dart';
import 'providers/seller_order_provider.dart';
import 'providers/rfq_provider.dart';
import 'providers/seller_settings_provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (kIsWeb) {
    await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform);
  } else {
    await Firebase.initializeApp();
  }
  // Phase 17, Workstream 2: monitoring mode only — see
  // AppCheckService's header comment. Never blocks startup (activate()
  // swallows its own errors internally).
  await AppCheckService.activate();
  await NotificationService.initialize();

  // Force portrait orientation
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  runApp(const SellerApp());
}

class SellerApp extends StatelessWidget {
  const SellerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => SellerAuthProvider()),
        ChangeNotifierProvider(create: (_) => SellerProductProvider()),
        ChangeNotifierProvider(create: (_) => SellerOrderProvider()),
        ChangeNotifierProvider(create: (_) => RfqProvider()),
        ChangeNotifierProvider(create: (_) => SellerSettingsProvider()..load()),
      ],
      child: const App(),
    );
  }
}
