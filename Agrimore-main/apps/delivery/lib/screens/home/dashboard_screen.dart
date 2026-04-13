// lib/screens/home/dashboard_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:agrimore_core/agrimore_core.dart';
import '../../providers/auth_provider.dart';
import '../../providers/order_provider.dart';
import '../../providers/location_provider.dart';
import '../orders/pending_orders_screen.dart';
import '../orders/active_order_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  bool _isOnline = false;
  
  @override
  void initState() {
    super.initState();
    _initializeProviders();
  }
  
  void _initializeProviders() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final auth = context.read<DeliveryAuthProvider>();
      final orderProvider = context.read<DeliveryOrderProvider>();
      final locationProvider = context.read<LocationProvider>();
      
      if (auth.user != null) {
        orderProvider.loadAvailableOrders();
        orderProvider.watchActiveOrder(auth.user!.uid);
        locationProvider.checkPermissions();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // Header
            _buildHeader(colorScheme),
            
            // Online Toggle
            _buildOnlineToggle(colorScheme),
            
            // Active Order or Dashboard
            Expanded(
              child: Consumer<DeliveryOrderProvider>(
                builder: (context, orderProvider, _) {
                  if (orderProvider.hasActiveOrder) {
                    return _buildActiveOrderCard(orderProvider.activeOrder!, colorScheme);
                  }
                  return _buildDashboardContent(colorScheme);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildHeader(ColorScheme colorScheme) {
    return Consumer<DeliveryAuthProvider>(
      builder: (context, auth, _) {
        return Container(
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              CircleAvatar(
                radius: 24,
                backgroundColor: colorScheme.primaryContainer,
                child: Text(
                  auth.user?.initials ?? 'DP',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: colorScheme.primary,
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Hello, ${auth.user?.firstName ?? 'Partner'}',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: colorScheme.onSurface,
                      ),
                    ),
                    Text(
                      _isOnline ? 'Ready to deliver' : 'Offline',
                      style: TextStyle(
                        fontSize: 13,
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: () => _showLogoutDialog(),
                icon: Icon(Icons.logout_rounded),
                tooltip: 'Logout',
              ),
            ],
          ),
        );
      },
    );
  }
  
  Widget _buildOnlineToggle(ColorScheme colorScheme) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: _isOnline ? colorScheme.primary : colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Icon(
            _isOnline ? Icons.circle : Icons.circle_outlined,
            size: 12,
            color: _isOnline ? Colors.white : colorScheme.onSurfaceVariant,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              _isOnline ? 'You are Online' : 'You are Offline',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: _isOnline ? Colors.white : colorScheme.onSurface,
              ),
            ),
          ),
          Switch(
            value: _isOnline,
            onChanged: (value) => _toggleOnline(value),
            activeColor: Colors.white,
            activeTrackColor: Colors.white.withValues(alpha: 0.3),
          ),
        ],
      ),
    );
  }
  
  Widget _buildDashboardContent(ColorScheme colorScheme) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Earnings Rate Card
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.green.shade400,
                  Colors.green.shade600,
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.green.withOpacity(0.3),
                  blurRadius: 12,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.currency_rupee_rounded, color: Colors.white, size: 28),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Current Rate',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        '₹4.75 / km',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Text(
                    'Min ₹15',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 20),
          
          // Stats Row
          Row(
            children: [
              Expanded(child: _buildStatCard('Today', '0', Icons.receipt_long_rounded, colorScheme)),
              const SizedBox(width: 12),
              Expanded(child: _buildStatCard('Distance', '0 km', Icons.route_rounded, colorScheme)),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: _buildStatCard('Earnings', '₹0', Icons.account_balance_wallet_rounded, colorScheme, isHighlight: true)),
              const SizedBox(width: 12),
              Expanded(child: _buildStatCard('Rating', '5.0 ⭐', Icons.star_rounded, colorScheme)),
            ],
          ),
          
          const SizedBox(height: 24),
          
          // Quick Actions
          Text(
            'Quick Actions',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 12),
          
          _buildActionCard(
            'Available Orders',
            'View and accept delivery orders',
            Icons.inbox_rounded,
            colorScheme,
            badgeCount: context.watch<DeliveryOrderProvider>().availableOrders.length,
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const PendingOrdersScreen()),
            ),
          ),
          const SizedBox(height: 12),
          _buildActionCard(
            'My Deliveries',
            'View your delivery history',
            Icons.history_rounded,
            colorScheme,
            onTap: () {
              // TODO: Navigate to history
            },
          ),
        ],
      ),
    );
  }
  
  Widget _buildStatCard(String label, String value, IconData icon, ColorScheme colorScheme, {bool isHighlight = false}) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isHighlight ? colorScheme.primaryContainer : colorScheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isHighlight ? colorScheme.primary.withOpacity(0.3) : colorScheme.outline.withOpacity(0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: isHighlight ? colorScheme.primary : colorScheme.onSurfaceVariant, size: 28),
          const SizedBox(height: 12),
          Text(
            value,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w900,
              color: isHighlight ? colorScheme.primary : colorScheme.onSurface,
            ),
          ),
          Text(
            label,
            style: TextStyle(
              fontSize: 13,
              color: colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildActionCard(String title, String subtitle, IconData icon, ColorScheme colorScheme, {VoidCallback? onTap, int badgeCount = 0}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainerLowest,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: colorScheme.outline.withOpacity(0.1)),
        ),
        child: Row(
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: colorScheme.primary),
                ),
                if (badgeCount > 0)
                  Positioned(
                    right: -6,
                    top: -6,
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: Colors.red,
                        shape: BoxShape.circle,
                      ),
                      child: Text(
                        '$badgeCount',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                  Text(subtitle, style: TextStyle(fontSize: 12, color: colorScheme.onSurfaceVariant)),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: colorScheme.onSurfaceVariant),
          ],
        ),
      ),
    );
  }
  
  Widget _buildActiveOrderCard(OrderModel order, ColorScheme colorScheme) {
    return Container(
      margin: const EdgeInsets.all(20),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.delivery_dining_rounded, color: colorScheme.primary, size: 32),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Active Delivery',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: colorScheme.onPrimaryContainer,
                      ),
                    ),
                    Text(
                      'Order #${order.orderNumber}',
                      style: TextStyle(
                        fontSize: 13,
                        color: colorScheme.onPrimaryContainer.withValues(alpha: 0.7),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          FilledButton(
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => ActiveOrderScreen(order: order)),
            ),
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(48),
            ),
            child: Text('View Details'),
          ),
        ],
      ),
    );
  }
  
  void _toggleOnline(bool value) async {
    HapticFeedback.lightImpact();
    setState(() => _isOnline = value);
    
    final auth = context.read<DeliveryAuthProvider>();
    final location = context.read<LocationProvider>();
    
    if (value && auth.user != null) {
      await location.startTracking(auth.user!.uid);
      await location.setOnlineStatus(auth.user!.uid, true);
    } else if (auth.user != null) {
      location.stopTracking();
      await location.setOnlineStatus(auth.user!.uid, false);
    }
  }
  
  void _showLogoutDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Logout'),
        content: Text('Are you sure you want to logout?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(context);
              context.read<DeliveryAuthProvider>().signOut();
            },
            child: Text('Logout'),
          ),
        ],
      ),
    );
  }
}
