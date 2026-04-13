// lib/screens/user/orders/my_orders_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../providers/order_provider.dart';
import '../../../app/themes/app_colors.dart';
import 'orders_screen.dart'; // ✅ NEW: Main orders screen with tabs

class MyOrdersScreen extends StatefulWidget {
  const MyOrdersScreen({Key? key}) : super(key: key);

  @override
  State<MyOrdersScreen> createState() => _MyOrdersScreenState();
}

class _MyOrdersScreenState extends State<MyOrdersScreen> {
  @override
  void initState() {
    super.initState();
    // Load orders when screen opens
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<OrderProvider>(context, listen: false).loadOrders();
    });
  }

  @override
  Widget build(BuildContext context) {
    // ✅ REDIRECT TO NEW OrdersScreen
    // This screen now acts as a wrapper/entry point
    return const OrdersScreen();
  }
}
