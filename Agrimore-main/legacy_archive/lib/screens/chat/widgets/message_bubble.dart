// lib/screens/chat/widgets/message_bubble.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:agroconnect/models/chat_message.dart';
import 'product_card_horizontal.dart';
import 'quick_reply_chip.dart';
import 'typing_indicator.dart';
import 'order_card_renderer.dart';

class MessageBubble extends HookWidget {
  final ChatMessage message;
  final Function(String)? onQuickReply;
  final Function(String)? onOrderTap;
  final Function(int)? onRate;
  final VoidCallback? onBookmark;
  final VoidCallback? onCopy;

  const MessageBubble({
    Key? key,
    required this.message,
    this.onQuickReply,
    this.onOrderTap,
    this.onRate,
    this.onBookmark,
    this.onCopy,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // --- Animation with Hooks ---
    final animationController = useAnimationController(
      duration: const Duration(milliseconds: 300),
    );

    final fadeAnimation = useMemoized(
      () => Tween<double>(begin: 0.0, end: 1.0).animate(
        CurvedAnimation(parent: animationController, curve: Curves.easeOut),
      ),
      [animationController],
    );

    final slideAnimation = useMemoized(
      () => Tween<Offset>(
        begin: Offset(message.isUser ? 0.3 : -0.3, 0),
        end: Offset.zero,
      ).animate(
        CurvedAnimation(parent: animationController, curve: Curves.easeOut),
      ),
      [animationController],
    );

    useEffect(() {
      animationController.forward();
      return null;
    }, [animationController]);

    // --- Widget Build Logic ---
    if (message.messageType == MessageType.loading) {
      return const Align(
        alignment: Alignment.centerLeft,
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 4.0),
          child: TypingIndicator(),
        ),
      );
    }

    if (message.messageType == MessageType.system) {
      return const SizedBox.shrink(); // Don't render system messages
    }

