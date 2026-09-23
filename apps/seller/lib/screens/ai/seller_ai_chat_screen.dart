import 'package:agrimore_ui/agrimore_ui.dart';
import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../../providers/seller_ai_chat_provider.dart';
import '../../providers/seller_ai_connection_provider.dart';
import '../profile/seller_ai_integration_screen.dart';

/// M-08 AI assistant chat (ADR §10.6, SELLER-UI-1d): seller-scoped answers
/// through sellerAiChatProxy; suggested prompts; not-connected state → M-09.
class SellerAiChatScreen extends StatefulWidget {
  const SellerAiChatScreen({super.key});

  @override
  State<SellerAiChatScreen> createState() => _SellerAiChatScreenState();
}

class _SellerAiChatScreenState extends State<SellerAiChatScreen> {
  static const double _bubbleMaxFraction = 0.78;

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
      duration: WsMotion.standard,
      curve: WsMotion.curveEnter,
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

  void _send(String text) {
    if (text.trim().isEmpty || _chatProvider.isSending) return;
    _textController.clear();
    _chatProvider.sendMessage(text);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(tooltip: l10n.back, icon: const Icon(AgIcons.arrowLeft), onPressed: () => Navigator.of(context).maybePop()),
        title: Text(l10n.aiTitle),
      ),
      body: _connectionProvider.isLoading
          ? const Center(child: CircularProgressIndicator())
          : _connectionProvider.connected
              ? _buildChat()
              : _buildNotConnected(),
    );
  }

  Widget _buildNotConnected() {
    final l10n = AppLocalizations.of(context);
    final t = context.ws;
    final text = context.wsText;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(WsSpace.s24),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(AgIcons.sparkles, size: WsIconSize.empty, color: t.primary),
          const SizedBox(height: WsSpace.s16),
          Text(l10n.aiConnectTitle, style: text.titleMedium, textAlign: TextAlign.center),
          const SizedBox(height: WsSpace.s8),
          Text(l10n.aiConnectBody, style: text.bodyMedium!.copyWith(color: t.textSecondary), textAlign: TextAlign.center),
          const SizedBox(height: WsSpace.s24),
          FilledButton(
            onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const SellerAiIntegrationScreen())),
            child: Text(l10n.aiConnectNow),
          ),
        ]),
      ),
    );
  }

  Widget _buildChat() {
    final l10n = AppLocalizations.of(context);
    final messages = _chatProvider.messages;
    final itemCount = messages.length + (_chatProvider.isSending ? 1 : 0);
    final prompts = [l10n.aiPromptRestock, l10n.aiPromptBestSellers, l10n.aiPromptPricing];
    final showPrompts = messages.where((m) => m.isUser).isEmpty;
    return Column(children: [
      Expanded(
        child: ListView.builder(
          controller: _scrollController,
          padding: const EdgeInsets.all(WsSpace.page),
          itemCount: itemCount,
          itemBuilder: (context, i) => i >= messages.length ? const _TypingBubble() : _Bubble(message: messages[i], maxFraction: _bubbleMaxFraction),
        ),
      ),
      if (showPrompts)
        SizedBox(
          height: WsSize.chipHeight + WsSpace.s16,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: WsSpace.page, vertical: WsSpace.s8),
            children: [
              for (final p in prompts)
                Padding(
                  padding: const EdgeInsets.only(right: WsSpace.s8),
                  child: ActionChip(label: Text(p), onPressed: _chatProvider.isSending ? null : () => _send(p)),
                ),
            ],
          ),
        ),
      _buildInputBar(),
    ]);
  }

  Widget _buildInputBar() {
    final l10n = AppLocalizations.of(context);
    final t = context.ws;
    return DecoratedBox(
      decoration: BoxDecoration(color: t.surface, boxShadow: WsElevation.level1),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(WsSpace.s12, WsSpace.s8, WsSpace.s12, WsSpace.s12),
          child: Row(children: [
            Expanded(
              child: TextField(
                controller: _textController,
                enabled: !_chatProvider.isSending,
                textInputAction: TextInputAction.send,
                minLines: 1,
                maxLines: 4,
                decoration: InputDecoration(hintText: l10n.aiInputHint),
                onSubmitted: _send,
              ),
            ),
            const SizedBox(width: WsSpace.s8),
            IconButton.filled(
              tooltip: l10n.aiSend,
              onPressed: _chatProvider.isSending ? null : () => _send(_textController.text),
              icon: const Icon(AgIcons.chat),
            ),
          ]),
        ),
      ),
    );
  }
}

class _Bubble extends StatelessWidget {
  const _Bubble({required this.message, required this.maxFraction});
  final ChatMessage message;
  final double maxFraction;

  @override
  Widget build(BuildContext context) {
    final t = context.ws;
    final text = context.wsText;
    final isUser = message.isUser;
    final (Color bg, Color fg) = message.isError
        ? (t.errorBg, t.errorFg)
        : isUser
            ? (t.primary, t.onPrimary)
            : (t.surface, t.textPrimary);
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: WsSpace.s4),
        padding: const EdgeInsets.symmetric(horizontal: WsSpace.s12, vertical: WsSpace.s8),
        constraints: BoxConstraints(maxWidth: MediaQuery.sizeOf(context).width * maxFraction),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(WsRadius.card),
          border: isUser || message.isError ? null : Border.all(color: t.divider),
        ),
        child: SelectableText(message.text, style: text.bodyMedium!.copyWith(color: fg)),
      ),
    );
  }
}

class _TypingBubble extends StatelessWidget {
  const _TypingBubble();

  @override
  Widget build(BuildContext context) {
    final t = context.ws;
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: WsSpace.s4),
        padding: const EdgeInsets.all(WsSpace.s12),
        decoration: BoxDecoration(
          color: t.surface,
          borderRadius: BorderRadius.circular(WsRadius.card),
          border: Border.all(color: t.divider),
        ),
        child: SizedBox.square(
          dimension: WsIconSize.supporting,
          child: CircularProgressIndicator(semanticsLabel: AppLocalizations.of(context).aiThinking),
        ),
      ),
    );
  }
}
