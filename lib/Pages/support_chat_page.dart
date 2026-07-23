import 'package:flutter/material.dart';
import 'package:login_ui/services/ai_service.dart';
import 'package:login_ui/components/jarvis_avatar.dart';
import 'package:login_ui/theme/app_theme.dart';

class SupportChatPage extends StatefulWidget {
  const SupportChatPage({super.key});

  @override
  State<SupportChatPage> createState() => _SupportChatPageState();
}

class _SupportChatPageState extends State<SupportChatPage> {
  final AiService _aiService = AiService();
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  final List<AiMessage> _messages = [
    const AiMessage(
      role: 'assistant',
      content:
          "Hi! I'm Jarvis, the GroupApp assistant. Ask me anything — how to "
          "create or join a group, add calendar events, change settings, and "
          "more. Tip: you can also summon me in any group chat by typing "
          "\"@jarvis\" followed by your question.",
    ),
  ];
  bool _isSending = false;

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty || _isSending) return;

    setState(() {
      _messages.add(AiMessage(role: 'user', content: text));
      _isSending = true;
    });
    _messageController.clear();
    _scrollToBottom();

    try {
      final reply = await _aiService.sendMessage(_messages);
      if (!mounted) return;
      setState(() {
        _messages.add(AiMessage(role: 'assistant', content: reply));
        _isSending = false;
      });
      _scrollToBottom();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _messages.add(
          const AiMessage(
            role: 'assistant',
            content:
                "Sorry, I'm having trouble responding right now. Please try again.",
          ),
        );
        _isSending = false;
      });
      _scrollToBottom();
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        flexibleSpace: const GradientAppBarBackground(),
        title: Row(
          children: [
            const JarvisAvatar(radius: 14),
            const SizedBox(width: 10),
            const Text(
              'Jarvis',
              style: TextStyle(color: Colors.white),
            ),
          ],
        ),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: NeonBackground(
        child: Column(
        children: [
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.all(16),
              itemCount: _messages.length + (_isSending ? 1 : 0),
              itemBuilder: (context, index) {
                // Typing indicator as the trailing item while waiting.
                if (_isSending && index == _messages.length) {
                  return _buildBubble(
                    context,
                    isUser: false,
                    child: SizedBox(
                      width: 40,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '...',
                            style: TextStyle(
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                final message = _messages[index];
                return _buildBubble(
                  context,
                  isUser: message.isUser,
                  child: Text(
                    message.content,
                    style: TextStyle(
                      color: message.isUser
                          ? colorScheme.onPrimary
                          : colorScheme.onSurface,
                      fontSize: 14,
                    ),
                  ),
                );
              },
            ),
          ),

          // Message input
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isDark
                  ? colorScheme.surfaceContainerHigh
                  : colorScheme.surface,
              border: Border(
                top: BorderSide(
                  color: colorScheme.outlineVariant.withValues(alpha: 0.7),
                  width: 0.5,
                ),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _messageController,
                    decoration: InputDecoration(
                      hintText: 'Ask about GroupApp...',
                      hintStyle:
                          TextStyle(color: colorScheme.onSurfaceVariant),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: BorderSide.none,
                      ),
                      filled: true,
                      fillColor: isDark
                          ? colorScheme.surfaceContainerHigh
                          : colorScheme.surfaceContainerLow,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 10,
                      ),
                    ),
                    style: TextStyle(color: colorScheme.onSurface),
                    maxLines: null,
                    textCapitalization: TextCapitalization.sentences,
                    enabled: !_isSending,
                    onSubmitted: (_) => _sendMessage(),
                  ),
                ),
                const SizedBox(width: 8),
                CircleAvatar(
                  backgroundColor: colorScheme.primary,
                  child: IconButton(
                    icon: Icon(
                      Icons.send,
                      color: colorScheme.onPrimary,
                      size: 20,
                    ),
                    onPressed: _isSending ? null : _sendMessage,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      ),
    );
  }

  Widget _buildBubble(
    BuildContext context, {
    required bool isUser,
    required Widget child,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.75,
        ),
        decoration: BoxDecoration(
          color: isUser
              ? colorScheme.primary
              : (isDark
                  ? colorScheme.surfaceContainerHigh
                  : colorScheme.surface),
          borderRadius: BorderRadius.circular(12),
        ),
        child: child,
      ),
    );
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }
}
