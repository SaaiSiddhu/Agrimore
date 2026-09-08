import 'package:agrimore_ui/agrimore_ui.dart';
import 'package:flutter/material.dart';
import '../../providers/seller_ai_chat_provider.dart';
import '../../providers/seller_ai_connection_provider.dart';
import '../profile/seller_ai_integration_screen.dart';

/// Phase AI-4D — apps/seller's own AI Assistant chat screen. Reached from a
/// new SellerProfileScreen menu entry ("AI Assistant"), matching that
/// screen's own convention of pushing a dedicated screen for a stateful
/// feature rather than a simple info dialog.
///
/// Gated on connection status via a screen-local SellerAiConnectionProvider
/// instance (mirrors SellerAiIntegrationScreen's own pattern -- this
/// provider is not registered globally in main.dart, so every screen that
/// needs it creates and disposes its own): not connected shows a CTA to
/// SellerAiIntegrationScreen (AI-4C); connected shows the actual chat, driven
/// by SellerAiChatProvider (this phase), which does the functionCall dispatch
/// loop against sellerAiChatProxy (AI-4B).
class SellerAiChatScreen extends StatefulWidget {
  const SellerAiChatScreen({super.key});

  @override
  State<SellerAiChatScreen> createState() => _SellerAiChatScreenState();
}

class _SellerAiChatScreenState extends State<SellerAiChatScreen> {
  static const _accentColor = Color(0xFF2D7D3C);

  final _chatProvider = SellerAiChatProvider();
  final _connectionProvider = SellerAiConnectionProvider();
  final _textController = TextEditingController();
  final _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _connectionProvider.addListener(_onProviderChanged);
    _connectionProvider.loadStatus();
    _chatProvider.addListener(_onProviderChanged);
    _chatProvider.seedGreeting();
  }

  void _onProviderChanged() {
    if (!mounted) return;
    setState(() {});
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
  }

  void _scrollToBottom() {
    if (!_scrollController.hasClients) return;
    _scrollController.animateTo(
      _scrollController.position.maxScrollExtent,
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOut,
    );
  }

  @override
  void dispose() {
    _connectionProvider.removeListener(_onProviderChanged);
    _connectionProvider.dispose();
    _chatProvider.removeListener(_onProviderChanged);
    _textController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _handleSend() {
    final text = _textController.text;
    if (text.trim().isEmpty || _chatProvider.isSending) return;
    _textController.clear();
    _chatProvider.sendMessage(text);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF121212) : const Color(0xFFF5F7FA),
      appBar: AppBar(title: const Text('AI Assistant')),
      body: _connectionProvider.isLoading
          ? const Center(child: CircularProgressIndicator(color: _accentColor))
          : _connectionProvider.connected
              ? _buildChat(isDark)
              : _buildNotConnected(isDark),
    );
  }

  Widget _buildNotConnected(bool isDark) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.smart_toy_outlined, size: 56, color: _accentColor),
            const SizedBox(height: 16),
            Text('Connect your AI Assistant',
                style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 18,
                    color: isDark ? Colors.white : Colors.black87)),
            const SizedBox(height: 8),
            Text(
              'Connect your own ChatGPT or Gemini key to start asking questions about your products and orders.',
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontSize: 13, color: isDark ? Colors.grey[400] : const Color(0xFF6B7280)),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const SellerAiIntegrationScreen()),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: _accentColor,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              child: const Text('Connect Now',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChat(bool isDark) {
    final messages = _chatProvider.messages;
    final itemCount = messages.length + (_chatProvider.isSending ? 1 : 0);
    return Column(
      children: [
        Expanded(
          child: ListView.builder(
            controller: _scrollController,
            padding: const EdgeInsets.all(16),
            itemCount: itemCount,
            itemBuilder: (context, i) {
              if (i >= messages.length) return _buildTypingBubble(isDark);
              return _buildBubble(messages[i], isDark);
            },
          ),
        ),
        _buildInputBar(isDark),
      ],
    );
  }

  Widget _buildBubble(ChatMessage message, bool isDark) {
    final isUser = message.isUser;
    final isError = message.isError;
    final bg = isError
        ? AppColors.error.withValues(alpha: 0.1)
        : isUser
            ? _accentColor
            : (isDark ? Colors.grey[900] : Colors.white);
    final fg = isError
        ? AppColors.errorDark
        : isUser
            ? Colors.white
            : (isDark ? Colors.white : Colors.black87);

    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 6),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.78),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(14),
          border: (isUser || isError)
              ? null
              : Border.all(color: isDark ? Colors.grey[800]! : const Color(0xFFE5E7EB)),
        ),
        child: Text(message.text, style: TextStyle(color: fg, fontSize: 14, height: 1.4)),
      ),
    );
  }

  Widget _buildTypingBubble(bool isDark) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 6),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: isDark ? Colors.grey[900] : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: isDark ? Colors.grey[800]! : const Color(0xFFE5E7EB)),
        ),
        child: SizedBox(
          width: 18,
          height: 18,
          child: CircularProgressIndicator(strokeWidth: 2, color: _accentColor),
        ),
      ),
    );
  }

  Widget _buildInputBar(bool isDark) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 10, offset: const Offset(0, -2)),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _textController,
                  enabled: !_chatProvider.isSending,
                  textInputAction: TextInputAction.send,
                  decoration: InputDecoration(
                    hintText: 'Ask about your sales, products, or orders...',
                    filled: true,
                    fillColor: isDark ? Colors.grey[900] : const Color(0xFFF1F5F9),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(24),
                      borderSide: BorderSide.none,
                    ),
                  ),
                  onSubmitted: (_) => _handleSend(),
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                onPressed: _chatProvider.isSending ? null : _handleSend,
                icon: Icon(Icons.send_rounded,
                    color: _chatProvider.isSending ? Colors.grey : _accentColor),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
