import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:agrimore_ui/agrimore_ui.dart';
import '../../providers/theme_provider.dart';
import '../../providers/business_feed_provider.dart';

/// BUSINESS-NETWORK-2 (slice 2 of 2): a feed of posts from sellers the
/// customer follows, newest first. See BusinessFeedProvider for the query
/// approach and its own disclosed v1 limits.
class BusinessFeedScreen extends StatefulWidget {
  const BusinessFeedScreen({super.key});

  @override
  State<BusinessFeedScreen> createState() => _BusinessFeedScreenState();
}

class _BusinessFeedScreenState extends State<BusinessFeedScreen> {
  final _feedProvider = BusinessFeedProvider();

  @override
  void initState() {
    super.initState();
    _feedProvider.addListener(_onFeedChanged);
    _feedProvider.loadFeed();
  }

  void _onFeedChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _feedProvider.removeListener(_onFeedChanged);
    _feedProvider.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDark = themeProvider.isDarkMode;
    final accentColor = isDark ? AppColors.primaryLight : AppColors.primary;

    return Scaffold(
      backgroundColor: isDark ? AppColors.backgroundDark : Colors.grey[50],
      appBar: AppBar(
        title: const Text('Following'),
        backgroundColor: isDark ? AppColors.surfaceDark : Colors.white,
        foregroundColor: isDark ? Colors.white : Colors.black87,
        elevation: 0,
      ),
      body: _feedProvider.isLoading
          ? const Center(child: CircularProgressIndicator())
          : _feedProvider.error != null
              ? ErrorView(
                  message: 'Could not load your feed.',
                  onRetry: _feedProvider.loadFeed,
                )
              : _feedProvider.posts.isEmpty
                  ? const EmptyState(
                      icon: Icons.dynamic_feed_outlined,
                      title: 'No posts yet',
                      message: 'Follow a seller from their business profile to see their posts here.',
                    )
                  : RefreshIndicator(
                      onRefresh: _feedProvider.loadFeed,
                      child: ListView.builder(
                        padding: const EdgeInsets.all(12),
                        itemCount: _feedProvider.posts.length,
                        itemBuilder: (context, index) {
                          final post = _feedProvider.posts[index];
                          return _PostCard(
                            post: post,
                            isDark: isDark,
                            accentColor: accentColor,
                          );
                        },
                      ),
                    ),
    );
  }
}

class _PostCard extends StatelessWidget {
  final Map<String, dynamic> post;
  final bool isDark;
  final Color accentColor;

  const _PostCard({required this.post, required this.isDark, required this.accentColor});

  @override
  Widget build(BuildContext context) {
    final sellerId = post['sellerId'] as String?;
    final shopName = post['shopName'] as String? ?? 'A seller you follow';
    final text = post['text'] as String?;
    final imageUrl = post['imageUrl'] as String?;
    final productId = post['productId'] as String?;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isDark ? Colors.grey[800]! : Colors.grey[200]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
            onTap: sellerId == null
                ? null
                : () => Navigator.pushNamed(context, '/business/$sellerId'),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 16,
                    backgroundColor: accentColor.withValues(alpha: 0.1),
                    child: Icon(Icons.storefront, color: accentColor, size: 16),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      shopName,
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (text?.isNotEmpty == true)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              child: Text(
                text!,
                style: TextStyle(color: isDark ? Colors.grey[300] : Colors.grey[800]),
              ),
            ),
          if (imageUrl != null)
            ClipRRect(
              borderRadius: BorderRadius.zero,
              child: Image.network(
                imageUrl,
                width: double.infinity,
                height: 220,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => const SizedBox.shrink(),
              ),
            ),
          if (productId != null)
            Padding(
              padding: const EdgeInsets.all(12),
              child: OutlinedButton.icon(
                onPressed: () => Navigator.pushNamed(context, '/product/$productId'),
                icon: Icon(Icons.shopping_bag_outlined, size: 16, color: accentColor),
                label: Text('View product', style: TextStyle(color: accentColor)),
                style: OutlinedButton.styleFrom(side: BorderSide(color: accentColor)),
              ),
            ),
        ],
      ),
    );
  }
}
