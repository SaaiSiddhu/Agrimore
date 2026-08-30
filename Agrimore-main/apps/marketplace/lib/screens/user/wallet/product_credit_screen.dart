import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:agrimore_ui/agrimore_ui.dart';

import '../../../providers/product_credit_provider.dart';
import '../../../providers/theme_provider.dart';
import 'widgets/product_credit_ledger_tile.dart';

/// Full AgriMore Product Credit history — the first customer-facing
/// history surface for this ledger. Mirrors TransactionHistoryScreen's
/// structure (grouped-by-date list, pull to refresh, empty state) but for
/// a bounded query, not an unbounded one — see ProductCreditProvider.
///
/// Read-only: no redeem/enrol/cancel action anywhere on this screen.
class ProductCreditScreen extends StatefulWidget {
  const ProductCreditScreen({Key? key}) : super(key: key);

  @override
  State<ProductCreditScreen> createState() => _ProductCreditScreenState();
}

class _ProductCreditScreenState extends State<ProductCreditScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<ProductCreditProvider>(context, listen: false).init();
    });
  }

  Future<void> _refresh() {
    return Provider.of<ProductCreditProvider>(context, listen: false).refresh();
  }

  Map<String, List<dynamic>> _groupByDate(List<dynamic> entries) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    final Map<String, List<dynamic>> grouped = {};
    for (final entry in entries) {
      final d = entry.createdAt as DateTime;
      final key = '${months[d.month - 1]} ${d.day}, ${d.year}';
      grouped.putIfAbsent(key, () => []).add(entry);
    }
    return grouped;
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDark = themeProvider.isDarkMode;

    final backgroundColor = isDark ? const Color(0xFF121212) : AppColors.background;
    final cardColor = isDark ? const Color(0xFF1E1E1E) : Colors.white;
    final accentColor = isDark ? AppColors.primaryLight : AppColors.primary;

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        backgroundColor: backgroundColor,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios, color: isDark ? Colors.white : Colors.black87),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Product Credit History',
          style: TextStyle(
            color: isDark ? Colors.white : Colors.black87,
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
        centerTitle: true,
      ),
      body: Consumer<ProductCreditProvider>(
        builder: (context, provider, _) {
          if (provider.isLoading) {
            return Center(child: CircularProgressIndicator(color: accentColor));
          }

          if (!provider.isEnabled) {
            // Fail-closed: even reaching this screen with the flag off
            // (e.g. a stale deep link) shows nothing about the programme
            // — no teaser, no "coming soon".
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Text(
                  'Product Credit is not available right now.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    color: isDark ? Colors.grey[400] : Colors.grey[600],
                  ),
                ),
              ),
            );
          }

          if (provider.hasLedgerError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.error_outline,
                      size: 48,
                      color: isDark ? Colors.grey[600] : Colors.grey[400],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'History is temporarily unavailable. Pull to refresh to try again.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 14,
                        color: isDark ? Colors.grey[400] : Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
            );
          }

          if (provider.ledger.isEmpty) {
            return RefreshIndicator(
              onRefresh: _refresh,
              color: accentColor,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: [
                  SizedBox(
                    height: MediaQuery.of(context).size.height * 0.6,
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.eco_outlined,
                            size: 64,
                            color: isDark ? Colors.grey[600] : Colors.grey[400],
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'No Product Credit activity yet',
                            style: TextStyle(
                              fontSize: 16,
                              color: isDark ? Colors.grey[400] : Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            );
          }

          final grouped = _groupByDate(provider.ledger);

          return RefreshIndicator(
            onRefresh: _refresh,
            color: accentColor,
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              itemCount: grouped.length,
              itemBuilder: (context, index) {
                final date = grouped.keys.elementAt(index);
                final entries = grouped[date]!;

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: Text(
                        date,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: isDark ? Colors.grey[400] : Colors.grey[600],
                        ),
                      ),
                    ),
                    Container(
                      decoration: BoxDecoration(
                        color: cardColor,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(isDark ? 0.3 : 0.05),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Column(
                        children: entries
                            .map((entry) => ProductCreditLedgerTile(entry: entry, isDark: isDark))
                            .toList(),
                      ),
                    ),
                  ],
                );
              },
            ),
          );
        },
      ),
    );
  }
}