    return FadeTransition(
      opacity: fadeAnimation,
      child: SlideTransition(
        position: slideAnimation,
        child: Align(
          alignment:
              message.isUser ? Alignment.centerRight : Alignment.centerLeft,
          child: Container(
            constraints: BoxConstraints(
              maxWidth: MediaQuery.of(context).size.width * 0.8,
            ),
            margin: const EdgeInsets.symmetric(vertical: 4),
            child: Column(
              crossAxisAlignment:
                  message.isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
              children: [
                _buildMessageContent(context, theme, message),

                // ✅ FIXED: Order List with proper null handling
                if (message.hasOrders && onOrderTap != null) ...[
                  const SizedBox(height: 10),
                  OrderCardRenderer(
                    message: message,
                    onOrderTap: onOrderTap!,  // Non-nullable now
                  ),
                ],

                if (message.hasProducts) ...[
                  const SizedBox(height: 10),
                  _buildProductsList(message),
                ],
                if (message.hasQuickReplies) ...[
                  const SizedBox(height: 10),
                  _buildQuickReplies(message, onQuickReply),
                ],
                if (message.hasSuggestions) ...[
                  const SizedBox(height: 8),
                  _buildSuggestions(context, theme, message),
                ],
                if (message.isAI) ...[
                  const SizedBox(height: 4),
                  _buildMessageActions(
                    context,
                    theme,
                    message,
                    onRate,
                    onBookmark,
                    onCopy,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// -----------------------------------------------------------------
// Private Helper Functions (Extracted from class for cleanliness)
// -----------------------------------------------------------------

Widget _buildMessageContent(
    BuildContext context, ThemeData theme, ChatMessage message) {
  final colorScheme = theme.colorScheme;
  final textTheme = theme.textTheme;

  final borderRadius = BorderRadius.only(
    topLeft: const Radius.circular(20),
    topRight: const Radius.circular(20),
    bottomLeft: Radius.circular(message.isUser ? 20 : 4),
    bottomRight: Radius.circular(message.isUser ? 4 : 20),
  );

  // Themed colors
  final Color bubbleColor;
  final Color textColor;
  final Color timeColor;
  final Gradient? gradient;

  if (message.isUser) {
    bubbleColor = Colors.transparent; // Will be covered by gradient
    gradient = LinearGradient(
      colors: [
        colorScheme.primary,
        colorScheme.primary.withValues(alpha: 0.8),
      ],
    );
    textColor = colorScheme.onPrimary;
    timeColor = colorScheme.onPrimary.withValues(alpha: 0.7);
  } else if (message.isError) {
    bubbleColor = colorScheme.errorContainer;
    gradient = null;
    textColor = colorScheme.onErrorContainer;
    timeColor = colorScheme.onErrorContainer.withOpacity(0.7);
  } else {
    bubbleColor = colorScheme.surfaceContainerHighest;
    gradient = null;
    textColor = colorScheme.onSurface;
    timeColor = colorScheme.onSurfaceVariant;
  }

  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
    decoration: BoxDecoration(
      gradient: gradient,
      color: bubbleColor,
      borderRadius: borderRadius,
      boxShadow: [
        BoxShadow(
          color: colorScheme.shadow.withOpacity(0.05),
          blurRadius: 6,
          offset: const Offset(0, 2),
        ),
      ],
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Use Markdown for AI, simple Text for user
        if (message.isAI || message.isError)
          MarkdownBody(
            data: message.text,
            selectable: true,
            styleSheet: MarkdownStyleSheet.fromTheme(theme).copyWith(
              p: textTheme.bodyMedium
                  ?.copyWith(height: 1.4, color: textColor),
              a: textTheme.bodyMedium?.copyWith(
                color: colorScheme.primary, // Links are always primary color
                decoration: TextDecoration.underline,
              ),
            ),
          )
        else
          Text(
            message.text,
            style: textTheme.bodyMedium
                ?.copyWith(color: textColor, height: 1.4, fontSize: 15),
          ),
        const SizedBox(height: 4),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              message.formattedTime,
              style: textTheme.bodySmall?.copyWith(color: timeColor, fontSize: 11),
            ),
            if (message.isBookmarked) ...[
              const SizedBox(width: 4),
              Icon(
                Icons.bookmark,
                size: 12,
                color: message.isUser ? timeColor : Colors.amber[700],
              ),
            ],
          ],
        ),
      ],
    ),
  );
}

Widget _buildProductsList(ChatMessage message) {
  return SizedBox(
    height: 220,
    child: ListView.builder(
      scrollDirection: Axis.horizontal,
      itemCount: message.productCount,
      padding: const EdgeInsets.symmetric(horizontal: 4),
      itemBuilder: (context, index) {
        final product = message.products![index];
        return Padding(
          padding: const EdgeInsets.only(right: 12),
          child: ProductCardHorizontal(product: product),
        );
      },
    ),
  );
}

Widget _buildQuickReplies(
    ChatMessage message, Function(String)? onQuickReply) {
  return Wrap(
    spacing: 8,
    runSpacing: 8,
    children: message.quickReplies!.map((reply) {
      return QuickReplyChip(
        label: reply,
        onTap: () => onQuickReply?.call(reply),
      );
    }).toList(),
  );
}

Widget _buildSuggestions(
    BuildContext context, ThemeData theme, ChatMessage message) {
  final suggestions = (message.data != null &&
          message.data!['suggestions'] is List)
      ? List<String>.from(message.data!['suggestions'])
      : <String>[];

  if (suggestions.isEmpty) return const SizedBox.shrink();

  final colorScheme = theme.colorScheme;
  final textTheme = theme.textTheme;

  return Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: colorScheme.tertiaryContainer,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: colorScheme.outlineVariant.withOpacity(0.5)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.tips_and_updates,
                size: 16, color: colorScheme.onTertiaryContainer),
            const SizedBox(width: 6),
            Text(
              'Suggestions:',
              style: textTheme.bodySmall?.copyWith(
                color: colorScheme.onTertiaryContainer,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ...suggestions.map(
          (s) => Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Text(
              '• $s',
              style: textTheme.bodySmall
                  ?.copyWith(color: colorScheme.onTertiaryContainer),
            ),
          ),
        ),
      ],
    ),
  );
}

Widget _buildMessageActions(
  BuildContext context,
  ThemeData theme,
  ChatMessage message,
  Function(int)? onRate,
  VoidCallback? onBookmark,
  VoidCallback? onCopy,
) {
  return Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      if (message.isRated)
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.amber.shade50,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              Icon(Icons.star, size: 12, color: Colors.amber[700]),
              const SizedBox(width: 4),
              Text(
                '${message.rating}',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: Colors.amber[900],
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        )
      else
        TextButton.icon(
          onPressed: () => _showRatingDialog(context, onRate),
          icon: Icon(Icons.star_outline,
              size: 14, color: theme.colorScheme.onSurfaceVariant),
          label: Text(
            'Rate',
            style: theme.textTheme.bodySmall
                ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
          style: TextButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            minimumSize: Size.zero,
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
        ),
      IconButton(
        icon: Icon(
          message.isBookmarked ? Icons.bookmark : Icons.bookmark_outline,
          size: 18,
          color: message.isBookmarked
              ? Colors.amber[700]
              : theme.colorScheme.onSurfaceVariant,
        ),
        padding: EdgeInsets.zero,
        constraints: const BoxConstraints(),
        onPressed: onBookmark,
      ),
      IconButton(
        icon: Icon(Icons.copy_outlined,
            size: 18, color: theme.colorScheme.onSurfaceVariant),
        padding: EdgeInsets.zero,
        constraints: const BoxConstraints(),
        onPressed: onCopy,
      ),
    ],
  );
}

void _showRatingDialog(BuildContext context, Function(int)? onRate) {
  showDialog(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Rate this response'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('How helpful was this answer?'),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: List.generate(5, (index) {
              final rating = index + 1;
              return IconButton(
                icon: Icon(Icons.star, color: Colors.amber[700], size: 32),
                onPressed: () {
                  onRate?.call(rating);
                  Navigator.pop(context);
                },
              );
            }),
          ),
        ],
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    ),
  );
}
