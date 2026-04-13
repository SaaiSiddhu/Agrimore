import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:provider/provider.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../../../../app/themes/app_colors.dart';
import '../../../../app/themes/app_text_styles.dart';
import '../../../../models/cart_item_model.dart';
import '../../../../providers/theme_provider.dart';

class CartItemCard extends StatefulWidget {
  final CartItemModel item;
  final VoidCallback onRemove;
  final Function(int) onQuantityChanged;

  const CartItemCard({
    Key? key,
    required this.item,
    required this.onRemove,
    required this.onQuantityChanged,
  }) : super(key: key);

  @override
  State<CartItemCard> createState() => _CartItemCardState();
}

class _CartItemCardState extends State<CartItemCard> with SingleTickerProviderStateMixin {
  bool _isRemoving = false;
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeIn),
    );
    
    _slideAnimation = Tween<Offset>(
      begin: const Offset(-0.3, 0),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));

    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _handleRemove() async {
    HapticFeedback.mediumImpact();
    
    final isDark = context.read<ThemeProvider>().isDarkMode;
    
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.error.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: FaIcon(FontAwesomeIcons.triangleExclamation, color: AppColors.error, size: 20),
            ),
            const SizedBox(width: 12),
            Text(
              'Remove Item',
              style: TextStyle(color: isDark ? Colors.white : Colors.black87),
            ),
          ],
        ),
        content: Text(
          'Remove ${widget.item.productName} from cart?',
          style: TextStyle(color: isDark ? Colors.grey[300] : Colors.grey[700]),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              'Cancel',
              style: TextStyle(color: isDark ? Colors.grey[400] : AppColors.textSecondary),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: const Text('Remove', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      setState(() => _isRemoving = true);
      await _controller.reverse();
      widget.onRemove();
    }
  }

  void _handleQuantityChange(int newQuantity) {
    HapticFeedback.selectionClick();
    widget.onQuantityChanged(newQuantity);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = context.watch<ThemeProvider>().isDarkMode;
    final accentColor = isDark ? AppColors.primaryLight : AppColors.primary;
    
    return FadeTransition(
      opacity: _fadeAnimation,
      child: SlideTransition(
        position: _slideAnimation,
        child: Stack(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildProductImage(isDark, accentColor),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildProductInfo(isDark),
                          const SizedBox(height: 8),
                          _buildPriceInfo(isDark, accentColor),
                          const SizedBox(height: 12),
                          _buildBottomActions(isDark, accentColor),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
            if (_isRemoving)
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    color: (isDark ? Colors.black : Colors.white).withOpacity(0.7),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Center(
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      valueColor: AlwaysStoppedAnimation<Color>(accentColor),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildProductImage(bool isDark, Color accentColor) {
    return Hero(
      tag: 'cart_item_${widget.item.productId}',
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isDark ? Colors.grey[800]! : Colors.grey[200]!,
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(isDark ? 0.3 : 0.05),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: CachedNetworkImage(
            imageUrl: widget.item.productImage,
            width: 90,
            height: 90,
            fit: BoxFit.cover,
            placeholder: (context, url) => Container(
              color: isDark ? Colors.grey[850] : Colors.grey[100],
              child: Center(
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(accentColor.withOpacity(0.5)),
                ),
              ),
            ),
            errorWidget: (context, url, error) => Container(
              color: isDark ? Colors.grey[850] : Colors.grey[100],
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.broken_image_outlined,
                    color: isDark ? Colors.grey[600] : Colors.grey[400],
                    size: 32,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'No Image',
                    style: TextStyle(
                      fontSize: 9,
                      color: isDark ? Colors.grey[600] : Colors.grey[500],
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildProductInfo(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.item.productName,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      height: 1.3,
                      letterSpacing: -0.2,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (widget.item.variant != null && widget.item.variant!.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: isDark ? Colors.grey[800] : Colors.grey[100],
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: isDark ? Colors.grey[700]! : Colors.grey[300]!,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          FaIcon(
                            FontAwesomeIcons.cube,
                            size: 10,
                            color: isDark ? Colors.grey[400] : Colors.grey[600],
                          ),
                          const SizedBox(width: 6),
                          Text(
                            widget.item.variant!,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: isDark ? Colors.grey[300] : Colors.grey[700],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: _handleRemove,
              child: Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: AppColors.error.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: FaIcon(
                  FontAwesomeIcons.trash,
                  color: AppColors.error,
                  size: 14,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildPriceInfo(bool isDark, Color accentColor) {
    final hasDiscount = widget.item.originalPrice != null && 
                        widget.item.originalPrice! > widget.item.price;
    final savings = hasDiscount 
        ? widget.item.originalPrice! - widget.item.price 
        : 0.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              '₹${widget.item.price.toStringAsFixed(0)}',
              style: TextStyle(
                fontSize: 16,
                color: accentColor,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.3,
              ),
            ),
            if (hasDiscount) ...[
              const SizedBox(width: 8),
              Text(
                '₹${widget.item.originalPrice!.toStringAsFixed(0)}',
                style: TextStyle(
                  fontSize: 13,
                  decoration: TextDecoration.lineThrough,
                  color: isDark ? Colors.grey[500] : Colors.grey[500],
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ],
        ),
        if (hasDiscount) ...[
          const SizedBox(height: 6),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.green.shade600, Colors.green.shade500],
                  ),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const FaIcon(
                      FontAwesomeIcons.percent,
                      size: 8,
                      color: Colors.white,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '${widget.item.discountPercentage.toStringAsFixed(0)}% OFF',
                      style: const TextStyle(
                        fontSize: 10,
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.3,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              FaIcon(
                FontAwesomeIcons.piggyBank,
                size: 10,
                color: Colors.green.shade700,
              ),
              const SizedBox(width: 4),
              Text(
                'Save ₹${savings.toStringAsFixed(0)}',
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.green.shade700,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }

  Widget _buildBottomActions(bool isDark, Color accentColor) {
    return Row(
      children: [
        _buildCompactQuantitySelector(isDark, accentColor),
        const Spacer(),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: accentColor.withOpacity(0.15),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(
              color: accentColor.withOpacity(0.3),
              width: 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Total: ',
                style: TextStyle(
                  fontSize: 11,
                  color: accentColor.withOpacity(0.8),
                  fontWeight: FontWeight.w600,
                  letterSpacing: -0.1,
                ),
              ),
              Text(
                '₹${(widget.item.price * widget.item.quantity).toStringAsFixed(0)}',
                style: TextStyle(
                  fontSize: 13,
                  color: accentColor,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.2,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildCompactQuantitySelector(bool isDark, Color accentColor) {
    final isMinQuantity = widget.item.quantity <= 1;
    final isMaxQuantity = widget.item.quantity >= 10;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? Colors.grey[850] : Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: accentColor.withOpacity(0.3),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.2 : 0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildQuantityButton(
            icon: FontAwesomeIcons.minus,
            onPressed: isMinQuantity 
                ? null 
                : () => _handleQuantityChange(widget.item.quantity - 1),
            isEnabled: !isMinQuantity,
            isDark: isDark,
            accentColor: accentColor,
          ),
          Container(
            constraints: const BoxConstraints(minWidth: 40),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: isDark ? Colors.grey[800] : Colors.grey[50],
              border: Border.symmetric(
                vertical: BorderSide(
                  color: accentColor.withOpacity(0.2),
                  width: 1,
                ),
              ),
            ),
            child: Text(
              widget.item.quantity.toString(),
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w800,
                color: accentColor,
                letterSpacing: -0.2,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          _buildQuantityButton(
            icon: FontAwesomeIcons.plus,
            onPressed: isMaxQuantity 
                ? null 
                : () => _handleQuantityChange(widget.item.quantity + 1),
            isEnabled: !isMaxQuantity,
            isDark: isDark,
            accentColor: accentColor,
          ),
        ],
      ),
    );
  }

  Widget _buildQuantityButton({
    required IconData icon,
    required VoidCallback? onPressed,
    required bool isEnabled,
    required bool isDark,
    required Color accentColor,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(6),
        child: Container(
          padding: const EdgeInsets.all(10),
          child: FaIcon(
            icon,
            size: 14,
            color: isEnabled 
                ? accentColor 
                : (isDark ? Colors.grey[700] : Colors.grey[400]),
          ),
        ),
      ),
    );
  }
}
