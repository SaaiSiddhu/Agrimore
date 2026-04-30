// lib/main.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:provider/provider.dart';
import 'package:agrimore_core/agrimore_core.dart';
import 'app/app.dart';
import 'providers/seller_auth_provider.dart';
import 'providers/seller_product_provider.dart';
import 'providers/seller_order_provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  
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
      ],
      child: const App(),
    );
  }
}
