import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:agrimore_ui/agrimore_ui.dart';
import 'product_card_widget.dart';

class ChatMessageWidget extends StatefulWidget {
  final String text;
  final bool isUser;
  final List<Map<String, dynamic>>? products;
  final Function(String)? onProductTap;
  final DateTime? timestamp;

  const ChatMessageWidget({
    Key? key,
    required this.text,
    required this.isUser,
    this.products,
    this.onProductTap,
    this.timestamp,
  }) : super(key: key);

  @override
  State<ChatMessageWidget> createState() => _ChatMessageWidgetState();
}

class _ChatMessageWidgetState extends State<ChatMessageWidget> 
    with SingleTickerProviderStateMixin {
  bool _showActions = false;
  bool _isCopied = false;
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    
    _scaleAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeOutBack,
      ),
    );
    
    _slideAnimation = Tween<Offset>(
      begin: Offset(widget.isUser ? 0.3 : -0.3, 0),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeOutCubic,
      ),
    );
    
    _animationController.forward();
  }

  void _copyToClipboard() {
    Clipboard.setData(ClipboardData(text: widget.text));
    HapticFeedback.mediumImpact();
    
    setState(() => _isCopied = true);
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: const [
            Icon(Icons.check_circle, color: Colors.white, size: 20),
            SizedBox(width: 12),
            Text('Message copied to clipboard'),
          ],
        ),
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppColors.success,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        margin: const EdgeInsets.all(16),
      ),
    );
    
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) {
        setState(() => _isCopied = false);
      }
    });
  }

  String _formatTimestamp(DateTime? timestamp) {
    if (timestamp == null) return '';
    
    final now = DateTime.now();
    final difference = now.difference(timestamp);
    
    if (difference.inSeconds < 60) {
      return 'Just now';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h ago';
    } else {
      return DateFormat('MMM d, h:mm a').format(timestamp);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SlideTransition(
      position: _slideAnimation,
      child: ScaleTransition(
        scale: _scaleAnimation,
        child: Align(
          alignment: widget.isUser ? Alignment.centerRight : Alignment.centerLeft,
          child: GestureDetector(
            onLongPress: () {
              HapticFeedback.mediumImpact();
              setState(() => _showActions = !_showActions);
            },
            child: Container(
              margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 16),
              constraints: BoxConstraints(
                maxWidth: MediaQuery.of(context).size.width * 0.80,
              ),
              child: Column(
                crossAxisAlignment: widget.isUser 
                    ? CrossAxisAlignment.end 
                    : CrossAxisAlignment.start,
                children: [
                  // Message Bubble
                  Stack(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 18,
                          vertical: 14,
                        ),
                        decoration: BoxDecoration(
                          gradient: widget.isUser
                              ? LinearGradient(
                                  colors: [
                                    AppColors.primary,
                                    AppColors.primary.withOpacity(0.8),
                                  ],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                )
                              : null,
                          color: widget.isUser ? null : Colors.white,
                          borderRadius: BorderRadius.only(
                            topLeft: const Radius.circular(20),
                            topRight: const Radius.circular(20),
                            bottomLeft: Radius.circular(widget.isUser ? 20 : 6),
                            bottomRight: Radius.circular(widget.isUser ? 6 : 20),
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: widget.isUser
                                  ? AppColors.primary.withOpacity(0.2)
                                  : Colors.black.withOpacity(0.08),
                              blurRadius: 10,
                              offset: const Offset(0, 3),
                            ),
                          ],
                          border: widget.isUser
                              ? null
                              : Border.all(
                                  color: Colors.grey.shade200,
                                  width: 1,
                                ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Message Text
                            Text(
                              widget.text,
                              style: TextStyle(
                                color: widget.isUser ? Colors.white : Colors.black87,
                                fontSize: 15,
                                height: 1.5,
                                letterSpacing: 0.2,
                              ),
                            ),
                            
                            // Timestamp
                            if (widget.timestamp != null) ...[
                              const SizedBox(height: 6),
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.access_time,
                                    size: 11,
                                    color: widget.isUser 
                                        ? Colors.white.withOpacity(0.7) 
                                        : Colors.grey[500],
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    _formatTimestamp(widget.timestamp),
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: widget.isUser 
                                          ? Colors.white.withOpacity(0.8) 
                                          : Colors.grey[600],
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ],
                        ),
                      ),
                      
                      // AI Badge
                      if (!widget.isUser)
                        Positioned(
                          left: -8,
                          top: -8,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  AppColors.primary,
                                  AppColors.primary.withOpacity(0.7),
                                ],
                              ),
                              borderRadius: BorderRadius.circular(12),
                              boxShadow: [
                                BoxShadow(
                                  color: AppColors.primary.withOpacity(0.3),
                                  blurRadius: 8,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.smart_toy,
                                  size: 12,
                                  color: Colors.white,
                                ),
                                SizedBox(width: 4),
                                Text(
                                  'AI',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                  
                  // Action Buttons (Copy, etc.)
                  if (_showActions)
                    TweenAnimationBuilder<double>(
                      tween: Tween(begin: 0.0, end: 1.0),
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeOutBack,
                      builder: (context, value, child) {
                        return Transform.scale(
                          scale: value,
                          child: Opacity(
                            opacity: value,
                            child: child,
                          ),
                        );
                      },
                      child: Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            _buildActionButton(
                              icon: _isCopied ? Icons.check : Icons.copy,
                              label: _isCopied ? 'Copied' : 'Copy',
                              onTap: _copyToClipboard,
                              color: _isCopied ? AppColors.success : Colors.grey,
                            ),
                          ],
                        ),
                      ),
                    ),
                  
                  // Product Cards (if any)
                  if (widget.products != null && widget.products!.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    TweenAnimationBuilder<double>(
                      tween: Tween(begin: 0.0, end: 1.0),
                      duration: const Duration(milliseconds: 600),
                      curve: Curves.easeOutCubic,
                      builder: (context, value, child) {
                        return Opacity(
                          opacity: value,
                          child: Transform.translate(
                            offset: Offset(0, 20 * (1 - value)),
                            child: child,
                          ),
                        );
                      },
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.05),
                              blurRadius: 15,
                              offset: const Offset(0, 5),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Products Header
                            Padding(
                              padding: const EdgeInsets.only(left: 4, bottom: 12),
                              child: Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 6,
                                    ),
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        colors: [
                                          AppColors.primary.withOpacity(0.15),
                                          AppColors.primary.withOpacity(0.05),
                                        ],
                                      ),
                                      borderRadius: BorderRadius.circular(20),
                                      border: Border.all(
                                        color: AppColors.primary.withOpacity(0.3),
                                      ),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Icon(
                                          Icons.shopping_bag_outlined,
                                          size: 16,
                                          color: AppColors.primary,
                                        ),
                                        const SizedBox(width: 6),
                                        Text(
                                          '${widget.products!.length} ${widget.products!.length == 1 ? 'Product' : 'Products'}',
                                          style: const TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w600,
                                            color: AppColors.primary,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            
                            // Products List
                            SizedBox(
                              height: 240,
                              child: ListView.builder(
                                scrollDirection: Axis.horizontal,
                                padding: const EdgeInsets.symmetric(horizontal: 4),
                                physics: const BouncingScrollPhysics(),
                                itemCount: widget.products!.length,
                                itemBuilder: (context, index) {
                                  final product = widget.products![index];
                                  return TweenAnimationBuilder<double>(
                                    tween: Tween(begin: 0.0, end: 1.0),
                                    duration: Duration(
                                      milliseconds: 400 + (index * 100),
                                    ),
                                    curve: Curves.easeOutBack,
                                    builder: (context, value, child) {
                                      return Transform.scale(
                                        scale: 0.8 + (0.2 * value),
                                        child: Opacity(
                                          opacity: value,
                                          child: child,
                                        ),
                                      );
                                    },
                                    child: ProductCardWidget(
                                      product: product,
                                      onTap: () {
                                        if (widget.onProductTap != null) {
                                          HapticFeedback.selectionClick();
                                          widget.onProductTap!(product['id']);
                                        }
                                      },
                                    ),
                                  );
                                },
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    required Color color,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: color.withOpacity(0.3),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }
}
