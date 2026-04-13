// lib/screens/chat/ai_chat_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:intl/intl.dart';
import 'package:agrimore_core/agrimore_core.dart';
import 'package:agrimore_services/agrimore_services.dart';
import 'widgets/message_bubble.dart';
import 'chat_history_screen.dart';

class AIChatScreen extends HookWidget {
  const AIChatScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final textController = useTextEditingController();
    final scrollController = useScrollController();
    final focusNode = useFocusNode();

    final chat = _useAIChat(
      context: context,
      scrollController: scrollController,
    );

    final showScrollToBottom = useState(false);

    useEffect(() {
      void scrollListener() {
        final show =
            scrollController.hasClients && scrollController.offset > 200;
        if (show != showScrollToBottom.value) {
          showScrollToBottom.value = show;
        }
      }

      scrollController.addListener(scrollListener);
      return () => scrollController.removeListener(scrollListener);
    }, [scrollController]);

    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      backgroundColor: colorScheme.background,
      appBar: const _ChatAppBar(),
      body: chat.state.isInitializing
          ? const _LoadingState()
          : Stack(
              children: [
                Column(
                  children: [
                    if (chat.state.isGuest) const _GuestModeBanner(),
                    // Stats bar removed for cleaner UI
                    Expanded(
                      child: _MessageList(
                        scrollController: scrollController,
                        messages: chat.state.messages,
                        onQuickReply: (reply) {
                          textController.text = reply;
                          chat.actions.sendMessage(reply);
                        },
                        onReply: chat.actions.setReplyTo,
                        onCopy: (text) {
                          Clipboard.setData(ClipboardData(text: text));
                          chat.actions.showSnack('Message copied',
                              isError: false);
                        },
                      ),
                    ),
                    if (chat.state.replyToMessage != null)
                      _ReplyingToBar(
                        message: chat.state.replyToMessage!,
                        onCancel: () => chat.actions.setReplyTo(null),
                      ),
                    _ChatInputArea(
                      controller: textController,
                      focusNode: focusNode,
                      isLoading: chat.state.isLoading,
                      onSend: chat.actions.sendMessage,
                    ),
                  ],
                ),
                if (showScrollToBottom.value)
                  Positioned(
                    right: 16,
                    bottom: 90,
                    child: FloatingActionButton.small(
                      onPressed: chat.actions.scrollToBottom,
                      backgroundColor: colorScheme.primary,
                      child: Icon(Icons.arrow_downward,
                          color: colorScheme.onPrimary),
                    ),
                  ),
              ],
            ),
    );
  }
}

class _AIChatState {
  final List<ChatMessage> messages;
  final bool isLoading;
  final bool isInitializing;
  final bool isGuest;
  final Map<String, int> sessionStats;
  final ChatMessage? replyToMessage;

  _AIChatState({
    required this.messages,
    required this.isLoading,
    required this.isInitializing,
    required this.isGuest,
    required this.sessionStats,
    this.replyToMessage,
  });
}

class _AIChatActions {
  final Future<void> Function(String) sendMessage;
  final Future<void> Function() startNewChat;
  final Future<void> Function() showHistory;
  final void Function(String?) setReplyTo;
  final void Function() scrollToBottom;
  final void Function(String, {required bool isError}) showSnack;

  _AIChatActions({
    required this.sendMessage,
    required this.startNewChat,
    required this.showHistory,
    required this.setReplyTo,
    required this.scrollToBottom,
    required this.showSnack,
  });
}

