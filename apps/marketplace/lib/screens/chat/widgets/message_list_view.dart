// lib/screens/chat/widgets/message_list_view.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:agrimore_core/agrimore_core.dart';
import 'message_bubble.dart';
import 'order_card_renderer.dart';

class MessageListView extends StatelessWidget {
  final GlobalKey<AnimatedListState> listKey;
  final ScrollController scrollController;
  final List<ChatMessage> messages;
  final Function(String) onQuickReply;
  final Function(ChatMessage) onShowMessageOptions;
  final Function(String) onOrderTap;

  const MessageListView({
    Key? key,
    required this.listKey,
    required this.scrollController,
    required this.messages,
    required this.onQuickReply,
    required this.onShowMessageOptions,
    required this.onOrderTap,
  }) : super(key: key);

  Widget _buildTimestamp(BuildContext context, DateTime timestamp) {
    final formatted = DateFormat('MMM d, yyyy – hh:mm a').format(timestamp);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Text(
        formatted,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
      ),
    );
  }

  Widget _buildItem(
      BuildContext context, int index, Animation<double> animation) {
    final message = messages[index];
    final showTimestamp = index == 0 ||
        messages[index - 1]
                .timestamp
                .difference(message.timestamp)
                .inMinutes >
            5;

    return FadeTransition(
      opacity: animation,
      child: SizeTransition(
        sizeFactor: CurvedAnimation(parent: animation, curve: Curves.easeOut),
        child: Column(
          children: [
            if (showTimestamp) _buildTimestamp(context, message.timestamp),
            GestureDetector(
              onLongPress: () => onShowMessageOptions(message),
              child: MessageBubble(
                message: message,
                onQuickReply: onQuickReply,
                onBookmark: () {},
                onRate: (_) {},
                onCopy: () {
                  Clipboard.setData(ClipboardData(text: message.text));
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Message copied')),
                  );
                },
              ),
            ),
            const SizedBox(height: 8),
            OrderCardRenderer(
              message: message,
              onOrderTap: onOrderTap,
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return messages.isEmpty
        ? const Center(child: Text('No messages yet.'))
        : AnimatedList(
            key: listKey,
            controller: scrollController,
            padding: const EdgeInsets.all(16),
            initialItemCount: messages.length,
            itemBuilder: _buildItem,
          );
  }
}
