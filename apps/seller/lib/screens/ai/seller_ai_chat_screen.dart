import 'package:agrimore_core/agrimore_core.dart';
import 'package:flutter/material.dart';

import '../../design_system/design_system.dart';
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
    final duration = context.motion(SellerMotion.standard);
    if (duration == Duration.zero) {
      _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
    } else {
      _scrollController.animateTo(_scrollController.position.maxScrollExtent, duration: duration, curve: SellerMotion.enter);
    }
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
    final connected = !_connectionProvider.isLoading && _connectionProvider.connected;
    return Scaffold(
      appBar: SellerAppBar.detail(
        context,
        title: l10n.aiTitle,
        status: connected ? SellerStatusBadge(label: l10n.aiStatusConnected, tone: SellerTone.success, icon: SellerIcons.success) : null,
      ),
      body: _connectionProvider.isLoading
          ? SellerLoadingView(label: l10n.dsLoading)
          : connected
              ? _buildChat()
              : _buildNotConnected(),
    );
  }

  /// Not connected (board 23-01): what the assistant does and where to
  /// connect it. Activation itself is website-only (D-SELLER-AI-WEB-ONLY).
  Widget _buildNotConnected() {
    final l10n = AppLocalizations.of(context);
    return SellerEmptyState(
      icon: SellerIcons.ai,
      title: l10n.aiConnectTitle,
      message: l10n.aiConnectBody,
      actionLabel: l10n.aiConnectNow,
      onAction: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const SellerAiIntegrationScreen())),
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
          padding: EdgeInsets.all(context.pageInset),
          itemCount: itemCount,
          itemBuilder: (context, i) => i >= messages.length
              ? const _TypingBubble()
              : _Bubble(
                  message: messages[i],
                  maxFraction: _bubbleMaxFraction,
                  onRetry: i == messages.length - 1 && messages[i].isError ? _chatProvider.retryLast : null,
                ),
        ),
      ),
      if (showPrompts)
        SellerChipBar(children: [
          for (final p in prompts)
            SellerChip(label: p, icon: SellerIcons.ai, selected: false, onSelected: _chatProvider.isSending ? null : (_) => _send(p)),
        ]),
      _buildInputBar(),
    ]);
  }

  Widget _buildInputBar() {
    final l10n = AppLocalizations.of(context);
    final c = context.colors;
    return DecoratedBox(
      decoration: BoxDecoration(color: c.surface, border: Border(top: BorderSide(color: c.border))),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(SellerSpace.s12, SellerSpace.s8, SellerSpace.s12, SellerSpace.s12),
          child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Expanded(
              child: TextField(
                controller: _textController,
                enabled: !_chatProvider.isSending,
                textInputAction: TextInputAction.send,
                minLines: 1,
                maxLines: 4,
                style: context.text.bodyLarge,
                decoration: InputDecoration(hintText: l10n.aiInputHint),
                onSubmitted: _send,
              ),
            ),
            const SizedBox(width: SellerSpace.s8),
            SellerIconButton(
              icon: SellerIcons.send,
              label: l10n.aiSend,
              filled: true,
              onPressed: _chatProvider.isSending ? null : () => _send(_textController.text),
            ),
          ]),
        ),
      ),
    );
  }
}

/// Chat bubble (board 23-01): the seller on the right in teal, the
/// assistant on the left on the surface with a sparkles avatar. Greeting,
/// not-connected and error messages are shown in the app's own words.
class _Bubble extends StatelessWidget {
  const _Bubble({required this.message, required this.maxFraction, this.onRetry});
  final ChatMessage message;
  final double maxFraction;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final c = context.colors;
    final text = context.text;
    final isUser = message.isUser;
    final body = message.isError
        ? l10n.aiChatError
        : switch (message.category) {
            'greeting' => l10n.aiGreeting,
            'ai_offline' => l10n.aiOffline,
            _ => message.text,
          };
    final (Color bg, Color fg) = message.isError
        ? (c.dangerContainer, c.danger)
        : isUser
            ? (c.primary, c.onPrimary)
            : (c.surface, c.textPrimary);
    final bubble = Container(
      margin: const EdgeInsets.symmetric(vertical: SellerSpace.s4),
      padding: const EdgeInsets.symmetric(horizontal: SellerSpace.s12, vertical: SellerSpace.s8),
      constraints: BoxConstraints(maxWidth: MediaQuery.sizeOf(context).width * maxFraction),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(SellerRadius.card),
        border: isUser || message.isError ? null : Border.all(color: c.border),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
        SelectableText(body, style: text.bodyLarge!.copyWith(color: fg)),
        const SizedBox(height: SellerSpace.s2),
        Text(SellerFormat.time(message.timestamp), style: text.bodySmall!.copyWith(color: isUser ? c.onPrimary : c.textSecondary)),
        if (onRetry != null) ...[
          const SizedBox(height: SellerSpace.s8),
          SellerButton.secondary(label: l10n.aiRetry, icon: SellerIcons.refresh, compact: true, expand: false, onPressed: onRetry),
        ],
      ]),
    );
    return Align(
      alignment: isUser ? AlignmentDirectional.centerEnd : AlignmentDirectional.centerStart,
      child: isUser
          ? bubble
          : Row(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Padding(padding: EdgeInsets.only(top: SellerSpace.s4), child: SellerIconTile(icon: SellerIcons.ai, circle: true, size: SellerSize.avatarSm)),
              const SizedBox(width: SellerSpace.s8),
              Flexible(child: bubble),
            ]),
    );
  }
}

class _TypingBubble extends StatelessWidget {
  const _TypingBubble();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Align(
      alignment: AlignmentDirectional.centerStart,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: SellerSpace.s8),
        child: SellerProgressLabel(label: l10n.aiThinking, center: false),
      ),
    );
  }
}