({_AIChatState state, _AIChatActions actions}) _useAIChat({
  required BuildContext context,
  required ScrollController scrollController,
}) {
  final messages = useState<List<ChatMessage>>([]);
  final isLoading = useState(false);
  final isInitializing = useState(true);
  final isGuest = useState(false);
  final sessionStats = useState<Map<String, int>>({});
  final replyToMessageId = useState<String?>(null);

  final aiService = useMemoized(() => AIChatService());

  final theme = Theme.of(context);
  final colorScheme = theme.colorScheme;

  void scrollToBottom({Duration delay = Duration.zero}) {
    Future.delayed(delay, () {
      if (!context.mounted || !scrollController.hasClients) return;
      scrollController.animateTo(
        scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    });
  }

  void showSnack(String msg, {required bool isError}) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          msg,
          style: TextStyle(
            color: isError
                ? colorScheme.onErrorContainer
                : colorScheme.onPrimaryContainer,
          ),
        ),
        backgroundColor: isError
            ? colorScheme.errorContainer
            : colorScheme.primaryContainer,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  void showGuestModeDialog() {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Guest Mode: Chat history won\'t be saved.',
          style: TextStyle(color: colorScheme.onSecondaryContainer),
        ),
        backgroundColor: colorScheme.secondaryContainer,
        duration: const Duration(seconds: 5),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
        action: SnackBarAction(
          label: 'Login',
          textColor: colorScheme.secondary,
          onPressed: () =>
              Navigator.pushReplacementNamed(context, '/login'),
        ),
      ),
    );
  }

  Future<void> loadSessionStats() async {
    try {
      sessionStats.value = aiService.getSessionStats();
    } catch (e) {
      debugPrint('Session stats error: $e');
    }
  }

  Future<void> initializeChat([String? sessionId]) async {
    isInitializing.value = true;
    try {
      if (sessionId != null) {
        final history = await aiService.loadSessionHistory(sessionId);
        messages.value = history;
      } else {
        final currentSessionId = aiService.currentSessionId;
        final history = await aiService.loadSessionHistory(currentSessionId);
        if (history.isNotEmpty && !isGuest.value) {
          messages.value = history;
        } else {
          final greeting = ChatMessage.ai(
            text: isGuest.value
                ? '**Welcome to Agrimore!**\nYou are in Guest Mode — limited features.'
                : '**Welcome to Agrimore!**\nYour smart agricultural assistant is ready.',
            sessionId: currentSessionId,
            quickReplies: ['Show all products', 'Best deals'],
            category: 'greeting',
          );
          messages.value = [greeting];
          if (!isGuest.value) await aiService.saveMessage(greeting);
        }
      }
      scrollToBottom(delay: const Duration(milliseconds: 300));
      if (!isGuest.value) await loadSessionStats();
    } catch (e) {
      debugPrint('Initialize chat error: $e');
      messages.value = [
        ChatMessage.error(
          text: 'Failed to load chat history or initialize.',
          sessionId: aiService.currentSessionId,
          errorMessage: e.toString(),
        )
      ];
    } finally {
      isInitializing.value = false;
    }
  }

  Future<void> checkAuthAndInitialize() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      isGuest.value = user == null;
      if (isGuest.value) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          showGuestModeDialog();
        });
      }
      await initializeChat();
    } catch (e) {
      debugPrint('Auth check failed: $e');
      showSnack('Failed to initialize chat.', isError: true);
      isInitializing.value = false;
    }
  }

  Future<void> sendMessage(String text) async {
    if (text.trim().isEmpty) return;

    HapticFeedback.mediumImpact();

    final userMessage = ChatMessage.user(
      text: text.trim(),
      sessionId: aiService.currentSessionId,
      replyTo: replyToMessageId.value,
      category: 'user_query',
    );

    isLoading.value = true;
    replyToMessageId.value = null;
    messages.value = [...messages.value, userMessage];
    scrollToBottom();

    if (!isGuest.value) await aiService.saveMessage(userMessage);

    final loading = ChatMessage.loading(
        sessionId: aiService.currentSessionId, category: 'system');
    messages.value = [...messages.value, loading];
    scrollToBottom(delay: const Duration(milliseconds: 100));

    try {
      final aiResponse = await aiService.processUserMessage(
        text,
        conversationHistory:
            messages.value.where((m) => m.id != loading.id).toList(),
      );

      messages.value = [
        ...messages.value.where((m) => m.id != loading.id),
        aiResponse
      ];

      if (!isGuest.value) {
        await aiService.saveMessage(aiResponse);
        await loadSessionStats();
      }
    } catch (e) {
      debugPrint('AI message error: $e');
      messages.value = [
        ...messages.value.where((m) => m.id != loading.id),
        ChatMessage.error(
          text: 'Something went wrong. Please try again.',
          sessionId: aiService.currentSessionId,
          errorMessage: e.toString(),
        )
      ];
    } finally {
      isLoading.value = false;
      scrollToBottom(delay: const Duration(milliseconds: 200));
    }
  }

  Future<void> startNewChat() async {
    if (isGuest.value) {
      aiService.startNewSession();
      await initializeChat();
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Start New Chat?'),
        content: const Text(
          'Your current chat will be saved in history. Start a new one?',
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Start New')),
        ],
      ),
    );

    if (confirmed == true) {
      aiService.startNewSession();
      await initializeChat();
      HapticFeedback.mediumImpact();
      showSnack('New chat started!', isError: false);
    }
  }

  Future<void> showHistory() async {
    if (isGuest.value) {
      showSnack('Login to access chat history', isError: true);
      return;
    }

    final selectedSession = await Navigator.push<String>(
      context,
      MaterialPageRoute(builder: (_) => const ChatHistoryScreen()),
    );

    if (selectedSession != null) {
      await initializeChat(selectedSession);
    }
  }

  void setReplyTo(String? messageId) {
    replyToMessageId.value = messageId;
  }

  useEffect(() {
    checkAuthAndInitialize();
    return null;
  }, []);

  final state = _AIChatState(
    messages: messages.value,
    isLoading: isLoading.value,
    isInitializing: isInitializing.value,
    isGuest: isGuest.value,
    sessionStats: sessionStats.value,
    replyToMessage: replyToMessageId.value == null
        ? null
        : messages.value.firstWhereOrNull(
            (m) => m.id == replyToMessageId.value),
  );

  final actions = _AIChatActions(
    sendMessage: sendMessage,
    startNewChat: startNewChat,
    showHistory: showHistory,
    setReplyTo: setReplyTo,
    scrollToBottom: scrollToBottom,
    showSnack: showSnack,
  );

  return (state: state, actions: actions);
}

class _ChatAppBar extends StatelessWidget implements PreferredSizeWidget {
  const _ChatAppBar();

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return AppBar(
      backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
      elevation: 0.5,
      title: const Text(
        'Agrimore Assistant',
        style: TextStyle(
          fontWeight: FontWeight.w600,
          fontSize: 18,
        ),
      ),
      centerTitle: false,
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
}

class _LoadingState extends StatelessWidget {
  const _LoadingState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(
              color: Theme.of(context).colorScheme.primary),
          const SizedBox(height: 20),
          Text('Loading conversation...',
              style: Theme.of(context).textTheme.bodyLarge),
        ],
      ),
    );
  }
}

class _GuestModeBanner extends StatelessWidget {
  const _GuestModeBanner();

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: colorScheme.secondaryContainer,
      child: Row(
        children: [
          Icon(Icons.info_outline, color: colorScheme.onSecondaryContainer),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Guest Mode – Limited features enabled',
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(color: colorScheme.onSecondaryContainer),
            ),
          ),
          TextButton(
            onPressed: () =>
                Navigator.pushReplacementNamed(context, '/login'),
            child: Text(
              'Login',
              style: TextStyle(
                  color: colorScheme.secondary, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }
}

class _SessionStatsBar extends StatelessWidget {
  final Map<String, int> stats;

  const _SessionStatsBar({required this.stats});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: colorScheme.primaryContainer.withValues(alpha: 0.5),
        border: Border(
          bottom: BorderSide(color: colorScheme.outlineVariant.withValues(alpha: 0.5)),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _StatChip(
            icon: Icons.chat_bubble_outline,
            value: '${stats['totalMessages'] ?? 0}',
            label: 'Messages',
          ),
          _StatChip(
            icon: Icons.shopping_bag_outlined,
            value: '${stats['productViews'] ?? 0}',
            label: 'Products',
          ),
          _StatChip(
            icon: Icons.person_outline,
            value: '${stats['userMessages'] ?? 0}',
            label: 'You',
          ),
        ],
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;

  const _StatChip(
      {required this.icon, required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: colorScheme.onPrimaryContainer),
        const SizedBox(width: 6),
        Text(value,
            style: textTheme.bodySmall?.copyWith(
              fontWeight: FontWeight.w600,
              color: colorScheme.onPrimaryContainer,
            )),
        const SizedBox(width: 4),
        Text(label,
            style: textTheme.bodySmall
                ?.copyWith(color: colorScheme.onPrimaryContainer)),
      ],
    );
  }
}

class _MessageList extends StatelessWidget {
  final ScrollController scrollController;
  final List<ChatMessage> messages;
  final void Function(String) onQuickReply;
  final void Function(String) onReply;
  final void Function(String) onCopy;

  const _MessageList({
    required this.scrollController,
    required this.messages,
    required this.onQuickReply,
    required this.onReply,
    required this.onCopy,
  });

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      controller: scrollController,
      padding: const EdgeInsets.all(16),
      itemCount: messages.length,
      itemBuilder: (context, index) {
        final message = messages[index];
        final showTimestamp = index == 0 ||
            messages[index - 1]
                    .timestamp
                    .difference(message.timestamp)
                    .inMinutes >
                5;

        return Column(
          children: [
            if (showTimestamp) _buildTimestamp(context, message.timestamp),
            GestureDetector(
              onLongPress: () => _showMessageOptions(context, message),
              child: MessageBubble(
                message: message,
                onQuickReply: onQuickReply,
                onOrderTap: (orderId) {
                  Navigator.pushNamed(
                    context,
                    '/order-details',
                    arguments: orderId,
                  );
                },
                onBookmark: () {},
                onRate: (_) {},
                onCopy: () => onCopy(message.text),
              ),
            ),
            const SizedBox(height: 12),
          ],
        );
      },
    );
  }

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

  void _showMessageOptions(BuildContext context, ChatMessage message) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.reply),
              title: const Text('Reply'),
              onTap: () {
                Navigator.pop(context);
                onReply(message.id);
              },
            ),
            ListTile(
              leading: const Icon(Icons.copy),
              title: const Text('Copy'),
              onTap: () {
                Navigator.pop(context);
                onCopy(message.text);
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _ReplyingToBar extends StatelessWidget {
  final ChatMessage message;
  final VoidCallback onCancel;

  const _ReplyingToBar({required this.message, required this.onCancel});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: colorScheme.primaryContainer.withOpacity(0.6),
        border: Border(
          top: BorderSide(color: colorScheme.outlineVariant.withOpacity(0.5)),
        ),
      ),
      child: Row(
        children: [
          Icon(Icons.reply, size: 18, color: colorScheme.onPrimaryContainer),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message.text.replaceAll('\n', ' '),
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: colorScheme.onPrimaryContainer),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          IconButton(
            icon: Icon(Icons.close,
                size: 18, color: colorScheme.onPrimaryContainer),
            onPressed: onCancel,
          ),
        ],
      ),
    );
  }
}

class _ChatInputArea extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final bool isLoading;
  final void Function(String) onSend;

  const _ChatInputArea({
    required this.controller,
    required this.focusNode,
    required this.isLoading,
    required this.onSend,
  });

  void _handleSend() {
    final text = controller.text.trim();
    if (text.isEmpty) return;
    controller.clear(); // Clear input immediately
    onSend(text);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 15,
            offset: const Offset(0, -3),
          )
        ],
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          child: Row(
            children: [
              // Input field with glass effect
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: isDark 
                        ? Colors.white.withOpacity(0.08) 
                        : const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(28),
                    border: Border.all(
                      color: isDark 
                          ? Colors.white.withOpacity(0.1)
                          : const Color(0xFFE2E8F0),
                    ),
                  ),
                  child: TextField(
                    controller: controller,
                    focusNode: focusNode,
                    style: TextStyle(
                      color: isDark ? Colors.white : Colors.black87,
                      fontSize: 15,
                    ),
                    decoration: InputDecoration(
                      hintText: 'Ask me anything...',
                      hintStyle: TextStyle(
                        color: isDark ? Colors.grey[500] : Colors.grey[500],
                        fontSize: 15,
                      ),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 20, 
                        vertical: 14,
                      ),
                      prefixIcon: Icon(
                        Icons.chat_bubble_outline_rounded,
                        color: isDark ? Colors.grey[500] : Colors.grey[500],
                        size: 20,
                      ),
                    ),
                    textInputAction: TextInputAction.send,
                    onSubmitted: isLoading ? null : (_) => _handleSend(),
                    enabled: !isLoading,
                    maxLines: 1,
                    textCapitalization: TextCapitalization.sentences,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              // Professional send button with AppColors
              GestureDetector(
                onTap: isLoading ? null : _handleSend,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    gradient: isLoading
                        ? null
                        : const LinearGradient(
                            colors: [
                              Color(0xFF2E7D32), // AppColors.primary
                              Color(0xFF43A047),
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                    color: isLoading 
                        ? (isDark ? Colors.grey[800] : Colors.grey[300])
                        : null,
                    borderRadius: BorderRadius.circular(26),
                    boxShadow: isLoading
                        ? null
                        : [
                            BoxShadow(
                              color: const Color(0xFF2E7D32).withOpacity(0.4),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            ),
                          ],
                  ),
                  child: isLoading
                      ? const Padding(
                          padding: EdgeInsets.all(14),
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            color: Colors.grey,
                          ),
                        )
                      : const Icon(
                          Icons.send_rounded,
                          color: Colors.white,
                          size: 22,
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

extension ListExtension<T> on List<T> {
  T? firstWhereOrNull(bool Function(T) test) {
    try {
      return firstWhere(test);
    } catch (e) {
      return null;
    }
  }
}
